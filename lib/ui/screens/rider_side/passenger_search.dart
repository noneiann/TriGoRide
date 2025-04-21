import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_bookings.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/auth_services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
class PassengerSearchPage extends StatefulWidget {
  const PassengerSearchPage({super.key});

  @override
  State<PassengerSearchPage> createState() => _PassengerSearchPageState();
}

class _PassengerSearchPageState extends State<PassengerSearchPage> {
  final AuthService _authService = AuthService();
  GoogleMapController? _mapController;

  LatLng? _currentLatLng;
  final Location _location = Location();
  bool _loading = true;

  /// Single most recent booking
  Map<String, dynamic>? _currentBooking;

  /// Map polylines
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _checkForActiveBooking();
  }

  Future<void> _checkForActiveBooking() async {
    final uid = _authService.getUser().uid;
    final snap = await _authService.firestore
        .collection('bookings')
        .where('assignedRider', isEqualTo: uid)
        .where('status', isEqualTo: 'Accepted')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      // you already have an active booking → go show it
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RiderBookingsPage()),
      );
    } else {
      // no active booking → proceed to search flow
      _initialize();
    }
  }
  Future<void> _initialize() async {

    await Future.wait([
      _fetchUserLocation(),
      _fetchMostRecentBooking(),
    ]);
    if (_currentBooking != null) {
      _getRoadPolylines();
    } else {
      debugPrint('No pending bookings found');
    }
    setState(() => _loading = false);
  }
  Future<void> _getRoadPolylines() async {
    if (_currentBooking == null) return;
    final GeoPoint p = _currentBooking!['pickUp'] as GeoPoint;
    final GeoPoint d = _currentBooking!['dropOff'] as GeoPoint;

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
      final List<LatLng> route = result.points
          .map((pt) => LatLng(pt.latitude, pt.longitude))
          .toList();

      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: route,
        ));
      });

      // Animate camera to fit the route
      if (_mapController != null) {
        LatLngBounds bounds = _getLatLngBounds(route);
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    } else {
      debugPrint('Directions API returned no points: ${result.errorMessage}');
    }
  }

  LatLngBounds _getLatLngBounds(List<LatLng> points) {
    final southwestLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final southwestLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final northeastLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final northeastLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    return LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }
      final userLocation = await _location.getLocation();
      _currentLatLng = LatLng(userLocation.latitude!, userLocation.longitude!);
    } catch (e) {
      debugPrint('Error fetching user location: $e');
    }
  }

  Future<void> _fetchMostRecentBooking() async {
    final currentRider = _authService.getUser().uid;
    try {
      final snapshot = await _authService.firestore
          .collection('bookings')
          .where('status', isEqualTo: 'Pending')
          .orderBy('dateBooked', descending: true)
          .get();

      debugPrint('Total pending bookings: ${snapshot.docs.length}');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final declinedRiders = List<String>.from(data['declined_riders'] ?? []);

        if (!declinedRiders.contains(currentRider)) {
          debugPrint('Found booking not declined by current rider: ${doc.id}');
          _currentBooking = {
            'id': doc.id,
            'passenger': data['passenger'] as String? ?? 'Unknown',
            'phone': data['phone'] as String? ?? 'N/A',
            'pickUp': data['pickUp'] as GeoPoint,
            'dropOff': data['dropOff'] as GeoPoint,
            'declined_riders': declinedRiders,
          };
          break;
        }
      }

      if (_currentBooking == null) {
        debugPrint('No suitable booking found for current rider.');
      }
    } catch (e) {
      debugPrint('Error fetching booking: $e');
    }
  }



  void _acceptBooking() async {
    if (_currentBooking == null) return;
    try {
      final currentRider = _authService.getUser().uid;
      await _authService.firestore
          .collection('bookings')
          .doc(_currentBooking!['id'])
          .update({
        'status': 'Accepted',
        'assignedRider': currentRider,
      });
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (BuildContext context) => RiderBookingsPage()));
    } catch (e) {
      debugPrint('Error accepting: $e');
    }
  }


  void _declineBooking() async {
    if (_currentBooking == null) return;
    try {
      _currentBooking?['declined_riders'].add(_authService.getUser().uid);
      await _authService.firestore.collection('bookings').doc(_currentBooking!['id']).update(
          _currentBooking as Map<Object, Object?>);
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (BuildContext context) => super.widget));
    } catch (e) {
      debugPrint('Error declining: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading || _currentLatLng == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Passenger Search', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If still no booking, show message
    if (_currentBooking == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Passenger Search', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: const Center(child: Text('No pending bookings at the moment.')),
      );
    }

    // Build markers and polylines for the current booking
    final Set<Marker> markers = {};
    final GeoPoint pg = _currentBooking!['pickUp'] as GeoPoint;
    markers.add(Marker(
      markerId: const MarkerId('pickUp'),
      position: LatLng(pg.latitude, pg.longitude),
      infoWindow: InfoWindow(title: _currentBooking!['passenger']),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    ));
    final GeoPoint dg = _currentBooking!['dropOff'] as GeoPoint;
    markers.add(Marker(
      markerId: const MarkerId('dropOff'),
      position: LatLng(dg.latitude, dg.longitude),
      infoWindow: const InfoWindow(title: 'Drop-off'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passenger Search', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderNotificationsPage())),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(target: _currentLatLng!, zoom: 16),
            markers: markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Passenger: ${_currentBooking!['passenger']}', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('Phone: ${_currentBooking!['phone']}', style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _declineBooking,
                          child: const Text('Decline'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _acceptBooking,
                          child: const Text('Accept'),
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
