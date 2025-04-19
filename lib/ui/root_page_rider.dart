import 'package:flutter/material.dart';
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
  List<Widget> pages = [
    RiderHomeScreen(),
    const RiderBookingsPage(),
    const RideHistoryPage(),
    const RiderFeedbacks()
  ];

  List<IconData> iconList = [
    Icons.home,
    Icons.book,
    Icons.history,
    Icons.feedback
  ];

  List<String> titleList = [
    'Home',
    'Bookings',
    'Ride History',
    'Feedbacks'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: IndexedStack(
        index: _bottomNavIndex,
        children: pages,
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        splashColor: Colors.orange.shade900,
        activeColor: Colors.orange,
        inactiveColor: Colors.grey,
        icons: iconList,
        activeIndex: _bottomNavIndex,
        gapLocation: GapLocation.center,
        notchSmoothness: NotchSmoothness.softEdge,
        onTap: (index) => {
          setState(() {
            _bottomNavIndex = index;
          })
        },
        
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => {}, child: Icon(Icons.search), backgroundColor: Theme.of(context).primaryColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

    );
  }
}
