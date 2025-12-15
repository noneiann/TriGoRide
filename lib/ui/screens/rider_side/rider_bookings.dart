// Modified RiderBookingsPage class with rating integration
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:tri_go_ride/ui/root_page_rider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../services/auth_services.dart';
import '../../../services/noti_services.dart';
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
  StreamSubscription<DocumentSnapshot>? _bookingStatusListener;

  // proximity tracking
  bool _hasShownProximityDialog = false;
  double? _lastDistance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _bookingStatusListener?.cancel();
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
      _listenToBookingStatus(); // monitor for cancellations
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

  void _listenToBookingStatus() {
    if (_acceptedBooking == null) return;

    final bookingId = _acceptedBooking!['id'] as String;
    _bookingStatusListener = _authService.firestore
        .collection('bookings')
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        _handleBookingCancellation('Booking no longer exists');
        return;
      }

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;

      // Check if booking was cancelled
      if (status == 'Cancelled') {
        final cancelledBy = data['cancelledBy'] as String? ?? 'passenger';
        _handleBookingCancellation(cancelledBy == 'passenger'
            ? 'Passenger cancelled the ride'
            : 'Ride was cancelled');
      }
    });
  }

  void _handleBookingCancellation(String message) {
    // Cancel timers
    _locationUpdateTimer?.cancel();
    _bookingStatusListener?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 32),
            SizedBox(width: 8),
            Text('Ride Cancelled'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RootPageRider()),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        final String pickUpAddress = d['pickUpAddress'] as String? ?? '';
        final String dropOffAddress = d['dropOffAddress'] as String? ?? '';
        final fare = d['fare'] ?? '';
        final int passengerCount = d['passengerCount'] as int? ?? 1;

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
            'pickUpAddress': pickUpAddress,
            'dropOff': dropoffGP,
            'dropOffAddress': dropOffAddress,
            'fare': fare,
            'passengerCount': passengerCount,
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
        _currentLatLng = LatLng(loc.latitude!, loc.longitude!);

        await _authService.firestore
            .collection('bookings')
            .doc(_acceptedBooking!['id'])
            .update({
          'driverLocation': GeoPoint(loc.latitude!, loc.longitude!),
        });

        // Check proximity to pickup location
        _checkProximityToPickup();
      }
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  void _checkProximityToPickup() {
    if (_hasShownProximityDialog) return;
    if (_currentLatLng == null || _acceptedBooking == null) return;

    final bookingStatus = _acceptedBooking!['status'] as String?;
    if (bookingStatus != 'Accepted') return;

    final pickupGP = _acceptedBooking!['pickUp'] as GeoPoint?;
    if (pickupGP == null) return;

    final distance = Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      pickupGP.latitude,
      pickupGP.longitude,
    );

    _lastDistance = distance;

    if (distance <= 100 && !_hasShownProximityDialog) {
      _hasShownProximityDialog = true;
      Future.microtask(() => _showStartRideDialog(distance));
    }
  }

  Future<void> _showStartRideDialog(double distance) async {
    if (!mounted) return;

    final passengerName =
        _acceptedBooking!['passenger'] as String? ?? 'Passenger';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.green, size: 32),
            SizedBox(width: 8),
            Text('Arrived at Pickup'),
          ],
        ),
        content: Text(
          'You are ${distance.toStringAsFixed(0)} meters from $passengerName\'s pickup location.\n\nReady to start the ride?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NOT YET'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('START RIDE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _startRide();
    } else {
      _hasShownProximityDialog = false;
    }
  }

  Future<void> _startRide() async {
    try {
      await _authService.firestore
          .collection('bookings')
          .doc(_acceptedBooking!['id'])
          .update({
        'status': 'In Progress',
        'rideStartedAt': Timestamp.now(),
      });

      // Update local booking data
      setState(() {
        _acceptedBooking!['status'] = 'In Progress';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride started! Have a safe trip.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error starting ride: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      _hasShownProximityDialog = false;
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

      // Wait for map to be ready and then animate camera
      await Future.delayed(const Duration(milliseconds: 300));
      if (_mapController != null) {
        // Include driver's current location in bounds
        final boundsPoints = [...route];
        if (_currentLatLng != null) {
          boundsPoints.add(_currentLatLng!);
        }
        final bounds = _calculateBounds(boundsPoints);
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
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

  // Modified complete ride function to include rating
  void _completeRide() async {
    if (_acceptedBooking == null) return;

    try {
      // Stop location updates
      _locationUpdateTimer?.cancel();

      print('✅ Booking data: $_acceptedBooking');

      final uid = _authService.getUser()?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Get booking details
      final bookingId = _acceptedBooking!['id'] as String;
      final passengerName = _acceptedBooking!['passenger'] as String;
      final fare = (_acceptedBooking!['fare'] as num?)?.toDouble() ?? 0.0;

      final pickupAddress =
          _acceptedBooking!['pickUpAddress'] as String? ?? 'Pickup location';
      final dropoffAddress =
          _acceptedBooking!['dropOffAddress'] as String? ?? 'Drop-off location';

      // 🔹 Find passenger document by username
      final passengerQuery = await _authService.firestore
          .collection('users')
          .where('username', isEqualTo: passengerName)
          .get();

      if (passengerQuery.docs.isEmpty) {
        debugPrint('⚠️ No passenger found with username: $passengerName');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Passenger not found: $passengerName')),
          );
        }
        return;
      }

      final passengerDoc = passengerQuery.docs.first;
      final passengerEmail =
          passengerDoc.data()['email'] as String? ?? 'unknown_user';
      final passengerToken = passengerDoc.data()['fcmToken'] as String? ?? '';
      final passengerPhone = passengerDoc.data()['phone'] as String? ?? '';

      // 🔹 Get driver details
      final driverDoc = await _authService.firestore
          .collection('users')
          .doc(_authService.getUser()?.email)
          .get();
      final driverName = driverDoc.data()?['username'] as String? ?? 'Driver';
      final driverEmail = driverDoc.data()?['email'] as String? ?? uid;

      // 🔹 Update booking status
      await _authService.firestore
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'Completed',
        'active': false,
        'completedAt': Timestamp.now(),
      });

      // 🔹 Send FCM notification to passenger
      if (passengerToken.isNotEmpty) {
        final sk = dotenv.get('FCM_SERVER_KEY');
        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$sk',
          },
          body: jsonEncode({
            'to': passengerToken,
            'notification': {
              'title': 'Ride Completed',
              'body':
                  'Thanks for riding with us, $passengerName! Your fare was ₱${fare.toStringAsFixed(2)}.',
            },
          }),
        );
      }

      // 🔹 Send email notification
      await NotiService().sendRideCompletionEmail(
        passengerEmail: passengerEmail,
        passengerName: passengerName,
        driverName: driverName,
        pickupLocation: pickupAddress,
        dropoffLocation: dropoffAddress,
        fare: fare,
        bookingId: bookingId,
      );

      // 🔹 Log notifications in Firestore
      final now = Timestamp.now();
      final notifs = _authService.firestore.collection('notifs');

      await notifs.add({
        'userId': passengerEmail,
        'type': 'ride_update',
        'message':
            'Your ride has been completed. Fare: ₱${fare.toStringAsFixed(2)}.',
        'timestamp': now,
        'read': false,
        'bookingId': bookingId,
      });

      await notifs.add({
        'userId': driverEmail,
        'type': 'ride_update',
        'message': 'You completed the ride for $passengerName.',
        'timestamp': now,
        'read': false,
        'bookingId': bookingId,
      });

      // 🔹 Navigate to root page
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RootPageRider()),
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
            onMapCreated: (c) {
              _mapController = c;
              // If polylines already exist, fit bounds
              if (_polylines.isNotEmpty) {
                final points = _polylines.first.points.toList();
                // Include driver's current location in bounds
                if (_currentLatLng != null) {
                  points.add(_currentLatLng!);
                }
                final bounds = _calculateBounds(points);
                Future.delayed(const Duration(milliseconds: 300), () {
                  c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
                });
              }
            },
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
                    // Passenger name and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(booking['passenger'],
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(booking['status'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            booking['status'],
                            style: TextStyle(
                                color: _statusColor(booking['status']),
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Date and time
                    _buildInfoRow(
                      Icons.access_time,
                      'Date & Time',
                      DateFormat('MMM d, yyyy • h:mm a')
                          .format(booking['datetime']),
                      theme,
                    ),
                    const SizedBox(height: 8),

                    // Pickup location
                    _buildInfoRow(
                      Icons.location_on,
                      'Pickup',
                      booking['pickUpAddress'] ?? 'N/A',
                      theme,
                    ),
                    const SizedBox(height: 8),

                    // Dropoff location
                    _buildInfoRow(
                      Icons.flag,
                      'Dropoff',
                      booking['dropOffAddress'] ?? 'N/A',
                      theme,
                    ),
                    const SizedBox(height: 8),

                    // Passenger count and fare
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildInfoRow(
                            Icons.people,
                            'Passengers',
                            '${booking['passengerCount'] ?? 1}',
                            theme,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInfoRow(
                            Icons.payments,
                            'Fare',
                            '₱${(booking['fare'] ?? 0).toStringAsFixed(2)}',
                            theme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Distance indicator
                    if (_lastDistance != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _lastDistance! <= 100
                                ? Colors.green.withOpacity(0.1)
                                : theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _lastDistance! <= 100
                                  ? Colors.green
                                  : theme.primaryColor,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _lastDistance! <= 100
                                    ? Icons.location_on
                                    : Icons.directions_car,
                                color: _lastDistance! <= 100
                                    ? Colors.green
                                    : theme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _lastDistance! < 1000
                                    ? '${_lastDistance!.toStringAsFixed(0)}m from pickup'
                                    : '${(_lastDistance! / 1000).toStringAsFixed(1)}km from pickup',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _lastDistance! <= 100
                                      ? Colors.green
                                      : theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final phone = booking['phone'] as String? ?? '';
                              final cleanPhone =
                                  phone.replaceAll(RegExp(r'\s+'), '');

                              if (cleanPhone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('No phone number available')),
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
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text('Call'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _completeRide,
                          icon:
                              const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Complete'),
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
