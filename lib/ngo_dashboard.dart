import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class NGOMissionHub extends StatefulWidget {
  const NGOMissionHub({super.key});

  @override
  State<NGOMissionHub> createState() => _NGOMissionHubState();
}

class _NGOMissionHubState extends State<NGOMissionHub> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // State variables for backend logic
  bool _isAnalyzing = false;
  String _aiStrategy = "Fetching internal logistics advisor...";
  bool _isPinVerified = false;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateMissionStrategy();
  }

  // ==========================================
  // BACKEND: AI OPS STRATEGY (Operational Prompt)
  // ==========================================
  Future<void> _generateMissionStrategy() async {
    setState(() => _isAnalyzing = true);
    try {
      final resNews = await http.get(Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      String news = "General Malaysia news";
      if (resNews.statusCode == 200) {
        news = XmlDocument.parse(resNews.body).findAllElements('title').take(5).map((e) => e.innerText).join(". ");
      }

      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: dotenv.env['GEMINI_KEY']!);
      
      // Tasked for NGO internal ops specifically (disbursement/drop-offs)
      final prompt = """
      CONTEXT: $news
      TASK: You are an internal NGO Logistics Consultant. 
      Suggest how to verify drop-offs and manage disbursement logs based on these news trends.
      Limit to 2 sentences. Professional tone.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _aiStrategy = response.text ?? "Focus on verified high-urgency zones.";
      });
    } catch (e) {
      _aiStrategy = "Maintain standby readiness for internal logistics.";
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. BACKEND GATE: Check Project PIN
    if (!_isPinVerified) {
      return _buildPinGate();
    }

    // 2. BACKEND DATA: Listen to the specific NGO's profile
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        // Extract real data from Firestore
        var ngoData = snapshot.data!.data() as Map<String, dynamic>;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(),
          body: SingleChildScrollView( // Allow scrolling for all sections
            child: Column(
              children: [
                _buildAIStrategyCard(),
                
                // NEW: Logistics Analytics (Transparency/Dispatch)
                _buildLogisticsStats(ngoData),

                // NEW: Fund Summary (Bank Details)
                _buildFundSummary(ngoData),

                // NEW: Operational Actions (QR & Items)
                _buildActionButtons(),

                _buildSearchBar(),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.radar, size: 18, color: Colors.teal),
                      SizedBox(width: 8),
                      Text("LIVE FIELD REPORTS", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                
                // Needs List
                SizedBox(
                  height: 400, // Fixed height for stream inside scrollview
                  child: _buildLiveNeedsStream()
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.teal,
            onPressed: () => _showAddNeedDialog(isPhysical: false),
            icon: const Icon(Icons.add_location_alt, color: Colors.white),
            label: const Text("Post Need", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    );
  }

  // ==========================================
  // UI COMPONENTS (INTEGRATED WITH BACKEND)
  // ==========================================

  Widget _buildPinGate() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 64, color: Colors.teal),
              const SizedBox(height: 16),
              const Text("Project PIN Required", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("Enter your secure NGO project PIN", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                obscureText: true,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: "••••", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // BACKEND: Validate PIN (hardcoded 8888 or fetch from ngoData)
                  if (_pinController.text == "8888") {
                    setState(() => _isPinVerified = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN")));
                  }
                },
                child: const Text("Verify & Access Hub"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogisticsStats(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _statCard("Transparency Score", "${data['transparencyScore'] ?? 0}%", Icons.verified_user, Colors.green),
          const SizedBox(width: 10),
          _statCard("Avg Dispatch", "${data['dispatchTime'] ?? 'N/A'} Days", Icons.local_shipping, Colors.blue),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFundSummary(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.slate.shade900, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Colors.white70),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Fund Bank Account", style: TextStyle(color: Colors.white54, fontSize: 10)),
            Text("${data['bankName'] ?? 'Bank'} : ${data['bankAcc'] ?? 'Account'}", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openScanner(), 
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Verify Drop-off"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddNeedDialog(isPhysical: true),
              icon: const Icon(Icons.shopping_basket),
              label: const Text("Request Items"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BACKEND LOGIC ACTIONS
  // ==========================================

  void _openScanner() {
    // Logic: Use mobile_scanner to verify donation IDs
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening QR Verifier...")));
  }

  void _fulfillNeed(String docId) async {
    // BACKEND: Transparency improves when items are marked fulfilled
    await _db.collection('needs').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mission Fulfilled and marker removed.")));
  }

  void _showAddNeedDialog({required bool isPhysical}) {
    final loc = TextEditingController();
    final desc = TextEditingController();
    String urgency = 'High';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isPhysical ? "REQUEST PHYSICAL GOODS" : "NEW FIELD REPORT", 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
            const SizedBox(height: 20),
            TextField(controller: loc, decoration: InputDecoration(labelText: isPhysical ? "Drop-off Location" : "Location (District)")),
            const SizedBox(height: 12),
            TextField(controller: desc, decoration: InputDecoration(labelText: isPhysical ? "Items needed (e.g., 50x Rice)" : "Summary of Crisis")),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () async {
                  // BACKEND: Save to Firestore
                  await _db.collection('needs').add({
                    'ngoId': user?.uid,
                    'locationName': loc.text,
                    'description': desc.text,
                    'urgency': urgency,
                    'type': isPhysical ? 'Physical' : 'Field',
                    'createdAt': FieldValue.serverTimestamp(),
                    'lat': 4.21, 'lng': 101.9,
                  });
                  Navigator.pop(context);
                },
                child: const Text("PUBLISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Existing helpers...
  PreferredSizeWidget _buildAppBar() => AppBar(
    elevation: 0,
    backgroundColor: Colors.white,
    title: const Text("NGO Mission Hub", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
    actions: [
      IconButton(icon: const Icon(Icons.refresh, color: Colors.teal), onPressed: _generateMissionStrategy),
      IconButton(icon: const Icon(Icons.logout, color: Colors.grey), onPressed: () => FirebaseAuth.instance.signOut()),
    ],
  );

  Widget _buildAIStrategyCard() { /* Unchanged from your code */ }
  Widget _buildSearchBar() { /* Unchanged from your code */ }
  Widget _buildLiveNeedsStream() { /* Unchanged from your code */ }
  Color _getColorForUrgency(String urgency) { /* Unchanged from your code */ }
}