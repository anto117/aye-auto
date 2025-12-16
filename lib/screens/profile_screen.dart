import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart'; // 🟢 Points to your existing file

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('rider_data');
    if (data != null) {
      setState(() {
        userData = jsonDecode(data);
      });
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // 🟢 Make sure the class name here matches what is inside login_screen.dart
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (_) => const RiderLoginScreen()), 
      (route) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Profile"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      backgroundColor: Colors.white,
      body: userData == null 
        ? const Center(child: CircularProgressIndicator()) 
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const CircleAvatar(radius: 50, backgroundColor: Colors.black12, child: Icon(Icons.person, size: 50, color: Colors.black)),
                const SizedBox(height: 20),
                _infoTile("Name", userData!['name']),
                _infoTile("Phone", userData!['phone']),
                _infoTile("Email", userData!['email'] ?? "Not Provided"),
                _infoTile("Gender", userData!['gender'] ?? "Not Provided"),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _logout, 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  ),
                )
              ],
            ),
          ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }
}