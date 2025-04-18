import 'package:flutter/material.dart';

class RiderBookingsPage extends StatefulWidget {
  const RiderBookingsPage({super.key});

  @override
  State<RiderBookingsPage> createState() => _RiderBookingsPageState();
}

class _RiderBookingsPageState extends State<RiderBookingsPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("Bookings Page"),
      ),
    );
  }
}
