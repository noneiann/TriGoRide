import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_picker_screen.dart';

class BookRideScreen extends StatefulWidget {
  @override
  _BookRideScreenState createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  LatLng? pickUpLatLng;
  LatLng? dropOffLatLng;

  String? pickUpLabel;
  String? dropOffLabel;

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
                      'assets/images/rickshaw_logo.png',
                      height: 100,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'TriGoRide',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
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
                  // Save or proceed with pickup/drop-off data
                  print("Pickup: $pickUpLatLng");
                  print("Drop-off: $dropOffLatLng");
                },
                child: Text("Book Ride", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
