import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      selectedItemColor: Colors.orange,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Book a Ride'),
        BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Track Ride'),
        BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Emergency Alert'),
      ],
    );
  }
}
