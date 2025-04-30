import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/services/noti_services.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/waiting_for_driver.dart';
import '../../location_picker_screen.dart';

/// Helper: fetch nearest place (name, vicinity) via Google Places Nearby Search
Future<String?> getNearestPlace(double lat, double lng) async {
  await dotenv.load(fileName: ".env");
  final key = dotenv.get('GOOGLEMAPS_APIKEY');
  if (key == null) {
    debugPrint('❌ GOOGLE_MAPS_APIKEY missing');
    return null;
  }

  // Build URL
  final params = {
    'key'     : key,
    'location': '$lat,$lng',
    'rankby'  : 'distance',
    'type'    : 'establishment',
  };
  final url = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/nearbysearch/json',
    params,
  );

  debugPrint('🔗 Nearby Search URL:\n  $url');

  // Fire the request
  final res = await http.get(url);
  debugPrint('📥 HTTP ${res.statusCode}');

  // Log the first 1000 chars of the body so you can inspect status & results
  final bodySnippet = res.body.length > 1000
      ? res.body.substring(0, 1000) + '…'
      : res.body;
  debugPrint('📝 Body:\n$bodySnippet');

  if (res.statusCode != 200) {
    debugPrint('❌ Non-200 HTTP status, aborting.');
    return null;
  }

  final Map<String, dynamic> data = jsonDecode(res.body);
  final status = data['status'] as String? ?? 'NO_STATUS';
  debugPrint('🔍 API status: $status');
  if (status != 'OK') {
    debugPrint('⚠️ error_message: ${data['error_message']}');
    return null;
  }

  final results = data['results'] as List<dynamic>? ?? [];
  debugPrint('✅ ${results.length} results returned');

  if (results.isEmpty) return null;

  // Log each name/vicinity for clarity
  for (var i = 0; i < results.length; i++) {
    final poi = results[i] as Map<String, dynamic>;
    debugPrint('  [$i] ${poi['name']} ');
  }

  final first = results[2] as Map<String, dynamic>;
  final name     = first['name']     as String?;
  final vicinity = first['vicinity'] as String?;
  if (name != null && vicinity != null) {
    final primary = name.split(',').first.trim();
    return primary;
  }
  return name;
}

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({Key? key}) : super(key: key);

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final AuthService _authService = AuthService();
  late final CollectionReference _bookings;
  late final CollectionReference _notifs;
  LatLng? _pickUp;
  LatLng? _dropOff;
  String? _pickUpAddress;
  String? _dropOffAddress;
  String? _passenger;

  @override
  void initState() {
    super.initState();
    _bookings = _authService.firestore.collection('bookings');
    _notifs = _authService.firestore.collection('notifs');
    _loadPassengerAndCheckActive();
  }

  Future<void> _loadPassengerAndCheckActive() async {
    final email = _authService.getUser()?.email;
    if (email == null) return;
    final userDoc = await _authService.firestore.collection('users').doc(email).get();
    _passenger = (userDoc.data() as Map<String, dynamic>)['username'] as String?;
    await _checkActiveBooking();
  }

  Future<void> _checkActiveBooking() async {
    if (_passenger == null) return;
    final snap = await _bookings
        .where('passenger', isEqualTo: _passenger)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return;
    final data = snap.docs.first.data() as Map<String, dynamic>;
    final pu   = data['pickUp']  as GeoPoint;
    final doff = data['dropOff'] as GeoPoint;
    Navigator.pushReplacement(context,
      MaterialPageRoute(
        builder: (_) => WaitingForDriverScreen(
          bookingId: snap.docs.first.id,
          pickUp:  LatLng(pu.latitude, pu.longitude),
          dropOff: LatLng(doff.latitude, doff.longitude),
        ),
      ),
    );
  }

  double _toRad(double deg) => deg * pi / 180;

  double _calcKm(LatLng a, LatLng b) {
    const R = 6371; // km
    final dLat = _toRad(b.latitude  - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = sin(dLat/2)*sin(dLat/2)
        + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2);
    return 2 * R * atan2(sqrt(h), sqrt(1 - h));
  }

  double get _distanceKm =>
      (_pickUp != null && _dropOff != null)
          ? _calcKm(_pickUp!, _dropOff!)
          : 0.0;

  double get _estimatedFare {
    final raw = (_distanceKm / 2) * 15;
    final fare = raw < 15 ? 15 : raw;
    return double.parse(fare.toStringAsFixed(2));
  }

  Future<void> _selectLocation(bool isPickup) async {
    final LatLng? chosen = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen()),
    );
    if (chosen == null) return;
    setState(() {
      if (isPickup) {
        _pickUp = chosen;
        _pickUpAddress = 'Loading…';
      } else {
        _dropOff = chosen;
        _dropOffAddress = 'Loading…';
      }
    });

    try {
      final addr = await getNearestPlace(chosen.latitude, chosen.longitude);
      setState(() {
        if (isPickup) _pickUpAddress = addr ?? '${chosen.latitude.toStringAsFixed(4)}, ${chosen.longitude.toStringAsFixed(4)}';
        else           _dropOffAddress = addr ?? '${chosen.latitude.toStringAsFixed(4)}, ${chosen.longitude.toStringAsFixed(4)}';
      });
    } catch (_) {
      setState(() {
        if (isPickup) _pickUpAddress = '${chosen.latitude.toStringAsFixed(4)}, ${chosen.longitude.toStringAsFixed(4)}';
        else           _dropOffAddress = '${chosen.latitude.toStringAsFixed(4)}, ${chosen.longitude.toStringAsFixed(4)}';
      });
    }
  }

  Future<void> _bookRide() async {
    final pu  = _pickUp!;
    final dof = _dropOff!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Text(
            'From:  ${_pickUpAddress}\n'
                'To:    ${_dropOffAddress}\n\n'
                'Distance: ${_distanceKm.toStringAsFixed(2)} km\n'
                'Fare: ₱${_estimatedFare.toStringAsFixed(2)}'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context,true), child: const Text('Book')),
        ],
      ),
    );
    if (ok != true) return;

    final docRef = await _bookings.add({
      'dateBooked'     : Timestamp.now(),
      'passenger'      : _passenger,
      'status'         : 'Pending',
      'active'         : true,
      'pickUp'         : GeoPoint(pu.latitude, pu.longitude),
      'pickUpAddress'  : _pickUpAddress,
      'dropOff'        : GeoPoint(dof.latitude, dof.longitude),
      'dropOffAddress' : _dropOffAddress,
      'fare'           : _estimatedFare,
    });

    // Get current user
    final user = _authService.getUser();
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Add notification
    await _notifs.add({
      'userId': user.email!,
      'type': 'booking',
      'message': 'Ride booked successfully. Waiting for driver.',
      'timestamp': Timestamp.now(),
      'read': false,
      'bookingId': docRef.id,
    });
    await NotiService().showNotification(
      title: 'Ride Booked!',
      body: 'Driver is being assigned. Estimated fare: ₱${_estimatedFare.toStringAsFixed(2)}',
    );
    Navigator.pushReplacement(context,
      MaterialPageRoute(
        builder: (_) => WaitingForDriverScreen(
          bookingId: docRef.id,
          pickUp:  pu,
          dropOff: dof,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showMap = _pickUp != null && _dropOff != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Ride'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Map Preview
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                height: 200,
                child: showMap
                    ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (_pickUp!.latitude  + _dropOff!.latitude )/2,
                      (_pickUp!.longitude + _dropOff!.longitude)/2,
                    ),
                    zoom: 13,
                  ),
                  markers: {
                    Marker(markerId: const MarkerId('pu'), position: _pickUp!),
                    Marker(markerId: const MarkerId('do'), position: _dropOff!),
                  },
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                )
                    : Center(child: Text('Map preview', style: theme.textTheme.bodyMedium)),
              ),
            ),

            const SizedBox(height: 24),

            // Location selectors
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_pin),
                    title: const Text('Pickup location'),
                    subtitle: _pickUpAddress != null
                        ? Text(_pickUpAddress!)
                        : const Text('Tap to select'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectLocation(true),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.flag),
                    title: const Text('Drop-off location'),
                    subtitle: _dropOffAddress != null
                        ? Text(_dropOffAddress!)
                        : const Text('Tap to select'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectLocation(false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Summary card
            if (showMap)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: theme.colorScheme.primary.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.directions, color: theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Distance: ${_distanceKm.toStringAsFixed(2)} km\n'
                              'Fare: ₱${_estimatedFare.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: showMap ? _bookRide : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Book Ride', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
