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
  bool _isAnalyzing = false;
  String _aiStrategy = "Fetching latest regional updates...";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generateMissionStrategy();
  }

  // --- AI MISSION STRATEGY (Mirroring Donor Map's News Logic) ---
  Future<void> _generateMissionStrategy() async {
    setState(() => _isAnalyzing = true);
    try {
      // 1. Fetch News for Context (Same as Donor Map)
      final resNews = await http.get(Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      String news = "General Malaysia news";
      if (resNews.statusCode == 200) {
        news = XmlDocument.parse(resNews.body).findAllElements('title').take(5).map((e) => e.innerText).join(". ");
      }

      // 2. Ask Gemini for Operational Strategy
      final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: dotenv.env['GEMINI_KEY']!);
      final prompt = """
      CONTEXT: $news
      NGO ROLE: Disaster Relief & Poverty Alleviation.
      TASK: Provide a 2-sentence 'Commanders Intent' or strategy for an NGO operating in Malaysia today. 
      Focus on logistics or high-risk areas mentioned in news.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _aiStrategy = response.text ?? "Focus on verified high-urgency zones.";
      });
    } catch (e) {
      _aiStrategy = "Maintain standby readiness for climate-related logistics.";
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("NGO Mission Hub", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.teal), onPressed: _generateMissionStrategy),
          IconButton(icon: const Icon(Icons.logout, color: Colors.grey), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: Column(
        children: [
          // 1. AI STRATEGY CARD (Mirroring the Search/News vibe)
          _buildAIStrategyCard(),

          // 2. SEARCH BAR (To filter their own reports)
          _buildSearchBar(),

          // 3. MISSION REVIEWS (Live Firestore Stream)
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
          
          Expanded(child: _buildLiveNeedsStream()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: _showAddNeedDialog,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text("Post Need", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAIStrategyCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade800, Colors.teal.shade600]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text("AI ADVISOR", style: TextStyle(color: Colors.teal.shade100, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
              const Spacer(),
              if (_isAnalyzing) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiStrategy,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Filter reports by location...",
          prefixIcon: const Icon(Icons.search, color: Colors.teal),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildLiveNeedsStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('needs')
          .where('ngoId', isEqualTo: user?.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Text("No active missions. Post a need to start.", style: TextStyle(color: Colors.grey.shade400)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final urgency = data['urgency'] ?? 'Medium';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _getColorForUrgency(urgency).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.warning_rounded, color: _getColorForUrgency(urgency)),
                ),
                title: Text(data['locationName'] ?? "Zone", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(data['description'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, py: 2),
                      decoration: BoxDecoration(color: _getColorForUrgency(urgency), borderRadius: BorderRadius.circular(12)),
                      child: Text(urgency, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.verified_user, color: Colors.green),
                  onPressed: () => _fulfillNeed(docs[index].id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getColorForUrgency(String urgency) {
    if (urgency == 'Critical') return Colors.redAccent;
    if (urgency == 'High') return Colors.orange;
    return Colors.teal;
  }

  // --- LOGIC ---

  void _fulfillNeed(String docId) async {
    await FirebaseFirestore.instance.collection('needs').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mission Fulfilled and marker removed.")));
  }

  void _showAddNeedDialog() {
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
            const Text("REPORT FIELD NEED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
            const SizedBox(height: 20),
            TextField(controller: loc, decoration: const InputDecoration(labelText: "Location (District, State)", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: desc, decoration: const InputDecoration(labelText: "Summary of Need", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: urgency,
              items: ['Critical', 'High', 'Medium'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => urgency = v!,
              decoration: const InputDecoration(labelText: "Urgency Level", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('needs').add({
                    'ngoId': user?.uid,
                    'locationName': loc.text,
                    'description': desc.text,
                    'urgency': urgency,
                    'createdAt': FieldValue.serverTimestamp(),
                    'lat': 4.21, // Use a geolocator in prod
                    'lng': 101.9,
                  });
                  Navigator.pop(context);
                },
                child: const Text("PUBLISH TO DONOR MAP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}