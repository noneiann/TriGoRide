import 'package:flutter/material.dart';


class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Ride History Page"),
      ),
    );
  }
}
