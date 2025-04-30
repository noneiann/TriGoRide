// Modified RiderBookingsPage class with rating integration
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:tri_go_ride/ui/root_page_rider.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../services/auth_services.dart';
import '../passenger_side/rating_dialog.dart';

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

  // periodic update timer
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    // load your location and the booking in parallel
    await Future.wait([
      _fetchUserLocation(),
      _loadAcceptedBooking(),
    ]);

    if (_acceptedBooking != null) {
      await _getRoadPolylines();
      _startLocationUpdates(); // begin sending location updates
    }

    setState(() => _loading = false);
  }

  Future<void> _fetchUserLocation() async {
    try {
      if (!await _location.serviceEnabled()) {
        if (!await _location.requestService()) return;
      }
      if (await _location.hasPermission() == PermissionStatus.denied) {
        if (await _location.requestPermission() != PermissionStatus.granted)
          return;
      }
      final loc = await _location.getLocation();
      _currentLatLng = LatLng(loc.latitude!, loc.longitude!);
    } catch (e) {
      debugPrint('Error fetching user location: $e');
    }
  }

  Future<void> _loadAcceptedBooking() async {
    try {
      final uid = _authService.getUser()?.uid;
      final snap = await _authService.firestore
          .collection('bookings')
          .where('assignedRider', isEqualTo: uid)
          .where('status', isEqualTo: 'Accepted')
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        final d = doc.data();

        final String passengerName = d['passenger'] as String? ?? 'Unknown';
        final String passengerId = d['passengerId'] as String? ?? '';

        // Query users collection for this username
        String phoneNumber = 'N/A';
        final userQuery = await _authService.firestore
            .collection('users')
            .where('username', isEqualTo: passengerName)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          phoneNumber = userData['phone'] as String? ?? phoneNumber;
        }

        final GeoPoint? pickupGP = d['pickUp'] as GeoPoint?;
        final GeoPoint? dropoffGP = d['dropOff'] as GeoPoint?;
        final Timestamp? ts = d['dateBooked'] as Timestamp?;

        if (pickupGP != null && dropoffGP != null && ts != null) {
          _acceptedBooking = {
            'id': doc.id,
            'passenger': passengerName,
            'passengerId': passengerId,
            'phone': phoneNumber,
            'pickUp': pickupGP,
            'dropOff': dropoffGP,
            'datetime': ts.toDate(),
            'status': d['status'] as String? ?? 'N/A',
          };
        }
      }
    } catch (e) {
      debugPrint('Error loading booking: $e');
    }
  }

  void _startLocationUpdates() {
    // send every 3 seconds
    _locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
          await _sendCurrentLocation();
        });
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final loc = await _location.getLocation();
      if (loc.latitude != null &&
          loc.longitude != null &&
          _acceptedBooking != null) {
        await _authService.firestore
            .collection('bookings')
            .doc(_acceptedBooking!['id'])
            .update({
          'driverLocation': GeoPoint(loc.latitude!, loc.longitude!),
        });
      }
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  Future<void> _getRoadPolylines() async {
    if (_acceptedBooking == null) return;
    final GeoPoint p = _acceptedBooking!['pickUp'];
    final GeoPoint d = _acceptedBooking!['dropOff'];

    await dotenv.load(fileName: ".env");
    final apiKey = dotenv.get('GOOGLEMAPS_APIKEY');
    final polylinePoints = PolylinePoints();

    final result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: apiKey,
        request: PolylineRequest(
          origin: PointLatLng(p.latitude, p.longitude),
          destination: PointLatLng(d.latitude, d.longitude),
          mode: TravelMode.driving,
        ));

    if (result.points.isNotEmpty) {
      final route =
      result.points.map((pt) => LatLng(pt.latitude, pt.longitude)).toList();

      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: route,
        width: 5,
        color: Colors.blue,
      ));

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

  // Modified complete ride function to include rating
  void _completeRide() async {
    if (_acceptedBooking == null) return;

    try {
      // Stop location updates
      _locationUpdateTimer?.cancel();

      final uid = _authService.getUser()?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Update booking status
      await _authService.firestore
          .collection('bookings')
          .doc(_acceptedBooking!['id'])
          .update({
        'status': 'Completed',
        'active': false,
        'completedAt': Timestamp.now(),
      });

      // Show rating dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => EnhancedRatingDialog(
            driverId: uid,
            bookingId: _acceptedBooking!['id'],
            onRatingComplete: () {
              // Navigate back to root page after rating
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RootPageRider()),
              );
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing ride: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
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
          title: const Text('My Booking',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
        body: const Center(child: Text('You have no active bookings.')),
      );
    }

    final booking = _acceptedBooking!;
    final GeoPoint pg = booking['pickUp'];
    final GeoPoint dg = booking['dropOff'];

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
        title: const Text('My Booking',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
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
          Align(
            alignment: Alignment.bottomCenter,
            child: Card(
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(booking['passenger'],
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(booking['status'],
                            style: TextStyle(
                                color: _statusColor(booking['status']),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM d, yyyy • h:mm a')
                            .format(booking['datetime'])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final phone = booking['phone'] as String? ?? '';
                              final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');

                              if (cleanPhone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No phone number available')),
                                );
                                return;
                              }

                              final String urlString = 'tel:$cleanPhone';
                              await launchUrl(
                                Uri.parse(urlString),
                                mode: LaunchMode.externalApplication,
                              );
                            } catch (e) {
                              debugPrint('Phone call exception: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.phone),
                          label: Text(booking['phone'] ?? 'Call'),
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