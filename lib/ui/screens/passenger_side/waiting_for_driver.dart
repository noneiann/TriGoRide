import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'driver_info.dart';

class WaitingForDriverScreen extends StatefulWidget {
  final String bookingId;
  final LatLng pickUp, dropOff;

  const WaitingForDriverScreen({
    Key? key,
    required this.bookingId,
    required this.pickUp,
    required this.dropOff,
  }) : super(key: key);

  @override
  _WaitingForDriverScreenState createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> {
  late final Stream<DocumentSnapshot> bookingStream;

  @override
  void initState() {
    super.initState();
    bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Finding a Driver…")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: bookingStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return Center(child: CircularProgressIndicator());

          if (!snap.hasData || !snap.data!.exists)
            return Center(child: Text("Booking not found"));

          final data = snap.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String;

          if (status == 'Pending') {
            // show map with just pickup & dropoff markers
            return GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.pickUp,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('pickup'),
                  position: widget.pickUp,
                  infoWindow: InfoWindow(title: 'Pick‑up'),
                ),
                Marker(
                  markerId: MarkerId('dropoff'),
                  position: widget.dropOff,
                  infoWindow: InfoWindow(title: 'Drop‑off'),
                ),
              },
            );
          }

          if (status == 'Accepted') {
            final assignedRider = data['assignedRider'] as String;
            final gp = data['driverLocation'] as GeoPoint?;
            final driverLoc = gp != null
                ? LatLng(gp.latitude, gp.longitude)
                : null;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverInfoScreen(
                    riderUid: assignedRider,
                    bookingId: widget.bookingId,
                    pickUp: widget.pickUp,
                    dropOff: widget.dropOff,
                    initialDriverLocation: driverLoc,
                  ),
                ),
              );
            });
            return Center(child: CircularProgressIndicator());
          }


          return Center(child: Text("Status: $status"));
        },
      ),
    );
  }
}
