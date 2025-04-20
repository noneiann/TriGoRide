import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PassengerRideHistory extends StatefulWidget {
  const PassengerRideHistory({super.key});

  @override
  State<PassengerRideHistory> createState() => _PassengerRideHistoryState();
}

class _PassengerRideHistoryState extends State<PassengerRideHistory> {
  final List<Map<String, dynamic>> _rideHistory = [
    {
      'destination': 'SM City Manila',
      'dateTime': DateTime.now().subtract(Duration(hours: 3)),
      'fare': 150.0,
      'status': 'Completed',
    },
    {
      'destination': 'Robinsons Place Ermita',
      'dateTime': DateTime.now().subtract(Duration(days: 1, hours: 2)),
      'fare': 120.0,
      'status': 'Cancelled',
    },
    {
      'destination': 'Quiapo Church',
      'dateTime': DateTime.now().subtract(Duration(days: 2, hours: 5)),
      'fare': 100.0,
      'status': 'Completed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Ride History",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () {
              print('notifs pressed');
            },
            icon: Icon(Icons.notifications),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _rideHistory.isEmpty
            ? Center(
          child: Text(
            "No rides yet.",
            style: theme.textTheme.titleMedium,
          ),
        )
            : ListView.builder(
          itemCount: _rideHistory.length,
          itemBuilder: (context, index) {
            final ride = _rideHistory[index];
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
                      ride['destination'],
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMM dd, yyyy – hh:mm a')
                              .format(ride['dateTime']),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          '₱${ride['fare'].toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ride['status'],
                      style: TextStyle(
                        color: ride['status'] == 'Completed'
                            ? Colors.green
                            : Colors.red,
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

