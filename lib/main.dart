import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert'; // For parsing AI JSON
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// Ensure you have run 'dart pub global run flutterfire_cli:flutterfire configure'
import 'firebase_options.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Use 'pw' prefix to avoid conflict with Flutter's widgets
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // Use open_filex
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

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

  // --- UPDATED AUTH LOGIC WITH ROLE PROTECTION & SIGNUP ---
  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }
    setState(() => _isLoading = true);

    try {
      if (view == 'signup') {
        // ==========================================
        // 1. SIGN UP LOGIC
        // ==========================================
        UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        String userName = _nameController.text.trim();
        if (userName.isEmpty) userName = "New User";

        // Save the user data (including their selected role) to Firestore
        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'name': userName,
          'email': _emailController.text.trim(),
          'role': selectedRole, // This saves 'donor', 'ngo', or 'courier'
          'createdAt': FieldValue.serverTimestamp(),
          // Default stats used by the Donor Dashboard
          'walletBalance': 0.0,
          'impactValue': 0.0,
          'livesTouched': 0,
        });

        // Navigate into the app
        _navigateToApp(userName);

      } else {
        // ==========================================
        // 2. LOGIN LOGIC
        // ==========================================
        UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        // Fetch Role from Firestore
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .get();

        if (doc.exists) {
          String dbRole = doc['role']; // The role saved in Database

          // SECURITY CHECK: Compare DB Role with Selected UI Role
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
    } catch (e) {
      _showError("An error occurred: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

        // NEW: COURIER LOGISTICS BUTTON
        _roleBtn(
          "Logistics Courier",
          "Manage pickups & drop-offs",
          LucideIcons.truck,
          Colors.orange.shade700,
              () => setState(() => selectedRole = 'courier'),
          isSelected: selectedRole == 'courier',
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
  final ScrollController _dashboardScrollController = ScrollController();

  @override
  void dispose() {
    _dashboardScrollController.dispose();
    super.dispose();
  }

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

  // @override
  // Widget build(BuildContext context) {
  //   final themeColor = widget.role == 'ngo' ? kBlue : kEmerald;
  //
  //   final List<Widget> pages = [
  //     // 1. PASS THE CONTROLLER HERE
  //     DonorDashboard(
  //       userName: widget.userName,
  //       scrollController: _dashboardScrollController,
  //     ),
  //
  //     // 2. UPDATE THE onTopUp FUNCTION
  //     ReliefMap(
  //       onTopUp: () {
  //         // Switch to the Dashboard tab (index 0)
  //         setState(() => _index = 0);
  //
  //         // Wait 300ms for the Dashboard to build, then scroll to the bottom
  //         Future.delayed(const Duration(milliseconds: 300), () {
  //           if (_dashboardScrollController.hasClients) {
  //             _dashboardScrollController.animateTo(
  //               _dashboardScrollController.position.maxScrollExtent,
  //               duration: const Duration(milliseconds: 500),
  //               curve: Curves.easeOut,
  //             );
  //           }
  //         });
  //       },
  //     ),
  //
  //     const AiAdvisorPage(),
  //     const MyImpactPage(),
  //   ];
  //
  //   return Scaffold(
  //     appBar: AppBar(
  //       backgroundColor: Colors.white,
  //       elevation: 0,
  //       centerTitle: false,
  //       title: _buildBrandLogo(), // Use the custom logo widget
  //       actions: [
  //         Padding(
  //           padding: const EdgeInsets.only(right: 8.0),
  //           child: IconButton(
  //             onPressed: () {
  //               Navigator.push(
  //                 context,
  //                 MaterialPageRoute(builder: (context) => ProfileScreen(userName: widget.userName)),
  //               );
  //             },
  //             icon: Container(
  //               padding: const EdgeInsets.all(6),
  //               decoration: BoxDecoration(
  //                 color: kSlate50,
  //                 shape: BoxShape.circle,
  //                 border: Border.all(color: kSlate100),
  //               ),
  //               child: const Icon(LucideIcons.user, color: kSlate800, size: 20),
  //             ),
  //           ),
  //         ),
  //         // Optional: A quick logout button next to profile
  //         IconButton(
  //           onPressed: () async {
  //             await FirebaseAuth.instance.signOut();
  //             // THIS IS THE FIX: Clear everything and go back to selection
  //             if (!context.mounted) return;
  //             Navigator.of(context).pushAndRemoveUntil(
  //               MaterialPageRoute(builder: (context) => const AuthWrapper()),
  //                   (route) => false,
  //             );
  //           },
  //           icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
  //         ),
  //       ],
  //     ),
  //     body: pages[_index],
  //     bottomNavigationBar: Container(
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         border: Border(top: BorderSide(color: kSlate100, width: 1)),
  //       ),
  //       child: BottomNavigationBar(
  //         currentIndex: _index,
  //         onTap: (v) => setState(() => _index = v),
  //         selectedItemColor: themeColor,
  //         unselectedItemColor: kSlate400,
  //         backgroundColor: Colors.white,
  //         elevation: 0,
  //         type: BottomNavigationBarType.fixed,
  //         items: const [
  //           BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Dashboard"),
  //           BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
  //           BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
  //           BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "My Impact"),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  // @override
  // Widget build(BuildContext context) {
  //   final isNgo = widget.role == 'ngo';
  //   final themeColor = isNgo ? kBlue : kEmerald;
  //   final isCourier = widget.role == 'courier';
  //
  //   // 1. DYNAMIC PAGES BASED ON ROLE
  //   final List<Widget> pages = isNgo
  //       ? [
  //     const NGODashboard(), // NGO's 1st Tab: Mission Hub
  //     const ReliefMap(),    // NGO's 2nd Tab: Relief Map
  //     const AiAdvisorPage(role: 'ngo'), // NGO's 3rd Tab: NGO AI
  //     const ReliefMap(), // NGO's 4th Tab: Logistics Data
  //   ]
  //       : [
  //     DonorDashboard(
  //       userName: widget.userName,
  //       scrollController: _dashboardScrollController,
  //     ),
  //     ReliefMap(
  //       onTopUp: () {
  //         setState(() => _index = 0);
  //         Future.delayed(const Duration(milliseconds: 300), () {
  //           if (_dashboardScrollController.hasClients) {
  //             _dashboardScrollController.animateTo(
  //               _dashboardScrollController.position.maxScrollExtent,
  //               duration: const Duration(milliseconds: 500),
  //               curve: Curves.easeOut,
  //             );
  //           }
  //         });
  //       },
  //     ),
  //     const AiAdvisorPage(role: 'donor'),
  //     const MyImpactPage(),
  //   ];
  //
  //   // 2. DYNAMIC BOTTOM NAV ITEMS BASED ON ROLE
  //   final List<BottomNavigationBarItem> navItems = isNgo
  //       ? const [
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Mission Hub"),
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "Logistics Data"),
  //   ]
  //       : const [
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Dashboard"),
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
  //     BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "My Impact"),
  //   ];
  //
  //   return Scaffold(
  //     appBar: AppBar(
  //       backgroundColor: Colors.white,
  //       elevation: 0,
  //       centerTitle: false,
  //       title: _buildBrandLogo(),
  //       actions: [
  //         // 1. NEW: NOTIFICATION BELL
  //         const Center(
  //           child: Padding(
  //             padding: EdgeInsets.only(right: 8.0),
  //             child: NotificationBell(), // <--- ADDED HERE
  //           ),
  //         ),
  //
  //         // 2. EXISTING: PROFILE BUTTON
  //         Padding(
  //           padding: const EdgeInsets.only(right: 8.0),
  //           child: IconButton(
  //             onPressed: () {
  //               Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userName: widget.userName)));
  //             },
  //             icon: Container(
  //               padding: const EdgeInsets.all(6),
  //               decoration: BoxDecoration(color: kSlate50, shape: BoxShape.circle, border: Border.all(color: kSlate100)),
  //               child: const Icon(LucideIcons.user, color: kSlate800, size: 20),
  //             ),
  //           ),
  //         ),
  //
  //         // 3. EXISTING: LOGOUT BUTTON
  //         IconButton(
  //           onPressed: () async {
  //             await FirebaseAuth.instance.signOut();
  //             if (!context.mounted) return;
  //             Navigator.of(context).pushAndRemoveUntil(
  //               MaterialPageRoute(builder: (context) => const AuthWrapper()),
  //                   (route) => false,
  //             );
  //           },
  //           icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
  //         ),
  //         const SizedBox(width: 8), // Small padding at the very edge
  //       ],
  //     ),
  //     body: pages[_index],
  //     bottomNavigationBar: Container(
  //       decoration: const BoxDecoration(
  //         color: Colors.white,
  //         border: Border(top: BorderSide(color: kSlate100, width: 1)),
  //       ),
  //       child: BottomNavigationBar(
  //         currentIndex: _index,
  //         onTap: (v) => setState(() => _index = v),
  //         selectedItemColor: themeColor,
  //         unselectedItemColor: kSlate400,
  //         backgroundColor: Colors.white,
  //         elevation: 0,
  //         type: BottomNavigationBarType.fixed,
  //         items: navItems,
  //       ),
  //     ),
  //   );
  // }
  // @override
  // Widget build(BuildContext context) {
  //   final isNgo = widget.role == 'ngo';
  //   final isCourier = widget.role == 'courier';
  //
  //   // Dynamic Theme Color: NGO is Blue, Courier is Orange, Donor is Emerald
  //   final themeColor = isNgo ? kBlue : (isCourier ? Colors.orange.shade700 : kEmerald);
  //
  //   // 1. DYNAMIC PAGES & NAV ITEMS BASED ON ROLE
  //   List<Widget> pages;
  //   List<BottomNavigationBarItem> navItems;
  //
  //   if (isNgo) {
  //     pages = [
  //       const NGODashboard(), // NGO's 1st Tab: Mission Hub
  //       const ReliefMap(),    // NGO's 2nd Tab: Relief Map
  //       const AiAdvisorPage(role: 'ngo'), // NGO's 3rd Tab: NGO AI
  //       const ReliefMap(), // NGO's 4th Tab: Logistics Data
  //     ];
  //     navItems = const [
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Mission Hub"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "Logistics"),
  //     ];
  //   } else if (isCourier) {
  //     // --- COURIER DASHBOARD OVERRIDE ---
  //     pages = [
  //       const CourierDashboard(), // The new scanner hub
  //       const ReliefMap(),        // Allow them to see the map
  //     ];
  //     navItems = const [
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.scanLine), label: "Scanner Hub"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Delivery Map"),
  //     ];
  //   } else {
  //     // --- DEFAULT DONOR DASHBOARD ---
  //     pages = [
  //       DonorDashboard(
  //         userName: widget.userName,
  //         scrollController: _dashboardScrollController,
  //       ),
  //       ReliefMap(
  //         onTopUp: () {
  //           setState(() => _index = 0);
  //           Future.delayed(const Duration(milliseconds: 300), () {
  //             if (_dashboardScrollController.hasClients) {
  //               _dashboardScrollController.animateTo(
  //                 _dashboardScrollController.position.maxScrollExtent,
  //                 duration: const Duration(milliseconds: 500),
  //                 curve: Curves.easeOut,
  //               );
  //             }
  //           });
  //         },
  //       ),
  //       const AiAdvisorPage(role: 'donor'),
  //       const MyImpactPage(),
  //     ];
  //     navItems = const [
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Dashboard"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
  //       BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "My Impact"),
  //     ];
  //   }
  //
  //   // Safety check: If you switch from a role with 4 tabs to a role with 2 tabs, prevent crashes.
  //   int safeIndex = _index >= pages.length ? 0 : _index;
  //
  //   return Scaffold(
  //     appBar: AppBar(
  //       backgroundColor: Colors.white,
  //       elevation: 0,
  //       centerTitle: false,
  //       title: _buildBrandLogo(),
  //       actions: [
  //         // Hide Notifications and Profile for the Courier to keep it clean
  //         if (!isCourier) ...[
  //           const Center(
  //             child: Padding(
  //               padding: EdgeInsets.only(right: 8.0),
  //               child: NotificationBell(),
  //             ),
  //           ),
  //           Padding(
  //             padding: const EdgeInsets.only(right: 8.0),
  //             child: IconButton(
  //               onPressed: () {
  //                 Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userName: widget.userName)));
  //               },
  //               icon: Container(
  //                 padding: const EdgeInsets.all(6),
  //                 decoration: BoxDecoration(color: kSlate50, shape: BoxShape.circle, border: Border.all(color: kSlate100)),
  //                 child: const Icon(LucideIcons.user, color: kSlate800, size: 20),
  //               ),
  //             ),
  //           ),
  //         ],
  //
  //         // Keep Logout visible for EVERYONE so you can switch roles during demo easily!
  //         IconButton(
  //           onPressed: () async {
  //             await FirebaseAuth.instance.signOut();
  //             if (!context.mounted) return;
  //             Navigator.of(context).pushAndRemoveUntil(
  //               MaterialPageRoute(builder: (context) => const AuthWrapper()),
  //                   (route) => false,
  //             );
  //           },
  //           icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
  //         ),
  //         const SizedBox(width: 8),
  //       ],
  //     ),
  //     body: pages[safeIndex],
  //     bottomNavigationBar: Container(
  //       decoration: const BoxDecoration(
  //         color: Colors.white,
  //         border: Border(top: BorderSide(color: kSlate100, width: 1)),
  //       ),
  //       child: BottomNavigationBar(
  //         currentIndex: safeIndex,
  //         onTap: (v) => setState(() => _index = v),
  //         selectedItemColor: themeColor,
  //         unselectedItemColor: kSlate400,
  //         backgroundColor: Colors.white,
  //         elevation: 0,
  //         type: BottomNavigationBarType.fixed,
  //         items: navItems,
  //       ),
  //     ),
  //   );
  // }
// --- PASTE THIS INSIDE _AppShellState ---
  @override
  Widget build(BuildContext context) {
    final isNgo = widget.role == 'ngo';
    final isCourier = widget.role == 'courier';

    // Dynamic Theme Color: NGO is Blue, Courier is Orange, Donor is Emerald
    final themeColor = isNgo ? kBlue : (isCourier ? Colors.orange.shade700 : kEmerald);

    // 1. DYNAMIC PAGES & NAV ITEMS BASED ON ROLE
    List<Widget> pages;
    List<BottomNavigationBarItem> navItems = [];

    if (isNgo) {
      pages = [
        const NGODashboard(), // NGO's 1st Tab: Mission Hub
        const ReliefMap(),    // NGO's 2nd Tab: Relief Map
        const AiAdvisorPage(role: 'ngo'), // NGO's 3rd Tab: NGO AI
        const ReliefMap(), // NGO's 4th Tab: Logistics Data
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Mission Hub"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "Logistics"),
      ];
    } else if (isCourier) {
      // --- COURIER DASHBOARD OVERRIDE ---
      pages = [
        const CourierDashboard(), // ONLY the scanner hub
      ];
      // navItems remains empty because we hide the bottom bar below!
    } else {
      // --- DEFAULT DONOR DASHBOARD ---
      pages = [
        DonorDashboard(
          userName: widget.userName,
          scrollController: _dashboardScrollController,
        ),
        ReliefMap(
          onTopUp: () {
            setState(() => _index = 0);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_dashboardScrollController.hasClients) {
                _dashboardScrollController.animateTo(
                  _dashboardScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                );
              }
            });
          },
        ),
        const AiAdvisorPage(role: 'donor'),
        const MyImpactPage(),
      ];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(LucideIcons.layoutDashboard), label: "Dashboard"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.map), label: "Relief Map"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: "AI Advisor"),
        BottomNavigationBarItem(icon: Icon(LucideIcons.barChart3), label: "My Impact"),
      ];
    }

    // Safety check: If you switch from a role with 4 tabs to a role with 1 tab, prevent crashes.
    int safeIndex = _index >= pages.length ? 0 : _index;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: _buildBrandLogo(),
        actions: [
          // Hide Notifications and Profile for the Courier to keep it clean
          if (!isCourier) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: NotificationBell(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userName: widget.userName)));
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: kSlate50, shape: BoxShape.circle, border: Border.all(color: kSlate100)),
                  child: const Icon(LucideIcons.user, color: kSlate800, size: 20),
                ),
              ),
            ),
          ],

          // Keep Logout visible for EVERYONE so you can switch roles during demo easily!
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                    (route) => false,
              );
            },
            icon: const Icon(LucideIcons.logOut, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[safeIndex],

      // If it is the courier, return 'null' so the bottom bar disappears completely!
      bottomNavigationBar: isCourier
          ? null
          : Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kSlate100, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (v) => setState(() => _index = v),
          selectedItemColor: themeColor,
          unselectedItemColor: kSlate400,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: navItems,
        ),
      ),
    );
  }
}

// class ProfileScreen extends StatelessWidget {
//   final String userName;
//   const ProfileScreen({super.key, required this.userName});
//
//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold)),
//         elevation: 0,
//         backgroundColor: Colors.white,
//         foregroundColor: kSlate800,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           children: [
//             // User Avatar & Name
//             CircleAvatar(
//               radius: 40,
//               backgroundColor: kEmerald.withOpacity(0.1),
//               child: Text(userName[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kEmerald)),
//             ),
//             const SizedBox(height: 16),
//             Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//             Text(user?.email ?? "email@example.com", style: const TextStyle(color: kSlate400)),
//
//             const SizedBox(height: 40),
//
//             // Settings List
//           // FIX FOR EMAIL
//             _profileOption(
//               icon: LucideIcons.mail,
//               title: "Update Email",
//               onTap: () => _showUpdateDialog(
//                 context,
//                 "Email",
//                     (newEmail) async {
//                   final user = FirebaseAuth.instance.currentUser;
//
//                   // 1. MANUAL UNIQUENESS CHECK: Check if email exists in Firestore
//                   final result = await FirebaseFirestore.instance
//                       .collection('users')
//                       .where('email', isEqualTo: newEmail)
//                       .get();
//
//                   if (result.docs.isNotEmpty) {
//                     // Throw a custom error so the catch block handles it
//                     throw FirebaseAuthException(
//                         code: 'email-already-in-use',
//                         message: 'This email is already registered by another user.'
//                     );
//                   }
//
//                   // 2. THE UPDATE: Since updateEmail is deleted from the SDK,
//                   // we MUST use verifyBeforeUpdateEmail.
//                   // Note: This IS the only method currently available in the SDK.
//                   await user?.verifyBeforeUpdateEmail(newEmail);
//
//                   // 3. SYNC TO FIRESTORE
//                   await FirebaseFirestore.instance
//                       .collection('users')
//                       .doc(user?.uid)
//                       .update({'email': newEmail});
//                 },
//               ),
//             ),
//
//           // FIX FOR PASSWORD
//           _profileOption(
//             icon: LucideIcons.lock,
//             title: "Change Password",
//             onTap: () => _showUpdateDialog(
//               context,
//               "Password",
//                   (val) async => await user?.updatePassword(val), // Keep this but make it async
//             ),
//           ),
//             const Divider(height: 40),
//             _profileOption(
//               icon: LucideIcons.logOut,
//               title: "Logout",
//               color: Colors.red,
//               onTap: () async {
//                 await FirebaseAuth.instance.signOut();
//                 // THIS IS THE FIX: Clear everything and go back to selection
//                 if (!context.mounted) return;
//                 Navigator.of(context).pushAndRemoveUntil(
//                   MaterialPageRoute(builder: (context) => const AuthWrapper()),
//                       (route) => false,
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _profileOption({required IconData icon, required String title, required VoidCallback onTap, Color? color}) {
//     return ListTile(
//       onTap: onTap,
//       leading: Icon(icon, color: color ?? kSlate800, size: 20),
//       title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? kSlate800)),
//       trailing: const Icon(LucideIcons.chevronRight, size: 16, color: kSlate400),
//       contentPadding: const EdgeInsets.symmetric(vertical: 4),
//     );
//   }
//
//   // Generic Dialog for Updates
//   // Update the signature to: Future<void> Function(String)
//   void _showUpdateDialog(BuildContext context, String type, Future<void> Function(String) onUpdate) {
//     final controller = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Text("Update $type", style: const TextStyle(fontWeight: FontWeight.bold)),
//         content: TextField(
//           controller: controller,
//           autofocus: true,
//           decoration: InputDecoration(
//             hintText: "Enter new $type",
//             filled: true,
//             fillColor: kSlate50,
//             border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
//           ),
//           obscureText: type == "Password",
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white),
//             onPressed: () async {
//               try {
//                 String val = controller.text.trim();
//                 if (val.isEmpty) return;
//
//                 await onUpdate(val);
//
//                 Navigator.pop(context);
//
//                 // Custom message based on type
//                 String successMsg = type == "Email"
//                     ? "Checking email... Link sent for verification."
//                     : "Password updated!";
//
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
//               } on FirebaseAuthException catch (e) {
//                 // This catches the 'email-already-in-use' error we threw manually
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text(e.message ?? "An error occurred"), backgroundColor: Colors.redAccent),
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
//                 );
//               }
//             },
//             child: const Text("Update"),
//           )
//         ],
//       ),
//     );
//   }
// }
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
              child: Text(userName.isNotEmpty ? userName[0] : "?", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kEmerald)),
            ),
            const SizedBox(height: 16),
            Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user?.email ?? "email@example.com", style: const TextStyle(color: kSlate400)),

            const SizedBox(height: 40),

            // Settings List
            _profileOption(
              icon: LucideIcons.home,
              title: "Update Registered Address",
              onTap: () => _showUpdateDialog(
                  context,
                  "Address",
                  // 1. UPDATE LOGIC
                      (newAddress) async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({'address': newAddress});
                    }
                  },
                  // 2. NEW DELETE LOGIC
                  onDelete: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({'address': FieldValue.delete()}); // Erases the field entirely
                    }
                  }
              ),
            ),

            _profileOption(
              icon: LucideIcons.mail,
              title: "Update Email",
              onTap: () => _showUpdateDialog(
                context,
                "Email",
                    (newEmail) async {
                  final user = FirebaseAuth.instance.currentUser;
                  final result = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: newEmail)
                      .get();

                  if (result.docs.isNotEmpty) {
                    Navigator.pop(context);
                    throw FirebaseAuthException(
                        code: 'email-already-in-use',
                        message: 'This email is already registered by another user.'
                    );
                  }

                  await user?.verifyBeforeUpdateEmail(newEmail);
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .update({'email': newEmail});
                },
              ),
            ),

            _profileOption(
              icon: LucideIcons.lock,
              title: "Change Password",
              onTap: () => _showUpdateDialog(
                context,
                "Password",
                    (val) async => await user?.updatePassword(val),
              ),
            ),
            const Divider(height: 40),

            _profileOption(
              icon: LucideIcons.logOut,
              title: "Logout",
              color: Colors.red,
              onTap: () async {
                await FirebaseAuth.instance.signOut();
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

  // --- FULLY REDESIGNED UPDATE DIALOG WITH DELETE OPTION ---
  void _showUpdateDialog(
      BuildContext context,
      String type,
      Future<void> Function(String) onUpdate,
      {Future<void> Function()? onDelete} // Optional Delete Function
      ) {
    final TextEditingController controller = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. CUSTOM HEADER
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: kEmerald,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Update $type",
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              const Text(
                                "PROFILE MANAGEMENT",
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (!isProcessing) Navigator.pop(context);
                          },
                          icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
                        )
                      ],
                    ),
                  ),

                  // 2. BODY CONTENT
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "NEW ${type.toUpperCase()}",
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),

                        // Formatted Text Field
                        TextField(
                          controller: controller,
                          autofocus: true,
                          obscureText: type == "Password",
                          maxLines: type == "Address" ? 3 : 1,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kSlate800),
                          decoration: InputDecoration(
                            hintText: type == "Address" ? "Enter full street address" : "Enter new $type",
                            hintStyle: const TextStyle(color: kSlate400, fontWeight: FontWeight.w400),
                            filled: true,
                            fillColor: kSlate50,
                            contentPadding: const EdgeInsets.all(20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kSlate100, width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kEmerald, width: 2)),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 3. MAIN SAVE BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kEmerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: isProcessing
                                ? null
                                : () async {
                              String val = controller.text.trim();
                              if (val.isEmpty) return; // Must type something to save

                              setDialogState(() => isProcessing = true);

                              try {
                                await onUpdate(val);

                                if (context.mounted) {
                                  Navigator.pop(context);

                                  String successMsg = "Updated successfully!";
                                  if (type == "Email") successMsg = "Checking email... Link sent for verification.";
                                  if (type == "Password") successMsg = "Password updated!";
                                  if (type == "Address") successMsg = "Address saved successfully! Our logistics partners will use this for doorstep pick-ups.";

                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(successMsg),
                                    backgroundColor: kEmerald,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ));
                                }
                              } on FirebaseAuthException catch (e) {
                                setDialogState(() => isProcessing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message ?? "An error occurred"), backgroundColor: Colors.redAccent),
                                );
                              } catch (e) {
                                setDialogState(() => isProcessing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                                );
                              }
                            },
                            child: isProcessing && controller.text.isNotEmpty
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                                : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        ),

                        // 4. CONDITIONALLY RENDER REMOVE BUTTON
                        if (onDelete != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              onPressed: isProcessing ? null : () async {
                                setDialogState(() => isProcessing = true);
                                try {
                                  await onDelete();

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("$type removed successfully."),
                                        backgroundColor: Colors.redAccent,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isProcessing = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                                  );
                                }
                              },
                              child: Text("Remove $type", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],

                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 4. DONOR DASHBOARD (WITH BALANCE & TOP-UP)
// ==========================================
class DonorDashboard extends StatelessWidget {
  final String userName;
  final ScrollController? scrollController;
  const DonorDashboard({super.key, required this.userName, this.scrollController});

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? "";


    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnapshot) {
          var userData = userSnapshot.data?.data() as Map<String, dynamic>?;

          // DYNAMIC FIELDS FROM FIREBASE
         // String impact = userData?['impactValue']?.toString() ?? "0.00";
          double impactScore = (userData?['impactValue'] as num? ?? 0.0).toDouble();

// For the UI Display (needs a 2-decimal string)
          String impact = impactScore.toStringAsFixed(2);
          String lives = userData?['livesTouched']?.toString() ?? "0";
          double balance = (userData?['walletBalance'] ?? 0.0).toDouble(); // NEW: BALANCE FIELD
          double impactValue = (userData?['impactValue'] as num? ?? 0).toDouble();
          double livesValue = (userData?['livesTouched'] as num? ?? 0).toDouble();
          // Inside build:
          // 2. Format Impact (This adds the 'RM' automatically)
          String formattedImpact = NumberFormat.compactCurrency(
            symbol: 'RM ',
            decimalDigits: 0,
          ).format(impactValue);

// 3. Format Lives (Use the numeric value directly)
          String formattedLives = NumberFormat.compact().format(livesValue);

          return SingleChildScrollView(
            controller: scrollController,
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
                    // Wallet Balance - Keep 2 decimals for currency feel
                    _statBox("WALLET BALANCE", "RM ${balance.toStringAsFixed(2)}", kEmerald),
                    const SizedBox(width: 8),

                    // FIX: Use 'formattedImpact' instead of '_formatCompact'
                    _statBox("IMPACT VALUE", formattedImpact, kBlue),
                    const SizedBox(width: 8),

                    // FIX: Use 'formattedLives' instead of '_formatCompact'
                    _statBox("LIVES TOUCHED", "~$formattedLives", const Color(0xFF6366F1)),
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
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _emptyState("No active donations found.");
                      }
                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          // PASS CONTEXT HERE
                          return _buildTrackingCardFromData(context, data);
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
              label: const Text("Top Up Funds to KitaCare Wallet", style: TextStyle(fontWeight: FontWeight.w800)),
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

  // // NEW: FUNCTION TO ADD MONEY TO THE WALLET
  // void _showTopUpDialog(BuildContext context, String uid) {
  //   final TextEditingController amountController = TextEditingController();
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  //       title: const Text("Top Up Wallet", style: TextStyle(fontWeight: FontWeight.w800)),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           const Text("Enter amount to transfer from your linked bank account.", style: TextStyle(fontSize: 12, color: kSlate500)),
  //           const SizedBox(height: 20),
  //           TextField(
  //             controller: amountController,
  //             keyboardType: TextInputType.number,
  //             autofocus: true,
  //             style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kEmerald),
  //             decoration: InputDecoration(
  //               prefixText: "RM ",
  //               hintText: "0.00",
  //               filled: true,
  //               fillColor: kSlate50,
  //               border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  //             ),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
  //         ElevatedButton(
  //           onPressed: () async {
  //             double amount = double.tryParse(amountController.text) ?? 0.0;
  //             if (amount > 0) {
  //               // UPDATE FIREBASE BALANCE
  //               await FirebaseFirestore.instance.collection('users').doc(uid).update({
  //                 'walletBalance': FieldValue.increment(amount),
  //               });
  //               Navigator.pop(context);
  //             }
  //           },
  //           child: const Text("Confirm Top Up"),
  //         )
  //       ],
  //     ),
  //   );
  // }
  void _showTopUpDialog(BuildContext context, String uid) {
    final TextEditingController amountController = TextEditingController(text: "50");
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. CUSTOM HEADER (Matches other dialogs)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: kEmerald,
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Top Up Wallet",
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              const Text(
                                "SECURE BANK TRANSFER",
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (!isProcessing) Navigator.pop(context);
                          },
                          icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
                        )
                      ],
                    ),
                  ),

                  // 2. BODY CONTENT
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ENTER AMOUNT (RM)",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),

                        // Large Centered Text Field
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: kEmerald),
                          decoration: InputDecoration(
                            prefixText: "RM ",
                            prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kSlate400),
                            filled: true,
                            fillColor: kSlate50,
                            contentPadding: const EdgeInsets.symmetric(vertical: 24),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: kSlate100, width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: kEmerald, width: 2)),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Helper Text to inform user of the limit
                        const Center(
                          child: Text(
                            "Maximum top-up limit: RM 99,999",
                            style: TextStyle(fontSize: 11, color: kSlate400, fontWeight: FontWeight.w600),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 3. FULL WIDTH ACTION BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kEmerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: isProcessing
                                ? null
                                : () async {
                              double amount = double.tryParse(amountController.text) ?? 0.0;

                              // --- NEW VALIDATION: Limit to strictly below 100,000 ---
                              if (amount >= 100000) {
                                Navigator.pop(context); // CLOSES THE DIALOG FIRST
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Top-up amount must be below RM 100,000."),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                return; // Stop the function here
                              }

                              if (amount > 0) {
                                setDialogState(() => isProcessing = true);

                                // UPDATE FIREBASE BALANCE
                                await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                  'walletBalance': FieldValue.increment(amount),
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Successfully topped up RM ${amount.toStringAsFixed(2)}"),
                                      backgroundColor: kEmerald,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              }
                            },
                            child: isProcessing
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Confirm Top Up", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                SizedBox(width: 10),
                                Icon(LucideIcons.arrowRight, size: 20)
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

  // --- 1. UPDATED CARD UI: ACCEPT QR DATA & SHOW BUTTON ---
  Widget _buildTrackingCard({
    required String id,
    required String target,
    required String status,
    required bool isItem,
    required String img,
    required List<dynamic> milestones,
    String? qrCodeData,
    VoidCallback? onViewQr,
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
            // Removed MainAxisAlignment.spaceBetween to allow Expanded to work
            children: [
              // --- 1. WRAP LEFT CONTENT IN EXPANDED ---
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: (isItem ? kBlue : kEmerald).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(isItem ? LucideIcons.package : LucideIcons.banknote, color: isItem ? kBlue : kEmerald, size: 16),
                    ),
                    const SizedBox(width: 12),
                    // --- 2. WRAP TEXT COLUMN IN EXPANDED ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(id, style: const TextStyle(color: kSlate400, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text(
                            target,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kSlate800),
                            overflow: TextOverflow.ellipsis, // <--- ADDS '...' IF TOO LONG
                            maxLines: 1, // <--- KEEPS IT ON ONE LINE
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8), // Gap between text and chip
              _statusChip(status, isItem ? kBlue : kEmerald),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: milestones.map((m) {
                    return _timelineItem(m['label'] ?? "Step", m['date'] ?? "", m['done'] ?? false);
                  }).toList(),
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(img, width: 100, height: 80, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(width: 100, height: 80, color: kSlate100, child: const Icon(Icons.image_not_supported)),
                ),
              )
            ],
          ),

          if (isItem && qrCodeData != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewQr,
                icon: const Icon(LucideIcons.qrCode, size: 16),
                label: const Text("View QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: kSlate800,
                    side: const BorderSide(color: kSlate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12)
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // --- 3. NEW HELPER: SHOW THE QR DIALOG ---
  void _showSavedQrDialog(BuildContext context, String qrData, String itemName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Item Donation QR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kSlate800)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 20))
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kSlate100, width: 2),
                    boxShadow: [BoxShadow(color: kSlate100, blurRadius: 10)]
                ),
                child: Image.network(
                  "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$qrData",
                  width: 180,
                  height: 180,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(width: 180, height: 180, child: Center(child: CircularProgressIndicator()));
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(itemName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: kEmerald)),
              const SizedBox(height: 8),
              Text("ID: $qrData", style: const TextStyle(fontWeight: FontWeight.bold, color: kSlate400, fontSize: 12)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white),
                  child: const Text("Close"),
                ),
              )
            ],
          ),
        ),
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

  Widget _buildTrackingCardFromData(BuildContext context, Map<String, dynamic> data) {
    String id = data['id'] ?? "ID-UNKNOWN";
    String? qrData = data['qrCodeData']; // Extract from Firebase
    String itemName = data['itemName'] ?? "Donation Item";

    return _buildTrackingCard(
      id: id,
      target: data['target'] ?? "Aid Project",
      status: data['status'] ?? "Processing",
      isItem: data['type'] == 'item',
      img: data['imageUrl'] ?? "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400",
      milestones: data['milestones'] ?? [],
      qrCodeData: qrData, // Pass to UI
      onViewQr: () => _showSavedQrDialog(context, qrData ?? id, itemName), // Pass action
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

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  bool _isVerified = false;

  void _onPinVerified() {
    setState(() {
      _isVerified = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If verified, show the original operational dashboard.
    // If not, show the new Secure Console PIN screen.
    return _isVerified
        ? const NGOOperationalDashboard()
        : NGOSecureConsole(onVerified: _onPinVerified);
  }
}
// ==========================================
// NEW: COURIER LOGISTICS DASHBOARD
// ==========================================
// ==========================================
// NEW: COURIER LOGISTICS DASHBOARD
// ==========================================
class CourierDashboard extends StatefulWidget {
  const CourierDashboard({super.key});

  @override
  State<CourierDashboard> createState() => _CourierDashboardState();
}

class _CourierDashboardState extends State<CourierDashboard> {
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessing = false;

  // Simulate scanning by pulling data from Firebase based on QR String
  Future<void> _processScan() async {
    String qrData = _qrController.text.trim();
    if (qrData.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Look across ALL users for a donation with this specific QR code
      var query = await FirebaseFirestore.instance
          .collectionGroup('donations')
          .where('qrCodeData', isEqualTo: qrData)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid QR Code. Package not found in system.")));
        }
        setState(() => _isProcessing = false);
        return;
      }

      // We found the package!
      var doc = query.docs.first;
      var data = doc.data();

      setState(() => _isProcessing = false);
      _qrController.clear();
      if (mounted) Navigator.pop(context); // Close scan dialog

      // Open Action Dialog
      _showPackageActionDialog(doc.reference, data);

    } catch (e) {
      debugPrint("Scan Error: $e");
      setState(() => _isProcessing = false);
    }
  }

  // --- NEW: OPEN CAMERA SCANNER ---
  void _openCameraScanner() async {
    // 1. Close the manual entry dialog first
    Navigator.pop(context);

    // 2. Open the full-screen camera
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    // 3. If a code was scanned, process it automatically!
    if (scannedCode != null && scannedCode is String) {
      _qrController.text = scannedCode;
      _processScan();
    }
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.scanLine, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text("Scan Package QR", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const Text("Use your camera or enter the ID manually.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),

              const SizedBox(height: 24),

              // --- CAMERA SCAN BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  icon: const Icon(LucideIcons.camera),
                  onPressed: _openCameraScanner,
                  label: const Text("Open Camera Scanner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("OR MANUAL ENTRY", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _qrController,
                decoration: InputDecoration(
                  hintText: "e.g., KC-12345-TEN",
                  filled: true,
                  fillColor: kSlate50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kSlate100,
                      foregroundColor: kSlate800,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  onPressed: _isProcessing ? null : _processScan,
                  child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Find via ID", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // The Dialog where Courier Updates the Package Status
  void _showPackageActionDialog(DocumentReference docRef, Map<String, dynamic> data) {
    List<dynamic> milestones = data['milestones'] ?? [];

    // Determine Current State
    bool isPickedUp = milestones.length > 1 && milestones[1]['done'] == true;
    bool isDroppedOff = milestones.length > 3 && milestones[3]['done'] == true;

    XFile? capturedImage;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                          child: Icon(LucideIcons.package, color: Colors.orange.shade700, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(data['itemName'] ?? "Package", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
                        Text("Target: ${data['target']}", style: const TextStyle(color: Colors.grey)),
                        const Divider(height: 32),

                        if (isDroppedOff) ...[
                          const Icon(LucideIcons.checkCircle, color: kEmerald, size: 48),
                          const SizedBox(height: 12),
                          const Text("Delivery Completed", style: TextStyle(color: kEmerald, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close")))
                        ]
                        else if (!isPickedUp) ...[
                          // --- ACTION: PICK UP ---
                          const Text("Action Required: Pick-up from Donor", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(LucideIcons.truck),
                              label: const Text("Confirm Pick-Up"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                              onPressed: () async {
                                // Update Firestore (Milestone 1)
                                milestones[1]['done'] = true;
                                await docRef.update({
                                  'milestones': milestones,
                                  'status': 'Picked Up & In Transit'
                                });
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Package Picked Up! Donor notified.")));
                                }
                              },
                            ),
                          )
                        ]
                        else ...[
                            // --- ACTION: DROP OFF (REQUIRES PHOTO) ---
                            const Text("Action Required: Drop-off at NGO Hub", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),

                            // Photo Area
                            GestureDetector(
                              onTap: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                                if (photo != null) setDialogState(() => capturedImage = photo);
                              },
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                    color: kSlate50,
                                    border: Border.all(color: capturedImage != null ? kEmerald : kSlate300, width: 2),
                                    borderRadius: BorderRadius.circular(16)
                                ),
                                child: capturedImage != null
                                    ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(capturedImage!.path), fit: BoxFit.cover))
                                    : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.camera, color: Colors.orange.shade700, size: 32),
                                    const SizedBox(height: 8),
                                    const Text("Tap to take proof photo", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(LucideIcons.checkSquare),
                                label: const Text("Confirm Drop-Off"),
                                style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white),
                                onPressed: capturedImage == null ? null : () async {

                                  // To simulate storage upload, we use a placeholder success image URL.
                                  // In production: upload `capturedImage` to Firebase Storage, get URL, save to DB.
                                  String simulatedProofUrl = "https://images.unsplash.com/photo-1577705998148-6da4f3963bc8?w=400";

                                  // Update Firestore (Milestones 2 and 3)
                                  if (milestones.length > 3) {
                                    milestones[2]['done'] = true; // Arrived at Hub
                                    milestones[3]['done'] = true; // Verified
                                  }

                                  await docRef.update({
                                    'milestones': milestones,
                                    'status': 'Arrived at NGO Hub',
                                    'proofOfDeliveryUrl': simulatedProofUrl,
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Drop-off Verified! Photo uploaded.")));
                                  }
                                },
                              ),
                            )
                          ],

                        // Cancel button
                        if (!isDroppedOff)
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey)))
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Logistics Hub", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: kSlate800)),
              const Text("Courier Access Terminal", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),

              // Big Scan Button
              GestureDetector(
                onTap: _showScanDialog,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.orange.shade200, blurRadius: 20, offset: const Offset(0, 10))]
                  ),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.scanLine, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      Text("SCAN PACKAGE QR", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      const Text("To Pickup or Drop-off", style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Text("System Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(child: _statBox("ACTIVE TASKS", "2", Colors.orange.shade700)),
                  const SizedBox(width: 16),
                  Expanded(child: _statBox("DELIVERED", "14", kEmerald)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kSlate50, borderRadius: BorderRadius.circular(16), border: Border.all(color: kSlate100)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          ]
      ),
    );
  }
}

// ==========================================
// NEW: CAMERA SCANNER SCREEN
// ==========================================
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Scan Package", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isScanned) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  setState(() => _isScanned = true);
                  Navigator.pop(context, code); // Return the scanned code back!
                }
              }
            },
          ),
          // Simple visual overlay for scanning
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade700, width: 4),
                borderRadius: BorderRadius.circular(24)
            ),
          ),
          const Positioned(
            bottom: 50,
            child: Text("Align QR code within the frame", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

// ==========================================
// NEW SCREEN: NGO Secure Console (PIN Entry)
// Matches your web screenshot and uses Firebase
// ==========================================
class NGOSecureConsole extends StatefulWidget {
  final VoidCallback onVerified;

  const NGOSecureConsole({super.key, required this.onVerified});

  @override
  State<NGOSecureConsole> createState() => _NGOSecureConsoleState();
}

class _NGOSecureConsoleState extends State<NGOSecureConsole> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _verifyPinWithFirebase() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Fetch the portal configuration from Firebase
      // Adjust collection/doc names based on your actual database structure
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('ngo_settings')
          .doc('portal_config')
          .get();

      if (doc.exists) {
        String correctPin = doc['projectPin'];

        // 2. Verify the entered PIN
        if (_pinController.text.trim() == correctPin) {
          widget.onVerified(); // Success! Go to dashboard
        } else {
          setState(() {
            _errorMessage = 'Invalid Project PIN. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Portal configuration not found in database.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kSlate100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.fact_check_outlined, // Replaces web icon
                  color: kBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                "NGO Secure Console",
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kSlate800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle (Fetches NGO Name from Firebase so it's not hardcoded)
              FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('ngo_settings').doc('portal_config').get(),
                  builder: (context, snapshot) {
                    String ngoName = "Loading...";
                    if (snapshot.hasData && snapshot.data!.exists) {
                      ngoName = snapshot.data!['ngoName'];
                    }
                    return Text(
                      "Official $ngoName Portal. Enter your project PIN.",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: kSlate400,
                      ),
                      textAlign: TextAlign.center,
                    );
                  }
              ),
              const SizedBox(height: 32),

              // PIN Input Field
              // CORRECT
              TextField(
                controller: _pinController,
                obscureText: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(letterSpacing: 12), // <--- Moved here!
                decoration: InputDecoration(
                  hintText: "P R O J E C T  P I N",
                  hintStyle: TextStyle(letterSpacing: 4, color: kSlate400.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSlate100),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kSlate100),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kBlue),
                  ),
                ),
              ),

              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPinWithFirebase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Enter Secure Portal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ORIGINAL SCREEN: Operational Dashboard
// This shows ONLY after successful PIN entry
// ==========================================
class NGOOperationalDashboard extends StatelessWidget {
  const NGOOperationalDashboard({super.key});

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

          Row(
            children: [
              _ngoStat("ACTIVE ZONES", "04", kBlue),
              const SizedBox(width: 12),
              _ngoStat("DISBURSED", "RM 12.5k", kEmerald),
            ],
          ),

          const SizedBox(height: 32),
          const SectionTitle(title: "Managed Disaster Zones", icon: Icons.map, color: kBlue),
          const SizedBox(height: 16),

          _managedZoneCard("Rantau Panjang, Kelantan", "Monitoring", 92),
          _managedZoneCard("Baling, Kedah", "Relief Dispatched", 78),

          const SizedBox(height: 32),
          _ngoActionButton("Publish New Field Report", Icons.description, kBlue),
          const SizedBox(height: 12),
          _ngoActionButton("Verify Donor Receipt (Scan QR)", Icons.qr_code, kSlate800),
        ],
      ),
    );
  }

  // (Your original helper methods here...)
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
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

// class SectionTitle extends StatelessWidget {
//   final String title;
//   final IconData icon;
//   final Color color;
//
//   const SectionTitle({
//     super.key,
//     required this.title,
//     required this.icon,
//     required this.color,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 20, color: color),
//         const SizedBox(width: 8),
//         Text(
//           title,
//           style: GoogleFonts.inter(
//             fontSize: 18,
//             fontWeight: FontWeight.w800,
//             color: const Color(0xFF1E293B), // kSlate800
//           ),
//         ),
//       ],
//     );
//   }
// }

// ==========================================
// GLOBAL CACHE (Above the class)
// ==========================================
List<dynamic> _cachedAiNeeds = [];
DateTime? _lastFetchTime;
String _globalLastUpdated = "Never";
DateTime? _lastSuccessfulFetch;

class ReliefMap extends StatefulWidget {
  final VoidCallback? onTopUp;

  const ReliefMap({super.key, this.onTopUp});
  @override
  State<ReliefMap> createState() => _ReliefMapState();
  }

class _ReliefMapState extends State<ReliefMap> {
  String _selectedFilter = "All";
  final List<String> _categories = ["All", "Flood Relief", "Food Security", "Medical Aid"];

  // Define your reliable images here once
  final Map<String, String> _categoryImages = {
    'Education': "https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400&q=80",
    'Clothing': "https://images.unsplash.com/photo-1523381210434-271e8be1f52b?w=400&q=80",
    'Food': "https://images.unsplash.com/photo-1488521787991-ed7bbaae773c?w=400&q=80",
    'Medical': "https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400&q=80",
    'Disaster Relief': "https://images.pexels.com/photos/6995201/pexels-photo-6995201.jpeg?auto=compress&cs=tinysrgb&w=400", // Flood
    'Money': "https://images.unsplash.com/photo-1593113598332-cd288d649433?w=400&q=80", // Generic
    'Default': "https://images.unsplash.com/photo-1469571486292-0ba58a3f068b?w=400&q=80",
  };

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

  // --- FIXED ZOOM FUNCTION ---
  void _safeMapMove({required MapLatLng latLng, required double zoom}) {
    // We remove 'addPostFrameCallback' so it updates INSTANTLY.
    // We wrap it in setState to force the Map widget to redraw immediately.
    if (mounted) {
      setState(() {
        _zoomPanBehavior.focalLatLng = latLng;
        _zoomPanBehavior.zoomLevel = zoom;
      });
    }
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

      // Inside _fetchNewDataFromAI
      final prompt = "Search active disaster situations in Malaysia (Last 48h). Categories: Flood Relief, Food Security, Medical Aid. Return strictly RAW JSON LIST ONLY. Provide exactly 3 specific items for each category in needed_items. Format: [{\"location\": \"string\", \"category\": \"string\", \"description\": \"string\", \"score\": 90, \"lat\": 4.0, \"lng\": 101.0, \"severities\": {\"edu\": \"Medium/High/Critical\", \"cloth\": \"Medium/High/Critical\", \"food\": \"Medium/High/Critical\", \"med\": \"Medium/High/Critical\", \"rel\": \"Medium/High/Critical\"}, \"needed_items\": {\"edu\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"cloth\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"food\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"med\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"rel\": [\"Item 1\", \"Item 2\", \"Item 3\"]}}]";
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
        border: Border.all(
            color: isSelected ? kEmerald : kSlate100,
            width: isSelected ? 2.5 : 1
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: kEmerald.withOpacity(0.1), blurRadius: 10)]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['category']?.toString().toUpperCase() ?? "GENERAL",
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kSlate400),
              ),
              const Text(
                "VERIFIED",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kEmerald),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item['location'] ?? "Unknown",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
          ),
          const SizedBox(height: 4),
          Text(item['description'] ?? "",
              style: const TextStyle(color: kSlate500, fontSize: 12)
          ),
          const SizedBox(height: 16),

          // --- FIXED BUTTON: WRAPS TEXT AND CENTERED ---
          // --- FIXED BUTTON: FULL WIDTH BUT COMPACT HEIGHT ---
          SizedBox(
            width: double.infinity, // Spans the entire width of the card
            child: ElevatedButton.icon(
              onPressed: () => _showContributeDialog(context, item),
              icon: const Icon(LucideIcons.arrowUpRight, size: 16),
              label: const Text(
                "Contribute Now",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kEmerald,
                foregroundColor: Colors.white,
                elevation: 0,
                // Adjust vertical padding to make the box "thinner"
                padding: const EdgeInsets.symmetric(vertical: 8),
                // Remove the default minimum height (usually 48)
                minimumSize: const Size(double.infinity, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )
          // ------------------------------------------
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

  void _showContributeDialog(BuildContext context, Map<String, dynamic> item) {
    int step = 0; // 0: Selection, 1: Form, 2: Confirm, 3: Error, 4: Success
    String? selectedOption;
    String? selectedBank;
    bool isPaying = false;
    double currentWalletBalance = 0.0;
    final TextEditingController amountController = TextEditingController(text: "50");
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    showDialog(
      context: context,
      barrierDismissible: !isPaying,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogHeader(item, context),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        if (step == 0) ...[
                          // STEP 0: SELECTION
                          _buildContributeCard(
                            title: "Donate Money",
                            sub: "Secured transaction via KitaCare Wallet.",
                            icon: LucideIcons.banknote,
                            iconBg: const Color(0xFFD1FAE5),
                            iconColor: kEmerald,
                            isSelected: selectedOption == 'money',
                            selectedBorderColor: kEmerald,
                            selectedBgColor: kEmerald.withOpacity(0.08),
                            onTap: () => setDialogState(() => selectedOption = 'money'),
                          ),
                          const SizedBox(height: 16),
                          _buildContributeCard(
                            title: "Donate Items",
                            sub: "Contribute physical goods (Books, Food, etc.)",
                            icon: LucideIcons.package,
                            iconBg: const Color(0xFFDBEAFE),
                            iconColor: kBlue,
                            isSelected: selectedOption == 'items',
                            selectedBorderColor: kBlue,
                            selectedBgColor: kBlue.withOpacity(0.08),
                            onTap: () => setDialogState(() => selectedOption = 'items'),
                          ),
                          const SizedBox(height: 24),
                          if (selectedOption != null)
                            _buildStepButton(
                              label: "Confirm Selection",
                              color: selectedOption == 'money' ? kEmerald : kBlue,
                              onTap: () {
                                if (selectedOption == 'money') setDialogState(() => step = 1);
                                else  _showItemSelectionDialog(context, item);
                              },
                            )
                        ] else if (step == 1) ...[
                          // STEP 1: FORM
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("SELECT FUNDING SOURCE",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 8),
                          _buildBankDropdown(uid, selectedBank, (val) {
                            setDialogState(() => selectedBank = val);
                          }),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("CONTRIBUTION AMOUNT (RM)",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 8),

                          // The Amount Stepper Input
                          _buildAmountStepper(amountController, () => setDialogState(() {})),

                          const SizedBox(height: 8),

                          // --- NEW: Helper Text for Limit ---
                          const Center(
                            child: Text(
                              "Maximum contribution limit: RM 99,999",
                              style: TextStyle(fontSize: 11, color: kSlate400, fontWeight: FontWeight.w600),
                            ),
                          ),

                          const SizedBox(height: 24),
                          _buildStepButton(
                            label: "Proceed to Payment",
                            icon: LucideIcons.arrowRight,
                            onTap: () {
                              // --- NEW: VALIDATION LOGIC ---
                              double donateAmount = double.tryParse(amountController.text) ?? 0.0;

                              if (donateAmount >= 100000) {
                                Navigator.pop(context);
                                // Show error and DO NOT proceed to step 2
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Donation amount must be below RM 100,000."),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                return;
                              }

                              if (donateAmount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text("Please enter a valid amount."),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                                return;
                              }

                              // If validation passes, move to the next step
                              setDialogState(() => step = 2);
                            },
                          ),
                        ] else if (step == 2) ...[
                          // STEP 2: CONFIRM
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text("CONFIRM SECURE PAYMENT",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
                          ),
                          const SizedBox(height: 16),
                          _buildStepButton(
                            label: isPaying ? "" : "Pay RM ${amountController.text} Secured",
                            icon: isPaying ? null : LucideIcons.lock,
                            isLoading: isPaying,
                            onTap: () async {
                              // 1. DECLARE VARIABLES FIRST
                              final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
                              double donateAmount = double.tryParse(amountController.text) ?? 0.0;
                              bool isUsingInternalWallet = (selectedBank ?? "KitaCare Wallet") == "KitaCare Wallet";

                              // 2. CHECK FUNDING (ONLY FOR INTERNAL WALLET)
                              if (isUsingInternalWallet) {
                                final userSnapshot = await userRef.get();
                                currentWalletBalance = (userSnapshot.data()?['walletBalance'] ?? 0.0).toDouble();

                                if (donateAmount > currentWalletBalance) {
                                  setDialogState(() => step = 3); // Go to Error Step
                                  return;
                                }
                              }

                              // 3. START PAYING ANIMATION
                              setDialogState(() => isPaying = true);

                              try {
                                // 4. CALCULATE LIVES (RM 10 = 1 Life)
                                int calculatedLives = (donateAmount / 10).floor();
                                if (calculatedLives < 1) calculatedLives = 1;

                                String cat = item['category'] ?? "";
                                String imageToSave = _categoryImages['Money']!; // Default
                                if (cat.contains("Flood")) imageToSave = _categoryImages['Disaster Relief']!;
                                else if (cat.contains("Food")) imageToSave = _categoryImages['Food']!;
                                else if (cat.contains("Medical")) imageToSave = _categoryImages['Medical']!;
                                else if (cat.contains("Education")) imageToSave = _categoryImages['Education']!;
                                else if (cat.contains("Clothes")) imageToSave = _categoryImages['Clothing']!;
                                else if (cat.contains("Shirts")) imageToSave = _categoryImages['Clothing']!;

                                // 5. DATABASE UPDATES
                                if (isUsingInternalWallet) {
                                  await userRef.update({
                                    'walletBalance': FieldValue.increment(-donateAmount),
                                    'impactValue': FieldValue.increment(donateAmount),
                                    'livesTouched': FieldValue.increment(calculatedLives),
                                  });
                                } else {
                                  // External Bank: Only update Impact and Lives
                                  await userRef.update({
                                    'impactValue': FieldValue.increment(donateAmount),
                                    'livesTouched': FieldValue.increment(calculatedLives),
                                  });
                                }

                                // 6. CREATE TRACKING RECORD
                                // await userRef.collection('donations').add({
                                //   'id': "KC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
                                //   'target': item['location'] ?? "Relief Project",
                                //   'status': "Processing",
                                //   'type': 'money',
                                //   'amount': donateAmount,
                                //   'imageUrl': imageToSave,
                                //   'milestones': [
                                //     {'label': 'Payment Verified', 'date': 'Today', 'done': true},
                                //     {'label': 'NGO Allocation', 'date': 'Pending', 'done': false},
                                //     {'label': 'Final Disbursement', 'date': '', 'done': false},
                                //   ],
                                //   'timestamp': FieldValue.serverTimestamp(),
                                // });
                                // 6. CREATE TRACKING RECORD
                                await userRef.collection('donations').add({
                                  'id': "KC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
                                  'target': item['location'] ?? "Relief Project",

                                  // ---> ADD THIS ONE LINE <---
                                  'category': item['category'] ?? "Relief Aid",

                                  'status': "Processing",
                                  'type': 'money',
                                  'amount': donateAmount,
                                  'imageUrl': imageToSave,
                                  'milestones': [
                                    {'label': 'Payment Verified', 'date': 'Today', 'done': true},
                                    {'label': 'NGO Allocation', 'date': 'Pending', 'done': false},
                                    {'label': 'Final Disbursement', 'date': '', 'done': false},
                                  ],
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) {
                                  setDialogState(() {
                                    isPaying = false;
                                    step = 4; // Move to Success Step
                                  });
                                }
                              } catch (e) {
                                debugPrint("Payment Error: $e");
                                setDialogState(() => isPaying = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Payment failed. Please try again."))
                                );
                              }
                            },
                          ),
                        ] else if (step == 3) ...[
                          // STEP 3: ERROR
                          const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 48),
                          const SizedBox(height: 16),
                          const Text("Insufficient Funding",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kSlate800)),
                          const SizedBox(height: 8),
                          const Text("Your balance is too low for this transaction.", textAlign: TextAlign.center, style: TextStyle(color: kSlate500, fontSize: 13)),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: kSlate50, borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Wallet Balance:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text("RM ${currentWalletBalance.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildStepButton(
                            label: "Top Up Wallet",
                            icon: LucideIcons.plusCircle,
                            onTap: () {
                              Navigator.pop(context);
                              if (widget.onTopUp != null) widget.onTopUp!();
                            },
                          ),
                        ] else if (step == 4) ...[
                          // STEP 4: INTEGRATED SUCCESS UI
                          const Icon(LucideIcons.checkCircle, color: kEmerald, size: 64),
                          const SizedBox(height: 16),
                          const Text("Contribution Successful!",
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kSlate800)),
                          const SizedBox(height: 8),
                          const Text("Thank you for your kindness. Your support will make a real impact.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: kSlate500, fontSize: 13)),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: kEmerald.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Amount Transferred:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                Text("RM ${amountController.text}.00",
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: kEmerald)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildStepButton(
                            label: "Return to Map",
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Replace your existing _showItemSelectionDialog
  void _showItemSelectionDialog(BuildContext context, Map<String, dynamic> item) {
    final Map<String, dynamic> sev = item['severities'] ?? {};
    final Map<String, dynamic> itemsList = item['needed_items'] ?? {};

    // Track selection locally (Captured by the StatefulBuilder)
    String selectedCategory = "";

    showDialog(
      context: context,
      builder: (context) {
        // STATEFUL BUILDER IS KEY HERE
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogHeader(item, context),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // --- ROW 1: Education & Clothing ---
                        Row(
                          children: [
                            _buildItemCategoryCard(
                              "Education",
                              LucideIcons.book,
                              sev['edu'] ?? "abc",
                                  () {
                                setDialogState(() => selectedCategory = "Education");
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  _showCategoryItemSelection(context, item, "EDUCATION",
                                      List<String>.from(itemsList['edu'] ?? ["Books"]),
                                      "Education"); // <--- ADD THIS PARAMETER
                                });
                              },
                              isSelected: selectedCategory == "Education",
                            ),
                            const SizedBox(width: 12),
                            _buildItemCategoryCard(
                              "Clothing",
                              LucideIcons.shirt,
                              sev['cloth'] ?? "abc",
                                  () {
                                setDialogState(() => selectedCategory = "Clothing");
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  _showCategoryItemSelection(context, item, "CLOTHING", List<String>.from(itemsList['cloth'] ?? ["Clothes"]), "Clothing");
                                });
                              },
                              isSelected: selectedCategory == "Clothing",
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // --- ROW 2: Food & Medical ---
                        Row(
                          children: [
                            _buildItemCategoryCard(
                              "Food",
                              LucideIcons.shoppingBag,
                              sev['food'] ?? "abc",
                                  () {
                                setDialogState(() => selectedCategory = "Food");
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  _showCategoryItemSelection(context, item, "FOOD", List<String>.from(itemsList['food'] ?? ["Rice"]), "Food");
                                });
                              },
                              isSelected: selectedCategory == "Food",
                            ),
                            const SizedBox(width: 12),
                            _buildItemCategoryCard(
                              "Medical",
                              LucideIcons.stethoscope,
                              sev['med'] ?? "abc",
                                  () {
                                setDialogState(() => selectedCategory = "Medical");
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  _showCategoryItemSelection(context, item, "MEDICAL", List<String>.from(itemsList['med'] ?? ["Meds"]), "Medical");
                                });
                              },
                              isSelected: selectedCategory == "Medical",
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // --- ROW 3: Disaster Relief ---
                        Row(
                          children: [
                            _buildItemCategoryCard(
                              "Disaster Relief",
                              LucideIcons.cloudLightning,
                              sev['rel'] ?? "abc", // 'rel' matches your AI JSON key
                                  () {
                                setDialogState(() => selectedCategory = "Disaster Relief");
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  _showCategoryItemSelection(context, item, "DISASTER RELIEF", List<String>.from(itemsList['rel'] ?? ["Tents", "Flashlights"]), "Disaster Relief");
                                });
                              },
                              isSelected: selectedCategory == "Disaster Relief",
                            ),
                            const SizedBox(width: 12),
                            // Empty Expanded widget to keep the layout grid balanced (2 columns)
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryItemSelection(BuildContext context, Map<String, dynamic> item, String categoryTitle, List<String> items, String categoryKey) {
    String? selectedItem;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogHeader(item, context),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("SELECT ITEM IN $categoryTitle",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
                          const SizedBox(height: 16),

                          // ITEM LIST
                          ...items.map((itemName) {
                            bool isSelected = selectedItem == itemName;
                            return GestureDetector(
                              onTap: () => setDialogState(() => selectedItem = itemName),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                    color: isSelected ? kEmerald.withOpacity(0.08) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isSelected ? kEmerald : Colors.transparent, width: 2)
                                ),
                                child: Row(
                                  children: [
                                    Text(itemName, style: TextStyle(fontWeight: FontWeight.w700, color: isSelected ? kEmerald : kSlate800)),
                                    const Spacer(),
                                    if(isSelected) const Icon(LucideIcons.checkCircle2, color: kEmerald, size: 18)
                                  ],
                                ),
                              ),
                            );
                          }).toList(),

                          const SizedBox(height: 12),

                          // MATCH BUTTON
                          _buildStepButton(
                            label: "Match with NGO",
                            icon: LucideIcons.zap,
                            color: selectedItem != null ? kEmerald : kSlate300,
                            onTap: () {
                              if (selectedItem != null) {
                                Navigator.pop(context); // Close selection dialog
                                // OPEN THE NEW AI MATCHING PROCESS
                                _showMatchProcessDialog(context, item, selectedItem!, categoryKey);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  // void _showMatchProcessDialog(BuildContext context, Map<String, dynamic> locationData, String selectedItem, String categoryKey) {
  //   int state = 0;
  //   bool isSaving = false;
  //   String? generatedQrData;
  //   String deliveryMethod = 'self'; // 'self' or 'driver'
  //   final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
  //
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       // --- NEW: STREAMBUILDER FETCHES THE ADDRESS IN REAL-TIME ---
  //       return StreamBuilder<DocumentSnapshot>(
  //           stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
  //           builder: (context, userSnapshot) {
  //
  //             // Extract the address
  //             String currentAddress = "";
  //             if (userSnapshot.hasData && userSnapshot.data!.exists) {
  //               final data = userSnapshot.data!.data() as Map<String, dynamic>?;
  //               currentAddress = data?['address']?.toString().trim() ?? "";
  //             }
  //             bool hasAddress = currentAddress.isNotEmpty;
  //
  //             return StatefulBuilder(
  //               builder: (context, setState) {
  //                 return Dialog(
  //                   insetPadding: const EdgeInsets.symmetric(horizontal: 20),
  //                   backgroundColor: Colors.white,
  //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  //                   child: Column(
  //                     mainAxisSize: MainAxisSize.min,
  //                     children: [
  //                       _buildDialogHeader(locationData, context),
  //
  //                       Padding(
  //                         padding: const EdgeInsets.all(24),
  //                         child: state == 0
  //                         // --- STATE 0: SIMULATION LOADING ---
  //                             ? Column(
  //                           children: [
  //                             const SizedBox(height: 20),
  //                             const SizedBox(
  //                               width: 60, height: 60,
  //                               child: CircularProgressIndicator(color: kEmerald, strokeWidth: 5),
  //                             ),
  //                             const SizedBox(height: 24),
  //                             Text("AI is finding local needs...",
  //                                 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kSlate500)),
  //                             const SizedBox(height: 24),
  //                             TextButton(
  //                               onPressed: () async {
  //                                 await Future.delayed(const Duration(milliseconds: 800));
  //                                 setState(() => state = 1);
  //                               },
  //                               child: const Text("Click to simulate match",
  //                                   style: TextStyle(color: kEmerald, fontWeight: FontWeight.bold)),
  //                             ),
  //                             const SizedBox(height: 20),
  //                           ],
  //                         )
  //                             : state == 1
  //                         // --- STATE 1: MATCH FOUND DETAILS & DELIVERY CHOICE ---
  //                             ? Column(
  //                           children: [
  //                             Container(
  //                               padding: const EdgeInsets.all(16),
  //                               decoration: BoxDecoration(
  //                                 color: kEmerald.withOpacity(0.08),
  //                                 borderRadius: BorderRadius.circular(16),
  //                                 border: Border.all(color: kEmerald.withOpacity(0.2)),
  //                               ),
  //                               child: Row(
  //                                 crossAxisAlignment: CrossAxisAlignment.start,
  //                                 children: [
  //                                   const Icon(LucideIcons.zap, color: kEmerald, size: 24),
  //                                   const SizedBox(width: 12),
  //                                   Expanded(
  //                                     child: RichText(
  //                                       text: TextSpan(
  //                                           style: GoogleFonts.inter(color: kSlate800, fontSize: 13, height: 1.4),
  //                                           children: [
  //                                             const TextSpan(text: "AI Match Found! ", style: TextStyle(fontWeight: FontWeight.w900, color: kEmerald)),
  //                                             const TextSpan(text: "Your contribution for "),
  //                                             TextSpan(text: selectedItem, style: const TextStyle(fontWeight: FontWeight.w800)),
  //                                             const TextSpan(text: " is critical for the "),
  //                                             TextSpan(text: "${locationData['location']} ", style: const TextStyle(fontWeight: FontWeight.w800)),
  //                                             const TextSpan(text: "zone."),
  //                                           ]
  //                                       ),
  //                                     ),
  //                                   ),
  //                                 ],
  //                               ),
  //                             ),
  //                             const SizedBox(height: 16),
  //
  //                             // Delivery Selection
  //                             const Align(
  //                               alignment: Alignment.centerLeft,
  //                               child: Text("SELECT DELIVERY METHOD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
  //                             ),
  //                             const SizedBox(height: 12),
  //                             Row(
  //                               children: [
  //                                 Expanded(
  //                                   child: _buildDeliveryOption(
  //                                     title: "Self\nDrop-off",
  //                                     icon: LucideIcons.mapPin,
  //                                     isSelected: deliveryMethod == 'self',
  //                                     onTap: () => setState(() => deliveryMethod = 'self'),
  //                                   ),
  //                                 ),
  //                                 const SizedBox(width: 12),
  //                                 Expanded(
  //                                   child: _buildDeliveryOption(
  //                                     title: "Courier\nPick-up",
  //                                     icon: LucideIcons.truck,
  //                                     isSelected: deliveryMethod == 'driver',
  //                                     onTap: () => setState(() => deliveryMethod = 'driver'),
  //                                   ),
  //                                 ),
  //                               ],
  //                             ),
  //                             const SizedBox(height: 16),
  //
  //                             // Dynamic Location/Pickup Card
  //                             deliveryMethod == 'self'
  //                                 ? Container(
  //                               width: double.infinity,
  //                               padding: const EdgeInsets.all(20),
  //                               decoration: BoxDecoration(
  //                                 color: kSlate50,
  //                                 borderRadius: BorderRadius.circular(16),
  //                                 border: Border.all(color: kSlate100),
  //                               ),
  //                               child: Column(
  //                                 crossAxisAlignment: CrossAxisAlignment.start,
  //                                 children: [
  //                                   const Text("RECOMMENDED DROP-OFF", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
  //                                   const SizedBox(height: 12),
  //                                   Row(
  //                                     children: [
  //                                       const Icon(LucideIcons.mapPin, color: kBlue, size: 24),
  //                                       const SizedBox(width: 12),
  //                                       Expanded(
  //                                         child: Column(
  //                                           crossAxisAlignment: CrossAxisAlignment.start,
  //                                           children: [
  //                                             const Text("MERCY Malaysia HQ", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kSlate800)),
  //                                             Text("Kuala Lumpur City Centre", style: GoogleFonts.inter(color: kSlate500, fontSize: 12)),
  //                                           ],
  //                                         ),
  //                                       )
  //                                     ],
  //                                   ),
  //                                 ],
  //                               ),
  //                             )
  //                                 :
  //                             // --- NEW DYNAMIC ADDRESS UI ---
  //                             Container(
  //                               width: double.infinity,
  //                               padding: const EdgeInsets.all(20),
  //                               decoration: BoxDecoration(
  //                                 color: kBlue.withOpacity(0.05),
  //                                 borderRadius: BorderRadius.circular(16),
  //                                 border: Border.all(color: kBlue.withOpacity(0.2)),
  //                               ),
  //                               child: Column(
  //                                 crossAxisAlignment: CrossAxisAlignment.start,
  //                                 children: [
  //                                   Row(
  //                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                                     children: [
  //                                       const Text("DOORSTEP COURIER PICK-UP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: 0.5)),
  //                                       // The Edit Button
  //                                       GestureDetector(
  //                                         onTap: () => _editAddressDialog(context, uid, currentAddress),
  //                                         child: Container(
  //                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  //                                           decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBlue.withOpacity(0.2))),
  //                                           child: const Text("EDIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kBlue)),
  //                                         ),
  //                                       )
  //                                     ],
  //                                   ),
  //                                   const SizedBox(height: 12),
  //                                   Row(
  //                                     crossAxisAlignment: CrossAxisAlignment.start,
  //                                     children: [
  //                                       const Icon(LucideIcons.mapPin, color: kBlue, size: 24),
  //                                       const SizedBox(width: 12),
  //                                       Expanded(
  //                                         child: Column(
  //                                           crossAxisAlignment: CrossAxisAlignment.start,
  //                                           children: [
  //                                             Text(
  //                                                 hasAddress ? currentAddress : "No Address Registered",
  //                                                 style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: hasAddress ? kSlate800 : Colors.redAccent)
  //                                             ),
  //                                             const SizedBox(height: 4),
  //                                             Text(
  //                                                 hasAddress ? "Please verify this is the correct pick-up spot." : "Tap EDIT to add your address.",
  //                                                 style: GoogleFonts.inter(color: kSlate500, fontSize: 12)
  //                                             ),
  //                                           ],
  //                                         ),
  //                                       )
  //                                     ],
  //                                   ),
  //                                 ],
  //                               ),
  //                             ),
  //
  //                             const SizedBox(height: 24),
  //
  //                             // Confirm Button
  //                             _buildStepButton(
  //                               label: "Confirm & Get QR",
  //                               icon: LucideIcons.qrCode,
  //                               isLoading: isSaving,
  //                               onTap: () async {
  //                                 // NEW VALIDATION: Prevent courier without address
  //                                 if (deliveryMethod == 'driver' && !hasAddress) {
  //                                   ScaffoldMessenger.of(context).showSnackBar(
  //                                       const SnackBar(
  //                                         content: Text("Please add a pick-up address first."),
  //                                         backgroundColor: Colors.redAccent,
  //                                         behavior: SnackBarBehavior.floating,
  //                                       )
  //                                   );
  //                                   return;
  //                                 }
  //
  //                                 setState(() => isSaving = true);
  //
  //                                 // If driver selected, show a matching simulation
  //                                 if (deliveryMethod == 'driver') {
  //                                   setState(() => state = 2);
  //                                   await Future.delayed(const Duration(seconds: 2));
  //                                 }
  //
  //                                 String finalImage = _categoryImages[categoryKey] ?? _categoryImages['Default']!;
  //
  //                                 String qrCode = await _saveItemDonationToFirebase(locationData, selectedItem, finalImage, deliveryMethod);
  //
  //                                 if (context.mounted) {
  //                                   setState(() {
  //                                     isSaving = false;
  //                                     generatedQrData = qrCode;
  //                                     state = 3;
  //                                   });
  //                                 }
  //                               },
  //                             ),
  //                           ],
  //                         )
  //                             : state == 2
  //                         // --- STATE 2: FINDING COURIER SIMULATION ---
  //                             ? Column(
  //                           children: [
  //                             const SizedBox(height: 20),
  //                             const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: kBlue, strokeWidth: 5)),
  //                             const SizedBox(height: 24),
  //                             Text("Scheduling courier pick-up...", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kSlate500)),
  //                             const SizedBox(height: 20),
  //                           ],
  //                         )
  //                         // --- STATE 3: QR CODE DISPLAY ---
  //                             : Column(
  //                           children: [
  //                             const Text("DONATION REGISTERED", style: TextStyle(fontWeight: FontWeight.w900, color: kEmerald, letterSpacing: 1.0, fontSize: 12)),
  //                             const SizedBox(height: 20),
  //
  //                             Container(
  //                               padding: const EdgeInsets.all(16),
  //                               decoration: BoxDecoration(
  //                                   color: Colors.white,
  //                                   borderRadius: BorderRadius.circular(16),
  //                                   border: Border.all(color: kSlate100, width: 2),
  //                                   boxShadow: const [BoxShadow(color: kSlate100, blurRadius: 10)]
  //                               ),
  //                               child: Image.network(
  //                                 "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$generatedQrData",
  //                                 width: 150,
  //                                 height: 150,
  //                                 loadingBuilder: (context, child, loadingProgress) {
  //                                   if (loadingProgress == null) return child;
  //                                   return const SizedBox(width: 150, height: 150, child: Center(child: CircularProgressIndicator()));
  //                                 },
  //                               ),
  //                             ),
  //
  //                             const SizedBox(height: 16),
  //                             Text(generatedQrData ?? "ERROR", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kSlate800)),
  //
  //                             Text(
  //                                 deliveryMethod == 'self' ? "Show this to the NGO officer." : "Show this to the logistics courier.",
  //                                 style: const TextStyle(color: kSlate500, fontSize: 12)
  //                             ),
  //                             const SizedBox(height: 24),
  //
  //                             _buildStepButton(
  //                               label: "Save to Dashboard",
  //                               icon: LucideIcons.download,
  //                               onTap: () {
  //                                 Navigator.pop(context);
  //                                 _showSuccessAlert(context);
  //                               },
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 );
  //               },
  //             );
  //           }
  //       );
  //     },
  //   );
  // }
  void _showMatchProcessDialog(BuildContext context, Map<String, dynamic> locationData, String selectedItem, String categoryKey) {
    int state = 0;
    bool isSaving = false;
    bool isAiFetching = false;
    String? generatedQrData;
    String deliveryMethod = 'self'; // 'self' or 'driver'

    // --- NEW: Dynamic AI Match Variables ---
    String dynamicNgoName = "Searching...";
    String dynamicNgoAddress = "Searching...";

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // STREAMBUILDER FETCHES THE ADDRESS IN REAL-TIME
        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnapshot) {

              // Extract the address
              String currentAddress = "";
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>?;
                currentAddress = data?['address']?.toString().trim() ?? "";
              }
              bool hasAddress = currentAddress.isNotEmpty;

              return StatefulBuilder(
                builder: (context, setState) {

                  // --- NEW: ACTUAL AI FETCH FUNCTION ---
                  Future<void> fetchNearestNGO() async {
                    setState(() => isAiFetching = true);
                    try {
                      final apiKey = dotenv.env['GEMINI_FIND_KEY'];
                      final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: apiKey!);

                      final String targetLoc = locationData['location'] ?? "Malaysia";

                      // Prompt Gemini to find a nearby NGO
                      final prompt = """
                      Find a real or highly plausible NGO branch, relief center, or drop-off point near $targetLoc, Malaysia that accepts $selectedItem donations. 
                      Return STRICTLY a RAW JSON object with 'ngo_name' and 'address'. DO NOT wrap in markdown.
                      Example: {"ngo_name": "MERCY Malaysia Kelantan Chapter", "address": "Jalan Hospital, 15200 Kota Bharu, Kelantan"}
                      """;

                      final response = await model.generateContent([Content.text(prompt)]);
                      String rawJson = response.text ?? "{}";

                      // Cleanup markdown if AI accidentally includes it
                      rawJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
                      int start = rawJson.indexOf('{');
                      int end = rawJson.lastIndexOf('}');
                      if (start != -1 && end != -1) rawJson = rawJson.substring(start, end + 1);

                      final decoded = jsonDecode(rawJson);

                      setState(() {
                        dynamicNgoName = decoded['ngo_name'] ?? "MERCY Malaysia Hub";
                        dynamicNgoAddress = decoded['address'] ?? targetLoc;
                        state = 1; // Move to results state
                        isAiFetching = false;
                      });
                    } catch (e) {
                      debugPrint("AI NGO Match Error: $e");
                      // Fallback if AI fails (e.g. Quota limit)
                      setState(() {
                        dynamicNgoName = "Malaysian Red Crescent Hub";
                        dynamicNgoAddress = "Nearest available center to ${locationData['location']}";
                        state = 1;
                        isAiFetching = false;
                      });
                    }
                  }

                  return Dialog(
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDialogHeader(locationData, context),

                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: state == 0
                          // --- STATE 0: SIMULATION LOADING ---
                              ? Column(
                            children: [
                              const SizedBox(height: 20),
                              const SizedBox(
                                width: 60, height: 60,
                                child: CircularProgressIndicator(color: kEmerald, strokeWidth: 5),
                              ),
                              const SizedBox(height: 24),
                              Text(isAiFetching ? "Scanning local logistics..." : "AI is finding local needs...",
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kSlate500)),
                              const SizedBox(height: 24),

                              // Trigger the REAL AI fetch instead of just waiting
                              isAiFetching
                                  ? const SizedBox(height: 48) // Space holder while fetching
                                  : TextButton(
                                onPressed: fetchNearestNGO, // <-- CALLS AI HERE
                                child: const Text("Find Nearest Drop-off",
                                    style: TextStyle(color: kEmerald, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                              : state == 1
                          // --- STATE 1: MATCH FOUND DETAILS & DELIVERY CHOICE ---
                              ? Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: kEmerald.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kEmerald.withOpacity(0.2)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(LucideIcons.zap, color: kEmerald, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                            style: GoogleFonts.inter(color: kSlate800, fontSize: 13, height: 1.4),
                                            children: [
                                              const TextSpan(text: "AI Match Found! ", style: TextStyle(fontWeight: FontWeight.w900, color: kEmerald)),
                                              const TextSpan(text: "Your contribution for "),
                                              TextSpan(text: selectedItem, style: const TextStyle(fontWeight: FontWeight.w800)),
                                              const TextSpan(text: " is critical for the "),
                                              TextSpan(text: "${locationData['location']} ", style: const TextStyle(fontWeight: FontWeight.w800)),
                                              const TextSpan(text: "zone."),
                                            ]
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Delivery Selection
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text("SELECT DELIVERY METHOD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDeliveryOption(
                                      title: "Self\nDrop-off",
                                      icon: LucideIcons.mapPin,
                                      isSelected: deliveryMethod == 'self',
                                      onTap: () => setState(() => deliveryMethod = 'self'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDeliveryOption(
                                      title: "Courier\nPick-up",
                                      icon: LucideIcons.truck,
                                      isSelected: deliveryMethod == 'driver',
                                      onTap: () => setState(() => deliveryMethod = 'driver'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Dynamic Location/Pickup Card
                              deliveryMethod == 'self'
                                  ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: kSlate50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kSlate100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("AI RECOMMENDED DROP-OFF", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kEmerald, letterSpacing: 0.5)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(LucideIcons.mapPin, color: kBlue, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // --- NEW: Dynamic AI Name and Address ---
                                              Text(dynamicNgoName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kSlate800)),
                                              Text(dynamicNgoAddress, style: GoogleFonts.inter(color: kSlate500, fontSize: 12)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              )
                                  :
                              // --- NEW DYNAMIC ADDRESS UI ---
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: kBlue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: kBlue.withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("DOORSTEP COURIER PICK-UP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlue, letterSpacing: 0.5)),
                                        // The Edit Button
                                        GestureDetector(
                                          onTap: () => _editAddressDialog(context, uid, currentAddress),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBlue.withOpacity(0.2))),
                                            child: const Text("EDIT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kBlue)),
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(LucideIcons.mapPin, color: kBlue, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  hasAddress ? currentAddress : "No Address Registered",
                                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: hasAddress ? kSlate800 : Colors.redAccent)
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  hasAddress ? "Please verify this is the correct pick-up spot." : "Tap EDIT to add your address.",
                                                  style: GoogleFonts.inter(color: kSlate500, fontSize: 12)
                                              ),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Confirm Button
                              _buildStepButton(
                                label: "Confirm & Get QR",
                                icon: LucideIcons.qrCode,
                                isLoading: isSaving,
                                onTap: () async {
                                  // NEW VALIDATION: Prevent courier without address
                                  if (deliveryMethod == 'driver' && !hasAddress) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("Please add a pick-up address first."),
                                          backgroundColor: Colors.redAccent,
                                          behavior: SnackBarBehavior.floating,
                                        )
                                    );
                                    return;
                                  }

                                  setState(() => isSaving = true);

                                  // If driver selected, show a matching simulation
                                  if (deliveryMethod == 'driver') {
                                    setState(() => state = 2);
                                    await Future.delayed(const Duration(seconds: 2));
                                  }

                                  String finalImage = _categoryImages[categoryKey] ?? _categoryImages['Default']!;

                                  String qrCode = await _saveItemDonationToFirebase(locationData, selectedItem, finalImage, deliveryMethod);

                                  if (context.mounted) {
                                    setState(() {
                                      isSaving = false;
                                      generatedQrData = qrCode;
                                      state = 3;
                                    });
                                  }
                                },
                              ),
                            ],
                          )
                              : state == 2
                          // --- STATE 2: FINDING COURIER SIMULATION ---
                              ? Column(
                            children: [
                              const SizedBox(height: 20),
                              const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: kBlue, strokeWidth: 5)),
                              const SizedBox(height: 24),
                              Text("Scheduling courier pick-up...", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: kSlate500)),
                              const SizedBox(height: 20),
                            ],
                          )
                          // --- STATE 3: QR CODE DISPLAY ---
                              : Column(
                            children: [
                              const Text("DONATION REGISTERED", style: TextStyle(fontWeight: FontWeight.w900, color: kEmerald, letterSpacing: 1.0, fontSize: 12)),
                              const SizedBox(height: 20),

                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: kSlate100, width: 2),
                                    boxShadow: const [BoxShadow(color: kSlate100, blurRadius: 10)]
                                ),
                                child: Image.network(
                                  "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$generatedQrData",
                                  width: 150,
                                  height: 150,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(width: 150, height: 150, child: Center(child: CircularProgressIndicator()));
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),
                              Text(generatedQrData ?? "ERROR", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kSlate800)),

                              Text(
                                  deliveryMethod == 'self' ? "Show this to the NGO officer." : "Show this to the logistics courier.",
                                  style: const TextStyle(color: kSlate500, fontSize: 12)
                              ),
                              const SizedBox(height: 24),

                              _buildStepButton(
                                label: "Save to Dashboard",
                                icon: LucideIcons.download,
                                onTap: () {
                                  Navigator.pop(context);
                                  _showSuccessAlert(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
        );
      },
    );
  }

  // HELPER: Small pop-up to edit address from the map UI
  void _editAddressDialog(BuildContext context, String uid, String currentAddress) {
    final TextEditingController controller = TextEditingController(text: currentAddress);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. CUSTOM HEADER (Changed to Green)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: kEmerald, // <-- 1. CHANGED HERE
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Update Address",
                                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              const Text(
                                "COURIER PICK-UP LOGISTICS",
                                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (!isSaving) Navigator.pop(context);
                          },
                          icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
                        )
                      ],
                    ),
                  ),

                  // 2. BODY CONTENT
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "FULL STREET ADDRESS",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),

                        // Formatted Text Field
                        TextField(
                          controller: controller,
                          maxLines: 3,
                          autofocus: true,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kSlate800),
                          decoration: InputDecoration(
                            hintText: "Enter your full address (Street, City, State)...",
                            hintStyle: const TextStyle(color: kSlate400, fontWeight: FontWeight.w400),
                            filled: true,
                            fillColor: kSlate50,
                            contentPadding: const EdgeInsets.all(20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kSlate100, width: 2)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kEmerald, width: 2)), // <-- 2. CHANGED HERE
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 3. FULL WIDTH ACTION BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kEmerald, // <-- 3. CHANGED HERE
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                              if (controller.text.trim().isEmpty) return;

                              setDialogState(() => isSaving = true);

                              // Save straight to Firebase
                              await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                'address': controller.text.trim()
                              });

                              if (context.mounted) Navigator.pop(context); // Close the edit dialog
                            },
                            child: isSaving
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            )
                                : const Text("Save Address", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // NEW: DONATION & COURIER TRACKING DASHBOARD
  // ==========================================
  void _showTrackingDashboard(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // 1. Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: kBlue,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Track Logistics", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                          const Text("COURIER & DROP-OFF STATUS", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: Colors.white, size: 24),
                    )
                  ],
                ),
              ),

              // 2. Body (Real-time Stream from Firebase)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('donations')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: kBlue));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No active logistics found.", style: TextStyle(color: kSlate500, fontWeight: FontWeight.w600)),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return _buildDonationTrackerCard(context, data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDonationTrackerCard(BuildContext context, Map<String, dynamic> data) {
    bool isMoney = data['type'] == 'money';
    String title = isMoney ? "RM ${data['amount']}" : (data['itemName'] ?? "Donation");
    String target = data['target'] ?? "Unknown Location";
    String status = data['status'] ?? "Processing";
    String deliveryMethod = data['deliveryMethod'] ?? "self";
    List<dynamic> milestones = data['milestones'] ?? [];
    String qrData = data['qrCodeData'] ?? "";

    bool isCompleted = status.toLowerCase().contains("distributed") || status.toLowerCase().contains("arrived");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kSlate100, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Info Row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Item Image
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: kSlate100,
                    image: data['imageUrl'] != null
                        ? DecorationImage(image: NetworkImage(data['imageUrl']), fit: BoxFit.cover)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kSlate800)),
                      Text(target, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: kSlate500)),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted ? kEmerald.withOpacity(0.1) : kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isCompleted ? kEmerald : kBlue),
                  ),
                )
              ],
            ),
          ),

          const Divider(height: 1, color: kSlate100),

          // Milestone Timeline (Updates in real-time!)
          if (milestones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: List.generate(milestones.length, (index) {
                  final m = milestones[index];
                  bool isDone = m['done'] == true;
                  bool isLast = index == milestones.length - 1;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline Graphic (Dots and Lines)
                      Column(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: isDone ? kBlue : Colors.white,
                              border: Border.all(color: isDone ? kBlue : kSlate200, width: 2),
                              shape: BoxShape.circle,
                            ),
                            child: isDone ? const Icon(LucideIcons.check, size: 12, color: Colors.white) : null,
                          ),
                          if (!isLast)
                            Container(width: 2, height: 30, color: isDone ? kBlue : kSlate200),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Milestone Text
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            m['label'] ?? "",
                            style: TextStyle(
                              fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                              color: isDone ? kSlate800 : kSlate400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    ],
                  );
                }),
              ),
            ),

          // Show QR Code Button (Only if it's an item and not completed yet)
          if (!isCompleted && !isMoney && qrData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showSavedQRDialog(context, qrData, target, deliveryMethod),
                  icon: const Icon(LucideIcons.qrCode, size: 16),
                  label: const Text("Show QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kBlue, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  void _showSavedQRDialog(BuildContext context, String qrData, String target, String deliveryMethod) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("DONATION QR CODE", style: TextStyle(fontWeight: FontWeight.w900, color: kBlue, letterSpacing: 1.0, fontSize: 12)),
              const SizedBox(height: 16),

              // Generated QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    border: Border.all(color: kSlate100, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
                ),
                child: Image.network(
                  "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$qrData",
                  width: 150,
                  height: 150,
                  loadingBuilder: (context, child, progress) => progress == null ? child : const CircularProgressIndicator(color: kBlue),
                ),
              ),
              const SizedBox(height: 16),

              Text(qrData, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kSlate800)),
              Text(target, style: const TextStyle(color: kSlate500, fontSize: 12)),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: kBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  deliveryMethod == 'self' ? "Show this to the NGO drop-off officer." : "Show this to the logistics courier.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildDeliveryOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? kEmerald.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kEmerald : kSlate100,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? kEmerald : kSlate400, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? kEmerald : kSlate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER: SAVE TO FIREBASE (Returns the QR String)
  // ==========================================
  // Future<String> _saveItemDonationToFirebase(Map<String, dynamic> locationData, String item, String imageUrl) async {
  //   final user = FirebaseAuth.instance.currentUser;
  //   if (user == null) return "ERROR";
  //
  //   // 1. Generate unique QR Data
  //   String uniqueId = "KC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
  //   String qrString = "$uniqueId-${item.substring(0,3).toUpperCase()}";
  //
  //   // 2. Add to Firebase
  //   await FirebaseFirestore.instance
  //       .collection('users')
  //       .doc(user.uid)
  //       .collection('donations')
  //       .add({
  //     'id': uniqueId,
  //     'target': locationData['location'] ?? "Unknown Zone",
  //     'status': "Pending Drop-off",
  //     'type': 'item',
  //     'itemName': item,
  //     'imageUrl': imageUrl, // Saved here!
  //     'qrCodeData': qrString, // STORED IN FIREBASE
  //     'milestones': [
  //       {'label': 'Pledge Confirmed', 'date': 'Today', 'done': true},
  //       {'label': 'Drop-off Verified', 'date': '', 'done': false},
  //       {'label': 'Distributed', 'date': '', 'done': false},
  //     ],
  //     'timestamp': FieldValue.serverTimestamp(),
  //   });
  //
  //   return qrString; // Return the string so we can generate the image
  // }
  Future<String> _saveItemDonationToFirebase(Map<String, dynamic> locationData, String item, String imageUrl, String deliveryMethod) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "ERROR";

    // 1. Generate unique QR Data
    String uniqueId = "KC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
    String qrString = "$uniqueId-${item.substring(0,3).toUpperCase()}";

    // 2. Setup Milestones based on method
    String initialStatus = deliveryMethod == 'self' ? "Pending Drop-off" : "Awaiting Courier"; // Changed
    List<Map<String, dynamic>> finalMilestones = deliveryMethod == 'self'
        ? [
      {'label': 'Pledge Confirmed', 'date': 'Today', 'done': true},
      {'label': 'Drop-off Verified', 'date': '', 'done': false},
      {'label': 'Distributed', 'date': '', 'done': false},
    ]
        : [
      // --- ADDED THE 4TH MILESTONE HERE FOR COURIER ---
      {'label': 'Courier Assigned', 'date': 'Today', 'done': true},
      {'label': 'Picked Up & In Transit', 'date': '', 'done': false},
      {'label': 'Arrived at NGO Hub', 'date': '', 'done': false},
      {'label': 'Drop-off Verified', 'date': '', 'done': false},
      {'label': 'Distributed', 'date': '', 'done': false}// <--- NEW MILESTONE
    ];

    // 3. Add to Firebase
    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(user.uid)
    //     .collection('donations')
    //     .add({
    //   'id': uniqueId,
    //   'target': locationData['location'] ?? "Unknown Zone",
    //   'status': initialStatus, // Dynamic Status
    //   'type': 'item',
    //   'deliveryMethod': deliveryMethod, // Save method type to DB
    //   'itemName': item,
    //   'imageUrl': imageUrl,
    //   'qrCodeData': qrString,
    //   'milestones': finalMilestones, // Dynamic Milestones
    //   'timestamp': FieldValue.serverTimestamp(),
    // });
    // 3. Add to Firebase
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('donations')
        .add({
      'id': uniqueId,
      'target': locationData['location'] ?? "Unknown Zone",

      // ---> ADD THIS LINE HERE <---
      'category': (locationData['category'] is String) ? locationData['category'] : "Relief Aid",

      'status': initialStatus,
      'type': 'item',
      'deliveryMethod': deliveryMethod,
      'itemName': item,
      'imageUrl': imageUrl,
      'qrCodeData': qrString,
      'milestones': finalMilestones,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return qrString;
  }

// --- HELPER FOR THE ITEM CARDS ---
  // Replace your existing _buildItemCategoryCard with this updated version
  Widget _buildItemCategoryCard(
      String title,
      IconData icon,
      String urgency,
      VoidCallback onTap,
      {bool isSelected = false} // Added parameter
      ) {
    // Color logic...
    Color bgColor;
    Color textColor;

    switch (urgency.toLowerCase()) {
      case 'critical':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        break;
      case 'high':
        bgColor = const Color(0xFFFFEDD5);
        textColor = const Color(0xFF9A3412);
        break;
      case 'medium':
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        break;
      default:
        bgColor = kSlate100;
        textColor = kSlate500;
    }

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer( // Changed to AnimatedContainer for smooth transition
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            // Logic: If selected, Emerald background tint + Emerald Border
            color: isSelected ? kEmerald.withOpacity(0.05) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // Logic: Green border if selected, invisible/grey if not
              color: isSelected ? kEmerald : const Color(0xFFF1F5F9),
              width: isSelected ? 2.5 : 1, // Thicker border when selected
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: kEmerald, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isSelected ? kEmerald : kSlate800 // Text turns green too
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  urgency.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PROFESSIONAL ERROR HELPER ---
  void _showFundingError(BuildContext context, double currentBalance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(LucideIcons.alertCircle, color: Colors.redAccent, size: 24),
            SizedBox(width: 12),
            Text("Insufficient Funding", style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your KitaCare Wallet balance is insufficient to complete this transaction.",
                style: TextStyle(color: kSlate500, fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSlate50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Current Balance:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text("RM ${currentBalance.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: kSlate800)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: kSlate400, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kEmerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (widget.onTopUp != null) widget.onTopUp!(); // Call the trigger
            },
            child: const Text("Top Up Wallet"),
          ),
        ],
      ),
    );
  }

  // --- NEW UI HELPERS ---

  Widget _buildBankDropdown(String uid, String? currentVal, Function(String?) onChanged) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('wallet').snapshots(),
      builder: (context, snapshot) {
        List<String> items = ["KitaCare Wallet"]; // Default first option
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            items.add(doc['bankName'] ?? "Unknown Bank");
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal ?? items.first,
              isExpanded: true,
              icon: const Icon(LucideIcons.chevronDown, size: 16, color: kSlate400),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kSlate800),
              items: items.map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAmountStepper(TextEditingController ctrl, VoidCallback onUpdate) {
    void adjust(int offset) {
      int current = int.tryParse(ctrl.text) ?? 0;
      int next = (current + offset).clamp(1, 10000);
      ctrl.text = next.toString();
      onUpdate();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        // THE FIX: Emerald border from your image
        border: Border.all(color: kEmerald, width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24), // Spacer to balance the arrows on the right
          Expanded(
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              onChanged: (v) => onUpdate(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kSlate800),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          // THE FIX: Vertical arrows on the right side
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => adjust(1), // Increase by 10
                child: const Icon(LucideIcons.chevronUp, size: 14, color: kSlate400),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => adjust(-1), // Decrease by 10
                child: const Icon(LucideIcons.chevronDown, size: 14, color: kSlate400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogHeader(Map<String, dynamic> item, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: kEmerald,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Contribute to ${item['location'] ?? 'Location'}",
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                const Text("MERCY MALAYSIA",
                    style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              ],
            ),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, color: Colors.white, size: 20))
        ],
      ),
    );
  }

  Widget _buildStepButton({
    required String label,
    IconData? icon,
    Color color = kEmerald,
    required VoidCallback onTap,
    bool isLoading = false
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Added to keep things centered
          children: [
            // 1. Wrap the Text in Flexible
            Flexible(
              child: Text(
                label,
                // 2. Add ellipsis so it shows "Pay RM 500..." instead of breaking
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 10),
              Icon(icon, size: 20)
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // UPDATED: SUCCESS ALERT (CLOSES ALL DIALOGS)
  // ==========================================
  void _showSuccessAlert(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent clicking outside to close
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Success Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kEmerald.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.check, color: kEmerald, size: 40),
              ),
              const SizedBox(height: 24),

              // 2. Title
              Text(
                "Contribution Successful!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kSlate800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // 3. Subtitle
              const Text(
                "Thank you for your kindness. Your support is now recorded in the KitaCare ecosystem.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kSlate500,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // 4. Action Button
              _buildStepButton(
                label: "Return to Map",
                // --- THE FIX IS HERE ---
                // This command closes ALL open dialogs until it hits the main screen
                onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                // -----------------------
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContributeCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required bool isSelected,
    required Color selectedBorderColor,
    required Color selectedBgColor, // Signature fix
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          // Logic: Shade color when selected, else standard off-white
          color: isSelected ? selectedBgColor : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBorderColor : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: selectedBorderColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isSelected ? selectedBorderColor : kSlate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub,
                    style: TextStyle(
                      color: isSelected ? selectedBorderColor.withOpacity(0.7) : kSlate500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key}); // Use super parameters

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _seenCount = 0;

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('donations')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Use a List of typed Maps to avoid 'dynamic' errors
        List<Map<String, dynamic>> notifications = [];

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            // Casting milestones safely as a List of dynamic objects
            final List<dynamic> milestones = data['milestones'] ?? [];
            final String itemName = data['itemName'] ?? (data['type'] == 'money' ? "Donation" : "Item");
            final String target = data['target'] ?? "Unknown Hub";
            final String method = data['deliveryMethod'] ?? "self";

            for (int i = 1; i < milestones.length; i++) {
              final m = milestones[i] as Map<String, dynamic>; // Cast individual milestone
              if (m['done'] == true) {
                notifications.add({
                  'title': m['label'] ?? 'Update',
                  'body': method == 'driver'
                      ? 'Update: Your $itemName for $target has reached this status.'
                      : 'Update: Your drop-off for $target is verified.',
                  'icon': method == 'driver' ? LucideIcons.truck : LucideIcons.box,
                  'color': i == milestones.length - 1 ? Colors.green : Colors.blue,
                });
              }
            }
          }
        }

        int currentCount = notifications.length;
        bool hasUnread = currentCount > _seenCount;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _seenCount = currentCount);
                _showNotificationSheet(context, notifications);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Icon(LucideIcons.bell, color: Colors.black87, size: 22),
              ),
            ),

            if (hasUnread)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18), // Ensure it stays circular
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "${currentCount - _seenCount}",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
          ],
        );
      },
    );
  }

  void _showNotificationSheet(BuildContext context, List<Map<String, dynamic>> notifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSheetContent(context, notifications),
    );
  }

  // Refactored helper to keep the code clean
  Widget _buildSheetContent(BuildContext context, List<Map<String, dynamic>> notifications) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black87)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, color: Colors.black54),
                )
              ],
            ),
          ),

          // List
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                // Reverse index so newest notifications appear first
                final notif = notifications[notifications.length - 1 - index];
                return _buildNotificationItem(notif);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bellRing, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("You're all caught up!", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (notif['color'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(notif['icon'], color: notif['color'], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif['title'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 4),
                Text(notif['body'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4)),
                const SizedBox(height: 8),
                Text("Just now", style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

//
// // ==========================================
// // 5. AI ADVISOR PAGE (WEB STYLE MATCH)
// // ==========================================
// class AiAdvisorPage extends StatefulWidget {
//   const AiAdvisorPage({super.key});
//
//   @override
//   State<AiAdvisorPage> createState() => _AiAdvisorPageState();
// }
//
// class _AiAdvisorPageState extends State<AiAdvisorPage> {
//   final TextEditingController _controller = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   bool _isLoading = false;
//
//   // Initial Chat History matching your screenshot
//   final List<Map<String, dynamic>> _messages = [
//     {
//       "role": "ai",
//       "text": "Selamat Sejahtera! I am KitaCare AI. I can help you find verified NGOs, manage your donation wallet, or find the nearest drop-off point for physical items. What would you like to know?"
//     }
//   ];
//
//   Future<void> _sendMessage() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return;
//
//     // 1. Add User Message
//     setState(() {
//       _messages.add({"role": "user", "text": text});
//       _isLoading = true;
//     });
//     _controller.clear();
//     _scrollToBottom();
//
//     try {
//       // 2. Call Gemini AI
//       final apiKey = dotenv.env['GEMINI_ADVISOR_KEY'];
//       print("API KEY: ${dotenv.env['GEMINI_ADVISOR_KEY']}");
//       if (apiKey == null) throw "API Key not found";
//
//       final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: apiKey);
//
//       // Context for the AI to act as KitaCare Advisor
//       final prompt = """
//       You are KitaCare AI, an expert humanitarian advisor for a Malaysian disaster relief app.
//       Your tone is professional, empathetic, and distinctively Malaysian (use 'Selamat Sejahtera', 'Rakyat', etc. occasionally).
//
//       Key features you know about:
//       1. Verified NGOs (ROS/SSM registered).
//       2. KitaCare Wallet (Secure donations).
//       3. Relief Map (Real-time disaster tracking).
//       4. Item Donations (Physical goods drop-off).
//
//       Answer the user's question briefly and helpfully.
//       User: $text
//       """;
//
//       final response = await model.generateContent([Content.text(prompt)]);
//
//       // 3. Add AI Response
//       setState(() {
//         _messages.add({
//           "role": "ai",
//           "text": response.text?.replaceAll('*', '') ?? "I apologize, I couldn't process that request."
//         });
//         _isLoading = false;
//       });
//       _scrollToBottom();
//
//     } catch (e) {
//       setState(() {
//         _messages.add({"role": "ai", "text": "Sorry, I am having trouble connecting to the server. Please try again."});
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: const Color(0xFFF8FAFC), // Light background like web
//       child: Column(
//         children: [
//           // --- HEADER CARD (Matching Screenshot) ---
//           Container(
//             width: double.infinity,
//             margin: const EdgeInsets.all(20),
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: const Color(0xFFE2E8F0)),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.02),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 )
//               ],
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(10),
//                   decoration: BoxDecoration(
//                     color: kEmerald,
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: const Icon(LucideIcons.messageSquare, color: Colors.white, size: 24),
//                 ),
//                 const SizedBox(width: 16),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "KitaCare DONOR AI",
//                       style: GoogleFonts.inter(
//                         fontSize: 16,
//                         fontWeight: FontWeight.w800,
//                         color: kSlate800,
//                       ),
//                     ),
//                     const Text(
//                       "EXPERT ADVISOR",
//                       style: TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w900,
//                         color: kEmerald,
//                         letterSpacing: 1.0,
//                       ),
//                     ),
//                   ],
//                 )
//               ],
//             ),
//           ),
//
//           // --- CHAT AREA ---
//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               itemCount: _messages.length + (_isLoading ? 1 : 0),
//               itemBuilder: (context, index) {
//                 if (index == _messages.length) {
//                   return Align(
//                     alignment: Alignment.centerLeft,
//                     child: Container(
//                       margin: const EdgeInsets.only(bottom: 16),
//                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: const BorderRadius.only(
//                           topLeft: Radius.circular(16),
//                           topRight: Radius.circular(16),
//                           bottomLeft: Radius.zero,
//                           bottomRight: Radius.circular(16),
//                         ),
//                         border: Border.all(color: const Color(0xFFE2E8F0)),
//                       ),
//                       child: const PulsingLoadingText(),
//                     ),
//                   );
//                 }
//
//                 final msg = _messages[index];
//                 final isAi = msg['role'] == 'ai';
//
//                 return Align(
//                   alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
//                   child: Container(
//                     margin: const EdgeInsets.only(bottom: 16),
//                     padding: const EdgeInsets.all(20),
//                     constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
//                     decoration: BoxDecoration(
//                       color: isAi ? Colors.white : kEmerald,
//                       borderRadius: BorderRadius.only(
//                         topLeft: const Radius.circular(16),
//                         topRight: const Radius.circular(16),
//                         bottomLeft: isAi ? Radius.zero : const Radius.circular(16),
//                         bottomRight: isAi ? const Radius.circular(16) : Radius.zero,
//                       ),
//                       border: isAi ? Border.all(color: const Color(0xFFE2E8F0)) : null,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.03),
//                           blurRadius: 8,
//                           offset: const Offset(0, 2),
//                         )
//                       ],
//                     ),
//                     child: Text(
//                       msg['text'],
//                       style: GoogleFonts.inter(
//                         fontSize: 14,
//                         height: 1.5,
//                         color: isAi ? kSlate800 : Colors.white,
//                         fontWeight: isAi ? FontWeight.w400 : FontWeight.w500,
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//
//           // --- INPUT AREA (Matching Screenshot) ---
//           Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               border: Border(top: BorderSide(color: kSlate100)),
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _controller,
//                     onSubmitted: (_) => _sendMessage(),
//                     style: const TextStyle(fontSize: 14),
//                     decoration: InputDecoration(
//                       hintText: "Ask about donation points or tax certificates...",
//                       hintStyle: const TextStyle(color: kSlate400, fontSize: 13),
//                       filled: true,
//                       fillColor: const Color(0xFFF8FAFC),
//                       contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                         borderSide: const BorderSide(color: kEmerald),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 GestureDetector(
//                   onTap: _sendMessage,
//                   child: Container(
//                     padding: const EdgeInsets.all(14),
//                     decoration: BoxDecoration(
//                       color: kEmerald,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// ==========================================
// 5. AI ADVISOR PAGE (DYNAMIC FOR DONOR & NGO)
// ==========================================
class AiAdvisorPage extends StatefulWidget {
  final String role; // 'donor' or 'ngo'
  const AiAdvisorPage({super.key, required this.role});

  @override
  State<AiAdvisorPage> createState() => _AiAdvisorPageState();
}

class _AiAdvisorPageState extends State<AiAdvisorPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    // Initialize the first message based on the role
    _messages = [
      {
        "role": "ai",
        "text": widget.role == 'ngo'
            ? "Selamat Sejahtera! I am KitaCare NGO Support AI. I can assist you with managing physical item needs, verifying drop-off receipts, or checking disbursement logs. How can I help your mission today?"
            : "Selamat Sejahtera! I am KitaCare AI. I can help you find verified NGOs, manage your donation wallet, or find the nearest drop-off point for physical items. What would you like to know?"
      }
    ];
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final apiKey = dotenv.env['GEMINI_ADVISOR_KEY'];
      if (apiKey == null) throw "API Key not found";

      final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: apiKey);

      // Context changes based on Role
      final prompt = widget.role == 'ngo'
          ? """You are KitaCare NGO Support AI. Assist NGOs in Malaysia with disaster relief logistics, verifying donor QR codes, inventory management, and field report generation. Keep responses professional, helpful, and concise. User: $text"""
          : """You are KitaCare AI, an expert humanitarian advisor for a Malaysian disaster relief app. Assist individual donors with finding verified NGOs, wallet donations, and map tracking. Keep responses professional, helpful, and concise. User: $text""";

      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        _messages.add({
          "role": "ai",
          "text": response.text?.replaceAll('*', '') ?? "I apologize, I couldn't process that request."
        });
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({"role": "ai", "text": "Sorry, I am having trouble connecting to the server. Please try again."});
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNgo = widget.role == 'ngo';
    final themeColor = isNgo ? kBlue : kEmerald;
    final titleText = isNgo ? "KitaCare NGO AI" : "KitaCare DONOR AI";

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // --- HEADER CARD ---
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.messageSquare, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleText, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate800)),
                    Text("EXPERT ADVISOR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: themeColor, letterSpacing: 1.0)),
                  ],
                )
              ],
            ),
          ),

          // --- CHAT AREA ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const PulsingLoadingText(),
                    ),
                  );
                }

                final msg = _messages[index];
                final isAi = msg['role'] == 'ai';

                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                      color: isAi ? Colors.white : themeColor, // Blue for NGO user texts, Green for Donor
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isAi ? Radius.zero : const Radius.circular(16),
                        bottomRight: isAi ? const Radius.circular(16) : Radius.zero,
                      ),
                      border: isAi ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Text(
                      msg['text'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: isAi ? kSlate800 : Colors.white,
                        fontWeight: isAi ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- INPUT AREA ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kSlate100))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isNgo ? "Ask about receipt verification or logistics..." : "Ask about donation points or tax certificates...",
                      hintStyle: const TextStyle(color: kSlate400, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CUSTOM ANIMATED LOADING TEXT (AI ADVISOR)
// ==========================================
class PulsingLoadingText extends StatefulWidget {
  const PulsingLoadingText({super.key});
  @override
  State<PulsingLoadingText> createState() => _PulsingLoadingTextState();
}

class _PulsingLoadingTextState extends State<PulsingLoadingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.4,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // THIS IS THE FIXED LINE: It now has and a Text widget
        children: const [
          Icon(Icons.auto_awesome, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text(
            "Consulting KitaCare Knowledge...",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

const Color kSlate200 = Color(0xFFE2E8F0);
const Color kSlate600 = Color(0xFF475569);
const Color kBlueBrand = Color(0xFF2563EB);
//
// class MyImpactPage extends StatelessWidget {
//   const MyImpactPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: StreamBuilder<DocumentSnapshot>(
//         stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
//         builder: (context, userSnapshot) {
//           if (userSnapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator(color: kEmerald));
//           }
//
//           var userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
//           // Assuming 'impactPoints' is a field in your user doc to determine tier
//           double impactValue = 0.0;
//           if (userData?['impactPoints'] != null) {
//             var p = userData!['impactPoints'];
//             // Check if it's a number, or if it's a Map containing a number
//             if (p is num) {
//               impactValue = p.toDouble();
//             } else if (p is Map && p['current'] != null) {
//               impactValue = (p['current'] as num).toDouble();
//             }
//           }
//
//           // --- Dynamic Tier Calculation ---
//           String tierName = "Supporter";
//           String badgeText = "BRONZE";
//           String description = "Start your journey to help the community.";
//
//           if (impactValue >= 100) {
//             tierName = "Community Pillar";
//             badgeText = "GOLD";
//             description = "You are in the top 10% of Malaysian supporters this year.";
//           } else if (impactValue >= 50) {
//             tierName = "Active Contributor";
//             badgeText = "SILVER";
//             description = "You're making a real difference in the community!";
//           }
//
//           return StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(uid)
//                 .collection('donations')
//                 .orderBy('timestamp', descending: true)
//                 .snapshots(),
//             builder: (context, donationSnapshot) {
//               if (donationSnapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator(color: kEmerald));
//               }
//
//               final donations = donationSnapshot.data?.docs ?? [];
//
//               int itemsDonated = 0;
//               double totalMoney = 0;
//
//               for (var doc in donations) {
//                 var data = doc.data() as Map<String, dynamic>;
//                 // Logic: check if type is 'item' or 'monetary'
//                 if (data['type'] == 'item') {
//                   itemsDonated += (data['quantity'] as num? ?? 1).toInt();
//                 } else {
//                   totalMoney += (data['amount'] ?? 0).toDouble();
//                 }
//               }
//
//               String moneyStr = totalMoney % 1 == 0
//                   ? totalMoney.toInt().toString()
//                   : totalMoney.toStringAsFixed(2);
//
//               return SingleChildScrollView(
//                 padding: const EdgeInsets.all(32.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       "My Charitable Journey",
//                       style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: kSlate800),
//                     ),
//                     const SizedBox(height: 6),
//                     const Text(
//                       "Quantifying your impact across the Malaysian community.",
//                       style: TextStyle(color: kSlate500, fontSize: 14),
//                     ),
//                     const SizedBox(height: 32),
//
//                     LayoutBuilder(builder: (context, constraints) {
//                       return Wrap(
//                         spacing: 16,
//                         runSpacing: 16,
//                         children: [
//                           _buildStatCard("Cash Support", "RM $moneyStr", kEmerald),
//                           _buildStatCard("Physical Items", itemsDonated.toString(), kBlueBrand),
//
//                           // FIX: Use named arguments here to pass the dynamic variables
//                           _buildTierCard(
//                             tierName: tierName,
//                             badgeText: badgeText,
//                             description: description,
//                           ),
//                         ],
//                       );
//                     }),
//
//                     const SizedBox(height: 48),
//
//                     // --- AUDIT LIST (TABLE) ---
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         border: Border.all(color: kSlate100),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.all(24.0),
//                             child: Text(
//                               "Contribution Audit & Certificates",
//                               style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate800),
//                             ),
//                           ),
//                           const Divider(height: 1, color: kSlate100),
//
//                           if (donations.isEmpty)
//                             const Padding(
//                               padding: EdgeInsets.all(32.0),
//                               child: Center(
//                                 child: Text("No contributions yet. Start your journey today!", style: TextStyle(color: kSlate400)),
//                               ),
//                             )
//                           else
//                             Column(
//                               children: [
//                                 _buildTableHeader(),
//                                 ...donations.map((d) {
//                                   var data = d.data() as Map<String, dynamic>;
//                                   return Column(
//                                     children: [
//                                       _buildTableRow(context, data),
//                                       const Divider(height: 1, color: kSlate100),
//                                     ],
//                                   );
//                                 }),
//                               ],
//                             ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   // --- WIDGET HELPER: Stat Card ---
//   Widget _buildStatCard(String label, String value, Color valueColor) {
//     return Container(
//       constraints: const BoxConstraints(minWidth: 160),
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: kSlate100),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(label, style: const TextStyle(color: kSlate500, fontWeight: FontWeight.w600, fontSize: 12)),
//           const SizedBox(height: 8),
//           Text(value, style: GoogleFonts.inter(color: valueColor, fontWeight: FontWeight.w900, fontSize: 22)),
//         ],
//       ),
//     );
//   }
//
//   // --- WIDGET HELPER: Tier Card ---
//   Widget _buildTierCard({
//     required String tierName,
//     required String badgeText,
//     required String description,
//   }) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//       decoration: BoxDecoration(
//         color: const Color(0xFF064E3B), // The dark green from your photo
//         borderRadius: BorderRadius.circular(24),
//       ),
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Positioned(
//             right: -10,
//             top: -10,
//             child: Icon(
//               LucideIcons.award,
//               size: 100,
//               color: Colors.white.withValues(alpha: 0.05), // Subtle watermark
//             ),
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Text(
//                       "PHILANTHROPY TIER",
//                       style: TextStyle(
//                         color: Color(0xFF34D399),
//                         fontSize: 11,
//                         fontWeight: FontWeight.w800,
//                         letterSpacing: 1.2,
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       tierName, // Dynamically pulled from the 'if' logic above
//                       style: GoogleFonts.inter(
//                         color: Colors.white,
//                         fontSize: 22,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       description, // Dynamically pulled from the 'if' logic above
//                       style: TextStyle(
//                         color: Colors.white.withValues(alpha: 0.6),
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF34D399),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   badgeText,
//                   style: const TextStyle(
//                     color: Color(0xFF064E3B),
//                     fontSize: 12,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//   // --- WIDGET HELPER: Table Header ---
//   Widget _buildTableHeader() {
//     const TextStyle headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kSlate400, letterSpacing: 0.5);
//     return const Padding(
//       padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//       child: Row(
//         children: [
//           Expanded(flex: 3, child: Text("DATE", style: headerStyle)),
//           Expanded(flex: 2, child: Text("TYPE", style: headerStyle)), // Added Type
//           Expanded(flex: 4, child: Text("CAUSE", style: headerStyle)),
//           Expanded(flex: 3, child: Text("NGO", style: headerStyle)),
//           Expanded(flex: 3, child: Text("IMPACT", style: headerStyle)),
//           Expanded(flex: 2, child: Text("ACTION", style: headerStyle)),
//         ],
//       ),
//     );
//   }
//
//   // --- WIDGET HELPER: Table Row ---
//   // --- WIDGET HELPER: Table Row ---
//   Widget _buildTableRow(BuildContext context, Map<String, dynamic> data) {
//     bool isItem = data['type'] == 'item';
//
//     // 1. Format Date
//     String dateStr = "---";
//     if (data['timestamp'] != null) {
//       DateTime dt = (data['timestamp'] as Timestamp).toDate();
//       dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
//     }
//
//     // 2. Dynamic Cause [Location, Category]
//     String location = data['location'] ?? "Unknown";
//     String category = data['category'] ?? "General Relief";
//     String displayCause = "[$location, $category]";
//
//     // 3. Dynamic Impact Text
//     String impactText = isItem
//         ? "${data['quantity'] ?? 1}x ${data['itemName'] ?? 'Items'}"
//         : "RM ${data['amount'] ?? 0}";
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//       child: Row(
//         children: [
//           // DATE
//           Expanded(flex: 3, child: Text(dateStr, style: const TextStyle(color: kSlate500, fontSize: 13))),
//
//           // TYPE (Pill Label)
//           Expanded(
//             flex: 2,
//             child: UnconstrainedBox(
//               alignment: Alignment.centerLeft,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: isItem ? const Color(0xFFEEF2FF) : const Color(0xFFECFDF5),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text(
//                   isItem ? "ITEM" : "MONEY",
//                   style: TextStyle(
//                     color: isItem ? const Color(0xFF4F46E5) : const Color(0xFF10B981),
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // CAUSE [Location, Category]
//           Expanded(
//               flex: 4,
//               child: Text(
//                   displayCause,
//                   style: GoogleFonts.inter(
//                       fontWeight: FontWeight.w700,
//                       color: kSlate800,
//                       fontSize: 13
//                   )
//               )
//           ),
//
//           // NGO
//           Expanded(flex: 3, child: Text(data['ngo'] ?? "MERCY Malaysia", style: const TextStyle(color: kSlate500, fontSize: 13))),
//
//           // IMPACT
//           Expanded(
//               flex: 3,
//               child: Text(
//                   impactText,
//                   style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kSlate600, fontSize: 13)
//               )
//           ),
//
//           // ACTION
//           Expanded(
//             flex: 2,
//             child: _buildCertificateButton(context),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // --- WIDGET HELPER: Certificate Button ---
//   Widget _buildCertificateButton(BuildContext context) {
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: InkWell(
//         onTap: () {
//           // Trigger a simple notification for now
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text("Certificate generated and saved."),
//               backgroundColor: Color(0xFF1E293B), // kSlate800
//             ),
//           );
//         },
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//           decoration: BoxDecoration(
//             color: const Color(0xFFF8FAFC), // kSlate50
//             borderRadius: BorderRadius.circular(6),
//             border: Border.all(color: const Color(0xFFE2E8F0)), // kSlate200
//           ),
//           child: const Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(LucideIcons.download, size: 14, color: Color(0xFF475569)), // kSlate600
//               SizedBox(width: 6),
//               Text(
//                 "Certificate",
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF475569), // kSlate600
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// // }
// // ==========================================
// // 6. MY IMPACT PAGE (FIXED IMPLEMENTATION)
// // ==========================================
// class MyImpactPage extends StatelessWidget {
//   const MyImpactPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
//
//     return StreamBuilder<QuerySnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection('users')
//           .doc(uid)
//           .collection('donations')
//           .orderBy('timestamp', descending: true)
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator(color: kEmerald));
//         }
//
//         final docs = snapshot.data?.docs ?? [];
//         double totalCash = 0;
//         int totalItems = 0;
//
//         // FIXED: Corrected logic to iterate and extract totals
//         for (var doc in docs) {
//           final data = doc.data() as Map<String, dynamic>;
//
//           if (data['type'] == 'money') {
//             // Use .toDouble() for cash/currency
//             totalCash += (data['amount'] ?? 0.0).toDouble();
//           } else if (data['type'] == 'item') {
//             // FIX: Cast to num first, then convert to int
//             totalItems += (data['quantity'] as num? ?? 1).toInt();
//           }
//         }
//
//         return SingleChildScrollView(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 1. Header Section
//               Text("My Charitable Journey",
//                   style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: kSlate800)),
//               const SizedBox(height: 4),
//               const Text("Quantifying your impact across the Malaysian community.",
//                   style: TextStyle(color: kSlate500, fontSize: 14)),
//               const SizedBox(height: 32),
//
//               // 2. Horizontal Scroll for Stat Cards
//               SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 physics: const BouncingScrollPhysics(),
//                 child: Row(
//                   children: [
//                     _buildStatCard("Cash Support", "RM ${totalCash.toStringAsFixed(2)}", kEmerald),
//                     const SizedBox(width: 16),
//                     _buildStatCard("Physical Items", totalItems.toString(), kBlue),
//                     const SizedBox(width: 16),
//                     _buildTierCard(),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 32),
//
//               // 3. Contribution Table inside a Card Container
//               Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(color: kSlate100),
//                   boxShadow: [
//                     BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.all(24),
//                       child: Text("Contribution Audit & Certificates",
//                           style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate800)),
//                     ),
//                     const Divider(height: 1, color: kSlate100),
//                     if (docs.isEmpty)
//                       const Padding(
//                         padding: EdgeInsets.all(32),
//                         child: Center(child: Text("No contributions found yet.", style: TextStyle(color: kSlate400))),
//                       )
//                     else
//                       SingleChildScrollView(
//                         scrollDirection: Axis.horizontal,
//                         physics: const BouncingScrollPhysics(),
//                         child: DataTable(
//                           horizontalMargin: 24,
//                           columnSpacing: 32,
//                           columns: const [
//                             DataColumn(label: Text("DATE")),
//                             DataColumn(label: Text("TYPE")),
//                             DataColumn(label: Text("CAUSE")),
//                             DataColumn(label: Text("NGO")),
//                             DataColumn(label: Text("IMPACT")),
//                             DataColumn(label: Text("ACTION")),
//                           ],
//                           rows: docs.map((doc) => _buildDataRow(doc.data() as Map<String, dynamic>)).toList(),
//                         ),
//                       ),
//                   ],
//                 ),
//               )
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildStatCard(String title, String value, Color valueColor) {
//     return Container(
//       width: 180,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: kSlate100),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: const TextStyle(color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12)),
//           const SizedBox(height: 12),
//           Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: valueColor)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTierCard() {
//     return Container(
//       width: 320,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: const Color(0xFF064E3B),
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text("PHILANTHROPY TIER", style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w900)),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(color: const Color(0xFF34D399), borderRadius: BorderRadius.circular(8)),
//                 child: const Text("GOLD", style: TextStyle(color: Color(0xFF064E3B), fontSize: 10, fontWeight: FontWeight.w900)),
//               )
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text("Community Pillar", style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
//           const Text("You are in the top 10% of Malaysian supporters this year.", style: TextStyle(color: Colors.white70, fontSize: 12)),
//         ],
//       ),
//     );
//   }
//
//   DataRow _buildDataRow(Map<String, dynamic> data) {
//     bool isMoney = data['type'] == 'money';
//     String dateStr = "2024-10-24";
//     if (data['timestamp'] != null) {
//       DateTime d = (data['timestamp'] as Timestamp).toDate();
//       dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
//     }
//
//     return DataRow(cells: [
//       DataCell(Text(dateStr)),
//       DataCell(Text(isMoney ? "MONEY" : "ITEM")),
//       DataCell(Text(data['cause'] ?? "Relief Aid")),
//       DataCell(Text(data['ngo'] ?? "MERCY Malaysia")),
//       DataCell(Text(isMoney ? "RM ${data['amount']}" : "${data['quantity']}x ${data['itemName']}")),
//       DataCell(const Icon(LucideIcons.download, size: 16, color: kSlate400)),
//     ]);
//   }
// }

// // ==========================================
// // 6. MY IMPACT PAGE (DYNAMIC WITH FIRESTORE IMPACT SCORE)
// // ==========================================
// class MyImpactPage extends StatelessWidget {
//   const MyImpactPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
//
//     // 1. OUTER STREAM: Fetch the User's Document (for impactValue/Tier)
//     return StreamBuilder<DocumentSnapshot>(
//         stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
//         builder: (context, userSnapshot) {
//           if (userSnapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator(color: kEmerald));
//           }
//
//           var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
//
//           // SAFE EXTRACTION: Matches DonorDashboard logic
//           double impactScore = 0.0;
//           if (userData?['impactValue'] != null) {
//             var val = userData!['impactValue'];
//             impactScore = (val is Map)
//                 ? (val['amount']?.toDouble() ?? 0.0)
//                 : (val is num ? val.toDouble() : 0.0);
//           }
//
//           // 2. INNER STREAM: Fetch the Donations (for Table and Totals)
//           return StreamBuilder<QuerySnapshot>(
//             stream: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(uid)
//                 .collection('donations')
//                 .orderBy('timestamp', descending: true)
//                 .snapshots(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator(color: kEmerald));
//               }
//
//               final docs = snapshot.data?.docs ?? [];
//               double totalCash = 0;
//               int totalItems = 0;
//
//               // Calculate totals for the stat cards
//               for (var doc in docs) {
//                 final data = doc.data() as Map<String, dynamic>;
//                 if (data['type'] == 'money') {
//                   totalCash += (data['amount'] ?? 0.0).toDouble();
//                 } else if (data['type'] == 'item') {
//                   totalItems += (data['quantity'] as num? ?? 1).toInt();
//                 }
//               }
//
//               return SingleChildScrollView(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // 1. Header Section
//                     Text("My Charitable Journey",
//                         style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: kSlate800)),
//                     const SizedBox(height: 4),
//                     const Text("Quantifying your impact across the Malaysian community.",
//                         style: TextStyle(color: kSlate500, fontSize: 14)),
//                     const SizedBox(height: 32),
//
//                     // 2. Horizontal Scroll for Stat Cards
//                     SingleChildScrollView(
//                       scrollDirection: Axis.horizontal,
//                       physics: const BouncingScrollPhysics(),
//                       child: Row(
//                         children: [
//                           _buildStatCard("Cash Support", "RM ${totalCash.toStringAsFixed(2)}", kEmerald),
//                           const SizedBox(width: 16),
//                           _buildStatCard("Physical Items", totalItems.toString(), kBlue),
//                           const SizedBox(width: 16),
//                           _buildTierCard(impactScore),
//                         ],
//                       ),
//                     ),
//
//                     const SizedBox(height: 32),
//
//                     // 3. Contribution Table inside a Card Container
//                     Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(24),
//                         border: Border.all(color: kSlate100),
//                         boxShadow: [
//                           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
//                         ],
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Padding(
//                             padding: const EdgeInsets.all(24),
//                             child: Text("Contribution Audit & Certificates",
//                                 style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate800)),
//                           ),
//                           const Divider(height: 1, color: kSlate100),
//                           if (docs.isEmpty)
//                             const Padding(
//                               padding: EdgeInsets.all(32),
//                               child: Center(child: Text("No contributions found yet.", style: TextStyle(color: kSlate400))),
//                             )
//                           else
//                             SingleChildScrollView(
//                               scrollDirection: Axis.horizontal,
//                               physics: const BouncingScrollPhysics(),
//                               child: DataTable(
//                                 horizontalMargin: 24,
//                                 columnSpacing: 32,
//                                 columns: const [
//                                   DataColumn(label: Text("DATE")),
//                                   DataColumn(label: Text("TYPE")),
//                                   DataColumn(label: Text("CAUSE")),
//                                   DataColumn(label: Text("NGO")),
//                                   DataColumn(label: Text("IMPACT")),
//                                   DataColumn(label: Text("ACTION")),
//                                 ],
//                                 rows: docs.map((doc) => _buildDataRow(doc.data() as Map<String, dynamic>)).toList(),
//                               ),
//                             ),
//                         ],
//                       ),
//                     )
//                   ],
//                 ),
//               );
//             },
//           );
//         }
//     );
//   }
//
//   Widget _buildStatCard(String title, String value, Color valueColor) {
//     return Container(
//       width: 180,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: kSlate100),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: const TextStyle(color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12)),
//           const SizedBox(height: 12),
//           Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: valueColor)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTierCard(double impactScore) {
//     String tierName = "BRONZE";
//     String tierTitle = "Rising Supporter";
//     String tierDesc = "Your journey of making an impact begins here.";
//     Color badgeColor = const Color(0xFFFBBF24);
//     Color bgColor = const Color(0xFF78350F);
//
//     if (impactScore >= 5000) {
//       tierName = "PLATINUM";
//       tierTitle = "National Hero";
//       tierDesc = "You are in the top 1% of supporters this year.";
//       badgeColor = const Color(0xFF22D3EE);
//       bgColor = const Color(0xFF164E63);
//     } else if (impactScore >= 1000) {
//       tierName = "GOLD";
//       tierTitle = "Community Pillar";
//       tierDesc = "You are in the top 10% of Malaysian supporters.";
//       badgeColor = const Color(0xFF34D399);
//       bgColor = const Color(0xFF064E3B);
//     } else if (impactScore >= 200) {
//       tierName = "SILVER";
//       tierTitle = "Generous Giver";
//       tierDesc = "A consistent beacon of hope for communities.";
//       badgeColor = const Color(0xFF94A3B8);
//       bgColor = const Color(0xFF1E293B);
//     }
//
//     return Container(
//       width: 320,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text("PHILANTHROPY TIER", style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
//                 child: Text(tierName, style: TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.w900)),
//               )
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(tierTitle, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
//           Text(tierDesc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
//         ],
//       ),
//     );
//   }
//
//   DataRow _buildDataRow(Map<String, dynamic> data) {
//     bool isMoney = data['type'] == 'money';
//     String dateStr = "N/A";
//     if (data['timestamp'] != null) {
//       DateTime d = (data['timestamp'] as Timestamp).toDate();
//       dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
//     }
//
//     return DataRow(cells: [
//       DataCell(Text(dateStr)),
//       DataCell(Text(isMoney ? "MONEY" : "ITEM")),
//       DataCell(Text(data['cause'] ?? "Relief Aid")),
//       DataCell(Text(data['ngo'] ?? "MERCY Malaysia")),
//       DataCell(Text(isMoney ? "RM ${data['amount']}" : "${data['quantity']}x ${data['itemName']}")),
//       DataCell(const Icon(LucideIcons.download, size: 16, color: kSlate400)),
//     ]);
//   }
// }

// // ==========================================
// // 6. MY IMPACT PAGE (DYNAMIC WITH FIRESTORE IMPACT SCORE)
// // ==========================================
// class MyImpactPage extends StatelessWidget {
//   const MyImpactPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";
//
//     // 1. FETCH GLOBAL RELIEF CATEGORY (DYNAMIC)
//     return StreamBuilder<DocumentSnapshot>(
//         stream: FirebaseFirestore.instance.collection('relief_cache').doc('current_status').snapshots(),
//         builder: (context, cacheSnapshot) {
//           // Default fallback if database is empty
//           String globalCategory = "Relief Aid";
//
//           if (cacheSnapshot.hasData && cacheSnapshot.data!.exists) {
//             var cacheData = cacheSnapshot.data!.data() as Map<String, dynamic>;
//
//             // Navigate the 'results' array from your screenshot
//             List<dynamic>? results = cacheData['results'] as List<dynamic>?;
//
//             if (results != null && results.isNotEmpty) {
//               // This pulls "Flood Relief" (or whatever you change it to) from the first item
//               globalCategory = results[0]['category'] ?? "Relief Aid";
//               print("DEBUG: Category updated to -> $globalCategory");
//             }
//           }
//
//           // 2. Fetch User Data (Impact Score)
//           return StreamBuilder<DocumentSnapshot>(
//             stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
//             builder: (context, userSnapshot) {
//               if (userSnapshot.connectionState == ConnectionState.waiting) {
//                 return const Center(child: CircularProgressIndicator(color: kEmerald));
//               }
//
//               var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
//               double impactScore = (userData?['impactValue'] as num? ?? 0.0).toDouble();
//
//               // 3. Fetch Donations List
//               return StreamBuilder<QuerySnapshot>(
//                 stream: FirebaseFirestore.instance
//                     .collection('users')
//                     .doc(uid)
//                     .collection('donations')
//                     .orderBy('timestamp', descending: true)
//                     .snapshots(),
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return const Center(child: CircularProgressIndicator(color: kEmerald));
//                   }
//
//                   final docs = snapshot.data?.docs ?? [];
//                   double totalCash = 0;
//                   int totalItems = 0;
//
//                   for (var doc in docs) {
//                     final data = doc.data() as Map<String, dynamic>;
//                     if (data['type'] == 'money') {
//                       totalCash += (data['amount'] as num? ?? 0.0).toDouble();
//                     } else if (data['type'] == 'item') {
//                       totalItems += (data['quantity'] as num? ?? 1).toInt();
//                     }
//                   }
//
//                   return SingleChildScrollView(
//                     padding: const EdgeInsets.all(24),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text("My Charitable Journey",
//                             style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: kSlate800)),
//                         const SizedBox(height: 32),
//                         _buildTierCard(impactScore),
//                         const SizedBox(height: 16),
//                         Row(
//                           children: [
//                             Expanded(child: _buildStatCard("Cash Support", "RM ${totalCash.toStringAsFixed(2)}", kEmerald)),
//                             const SizedBox(width: 16),
//                             Expanded(child: _buildStatCard("Physical Items", totalItems.toString(), kBlueBrand)),
//                           ],
//                         ),
//                         const SizedBox(height: 32),
//                         Container(
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(24),
//                             border: Border.all(color: kSlate100),
//                           ),
//                           child: Column(
//                             children: [
//                               if (docs.isEmpty)
//                                 const Padding(
//                                   padding: EdgeInsets.all(32),
//                                   child: Center(child: Text("No contributions found yet.")),
//                                 )
//                               else
//                                 SingleChildScrollView(
//                                   scrollDirection: Axis.horizontal,
//                                   child: DataTable(
//                                     columns: const [
//                                       DataColumn(label: Text("DATE")),
//                                       DataColumn(label: Text("TYPE")),
//                                       DataColumn(label: Text("CAUSE")),
//                                       DataColumn(label: Text("NGO")),
//                                       DataColumn(label: Text("IMPACT")),
//                                       DataColumn(label: Text("ACTION")),
//                                     ],
//                                     // PASS THE DYNAMIC CATEGORY HERE
//                                     rows: docs.map((doc) {
//                                       final donationData = doc.data() as Map<String, dynamic>;
//                                       final String donationTarget = donationData['target'] ?? "";
//
//                                       // 1. LOOK UP THE CORRECT CATEGORY
//                                       // We search the 'activeReliefs' list for a map where 'location' == donationTarget
//                                       String matchedCategory = "Relief Aid"; // Fallback if no match is found
//
//                                       if (cacheSnapshot.hasData && cacheSnapshot.data!.exists) {
//                                         var cacheData = cacheSnapshot.data!.data() as Map<String, dynamic>;
//                                         List<dynamic> results = cacheData['results'] as List<dynamic>? ?? [];
//
//                                         // This finds the specific relief effort for this donation's location
//                                         var foundRelief = results.firstWhere(
//                                               (res) => res['location'] == donationTarget,
//                                           orElse: () => null,
//                                         );
//
//                                         if (foundRelief != null) {
//                                           matchedCategory = foundRelief['category'] ?? "Relief Aid";
//                                         }
//                                       }
//
//                                       // 2. PASS THE DYNAMIC CATEGORY TO YOUR FUNCTION
//                                       return _buildDataRow(donationData, matchedCategory);
//                                     }).toList(),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         )
//                       ],
//                     ),
//                   );
//                 },
//               );
//             },
//           );
//         }
//     );
//   }
//
//   Widget _buildStatCard(String title, String value, Color valueColor) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(color: kSlate100),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(title, style: const TextStyle(
//               color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12)),
//           const SizedBox(height: 12),
//           Text(value, style: GoogleFonts.inter(
//               fontSize: 18, fontWeight: FontWeight.w900, color: valueColor)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTierCard(double impactScore) {
//     String tierName = "BRONZE";
//     String tierTitle = "Rising Supporter";
//     String tierDesc = "Your journey of making an impact begins here.";
//     Color badgeColor = const Color(0xFFFBBF24);
//     Color bgColor = const Color(0xFF78350F);
//
//     if (impactScore >= 5000) {
//       tierName = "PLATINUM";
//       tierTitle = "National Hero";
//       tierDesc = "You are in the top 1% of supporters this year.";
//       badgeColor = const Color(0xFF22D3EE);
//       bgColor = const Color(0xFF164E63);
//     } else if (impactScore >= 1000) {
//       tierName = "GOLD";
//       tierTitle = "Community Pillar";
//       tierDesc = "You are in the top 10% of Malaysian supporters.";
//       badgeColor = const Color(0xFF34D399);
//       bgColor = const Color(0xFF064E3B);
//     } else if (impactScore >= 200) {
//       tierName = "SILVER";
//       tierTitle = "Generous Giver";
//       tierDesc = "A consistent beacon of hope for communities.";
//       badgeColor = const Color(0xFF94A3B8);
//       bgColor = const Color(0xFF1E293B);
//     }
//
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text("PHILANTHROPY TIER", style: TextStyle(color: badgeColor,
//                   fontSize: 10,
//                   fontWeight: FontWeight.w900,
//                   letterSpacing: 1.1)),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 10, vertical: 4),
//                 decoration: BoxDecoration(
//                     color: badgeColor, borderRadius: BorderRadius.circular(8)),
//                 child: Text(tierName, style: TextStyle(
//                     color: bgColor, fontSize: 10, fontWeight: FontWeight.w900)),
//               )
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(tierTitle, style: GoogleFonts.inter(
//               color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
//           Text(tierDesc,
//               style: const TextStyle(color: Colors.white70, fontSize: 12)),
//         ],
//       ),
//     );
//   }
//
// // UPDATED: Added category parameter to the builder
//   DataRow _buildDataRow(Map<String, dynamic> data, String fetchedCategory) {
//     bool isMoney = data['type'] == 'money';
//
//     // 1. Format Date
//     String dateStr = "N/A";
//     if (data['timestamp'] != null) {
//       DateTime d = (data['timestamp'] as Timestamp).toDate();
//       dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
//     }
//
//     // 2. Dynamic Cause String
//     String location = data['target'] ?? "General Location";
//     String dynamicCause = "$location, $fetchedCategory";
//
//     // 3. Impact Text (Formatted to 2 decimals for RM)
//     String impactText = isMoney
//         ? "RM ${(data['amount'] as num? ?? 0.0).toStringAsFixed(2)}"
//         : "${data['quantity'] ?? '1'}x ${data['itemName'] ?? 'Item'}";
//
//     return DataRow(cells: [
//       DataCell(Text(dateStr)),
//       DataCell(
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//           decoration: BoxDecoration(
//             color: (isMoney ? kEmerald : kBlueBrand).withOpacity(0.1),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Text(
//             isMoney ? "MONEY" : "ITEM",
//             style: TextStyle(color: isMoney ? kEmerald : kBlueBrand, fontSize: 10, fontWeight: FontWeight.w900),
//           ),
//         ),
//       ),
//       DataCell(Text(dynamicCause, style: const TextStyle(fontWeight: FontWeight.w600))),
//       DataCell(Text(data['ngo'] ?? "MERCY Malaysia", style: const TextStyle(color: kSlate500))),
//       DataCell(Text(impactText, style: const TextStyle(fontWeight: FontWeight.bold))),
//
//       // 4. FIXED ACTION COLUMN: Matching the Screenshot UI
//       DataCell(
//         ElevatedButton.icon(
//           onPressed: () {
//             // Add your download/view logic here
//             print("Downloading certificate for: ${data['id']}");
//           },
//           icon: const Icon(LucideIcons.download, size: 14, color: kSlate600),
//           label: const Text(
//             "Certificate",
//             style: TextStyle(color: kSlate800, fontSize: 12, fontWeight: FontWeight.w600),
//           ),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: kSlate50, // Light grey background
//             elevation: 0,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//               side: const BorderSide(color: kSlate100), // Subtle border
//             ),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           ),
//         ),
//       ),
//     ]);
//   }
// }

// ==========================================
// 6. MY IMPACT PAGE (DYNAMIC WITH FIRESTORE IMPACT SCORE)
// ==========================================
class MyImpactPage extends StatelessWidget {
  const MyImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('relief_cache').doc('current_status').snapshots(),
        builder: (context, cacheSnapshot) {
          // Initialize results list from cache
          List<dynamic> activeResults = [];
          if (cacheSnapshot.hasData && cacheSnapshot.data!.exists) {
            var cacheData = cacheSnapshot.data!.data() as Map<String, dynamic>;
            activeResults = cacheData['results'] as List<dynamic>? ?? [];
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: kEmerald));
              }

              var userData = userSnapshot.data?.data() as Map<String, dynamic>?;
              double impactScore = (userData?['impactValue'] as num? ?? 0.0).toDouble();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('donations')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: kEmerald));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  double totalCash = 0;
                  int totalItems = 0;

                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['type'] == 'money') {
                      totalCash += (data['amount'] as num? ?? 0.0).toDouble();
                    } else if (data['type'] == 'item') {
                      totalItems += (data['quantity'] as num? ?? 1).toInt();
                    }
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("My Charitable Journey",
                            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: kSlate800)),
                        const SizedBox(height: 32),
                        _buildTierCard(impactScore),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                                child: _buildStatCard(
                                    "Cash Support",
                                    "RM ${NumberFormat.compact().format(totalCash)}", // <--- COMPACT FORMAT ADDED HERE
                                    kEmerald
                                )
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildStatCard(
                                    "Physical Items",
                                    NumberFormat.compact().format(totalItems), // <--- COMPACT FORMAT ADDED HERE
                                    kBlueBrand
                                )
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: kSlate100),
                          ),
                          child: Column(
                            children: [
                              if (docs.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(child: Text("No contributions found yet.")),
                                )
                              else
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text("DATE")),
                                      DataColumn(label: Text("TYPE")),
                                      DataColumn(label: Text("CAUSE")),
                                      DataColumn(label: Text("NGO")),
                                      DataColumn(label: Text("IMPACT")),
                                      DataColumn(label: Text("ACTION")),
                                    ],
                                    // rows: docs.map((doc) {
                                    //   final donationData = doc.data() as Map<String, dynamic>;
                                    //   final String donationTarget = donationData['target'] ?? "";
                                    //
                                    //   // 1. FIRST check if the category is permanently saved in this specific donation record
                                    //   String matchedCategory = donationData['category']?.toString() ?? "";
                                    //
                                    //   // 2. If it's an old donation and missing the category, fallback to the live cache
                                    //   if (matchedCategory.isEmpty || matchedCategory == "null") {
                                    //     var foundRelief = activeResults.firstWhere(
                                    //           (res) => res['location'] == donationTarget,
                                    //       orElse: () => null,
                                    //     );
                                    //
                                    //     matchedCategory = foundRelief != null
                                    //         ? foundRelief['category'].toString()
                                    //         : "Relief Aid";
                                    //   }
                                    //
                                    //   // Ensure 'context' is the FIRST argument
                                    //   return _buildDataRow(context, donationData, matchedCategory);
                                    // }).toList(),
                                    rows: docs.map((doc) {
                                      final donationData = doc.data() as Map<String, dynamic>;

                                      // 1. FETCH EXACT CATEGORY FROM THE DONATION RECORD
                                      String matchedCategory = donationData['category']?.toString() ?? "";

                                      // 2. SMART FALLBACK FOR OLD DATA (Before the category field was added)
                                      if (matchedCategory.isEmpty || matchedCategory == "null") {
                                        String itemName = (donationData['itemName'] ?? "").toString().toLowerCase();

                                        if (itemName.contains("cloth") || itemName.contains("shirt") || itemName.contains("pants")) {
                                          matchedCategory = "Clothing";
                                        } else if (itemName.contains("food") || itemName.contains("rice") || itemName.contains("water") || itemName.contains("meal")) {
                                          matchedCategory = "Food Security";
                                        } else if (itemName.contains("med") || itemName.contains("kit") || itemName.contains("cream")) {
                                          matchedCategory = "Medical Aid";
                                        } else if (itemName.contains("book") || itemName.contains("edu")) {
                                          matchedCategory = "Education";
                                        } else {
                                          matchedCategory = "Relief Aid"; // Final default
                                        }
                                      }

                                      return _buildDataRow(context, donationData, matchedCategory);
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          );
        }
    );
  }

  // --- Helper Widgets ---

  Widget _buildStatCard(String title, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSlate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: kSlate500, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildTierCard(double impactScore) {
    String tierName = "BRONZE";
    String tierTitle = "Rising Supporter";
    String tierDesc = "Your journey of making an impact begins here.";
    Color badgeColor = const Color(0xFFFBBF24);
    Color bgColor = const Color(0xFF78350F);

    if (impactScore >= 5000) {
      tierName = "PLATINUM";
      tierTitle = "National Hero";
      tierDesc = "You are in the top 1% of supporters this year.";
      badgeColor = const Color(0xFF22D3EE);
      bgColor = const Color(0xFF164E63);
    } else if (impactScore >= 1000) {
      tierName = "GOLD";
      tierTitle = "Community Pillar";
      tierDesc = "You are in the top 10% of Malaysian supporters.";
      badgeColor = const Color(0xFF34D399);
      bgColor = const Color(0xFF064E3B);
    } else if (impactScore >= 200) {
      tierName = "SILVER";
      tierTitle = "Generous Giver";
      tierDesc = "A consistent beacon of hope for communities.";
      badgeColor = const Color(0xFF94A3B8);
      bgColor = const Color(0xFF1E293B);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("PHILANTHROPY TIER", style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
                child: Text(tierName, style: TextStyle(color: bgColor, fontSize: 10, fontWeight: FontWeight.w900)),
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(tierTitle, style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(tierDesc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  DataRow _buildDataRow(BuildContext context, Map<String, dynamic> data, String fetchedCategory) {
    bool isMoney = data['type'] == 'money';

    String dateStr = "N/A";
    if (data['timestamp'] != null) {
      DateTime d = (data['timestamp'] as Timestamp).toDate();
      dateStr = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }

    String location = data['target'] ?? "General Location";
    String dynamicCause = "$location, $fetchedCategory";

    String impactText = isMoney
        ? "RM ${(data['amount'] as num? ?? 0.0).toStringAsFixed(2)}"
        : "${data['quantity'] ?? '1'}x ${data['itemName'] ?? 'Item'}";

    return DataRow(cells: [
      DataCell(Text(dateStr)),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isMoney ? kEmerald : kBlueBrand).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isMoney ? "MONEY" : "ITEM",
            style: TextStyle(color: isMoney ? kEmerald : kBlueBrand, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ),
      // TO THIS:
      DataCell(
        SizedBox(
          width: 140, // Forces the text to wrap instead of stretching horizontally
          child: Text(
            dynamicCause,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      DataCell(
        SizedBox(
          width: 100, // Keeps the NGO name compact
          child: Text(
            data['ngo'] ?? "MERCY Malaysia",
            style: const TextStyle(color: kSlate500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      DataCell(Text(impactText, style: const TextStyle(fontWeight: FontWeight.bold))),
      DataCell(
        ElevatedButton.icon(
          onPressed: () => _downloadCertificate(context, data, dynamicCause, impactText, dateStr),
          icon: const Icon(LucideIcons.download, size: 14, color: kSlate600),
          label: const Text("Certificate", style: TextStyle(color: kSlate800, fontSize: 12, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kSlate50,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: kSlate100)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    ]);
  }

  // Import this at the top: import 'package:share_plus/share_plus.dart';

  Future<void> _downloadCertificate(BuildContext context, Map<String, dynamic> data, String cause, String impact, String date) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text("KitaCare AI", style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text("CERTIFICATE OF DONATION", style: pw.TextStyle(fontSize: 24)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text("Presented to a KitaCare Donor"),
              pw.SizedBox(height: 10),
              pw.Text("Cause: $cause"),
              pw.Text("Impact: $impact"),
              pw.Text("Date: $date"),
              pw.SizedBox(height: 40),
              pw.Text("Thank you for your kindness!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Get a safe directory for storing the file
      final directory = await getApplicationDocumentsDirectory(); //
      final filePath = "${directory.path}/KitaCare_Certificate_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(filePath);

      // 2. Save the PDF bytes
      await file.writeAsBytes(await pdf.save());

      // 3. Open the file using open_filex (it handles the content:// URI internally)
      final result = await OpenFilex.open(filePath); //

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open file: ${result.message}"))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
      );
    }
  }
}
