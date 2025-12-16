import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'profile_screen.dart'; // 🟢 Import Profile Screen

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  late IO.Socket socket;
  late GoogleMapController mapController;
  final TextEditingController _destinationController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>(); 

  // 🔴 YOUR GOOGLE API KEY
  final String googleApiKey = "AIzaSyCb3i7_Y_jvTtwyni1SwucLoDayMqqrmJ8"; 

  // --- STATE VARIABLES ---
  String status = "Idle"; 
  Map<String, dynamic>? estimateData;
  Map<String, dynamic>? rideDetails;
  
  Set<Marker> _markers = {}; 
  Set<Polyline> _polylines = {}; 

  LatLng? _driverLocation;
  LatLng _myLocation = const LatLng(12.9716, 77.5946);
  double? _selectedDropLat;
  double? _selectedDropLng;

  // 🟢 User Data & Payment
  Map<String, dynamic>? _userData;
  String _selectedPaymentMethod = "UPI"; // Default Payment Method

  // --- UI CONSTANTS ---
  final Color primaryColor = Colors.black;
  final Color accentColor = const Color(0xFF00BFA5); 

  @override
  void initState() {
    super.initState();
    _loadUserData(); // 🟢 Load User Data on Init
    initSocket();
    _getCurrentLocation();
  }

  // 🟢 Load User Data from Shared Preferences
  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('rider_data');
    if (data != null) {
      setState(() {
        _userData = jsonDecode(data);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_myLocation, 15));
    }
  }

  void initSocket() {
    socket = IO.io('https://aye-auto.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();

    socket.onConnect((_) => print('✅ Rider App Connected'));

    // 🟢 Updated to handle new Estimate Data Structure (UPI/Cash)
    socket.on('estimate_response', (data) {
      if (mounted) {
        setState(() {
          status = "Reviewing"; 
          estimateData = data;
          if (data['polyline'] != null) _drawRoute(data['polyline'], Colors.black);
        });
      }
    });

    socket.on('ride_accepted', (data) {
      if (mounted) {
        setState(() {
          status = "Accepted"; 
          rideDetails = data;
          if (data['polyline'] != null) _drawRoute(data['polyline'], Colors.black);
        });
      }
    });

    socket.on('driver_arrived_notification', (data) {
      if (mounted) {
        setState(() {
          status = "Arrived"; 
          if (data['dropPolyline'] != null) _drawRoute(data['dropPolyline'], Colors.green);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['msg']), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating
        ));
      }
    });

    socket.on('driver_moved', (data) {
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(data['lat'], data['lng']);
          _markers = {
            Marker(
              markerId: const MarkerId('driver'),
              position: _driverLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet), 
              rotation: data['heading'] != null ? (data['heading'] as num).toDouble() : 0.0,
            ),
          };
        });
        mapController.animateCamera(CameraUpdate.newLatLng(_driverLocation!));
      }
    });
  }

  void _drawRoute(String encodedPolyline, Color color) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> result = polylinePoints.decodePolyline(encodedPolyline);
    List<LatLng> points = result.map((p) => LatLng(p.latitude, p.longitude)).toList();
    setState(() {
      _polylines = { Polyline(polylineId: const PolylineId("route"), color: color, width: 5, points: points) };
    });
    if(points.isNotEmpty) mapController.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngList(points), 50));
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) { x0 = x1 = latLng.latitude; y0 = y1 = latLng.longitude; } 
      else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(northeast: LatLng(x1!, y1!), southwest: LatLng(x0!, y0!));
  }

  void getEstimate() {
    if (_destinationController.text.isEmpty) return;
    setState(() { rideDetails = null; estimateData = null; });
    socket.emit('get_estimate', { 
      "pickupLat": _myLocation.latitude, "pickupLng": _myLocation.longitude,
      "destination": _destinationController.text, "dropLat": _selectedDropLat ?? 0.0, "dropLng": _selectedDropLng ?? 0.0
    });
  }

  void confirmRequest() {
    if (estimateData == null) return;
    
    // 🟢 Determine Final Fare based on Payment Method
    int finalFare = _selectedPaymentMethod == "UPI" 
        ? estimateData!['fareUPI'] 
        : estimateData!['fareCash'];

    setState(() => status = "Searching");
    
    socket.emit('request_ride', { 
      "pickupLat": _myLocation.latitude, "pickupLng": _myLocation.longitude,
      "destination": _destinationController.text,
      "dropLat": estimateData!['dropLat'], "dropLng": estimateData!['dropLng'],
      "fare": finalFare, // Send calculated fare
      "paymentMethod": _selectedPaymentMethod
    });
  }

  void resetApp() {
    setState(() {
      status = "Idle";
      _polylines.clear();
      _markers.clear();
      _destinationController.clear();
      rideDetails = null;
      estimateData = null;
    });
    mapController.animateCamera(CameraUpdate.newLatLngZoom(_myLocation, 15));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, 
      drawer: _buildDrawer(), 
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🗺️ MAP LAYER
          Padding(
            padding: EdgeInsets.only(bottom: status == "Idle" ? 300 : 0),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _myLocation, zoom: 15),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false, 
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                mapController = controller;
              },
            ),
          ),

          // 🔙 BACK BUTTON
          if (status != "Idle")
             Positioned(
              top: 50, left: 20,
              child: _circularButton(Icons.arrow_back, resetApp),
            ),

          // 📍 RE-CENTER BUTTON
          Positioned(
            bottom: status == "Idle" ? 360 : 380,
            right: 20,
            child: _circularButton(Icons.my_location, () => mapController.animateCamera(CameraUpdate.newLatLngZoom(_myLocation, 15))),
          ),

          // 🏠 IDLE STATE
          if (status == "Idle")
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 350,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Ayra Rider", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // 🔍 SEARCH BAR WITH MENU BUTTON
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(), 
                          ),
                          Expanded(
                            child: GooglePlaceAutoCompleteTextField(
                              textEditingController: _destinationController,
                              googleAPIKey: googleApiKey,
                              inputDecoration: const InputDecoration(
                                hintText: "Where to?",
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                              ),
                              debounceTime: 400, countries: const ["in"], isLatLngRequired: true,
                              getPlaceDetailWithLatLng: (Prediction prediction) {
                                setState(() {
                                  _destinationController.text = prediction.description!;
                                  if (prediction.lat != null) {
                                    _selectedDropLat = double.parse(prediction.lat!);
                                    _selectedDropLng = double.parse(prediction.lng!);
                                  }
                                });
                                getEstimate(); 
                              },
                              itemClick: (Prediction prediction) {
                                _destinationController.text = prediction.description!;
                                _destinationController.selection = TextSelection.fromPosition(TextPosition(offset: prediction.description!.length));
                              }
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: Icon(Icons.search, color: Colors.black),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 🚙 Suggestions Grid
                    const Text("Suggestions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _serviceCard("Ride", "assets/icon/icon.png", true),
                        _serviceCard("Intercity", null, false),
                        _serviceCard("Package", null, false),
                        _serviceCard("Rentals", null, false),
                      ],
                    )
                  ],
                ),
              ),
            ),

          // 📊 ACTIVE RIDE STATES
          if (status != "Idle")
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 25, offset: Offset(0, -5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),

                    // --- 1. REVIEWING ---
                    if (status == "Reviewing" && estimateData != null) ...[
                      const Text("Confirm your ride", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      // 💰 1. PRICE DISPLAY (Dynamic based on Selection)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text("₹", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                                  Text(
                                    _selectedPaymentMethod == "UPI" 
                                        ? "${estimateData!['fareUPI']}" 
                                        : "${estimateData!['fareCash']}", 
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                              Text(
                                _selectedPaymentMethod == "Cash" ? "Cash (Rounded)" : "UPI (Exact Fare)", 
                                style: const TextStyle(color: Colors.grey, fontSize: 12)
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
                            child: Text("${estimateData!['driverDistance']} away", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 🟢 2. PAYMENT METHOD SELECTION
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!), 
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Column(
                          children: [
                            RadioListTile(
                              title: const Text("UPI / Online"),
                              value: "UPI",
                              groupValue: _selectedPaymentMethod,
                              onChanged: (val) => setState(() => _selectedPaymentMethod = val.toString()),
                              secondary: const Icon(Icons.qr_code, color: Colors.blue),
                              dense: true,
                            ),
                            const Divider(height: 1),
                            RadioListTile(
                              title: const Text("Cash"),
                              value: "Cash",
                              groupValue: _selectedPaymentMethod,
                              onChanged: (val) => setState(() => _selectedPaymentMethod = val.toString()),
                              secondary: const Icon(Icons.money, color: Colors.green),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: estimateData!['hasDriver'] ? confirmRequest : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(estimateData!['hasDriver'] ? "CONFIRM RIDE" : "NO DRIVERS", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    // --- 2. SEARCHING ---
                    if (status == "Searching") ...[
                      const LinearProgressIndicator(color: Colors.black, backgroundColor: Colors.grey),
                      const SizedBox(height: 20),
                      const Text("Connecting you to a driver...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(onPressed: resetApp, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("CANCEL REQUEST", style: TextStyle(color: Colors.red))),
                      ),
                    ],

                    // --- 3. ON RIDE ---
                    if ((status == "Accepted" || status == "Arrived") && rideDetails != null) ...[
                      Row(
                        children: [
                          const CircleAvatar(radius: 28, backgroundColor: Colors.black12, child: Icon(Icons.person, size: 35, color: Colors.black54)),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(rideDetails!['driverName'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                                Text("🛺 ${rideDetails!['vehicle'] ?? 'Auto'}", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text("₹${rideDetails!['fare']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                              Text(status == "Arrived" ? "ARRIVED" : rideDetails!['eta'] ?? '2 mins', style: TextStyle(color: status == "Arrived" ? Colors.green : Colors.black, fontWeight: FontWeight.bold)),
                            ]),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(children: [
                          Expanded(child: _actionButton(Icons.call, "Call", Colors.green, () {})),
                          const SizedBox(width: 15),
                          Expanded(child: _actionButton(Icons.shield, "Safety", Colors.blue, () {})),
                        ])
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🟢 UPDATED: NAVIGATION DRAWER WIDGET
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 🟢 CLICKABLE HEADER -> PROFILE
          GestureDetector(
            onTap: () {
              Navigator.pop(context); // Close Drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: UserAccountsDrawerHeader(
              accountName: Text(_userData?['name'] ?? "Guest User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(_userData?['email'] ?? "Tap to view profile"),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white, 
                child: Icon(Icons.person, size: 40, color: Colors.black)
              ),
              decoration: const BoxDecoration(color: Colors.black),
            ),
          ),
          ListTile(leading: const Icon(Icons.history), title: const Text("Your Rides"), onTap: () {}),
          ListTile(leading: const Icon(Icons.payment), title: const Text("Payment"), onTap: () {}),
          ListTile(
            leading: const Icon(Icons.settings), 
            title: const Text("Settings"), 
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            }
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.help), title: const Text("Support"), onTap: () {}),
        ],
      ),
    );
  }

  Widget _circularButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 45, height: 45,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
        child: Icon(icon, color: Colors.black),
      ),
    );
  }

  Widget _serviceCard(String name, String? assetPath, bool isSelected) {
    return Column(
      children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(color: isSelected ? Colors.grey[200] : Colors.grey[100], borderRadius: BorderRadius.circular(15)),
          child: Center(
            child: assetPath != null 
              ? const Icon(Icons.local_taxi, size: 30) 
              : Icon(Icons.car_rental, size: 30, color: Colors.grey[400]),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))
      ],
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color.withOpacity(0.1), foregroundColor: color, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 15)),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}