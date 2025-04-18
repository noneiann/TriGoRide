import 'package:flutter/material.dart';

class RiderHomeScreen extends StatefulWidget{
const RiderHomeScreen({Key? key}) : super(key : key);

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();

}

class _RiderHomeScreenState extends State<RiderHomeScreen>{
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return const Scaffold(
      body: Center(
        child: Text("Home Page"),
      )
    );
  }
}