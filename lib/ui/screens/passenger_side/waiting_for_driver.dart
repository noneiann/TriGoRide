import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/rating_dialog.dart';
import '../../root_page_passenger.dart';
import 'driver_info.dart';

class WaitingForDriverScreen extends StatefulWidget {
  final String bookingId;
  final LatLng pickUp, dropOff;

  const WaitingForDriverScreen({
    Key? key,
    required this.bookingId,
    required this.pickUp,
    required this.dropOff,
  }) : super(key: key);

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> {
  late final StreamSubscription<DocumentSnapshot> _bookingSub;
  late final AuthService _authService;
  late final Interpreter _interpreter;

  String? _status;
  String? _riderUid;
  LatLng? _driverLocation;
  Timer? _retryTimer;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _loadModel();
    // show initial loading
    setState(() {
      _status = 'Loading';
    });
    _startBookingSubscription();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/heuristic_model.tflite');
  }

  void _startBookingSubscription() {
    _bookingSub = _authService.firestore
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen(
      _onBookingUpdate,
      onError: (error) {
        debugPrint('Error in booking subscription: $error');
        _scheduleRetry();
      },
    );
  }

  void _scheduleRetry() {
    if (_retryCount >= 5) return;

    _retryTimer = Timer(Duration(seconds: 3 * (_retryCount + 1)), () {
      _retryCount++;
      if (mounted) {
        debugPrint('Retrying booking subscription (attempt $_retryCount)');
        _startBookingSubscription();
      }
    });
  }

  Future<void> _assignBestDriver() async {
    final driverDocs = await _authService.firestore
        .collection('users')
        .where('userType', isEqualTo: 'Driver')
        .where('status', isEqualTo: 'available')
        .get();
    if (driverDocs.docs.isEmpty) {
      await _authService.firestore
          .collection('bookings')
          .doc(widget.bookingId)
          .update({'status': 'Rejected'});
      return;
    }

    List<String> driverIds = [];
    List<double> ratings = [];
    List<double> distances = [];

    for (var doc in driverDocs.docs) {
      final driverId = doc.data()['uid'];
      final gp = doc.data()['location'] as GeoPoint;
      final driverLoc = LatLng(gp.latitude, gp.longitude);

      final ratingSnap = await _authService.firestore
          .collection('ratings')
          .where('driverId', isEqualTo: driverId)
          .get();
      final driverRatings = ratingSnap.docs
          .map((d) => (d.data()['rating'] as num).toDouble())
          .toList();
      final avgRating = driverRatings.isEmpty
          ? 3.0
          : driverRatings.reduce((a, b) => a + b) / driverRatings.length;

      final dist = Geolocator.distanceBetween(
        widget.pickUp.latitude,
        widget.pickUp.longitude,
        driverLoc.latitude,
        driverLoc.longitude,
      );

      driverIds.add(driverId);
      ratings.add(avgRating);
      distances.add(dist);
    }

    double minR = ratings.reduce(min);
    double maxR = ratings.reduce(max);
    double minD = distances.reduce(min);
    double maxD = distances.reduce(max);

    List<double> normR = ratings
        .map((r) => (r - minR) / (maxR - minR + 1e-6))
        .toList();
    List<double> normD = distances
        .map((d) => (d - minD) / (maxD - minD + 1e-6))
        .toList();

    double bestScore = -double.infinity;
    String? bestDriver;

    for (int i = 0; i < driverIds.length; i++) {
      final input = [normR[i], normD[i]].reshape([1, 2]);
      var output = List.filled(1, 0.0).reshape([1, 1]);
      _interpreter.run([input], output);
      final score = output[0][0];
      if (score > bestScore) {
        bestScore = score;
        bestDriver = driverIds[i];
      }
    }
    print('Best Driver: $bestDriver');
    if (bestDriver != null) {
      final declinedDrivers = driverIds.where((id) => id != bestDriver).toList();

      await _authService.firestore
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'assignedRider': bestDriver,
        'status': 'Pending',
        'acceptedAt': FieldValue.serverTimestamp(),
        'declined_riders': declinedDrivers,
      });
    }

  }

  void _onBookingUpdate(DocumentSnapshot snapshot) async {
    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking was deleted')),
      );
      _navigateToHome();
      return;
    }

    final data = snapshot.data() as Map<String, dynamic>;
    final newStatus = data['status'] as String?;
    bool stateChanged = newStatus != _status;
    _status = newStatus;

    if (_status == 'Pending') {
      await _assignBestDriver();
    }

    final newRiderUid = data['assignedRider'] as String?;
    if (newRiderUid != _riderUid) {
      _riderUid = newRiderUid;
      stateChanged = true;
    }

    final driverGP = data['driverLocation'] as GeoPoint?;
    if (driverGP != null) {
      final newLoc = LatLng(driverGP.latitude, driverGP.longitude);
      if (_driverLocation == null ||
          _driverLocation!.latitude != newLoc.latitude ||
          _driverLocation!.longitude != newLoc.longitude) {
        _driverLocation = newLoc;
        stateChanged = true;
      }
    }

    if (stateChanged && mounted) setState(() {});

    if (_status == 'Completed') {
      _checkAndShowRatingDialog(data);
    } else if (_status == 'Accepted' && _riderUid != null) {
      _navigateToDriverInfo();
    }
  }

  void _checkAndShowRatingDialog(Map<String, dynamic> bookingData) {
    final hasRating = bookingData.containsKey('rating');
    if (!hasRating && mounted && _riderUid != null) {
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => EnhancedRatingDialog(
            driverId: _riderUid!,
            bookingId: widget.bookingId,
            onRatingComplete: _navigateToHome,
          ),
        );
      });
    } else {
      _navigateToHome();
    }
  }

  void _navigateToDriverInfo() {
    if (_riderUid != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DriverInfoScreen(
            driverUid: _riderUid!,
            bookingId: widget.bookingId,
            pickUp: widget.pickUp,
            dropOff: widget.dropOff,
            initialDriverLocation: _driverLocation,
          ),
        ),
      );
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootPagePassenger()),
            (route) => false,
      );
    }
  }

  void _cancelRide() async {
    try {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Ride'),
          content: const Text('Are you sure you want to cancel this ride?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('NO'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('YES, CANCEL'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await _authService.firestore
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'Cancelled',
        'cancelledBy': 'passenger',
        'cancelledAt': Timestamp.now(),
        'active': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your ride has been cancelled')),
        );
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel ride: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _bookingSub.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _cancelRide();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finding Your Ride'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelRide,
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_status == 'Loading') ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              const Text('Connecting…', style: TextStyle(fontSize: 18)),
            ] else if (_status == 'Pending') ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              const Text('Finding a driver...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text('Please wait while we connect you with a nearby driver', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: _cancelRide,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size.fromHeight(50)),
                  child: const Text('CANCEL RIDE', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_status == 'Cancelled') ...[
              const Icon(Icons.cancel, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text('Your ride has been cancelled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: _navigateToHome,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('BACK TO HOME', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_status == 'Rejected') ...[
              const Icon(Icons.sentiment_dissatisfied, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text('No drivers available at the moment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text('Please try again in a few minutes', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: _navigateToHome,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('BACK TO HOME', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_status == 'Accepted' && _riderUid == null) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              const Text('Driver found! Loading details...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}
