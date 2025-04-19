import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RiderBookingsPage extends StatefulWidget {
  const RiderBookingsPage({super.key});

  @override
  State<RiderBookingsPage> createState() => _RiderBookingsPageState();
}

class _RiderBookingsPageState extends State<RiderBookingsPage> {
  final List<Map<String, dynamic>> _bookings = [
    {
      'passenger': 'Alyssa Santos',
      'pickup': 'Sta. Mesa',
      'dropoff': 'Intramuros',
      'datetime': DateTime.now().add(Duration(hours: 2)),
      'status': 'Pending',
    },
    {
      'passenger': 'John Dela Cruz',
      'pickup': 'España Blvd',
      'dropoff': 'SM Manila',
      'datetime': DateTime.now().add(Duration(days: 1)),
      'status': 'Accepted',
    },
    {
      'passenger': 'Mark Reyes',
      'pickup': 'UST',
      'dropoff': 'Binondo',
      'datetime': DateTime.now().subtract(Duration(hours: 3)),
      'status': 'Completed',
    },
  ];

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Bookings",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () => print('notifs pressed'),
            icon: Icon(Icons.notifications),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _bookings.isEmpty
            ? Center(child: Text("No current bookings."))
            : ListView.builder(
          itemCount: _bookings.length,
          itemBuilder: (context, index) {
            final booking = _bookings[index];
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          booking['passenger'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          booking['status'],
                          style: TextStyle(
                            color: _statusColor(booking['status']),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_pin, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text('From: ${booking['pickup']}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.flag, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text('To: ${booking['dropoff']}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Text(DateFormat('MMM d, yyyy • h:mm a').format(booking['datetime'])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (booking['status'] == 'Pending')
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                booking['status'] = 'Accepted';
                              });
                            },
                            child: Text("Accept"),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => print('Contact pressed'),
                          icon: Icon(Icons.phone),
                          label: Text("Contact"),
                        ),
                      ],
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
