import 'package:flutter/material.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/passenger_home_screen.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
class RootPagePassenger extends StatefulWidget {
  const RootPagePassenger({super.key});

  @override
  State<RootPagePassenger> createState() => _RootPagePassengerState();
}


class _RootPagePassengerState extends State<RootPagePassenger> {
  int _bottomNavIndex = 0;
  List<Widget> pages = [
    HomeScreen(),
    // BookRideScreen(),
  ];

  List<IconData> iconList = [
    Icons.home,
    Icons.person,
  ];

  List<String> titleList = [
    'Home',
    'Profile',
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
              fontWeight: FontWeight.w700
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
      floatingActionButton: FloatingActionButton(
        onPressed: ()=>{print('pressed')},
        backgroundColor: Colors.orangeAccent,
        splashColor: Colors.orange.shade200,
        foregroundColor: Colors.white70,
        child: Icon(Icons.location_pin,size: 30,),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
