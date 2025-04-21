import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:tri_go_ride/ui/screens/rider_side/passenger_search.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_bookings.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_feedbacks.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_home_screen.dart';
import 'package:tri_go_ride/ui/screens/rider_side/rider_ride_history.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

class RootPageRider extends StatefulWidget {
  const RootPageRider({super.key});

  @override
  State<RootPageRider> createState() => _RootPageRiderState();
}

class _RootPageRiderState extends State<RootPageRider> {
  int _bottomNavIndex = 0;

  final List<IconData> _iconList = [
    Icons.home,
    Icons.book,
    Icons.history,
    Icons.feedback,
  ];

  final List<String> _titleList = [
    'Home',
    'Bookings',
    'Ride History',
    'Feedbacks',
  ];

  Widget _buildCurrentPage() {
    switch (_bottomNavIndex) {
      case 0:
        return RiderHomeScreen();
      case 1:
        return RiderBookingsPage();
      case 2:
        return const RideHistoryPage();
      case 3:
        return const RiderFeedbacks();
      default:
        return RiderHomeScreen();
    }
  }
  Widget _buildPassengerSearch(){
    return PassengerSearchPage();
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
          setState(() {
            _bottomNavIndex = index;
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {Navigator.push(context,PageTransition(
          type: PageTransitionType.bottomToTop,
          childBuilder: (context) => _buildPassengerSearch(),
        ),
        );},
        child: const Icon(Icons.search),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
