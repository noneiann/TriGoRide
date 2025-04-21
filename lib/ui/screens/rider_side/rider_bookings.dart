import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/ui/root_page_rider.dart';
import '../../../services/auth_services.dart';

class RiderBookingsPage extends StatefulWidget {
  const RiderBookingsPage({super.key});

  @override
  State<RiderBookingsPage> createState() => _RiderBookingsPageState();
}

class _RiderBookingsPageState extends State<RiderBookingsPage> {
  final AuthService _authService = AuthService();

  // map & location
  GoogleMapController? _mapController;
  final Location _location = Location();
  LatLng? _currentLatLng;
  Set<Polyline> _polylines = {};

  // booking state
  bool _loading = true;
  Map<String, dynamic>? _acceptedBooking;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // load your location and the booking in parallel
    await Future.wait([
      _fetchUserLocation(),
      _loadAcceptedBooking(),
    ]);
    print(_acceptedBooking);
    if (_acceptedBooking != null) {
      await _getRoadPolylines();
    }
    setState(() => _loading = false);
  }

  Future<void> _fetchUserLocation() async {
    try {
      if (!await _location.serviceEnabled()) {
        if (!await _location.requestService()) return;
      }
      if (await _location.hasPermission() == PermissionStatus.denied) {
        if (await _location.requestPermission() != PermissionStatus.granted) return;
      }
      final loc = await _location.getLocation();
      _currentLatLng = LatLng(loc.latitude!, loc.longitude!);
    } catch (e) {
      debugPrint('Error fetching user location: $e');
    }
  }

  Future<void> _loadAcceptedBooking() async {
    setState(() => _loading = true);
    try {
      final uid = _authService.getUser().uid;
      final snap = await _authService.firestore
          .collection('bookings')
          .where('assignedRider', isEqualTo: uid)
          .where('status', isEqualTo: 'Accepted')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final d = doc.data() as Map<String, dynamic>;

        // Safe‐cast to String? and provide fallback
        final passenger = d['passenger']?.toString() ?? 'Unknown';
        final phone     = d['phone']    ?.toString() ?? 'N/A';

        final GeoPoint? pickupGP  = d['pickUp']  as GeoPoint?;
        final GeoPoint? dropoffGP = d['dropOff'] as GeoPoint?;
        final Timestamp? ts       = d['dateBooked'] as Timestamp?;

        if (pickupGP == null || dropoffGP == null || ts == null) {
          debugPrint('Booking ${doc.id} missing required geo or date fields');
          _acceptedBooking = null;
        } else {
          _acceptedBooking = {
            'id'       : doc.id,
            'passenger': passenger,
            'phone'    : phone,
            'pickUp'   : pickupGP,
            'dropOff'  : dropoffGP,
            'datetime' : ts.toDate(),
            'status'   : d['status']
          };
        }
      } else {
        _acceptedBooking = null;
      }
    } catch (e) {
      debugPrint('Error loading booking: $e');
      _acceptedBooking = null;
    } finally {
      setState(() => _loading = false);
    }
  }


  Future<void> _getRoadPolylines() async {
    if (_acceptedBooking == null) return;
    final GeoPoint p = _acceptedBooking!['pickUp'] as GeoPoint;
    final GeoPoint d = _acceptedBooking!['dropOff'] as GeoPoint;

    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.get('GOOGLEMAPS_APIKEY');
    final polylinePoints = PolylinePoints();

    final result = await polylinePoints.getRouteBetweenCoordinates(
      apiKey,
      PointLatLng(p.latitude, p.longitude),
      PointLatLng(d.latitude, d.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      final route = result.points
          .map((pt) => LatLng(pt.latitude, pt.longitude))
          .toList();

      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: route,
        width: 5,
        color: Colors.blue,
      ));

      // once map is ready, animate camera to fit
      if (_mapController != null) {
        final bounds = _calculateBounds(route);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
      }
    } else {
      debugPrint('Directions API returned no points: ${result.errorMessage}');
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> pts) {
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    final south = lats.reduce((a, b) => a < b ? a : b);
    final north = lats.reduce((a, b) => a > b ? a : b);
    final west = lngs.reduce((a, b) => a < b ? a : b);
    final east = lngs.reduce((a, b) => a > b ? a : b);
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  void _completeRide() async {
    if (_acceptedBooking == null) return;
    try {
      await _authService.firestore
          .collection('bookings')
          .doc(_acceptedBooking!['id'])
          .update({'status': 'Completed'});
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RootPageRider()),);
    } catch (e) {
      debugPrint('Error completing ride: $e');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Accepted':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_acceptedBooking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Booking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: const Center(child: Text('You have no active bookings.')),
      );
    }

    final booking = _acceptedBooking!;
    final GeoPoint pg = booking['pickUp'] as GeoPoint;
    final GeoPoint dg = booking['dropOff'] as GeoPoint;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickUp'),
        position: LatLng(pg.latitude, pg.longitude),
        infoWindow: InfoWindow(title: booking['passenger']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      Marker(
        markerId: const MarkerId('dropOff'),
        position: LatLng(dg.latitude, dg.longitude),
        infoWindow: const InfoWindow(title: 'Drop-off'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Booking', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition: CameraPosition(
              target: _currentLatLng ?? LatLng(pg.latitude, pg.longitude),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: markers,
            polylines: _polylines,
          ),

          // bottom info card
          Align(
            alignment: Alignment.bottomCenter,
            child: Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // passenger/status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(booking['passenger'], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(booking['status'], style: TextStyle(color: _statusColor(booking['status']), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // datetime
                    Row(
                      children: [
                        Icon(Icons.access_time, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM d, yyyy • h:mm a').format(booking['datetime'])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            print('Calling ${booking['phone']}');
                          },
                          icon: const Icon(Icons.phone),
                          label: Text(booking['phone']),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _completeRide,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Complete Ride'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
