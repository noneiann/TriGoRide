import 'package:flutter/material.dart';

class BottomNavBarRider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      selectedItemColor: Colors.orange,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Ride History'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Booked'),
        BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Feedbacks'),
      ],
    );
  }
}
