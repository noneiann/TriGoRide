import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_notifications.dart';

class RiderFeedbacks extends StatefulWidget {
  const RiderFeedbacks({super.key});

  @override
  State<RiderFeedbacks> createState() => _RiderFeedbacksState();
}

class _RiderFeedbacksState extends State<RiderFeedbacks> {
  final List<Map<String, dynamic>> _feedbacks = [
    {
      'name': 'Alex Garcia',
      'rating': 4.5,
      'comment': 'Very polite and got me to my destination quickly!',
      'date': 'Apr 12, 2025',
    },
    {
      'name': 'Jasmine Cruz',
      'rating': 5.0,
      'comment': 'Super friendly and smooth ride.',
      'date': 'Apr 9, 2025',
    },
    {
      'name': 'Ben Santos',
      'rating': 4.0,
      'comment': 'Great service. Tricycle was clean!',
      'date': 'Apr 3, 2025',
    },
  ];


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Feedbacks",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
            ),
            IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RiderNotificationsPage())),
              icon: const Icon(Icons.notifications),
            )
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: _feedbacks.isEmpty
          ? const Center(child: Text("No feedback yet."))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _feedbacks.length,
        itemBuilder: (context, index) {
          final feedback = _feedbacks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: Name + Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        feedback['name'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        feedback['date'],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rating
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i < feedback['rating'].floor();
                      final half = (i + 1 - feedback['rating']) == 0.5;
                      return Icon(
                        half
                            ? Icons.star_half
                            : filled
                            ? Icons.star
                            : Icons.star_border,
                        size: 20,
                        color: Colors.orange,
                      );
                    }),
                  ),

                  const SizedBox(height: 12),

                  // Comment
                  Text(
                    feedback['comment'],
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
