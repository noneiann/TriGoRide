// lib/ui/screens/passenger_side/passenger_ride_history.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/ui/screens/notifs_page.dart';

import '../../booking_details.dart';


class PassengerRideHistory extends StatefulWidget {
  const PassengerRideHistory({super.key});

  @override
  State<PassengerRideHistory> createState() => _PassengerRideHistoryState();
}

class _PassengerRideHistoryState extends State<PassengerRideHistory> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _rideHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchRideHistory();
  }

  Future<void> _fetchRideHistory() async {
    await dotenv.load();

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
      final completed = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passenger', isEqualTo: passengerName)
          .where('status', isEqualTo: 'Completed')
          .get();
      final cancelled = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passenger', isEqualTo: passengerName)
          .where('status', isEqualTo: 'Cancelled')
          .get();

      // Merge and include each doc’s id
      final all = <Map<String, dynamic>>[];
      for (var doc in completed.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        all.add(d);
      }
      for (var doc in cancelled.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        all.add(d);
      }

      all.sort((a, b) {
        final at = (a['dateBooked'] as Timestamp).toDate();
        final bt = (b['dateBooked'] as Timestamp).toDate();
        return bt.compareTo(at);
      });

      setState(() {
        _rideHistory = all;
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
          'Ride History',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()));
            },
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: _rideHistory.isEmpty
            ? Center(
          child: Text(
            'No completed or cancelled rides yet.',
            style: theme.textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _rideHistory.length,
          itemBuilder: (context, index) {
            final ride = _rideHistory[index];
            final destination =
                ride['dropOffAddress'] as String? ??
                    'Unknown Destination';
            final dateTime = (ride['dateBooked'] as Timestamp)
                .toDate();
            final fare = ride['fare'] as num? ?? 0.0;
            final status = ride['status'] as String? ?? '';
            final bookingId = ride['id'] as String;

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BookingDetailsPage(bookingId: bookingId),
                  ),
                );
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat(
                                'MMM dd, yyyy – hh:mm a')
                                .format(dateTime),
                            style:
                            theme.textTheme.bodySmall,
                          ),
                          Text(
                            '₱${fare.toStringAsFixed(2)}',
                            style: theme.textTheme
                                .bodyMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w600,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status,
                        style: TextStyle(
                          color: status == 'Completed'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
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
