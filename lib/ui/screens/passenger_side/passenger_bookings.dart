import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/driver_info.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/waiting_for_driver.dart';

class PassengerBookingsScreen extends StatefulWidget {
  const PassengerBookingsScreen({Key? key}) : super(key: key);

  @override
  State<PassengerBookingsScreen> createState() => _PassengerBookingsScreenState();
}

class _PassengerBookingsScreenState extends State<PassengerBookingsScreen> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _activeBookings = [];

  @override
  void initState() {
    super.initState();
    _loadActiveBookings();
  }

  Future<void> _loadActiveBookings() async {
    setState(() => _loading = true);

    final user = _authService.getUser();
    if (user?.email == null) {
      setState(() => _loading = false);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.email)
        .get();
    final passengerName = userDoc.data()?['username'] as String?;
    if (passengerName == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // Get active bookings (Pending, Accepted, In Progress)
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passenger', isEqualTo: passengerName)
          .where('active', isEqualTo: true)
          .get();

      final bookings = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        bookings.add(data);
      }

      // Sort by date (most recent first)
      bookings.sort((a, b) {
        final aDate = (a['dateBooked'] as Timestamp).toDate();
        final bDate = (b['dateBooked'] as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });

      setState(() {
        _activeBookings = bookings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      setState(() => _loading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in progress':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.check_circle;
      case 'in progress':
        return Icons.directions_car;
      default:
        return Icons.info;
    }
  }

  void _navigateToBooking(Map<String, dynamic> booking) {
    final status = booking['status'] as String?;
    final bookingId = booking['id'] as String;
    final pickUpGP = booking['pickUp'] as GeoPoint?;
    final dropOffGP = booking['dropOff'] as GeoPoint?;
    final assignedRider = booking['assignedRider'] as String?;

    if (pickUpGP == null || dropOffGP == null) return;

    final pickUp = LatLng(pickUpGP.latitude, pickUpGP.longitude);
    final dropOff = LatLng(dropOffGP.latitude, dropOffGP.longitude);

    if (status == 'Pending') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            bookingId: bookingId,
            pickUp: pickUp,
            dropOff: dropOff,
          ),
        ),
      ).then((_) => _loadActiveBookings());
    } else if ((status == 'Accepted' || status == 'In Progress') && assignedRider != null) {
      // Get driver location from booking if available
      final driverLocGP = booking['driverLocation'] as GeoPoint?;
      final driverLoc = driverLocGP != null
          ? LatLng(driverLocGP.latitude, driverLocGP.longitude)
          : null;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverInfoScreen(
            driverUid: assignedRider,
            bookingId: bookingId,
            pickUp: pickUp,
            dropOff: dropOff,
            initialDriverLocation: driverLoc,
          ),
        ),
      ).then((_) => _loadActiveBookings());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Bookings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveBookings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActiveBookings,
              child: _activeBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active bookings',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your current rides will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activeBookings.length,
                      itemBuilder: (context, index) {
                        final booking = _activeBookings[index];
                        final status = booking['status'] as String? ?? 'Unknown';
                        final pickUpAddress = booking['pickUpAddress'] as String? ?? 'Unknown';
                        final dropOffAddress = booking['dropOffAddress'] as String? ?? 'Unknown';
                        final fare = (booking['fare'] as num?)?.toDouble() ?? 0.0;
                        final dateBooked = (booking['dateBooked'] as Timestamp?)?.toDate();
                        final assignedRider = booking['assignedRider'] as String?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _getStatusColor(status).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => _navigateToBooking(booking),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Status Badge
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getStatusIcon(status),
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              status.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      if (dateBooked != null)
                                        Text(
                                          DateFormat('MMM dd, h:mm a').format(dateBooked),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Pickup Location
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.trip_origin,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Pickup',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              pickUpAddress,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Dropoff Location
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Drop-off',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              dropOffAddress,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  // Fare and Driver Info
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.payments,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '₱${fare.toStringAsFixed(2)}',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (assignedRider != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person,
                                                size: 14,
                                                color: Colors.blue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Driver Assigned',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
