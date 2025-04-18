import 'package:flutter/material.dart';

class BookRideScreen extends StatelessWidget {
  final TextEditingController pickUpController = TextEditingController();
  final TextEditingController dropOffController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF3E0), // soft orange background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/rickshaw_logo.png', // add this to your assets
                      height: 100,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'RIDETRACK',
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

              // Pick-up Field
              TextField(
                controller: pickUpController,
                decoration: InputDecoration(
                  hintText: 'Pick-up',
                  prefixIcon: Icon(Icons.location_on, color: Colors.deepOrange),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Drop-off Field
              TextField(
                controller: dropOffController,
                decoration: InputDecoration(
                  hintText: 'Drop-off',
                  prefixIcon: Icon(Icons.navigation, color: Colors.deepOrange),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Payment Method Button
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Add payment method logic
                },
                icon: Icon(Icons.payment),
                label: Text("Payment method"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  backgroundColor: Colors.orange[100],
                  elevation: 4,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),

              SizedBox(height: 30),

              // Save Place Button
              ElevatedButton(
                onPressed: () {
                  // TODO: Handle saving place
                },
                child: Text("Save Place", style: TextStyle(fontSize: 16)),
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
