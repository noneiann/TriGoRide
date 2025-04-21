import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_notifications.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _rideHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    final currentRider = _authService.getUser().uid;
    try {
      final completedSnapshot = await _authService.firestore
          .collection('bookings')
          .where('assignedRider', isEqualTo: currentRider)
          .where('status', isEqualTo: 'Completed')
          .get();

      final cancelledSnapshot = await _authService.firestore
          .collection('bookings')
          .where('assignedRider', isEqualTo: currentRider)
          .where('status', isEqualTo: 'Cancelled')
          .get();

      final completed = completedSnapshot.docs.map((doc) => doc.data()).toList();
      final cancelled = cancelledSnapshot.docs.map((doc) => doc.data()).toList();

      final allRides = [...completed, ...cancelled];
      allRides.sort((a, b) {
        final aTime = (a['dateBooked'] as Timestamp).toDate();
        final bTime = (b['dateBooked'] as Timestamp).toDate();
        return bTime.compareTo(aTime); // descending
      });

      setState(() {
        _rideHistory = allRides;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching ride history: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Ride History",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RiderNotificationsPage()));
            },
            icon: const Icon(Icons.notifications),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: _rideHistory.isEmpty
            ? Center(
          child: Text(
            "No completed or cancelled rides yet.",
            style: theme.textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _rideHistory.length,
          itemBuilder: (context, index) {
            final ride = _rideHistory[index];
            final destination = ride['dropOff'].toString() ?? 'Unknown Destination';
            final dateTime = (ride['dateBooked'] as Timestamp).toDate();
            final fare = ride['fare'] ?? 0.0;
            final status = ride['status'];

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy – hh:mm a').format(dateTime),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '₱${fare.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(
                        color: status == 'Completed' ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
