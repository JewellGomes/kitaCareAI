import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start all tasks at once instead of one by one
  final initializations = await Future.wait([
    dotenv.load(fileName: ".env"),
    availableCameras().catchError((e) => <CameraDescription>[]),
  ]);

  cameras = initializations[1] as List<CameraDescription>;

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_KEY']!,
        appId: "1:922447048114:android:7ee1a2bd1c95c9322388ab",
        messagingSenderId: "922447048114",
        projectId: "silentsignalai-87900",
        storageBucket: "silentsignalai-87900.firebasestorage.app",
      ),
    );
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }

  runApp(const KitaCareApp());
}

class KitaCareApp extends StatelessWidget {
  const KitaCareApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- AUTHENTICATION ---
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
            TextButton(onPressed: () => _handleAuth(false), child: const Text("Create Account")),
          ],
        ),
      ),
    );
  }
}

// --- REAL-TIME HEAT MAP SCREEN ---
class DonationBranch {
  final String name;
  final String description;
  final MapLatLng location;
  final Color statusColor;
  final double intensity;
  final String category;

  DonationBranch({
    required this.name,
    required this.description,
    required this.location,
    required this.statusColor,
    required this.intensity,
    required this.category,
  });
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
    super.initState();
    _mapController = MapTileLayerController();
    _zoomPanBehavior = MapZoomPanBehavior(
      focalLatLng: const MapLatLng(4.2105, 101.9758),
      zoomLevel: 6,
      enableDoubleTapZooming: true,
    );

    // Wait 500ms so the UI can finish drawing before hitting the network
    Future.delayed(const Duration(milliseconds: 500), () {
      _fetchRealTimeMapPoints();
    });
  }

  Future<String> _fetchUNICEF() async {
    try {
      final url = Uri.parse('https://api.reliefweb.int/v1/reports?appname=kitacare&filter[field]=country&filter[value]=Malaysia&filter[field]=source&filter[value]=UNICEF&limit=2');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['data'].map((e) => e['fields']['title']).join(". ");
      }
    } catch (e) {}
    return "No recent UN reports.";
  }

  Future<String> _fetchNews() async {
    try {
      final res = await http.get(Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      if (res.statusCode == 200) {
        final doc = XmlDocument.parse(res.body);
        return doc.findAllElements('title').take(5).map((e) => e.innerText).join(". ");
      }
    } catch (e) {}
    return "No recent news.";
  }

  Future<void> _fetchRealTimeMapPoints() async {
    setState(() => _isLoadingMap = true);
    try {
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: dotenv.env['GEMINI_KEY']!);

      // Fetch news for context
      final resNews = await http.get(Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      String news = "General Malaysia news";
      if (resNews.statusCode == 200) {
        news = XmlDocument.parse(resNews.body).findAllElements('title').take(5).map((e) => e.innerText).join(". ");
      }

      final prompt = """
      CONTEXT: $news
      TASK: Identify 8-10 specific districts in Malaysia with poverty or disaster needs.
      OUTPUT ONLY VALID JSON:
      [{"name": "Location Name", "desc": "Need details", "lat": 3.1, "lng": 101.6, "intensity": 0.9, "category": "Food"}]
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
            _allBranches = decoded.map((item) {
              double intensity = (item['intensity'] ?? 0.5).toDouble();
              return DonationBranch(
                name: item['name'],
                description: item['desc'],
                location: MapLatLng(item['lat'], item['lng']),
                statusColor: intensity > 0.6 ? Colors.red : Colors.orange,
                intensity: intensity,
                category: item['category'] ?? 'General',
              );
            }).toList();
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

  Widget _buildHeatMarker(DonationBranch branch) {
    return GestureDetector(
      onTap: () => _showDetails(branch),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // THE BLURRY HEAT GLOW
          Container(
            width: 150 * branch.intensity, // Large spread
            height: 150 * branch.intensity,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  branch.statusColor.withOpacity(0.6),
                  branch.statusColor.withOpacity(0.2),
                  Colors.transparent,
                ],
                stops: const [0.1, 0.4, 1.0],
              ),
            ),
          ),
          // THE CENTER PIN
          Icon(Icons.location_on, color: branch.statusColor, size: 25),
        ],
      ),
    );
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
      // Set display branches to ONLY the selected one or reset to ALL
      // This ensures the marker builder doesn't go out of bounds
      _displayBranches = [branch];
    });

    // Update map focus
    _zoomPanBehavior.focalLatLng = branch.location;
    _zoomPanBehavior.zoomLevel = 12; // Zoom in to the location

    _showDetails(branch);
  }

  Future<void> _openNavigation(MapLatLng pos) async {
    final url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${pos.latitude},${pos.longitude}&travelmode=driving");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showDetails(DonationBranch branch) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(branch.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Chip(label: Text(branch.category), backgroundColor: Colors.teal.shade50),
            const SizedBox(height: 10),
            Text(branch.description, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openNavigation(branch.location),
                icon: const Icon(Icons.map),
                label: const Text("Navigate with Google Maps"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
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
          if (_isLoadingMap) const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRealTimeMapPoints),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _isSearching = false);
              FocusScope.of(context).unfocus();
            },
            child: SfMaps(
              // THE FIX: Adding a Key based on list length forces the map to redraw markers
              layers: [
                MapTileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  controller: _mapController,
                  zoomPanBehavior: _zoomPanBehavior,
                  initialMarkersCount: _displayBranches.length,
                  markerBuilder: (context, index) {
                    // SAFETY CHECK: Ensure index is within bounds
                    if (index >= _displayBranches.length) return const MapMarker(latitude: 0, longitude: 0, child: SizedBox());

                    final branch = _displayBranches[index];
                    return MapMarker(
                      latitude: branch.location.latitude,
                      longitude: branch.location.longitude,
                      child: _buildHeatMarker(branch),
                    );
                  },
                ),
              ],
            ),
          ),
          // SEARCH UI
          // SEARCH UI
          Positioned(
            top: 15, left: 15, right: 15,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
                  ),
                  child: TextField(
                    controller: _searchController,
                    onTap: () {
                      setState(() {
                        _isSearching = true;
                        // If empty, show all markers as suggestions
                        if (_searchController.text.isEmpty) _displayBranches = _allBranches;
                      });
                    },
                    onChanged: (val) {
                      setState(() {
                        _isSearching = val.isNotEmpty;
                        _displayBranches = _allBranches
                            .where((b) => b.name.toLowerCase().contains(val.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search live locations...",
                      border: InputBorder.none,
                      icon: const Icon(Icons.search),
                      // THIS IS THE ICON BUTTON FIX
                      suffixIcon: _isSearching ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          // 1. Clear the text
                          _searchController.clear();
                          // 2. Hide the search results and reset the list to ALL branches
                          setState(() {
                            _isSearching = false;
                            _displayBranches = List.from(_allBranches); // Use a copy to be safe
                          });
                          // 3. Close the keyboard
                          FocusScope.of(context).unfocus();
                        },
                      ) : null,
                    ),
                  ),
                ),
                // Search results dropdown
                if (_isSearching && _displayBranches.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _displayBranches.length,
                      itemBuilder: (context, index) {
                        final b = _displayBranches[index];
                        return ListTile(
                          leading: Icon(Icons.location_pin, color: b.statusColor),
                          title: Text(b.name),
                          subtitle: Text(b.category),
                          onTap: () => _moveToLocation(b), // This function must be fixed too!
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DonationFormScreen())),
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
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: dotenv.env['GEMINI_KEY']!);
      final prompt = "Suggest a real NGO in Malaysia for: $_donationType based on current news. Description: ${_descriptionController.text}";

      final content = [Content.text(prompt)];
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        content.add(Content.data('image/jpeg', bytes));
      }

      final res = await model.generateContent(content);
      setState(() { _aiRecommendation = res.text ?? "No recommendation found."; _isAnalyzing = false; });
    } catch (e) {
      setState(() { _aiRecommendation = e.toString(); _isAnalyzing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Donate Items")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _donationType,
              decoration: const InputDecoration(labelText: "Category"),
              items: ['Cash', 'Clothes', 'Food (Dry)', 'Food (Wet)', 'Books', 'Sanitary'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _donationType = val!),
            ),
            const SizedBox(height: 16),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final img = await _picker.pickImage(source: ImageSource.gallery);
                setState(() => _selectedImage = img);
              },
              child: Container(
                height: 200, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: _selectedImage == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, size: 40), Text("Upload Item Photo")]) : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_selectedImage!.path), fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _getAI, child: const Text("Get AI Recommendation"))),
            if (_aiRecommendation.isNotEmpty) Container(margin: const EdgeInsets.only(top: 20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)), child: _isAnalyzing ? const Center(child: CircularProgressIndicator()) : Text(_aiRecommendation)),
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
      appBar: AppBar(title: const Text("Community AI Audit")),
      body: CameraPreview(controller!),
    );
  }
}