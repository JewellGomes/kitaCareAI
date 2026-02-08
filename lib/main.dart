import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBg9eOhAsZqw8pZVuitlE6YNmTgk39uSHQ",
        appId: "1:922447048114:android:7ee1a2bd1c95c9322388ab",
        messagingSenderId: "922447048114",
        projectId: "silentsignalai-87900",
        storageBucket: "silentsignalai-87900.firebasestorage.app",
      ),
    );
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera error: $e");
  }
  runApp(const KitaCareApp());
}

class KitaCareApp extends StatelessWidget {
  const KitaCareApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const AuthWrapper(),
    );
  }
}

// --- AUTH ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) return const KitaCareMap();
        return const LoginScreen();
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.volunteer_activism, size: 80, color: Colors.teal),
            const Text("KitaCare AI", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal)),
            const Text("Smart Resource Allocation", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => _handleAuth(true), child: const Text("Login")),
            ),
            TextButton(onPressed: () => _handleAuth(false), child: const Text("New here? Sign Up")),
          ],
        ),
      ),
    );
  }
}

// --- DONATION WAZE / MAP SCREEN ---
class DonationBranch {
  final String name;
  final String description;
  final MapLatLng location;
  final Color statusColor;
  DonationBranch({required this.name, required this.description, required this.location, this.statusColor = Colors.teal});
}

class KitaCareMap extends StatefulWidget {
  const KitaCareMap({super.key});
  @override
  State<KitaCareMap> createState() => _KitaCareMapState();
}

class _KitaCareMapState extends State<KitaCareMap> {
  late MapTileLayerController _mapController;
  late MapZoomPanBehavior _zoomPanBehavior;
  bool _isLoadingMap = false;
  final TextEditingController _searchController = TextEditingController();

  List<DonationBranch> _allBranches = [];
  List<DonationBranch> _displayBranches = [];
  bool _isSearching = false;

  @override
  void initState() {
    _mapController = MapTileLayerController();
    _zoomPanBehavior = MapZoomPanBehavior(
      focalLatLng: const MapLatLng(4.2105, 101.9758),
      zoomLevel: 6,
      enableDoubleTapZooming: true,
    );
    _fetchRealTimeMapPoints();
    super.initState();
  }

  Color _parseColor(String colorStr) {
    if (colorStr == 'red') return Colors.red;
    if (colorStr == 'orange') return Colors.orange;
    return Colors.teal;
  }

  Future<void> _fetchRealTimeMapPoints() async {
    setState(() => _isLoadingMap = true);
    try {
      final resNews = await http.get(
          Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      final resUnicef = await http.get(Uri.parse(
          'https://api.reliefweb.int/v1/reports?appname=kitacare&filter[field]=country&filter[value]=Malaysia&filter[field]=source&filter[value]=UNICEF&limit=2'));

      String newsContext = "No news.";
      if (resNews.statusCode == 200) {
        newsContext = XmlDocument
            .parse(resNews.body)
            .findAllElements('title')
            .take(5)
            .map((e) => e.innerText)
            .join(". ");
      }

      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: 'AIzaSyCmKMOSQEwd9Cfdlv7Bq34WcOmpRtz236Y',
      );

      final prompt = """
      CONTEXT: $newsContext
      TASK: Identify 5 Malaysian NGO branches in these areas. 
      Respond ONLY with a JSON array: [{"name": "Name", "desc": "Need", "lat": 3.1, "lng": 101.6, "color": "red"}]
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      final String? jsonText = response.text;

      if (jsonText != null) {
        final start = jsonText.indexOf('[');
        final end = jsonText.lastIndexOf(']') + 1;
        if (start != -1 && end != -1) {
          final cleanedJson = jsonText.substring(start, end);
          List<dynamic> decoded = json.decode(cleanedJson);
          setState(() {
            _allBranches = decoded.map((item) =>
                DonationBranch(
                  name: item['name'],
                  description: item['desc'],
                  location: MapLatLng(item['lat'], item['lng']),
                  statusColor: _parseColor(item['color'] ?? 'teal'),
                )).toList();
            _displayBranches = _allBranches;
          });
        }
      }
    } catch (e) {
      debugPrint("Map Error: $e");
    } finally {
      setState(() => _isLoadingMap = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      _displayBranches = _allBranches
          .where((b) => b.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _moveToLocation(DonationBranch branch) {
    setState(() {
      _isSearching = false;
      _searchController.text = branch.name;
    });
    _zoomPanBehavior.focalLatLng = branch.location;
    _zoomPanBehavior.zoomLevel = 12;
    _showDetails(branch);
  }

  // UPDATED: Primary Navigation is now Google Maps
  Future<void> _openNavigation(MapLatLng pos) async {
    final googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${pos
            .latitude},${pos.longitude}&travelmode=driving"
    );

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to browser if app is not available
      await launchUrl(googleMapsUrl);
    }
  }

  void _showDetails(DonationBranch branch) {
    showModalBottomSheet(
      context: context,
      builder: (context) =>
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(branch.name, style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(branch.description, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                    onPressed: () => _openNavigation(branch.location),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text("Navigate with Google Maps")
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KitaCare Finder"),
        actions: [
          if (_isLoadingMap) const Center(
              child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(icon: const Icon(Icons.refresh),
              onPressed: _fetchRealTimeMapPoints),
          IconButton(icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: Stack(
        children: [
          // FIX 1: Wrap SfMaps in GestureDetector to close dropdown when tapping the map
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = false;
                FocusScope.of(context).unfocus(); // Hides keyboard
              });
            },
            child: SfMaps(
              layers: [
                MapTileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  controller: _mapController,
                  zoomPanBehavior: _zoomPanBehavior,
                  initialMarkersCount: _displayBranches.length,
                  markerBuilder: (context, index) {
                    return MapMarker(
                      latitude: _displayBranches[index].location.latitude,
                      longitude: _displayBranches[index].location.longitude,
                      child: GestureDetector(
                        onTap: () => _showDetails(_displayBranches[index]),
                        child: Icon(Icons.location_on,
                            color: _displayBranches[index].statusColor,
                            size: 35),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          Positioned(
            top: 15, left: 15, right: 15,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10)
                      ]),
                  child: TextField(
                    controller: _searchController,
                    // FIX 2: Add onTap to show the dropdown immediately
                    onTap: () {
                      setState(() {
                        _isSearching = true;
                        if (_searchController.text.isEmpty) {
                          _displayBranches =
                              _allBranches; // Show full list immediately
                        }
                      });
                    },
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search live locations...",
                      border: InputBorder.none,
                      icon: const Icon(Icons.search),
                      suffixIcon: _isSearching ? IconButton(
                          icon: const Icon(Icons.clear), onPressed: () {
                        _searchController.clear();
                        _onSearchChanged("");
                        // FIX 3: Close search state on clear
                        setState(() => _isSearching = false);
                        FocusScope.of(context).unfocus();
                      }) : null,
                    ),
                  ),
                ),
                // This dropdown will now show immediately because _isSearching is set on tap
                if (_isSearching && _displayBranches.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 5)
                        ]),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _displayBranches.length,
                      itemBuilder: (context, index) {
                        final branch = _displayBranches[index];
                        return ListTile(
                          leading: Icon(Icons.location_pin, color: branch
                              .statusColor),
                          title: Text(branch.name),
                          onTap: () => _moveToLocation(branch),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.push(context, MaterialPageRoute(
            builder: (context) => const DonationFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- DONATION FORM ---
class DonationFormScreen extends StatefulWidget {
  const DonationFormScreen({super.key});
  @override
  State<DonationFormScreen> createState() => _DonationFormScreenState();
}

class _DonationFormScreenState extends State<DonationFormScreen> {
  final _picker = ImagePicker();
  XFile? _selectedImage;
  String _donationType = 'Food (Dry)';
  final _descriptionController = TextEditingController();
  bool _isAnalyzing = false;
  String _aiRecommendation = "";

  Future<void> _getAI() async {
    setState(() { _isAnalyzing = true; _aiRecommendation = "Analyzing data..."; });
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: 'AIzaSyCmKMOSQEwd9Cfdlv7Bq34WcOmpRtz236Y');
      final prompt = "Suggest a real NGO in Malaysia for: $_donationType based on current news.";

      final content = [Content.text(prompt)];
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        content.add(Content.data('image/jpeg', bytes));
      }

      final res = await model.generateContent(content);
      setState(() { _aiRecommendation = res.text ?? "Error"; _isAnalyzing = false; });
    } catch (e) {
      setState(() { _aiRecommendation = e.toString(); _isAnalyzing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Donate Items")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButton<String>(
              isExpanded: true,
              value: _donationType,
              items: ['Cash', 'Clothes', 'Food (Dry)', 'Books', 'Sanitary'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _donationType = val!),
            ),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final img = await _picker.pickImage(source: ImageSource.gallery);
                setState(() => _selectedImage = img);
              },
              child: Container(height: 150, width: double.infinity, color: Colors.grey[200], child: _selectedImage == null ? const Icon(Icons.add_a_photo) : Image.file(File(_selectedImage!.path))),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _getAI, child: const Text("Get AI Recommendation")),
            if (_aiRecommendation.isNotEmpty) Padding(padding: const EdgeInsets.all(10), child: _isAnalyzing ? const CircularProgressIndicator() : Text(_aiRecommendation))
          ],
        ),
      ),
    );
  }
}

// --- AI AUDIT ---
class AINeedsAssessment extends StatefulWidget {
  const AINeedsAssessment({super.key});
  @override
  State<AINeedsAssessment> createState() => _AINeedsAssessmentState();
}

class _AINeedsAssessmentState extends State<AINeedsAssessment> {
  CameraController? controller;
  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      controller!.initialize().then((_) => setState(() {}));
    }
  }
  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text("AI Audit")),
      body: CameraPreview(controller!),
    );
  }
}