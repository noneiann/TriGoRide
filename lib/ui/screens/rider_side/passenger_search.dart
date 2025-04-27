import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_bookings.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/auth_services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../../services/noti_services.dart';

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

  Map<String, dynamic>? _currentBooking;
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _checkForActiveBooking();
  }

  Future<void> _checkForActiveBooking() async {
    final uid = _authService.getUser()?.uid;
    final snap = await _authService.firestore
        .collection('bookings')
        .where('assignedRider', isEqualTo: uid)
        .where('status', isEqualTo: 'Accepted')
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RiderBookingsPage()),
      );
    } else {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    await Future.wait([_fetchUserLocation(), _fetchMostRecentBooking()]);
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
      googleApiKey: apiKey,
      request: PolylineRequest(
        origin: PointLatLng(p.latitude, p.longitude),
        destination: PointLatLng(d.latitude, d.longitude),
        mode: TravelMode.driving,
      ),
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
    final currentRider = _authService.getUser()?.uid;
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
            'pickUp': data['pickUp'],
            'dropOff': data['dropOff'],
            'pickUpAddress': data['pickUpAddress'],
            'dropOffAddress': data['dropOffAddress'],
            'declined_riders': declinedRiders,
            'dateBooked': data['dateBooked'] as Timestamp,
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

  Future<void> _acceptBooking() async {
    if (_currentBooking == null) return;
    final bookingId = _currentBooking!['id'] as String;
    final rider = _authService.getUser();
    final riderEmail = rider?.email;

    // 1️⃣ Update booking in Firestore
    await _authService.firestore
        .collection('bookings')
        .doc(bookingId)
        .update({
      'status': 'Accepted',
      'assignedRider': rider?.uid,
    });

    // 2️⃣ Rider: show a local notification immediately
    await NotiService().showNotification(
      title: 'Booking Accepted',
      body: 'You accepted the ride. Head to pickup now!',
    );

    // 3️⃣ Passenger: fetch their FCM token
    final passengerEmail = _currentBooking!['passenger'] as String;
    final userDoc = await _authService.firestore
        .collection('users')
        .doc(passengerEmail)
        .get();
    final passengerToken = userDoc.data()?['fcmToken'] as String?;

    // 4️⃣ If token exists, send an FCM push
    if (passengerToken != null && passengerToken.isNotEmpty) {
      await dotenv.load(fileName: '.env');
      final serverKey = dotenv.get('FCM_SERVER_KEY');
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': passengerToken,
          'notification': {
            'title': 'Driver on the Way!',
            'body': 'Your driver has accepted and is en route. 🚗',
            'sound': 'default',
          },
          'data': {
            'bookingId': bookingId,
            'type': 'booking_update',
          },
        }),
      );
    }

    // 5️⃣ Also log both notifs in your `notifs` collection
    final notifs = _authService.firestore.collection('notifs');
    final now = Timestamp.now();
    // Passenger entry
    await notifs.add({
      'userId': passengerEmail,
      'type': 'booking_update',
      'message': 'Your driver is on the way!',
      'timestamp': now,
      'read': false,
      'bookingId': bookingId,
    });
    // Rider entry
    if (riderEmail != null) {
      await notifs.add({
        'userId': riderEmail,
        'type': 'booking_update',
        'message': 'You accepted the ride. Proceed to pickup!',
        'timestamp': now,
        'read': false,
        'bookingId': bookingId,
      });
    }

    // 6️⃣ Navigate into your bookings screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RiderBookingsPage()),
    );
  }


  void _declineBooking() async {
    if (_currentBooking == null) return;
    try {
      _currentBooking?['declined_riders'].add(_authService.getUser()?.uid);
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
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Full-screen map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: markers,
            polylines: _polylines,
            initialCameraPosition: CameraPosition(
              target: _currentLatLng!,
              zoom: 14,
            ),
            padding: const EdgeInsets.only(bottom: 220), // Add padding to avoid markers being hidden by card
          ),

          // Booking card positioned at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle for dragging
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Passenger info with avatar
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                          radius: 24,
                          child: Icon(Icons.person, color: theme.colorScheme.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentBooking!['passenger'],
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentBooking!['phone'],
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Trip details
                    _buildInfoRow(
                      context,
                      Icons.access_time,
                      'Booking Time',
                      _formatDateTime(_currentBooking!['dateBooked'] as Timestamp),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.location_on,
                      'Pickup Location',
                      _currentBooking!['pickUpAddress'],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.location_off,
                      'Dropoff Location',
                      _currentBooking!['dropOffAddress'],
                    ),

                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _acceptBooking,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _declineBooking,
                            icon: const Icon(Icons.cancel),
                            label: const Text('Decline'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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

// Helper method to format Timestamp to readable date and time
String _formatDateTime(Timestamp timestamp) {
  final DateTime dateTime = timestamp.toDate();
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}

// Helper method to build info rows with icons
Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
  final theme = Theme.of(context);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: theme.colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}