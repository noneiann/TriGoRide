// lib/ui/screens/rider_side/rider_ride_history.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:tri_go_ride/services/auth_services.dart';

import 'package:tri_go_ride/ui/screens/notifs_page.dart';

import '../../booking_details.dart';

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
    await dotenv.load();

    final currentRider = _authService.getUser()?.uid;
    if (currentRider == null) {
      debugPrint('⚠️ No signed-in rider found, aborting fetchRideHistory.');
      setState(() => _loading = false);
      return;
    }

    try {
      final completedSnap = await _authService.firestore
          .collection('bookings')
          .where('assignedRider', isEqualTo: currentRider)
          .where('status', isEqualTo: 'Completed')
          .get();
      final cancelledSnap = await _authService.firestore
          .collection('bookings')
          .where('assignedRider', isEqualTo: currentRider)
          .where('status', isEqualTo: 'Cancelled')
          .get();

      // Merge, preserving doc IDs
      final all = <Map<String, dynamic>>[];
      for (var doc in completedSnap.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        all.add(d);
      }
      for (var doc in cancelledSnap.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        all.add(d);
      }

      // Sort by dateBooked descending
      all.sort((a, b) {
        final aTime = (a['dateBooked'] as Timestamp).toDate();
        final bTime = (b['dateBooked'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });

      setState(() {
        _rideHistory = all;
        _loading = false;
      });
      debugPrint('🏁 Loaded ${_rideHistory.length} rides');
    } catch (e, st) {
      debugPrint('❌ Error fetching ride history: $e\n$st');
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
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsPage()));
            },
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
            'No completed or cancelled rides yet.',
            style: theme.textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _rideHistory.length,
          itemBuilder: (context, index) {
            final ride = _rideHistory[index];
            final dropOffAddress =
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
                margin:
                const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        dropOffAddress,
                        style: theme
                            .textTheme.titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                        children: [
                          Text(
                            DateFormat(
                                'MMM dd, yyyy – hh:mm a')
                                .format(dateTime),
                            style: theme
                                .textTheme.bodySmall,
                          ),
                          Text(
                            '₱${fare.toStringAsFixed(2)}',
                            style: theme
                                .textTheme.bodyMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w600,
                              color:
                              theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status,
                        style: TextStyle(
                          color: status ==
                              'Completed'
                              ? Colors.green
                              : Colors.red,
                          fontWeight:
                          FontWeight.w500,
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
