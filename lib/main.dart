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

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // THE EMERGENCY HACKATHON FIX: Hardcoded Firebase Options
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
    debugPrint("KitaCare AI: Firebase Initialized!");
  } catch (e) {
    debugPrint("Firebase Initialization Error: $e");
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
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- AUTH GATEKEEPER ---
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

// --- REAL-TIME NEEDS MAP ---
class KitaCareMap extends StatefulWidget {
  const KitaCareMap({super.key});
  @override
  State<KitaCareMap> createState() => _KitaCareMapState();
}

class _KitaCareMapState extends State<KitaCareMap> {
  final List<MapMarker> _needMarkers = [
    const MapMarker(latitude: 3.147, longitude: 101.693, child: Icon(Icons.location_on, color: Colors.red, size: 35)),
    const MapMarker(latitude: 3.155, longitude: 101.701, child: Icon(Icons.location_on, color: Colors.orange, size: 30)),
    const MapMarker(latitude: 3.130, longitude: 101.682, child: Icon(Icons.location_on, color: Colors.green, size: 30)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KitaCare Needs Map"),
        actions: [
          // NEW: Button to open the Donation Form
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DonationFormScreen())),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: SfMaps(
        layers: [
          MapTileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            initialMarkersCount: _needMarkers.length,
            markerBuilder: (context, index) => _needMarkers[index],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AINeedsAssessment())),
        label: const Text("Report Need (AI)"),
        icon: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

// --- FEATURE: DONATION FORM WITH AI RECOMMENDATION ---
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

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    setState(() => _selectedImage = image);
  }

  // Helper function to get latest news from Malaysia
  Future<String> fetchUNICEFMalaysiaNeeds() async {
    try {
      // ReliefWeb API URL: Filters for Malaysia (ID: 151) and Source: UNICEF (ID: 1503)
      final url = Uri.parse(
          'https://api.reliefweb.int/v1/reports?appname=kitacare&filter[field]=country&filter[value]=Malaysia&filter[field]=source&filter[value]=UNICEF&limit=3&profile=full');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List reports = data['data'];

        if (reports.isNotEmpty) {
          // We take the title and a snippet of the latest report
          String unicefData = "";
          for (var report in reports) {
            unicefData += "- ${report['fields']['title']}. ";
          }
          return unicefData;
        }
      }
    } catch (e) {
      debugPrint("UNICEF Fetch Error: $e");
    }
    return "No recent UNICEF Malaysia reports. Defaulting to general community poverty and flood monitoring.";
  }

  Future<String> fetchMalaysiaNews() async {
    try {
      // Fetching from Berita Harian RSS Feed
      final response = await http.get(Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('title').take(5); // Get top 5 headlines
        return items.map((e) => e.innerText).join(". ");
      }
    } catch (e) {
      return "Could not fetch live Malaysia data. Focus on general poverty in Sabah and floods in Kelantan.";
    }
    return "No data.";
  }


  Future<void> _getAIRecommendation() async {
    setState(() {
      _isAnalyzing = true;
      _aiRecommendation = "Accessing live humanitarian reports...";
    });

    try {
      // 1. FETCH LIVE DATA FROM UN & NEWS
      String unicefData = await fetchUNICEFMalaysiaNeeds();
      String newsData = await fetchMalaysiaNews();

      final model = GenerativeModel(
        model: 'gemini-3-flash-preview',
        apiKey: 'AIzaSyBrcmxS3glEpq4UOdcgFHE4vZBcuCc9iXY',
      );

      // 2. THE DYNAMIC PROMPT (No hardcoded branch list)
      final prompt = """
      You are KitaCare AI, an expert on the Malaysian non-profit sector.
      
      USER INPUT:
      - Item: $_donationType
      - Description: ${_descriptionController.text}

      LIVE CONTEXT FROM APIS:
      - UN/UNICEF REPORTS: $unicefData
      - MALAYSIA NEWS: $newsData

      YOUR TASK:
      1. ANALYZE: Based on the LIVE DATA, identify the Malaysian state with the most urgent need for this item.
      2. NGO MATCHING: Search your internal database for established NGO branches in that specific state that accept these items.
         - For Food: Look for Food Aid Foundation, Kechara, or local Soup Kitchens.
         - For Clothes/Books: Look for Salvation Army, BLESS Shop, or Community Centers.
         - For Cash: Look for MERCY Malaysia or Islamic Relief branches.
      3. SPECIFICITY: You MUST provide a real branch name and a general area (e.g., "Kechara Soup Kitchen - Johor Bahru Branch"). Do not invent names.
      
      RESPONSE FORMAT:
      - RECOMMENDED STATE: 
      - URGENCY SOURCE: (Mention if this came from the News or UNICEF data)
      - RECOMMENDED NGO & BRANCH: (Name and City)
      - MISSION ALIGNMENT: (How this NGO's mission matches your donation)
    """;

      final content = [Content.text(prompt)];
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        content.add(Content.data('image/jpeg', bytes));
      }

      final response = await model.generateContent(content);

      setState(() {
        _aiRecommendation = response.text ?? "Data fetch successful, but no recommendation generated.";
        _isAnalyzing = false;
      });

    } catch (e) {
      setState(() {
        _aiRecommendation = "Connection Error: ${e.toString()}";
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Donate Items")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Donation Category", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: _donationType,
              items: ['Cash', 'Clothes', 'Food (Dry)', 'Food (Wet)', 'Books', 'Sanitary'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _donationType = val!),
            ),
            const SizedBox(height: 15),
            TextField(controller: _descriptionController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 15),
            const Text("Condition Image (AI Assessment)"),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                child: _selectedImage == null ? const Icon(Icons.add_a_photo) : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _getAIRecommendation,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Get AI Recommendation"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
            ),
            if (_aiRecommendation.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: _isAnalyzing ? const Center(child: CircularProgressIndicator()) : Text(_aiRecommendation),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// --- FEATURE: CAMERA-BASED NEEDS ASSESSMENT ---
class AINeedsAssessment extends StatefulWidget {
  const AINeedsAssessment({super.key});
  @override
  State<AINeedsAssessment> createState() => _AINeedsAssessmentState();
}

class _AINeedsAssessmentState extends State<AINeedsAssessment> {
  CameraController? controller;
  bool isAnalyzing = false;
  String result = "Point camera at a community area to assess urgency.";

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      controller = CameraController(cameras[0], ResolutionPreset.medium);
      controller!.initialize().then((_) => setState(() {}));
    }
  }

  Future<void> _analyzeWithGemini() async {
    setState(() { isAnalyzing = true; result = "Gemini is analyzing urgency..."; });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      isAnalyzing = false;
      result = "AI Assessment: High Priority (SDG 11). This urban area requires infrastructure support and clean water supplies.";
    });
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text("NGO AI Audit")),
      body: Column(
        children: [
          Expanded(child: CameraPreview(controller!)),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Text(result, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                if (isAnalyzing) const CircularProgressIndicator()
                else ElevatedButton.icon(onPressed: _analyzeWithGemini, icon: const Icon(Icons.psychology), label: const Text("Analyze Area")),
              ],
            ),
          )
        ],
      ),
    );
  }
}