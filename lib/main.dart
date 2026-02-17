// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:syncfusion_flutter_maps/maps.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
//
// // --- CONFIG ---
// // Custom Emerald color to match the React/Tailwind UI
// const Color emeraldColor = Color(0xFF10B981);
// const Color donorPrimary = Color(0xFF059669);
// const Color ngoPrimary = Color(0xFF2563EB);
//
// // --- MODELS & MOCK DATA ---
// enum UserRole { donor, ngo }
//
// class Need {
//   final String location, category, desc, verifiedBy;
//   final int score;
//   final MapLatLng coords;
//   Need({
//     required this.location,
//     required this.category,
//     required this.desc,
//     required this.verifiedBy,
//     required this.score,
//     required this.coords
//   });
// }
//
// final List<Need> mockNeeds = [
//   Need(location: "Rantau Panjang, Kelantan", category: "Flood Relief", score: 92, verifiedBy: "MERCY Malaysia", desc: "Immediate need for clean water.", coords: const MapLatLng(6.0028, 101.9750)),
//   Need(location: "Baling, Kedah", category: "Food Security", score: 78, verifiedBy: "MyCARE", desc: "Dry food rations required.", coords: const MapLatLng(5.6766, 100.9167)),
// ];
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await dotenv.load(fileName: ".env");
//
//   try {
//     await Firebase.initializeApp(
//       options: FirebaseOptions(
//         apiKey: dotenv.env['FIREBASE_KEY']!,
//         appId: "1:922447048114:android:7ee1a2bd1c95c9322388ab",
//         messagingSenderId: "922447048114",
//         projectId: "silentsignalai-87900",
//         storageBucket: "silentsignalai-87900.firebasestorage.app",
//       ),
//     );
//   } catch (e) {
//     debugPrint("Firebase Error: $e");
//   }
//
//   runApp(const KitaCareApp());
// }
//
// class KitaCareApp extends StatelessWidget {
//   const KitaCareApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         fontFamily: 'Inter',
//         colorScheme: ColorScheme.fromSeed(seedColor: donorPrimary),
//       ),
//       home: const AuthWrapper(),
//     );
//   }
// }
//
// class AuthWrapper extends StatefulWidget {
//   const AuthWrapper({super.key});
//   @override
//   State<AuthWrapper> createState() => _AuthWrapperState();
// }
//
// class _AuthWrapperState extends State<AuthWrapper> {
//   UserRole? selectedRole;
//   bool isLocalLoggedIn = false; // Local flag to bypass Firebase for testing
//
//   @override
//   Widget build(BuildContext context) {
//     // If we have selected a role, show the MainShell
//     if (isLocalLoggedIn && selectedRole != null) {
//       return MainShell(role: selectedRole!);
//     }
//
//     // Otherwise, show the selection screen
//     return RoleSelectionScreen(onRoleSelected: (role) {
//       setState(() {
//         selectedRole = role;
//         isLocalLoggedIn = true; // Set to true so the screen switches
//       });
//       print("Role selected: $role");
//     });
//   }
// }
//
// // --- 1. ROLE SELECTION ---
// class RoleSelectionScreen extends StatelessWidget {
//   final Function(UserRole) onRoleSelected;
//   const RoleSelectionScreen({super.key, required this.onRoleSelected});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: NetworkImage('https://images.unsplash.com/photo-1548337138-e87d889cc369?q=80&w=1000'),
//             fit: BoxFit.cover,
//             colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Icon(Icons.favorite, color: emeraldColor, size: 50),
//               const SizedBox(height: 10),
//               const Text("KitaCare AI",
//                   style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
//               const Text("Rakyat Menjaga Rakyat.",
//                   style: TextStyle(color: Colors.tealAccent, fontSize: 24, fontStyle: FontStyle.italic)),
//               const SizedBox(height: 40),
//               _roleButton(context, "Individual Donor", "Track your impact", Icons.person, donorPrimary, UserRole.donor),
//               const SizedBox(height: 16),
//               _roleButton(context, "Malaysian NGO", "Manage field ops", Icons.business, ngoPrimary, UserRole.ngo),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _roleButton(BuildContext context, String title, String sub, IconData icon, Color color, UserRole role) {
//     return Material(
//       color: Colors.transparent, // Required for InkWell splash to show
//       child: InkWell(
//         onTap: () => onRoleSelected(role),
//         borderRadius: BorderRadius.circular(24),
//         child: Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.9),
//               borderRadius: BorderRadius.circular(24)
//           ),
//           child: Row(
//             children: [
//               CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
//               const SizedBox(width: 20),
//               Expanded(child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
//                     Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
//                   ]
//               )),
//               const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // --- 2. MAIN APP SHELL ---
// class MainShell extends StatefulWidget {
//   final UserRole role;
//   const MainShell({super.key, required this.role});
//   @override
//   State<MainShell> createState() => _MainShellState();
// }
//
// class _MainShellState extends State<MainShell> {
//   int _selectedIndex = 0;
//
//   @override
//   Widget build(BuildContext context) {
//     final color = widget.role == UserRole.donor ? donorPrimary : ngoPrimary;
//
//     final screens = [
//       widget.role == UserRole.donor ? const DonorDashboard() : const NGODashboard(),
//       const ReliefMap(),
//       AIAdvisor(role: widget.role),
//       const ImpactAnalytics(),
//     ];
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("KitaCare ${widget.role.name.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
//         backgroundColor: Colors.white,
//         elevation: 0,
//       ),
//       drawer: Drawer(
//         child: Column(
//           children: [
//             UserAccountsDrawerHeader(
//               decoration: BoxDecoration(color: color),
//               accountName: Text(widget.role == UserRole.donor ? "Ahmad S." : "MERCY Malaysia"),
//               accountEmail: Text(widget.role == UserRole.donor ? "Donor ID: KC-88" : "NGO ID: PPM-001"),
//               currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person)),
//             ),
//             _navItem(0, Icons.dashboard, "Mission Hub"),
//             _navItem(1, Icons.map, "Relief Map"),
//             _navItem(2, Icons.message, "AI Advisor"),
//             _navItem(3, Icons.bar_chart, "Impact Tracking"),
//             const Spacer(),
//             ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text("Logout"), onTap: () => FirebaseAuth.instance.signOut()),
//           ],
//         ),
//       ),
//       body: screens[_selectedIndex],
//     );
//   }
//
//   Widget _navItem(int index, IconData icon, String label) {
//     return ListTile(
//       leading: Icon(icon, color: _selectedIndex == index ? emeraldColor : Colors.grey),
//       title: Text(label, style: TextStyle(fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal)),
//       onTap: () => setState(() { _selectedIndex = index; Navigator.pop(context); }),
//     );
//   }
// }
//
// // --- 3. DONOR DASHBOARD ---
// class DonorDashboard extends StatelessWidget {
//   const DonorDashboard({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(20),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text("Hello, Ahmad", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//           const Text("Your contributions are reshaping lives.", style: TextStyle(color: Colors.grey)),
//           const SizedBox(height: 20),
//           Row(
//             children: [
//               _statCard("Impact Value", "RM 400.00", emeraldColor),
//               const SizedBox(width: 10),
//               _statCard("Lives Touched", "~120", Colors.blue),
//             ],
//           ),
//           const SizedBox(height: 30),
//           const Text("Active Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//           const SizedBox(height: 15),
//           _trackingCard(),
//         ],
//       ),
//     );
//   }
//
//   Widget _statCard(String label, String val, Color color) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.all(20),
//         decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
//         child: Column(children: [
//           Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
//           Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
//         ]),
//       ),
//     );
//   }
//
//   Widget _trackingCard() {
//     return Container(
//       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade200)),
//       child: Column(
//         children: [
//           const ListTile(title: Text("Kelantan Flood Relief", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Donation ID: KC-88421"), trailing: Chip(label: Text("In Transit"))),
//           Padding(
//             padding: const EdgeInsets.all(20.0),
//             child: Column(
//               children: [
//                 _timelineStep("Donation Received", "Oct 24", true),
//                 _timelineStep("Items Procured", "Oct 25", true),
//                 _timelineStep("Lorry Dispatched", "Oct 26", true),
//                 _timelineStep("Distribution at Site", "Est. Oct 27", false),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _timelineStep(String label, String date, bool done) {
//     return Row(
//       children: [
//         Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? emeraldColor : Colors.grey, size: 20),
//         const SizedBox(width: 15),
//         Expanded(child: Text(label, style: TextStyle(color: done ? Colors.black : Colors.grey, fontWeight: done ? FontWeight.bold : FontWeight.normal))),
//         Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
//       ],
//     );
//   }
// }
//
// // --- 4. NGO DASHBOARD ---
// class NGODashboard extends StatefulWidget {
//   const NGODashboard({super.key});
//   @override
//   State<NGODashboard> createState() => _NGODashboardState();
// }
//
// class _NGODashboardState extends State<NGODashboard> {
//   bool isVerified = false;
//   @override
//   Widget build(BuildContext context) {
//     if (!isVerified) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(40.0),
//           child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//             const Icon(Icons.lock, size: 64, color: Colors.blue),
//             const SizedBox(height: 20),
//             const Text("NGO Secure Console", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             const Text("Enter official project PIN to access operations.", textAlign: TextAlign.center),
//             const SizedBox(height: 20),
//             const TextField(obscureText: true, textAlign: TextAlign.center, decoration: InputDecoration(hintText: "PIN CODE")),
//             const SizedBox(height: 20),
//             ElevatedButton(onPressed: () => setState(() => isVerified = true), child: const Text("Verify & Access")),
//           ]),
//         ),
//       );
//     }
//     return const Center(child: Text("Operational Hub Active: Managed Zones List"));
//   }
// }
//
// // --- 5. AI ADVISOR ---
// class AIAdvisor extends StatefulWidget {
//   final UserRole role;
//   const AIAdvisor({super.key, required this.role});
//   @override
//   State<AIAdvisor> createState() => _AIAdvisorState();
// }
//
// class _AIAdvisorState extends State<AIAdvisor> {
//   final TextEditingController _controller = TextEditingController();
//   List<Map<String, String>> chatHistory = [];
//   bool isLoading = false;
//
//   Future<void> _sendMessage() async {
//     final userText = _controller.text;
//     if (userText.isEmpty) return;
//
//     setState(() {
//       chatHistory.add({"role": "user", "content": userText});
//       isLoading = true;
//       _controller.clear();
//     });
//
//     final model = GenerativeModel(model: 'gemini-3-flash-preview', apiKey: dotenv.env['GEMINI_KEY']!);
//
//     final systemPrompt = widget.role == UserRole.ngo
//         ? "You are KitaCare NGO AI. Help Malaysian NGOs with logistics and receipts. Use terms like 'ROS registration' and 'Inventory'."
//         : "You are KitaCare AI for Donors. Help Malaysians with transparency and item matching. Use terms like 'Sadaqah' and 'Impact Tracking'.";
//
//     final response = await model.generateContent([Content.text("$systemPrompt User: $userText")]);
//
//     setState(() {
//       chatHistory.add({"role": "ai", "content": response.text ?? "Error connecting to advisor."});
//       isLoading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Expanded(
//           child: ListView.builder(
//             padding: const EdgeInsets.all(20),
//             itemCount: chatHistory.length,
//             itemBuilder: (context, i) => _chatBubble(chatHistory[i]),
//           ),
//         ),
//         if (isLoading) const LinearProgressIndicator(),
//         Padding(
//           padding: const EdgeInsets.all(15.0),
//           child: Row(
//             children: [
//               Expanded(child: TextField(controller: _controller, decoration: const InputDecoration(hintText: "Ask KitaCare AI..."))),
//               IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send, color: emeraldColor)),
//             ],
//           ),
//         )
//       ],
//     );
//   }
//
//   Widget _chatBubble(Map<String, String> msg) {
//     bool isUser = msg['role'] == 'user';
//     return Align(
//       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 5),
//         padding: const EdgeInsets.all(15),
//         decoration: BoxDecoration(
//           color: isUser ? emeraldColor : Colors.grey.shade100,
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Text(msg['content']!, style: TextStyle(color: isUser ? Colors.white : Colors.black)),
//       ),
//     );
//   }
// }
//
// // --- 6. REMAINING SCREENS ---
// class ReliefMap extends StatelessWidget {
//   const ReliefMap({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return SfMaps(layers: [
//       MapTileLayer(
//         urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//         initialMarkersCount: mockNeeds.length,
//         markerBuilder: (ctx, i) => MapMarker(
//           latitude: mockNeeds[i].coords.latitude,
//           longitude: mockNeeds[i].coords.longitude,
//           child: const Icon(Icons.location_on, color: Colors.red),
//         ),
//       )
//     ]);
//   }
// }
//
// class ImpactAnalytics extends StatelessWidget {
//   const ImpactAnalytics({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return const Center(child: Text("Detailed Mission Operational Data"));
//   }
// }
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:lucide_icons/lucide_icons.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:qr_flutter/qr_flutter.dart';
//
// // ==========================================
// // 1. CONFIG & THEME
// // ==========================================
// const Color kEmerald = Color(0xFF059669);
// const Color kBlue = Color(0xFF2563EB);
// const Color kSlate800 = Color(0xFF1E293B);
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   // await Firebase.initializeApp(); // Uncomment after connecting your google-services.json
//   runApp(const KitaCareApp());
// }
//
// class KitaCareApp extends StatelessWidget {
//   const KitaCareApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'KitaCare AI',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         textTheme: GoogleFonts.interTextTheme(),
//         useMaterial3: true,
//       ),
//       home: const AuthWrapper(),
//     );
//   }
// }
//
// // ==========================================
// // 2. AUTHENTICATION & ROLE SELECTION
// // ==========================================
// class AuthWrapper extends StatefulWidget {
//   const AuthWrapper({super.key});
//
//   @override
//   State<AuthWrapper> createState() => _AuthWrapperState();
// }
//
// class _AuthWrapperState extends State<AuthWrapper> {
//   String view = 'selection'; // selection, login, signup
//   String? selectedRole; // donor, ngo
//
//   // Controllers for Sign Up
//   final TextEditingController _nameController = TextEditingController();
//   final TextEditingController _emailController = TextEditingController();
//   final TextEditingController _idController = TextEditingController();
//   final TextEditingController _regController = TextEditingController(); // For NGO
//   final TextEditingController _passController = TextEditingController();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Background Image Logic
//           Container(
//             decoration: const BoxDecoration(
//               image: DecorationImage(
//                 image: NetworkImage("https://images.unsplash.com/photo-1548337138-e87d889cc369?q=80&w=2000"),
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           Container(color: Colors.black.withOpacity(0.6)),
//
//           SafeArea(
//             child: SingleChildScrollView( // Added to prevent keyboard overflow
//               padding: const EdgeInsets.symmetric(horizontal: 24.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 60),
//                   _buildBranding(),
//                   const SizedBox(height: 100), // Spacing logic
//                   _buildAuthCard(),
//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Same branding as before
//   Widget _buildBranding() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(color: kEmerald, borderRadius: BorderRadius.circular(16)),
//               child: const Icon(LucideIcons.heart, color: Colors.white, size: 28),
//             ),
//             const SizedBox(width: 12),
//             Text("KitaCare AI", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 32)),
//           ],
//         ),
//         const SizedBox(height: 16),
//         const Text("Rakyat Menjaga Rakyat.", style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
//         const Text("The Malaysian disaster relief ecosystem powered by AI.", style: TextStyle(color: Colors.white70, fontSize: 16)),
//       ],
//     );
//   }
//
//   Widget _buildAuthCard() {
//     return Container(
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(32),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
//       ),
//       child: AnimatedSwitcher(
//         duration: const Duration(milliseconds: 300),
//         child: _getCurrentView(),
//       ),
//     );
//   }
//
//   Widget _getCurrentView() {
//     if (view == 'selection') return _selectionView();
//     if (view == 'login') return _loginView();
//     return _signUpView(); // Show Sign Up if view is 'signup'
//   }
//
//   // 1. SELECTION VIEW
//   Widget _selectionView() {
//     return Column(
//       key: const ValueKey('selection'),
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text("Selamat Datang", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//         const Text("Select your account type to continue", style: TextStyle(color: Colors.grey)),
//         const SizedBox(height: 24),
//         _roleBtn("Individual Donor", "Track impact of your contributions", LucideIcons.user, kEmerald, () => _toView('login', 'donor')),
//         const SizedBox(height: 12),
//         _roleBtn("Malaysian NGO", "Manage field ops & verified needs", LucideIcons.building2, kBlue, () => _toView('login', 'ngo')),
//         const SizedBox(height: 20),
//         const Center(child: Text("COMPLIANCE WITH MALAYSIA ROS/SSM REGULATIONS", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold))),
//       ],
//     );
//   }
//
//   // 2. LOGIN VIEW
//   Widget _loginView() {
//     final themeColor = selectedRole == 'ngo' ? kBlue : kEmerald;
//     return Column(
//       key: const ValueKey('login'),
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Row(children: [
//           IconButton(onPressed: () => setState(() => view = 'selection'), icon: const Icon(LucideIcons.chevronLeft, size: 20)),
//           Text("${selectedRole?.toUpperCase()} LOGIN", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//         ]),
//         const SizedBox(height: 24),
//         _buildTextField("Email Address", LucideIcons.send, _emailController),
//         const SizedBox(height: 16),
//         _buildTextField("Password", LucideIcons.lock, _passController, obscure: true),
//         const SizedBox(height: 24),
//         _buildActionButton("Sign In", themeColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppShell(role: selectedRole!)))),
//         const SizedBox(height: 16),
//         TextButton(
//           onPressed: () => setState(() => view = 'signup'),
//           child: Text.rich(TextSpan(children: [
//             const TextSpan(text: "Don't have an account? ", style: TextStyle(color: Colors.grey)),
//             TextSpan(text: "Create New Account", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
//           ])),
//         )
//       ],
//     );
//   }
//
//   // 3. SIGN UP VIEW (The missing part)
//   Widget _signUpView() {
//     final themeColor = selectedRole == 'ngo' ? kBlue : kEmerald;
//     return Column(
//       key: const ValueKey('signup'),
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(children: [
//           IconButton(onPressed: () => setState(() => view = 'login'), icon: const Icon(LucideIcons.chevronLeft, size: 20)),
//           const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//         ]),
//         const Padding(
//           padding: EdgeInsets.only(left: 48, bottom: 20),
//           child: Text("Provide official details to verify identity.", style: TextStyle(color: Colors.grey, fontSize: 12)),
//         ),
//         _buildTextField(selectedRole == 'ngo' ? "Official NGO Name" : "Full Name as per MyKad", LucideIcons.user, _nameController),
//         if (selectedRole == 'ngo') ...[
//           const SizedBox(height: 16),
//           _buildTextField("ROS/SSM Reg No", LucideIcons.shieldCheck, _regController),
//         ],
//         const SizedBox(height: 16),
//         _buildTextField("Identity ID (MyKad/Passport)", LucideIcons.receipt, _idController),
//         const SizedBox(height: 16),
//         _buildTextField("Official Email", LucideIcons.send, _emailController),
//         const SizedBox(height: 16),
//         _buildTextField("Secure Password", LucideIcons.lock, _passController, obscure: true),
//         const SizedBox(height: 24),
//         _buildActionButton("Register Account", themeColor, () => Navigator.push(context, MaterialPageRoute(builder: (_) => AppShell(role: selectedRole!)))),
//       ],
//     );
//   }
//
//   // Helper methods to keep code clean
//   void _toView(String v, String r) => setState(() { view = v; selectedRole = r; });
//
//   Widget _buildTextField(String hint, IconData icon, TextEditingController controller, {bool obscure = false}) {
//     return TextField(
//       controller: controller,
//       obscureText: obscure,
//       decoration: InputDecoration(
//         hintText: hint,
//         hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
//         prefixIcon: Icon(icon, size: 18, color: Colors.grey),
//         filled: true,
//         fillColor: const Color(0xFFF8FAFC),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
//       ),
//     );
//   }
//
//   Widget _buildActionButton(String label, Color color, VoidCallback tap) {
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton(
//         onPressed: tap,
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color,
//           foregroundColor: Colors.white,
//           elevation: 4,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         ),
//         child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//       ),
//     );
//   }
//
//   Widget _roleBtn(String title, String sub, IconData icon, Color color, VoidCallback tap) {
//     bool isSelected = selectedRole == (title.contains("Donor") ? "donor" : "ngo");
//     return InkWell(
//       onTap: tap,
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.05),
//           border: Border.all(color: isSelected ? color : color.withOpacity(0.1), width: 1.5),
//           borderRadius: BorderRadius.circular(20),
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
//               child: Icon(icon, color: Colors.white, size: 20),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                   Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 11)),
//                 ],
//               ),
//             ),
//             Icon(LucideIcons.arrowRight, color: color, size: 18),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ==========================================
// // 3. MAIN APP SHELL (NAVIGATION)
// // ==========================================
// class AppShell extends StatefulWidget {
//   final String role;
//   const AppShell({super.key, required this.role});
//
//   @override
//   State<AppShell> createState() => _AppShellState();
// }
//
// class _AppShellState extends State<AppShell> {
//   int _index = 0;
//
//   @override
//   Widget build(BuildContext context) {
//     final themeColor = widget.role == 'ngo' ? kBlue : kEmerald;
//     final List<Widget> pages = [
//       widget.role == 'ngo' ? const NGODashboard() : const DonorDashboard(),
//       const ReliefMap(),
//       AIAdvisor(role: widget.role),
//       const AnalyticsPage(),
//     ];
//
//     return Scaffold(
//       body: pages[_index],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _index,
//         onTap: (v) => setState(() => _index = v),
//         selectedItemColor: themeColor,
//         unselectedItemColor: Colors.grey,
//         type: BottomNavigationBarType.fixed,
//         items: [
//           const BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Hub"),
//           const BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Map"),
//           const BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI"),
//           const BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "Data"),
//         ],
//       ),
//     );
//   }
// }
//
// // ==========================================
// // 4. DONOR DASHBOARD & TRACKING
// // ==========================================
// class DonorDashboard extends StatelessWidget {
//   const DonorDashboard({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 40),
//           const Text("Hello, Ahmad", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
//           const Text("Impact: RM 400.00 • 120 Lives Touched", style: TextStyle(color: kEmerald, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 32),
//           const SectionTitle(title: "Active Tracking", icon: LucideIcons.history, color: kEmerald),
//           _buildTrackingCard(),
//           const SizedBox(height: 24),
//           _buildTrackingCard(isItem: true),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTrackingCard({bool isItem = false}) {
//     return Container(
//       margin: const EdgeInsets.only(top: 16),
//       decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.withOpacity(0.1))),
//       child: Column(
//         children: [
//           ListTile(
//             leading: Icon(isItem ? LucideIcons.package : LucideIcons.banknote, color: isItem ? kBlue : kEmerald),
//             title: Text(isItem ? "Keningau Learning Center" : "Kelantan Flood Relief", style: const TextStyle(fontWeight: FontWeight.bold)),
//             subtitle: const Text("Status: In Transit", style: TextStyle(color: kEmerald, fontSize: 12, fontWeight: FontWeight.bold)),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(16),
//               child: Image.network(isItem ? "https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400" : "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400", height: 120, width: double.infinity, fit: BoxFit.cover),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ==========================================
// // 5. AI ADVISOR (GEMINI)
// // ==========================================
// class AIAdvisor extends StatefulWidget {
//   final String role;
//   const AIAdvisor({super.key, required this.role});
//
//   @override
//   State<AIAdvisor> createState() => _AIAdvisorState();
// }
//
// class _AIAdvisorState extends State<AIAdvisor> {
//   final List<Map<String, String>> messages = [];
//   final TextEditingController _ctrl = TextEditingController();
//
//   void sendMessage() async {
//     final text = _ctrl.text;
//     if (text.isEmpty) return;
//     setState(() {
//       messages.add({"role": "user", "content": text});
//       _ctrl.clear();
//     });
//     // Simulate AI delay
//     await Future.delayed(const Duration(seconds: 1));
//     setState(() {
//       messages.add({"role": "ai", "content": "I am looking into this for you. Based on current data from MERCY Malaysia, the most urgent need is at Rantau Panjang."});
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final themeColor = widget.role == 'ngo' ? kBlue : kEmerald;
//     return Scaffold(
//       appBar: AppBar(title: Text("KitaCare ${widget.role.toUpperCase()} AI", style: const TextStyle(fontWeight: FontWeight.bold))),
//       body: Column(
//         children: [
//           Expanded(
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: messages.length,
//               itemBuilder: (context, i) {
//                 final isUser = messages[i]['role'] == 'user';
//                 return Align(
//                   alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//                   child: Container(
//                     margin: const EdgeInsets.symmetric(vertical: 4),
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: isUser ? themeColor : Colors.grey[200],
//                       borderRadius: BorderRadius.circular(16).copyWith(topRight: isUser ? Radius.zero : const Radius.circular(16), topLeft: isUser ? const Radius.circular(16) : Radius.zero),
//                     ),
//                     child: Text(messages[i]['content']!, style: TextStyle(color: isUser ? Colors.white : Colors.black)),
//                   ),
//                 );
//               },
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: "Ask KitaCare AI...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))))),
//                 const SizedBox(width: 8),
//                 CircleAvatar(backgroundColor: themeColor, child: IconButton(onPressed: sendMessage, icon: const Icon(LucideIcons.send, color: Colors.white))),
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
//
// // ==========================================
// // 6. RELIEF HEATMAP (Simulation)
// // ==========================================
// class ReliefMap extends StatelessWidget {
//   const ReliefMap({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Simulated Map
//           Container(
//             decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1548337138-e87d889cc369?q=80&w=1200"), fit: BoxFit.cover)),
//           ),
//           // Markers
//           _marker(top: 200, left: 150, color: Colors.red, label: "92% Critical"),
//           _marker(top: 400, left: 250, color: Colors.orange, label: "78% Moderate"),
//
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
//                     child: const Row(
//                       children: [
//                         Icon(LucideIcons.mapPin, color: kEmerald),
//                         SizedBox(width: 12),
//                         Text("Active Disaster Zones", style: TextStyle(fontWeight: FontWeight.bold)),
//                       ],
//                     ),
//                   )
//                 ],
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }
//
//   Widget _marker({required double top, required double left, required Color color, required String label}) {
//     return Positioned(
//       top: top,
//       left: left,
//       child: Column(
//         children: [
//           Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
//           Icon(LucideIcons.alertCircle, color: color, size: 32),
//         ],
//       ),
//     );
//   }
// }
//
// // ==========================================
// // UTILS & COMPONENTS
// // ==========================================
// class SectionTitle extends StatelessWidget {
//   final String title;
//   final IconData icon;
//   final Color color;
//   const SectionTitle({super.key, required this.title, required this.icon, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 20, color: color),
//         const SizedBox(width: 8),
//         Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
//       ],
//     );
//   }
// }
//
// class NGODashboard extends StatelessWidget {
//   const NGODashboard({super.key});
//   @override
//   Widget build(BuildContext context) => const Center(child: Text("NGO Operational View"));
// }
//
// class AnalyticsPage extends StatelessWidget {
//   const AnalyticsPage({super.key});
//   @override
//   Widget build(BuildContext context) => const Center(child: Text("Mission Analytics View"));
// }
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert'; // For parsing AI JSON
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Ensure you have run 'dart pub global run flutterfire_cli:flutterfire configure'
import 'firebase_options.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


// ==========================================
// 1. CONFIG & THEME
// ==========================================
const Color kEmerald = Color(0xFF059669);
const Color kBlue = Color(0xFF2563EB);
const Color kSlate800 = Color(0xFF1E293B);
const Color kSlate400 = Color(0xFF94A3B8);
const Color kSlate300 = Color(0xFFCBD5E1);
const Color kSlate50 = Color(0xFFF8FAFC);
const Color kSlate500 = Color(0xFF64748B);
const Color kSlate100 = Color(0xFFF1F5F9);


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("DotEnv loaded successfully");
  } catch (e) {
    print("DotEnv Load Error: $e");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const KitaCareApp());
}

class KitaCareApp extends StatelessWidget {
  const KitaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitaCare AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// ==========================================
// 2. AUTHENTICATION & UI (RESTORED DESIGN)
// ==========================================
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String view = 'selection'; // selection, login, signup
  String? selectedRole; // donor, ngo
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _regController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // FIREBASE LOGIC
  // Future<void> _handleAuth() async {
  //   if (_emailController.text.isEmpty || _passController.text.isEmpty) return;
  //   setState(() => _isLoading = true);
  //
  //   try {
  //     if (view == 'signup') {
  //       UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  //         email: _emailController.text.trim(),
  //         password: _passController.text.trim(),
  //       );
  //
  //       await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
  //         'name': _nameController.text.trim(),
  //         'role': selectedRole,
  //         'email': _emailController.text.trim(),
  //         'idNumber': _idController.text.trim(),
  //         'regNo': selectedRole == 'ngo' ? _regController.text.trim() : '',
  //       });
  //       _navigateToApp(_nameController.text.trim());
  //     } else {
  //       UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
  //         email: _emailController.text.trim(),
  //         password: _passController.text.trim(),
  //       );
  //
  //       DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).get();
  //       _navigateToApp(doc['name'] ?? "User");
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  //   } finally {
  //     setState(() => _isLoading = false);
  //   }
  // }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- UPDATED AUTH LOGIC WITH ROLE PROTECTION ---
  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      if (view == 'signup') {
        // ... (Keep your existing sign-up logic here)
      } else {
        // 1. SIGN IN
        UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        // 2. FETCH ROLE FROM FIRESTORE
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .get();

        if (doc.exists) {
          String dbRole = doc['role']; // The role saved in Database

          // 3. SECURITY CHECK: Compare DB Role with Selected UI Role
          if (dbRole != selectedRole) {
            // Role Mismatch! Logout immediately.
            await FirebaseAuth.instance.signOut();
            _showError("Access Denied: This account is registered as a ${dbRole.toUpperCase()}.");
            return;
          }

          // Role Matches! Proceed.
          _navigateToApp(doc['name'] ?? "User");
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Authentication failed.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToApp(String name) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AppShell(role: selectedRole!, userName: name)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image (Restored Design)
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage("https://images.unsplash.com/photo-1548337138-e87d889cc369?q=80&w=2000"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.6)),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  _buildBranding(),
                  const SizedBox(height: 100),
                  _buildAuthCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kEmerald,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.heart, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Text(
              "KitaCare AI",
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 32,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          "Rakyat Menjaga Rakyat.",
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "The Malaysian disaster relief ecosystem powered by AI. Transparency, real-time logistics, and verified impact.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 24),
        // --- ADDED BUTTONS START HERE ---
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFeatureBadge(
              "VERIFIED ROS/SSM NGOS",
              LucideIcons.shieldCheck,
              kEmerald,
            ),
            _buildFeatureBadge(
              "REAL-TIME RELIEF MAP",
              LucideIcons.zap,
              kBlue,
            ),
          ],
        ),
        // --- ADDED BUTTONS END HERE ---
      ],
    );
  }

  // Helper method to create the pill-shaped badges
  Widget _buildFeatureBadge(String label, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Semi-transparent background
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)), // Subtle border
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)]),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: view == 'selection' ? _selectionView() : (view == 'login' ? _loginView() : _signUpView()),
      ),
    );
  }

  Widget _selectionView() {
    return Column(
      key: const ValueKey('selection'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Selamat Datang", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const Text("Select account type to continue", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        // Donor Button - Border turns Emerald when selected
        _roleBtn(
          "Individual Donor",
          "Track impact of your contributions",
          LucideIcons.user,
          kEmerald,
              () => setState(() => selectedRole = 'donor'),
          isSelected: selectedRole == 'donor',
        ),

        const SizedBox(height: 12),

        // NGO Button - Border turns Blue when selected
        _roleBtn(
          "Malaysian NGO",
          "Manage field ops & verified needs",
          LucideIcons.building2,
          kBlue,
              () => setState(() => selectedRole = 'ngo'),
          isSelected: selectedRole == 'ngo',
        ),

        const SizedBox(height: 32),

        // "Continue" button appears only after selection
        if (selectedRole != null)
          _buildActionButton(
            "Continue to Login",
            selectedRole == 'ngo' ? kBlue : kEmerald,
                () => setState(() => view = 'login'),
            hasIcon: true,
          ),
      ],
    );
  }

  Widget _loginView() {
    final themeColor = selectedRole == 'ngo' ? kBlue : kEmerald;
    return Column(
      key: const ValueKey('login'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => view = 'selection'), icon: const Icon(LucideIcons.chevronLeft, size: 20, color: kSlate400)),
            const SizedBox(width: 4),
            Text("${selectedRole?.toUpperCase()} LOGIN", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: kSlate800)),
          ],
        ),
        const SizedBox(height: 24),
        _buildLabeledField("Email Address", LucideIcons.send, _emailController),
        const SizedBox(height: 16),
        _buildLabeledField("Password", LucideIcons.lock, _passController, obscure: true),
        const SizedBox(height: 32),
        _buildActionButton("Sign In", themeColor, _handleAuth),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() => view = 'signup'),
            child: Text.rich(TextSpan(text: "Don't have an account? ", style: const TextStyle(color: Colors.grey, fontSize: 13), children: [TextSpan(text: "Create New Account", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold))])),
          ),
        ),
      ],
    );
  }

  Widget _signUpView() {
    final themeColor = selectedRole == 'ngo' ? kBlue : kEmerald;
    return Column(
      key: const ValueKey('signup'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(onPressed: () => setState(() => view = 'login'), icon: const Icon(LucideIcons.chevronLeft, size: 20, color: kSlate400)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text("NEW ${selectedRole?.toUpperCase()} REGISTRATION", style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text("Create Account", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: kSlate800)),
        const Text("Provide official details to verify your identity.", style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 32),
        _buildLabeledField("OFFICIAL NAME", LucideIcons.user, _nameController, hint: selectedRole == 'ngo' ? "Official NGO Name (MERCY Malaysia)" : "Full Name as per MyKad"),
        const SizedBox(height: 16),
        if (selectedRole == 'ngo') ...[
          _buildLabeledField("REGISTRATION NUMBER (ROS/SSM)", LucideIcons.shieldCheck, _regController, hint: "PPM-001-10-XXXX"),
          const SizedBox(height: 16),
        ],
        _buildLabeledField("IDENTITY ID (MYKAD/PASSPORT)", LucideIcons.receipt, _idController, hint: "XXXXXX-XX-XXXX"),
        const SizedBox(height: 16),
        _buildLabeledField("OFFICIAL EMAIL", LucideIcons.send, _emailController, hint: "contact@email.com"),
        const SizedBox(height: 16),
        _buildLabeledField("SECURE PASSWORD", LucideIcons.lock, _passController, obscure: true, hint: "••••••••"),
        const SizedBox(height: 32),
        _buildActionButton("Register Account", themeColor, _handleAuth, hasIcon: true),
      ],
    );
  }

  Widget _buildLabeledField(String label, IconData icon, TextEditingController ctrl, {bool obscure = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint ?? label,
            hintStyle: const TextStyle(color: kSlate300, fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: kSlate300),
            filled: true,
            fillColor: kSlate50,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: selectedRole == 'ngo' ? kBlue : kEmerald, width: 2)),
          ),
        ),
      ],
    );
  }

  // UI Helpers
  Widget _buildTextField(String hint, IconData icon, TextEditingController ctrl, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 18), filled: true, fillColor: const Color(0xFFF8FAFC), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback tap, {bool hasIcon = false}) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]),
      child: ElevatedButton(
        onPressed: tap,
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (hasIcon) ...[const SizedBox(width: 8), const Icon(LucideIcons.arrowRight, size: 20)]
          ],
        ),
      ),
    );
  }

  // Widget _roleBtn(String title, String sub, IconData icon, Color color, VoidCallback tap) {
  //   return InkWell(
  //     onTap: tap,
  //     child: Container(
  //       padding: const EdgeInsets.all(16),
  //       decoration: BoxDecoration(color: color.withOpacity(0.05), border: Border.all(color: color.withOpacity(0.1)), borderRadius: BorderRadius.circular(20)),
  //       child: Row(
  //         children: [
  //           Icon(icon, color: color),
  //           const SizedBox(width: 16),
  //           Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey))])),
  //           Icon(LucideIcons.arrowRight, color: color, size: 18),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _roleBtn(String title, String sub, IconData icon, Color color, VoidCallback tap, {required bool isSelected}) {
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Background gets a slight tint of the role color when selected
          color: isSelected ? color.withOpacity(0.08) : color.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            // Logic: If selected, use full role color (Emerald or Blue), else use a very faint version
            color: isSelected ? color : color.withOpacity(0.1),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            // Icon Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 20),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : kSlate800,
                      fontSize: 16
                  )),
                  Text(sub, style: TextStyle(
                      color: isSelected ? color.withOpacity(0.7) : Colors.grey,
                      fontSize: 11
                  )),
                ],
              ),
            ),
            // Change Arrow to Checkmark when selected
            Icon(
                isSelected ? LucideIcons.checkCircle2 : LucideIcons.arrowRight,
                color: color,
                size: 18
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. MAIN APP (SHELL WITH BOTTOM NAV)
// ==========================================
class AppShell extends StatefulWidget {
  final String role;
  final String userName;
  const AppShell({super.key, required this.role, required this.userName});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // CUSTOM LOGO WIDGET (Matching your image)
  Widget _buildBrandLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kEmerald, // Your green color
            borderRadius: BorderRadius.circular(12), // Rounded square
          ),
          child: const Icon(
            LucideIcons.heart,
            color: Colors.white,
            size: 20,
            fill: 1.0, // Solid heart
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: "KitaCare ", style: TextStyle(color: kSlate800)),
              TextSpan(text: "AI", style: const TextStyle(color: kEmerald)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.role == 'ngo' ? kBlue : kEmerald;

    final List<Widget> pages = [
      DonorDashboard(userName: widget.userName),
      const ReliefMap(),
      const Center(child: Text("AI Advisor")),
      const Center(child: Text("My Impact")),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _buildBrandLogo(), // Use the custom logo widget
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen(userName: widget.userName)),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kSlate50,
                  shape: BoxShape.circle,
                  border: Border.all(color: kSlate100),
                ),
                child: const Icon(LucideIcons.user, color: kSlate800, size: 20),
              ),
            ),
          ),
          // Optional: A quick logout button next to profile
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // THIS IS THE FIX: Clear everything and go back to selection
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                    (route) => false,
              );
            },
            icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kSlate100, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (v) => setState(() => _index = v),
          selectedItemColor: themeColor,
          unselectedItemColor: kSlate400,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
            BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
            BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "Impact"),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final String userName;
  const ProfileScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: kSlate800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // User Avatar & Name
            CircleAvatar(
              radius: 40,
              backgroundColor: kEmerald.withOpacity(0.1),
              child: Text(userName[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kEmerald)),
            ),
            const SizedBox(height: 16),
            Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user?.email ?? "email@example.com", style: const TextStyle(color: kSlate400)),

            const SizedBox(height: 40),

            // Settings List
          // FIX FOR EMAIL
            _profileOption(
              icon: LucideIcons.mail,
              title: "Update Email",
              onTap: () => _showUpdateDialog(
                context,
                "Email",
                    (newEmail) async {
                  final user = FirebaseAuth.instance.currentUser;

                  // 1. MANUAL UNIQUENESS CHECK: Check if email exists in Firestore
                  final result = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: newEmail)
                      .get();

                  if (result.docs.isNotEmpty) {
                    // Throw a custom error so the catch block handles it
                    throw FirebaseAuthException(
                        code: 'email-already-in-use',
                        message: 'This email is already registered by another user.'
                    );
                  }

                  // 2. THE UPDATE: Since updateEmail is deleted from the SDK,
                  // we MUST use verifyBeforeUpdateEmail.
                  // Note: This IS the only method currently available in the SDK.
                  await user?.verifyBeforeUpdateEmail(newEmail);

                  // 3. SYNC TO FIRESTORE
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .update({'email': newEmail});
                },
              ),
            ),

          // FIX FOR PASSWORD
          _profileOption(
            icon: LucideIcons.lock,
            title: "Change Password",
            onTap: () => _showUpdateDialog(
              context,
              "Password",
                  (val) async => await user?.updatePassword(val), // Keep this but make it async
            ),
          ),
            const Divider(height: 40),
            _profileOption(
              icon: LucideIcons.logOut,
              title: "Logout",
              color: Colors.red,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // THIS IS THE FIX: Clear everything and go back to selection
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileOption({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? kSlate800, size: 20),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? kSlate800)),
      trailing: const Icon(LucideIcons.chevronRight, size: 16, color: kSlate400),
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
    );
  }

  // Generic Dialog for Updates
  // Update the signature to: Future<void> Function(String)
  void _showUpdateDialog(BuildContext context, String type, Future<void> Function(String) onUpdate) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Update $type", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Enter new $type",
            filled: true,
            fillColor: kSlate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          obscureText: type == "Password",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                String val = controller.text.trim();
                if (val.isEmpty) return;

                await onUpdate(val);

                Navigator.pop(context);

                // Custom message based on type
                String successMsg = type == "Email"
                    ? "Checking email... Link sent for verification."
                    : "Password updated!";

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
              } on FirebaseAuthException catch (e) {
                // This catches the 'email-already-in-use' error we threw manually
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? "An error occurred"), backgroundColor: Colors.redAccent),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }
}

// ==========================================
// 4. DONOR DASHBOARD (WITH BALANCE & TOP-UP)
// ==========================================
class DonorDashboard extends StatelessWidget {
  final String userName;
  const DonorDashboard({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          var userData = userSnapshot.data?.data() as Map<String, dynamic>?;

          // DYNAMIC FIELDS FROM FIREBASE
          String impact = userData?['impactValue']?.toString() ?? "0.00";
          String lives = userData?['livesTouched']?.toString() ?? "0";
          double balance = (userData?['walletBalance'] ?? 0.0).toDouble(); // NEW: BALANCE FIELD

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hello, $userName",
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: kSlate800)
                ),
                const Text("Empowering Malaysian communities through KitaCare AI.",
                    style: TextStyle(color: kSlate500, fontSize: 14)
                ),
                const SizedBox(height: 24),

                // 1. STATS ROW (Now includes Balance)
                Row(
                  children: [
                    _statBox("WALLET BALANCE", "RM ${balance.toStringAsFixed(2)}", kEmerald),
                    const SizedBox(width: 8), // Smaller spacing to fit 3 cards
                    _statBox("IMPACT VALUE", "RM $impact", kBlue),
                    const SizedBox(width: 8),
                    _statBox("LIVES TOUCHED", "~$lives", const Color(0xFF6366F1)), // Indigo color for Lives
                  ],
                ),

                const SizedBox(height: 32),
                const Row(
                  children: [
                    Icon(LucideIcons.history, color: kEmerald, size: 18),
                    SizedBox(width: 8),
                    Text("Active Tracking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate800)),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. DYNAMIC DONATIONS LIST
                StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('donations')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _emptyState("No active donations found.");
                      }
                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return _buildTrackingCardFromData(data);
                        }).toList(),
                      );
                    }
                ),

                const SizedBox(height: 24),

                // 3. UPDATED WALLET SECTION (With Top-Up)
                _buildWalletSection(uid, context, balance),

                const SizedBox(height: 40),
              ],
            ),
          );
        }
    );
  }

  Widget _buildWalletSection(String uid, BuildContext context, double currentBalance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: kSlate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.wallet, color: kEmerald, size: 20),
                  const SizedBox(width: 12),
                  Text("KitaCare Wallet", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: kSlate800)),
                ],
              ),
              GestureDetector(
                onTap: () => _showAddWalletDialog(context, uid),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: kEmerald.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(LucideIcons.plus, color: kEmerald, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic List of Bank Accounts
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('wallet').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _emptyState("No accounts linked.");
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return _walletItem(data['bankName'] ?? "Bank", doc.id, uid);
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),

          // NEW: TOP UP BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTopUpDialog(context, uid),
              icon: const Icon(LucideIcons.arrowUpCircle, size: 18),
              label: const Text("Top Up Funds", style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _securityBanner(),
        ],
      ),
    );
  }

  // NEW: FUNCTION TO ADD MONEY TO THE WALLET
  void _showTopUpDialog(BuildContext context, String uid) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Top Up Wallet", style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter amount to transfer from your linked bank account.", style: TextStyle(fontSize: 12, color: kSlate500)),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kEmerald),
              decoration: InputDecoration(
                prefixText: "RM ",
                hintText: "0.00",
                filled: true,
                fillColor: kSlate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double amount = double.tryParse(amountController.text) ?? 0.0;
              if (amount > 0) {
                // UPDATE FIREBASE BALANCE
                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                  'walletBalance': FieldValue.increment(amount),
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Confirm Top Up"),
          )
        ],
      ),
    );
  }

  Widget _securityBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kEmerald.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, color: kEmerald, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text("Secured by Malaysian Banking AI Standards.", style: TextStyle(color: kEmerald.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _walletItem(String bankName, String docId, String uid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSlate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSlate100.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.banknote, size: 16, color: kSlate400),
          const SizedBox(width: 16),
          Text(
            bankName,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: kSlate800),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              // Dynamic delete from Firebase
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('wallet')
                  .doc(docId)
                  .delete();
            },
            child: Icon(LucideIcons.trash2, size: 16, color: kSlate300),
          ),
        ],
      ),
    );
  }

  // Visual layout matching the website card
  Widget _buildTrackingCard({
    required String id,
    required String target,
    required String status,
    required bool isItem,
    required String img,
    required List<dynamic> milestones, // Milestones are now dynamic!
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kSlate100)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: (isItem ? kBlue : kEmerald).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(isItem ? LucideIcons.package : LucideIcons.banknote, color: isItem ? kBlue : kEmerald, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(id, style: const TextStyle(color: kSlate400, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text(target, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kSlate800)),
                    ],
                  )
                ],
              ),
              _statusChip(status, isItem ? kBlue : kEmerald),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Timeline
              Expanded(
                child: Column(
                  children: milestones.map((m) {
                    return _timelineItem(
                        m['label'] ?? "Step",
                        m['date'] ?? "",
                        m['done'] ?? false
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(img, width: 100, height: 80, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(width: 100, height: 80, color: kSlate100, child: Icon(Icons.image_not_supported)),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _timelineItem(String label, String sub, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2, size: 14, color: done ? kEmerald : kSlate100),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: done ? kSlate800 : kSlate400)),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 9, color: kSlate400)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kSlate100, style: BorderStyle.solid)),
      child: Center(child: Text(message, style: const TextStyle(color: kSlate400, fontSize: 12))),
    );
  }

  // Data mapping from Firestore
  Widget _buildTrackingCardFromData(Map<String, dynamic> data) {
    return _buildTrackingCard(
      id: data['id'] ?? "ID-UNKNOWN",
      target: data['target'] ?? "Aid Project",
      status: data['status'] ?? "Processing",
      isItem: data['type'] == 'item',
      img: data['imageUrl'] ?? "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400",
      milestones: data['milestones'] ?? [], // This maps the dynamic list from Firebase
    );
  }

  // Stat box helper
  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSlate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: kSlate400, // Light slate/gray for label
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox( // Ensures text scales down instead of overflowing on small screens
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color, // Dynamic color (Emerald or Blue)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  // NEW: FUNCTION TO SHOW ADD DIALOG
  void _showAddWalletDialog(BuildContext context, String uid) {
    final TextEditingController bankController = TextEditingController();
    final TextEditingController accountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("Link New Account",
            style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: kSlate800)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField("Bank Name", LucideIcons.building2, bankController, "e.g. Maybank"),
            const SizedBox(height: 16),
            _buildDialogField("Account Number", LucideIcons.hash, accountController, "xxxx-xxxx-xxxx"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: kSlate400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (bankController.text.isNotEmpty && accountController.text.isNotEmpty) {
                // SAVE TO FIREBASE
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('wallet')
                    .add({
                  'bankName': bankController.text.trim(),
                  'accountNumber': accountController.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Link Account"),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(String label, IconData icon, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kSlate400)
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
            filled: true,
            fillColor: kSlate50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class NGODashboard extends StatelessWidget {
  const NGODashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text("Official Relief Hub", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: kSlate800)),
          const Text("MERCY Malaysia • Operational Status: ACTIVE", style: TextStyle(color: kBlue, fontWeight: FontWeight.bold)),

          const SizedBox(height: 32),

          // Operational Stats
          Row(
            children: [
              _ngoStat("ACTIVE ZONES", "04", kBlue),
              const SizedBox(width: 12),
              _ngoStat("DISBURSED", "RM 12.5k", kEmerald),
            ],
          ),

          const SizedBox(height: 32),
          const SectionTitle(title: "Managed Disaster Zones", icon: LucideIcons.mapPin, color: kBlue),
          const SizedBox(height: 16),

          // Managed Zone Card
          _managedZoneCard("Rantau Panjang, Kelantan", "Monitoring", 92),
          _managedZoneCard("Baling, Kedah", "Relief Dispatched", 78),

          const SizedBox(height: 32),
          _ngoActionButton("Publish New Field Report", LucideIcons.fileText, kBlue),
          const SizedBox(height: 12),
          _ngoActionButton("Verify Donor Receipt (Scan QR)", LucideIcons.qrCode, kSlate800),
        ],
      ),
    );
  }

  Widget _ngoStat(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kSlate100)),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: kSlate400)),
          Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        ]),
      ),
    );
  }

  Widget _managedZoneCard(String name, String status, int urgency) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kSlate100)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(status, style: const TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.bold)),
          ])),
          CircularProgressIndicator(value: urgency / 100, color: Colors.redAccent, backgroundColor: kSlate100, strokeWidth: 8),
        ],
      ),
    );
  }

  Widget _ngoActionButton(String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const SectionTitle({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B), // kSlate800
          ),
        ),
      ],
    );
  }
}

Future<void> listAvailableModels() async {
  final apiKey = dotenv.env['GEMINI_KEY']; // Ensure this matches your .env key
  final url = Uri.parse("https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey");

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("--- AVAILABLE MODELS ---");
      for (var model in data['models']) {
        print("Model Name: ${model['name']}");
        print("Methods: ${model['supportedGenerationMethods']}");
        print("-------------------------");
      }
    } else {
      print("Failed to list models: ${response.statusCode}");
      print("Response: ${response.body}");
    }
  } catch (e) {
    print("Error listing models: $e");
  }
}

// ==========================================
// GLOBAL CACHE (Above the class)
// ==========================================
List<dynamic> _cachedAiNeeds = [];
DateTime? _lastFetchTime;
String _globalLastUpdated = "Never";
DateTime? _lastSuccessfulFetch;

class ReliefMap extends StatefulWidget {
  const ReliefMap({super.key});
  @override
  State<ReliefMap> createState() => _ReliefMapState();
  }

class _ReliefMapState extends State<ReliefMap> {
  String _selectedFilter = "All";
  final List<String> _categories = ["All", "Flood Relief", "Food Security", "Medical Aid"];

  // Behavior object
  late MapZoomPanBehavior _zoomPanBehavior;
  final ScrollController _pageScrollController = ScrollController();

  String? _selectedLocationId;
  List<dynamic> aiNeeds = [];
  bool isLoading = true;
  String lastUpdatedText = "Never";

  @override
  void initState() {
    super.initState();
    _initMapBehavior();
    _syncReliefData();
  }

  void _initMapBehavior() {
    _zoomPanBehavior = MapZoomPanBehavior(
      focalLatLng: const MapLatLng(4.5, 109.3),
      zoomLevel: 4,
      enableDoubleTapZooming: true,
      enablePinching: true,
      enablePanning: true,
    );
  }

  void _safeMapMove({required MapLatLng latLng, required double zoom}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          // Direct update to behavior without calling setState
          // This is how Syncfusion handles smooth animations internally
          _zoomPanBehavior.focalLatLng = latLng;
          _zoomPanBehavior.zoomLevel = zoom;
        } catch (e) {
          debugPrint("Map move ignored: Engine busy");
        }
      }
    });
  }

  void _handleMarkerSelection(int index, Map<String, dynamic> data) {
    if (!mounted) return;

    // 1. Update UI (Green Border & Card Highlight)
    setState(() {
      _selectedLocationId = data['location'].toString().trim();
    });

    // 2. Move camera safely using a small delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      try {
        final double lat = double.tryParse(data['lat']?.toString() ?? "") ?? 4.5;
        final double lng = double.tryParse(data['lng']?.toString() ?? "") ?? 109.3;

        _zoomPanBehavior.focalLatLng = MapLatLng(lat, lng);
        _zoomPanBehavior.zoomLevel = 10;
      } catch (e) {
        debugPrint("Camera move prevented crash.");
      }
    });

    // 3. Scroll to the card
    if (_pageScrollController.hasClients) {
      double scrollOffset = 450.0 + (index * 210.0);
      _pageScrollController.animateTo(
        scrollOffset.clamp(0, _pageScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onMarkerTapped(int index, Map<String, dynamic> data) {
    String locId = (data['location'] ?? "").toString().trim();

    // Update the Green Border
    setState(() {
      _selectedLocationId = locId;
    });

    // Move Map safely
    _safeMapMove(
      latLng: MapLatLng(
        double.tryParse(data['lat'].toString()) ?? 4.5,
        double.tryParse(data['lng'].toString()) ?? 109.3,
      ),
      zoom: 10,
    );

    // Scroll the list below the map
    if (_pageScrollController.hasClients) {
      double scrollOffset = 450.0 + (index * 210.0);
      _pageScrollController.animateTo(
        scrollOffset.clamp(0, _pageScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 800),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  // --- THE CORE LOGIC: SYNC BETWEEN FIRESTORE CACHE AND AI ---
  Future<void> _syncReliefData() async {
    setState(() => isLoading = true);

    try {
      // 1. GET DATA FROM FIRESTORE
      final snapshot = await FirebaseFirestore.instance
          .collection('relief_cache')
          .doc('current_status')
          .get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final Timestamp timestamp = data['timestamp'];
        final DateTime lastFetch = timestamp.toDate();
        final List<dynamic> cachedResults = data['results'];

        // If data is fresh (less than 30 mins old), use it and STOP.
        if (DateTime.now().difference(lastFetch).inMinutes < 30) {
          debugPrint("Using fresh Firestore Cache.");
          _updateUI(cachedResults, lastFetch);
          return;
        }

        // 2. CACHE IS OLD - TRY TO REFRESH WITH AI
        debugPrint("Cache old. Attempting AI Refresh...");
        bool success = await _fetchNewDataFromAI();

        // 3. FALLBACK: If AI fails (Quota), show the old data anyway!
        if (!success) {
          debugPrint("AI failed. Falling back to stale Firestore data.");
          _updateUI(cachedResults, lastFetch);
          // Optional: Show a toast saying "Showing older data due to server limit"
        }
      } else {
        // No cache exists at all
        await _fetchNewDataFromAI();
      }

    } catch (e) {
      debugPrint("Sync Error: $e");
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  // Change this to return a bool (success/fail)
  Future<bool> _fetchNewDataFromAI() async {
    try {
      final apiKey = dotenv.env['GEMINI_KEY'];
      print("API KEY: ${dotenv.env['GEMINI_KEY']}");
      final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: apiKey!);

      final prompt = "Search active disaster situations in Malaysia (Last 48h). Categories: Flood Relief, Food Security, Medical Aid. Return strictly RAW JSON LIST ONLY. Format: [{\"location\": \"string\", \"category\": \"string\", \"description\": \"string\", \"score\": 90, \"lat\": 4.0, \"lng\": 101.0}]";

      final response = await model.generateContent([Content.text(prompt)]);
      String rawJson = response.text ?? "[]";

      // Clean JSON string
      rawJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
      int start = rawJson.indexOf('[');
      int end = rawJson.lastIndexOf(']');
      if (start != -1 && end != -1) rawJson = rawJson.substring(start, end + 1);

      final List<dynamic> decoded = jsonDecode(rawJson);

      // SAVE TO FIRESTORE
      await FirebaseFirestore.instance.collection('relief_cache').doc('current_status').set({
        'results': decoded,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _updateUI(decoded, DateTime.now());
      return true; // Success

    } catch (e) {
      debugPrint("AI Fetch Failed (Quota?): $e");
      if (e.toString().contains('429') || e.toString().contains('quota')) {
        debugPrint("Quota reached! Please wait 60 seconds.");
        // Show a message to the user: "AI is resting, try again in a minute."
      } else {
        debugPrint("AI Error: $e");
      }
      return false; // Failed
    }
  }

  void _updateUI(List<dynamic> data, DateTime time) {
    if (!mounted) return;
    setState(() {
      aiNeeds = data;
      lastUpdatedText = "${time.hour}:${time.minute.toString().padLeft(2, '0')}";
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> filteredNeeds = _selectedFilter == "All"
        ? aiNeeds
        : aiNeeds.where((item) => item['category'] == _selectedFilter).toList();

    return SingleChildScrollView(
      controller: _pageScrollController,
      child: Column(
        children: [
        Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 1. WRAP THIS COLUMN IN EXPANDED
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Malaysian Relief Heatmap",
                                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: kSlate800)),
                            const Text(
                              "AI-correlated signal tracking for humanitarian aid.",
                              style: TextStyle(color: kSlate500, fontSize: 13),
                            ),
                            Text("Updated at $lastUpdatedText",
                                style: const TextStyle(color: kEmerald, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),

                            // This will now scroll correctly because Expanded constrained the width
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(), // Optional: makes it feel smoother
                              child: Row(
                                children: _categories.map((cat) => _buildFilterTab(cat)).toList(),
                              ),
                            )
                          ],
                        ),
                      ),
                      // The Refresh Button stays on the right
                      IconButton(
                          onPressed: _syncReliefData,
                          icon: const Icon(LucideIcons.refreshCw, size: 20, color: kSlate400)
                      )
                    ],
                  ),
                ), // Your existing header logic

          // THE MAP CONTAINER
          Container(
            height: 380,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: kSlate100)
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: kEmerald))
                  : SfMaps(
                // CRITICAL: This Key forces the map to RESTART from scratch
                // every time you change a category. This stops the Red Screen.
                key: ValueKey('sf_map_$_selectedFilter'),
                layers: [
                  MapTileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    initialMarkersCount: filteredNeeds.length,
                    zoomPanBehavior: _zoomPanBehavior,
                    markerBuilder: (context, index) {
                      if (index >= filteredNeeds.length) return const MapMarker(latitude: 0, longitude: 0, child: SizedBox());

                      final data = filteredNeeds[index];
                      final String locName = (data['location'] ?? "").toString().trim();

                      // This boolean determines if the marker gets the green border
                      final bool isSelected = locName == _selectedLocationId;

                      return MapMarker(
                        latitude: double.tryParse(data['lat']?.toString() ?? "") ?? 4.5,
                        longitude: double.tryParse(data['lng']?.toString() ?? "") ?? 109.3,
                        child: GestureDetector(
                          // The Key is essential! It tells Flutter to repaint when isSelected changes.
                          key: ValueKey('marker_visual_${locName}_$isSelected'),
                          onTap: () => _handleMarkerSelection(index, data),
                          child: _buildMapMarker(
                              data['category'] ?? "General",
                              isSelected: isSelected // Passing it to the UI helper
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- PASTE THE ZOOM & RESET CONTROLS HERE ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ZOOM OUT
                _smallBtn(LucideIcons.minus, () => _zoomStep(false)),

                const SizedBox(width: 16),

                // RESET VIEW
                GestureDetector(
                  onTap: _resetView,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kSlate100),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.maximize, size: 16, color: kSlate800),
                        const SizedBox(width: 8),
                        Text("Reset View", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kSlate800)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // ZOOM IN
                _smallBtn(LucideIcons.plus, () => _zoomStep(true)),
              ],
            ),
          ),

          // THE LIST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredNeeds.length,
              itemBuilder: (context, index) {
                final item = filteredNeeds[index];
                final isSelected = item['location'].toString().trim() == _selectedLocationId;
                return _buildAICard(item, index, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- FILTER TAB LOGIC (Reset session) ---
  Widget _buildFilterTab(String label) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        if (_selectedFilter == label) return;

        setState(() {
          _selectedFilter = label;
          _selectedLocationId = null;
          // Refresh the behavior object for the new map instance
          _initMapBehavior();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? kEmerald : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? kEmerald : kSlate100),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : kSlate500
            )
        ),
      ),
    );
  }
  // --- VIEW ON MAP LOGIC (Direct to location) ---
  void _directToLocation(Map<String, dynamic> item, int index) {
    setState(() {
      _selectedLocationId = item['location'].toString().trim();

      // Update Map View
      _zoomPanBehavior.focalLatLng = MapLatLng(
          double.parse(item['lat'].toString()),
          double.parse(item['lng'].toString())
      );
      _zoomPanBehavior.zoomLevel = 10;
    });

    // Scroll to the card in the list
    double scrollOffset = 450.0 + (index * 210.0);
    _pageScrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.fastOutSlowIn,
    );
  }

  Widget _buildMapMarker(String category, {bool isSelected = false}) {
    // Map categories to colors
    Color markerColor;
    switch (category) {
      case 'Flood Relief':
        markerColor = Colors.blueAccent;
        break;
      case 'Medical Aid':
        markerColor = Colors.redAccent;
        break;
      case 'Food Security':
        markerColor = Colors.orange;
        break;
      default:
        markerColor = kSlate400;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(2), // Space between icon and border
      decoration: BoxDecoration(
        color: Colors.white, // White background for the icon
        shape: BoxShape.circle,
        border: Border.all(
          // THE FIX: Use kEmerald for the border color when selected
          color: isSelected ? kEmerald : Colors.white,
          width: isSelected ? 4 : 2, // Thicker border when selected
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: kEmerald.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]
            : [const BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: markerColor, // The actual category color
          shape: BoxShape.circle,
        ),
        child: Icon(
          category == 'Flood Relief' ? LucideIcons.droplets : LucideIcons.mapPin,
          color: Colors.white,
          size: isSelected ? 18 : 14,
        ),
      ),
    );
  }

  Widget _smallBtn(IconData icon, VoidCallback tap) {
    return GestureDetector(onTap: tap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kSlate100)), child: Icon(icon, size: 20)));
  }

  // UI HELPER FOR ZOOM BUTTONS
  Widget _zoomControlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          border: Border.all(color: kSlate100),
        ),
        child: Icon(icon, size: 20, color: kSlate800),
      ),
    );
  }

  // Updated Card with "View on Map" logic
  Widget _buildAICard(Map<String, dynamic> item, int index, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isSelected ? kEmerald : kSlate100, width: isSelected ? 2.5 : 1),
        boxShadow: isSelected ? [BoxShadow(color: kEmerald.withOpacity(0.1), blurRadius: 10)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item['category']?.toString().toUpperCase() ?? "GENERAL", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kSlate400)),
          const SizedBox(height: 8),
          Text(item['location'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(item['description'] ?? "", style: const TextStyle(color: kSlate500, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleMarkerSelection(index, item),
              style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white),
              child: const Text("View on Map"),
            ),
          )
        ],
      ),
    );
  }

  // Function for manual zoom buttons (+ / -)
  void _zoomStep(bool isIn) {
    _safeMapMove(
      // The ?? operator says: "Use focalLatLng, but if it's null, use these coordinates"
      latLng: _zoomPanBehavior.focalLatLng ?? const MapLatLng(4.5, 109.3),
      zoom: (_zoomPanBehavior.zoomLevel + (isIn ? 1 : -1)).clamp(1.0, 15.0),
    );
  }

  // Function to reset view to Malaysia overview (Like the first click)
  void _resetView() {
    _safeMapMove(
      latLng: const MapLatLng(4.5, 109.3), // Initial Malaysia center
      zoom: 4,                             // Initial zoom level
    );
    setState(() {
      _selectedLocationId = null; // Optional: clear green border on reset
    });
  }
}