import 'package:flutter/material.dart';

class RiderNotificationsPage extends StatefulWidget {
  const RiderNotificationsPage({super.key});

  @override
  State<RiderNotificationsPage> createState() => _RiderNotificationsPageState();
}

class _RiderNotificationsPageState extends State<RiderNotificationsPage> {

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: const Center(
        child: Text("Passenger Search"),
      ),
    );
  }
}
