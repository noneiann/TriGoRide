import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tri_go_ride/screens/register_passenger.dart';
import '../services/auth_services.dart';


class ChooseUser extends StatefulWidget {
  @override
  State<ChooseUser> createState() => _ChooseUserState();
}

class _ChooseUserState extends State<ChooseUser> {

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: 96),
              height: 100,
              alignment: Alignment.center,
              child: Icon(
                Icons.electric_rickshaw,
                size: 100,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: 128+64,),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("What do you want to Register as?"),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Rider box
                        GestureDetector(
                          onTap: () {
                            // Handle Rider registration (navigate to HomeScreen, for example)
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(builder: (context) => HomeScreen()),
                            // );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Rider option selected.')),
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Rider',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        // Passenger box
                        GestureDetector(
                          onTap: () {
                            // Handle Passenger registration
                            // Add your navigation or logic here for the Passenger option.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Passenger option selected.')),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RegisterPassenger()),
                            );
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Passenger',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        )

      ),
    );
  }
}
