import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  _LocationPickerScreenState createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _selectedLatLng;
  LatLng? _currentLatLng;
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final userLocation = await _location.getLocation();

    setState(() {
      _currentLatLng = LatLng(userLocation.latitude!, userLocation.longitude!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Location")),
      body: _currentLatLng == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng!,
              zoom: 16,
            ),
            onTap: (LatLng latLng) {
              setState(() {
                _selectedLatLng = latLng;
              });
            },
            markers: _selectedLatLng != null
                ? {
              Marker(
                markerId: MarkerId("selected"),
                position: _selectedLatLng!,
              )
            }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: () {
                if (_selectedLatLng != null) {
                  Navigator.pop(context, _selectedLatLng);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text("Confirm Location"),
            ),
          )
        ],
      ),
    );
  }
}
