import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:tri_go_ride/screens/splash_screen.dart';
import '../services/auth_services.dart';
import 'book_ride.dart';



class HomeScreen extends StatefulWidget {
  HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  late String name;

  @override
  void initState() {
    super.initState();
    _authService.logUser();
    name = _authService.getUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.orange,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Location'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              color: Colors.orange[300],
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.menu, color: Colors.black),
                  CircleAvatar(
                    backgroundImage: AssetImage('assets/images/profile.png'), // Replace with your own image
                  ),
                ],
              ),
            ),

            // Image / Quote Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Welcome, $name!',
              ),
            ),

            // Buttons Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildTile(Icons.history, "Ride History"),
                  _buildTile(Icons.directions_car, "Book a Ride"),
                  _buildTile(Icons.notifications, "Notifications"),
                  _buildTile(Icons.feedback, "Feedback"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String label) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          if (label == "Book a Ride"){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BookRideScreen()),
            );
          }
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: Colors.orange),
              SizedBox(height: 10),
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

