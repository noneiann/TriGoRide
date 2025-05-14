// lib/ui/screens/passenger_side/driver_info.dart

import 'dart:async';
import 'package:cloudinary_flutter/cloudinary_object.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_flutter/image/cld_image.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../main.dart';
import '../../root_page_passenger.dart';
import '../passenger_side/rating_dialog.dart';
import '../../../services/auth_services.dart';
import 'package:url_launcher/url_launcher.dart';

final CloudinaryObject cloudinary =
CloudinaryObject.fromCloudName(cloudName: 'dgu4lwrwn');

class DriverInfoScreen extends StatefulWidget {
  final String driverUid;
  final String bookingId;
  final LatLng pickUp;
  final LatLng dropOff;
  final LatLng? initialDriverLocation;

  const DriverInfoScreen({
    Key? key,
    required this.driverUid,
    required this.bookingId,
    required this.pickUp,
    required this.dropOff,
    this.initialDriverLocation,
  }) : super(key: key);

  @override
  _DriverInfoScreenState createState() => _DriverInfoScreenState();
}

class _DriverInfoScreenState extends State<DriverInfoScreen> {
  late int _driverRating = 0;
  LatLng? _driverLocation;
  GoogleMapController? _mapController;
  late BitmapDescriptor _tricycleIcon;
  late StreamSubscription<DocumentSnapshot> _bookingSub;
  String? _lastStatus;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _driverLocation = widget.initialDriverLocation;
    _loadTricycleIcon();
    _bookingSub = _authService.firestore.collection('bookings')
        .doc(widget.bookingId)
        .snapshots()
        .listen(_onBookingUpdate);
    _getRating();
  }

  Future<void> _handleSOS() async {
    final user = _authService.getUser();
    if (user == null) return;

    final doc = await _authService.firestore
        .collection('users')
        .doc(user.email)
        .get();

    final raw = doc.data()?['emergencyNum']?.toString();
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency number found')),
      );
      return;
    }

    final number = raw.replaceAll(RegExp(r'\D'), '');
    try {
      // On Android: places the call directly (with runtime CALL_PHONE permission prompt)
      // On iOS: opens the dialer with the number pre-filled
      await FlutterPhoneDirectCaller.callNumber(number);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing call: $e')),
      );
    }
  }


  Future<void> _loadTricycleIcon() async {
    _tricycleIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(50, 50)),
      'assets/tricycle.png',
    );
    if (mounted) setState(() {});
  }

  Future<void> _getRating() async {
    final ratings = await _authService.firestore
        .collection('ratings')
        .where('driverId', isEqualTo: widget.driverUid)
        .get();
    int sumRating = 0;
    for(var rating in ratings.docs) {
      final data = rating.data() as Map<String, dynamic>;
     sumRating += data['rating'] as int;
    }

    setState(() {
      _driverRating = sumRating ~/ ratings.docs.length;
    });
  }

  void _onBookingUpdate(DocumentSnapshot snap) {
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;

    // 1) Show rating dialog when status flips to "Completed"
    final status = data['status'] as String?;
    if (status == 'Completed' && _lastStatus != 'Completed') {
      Future.microtask(() {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => EnhancedRatingDialog(
            driverId: widget.driverUid,
            bookingId: widget.bookingId,
            onRatingComplete: () {
              Navigator.of(context).pop(); // dismiss dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RootPagePassenger()),
                    (route) => false,
              );
            },
          ),
        );
      });
    }
    _lastStatus = status;

    // 2) Update and animate driver marker
    final gp = data['driverLocation'] as GeoPoint?;
    if (gp != null) {
      final loc = LatLng(gp.latitude, gp.longitude);
      setState(() => _driverLocation = loc);
      _mapController?.animateCamera(CameraUpdate.newLatLng(loc));
    }
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
    };
    if (_driverLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation!,
        icon: _tricycleIcon,
        infoWindow: const InfoWindow(title: 'Your Driver'),
      ));
    }


      return Scaffold(
        appBar: AppBar(
          title: const Text('Driver on the Way'),
          actions: [
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
              tooltip: 'SOS',
              onPressed: _handleSOS,
            ),
          ],
        ),

        body: Stack(
          children: [

            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _authService.firestore
                  .collection('bookings')
                  .doc(widget.bookingId)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData || !snap.data!.exists) {
                  // still loading booking
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snap.data!.data()!;
                final gp = data['driverLocation'] as GeoPoint?;
                if (gp != null) {
                  _driverLocation = LatLng(gp.latitude, gp.longitude);
                  // animate camera once per update
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(_driverLocation!),
                    );
                  });
                }

                final markers = <Marker>{
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: widget.pickUp,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                  ),
                  Marker(
                    markerId: const MarkerId('dropoff'),
                    position: widget.dropOff,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                };
                if (_driverLocation != null) {
                  markers.add(Marker(
                    markerId: const MarkerId('driver'),
                    position: _driverLocation!,
                    icon: _tricycleIcon,
                    infoWindow: const InfoWindow(title: 'Your Driver'),
                  ));
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.initialDriverLocation ?? widget.pickUp,
                    zoom: widget.initialDriverLocation != null ? 17 : 15,
                  ),
                  markers: markers,
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                );
              },
            ),

            FutureBuilder<QuerySnapshot>(
              future: _authService.firestore
                  .collection('users')
                  .where('uid', isEqualTo: widget.driverUid)
                  .limit(1)
                  .get(),
              builder: (ctx, snap) {
                if (snap.connectionState != ConnectionState.done ||
                    !snap.hasData ||
                    snap.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final d = snap.data!.docs.first.data() as Map<String, dynamic>;
                final profileImage = d['profileImage'] as Map<String, dynamic>?;
                final fetchedProfileId = profileImage?['publicId'] as String? ?? '';

                return Positioned(
                  left: 16, right: 16, bottom: 16,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ClipOval(
                                child: CldImageWidget(
                                  cloudinary: cloudinary,
                                  publicId: fetchedProfileId ?? 'samples/placeholder',
                                  width: 60, height: 60, fit: BoxFit.cover,
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
                              Icon(Icons.star, color: theme.colorScheme.secondary),
                              const SizedBox(width: 4),
                              Text(
                                _driverRating != null
                                    ? (_driverRating ?? 0.0 as num).toStringAsFixed(1)
                                    : '-',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(color: theme.colorScheme.secondary),
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
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
