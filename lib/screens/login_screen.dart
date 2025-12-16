import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'rider_home_screen.dart';

// 🟢 1. LOGIN SCREEN
class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> login() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://aye-auto.onrender.com/api/rider-auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": _phoneController.text.trim(),
          "password": _passwordController.text.trim()
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Save User Data Locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('rider_data', jsonEncode(data['user'])); 
        
        // Navigate to Home
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RiderHomeScreen()));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['msg'] ?? "Login Failed")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_taxi, size: 80, color: Colors.black),
            const SizedBox(height: 20),
            const Text("Ayra Rider Login", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            
            TextField(
              controller: _phoneController, 
              decoration: InputDecoration(
                labelText: "Phone Number",
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
              ), 
              keyboardType: TextInputType.phone
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _passwordController, 
              decoration: InputDecoration(
                labelText: "Password",
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
              ), 
              obscureText: true
            ),
            const SizedBox(height: 25),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : login, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ), 
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("LOGIN", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
              ),
            ),
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderRegisterScreen())),
              child: const Text("Don't have an account? Register here", style: TextStyle(fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}

// 🟢 2. REGISTRATION SCREEN (Internal Class)
class RiderRegisterScreen extends StatefulWidget {
  const RiderRegisterScreen({super.key});

  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedGender = "Male";
  bool _isLoading = false;

  Future<void> register() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill required fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://aye-auto.onrender.com/api/rider-auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": _nameController.text.trim(),
          "phone": _phoneController.text.trim(),
          "email": _emailController.text.trim(),
          "gender": _selectedGender,
          "password": _passwordController.text.trim()
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        // Save User Data Locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('rider_data', jsonEncode(data['user']));
        
        if (mounted) {
          // Go to Home and remove all previous routes
          Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(builder: (_) => const RiderHomeScreen()), 
            (route) => false
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['msg'] ?? "Registration Failed")));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Account"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()), keyboardType: TextInputType.phone),
              const SizedBox(height: 15),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email (Optional)", prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
              const SizedBox(height: 15),
              
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
                decoration: const InputDecoration(labelText: "Gender", prefixIcon: Icon(Icons.people), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),

              TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Password", prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()), obscureText: true),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : register, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black), 
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("REGISTER", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}