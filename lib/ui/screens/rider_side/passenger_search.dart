import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_bookings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../services/auth_services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../../../services/noti_services.dart';
import 'package:http/http.dart' as http;

class PassengerSearchPage extends StatefulWidget {
  const PassengerSearchPage({super.key});

  @override
  State<PassengerSearchPage> createState() => _PassengerSearchPageState();
}

class _PassengerSearchPageState extends State<PassengerSearchPage> {
  String? _currentBookingId; // ← track ID
  Map<String, dynamic>? _currentBooking; // ← store the booking data
  final AuthService _auth = AuthService();
  final Location _locationSvc = Location();
  final DatabaseReference _realtimeDb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://trigoride-ee892-default-rtdb.asia-southeast1.firebasedatabase.app',
  ).ref();
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  Set<Polyline> _polylines = {};
  bool _isAvailable = false; // new
  Timer? _locationBroadcastTimer;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    // Don't auto-start as available - let driver toggle
    dotenv.load(fileName: ".env");
  }

  @override
  void dispose() {
    _setUnavailable();
    _locationBroadcastTimer?.cancel();
    super.dispose();
  }

  Future<void> _setAvailable() async {
    final email = _auth.getUser()!.email;

    print('🟢 Setting driver available: $email');

    // Ensure we have location before going available
    if (_currentLatLng == null) {
      print('📍 Fetching initial location...');
      await _fetchUserLocation();
    }

    if (_currentLatLng != null) {
      print(
          '✅ Location ready: ${_currentLatLng!.latitude}, ${_currentLatLng!.longitude}');
    } else {
      print('❌ Failed to get location');
    }

    await _auth.firestore.collection('users').doc(email).update({
      'status': 'available',
    });

    print('✅ Firestore status updated to available');

    // Start broadcasting location to Realtime Database
    _startLocationBroadcast();
  }

  void _startLocationBroadcast() {
    final uid = _auth.getUser()!.uid;

    print('🔥 Starting location broadcast for driver: $uid');

    // Broadcast location every 3 seconds to Realtime Database
    _locationBroadcastTimer =
        Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        // Get fresh location without triggering setState (no UI rebuild)
        final loc = await _locationSvc.getLocation();
        final currentLat = loc.latitude;
        final currentLng = loc.longitude;

        if (currentLat != null && currentLng != null) {
          // Update internal state without rebuilding UI
          _currentLatLng = LatLng(currentLat, currentLng);

          print('📍 Broadcasting location: $currentLat, $currentLng');

          // Update location in Realtime Database (much faster than Firestore)
          await _realtimeDb.child('driver_locations').child(uid).set({
            'uid': uid,
            'latitude': currentLat,
            'longitude': currentLng,
            'timestamp': ServerValue.timestamp,
            'status': 'available',
          });

          print('✅ Location broadcast successful');
        } else {
          print('⚠️ No current location to broadcast');
        }
      } catch (e) {
        print('❌ Error broadcasting location: $e');
      }
    });
  }

  Future<void> _setUnavailable() async {
    final email = _auth.getUser()!.email;
    final uid = _auth.getUser()!.uid;

    print('🔴 Setting driver unavailable: $email');

    _locationBroadcastTimer?.cancel();

    await _auth.firestore.collection('users').doc(email).update({
      'status': 'unavailable',
    });

    // Remove from Realtime Database
    try {
      await _realtimeDb.child('driver_locations').child(uid).remove();
      print('✅ Removed from Realtime Database');
    } catch (e) {
      print('❌ Error removing from Realtime Database: $e');
    }
  }

  Future<void> _fetchUserLocation() async {
    if (!await _locationSvc.serviceEnabled()) {
      if (!await _locationSvc.requestService()) return;
    }
    if (await _locationSvc.hasPermission() == PermissionStatus.denied) {
      if (await _locationSvc.requestPermission() != PermissionStatus.granted)
        return;
    }
    final loc = await _locationSvc.getLocation();
    setState(() => _currentLatLng = LatLng(loc.latitude!, loc.longitude!));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _pendingStream {
    var stream = _auth.firestore
        .collection('bookings')
        .where('status', isEqualTo: 'Pending')
        .orderBy('dateBooked', descending: true)
        .snapshots();
    print(stream);
    return stream;
  }

  void _getRoute(GeoPoint p, GeoPoint d) async {
    final apiKey = dotenv.get('GOOGLEMAPS_APIKEY');
    final pts = await PolylinePoints().getRouteBetweenCoordinates(
      googleApiKey: apiKey,
      request: PolylineRequest(
        origin: PointLatLng(p.latitude, p.longitude),
        destination: PointLatLng(d.latitude, d.longitude),
        mode: TravelMode.driving,
      ),
    );
    if (pts.points.isEmpty) return;
    final route =
        pts.points.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final bounds = _boundsFrom(route);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          width: 5,
          points: route,
          color: Colors.blue,
        )
      };
    });

    // Wait for map to be ready and then animate camera
    await Future.delayed(const Duration(milliseconds: 300));
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  LatLngBounds _boundsFrom(List<LatLng> pts) {
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );
  }

  Future<void> _acceptBooking(Map<String, dynamic> booking) async {
    final bid = booking['id'] as String;
    final rider = _auth.getUser()!;
    final paxName = booking['passenger'] as String;

    // Update booking status and assign rider
    await _auth.firestore.collection('bookings').doc(bid).update({
      'status': 'Accepted',
      'assignedRider': rider.uid,
    });

    // Local notification for rider
    await NotiService().showNotification(
      title: 'Booking Accepted',
      body: 'Head to pickup now!',
    );

    // 🔹 Get passenger document
    final userQuery = await _auth.firestore
        .collection('users')
        .where('username', isEqualTo: paxName)
        .get();

    if (userQuery.docs.isEmpty) {
      print('⚠️ No passenger found with name: $paxName');
    }

    final userDoc = userQuery.docs.first;
    final paxToken = userDoc.data()['fcmToken'] as String?;
    final paxPhone = userDoc.data()['phone'] as String?;
    final paxUsername = userDoc.data()['username'] as String? ?? 'Passenger';
    final paxEmail = userDoc.data()['email'] as String? ?? 'unknown_user';

    // 🔹 Get driver name
    final driverDoc =
        await _auth.firestore.collection('users').doc(rider.email).get();
    final driverName = driverDoc.data()?['username'] as String? ?? 'Driver';

    final pickupAddress =
        booking['pickUpAddress'] as String? ?? 'Your location';

    // 🔹 Send FCM notification to passenger
    if (paxToken?.isNotEmpty == true) {
      final sk = dotenv.get('FCM_SERVER_KEY');
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$sk',
        },
        body: jsonEncode({
          'to': paxToken,
          'notification': {
            'title': 'Driver on the way!',
            'body': 'Your ride has been accepted by $driverName.',
          },
        }),
      );
    }

    // 🔹 Send SMS notification to passenger
    if (paxPhone?.isNotEmpty == true) {
      await NotiService().sendBookingAcceptedSMS(
        passengerPhone: paxPhone!,
        passengerName: paxUsername,
        driverName: driverName,
        pickupLocation: pickupAddress,
      );
    }

    // 🔹 Log notifications in Firestore
    final now = Timestamp.now();
    final notifs = _auth.firestore.collection('notifs');
    await notifs.add({
      'userId': paxEmail,
      'type': 'booking_update',
      'message': 'Driver is on the way!',
      'timestamp': now,
      'read': false,
      'bookingId': bid,
    });
    await notifs.add({
      'userId': rider.email,
      'type': 'booking_update',
      'message': 'You accepted the booking.',
      'timestamp': now,
      'read': false,
      'bookingId': bid,
    });

    // 🔹 Navigate to rider bookings page
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RiderBookingsPage()),
      );
    }
  }

  void _declineBooking(Map<String, dynamic> booking) async {
    final uid = _auth.getUser()!.uid;
    final bid = booking['id'] as String;
    final declined =
        List<String>.from(booking['declined_riders'] as List? ?? [])..add(uid);

    await _auth.firestore.collection('bookings').doc(bid).update({
      'declined_riders': declined,
    });

    // Clear the current booking from UI so it disappears
    setState(() {
      _currentBooking = null;
      _currentBookingId = null;
      _polylines.clear();
    });

    print('✅ Booking declined, UI updated');
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    if (_currentLatLng == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingStream,
      builder: (ctx2, pendingSnap) {
        if (pendingSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = pendingSnap.data?.docs ?? [];
        final uid = _auth.getUser()!.uid;

// Separate bookings into special and regular
        final specialBookings = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final regularBookings = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (var d in docs) {
          final data = d.data();
          final declined = List<String>.from(data['declined_riders'] ?? []);
          if (declined.contains(uid)) continue;

          if (data['priorityType'] == 'special') {
            specialBookings.add(d);
          } else {
            regularBookings.add(d);
          }
        }

// Combine lists: special first
        final prioritizedBookings = [...specialBookings, ...regularBookings];

// Pick the first available booking
        String? newId;
        Map<String, dynamic>? newBooking;
        if (prioritizedBookings.isNotEmpty) {
          final b = prioritizedBookings.first;
          newId = b.id;
          newBooking = {
            'id': newId,
            ...b.data(),
            'declined_riders':
                List<String>.from(b.data()['declined_riders'] ?? []),
          };
        }
        if (newId != null && newId != _currentBookingId) {
          _currentBookingId = newId;
          _currentBooking = newBooking;

          _getRoute(
            _currentBooking!['pickUp'],
            _currentBooking!['dropOff'],
          );
        }

        if (_currentBooking == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Passenger Search')),
            body: Column(
              children: [
                // 1️⃣ Switch at top
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SwitchListTile(
                    title: Text(
                      _isAvailable
                          ? 'Online: Searching for passengers'
                          : 'Offline: Not available',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold), // center title text
                    ),
                    value: _isAvailable,
                    activeColor: Colors.green,
                    onChanged: (val) async {
                      setState(() => _isAvailable = val);
                      if (val) {
                        await _setAvailable();
                      } else {
                        await _setUnavailable();
                      }
                    },
                  ),
                ),

                // 2️⃣ Spacer to push icon/text to center
                const Expanded(child: SizedBox()),

                // 3️⃣ Status icon
                Icon(
                  _isAvailable ? Icons.search : Icons.pause_circle_filled,
                  size: 64,
                  color: _isAvailable ? Colors.green : Colors.grey,
                ),

                const SizedBox(height: 16),

                // 4️⃣ Centered status text
                Center(
                  child: Text(
                    _isAvailable
                        ? 'Waiting for riders to request a trip...'
                        : 'You are currently unavailable',
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ),

                // 5️⃣ Spacer to balance bottom
                const Expanded(child: SizedBox()),
              ],
            ),
          );
        }
        // Build the map + card UI (same as your original build)
        return Scaffold(
          appBar: AppBar(title: const Text('Passenger Search')),
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (c) {
                  _mapController = c;
                  // If polylines already exist, fit bounds
                  if (_polylines.isNotEmpty) {
                    final points = _polylines.first.points;
                    final bounds = _boundsFrom(points);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      c.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 100));
                    });
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng!,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: LatLng(
                      (_currentBooking?['pickUp'] as GeoPoint).latitude,
                      (_currentBooking?['pickUp'] as GeoPoint).longitude,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: LatLng(
                      (_currentBooking?['dropOff'] as GeoPoint).latitude,
                      (_currentBooking?['dropOff'] as GeoPoint).longitude,
                    ),
                  ),
                },
                polylines: _polylines,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Passenger name and priority badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Passenger: ${_currentBooking?['passenger']}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_currentBooking?['priorityType'] == 'special')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'SPECIAL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Pickup and Dropoff
                        _buildInfoRow(
                          Icons.location_on,
                          'Pickup',
                          _currentBooking?['pickUpAddress'] ?? 'N/A',
                          theme,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.flag,
                          'Drop-off',
                          _currentBooking?['dropOffAddress'] ?? 'N/A',
                          theme,
                        ),
                        const SizedBox(height: 8),

                        // Fare and Passenger Count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                Icons.people,
                                'Passengers',
                                '${_currentBooking?['passengerCount'] ?? 1}',
                                theme,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInfoRow(
                                Icons.payments,
                                'Fare',
                                '₱${(_currentBooking?['fare'] ?? 0).toStringAsFixed(2)}',
                                theme,
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _declineBooking(_currentBooking!),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Decline'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _acceptBooking(_currentBooking!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
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
      },
    );
  }
}
