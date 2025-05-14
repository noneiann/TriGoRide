import 'package:flutter/material.dart';
import 'package:tri_go_ride/ui/register_driver.dart';
import 'package:tri_go_ride/ui/register_passenger.dart';


class ChooseUser extends StatefulWidget {
  const ChooseUser({super.key});

  @override
  State<ChooseUser> createState() => _ChooseUserState();
}

class _ChooseUserState extends State<ChooseUser> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoColor = isDark ? Colors.orange : Colors.black;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: 96),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/TriGoRideLogo.png',
                height: 240,
                width: 240,
                color: logoColor,
                fit: BoxFit.contain,
              ),
            ),


            SizedBox(height: 100,),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => RegisterDriver()),
                            );
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
                                'Driver',
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
