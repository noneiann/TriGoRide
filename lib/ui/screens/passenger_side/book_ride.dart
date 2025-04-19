import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../location_picker_screen.dart';
import 'package:tri_go_ride/services/auth_services.dart';

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});

  @override
  _BookRideScreenState createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final AuthService _authService = AuthService();
  LatLng? pickUpLatLng;
  LatLng? dropOffLatLng;
  String? pickUpLabel;
  String? dropOffLabel;
  late CollectionReference bookings;
  late String passenger;

  @override
  void initState() {
    // TODO: implement initState
 bookings = _authService.firestore.collection('bookings');
 _authService.firestore.collection('users')
     .doc(_authService.getUser()
     .email!)
     .get()
     .then( (doc) {
   final data = doc.data() as Map<String, dynamic>;
   setState(() {
     passenger = data['username'];
   });
 });
    super.initState();
  }

  Future<void> _selectLocation(bool isPickup) async {
    final LatLng? selected = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LocationPickerScreen()),
    );

    if (selected != null) {
      setState(() {
        if (isPickup) {
          pickUpLatLng = selected;
          pickUpLabel = 'Lat: ${selected.latitude.toStringAsFixed(4)}, Lng: ${selected.longitude.toStringAsFixed(4)}';
        } else {
          dropOffLatLng = selected;
          dropOffLabel = 'Lat: ${selected.latitude.toStringAsFixed(4)}, Lng: ${selected.longitude.toStringAsFixed(4)}';
        }
      });
    }
  }

  Future<void> _addBooking() {
      return bookings.add({
        'dateBooked': Timestamp.now(),
        'passenger': passenger,
        'pickUp': GeoPoint(pickUpLatLng!.latitude, pickUpLatLng!.longitude),
        'dropOff': GeoPoint(dropOffLatLng!.latitude, dropOffLatLng!.longitude),
      }).then((value) => print('booking added'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF3E0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/TriGoRideLogo.png',
                      height: 100,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'TriGoRide',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),

              // Pick-up Button
              ElevatedButton.icon(
                onPressed: () => _selectLocation(true),
                icon: Icon(Icons.location_on),
                label: Text(pickUpLabel ?? 'Select Pick-up Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepOrange,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Drop-off Button
              ElevatedButton.icon(
                onPressed: () => _selectLocation(false),
                icon: Icon(Icons.navigation),
                label: Text(dropOffLabel ?? 'Select Drop-off Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepOrange,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  _addBooking();
                  print("Pickup: $pickUpLatLng");
                  print("Drop-off: $dropOffLatLng");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text("Book Ride", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
