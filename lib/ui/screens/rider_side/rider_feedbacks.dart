import 'package:flutter/material.dart';

class RiderFeedbacks extends StatefulWidget {
  const RiderFeedbacks({super.key});

  @override
  State<RiderFeedbacks> createState() => _RiderFeedbacksState();
}

class _RiderFeedbacksState extends State<RiderFeedbacks> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Rider Feedback"),
      ),
    );
  }
}
