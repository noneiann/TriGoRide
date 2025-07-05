import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tri_go_ride/services/auth_services.dart';
import 'package:tri_go_ride/services/noti_services.dart';
import 'package:tri_go_ride/ui/screens/passenger_side/waiting_for_driver.dart';
import '../../location_picker_screen.dart';
import '../../voice_hailing.dart';


Future<String?> getNearestPlace(double lat, double lng) async {
  await dotenv.load(fileName: ".env");
  final key = dotenv.get('GOOGLEMAPS_APIKEY');
  if (key == null) {
    debugPrint('❌ GOOGLE_MAPS_APIKEY missing');
    return null;
  }


  final params = {
    'key'     : key,
    'location': '$lat,$lng',
    'rankby'  : 'distance',
    'type'    : 'establishment', // You might want to broaden this or use 'point_of_interest'
  };
  final url = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/nearbysearch/json',
    params,
  );

  debugPrint('🔗 Nearby Search URL:\n  $url');


  final res = await http.get(url);
  debugPrint('📥 HTTP ${res.statusCode}');


  final bodySnippet = res.body.length > 1000
      ? res.body.substring(0, 1000) + '…'
      : res.body;
  debugPrint('📝 Body:\n$bodySnippet');

  if (res.statusCode != 200) {
    debugPrint('❌ Non-200 HTTP status, aborting.');
    return null;
  }

  final Map<String, dynamic> data = jsonDecode(res.body);
  final status = data['status'] as String? ?? 'NO_STATUS';
  debugPrint('🔍 API status: $status');
  if (status != 'OK') {
    debugPrint('⚠️ error_message: ${data['error_message']}');
    debugPrint('⚠️ info_messages: ${data['info_messages']}');
    return null;
  }

  final results = data['results'] as List<dynamic>? ?? [];
  debugPrint('✅ ${results.length} results returned');

  if (results.isEmpty) return null;

  // Log each name/vicinity for clarity
  // Using a more robust way to pick a meaningful name, e.g., the first non-route/political result or closest one.
  // For now, let's try to find one with a 'name' that's not just coordinates.
  for (var i = 0; i < results.length; i++) {
    final poi = results[i] as Map<String, dynamic>;
    final name = poi['name'] as String?;
    final vicinity = poi['vicinity'] as String?;
    debugPrint('  [$i] Name: ${poi['name']}, Vicinity: ${poi['vicinity']}, Types: ${poi['types']}');
    if (name != null && !name.contains(RegExp(r'^\d+\.\d+,\s*-?\d+\.\d+$'))) { // Avoid names that are just lat,lng
      return name.split(',').first.trim(); // Return the primary part of the name
    }
  }
  // Fallback to the first result's name if no better one is found
  final first = results.first as Map<String, dynamic>;
  return first['name'] as String?;
}

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({Key? key}) : super(key: key);

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen> {
  final AuthService _authService = AuthService();
  late final CollectionReference _bookings;
  late final CollectionReference _notifs;
  LatLng? _pickUp;
  LatLng? _dropOff;
  String? _pickUpAddress;
  String? _dropOffAddress;
  String? _passenger;
  Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;

  String _selectedPriority = 'regular'; // Default option: 'regular' or 'special'
  final TextEditingController _specialAmountController = TextEditingController();
  double _enteredSpecialAmount = 0.0;

  double _getZoomLevel() {
    final d = _distanceKm;
    if (d < 1) return 16;          // under 1 km
    if (d < 5) return 14;          // 1–5 km
    if (d < 10) return 13;         // 5–10 km
    if (d < 20) return 12;         // 10–20 km
    if (d < 50) return 10;         // 20–50 km
    return 8;                      // farther out
  }

  @override
  void initState() {
    super.initState();
    _bookings = _authService.firestore.collection('bookings');
    _notifs = _authService.firestore.collection('notifs');
    _loadPassengerAndCheckActive();
  }

  @override
  void dispose() {
    _specialAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPassengerAndCheckActive() async {
    final email = _authService.getUser()?.email;
    if (email == null) return;
    // It's good practice to check if mounted before setState after async operations.
    if (!mounted) return;
    final userDoc = await _authService.firestore.collection('users').doc(email).get();
    if (!mounted) return;
    _passenger = (userDoc.data() as Map<String, dynamic>)['username'] as String?;
    await _checkActiveBooking();
  }

  Future<void> _checkActiveBooking() async {
    if (_passenger == null) return;
    final snap = await _bookings
        .where('passenger', isEqualTo: _passenger)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();
    if (!mounted) return;
    if (snap.docs.isEmpty) return;
    final data = snap.docs.first.data() as Map<String, dynamic>;
    final pu   = data['pickUp']  as GeoPoint;
    final doff = data['dropOff'] as GeoPoint;
    Navigator.pushReplacement(context,
      MaterialPageRoute(
        builder: (_) => WaitingForDriverScreen(
          bookingId: snap.docs.first.id,
          pickUp:  LatLng(pu.latitude, pu.longitude),
          dropOff: LatLng(doff.latitude, doff.longitude),
        ),
      ),
    );
  }

  double _toRad(double deg) => deg * pi / 180;

  double _calcKm(LatLng a, LatLng b) {
    const R = 6371; // km
    final dLat = _toRad(b.latitude  - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final h = sin(dLat/2)*sin(dLat/2)
        + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2);
    return 2 * R * atan2(sqrt(h), sqrt(1 - h));
  }

  double get _distanceKm =>
      (_pickUp != null && _dropOff != null)
          ? _calcKm(_pickUp!, _dropOff!)
          : 0.0;

  double get _distanceM =>
      (_pickUp != null && _dropOff != null)
          ? _calcKm(_pickUp!, _dropOff!) * 1000
          : 0.0;

  double getServiceFee(double baseFare){
    return baseFare * 0.1; // 10% service fee
  }

  // This is the base cost of the ride before any fees or special amounts
  double get _baseRideCost {
    if (_pickUp == null || _dropOff == null) return 0.0;
    final raw = (_distanceM / 2000); // Assuming 2000m is a unit for fare calculation
    final double fare = raw < 1 ? 15 : 15 + (raw * 1.5); // ₱15 base, + ₱1.5 per 2000m unit
    return fare;
  }

  // This is the calculated service fee based on the base ride cost
  double get _serviceFeeAmount {
    return getServiceFee(_baseRideCost);
  }

  // This is the final total fare the passenger will pay
  double get _totalPayableFare {
    double totalFare = _baseRideCost + _serviceFeeAmount;
    if (_selectedPriority == 'special') {
      totalFare += _enteredSpecialAmount;
    }
    return double.parse(totalFare.toStringAsFixed(2));
  }

  Future<LatLng?> _getCoordinatesFromName(String name) async {
    await dotenv.load(fileName: ".env");
    final key = dotenv.get('GOOGLEMAPS_APIKEY');
    final url = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
      'key': key,
      'query': name,
    });
    final res = await http.get(url);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if ((data['results'] as List).isEmpty) return null;
    final loc = data['results'][0]['geometry']['location'];
    return LatLng(loc['lat'], loc['lng']);
  }

  /// Fetch route polyline between GeoPoints p and d
  void _getRoute(GeoPoint p, GeoPoint d) async {
    final apiKey = dotenv.get('GOOGLEMAPS_APIKEY');
    final pts = await PolylinePoints().getRouteBetweenCoordinates(
      googleApiKey: apiKey,
      request: PolylineRequest(
        origin: PointLatLng(p.latitude, p.longitude),
        destination: PointLatLng(d.latitude, d.longitude),
        mode: TravelMode.driving,
      ),
    );
    if (pts.points.isEmpty) return;
    final route = pts.points.map((e) => LatLng(e.latitude, e.longitude)).toList();
    final bounds = _boundsFrom(route);

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          width: 5,
          color: Theme.of(context).colorScheme.primary,
          points: route,
        )
      };
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  LatLngBounds _boundsFrom(List<LatLng> pts) {
    double? x0, x1, y0, y1;
    for (var p in pts) {
      if (x0 == null) {
        x0 = x1 = p.latitude;
        y0 = y1 = p.longitude;
      } else {
        if (p.latitude > x1!) x1 = p.latitude;
        if (p.latitude < x0) x0 = p.latitude;
        if (p.longitude > y1!) y1 = p.longitude;
        if (p.longitude < y0!) y0 = p.longitude;
      }
    }
    return LatLngBounds(southwest: LatLng(x0!, y0!), northeast: LatLng(x1!, y1!));
  }
  void _fitMapToMarkers() {
    if (_pickUp == null || _dropOff == null || _mapController == null) return;

    final bounds = _boundsFrom([_pickUp!, _dropOff!]);
    // Animate with a 50px padding so markers aren’t at the very edge:
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }


  Future<void> _selectLocation(bool isPickup) async {
    final chosen = await Navigator.push(context, MaterialPageRoute(builder: (_) => LocationPickerScreen()));
    if (chosen == null) return;
    setState(() { if (isPickup) _pickUp = chosen; else _dropOff = chosen; _fitMapToMarkers(); });
    final addr = await getNearestPlace(chosen.latitude, chosen.longitude);
    setState(() { if (isPickup) _pickUpAddress = addr; else _dropOffAddress = addr; _fitMapToMarkers(); });
    if (_pickUp != null && _dropOff != null) {
      _getRoute(GeoPoint(_pickUp!.latitude, _pickUp!.longitude), GeoPoint(_dropOff!.latitude, _dropOff!.longitude));
    }
  }

  Future<void> _startVoiceHailing() async {
    final res = await Navigator.push<Map<String, String>>(context, MaterialPageRoute(builder: (_) => const VoiceInputScreen()));
    if (res == null) return;
    final puName = res['pickup']!, doName = res['dropoff']!;
    final pu = await _getCoordinatesFromName(puName);
    final dof = await _getCoordinatesFromName(doName);
    if (pu != null && dof != null) {
      setState(() { _pickUp = pu; _dropOff = dof; _pickUpAddress = puName; _dropOffAddress = doName; _fitMapToMarkers(); });
      _getRoute(GeoPoint(pu.latitude, pu.longitude), GeoPoint(dof.latitude, dof.longitude));
    }
  }


  Future<void> _bookRide() async {
    if (_pickUp == null || _dropOff == null || _passenger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup, drop-off, or ensure you are logged in.')),
      );
      return;
    }

    if (_selectedPriority == 'special' && _enteredSpecialAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('For special priority, please enter a valid additional amount.')),
      );
      return;
    }


    final pu  = _pickUp!;
    final dof = _dropOff!;

    String dialogContent = 'From:  ${_pickUpAddress}\n'
        'To:    ${_dropOffAddress}\n\n'
        'Distance: ${_distanceM.toStringAsFixed(2)} m\n'
        'Base Ride Cost: ₱${_baseRideCost.toStringAsFixed(2)}\n'
        'Service Fee: ₱${_serviceFeeAmount.toStringAsFixed(2)}\n';
    if (_selectedPriority == 'special' && _enteredSpecialAmount > 0) {
      dialogContent += 'Special Add-on: ₱${_enteredSpecialAmount.toStringAsFixed(2)}\n';
    }
    dialogContent += '\nTotal Fare: ₱${_totalPayableFare.toStringAsFixed(2)}';


    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Booking'),
        content: Text(dialogContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context,true), child: const Text('Book')),
        ],
      ),
    );
    if (ok != true) return;

    final docRef = await _bookings.add({
      'dateBooked'     : Timestamp.now(),
      'passenger'      : _passenger,
      'status'         : 'Pending',
      'active'         : true,
      'pickUp'         : GeoPoint(pu.latitude, pu.longitude),
      'pickUpAddress'  : _pickUpAddress,
      'dropOff'        : GeoPoint(dof.latitude, dof.longitude),
      'dropOffAddress' : _dropOffAddress,
      'fare'           : _totalPayableFare,
      'baseRideCost'   : _baseRideCost,
      'serviceFee'     : _serviceFeeAmount,
      'priorityType'   : _selectedPriority,
      'specialAmount'  : _selectedPriority == 'special' ? _enteredSpecialAmount : 0.0,
    });

    // Get current user
    final user = _authService.getUser();
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    // Add notification
    await _notifs.add({
      'userId': user.email!,
      'type': 'booking',
      'message': 'Ride booked successfully. Waiting for driver. Total Fare: ₱${_totalPayableFare.toStringAsFixed(2)}',
      'timestamp': Timestamp.now(),
      'read': false,
      'bookingId': docRef.id,
    });
    await NotiService().showNotification(
      title: 'Ride Booked!',
      body: 'Driver is being assigned. Estimated fare: ₱${_totalPayableFare.toStringAsFixed(2)}',
    );

    if (!mounted) return;
    Navigator.pushReplacement(context,
      MaterialPageRoute(
        builder: (_) => WaitingForDriverScreen(
          bookingId: docRef.id,
          pickUp:  pu,
          dropOff: dof,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showMap = _pickUp != null && _dropOff != null;
    final canBook = showMap &&
        (_selectedPriority == 'regular' ||
            (_selectedPriority == 'special' && _enteredSpecialAmount > 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Ride'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: theme.iconTheme,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Preview
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                height: 200,
                child: showMap
                    ? GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _fitMapToMarkers();
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (_pickUp!.latitude  + _dropOff!.latitude )/2,
                      (_pickUp!.longitude + _dropOff!.longitude)/2,
                    ),
                    zoom: _getZoomLevel(), // Adjust zoom dynamically based on distance?
                  ),
                  markers: {
                    Marker(markerId: const MarkerId('pu'), position: _pickUp!),
                    Marker(markerId: const MarkerId('do'), position: _dropOff!),
                  },
                  polylines: _polylines,
                  zoomControlsEnabled: false,
                  scrollGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                )
                    : Center(child: Text('Map preview will appear here', style: theme.textTheme.bodyMedium)),
              ),
            ),

            const SizedBox(height: 24),

            // Location selectors
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.my_location),
                    title: const Text('Pickup location'),
                    subtitle: _pickUpAddress != null
                        ? Text(_pickUpAddress!, overflow: TextOverflow.ellipsis, maxLines: 1,)
                        : const Text('Tap to select'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectLocation(true),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Drop-off location'),
                    subtitle: _dropOffAddress != null
                        ? Text(_dropOffAddress!, overflow: TextOverflow.ellipsis, maxLines: 1,)
                        : const Text('Tap to select'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _selectLocation(false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Ride Priority Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0), // Align with card content
              child: Text(
                'Ride Priority',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Theme( // To ensure radio buttons pick up primary color correctly
                data: Theme.of(context).copyWith(
                  unselectedWidgetColor: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'regular',
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      title: const Text('Regular'),
                      subtitle: const Text('Standard fare: ₱15 base + ₱1.50/2km'),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    RadioListTile<String>(
                      value: 'special',
                      groupValue: _selectedPriority,
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                      title: const Text('Special'),
                      subtitle: const Text('Add an extra amount for your booking'),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    if (_selectedPriority == 'special')
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0, top: 0),
                        child: TextFormField(
                          controller: _specialAmountController,
                          decoration: InputDecoration(
                            labelText: 'Additional Amount',
                            prefixText: '₱ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              _enteredSpecialAmount = double.tryParse(value) ?? 0.0;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),


            const SizedBox(height: 24,),
            // Summary card
            if (showMap)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: theme.colorScheme.primaryContainer.withOpacity(0.3), // Use primaryContainer
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ride Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Distance: ${_distanceM > 1000 ? '${_distanceKm.toStringAsFixed(2)} km' : '${_distanceM.toStringAsFixed(0)} m'}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                          theme, 'Base Ride Cost:', '₱${_baseRideCost.toStringAsFixed(2)}'),
                      _buildSummaryRow(
                          theme, 'Service Fee (10%):', '₱${_serviceFeeAmount.toStringAsFixed(2)}'),
                      if (_selectedPriority == 'special' && _enteredSpecialAmount > 0)
                        _buildSummaryRow(
                            theme, 'Special Add-on:', '₱${_enteredSpecialAmount.toStringAsFixed(2)}'),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Fare:', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('₱${_totalPayableFare.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: IconButton(
                    iconSize: 48,
                    icon: Icon(Icons.mic, color: theme.colorScheme.primary),
                    onPressed: _startVoiceHailing,
                    tooltip: 'Voice Hailing',
                  ),
                ),
              ),
            const SizedBox(height: 100), // Space for bottom sheet


          ],
        ),
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: canBook ? _bookRide : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ).copyWith(
            elevation: MaterialStateProperty.all(canBook ? 2 : 0),
          ),
          child: const Text('Book Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }



  Widget _buildSummaryRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}