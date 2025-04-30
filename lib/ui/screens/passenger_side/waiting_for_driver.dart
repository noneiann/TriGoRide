import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/rating_dialog.dart';

import '../../root_page_passenger.dart';
import 'driver_info.dart'; // Import your existing RatingDialog

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
  String? _status;
  String? _riderUid;
  LatLng? _driverLocation;
  Timer? _retryTimer;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _startBookingSubscription();
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
    if (_retryCount >= 5) return; // give up after 5 retries

    _retryTimer = Timer(Duration(seconds: 3 * (_retryCount + 1)), () {
      _retryCount++;
      if (mounted) {
        debugPrint('Retrying booking subscription (attempt $_retryCount)');
        _startBookingSubscription();
      }
    });
  }

  void _onBookingUpdate(DocumentSnapshot snapshot) {
    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking was deleted')),
      );
      _navigateToHome();
      return;
    }

    final data = snapshot.data() as Map<String, dynamic>;
    final newStatus = data['status'] as String?;
    final newRiderUid = data['assignedRider'] as String?;
    final driverGP = data['driverLocation'] as GeoPoint?;

    bool stateChanged = false;

    if (newStatus != _status) {
      _status = newStatus;
      stateChanged = true;
    }

    if (newRiderUid != _riderUid) {
      _riderUid = newRiderUid;
      stateChanged = true;
    }

    if (driverGP != null) {
      final newDriverLoc = LatLng(driverGP.latitude, driverGP.longitude);
      if (_driverLocation == null ||
          _driverLocation!.latitude != newDriverLoc.latitude ||
          _driverLocation!.longitude != newDriverLoc.longitude) {
        _driverLocation = newDriverLoc;
        stateChanged = true;
      }
    }

    // Check for "Completed" status to show rating dialog
    if (_status == 'Completed') {
      _checkAndShowRatingDialog(data);
    } else if (_status == 'Accepted' && _riderUid != null) {
      _navigateToDriverInfo();
    }

    if (stateChanged && mounted) {
      setState(() {});
    }
  }

  void _checkAndShowRatingDialog(Map<String, dynamic> bookingData) {
    // Check if this booking has already been rated
    final bool hasRating = bookingData.containsKey('rating');

    if (!hasRating && mounted && _riderUid != null) {
      // Use your existing RatingDialog widget
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => EnhancedRatingDialog(
            driverId: _riderUid!,
            bookingId: widget.bookingId,
            onRatingComplete: _navigateToHome,
          ),
        );
      });
    } else {
      // Booking already has rating or missing driver ID, just go back to home
      _navigateToHome();
    }
  }

  void _navigateToDriverInfo() {
    if (_riderUid != null && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => DriverInfoScreen(
          driverId: _riderUid!,
          bookingId: widget.bookingId,
          pickUp: widget.pickUp,
          dropOff: widget.dropOff,
          driverLocation: _driverLocation, riderUid: '',
        ),
      ));
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RootPagePassenger()),
            (route) => false,
      );
    }
  }

  void _cancelRide() async {
    try {
      // Show confirmation dialog
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

      // Update booking status to cancelled
      await _authService.firestore
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status': 'Cancelled',
        'cancelledBy': 'passenger',
        'cancelledAt': Timestamp.now(),
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
        // Prevent back button from closing screen directly
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
            if (_status == 'Pending') ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Finding a driver...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Please wait while we connect you with a nearby driver',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: _cancelRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('CANCEL RIDE', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_status == 'Cancelled') ...[
              const Icon(
                Icons.cancel,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Your ride has been cancelled',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: _navigateToHome,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('BACK TO HOME', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_status == 'Rejected') ...[
              const Icon(
                Icons.sentiment_dissatisfied,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 20),
              const Text(
                'No drivers available at the moment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Please try again in a few minutes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton(
                  onPressed: _navigateToHome,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('BACK TO HOME', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else if (_status == 'Accepted' && _riderUid == null) ...[
              // Transitional state - driver accepted but details not loaded yet
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Driver found! Loading details...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}