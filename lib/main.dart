import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/rider_home_screen.dart';
import 'screens/login_screen.dart'; // This file contains RiderLoginScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Check local storage
  final prefs = await SharedPreferences.getInstance();
  
  // 2. We check for 'rider_data' now (since we save the full profile JSON)
  // If this exists, the user is logged in.
  final String? savedData = prefs.getString('rider_data');
  
  // 3. Decide which screen to start with
  runApp(MyApp(
    startScreen: savedData == null ? const RiderLoginScreen() : const RiderHomeScreen()
  ));
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aye Auto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.black,
        useMaterial3: true,
        // Optional: Define global font family if you have one
        // fontFamily: 'YourFont', 
      ),
      home: startScreen, // 🟢 Loads Login or Home dynamically
    );
  }
}