import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/book_ride.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_home_screen.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_profile.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_ride_history.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_bookings.dart';
import 'package:tri_go_ride/ui/login_screen.dart'; // ← your splash/login
import '../../../services/auth_services.dart'; // ← AuthService

class RootPagePassenger extends StatefulWidget {
  const RootPagePassenger({super.key});

  @override
  State<RootPagePassenger> createState() => _RootPagePassengerState();
}

class _RootPagePassengerState extends State<RootPagePassenger> {
  final AuthService _authService = AuthService();

  int _bottomNavIndex = 0;

  final List<IconData> _iconList = [
    Icons.home,
    Icons.event_note,
    Icons.history,
    Icons.person,
  ];

  final List<String> _titleList = [
    'Home',
    'Bookings',
    'History',
    'Profile',
  ];

  Widget _buildCurrentPage() {
    switch (_bottomNavIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const PassengerBookingsScreen();
      case 2:
        return const PassengerRideHistory();
      case 3:
        return PassengerProfile();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentPage(),
      bottomNavigationBar: AnimatedBottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        splashColor: Colors.orange.shade900,
        activeColor: Colors.orange,
        inactiveColor: Colors.grey,
        icons: _iconList,
        activeIndex: _bottomNavIndex,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.softEdge,
        onTap: (index) {
          setState(() => _bottomNavIndex = index);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            PageTransition(
              type: PageTransitionType.bottomToTop,
              childBuilder: (_) => const BookRideScreen(),
            ),
          );
        },
        child: const Icon(Icons.location_pin),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
