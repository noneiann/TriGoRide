import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class DriverInfoScreen extends StatefulWidget {
  final String riderUid;
  final String bookingId;
  final LatLng pickUp, dropOff;
  final LatLng? initialDriverLocation;

  const DriverInfoScreen({
    Key? key,
    required this.riderUid,
    required this.bookingId,
    required this.pickUp,
    required this.dropOff,
    this.initialDriverLocation,
  }) : super(key: key);

  @override
  _DriverInfoScreenState createState() => _DriverInfoScreenState();
}


class _DriverInfoScreenState extends State<DriverInfoScreen> {
  LatLng? _driverLocation;
  GoogleMapController? _mapController;
  late final StreamSubscription<DocumentSnapshot> _bookingSub;

  @override
  void initState() {
    super.initState();
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen((docSnap) {
      if (!docSnap.exists) return;
      final data = docSnap.data() as Map<String, dynamic>;
      final gp = data['driverLocation'] as GeoPoint?;
      if (gp != null) {
        final newLoc = LatLng(gp.latitude, gp.longitude);
        setState(() {
          _driverLocation = newLoc;
        });
        // also move the camera
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newLoc),
        );
      }
    });
  }

  @override
  void dispose() {
    _bookingSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always include pickUp & dropOff
    final markers = <Marker>{
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
      if (_driverLocation != null)
        Marker(
          markerId: MarkerId('driver'),
          position: _driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Your Driver'),
        ),
    };

    // Center on driver if available, otherwise on pickUp
    final initialCenter = _driverLocation ?? widget.pickUp;
    final initialZoom   = _driverLocation != null ? 14.0 : 12.0;

    return Scaffold(
      appBar: AppBar(title: Text("Driver on the Way")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCenter,
                zoom: initialZoom,
              ),
              markers: markers,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),

          // 2) Rider profile info below
          Expanded(
            flex: 2,
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where('uid', isEqualTo: widget.riderUid)
                  .limit(1)
                  .get(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return Center(child: CircularProgressIndicator());
                if (!snap.hasData || snap.data!.docs.isEmpty)
                  return Center(child: Text("Driver info not found"));

                final doc = snap.data!.docs.first;
                final d = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: d['photoUrl'] != null
                        ? NetworkImage(d['photoUrl'])
                        : null,
                  ),
                  title: Text(d['username'] ?? '—'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (d['vehicle'] != null) Text(d['vehicle']),
                      if (d['phone']   != null) Text(d['phone']),
                    ],
                  ),
                  trailing: Text(
                    d['rating'] != null
                        ? (d['rating'] as num).toStringAsFixed(1)
                        : '—',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
