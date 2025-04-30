// lib/ui/screens/booking_details_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailsPage extends StatelessWidget {
  final String bookingId;
  const BookingDetailsPage({Key? key, required this.bookingId}) : super(key: key);

  /// Fetches booking + rider username in one go.
  Future<Map<String, dynamic>> _fetchBookingAndRider() async {
    final bookingSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (!bookingSnap.exists) {
      throw Exception('Booking not found');
    }
    final data = bookingSnap.data()!;

    // Look up rider username
    final assignedUid = data['assignedRider'] as String?;
    String riderName = 'Unassigned';
    if (assignedUid != null && assignedUid.isNotEmpty) {
      final riderQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: assignedUid)
          .limit(1)
          .get();
      if (riderQuery.docs.isNotEmpty) {
        final u = riderQuery.docs.first.data();
        riderName = u['username'] as String? ?? assignedUid;
      } else {
        riderName = assignedUid; // fallback to UID
      }
    }

    // Merge riderName into the booking map
    return {
      'bookingId': bookingId,
      'passenger': data['passenger'] as String?    ?? 'N/A',
      'status': data['status'] as String?          ?? 'N/A',
      'fare': data['fare'] as num?                 ?? 0,
      'dateBooked': data['dateBooked'] as Timestamp?,
      'pickUpAddress': data['pickUpAddress'] as String? ?? 'N/A',
      'dropOffAddress': data['dropOffAddress'] as String? ?? 'N/A',
      'assignedRiderName': riderName,
      'active': data['active'], // we'll coerce below
    };
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('MMM d, y • h:mm a').format(dt);
  }

  TableRow _buildTableRow(String left, String right, BuildContext context) {
    final theme = Theme.of(context);
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(left,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(right, style: theme.textTheme.bodyMedium),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchBookingAndRider(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(child: Text('Error loading booking.'));
          }

          final data = snap.data!;
          final passenger      = data['passenger']        as String;
          final status         = data['status']           as String;
          final fare           = data['fare']             as num;
          final dateBookedTs   = data['dateBooked']       as Timestamp?;
          final pickUpAddress  = data['pickUpAddress']    as String;
          final dropOffAddress = data['dropOffAddress']   as String;
          final assignedRider  = data['assignedRiderName']as String;
          final dynamic aRaw   = data['active'];
          final bool active    = aRaw is bool
              ? aRaw
              : aRaw is String
              ? aRaw.toLowerCase() == 'true'
              : false;

          final rows = <TableRow>[];
          rows.add(_buildTableRow('Booking ID', data['bookingId'] as String, context));
          if (dateBookedTs != null) {
            rows.add(_buildTableRow(
                'Date Booked', _formatTimestamp(dateBookedTs), context));
          }
          rows.add(_buildTableRow('Passenger', passenger, context));
          rows.add(_buildTableRow('Assigned Rider', assignedRider, context));
          rows.add(_buildTableRow(
              'Status',
              '${status[0].toUpperCase()}${status.substring(1)}',
              context));
          rows.add(_buildTableRow('Active', active ? 'Yes' : 'No', context));
          rows.add(_buildTableRow('Pickup Address', pickUpAddress, context));
          rows.add(_buildTableRow('Drop-off Address', dropOffAddress, context));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'RIDE DETAILS',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(3),
                      },
                      children: rows,
                    ),
                    Divider(height: 32, thickness: 1, color: theme.dividerColor),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: ₱${fare.toStringAsFixed(2)}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
