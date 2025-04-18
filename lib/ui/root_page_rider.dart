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
  List<Widget> pages = const [
    RiderHomeScreen(),
    RideHistoryPage(),
    RiderBookingsPage(),
    RiderFeedbacks()
  ];

  List<IconData> iconList = [
    Icons.home,
    Icons.history,
    Icons.book,
    Icons.feedback
  ];

  List<String> titleList = [
    'Home',
    'Ride History',
    'Bookings',
    'Feedbacks'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(titleList[_bottomNavIndex], style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500
            ),),
            IconButton(onPressed: () => {print('notifs pressed')}, icon: Icon(Icons.notifications))
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0.0
      ),
      body: IndexedStack(
        index: _bottomNavIndex,
        children: pages,
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        splashColor: Colors.orange.shade900,
        activeColor: Colors.orange[900],
        inactiveColor: Colors.orange,
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

    );
  }
}
