import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/waiting_for_driver.dart';
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
    super.initState();
    bookings = _authService.firestore.collection('bookings');

    // 1) load your passenger username
    _authService.firestore
        .collection('users')
        .doc(_authService.getUser()!.email!)
        .get()
        .then((doc) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() => passenger = data['username']);
    })
    // 2) once passenger is set, check for an existing active booking
        .whenComplete(_checkActiveBooking);
  }

  /// If the user already has an active booking, go straight into the flow.
  Future<void> _checkActiveBooking() async {
    if (passenger == null) return;
    final snap = await bookings
        .where('passenger', isEqualTo: passenger)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      final GeoPoint pu = data['pickUp'];
      final GeoPoint doff = data['dropOff'];

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            bookingId: doc.id,
            pickUp: LatLng(pu.latitude, pu.longitude),
            dropOff: LatLng(doff.latitude, doff.longitude),
          ),
        ),
      );
    }
  }

  Future<String> _addBooking() async {
    final docRef = await bookings.add({
      'dateBooked': Timestamp.now(),
      'passenger': passenger,
      'status': 'Pending',
      'active': true, // ← mark it active
      'pickUp': GeoPoint(
        pickUpLatLng!.latitude,
        pickUpLatLng!.longitude,
      ),
      'dropOff': GeoPoint(
        dropOffLatLng!.latitude,
        dropOffLatLng!.longitude,
      ),
    });
    return docRef.id;
  }

  void _onBookPressed() async {
    final bookingId = await _addBooking();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WaitingForDriverScreen(
          bookingId: bookingId,
          pickUp: pickUpLatLng!,
          dropOff: dropOffLatLng!,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Book A Ride",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            onPressed: () {
              print('notifs pressed');
            },
            icon: Icon(Icons.notifications),
          )
        ],
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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


              // Pick-up Button
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _selectLocation(true),
                    icon: Icon(Icons.location_on),
                    label: Text(pickUpLabel ?? 'Select Pick-up Location'),
                    style: ElevatedButton.styleFrom(
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
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),


              // …

              ElevatedButton(
                onPressed: () {
                  if (pickUpLatLng == null || dropOffLatLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please select both pickup and drop‑off')),
                    );
                    return;
                  }
                  _onBookPressed(); // <-- actually call the method!
                  print("Pickup: $pickUpLatLng");
                  print("Drop‑off: $dropOffLatLng");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
