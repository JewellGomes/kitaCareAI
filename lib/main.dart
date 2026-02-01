import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:typed_data';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // THE EMERGENCY HACKATHON FIX: Hardcode the options
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBg9eOhAsZqw8pZVuitlE6YNmTgk39uSHQ", // See Step 2 below to find this
        appId: "1:922447048114:android:7ee1a2bd1c95c9322388ab",
        messagingSenderId: "922447048114",
        projectId: "silentsignalai-87900",
        storageBucket: "silentsignalai-87900.firebasestorage.app",
      ),
    );
    debugPrint("Firebase Initialized Successfully!");
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
  }

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera error: $e");
  }

  runApp(const SafePathApp());
}

class SafePathApp extends StatelessWidget {
  const SafePathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      // AuthWrapper decides if we see Login or Map
      home: const AuthWrapper(),
    );
  }
}

// --- GATEKEEPER ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const SafePathMap(); // Logged in!
        } else {
          return const LoginScreen(); // Not logged in!
        }
      },
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleAuth(bool isLogin) async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 80, color: Colors.indigo),
            const Text("SafePath MY", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _handleAuth(true), child: const Text("Login")),
                OutlinedButton(onPressed: () => _handleAuth(false), child: const Text("Sign Up")),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// --- MAIN MAP SCREEN ---
class SafePathMap extends StatefulWidget {
  const SafePathMap({super.key});
  @override
  State<SafePathMap> createState() => _SafePathMapState();
}

class _SafePathMapState extends State<SafePathMap> {
  MapLatLng _currentLocation = const MapLatLng(3.1390, 101.6869);
  late MapTileLayerController _mapController;

  @override
  void initState() {
    _mapController = MapTileLayerController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SafePath MY"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // LOGOUT BUTTON
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: SfMaps(
        layers: [
          MapTileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            // We move initialCenter and initialZoomLevel into the controller logic
            // if the direct parameters are failing.
            controller: _mapController,
            initialMarkersCount: 1,
            markerBuilder: (context, index) {
              return MapMarker(
                latitude: _currentLocation.latitude,
                longitude: _currentLocation.longitude,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "audit",
            backgroundColor: Colors.red,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CameraAuditScreen())),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "gps",
            backgroundColor: Colors.indigo,
            onPressed: () async {
              Position pos = await Geolocator.getCurrentPosition();
              setState(() => _currentLocation = MapLatLng(pos.latitude, pos.longitude));
            },
            child: const Icon(Icons.gps_fixed, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// --- CAMERA & AI SCREEN ---
class CameraAuditScreen extends StatefulWidget {
  const CameraAuditScreen({super.key});
  @override
  State<CameraAuditScreen> createState() => _CameraAuditScreenState();
}

class _CameraAuditScreenState extends State<CameraAuditScreen> {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("AI Safety Audit"), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Stack(
        children: [
          Center(child: CameraPreview(controller!)),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.analytics),
                label: const Text("Analyze with Gemini"),
                onPressed: () async {
                  // Capture & Send to Gemini Logic here
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}