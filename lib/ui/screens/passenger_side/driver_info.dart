import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../main.dart';

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
    this.initialDriverLocation, LatLng? driverLocation, required String driverId,
  }) : super(key: key);

  @override
  _DriverInfoScreenState createState() => _DriverInfoScreenState();
}

class _DriverInfoScreenState extends State<DriverInfoScreen> {
  LatLng? _driverLocation;
  GoogleMapController? _mapController;
  late BitmapDescriptor _tricycleIcon;
  late final StreamSubscription<DocumentSnapshot> _bookingSub;

  @override
  void initState() {
    super.initState();
    _loadTricycleIcon();
    _bookingSub = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen(_onBookingUpdate);
  }

  void _onBookingUpdate(DocumentSnapshot docSnap) {
    if (!docSnap.exists) return;
    final data = docSnap.data() as Map<String, dynamic>;
    final gp = data['driverLocation'] as GeoPoint?;
    if (gp != null) {
      final newLoc = LatLng(gp.latitude, gp.longitude);
      setState(() => _driverLocation = newLoc);
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(newLoc),
      );
    }
  }

  Future<void> _loadTricycleIcon() async {
    _tricycleIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/tricycle.png',
    );
    setState(() {});
  }

  @override
  void dispose() {
    _bookingSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickUp,
        infoWindow: const InfoWindow(title: 'Pick-up'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.dropOff,
        infoWindow: const InfoWindow(title: 'Drop-off'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (_driverLocation != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation!,
          icon: _tricycleIcon,
          infoWindow: const InfoWindow(title: 'Your Driver'),
        ),
    };

    final initialCenter = _driverLocation ?? widget.pickUp;
    final initialZoom = _driverLocation != null ? 14.0 : 12.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver on the Way'),
      ),
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialCenter,
                zoom: initialZoom,
              ),
              markers: markers,
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),
          ),
          // Elevated info card at bottom
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('uid', isEqualTo: widget.riderUid)
                .limit(1)
                .get(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox();
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const SizedBox();
              }

              final doc = snap.data!.docs.first;
              final d = doc.data() as Map<String, dynamic>;
              final Timestamp? ts = d['createdAt'] as Timestamp?;
              final String createdAt = ts != null
                  ? DateFormat('MMM d, yyyy at h:mm:ss a').format(ts.toDate())
                  : 'Unknown';

              return Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: CldImageWidget(
                                cloudinary: cloudinary,
                                publicId: d['photoId'] ?? 'samples/placeholder',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                transformation: Transformation()
                                  ..addTransformation('ar_1.0,c_fill,w_100/r_max/f_png'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                d['username'] ?? 'Unknown',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Icon(
                              Icons.star,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              d['rating'] != null
                                  ? (d['rating'] as num).toStringAsFixed(1)
                                  : '-',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoTile('Email', d['email'] ?? 'N/A', theme),
                        _buildInfoTile('Phone', d['phone'] ?? 'N/A', theme),
                        _buildInfoTile('Plate Number', d['plateNumber'] ?? 'N/A', theme),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}