import 'package:flutter/material.dart';
import 'package:tri_go_ride/services/auth_services.dart';
import 'book_ride.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  String? name;

  @override
  void initState() {
    super.initState();
    setName();
  }

  void setName() {
    _authService.firestore.collection('users').doc(_authService.getUser().email!).get().then((doc) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        name = data['username'];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            // Image / Quote Section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Welcome, $name!',
               style: TextStyle(
                 fontSize: 18,
                 fontWeight: FontWeight.w500)),
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

