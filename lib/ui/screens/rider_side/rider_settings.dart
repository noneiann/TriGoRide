import 'package:flutter/material.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_notifications.dart';
class RiderSettingsPage extends StatefulWidget {
  const RiderSettingsPage({super.key});

  @override
  State<RiderSettingsPage> createState() => _RiderSettingsPageState();
}

class _RiderSettingsPageState extends State<RiderSettingsPage> {

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => RiderNotificationsPage()));
            },
            icon: Icon(Icons.notifications),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: const Center(
        child: Text("Settings"),
      ),
    );
  }
}
