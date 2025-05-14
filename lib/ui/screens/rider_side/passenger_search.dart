import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final AuthService _auth = AuthService();
  final Location _locationSvc = Location();
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  Set<Polyline> _polylines = {};
  bool _isAvailable = false;   // new

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    _setAvailable();
    dotenv.load(fileName: ".env");
  }

  @override
  void dispose() {
    _setUnavailable();
    super.dispose();
  }



  Future<void> _setAvailable() async {
    final email = _auth.getUser()!.email;
    await _auth.firestore.collection('users').doc(email).update({
      'status': 'available',
    });
  }

  Future<void> _setUnavailable() async {
    final email = _auth.getUser()!.email;
    await _auth.firestore.collection('users').doc(email).update({
      'status': 'unavailable',
    });
  }

  Future<void> _fetchUserLocation() async {
    if (!await _locationSvc.serviceEnabled()) {
      if (!await _locationSvc.requestService()) return;
    }
    if (await _locationSvc.hasPermission() == PermissionStatus.denied) {
      if (await _locationSvc.requestPermission() != PermissionStatus.granted) return;
    }
    final loc = await _locationSvc.getLocation();
    setState(() => _currentLatLng = LatLng(loc.latitude!, loc.longitude!));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _acceptedStream {
    final uid = _auth.getUser()!.uid;
    return _auth.firestore
        .collection('bookings')
        .where('assignedRider', isEqualTo: uid)
        .where('status', isEqualTo: 'Accepted')
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _pendingStream {
    return _auth.firestore
        .collection('bookings')
        .where('status', isEqualTo: 'Pending')
        .orderBy('dateBooked', descending: true)
        .snapshots();
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
    final route = pts.points.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final bounds = _boundsFrom(route);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          width: 5,
          points: route,
        )
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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
    final paxEmail = booking['passenger'] as String;

    await _auth.firestore.collection('bookings').doc(bid).update({
      'status': 'Accepted',
      'assignedRider': rider.uid,
    });
    await NotiService().showNotification(
      title: 'Booking Accepted',
      body: 'Head to pickup now!',
    );

    // send FCM to passenger
    final userDoc = await _auth.firestore.collection('users').doc(paxEmail).get();
    final paxToken = userDoc.data()?['fcmToken'] as String?;
    if (paxToken?.isNotEmpty == true) {
      final sk = dotenv.get('FCM_SERVER_KEY');
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$sk'
        },
        body: jsonEncode({
          'to': paxToken,
          'notification': {
            'title': 'Driver on the way!',
            'body': 'Your ride has been accepted.',
          },
        }),
      );
    }

    // log notifications
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RiderBookingsPage()),
    );
  }

  void _declineBooking(Map<String, dynamic> booking) async {
    final uid = _auth.getUser()!.uid;
    final bid = booking['id'] as String;
    final declined = List<String>.from(booking['declined_riders'] as List? ?? [])
      ..add(uid);
    await _auth.firestore.collection('bookings').doc(bid).update({
      'declined_riders': declined,
    });
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
      stream: _acceptedStream,
      builder: (ctx, acceptSnap) {
        // 1️⃣ If there's an accepted booking, jump to RiderBookingsPage.
        if (acceptSnap.hasData && acceptSnap.data!.docs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const RiderBookingsPage()),
            );
          });
          return const SizedBox.shrink();
        }

        // 2️⃣ Otherwise listen for pending bookings
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _pendingStream,
          builder: (ctx2, pendingSnap) {
            if (pendingSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = pendingSnap.data?.docs ?? [];
            // find first not declined
            Map<String, dynamic>? booking;
            final uid = _auth.getUser()!.uid;
            for (var d in docs) {
              final data = d.data();
              final declined = List<String>.from(data['declined_riders'] ?? []);
              if (!declined.contains(uid)) {
                booking = {
                  'id': d.id,
                  ...data,
                  'declined_riders': declined,
                };
                break;
              }
            }

            if (booking == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Passenger Search')),
                body: Column(
                  children: [
                    // 1️⃣ Switch at top
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SwitchListTile(
                        title: Text(
                          _isAvailable
                              ? 'Online: Searching for passengers'
                              : 'Offline: Not available',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // center title text
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

            // Once we have a booking, draw route
            _getRoute(booking['pickUp'], booking['dropOff']);

            // Build the map + card UI (same as your original build)
            return Scaffold(
              appBar: AppBar(title: const Text('Passenger Search')),
              body: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (c) => _mapController = c,
                    initialCameraPosition: CameraPosition(
                      target: _currentLatLng!,
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(
                          (booking['pickUp'] as GeoPoint).latitude,
                          (booking['pickUp'] as GeoPoint).longitude,
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: LatLng(
                          (booking['dropOff'] as GeoPoint).latitude,
                          (booking['dropOff'] as GeoPoint).longitude,
                        ),
                      ),
                    },
                    polylines: _polylines,
                  ),
                  // ... your bottom booking card, with buttons calling
                  // _acceptBooking(booking) and _declineBooking(booking)
                ],
              ),
            );
          },
        );
      },
    );
  }
}
