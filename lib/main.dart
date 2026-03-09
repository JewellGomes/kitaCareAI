import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'firebase_options.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart'; // Use open_filex
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

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

// ============================================================
// KITACARE AI — Flutter App Entry Point
// ============================================================

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

  // --- BULLETPROOF AUTH LOGIC ---
  // --- BULLETPROOF AUTH LOGIC (ANDROID EMULATOR FIX) ---
  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (view == 'signup') {
        UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        String userName = _nameController.text.trim();
        if (userName.isEmpty) userName = "New User";

        await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
          'name': userName,
          'email': _emailController.text.trim(),
          'role': selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'walletBalance': 0.0,
          'impactValue': 0.0,
          'livesTouched': 0,
        });

        _navigateToApp(userName);

      } else {
        UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        // ==========================================
        // EMULATOR FIX: Force Server Fetch & Timeout
        // ==========================================
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .get(const GetOptions(source: Source.server)) // Forces it to bypass broken Android cache
            .timeout(const Duration(seconds: 10), onTimeout: () {
          throw "Database connection timed out. Check emulator internet.";
        });

        if (doc.exists) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

          if (data == null || !data.containsKey('role')) {
            String autoName = selectedRole == 'ngo' ? "Official NGO" : "New User";
            await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
              'name': autoName,
              'email': _emailController.text.trim(),
              'role': selectedRole,
              'createdAt': FieldValue.serverTimestamp(),
              'walletBalance': 0.0,
              'impactValue': 0.0,
              'livesTouched': 0,
            });
            _navigateToApp(autoName);
            return;
          }

          String dbRole = data['role'];

          if (dbRole != selectedRole) {
            await FirebaseAuth.instance.signOut();
            _showError("Access Denied: This account is registered as a ${dbRole.toUpperCase()}.");
            return;
          }

          _navigateToApp(data['name'] ?? "User");
        } else {
          String autoName = selectedRole == 'ngo' ? "Official NGO" : "New User";
          await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
            'name': autoName,
            'email': _emailController.text.trim(),
            'role': selectedRole,
            'createdAt': FieldValue.serverTimestamp(),
            'walletBalance': 0.0,
            'impactValue': 0.0,
            'livesTouched': 0,
          });
          _navigateToApp(autoName);
        }
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Authentication failed.");
    } catch (e) {
      _showError("Error: $e");
      print("CRITICAL ERROR: $e");
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
        ReliefMap(userRole: widget.role),     // NGO's 2nd Tab: Relief Map
        const AiAdvisorPage(role: 'ngo'), // NGO's 3rd Tab: NGO AI
        const LogisticsDashboard(),  // NGO's 4th Tab: Logistics Data
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
          userRole: widget.role,
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
class CourierDashboard extends StatefulWidget {
  const CourierDashboard({super.key});

  @override
  State<CourierDashboard> createState() => _CourierDashboardState();
}

class _CourierDashboardState extends State<CourierDashboard> {
  final TextEditingController _qrController = TextEditingController();
  bool _isProcessing = false;

  // --- ADDED closeDialog FLAG TO PREVENT BLACK SCREEN ---
  Future<void> _processScan({bool closeDialog = true}) async {
    String qrData = _qrController.text.trim();
    if (qrData.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      var query = await FirebaseFirestore.instance
          .collectionGroup('donations')
          .where('qrCodeData', isEqualTo: qrData)
          .get();

      if (query.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid QR Code. Package not found in system."))
          );
        }
        setState(() => _isProcessing = false);
        return;
      }

      var doc = query.docs.first;
      var data = doc.data();

      // ========================================================
      // NEW RESTRICTION: PREVENT SCANNING SELF DROP-OFF PACKAGES
      // ========================================================
      // If the field doesn't exist, or it isn't "driver", it's a self drop-off.
      bool isCourierDelivery = data.containsKey('deliveryMethod') && data['deliveryMethod'] == 'driver';

      if (!isCourierDelivery) {
        setState(() => _isProcessing = false);
        _qrController.clear();

        if (mounted) {
          if (closeDialog) Navigator.pop(context); // Close dialog if manual entry
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Scan Denied: This package is for Self Drop-off, not Courier Pick-up."),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
      // ========================================================

      List<dynamic> milestones = data['milestones'] ?? [];
      bool isPickedUp = milestones.length > 1 && milestones[1]['done'] == true;
      bool isArrivedAtHub = milestones.length > 2 && milestones[2]['done'] == true;

      if (isPickedUp && isArrivedAtHub) {
        setState(() => _isProcessing = false);
        _qrController.clear();

        if (mounted) {
          if (closeDialog) Navigator.pop(context); // Close only if instructed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Action Denied: This package has already been delivered to the NGO Hub!"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }

      setState(() => _isProcessing = false);
      _qrController.clear();

      if (mounted && closeDialog) {
        Navigator.pop(context); // Close scan dialog only if instructed
      }

      // Open Action Dialog
      _showPackageActionDialog(doc.reference, data);

    } catch (e) {
      debugPrint("Scan Error: $e");
      setState(() => _isProcessing = false);
    }
  }

  void _openCameraScanner() async {
    // 1. Close the manual entry dialog first
    Navigator.pop(context);

    // 2. Open the full-screen camera
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    // 3. Process automatically, but tell it NOT to pop the dialog again!
    if (scannedCode != null && scannedCode is String) {
      _qrController.text = scannedCode;
      _processScan(closeDialog: false); // <--- CRITICAL FIX HERE
    }
  }

  void _showScanDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
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
                    onPressed: _isProcessing ? null : () => _processScan(closeDialog: true), // <--- CRITICAL FIX HERE
                    child: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("Find via ID", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPackageActionDialog(DocumentReference docRef, Map<String, dynamic> data) {
    List<dynamic> milestones = List.from(data['milestones'] ?? []);

    // FIX 1: Correct the Milestone Indexes for Courier!
    // Index 1 = Picked Up & In Transit
    // Index 2 = Arrived at NGO Hub (This is the Courier's Drop-off)
    bool isPickedUp = milestones.length > 1 && milestones[1]['done'] == true;
    bool isArrivedAtHub = milestones.length > 2 && milestones[2]['done'] == true;

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
                  child: SingleChildScrollView(
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

                          if (isArrivedAtHub) ...[
                            // STATE 3: ALREADY DROPPED OFF
                            const Icon(LucideIcons.checkCircle, color: kEmerald, size: 48),
                            const SizedBox(height: 12),
                            const Text("Delivery Completed", style: TextStyle(color: kEmerald, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close")))
                          ]
                          else if (!isPickedUp) ...[
                            // STATE 1: NEEDS PICK-UP FIRST
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
                                  final nav = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(context);

                                  if (milestones.length > 1) {
                                    milestones[1]['done'] = true;
                                    milestones[1]['date'] = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
                                  }

                                  await docRef.update({
                                    'milestones': milestones,
                                    'status': 'Picked Up & In Transit'
                                  });

                                  nav.pop();
                                  messenger.showSnackBar(const SnackBar(
                                    content: Text("Package Picked Up! Donor notified."),
                                    backgroundColor: kEmerald,
                                  ));
                                },
                              ),
                            )
                          ]
                          else ...[
                              // STATE 2: PICKED UP, NOW NEEDS DROP-OFF
                              const Text("Action Required: Drop-off at NGO Hub", style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),

                              // Optional Camera Button
                              GestureDetector(
                                onTap: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
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
                                      ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(capturedImage!.path), fit: BoxFit.cover, width: double.infinity))
                                      : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.camera, color: Colors.orange.shade700, size: 32),
                                      const SizedBox(height: 8),
                                      const Text("Tap to take proof photo (Optional)", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Dynamic Drop-off Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  icon: Icon(capturedImage == null ? LucideIcons.skipForward : LucideIcons.checkSquare),
                                  label: Text(capturedImage == null ? "Drop-off Without Photo" : "Confirm Drop-Off"),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: capturedImage == null ? kSlate400 : kEmerald,
                                      foregroundColor: Colors.white
                                  ),
                                  onPressed: () async {
                                    final nav = Navigator.of(context);
                                    final messenger = ScaffoldMessenger.of(context);

                                    final String courierUid = FirebaseAuth.instance.currentUser?.uid ?? "";

                                    // FIX 2: Update Index 2 (Arrived at NGO Hub)
                                    if (milestones.length > 2) {
                                      milestones[2]['done'] = true;
                                      milestones[2]['date'] = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
                                    }

                                    // FIX 3: Status is 'Arrived at NGO Hub', NOT 'Drop-off Verified'
                                    Map<String, dynamic> updateData = {
                                      'milestones': milestones,
                                      'status': 'Arrived at NGO Hub',
                                      'courierId': courierUid,
                                    };

                                    if (capturedImage != null) {
                                      updateData['proofOfDeliveryUrl'] = "https://images.unsplash.com/photo-1577705998148-6da4f3963bc8?w=400";
                                    }

                                    await docRef.update(updateData);

                                    nav.pop();
                                    messenger.showSnackBar(SnackBar(
                                      content: Text(capturedImage == null
                                          ? "Dropped off without photo proof."
                                          : "Drop-off Verified! Photo uploaded."),
                                      backgroundColor: capturedImage == null ? Colors.orange : kEmerald,
                                    ));
                                  },
                                ),
                              )
                            ],

                          if (!isArrivedAtHub)
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey)))
                        ],
                      ),
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
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Mission Operational Data", style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: kSlate800)),
              const Text("Courier Access Terminal", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),

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
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collectionGroup('donations')
                          .where('status', isEqualTo: 'Arrived at NGO Hub')
                          .where('courierId', isEqualTo: currentUid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String deliveredCount = "...";
                        if (snapshot.hasData) {
                          deliveredCount = snapshot.data!.docs.length.toString();
                        } else if (snapshot.hasError) {
                          deliveredCount = "0";
                        }
                        return _statBox("DELIVERED", deliveredCount, kEmerald);
                      },
                    ),
                  ),
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

class NGOOperationalDashboard extends StatefulWidget {
  const NGOOperationalDashboard({super.key});

  @override
  State<NGOOperationalDashboard> createState() => _NGOOperationalDashboardState();
}

class _NGOOperationalDashboardState extends State<NGOOperationalDashboard> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int _selectedTab = 0; // 0: Operational Areas, 1: Physical Goods Requests

  // State variables for backend logic
  bool _isAnalyzing = false;
  String _aiStrategy = "Fetching internal logistics advisor...";

  @override
  void initState() {
    super.initState();
    _generateMissionStrategy();
    ensureReliefDataIsSynced();
  }

  // ==========================================
  // BACKEND: AI OPS STRATEGY (Operational Prompt)
  // ==========================================
  Future<void> _generateMissionStrategy() async {
    setState(() => _isAnalyzing = true);
    try {
      final resNews = await http.get(
          Uri.parse('https://www.bharian.com.my/berita/nasional.xml'));
      String news = "General Malaysia news";
      if (resNews.statusCode == 200) {
        news = XmlDocument
            .parse(resNews.body)
            .findAllElements('title')
            .take(5)
            .map((e) => e.innerText)
            .join(". ");
      }

      final apiKey = dotenv.env['GEMINI_KEY'];
      final model = GenerativeModel(
          model: 'gemini-flash-latest', apiKey: apiKey!);

      final prompt = """
      CONTEXT: $news
      TASK: You are an internal NGO Logistics Consultant. 
      Suggest how to verify drop-offs and manage disbursement logs in Malaysia based on these news trends.
      Limit to 2 sentences. Professional tone.
      """;

      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        _aiStrategy = response.text ?? "Focus on verified high-urgency zones.";
      });
    } catch (e) {
      _aiStrategy = "Maintain standby readiness for internal logistics.";
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

    @override
    Widget build(BuildContext context) {
      return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('users').doc(user?.uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(
                child: CircularProgressIndicator(color: kBlue));

            var ngoData = snapshot.data!.data() as Map<String, dynamic>? ?? {};

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NGO Header (Matches top of Image 1)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: kBlue, borderRadius: BorderRadius.circular(
                              12)),
                          child: const Icon(
                              LucideIcons.building2, color: Colors.white,
                              size: 24),
                        ),
                        const SizedBox(width: 16),

                        // 1. Wrap the middle section in Expanded to prevent overflow
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 2. Wrap the Name and Badge so they stack neatly if the screen is too narrow
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                      "MERCY Malaysia" ?? "NGO Portal",
                                      style: GoogleFonts.inter(fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: kSlate800)
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: kBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                            12)),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.checkCircle2,
                                            color: kBlue, size: 10),
                                        SizedBox(width: 4),
                                        Text("Official Partner",
                                            style: TextStyle(color: kBlue,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                  "PPM-001-10-XXXX • Relief Operational Hub",
                                  style: TextStyle(
                                      color: kSlate500, fontSize: 12)),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 3. Responsive Button: Shows only icon on small phones, full text on tablets/web
                        ElevatedButton(
                          onPressed: () => _showNewFieldReportDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery
                                    .of(context)
                                    .size
                                    .width > 450 ? 16 : 12,
                                vertical: 12
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.fileText, size: 16),
                              // Conditionally hide text if screen is narrow (mobile)
                              if (MediaQuery
                                  .of(context)
                                  .size
                                  .width > 450) ...[
                                const SizedBox(width: 8),
                                const Text("New Field Report", style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 1. CUSTOM TAB BAR
                    _buildCustomTabBar(),
                    const SizedBox(height: 24),

                    if (_selectedTab == 0) ...[
                      // --- TAB 1: OPERATIONAL AREAS ---
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          SizedBox(
                            width: MediaQuery
                                .of(context)
                                .size
                                .width > 800 ? MediaQuery
                                .of(context)
                                .size
                                .width * 0.55 : double.infinity,
                            child: _buildDisasterZonesCard(),
                          ),
                          SizedBox(
                            width: MediaQuery
                                .of(context)
                                .size
                                .width > 800 ? MediaQuery
                                .of(context)
                                .size
                                .width * 0.35 : double.infinity,
                            child: Column(
                              children: [
                                _buildFundsSummaryCard(context, ngoData),
                                const SizedBox(height: 24),
                                _buildVerifyReceiptCard(),
                                const SizedBox(height: 24),
                                // <-- Gap before new card
                                _buildVerifyFundsCard(),
                                // <-- NEW MONEY CARD HERE
                              ],
                            ),
                          )
                        ],
                      ),
                    ] else
                      ...[
                        // --- TAB 2: PHYSICAL GOODS REQUESTS ---
                        Wrap(
                          spacing: 24,
                          runSpacing: 24,
                          children: [
                            SizedBox(
                              width: MediaQuery
                                  .of(context)
                                  .size
                                  .width > 800 ? MediaQuery
                                  .of(context)
                                  .size
                                  .width * 0.55 : double.infinity,
                              child: _buildInventoryNeededCard(),
                            ),
                            SizedBox(
                              width: MediaQuery
                                  .of(context)
                                  .size
                                  .width > 800 ? MediaQuery
                                  .of(context)
                                  .size
                                  .width * 0.35 : double.infinity,
                              child: Column(
                                children: [
                                  _buildFundsSummaryCard(context, ngoData),
                                  const SizedBox(height: 24),
                                  _buildVerifyReceiptCard(),
                                  const SizedBox(height: 24),
                                  // <-- Gap before new card
                                  _buildVerifyFundsCard(),
                                  // <-- NEW MONEY CARD HERE
                                ],
                              ),
                            )
                          ],
                        ),
                      ]
                  ],
                ),
              ),
            );
          }
      );
    }

    // --- DIALOG: REQUEST PHYSICAL GOODS (Matches Image 3) ---
    // --- DIALOG: REQUEST PHYSICAL GOODS (Matches Image 2 + Location Dropdown) ---
    // --- DIALOG: REQUEST PHYSICAL GOODS (Fixed Firebase Deep Update) ---
    void _showRequestPhysicalGoodsDialog() {
      final TextEditingController itemCtrl = TextEditingController();
      final TextEditingController qtyCtrl = TextEditingController();

      String? selectedLocation;
      String selectedCategory = "Education"; // Default category
      String selectedUrgency = "High";

      String? errorMessage;
      bool isSaving = false;

      // Fetch active locations from relief_cache ONE TIME before the dialog builds
      Future<List<String>> fetchActiveLocations() async {
        try {
          final doc = await FirebaseFirestore.instance.collection(
              'relief_cache').doc('current_status').get();
          if (!doc.exists) return [];
          final data = doc.data()!;
          final results = data['results'] as List<dynamic>? ?? [];

          // Extract unique location names
          return results.map((e) => e['location'].toString()).toSet().toList();
        } catch (e) {
          return [];
        }
      }

      final Future<List<String>> locationsFuture = fetchActiveLocations();

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
                builder: (context, setState) {
                  return Dialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      width: 450, // Limits width on desktop
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Blue Header
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: kBlue,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // FIX: Wrapped in Expanded to prevent long text from pushing the 'X' off screen
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Request Physical Goods",
                                          style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                      const Text("POST TO DONOR MAP",
                                          style: TextStyle(color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (!isSaving) Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                      LucideIcons.x, color: Colors.white,
                                      size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),

                          // Form Body
                          // FIX: Added Flexible and SingleChildScrollView so it scrolls when the keyboard pops up!
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // --- TARGET LOCATION DROPDOWN ---
                                  _buildFormLabel(
                                      "TARGET LOCATION (ACTIVE ZONES)"),
                                  FutureBuilder<List<String>>(
                                      future: locationsFuture,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: kSlate200),
                                                borderRadius: BorderRadius
                                                    .circular(12)),
                                            child: const Row(
                                              children: [
                                                SizedBox(width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2)),
                                                SizedBox(width: 12),
                                                Text("Loading active zones...",
                                                    style: TextStyle(
                                                        color: kSlate500,
                                                        fontSize: 14))
                                              ],
                                            ),
                                          );
                                        }

                                        List<String> locations = snapshot.data ??
                                            [];

                                        if (locations.isEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius
                                                    .circular(12)),
                                            child: const Text(
                                                "No active zones found. Please publish a Field Report first.",
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold)),
                                          );
                                        }

                                        if (selectedLocation == null ||
                                            !locations.contains(
                                                selectedLocation)) {
                                          selectedLocation = locations.first;
                                        }

                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: kSlate200),
                                              borderRadius: BorderRadius.circular(
                                                  12),
                                              color: const Color(0xFFF8FAFC)
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedLocation,
                                              isExpanded: true,
                                              icon: const Icon(
                                                  LucideIcons.chevronDown,
                                                  size: 16),
                                              items: locations.map((loc) =>
                                                  DropdownMenuItem(
                                                      value: loc,
                                                      child: Text(loc,
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight
                                                                  .bold))
                                                  )).toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  selectedLocation = val!;
                                                  errorMessage = null;
                                                });
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                  ),
                                  const SizedBox(height: 16),

                                  _buildFormLabel("CATEGORY"),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                        border: Border.all(color: kSlate200),
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(0xFFF8FAFC)
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedCategory,
                                        isExpanded: true,
                                        icon: const Icon(
                                            LucideIcons.chevronDown, size: 16),
                                        items: [
                                          "Education",
                                          "Food Security",
                                          "Medical Aid",
                                          "Clothing",
                                          "Disaster Relief"
                                        ]
                                            .map((c) =>
                                            DropdownMenuItem(value: c,
                                                child: Text(c,
                                                    style: const TextStyle(
                                                        fontSize: 14)))).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedCategory = val!;
                                            errorMessage = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  _buildFormLabel("SPECIFIC ITEM"),
                                  TextField(
                                    controller: itemCtrl,
                                    onChanged: (_) =>
                                        setState(() => errorMessage = null),
                                    decoration: InputDecoration(
                                      hintText: "e.g. Sejarah Books, Blankets...",
                                      hintStyle: const TextStyle(
                                          color: kSlate400, fontSize: 14),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: kSlate200)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: kSlate200)),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start,
                                          children: [
                                            _buildFormLabel("URGENCY"),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 2),
                                              decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: kSlate200),
                                                  borderRadius: BorderRadius
                                                      .circular(12),
                                                  color: const Color(0xFFF8FAFC)),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedUrgency,
                                                  isExpanded: true,
                                                  icon: const Icon(
                                                      LucideIcons.chevronDown,
                                                      size: 16),
                                                  items: [
                                                    "Medium",
                                                    "High",
                                                    "Critical"
                                                  ]
                                                      .map((c) =>
                                                      DropdownMenuItem(value: c,
                                                          child: Text(c,
                                                              style: const TextStyle(
                                                                  fontSize: 14))))
                                                      .toList(),
                                                  onChanged: (val) =>
                                                      setState(() =>
                                                      selectedUrgency = val!),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // --- INLINE ERROR MESSAGE ---
                                  if (errorMessage != null)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.red.shade200)
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.alertCircle,
                                              color: Colors.red, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(errorMessage!,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ),
                                  // ----------------------------

                                  // Submit Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: kBlue,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                  12)),
                                          elevation: 0
                                      ),
                                      onPressed: isSaving ? null : () async {
                                        // 1. Validation
                                        if (selectedLocation == null) {
                                          setState(() =>
                                          errorMessage =
                                          "Please select a target location.");
                                          return;
                                        }
                                        if (itemCtrl.text
                                            .trim()
                                            .isEmpty) {
                                          setState(() =>
                                          errorMessage =
                                          "Please fill in the item name.");
                                          return;
                                        }

                                        setState(() {
                                          isSaving = true;
                                          errorMessage = null;
                                        });

                                        try {
                                          // 1. Push to NGO's personal inventory list (For auditing)
                                          await FirebaseFirestore.instance
                                              .collection(
                                              'ngo_inventory_requests').add({
                                            'ngoId': FirebaseAuth.instance
                                                .currentUser?.uid,
                                            'location': selectedLocation,
                                            'category': selectedCategory,
                                            'item': itemCtrl.text.trim(),
                                            'quantity': int.tryParse(
                                                qtyCtrl.text.trim()) ?? 1,
                                            'urgency': selectedUrgency,
                                            'timestamp': FieldValue
                                                .serverTimestamp(),
                                          });

                                          // 2. PROPER DEEP COPY UPDATE TO FIRESTORE
                                          DocumentReference cacheRef = FirebaseFirestore
                                              .instance
                                              .collection('relief_cache')
                                              .doc('current_status');
                                          DocumentSnapshot cacheSnap = await cacheRef
                                              .get();

                                          if (cacheSnap.exists) {
                                            List<dynamic> results = List.from(
                                                cacheSnap['results'] ?? []);

                                            // Find the zone matching the location
                                            int zoneIndex = results.indexWhere((
                                                r) =>
                                            r['location'] == selectedLocation);

                                            if (zoneIndex != -1) {
                                              // Map UI Category to JSON short keys used by AI
                                              String catKey = 'rel';
                                              if (selectedCategory ==
                                                  'Food Security')
                                                catKey = 'food';
                                              if (selectedCategory ==
                                                  'Medical Aid') catKey = 'med';
                                              if (selectedCategory == 'Education')
                                                catKey = 'edu';
                                              if (selectedCategory == 'Clothing')
                                                catKey = 'cloth';

                                              // --- DEEP COPY OF THE SPECIFIC ZONE ---
                                              Map<String,
                                                  dynamic> targetZone = Map<
                                                  String,
                                                  dynamic>.from(
                                                  results[zoneIndex]);

                                              // --- UPDATE NEEDED_ITEMS MAP ---
                                              Map<String,
                                                  dynamic> neededItems = Map<
                                                  String,
                                                  dynamic>.from(
                                                  targetZone['needed_items'] ??
                                                      {});
                                              List<dynamic> itemsList = List.from(
                                                  neededItems[catKey] ?? []);

                                              // Remove the generic placeholder if it exists!
                                              itemsList.removeWhere((item) =>
                                              item.toString() == "Blanket");

                                              // Add the specific item (e.g. "sejarah books")
                                              itemsList.add(itemCtrl.text.trim());
                                              neededItems[catKey] = itemsList;
                                              targetZone['needed_items'] =
                                                  neededItems; // Put map back in zone

                                              // --- UPDATE SEVERITIES MAP ---
                                              Map<String,
                                                  dynamic> severities = Map<
                                                  String,
                                                  dynamic>.from(
                                                  targetZone['severities'] ?? {});
                                              severities[catKey] =
                                                  selectedUrgency;
                                              targetZone['severities'] =
                                                  severities; // Put map back in zone

                                              // Replace the old zone map with our updated zone map
                                              results[zoneIndex] = targetZone;

                                              // Save the fully updated array back to cache
                                              await cacheRef.update(
                                                  {'results': results});
                                            }
                                          }

                                          // Close Dialog & Show Success
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger
                                                .of(context)
                                                .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Item successfully requested & published to the map!"),
                                                backgroundColor: Colors.green
                                            ));
                                          }
                                        } catch (e) {
                                          setState(() {
                                            isSaving = false;
                                            errorMessage =
                                            "Error publishing request: $e";
                                          });
                                        }
                                      },
                                      child: isSaving
                                          ? const SizedBox(width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2))
                                          : const Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .center,
                                        children: [
                                          Text("Publish Item Request",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16)),
                                          SizedBox(width: 8),
                                          Icon(LucideIcons.arrowRight, size: 18)
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }
            );
          }
      );
    }

    Widget _buildFormLabel(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(text, style: const TextStyle(fontSize: 10,
            fontWeight: FontWeight.w900,
            color: kSlate400,
            letterSpacing: 0.5)),
      );
    }

// --- DIALOG: NEW FIELD REPORT (With Live Map Search & Category) ---
    // --- DIALOG: NEW FIELD REPORT (With Inline Error Handling) ---
    void _showNewFieldReportDialog() {
      TextEditingController? autocompleteController;
      final TextEditingController summaryCtrl = TextEditingController();
      String selectedUrgency = "High";
      String selectedCategory = "Flood Relief";
      bool isPublishing = false;

      Map<String, dynamic>? verifiedLocation;
      String? errorMessage; // <-- NEW: State to hold the error message inside the dialog

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
                builder: (context, setState) {
                  return Dialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      width: 450, // Constrain width for desktop
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Blue Header
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: kBlue,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(24)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("New Field Report",
                                        style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const Text("OPERATIONAL INTELLIGENCE",
                                        style: TextStyle(color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0)),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (!isPublishing) Navigator.pop(context);
                                  },
                                  icon: const Icon(
                                      LucideIcons.x, color: Colors.white,
                                      size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              ],
                            ),
                          ),

                          // Form Body
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                _buildFormLabel("ZONE / AREA NAME"),
                                // --- STRICT LIVE MAP SEARCH AUTOCOMPLETE ---
                                Autocomplete<Map<String, dynamic>>(
                                  optionsBuilder: (
                                      TextEditingValue textEditingValue) async {
                                    final List<Map<String,
                                        dynamic>> defaultLocations = [
                                      {
                                        "name": "Kuala Krai",
                                        "display_name": "Kuala Krai, Kelantan, Malaysia",
                                        "lat": "5.5310",
                                        "lon": "102.1966"
                                      },
                                      {
                                        "name": "Kota Bharu",
                                        "display_name": "Kota Bharu, Kelantan, Malaysia",
                                        "lat": "6.1254",
                                        "lon": "102.2381"
                                      },
                                      {
                                        "name": "Shah Alam",
                                        "display_name": "Shah Alam, Selangor, Malaysia",
                                        "lat": "3.0738",
                                        "lon": "101.5183"
                                      },
                                      {
                                        "name": "Klang",
                                        "display_name": "Klang, Selangor, Malaysia",
                                        "lat": "3.0449",
                                        "lon": "101.4456"
                                      },
                                      {
                                        "name": "Baling",
                                        "display_name": "Baling, Kedah, Malaysia",
                                        "lat": "5.6766",
                                        "lon": "100.9167"
                                      },
                                      {
                                        "name": "Johor Bahru",
                                        "display_name": "Johor Bahru, Johor, Malaysia",
                                        "lat": "1.4927",
                                        "lon": "103.7414"
                                      },
                                      {
                                        "name": "Kuantan",
                                        "display_name": "Kuantan, Pahang, Malaysia",
                                        "lat": "3.8077",
                                        "lon": "103.3260"
                                      },
                                      {
                                        "name": "Kuala Lumpur",
                                        "display_name": "Kuala Lumpur, Malaysia",
                                        "lat": "3.1390",
                                        "lon": "101.6869"
                                      },
                                    ];

                                    if (textEditingValue.text.length < 3) {
                                      if (textEditingValue.text.isEmpty)
                                        return defaultLocations;
                                      return defaultLocations.where((loc) =>
                                          loc['name']
                                              .toString()
                                              .toLowerCase()
                                              .contains(textEditingValue.text
                                              .toLowerCase())
                                      );
                                    }

                                    final url = Uri.parse(
                                        'https://nominatim.openstreetmap.org/search?q=${Uri
                                            .encodeComponent(textEditingValue
                                            .text)}&format=json&countrycodes=my&limit=5');
                                    try {
                                      final response = await http.get(url,
                                          headers: {
                                            'User-Agent': 'KitaCareApp'
                                          });
                                      if (response.statusCode == 200) {
                                        final List data = json.decode(
                                            response.body);
                                        return data.cast<
                                            Map<String, dynamic>>();
                                      }
                                    } catch (e) {
                                      debugPrint("Autocomplete API Error: $e");
                                    }
                                    return const Iterable<
                                        Map<String, dynamic>>.empty();
                                  },

                                  displayStringForOption: (option) =>
                                  option['name'] ?? option['display_name'] ??
                                      '',

                                  fieldViewBuilder: (context, controller,
                                      focusNode, onEditingComplete) {
                                    autocompleteController = controller;
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      onEditingComplete: onEditingComplete,
                                      onChanged: (val) {
                                        // Clear location verification AND clear any active error message
                                        if (verifiedLocation != null ||
                                            errorMessage != null) {
                                          setState(() {
                                            verifiedLocation = null;
                                            errorMessage = null;
                                          });
                                        }
                                      },
                                      decoration: InputDecoration(
                                        hintText: "Click to see suggestions or type a city...",
                                        hintStyle: const TextStyle(
                                            color: kSlate400, fontSize: 14),
                                        prefixIcon: Icon(
                                            verifiedLocation != null
                                                ? LucideIcons.checkCircle
                                                : LucideIcons.search,
                                            size: 16,
                                            color: verifiedLocation != null
                                                ? Colors.green
                                                : kSlate400
                                        ),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                                12),
                                            borderSide: const BorderSide(
                                                color: kSlate200)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                                12),
                                            borderSide: const BorderSide(
                                                color: kSlate200)),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                                12),
                                            borderSide: const BorderSide(
                                                color: kBlue, width: 2)),
                                      ),
                                    );
                                  },

                                  optionsViewBuilder: (context, onSelected,
                                      options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                12)),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              maxHeight: 250, maxWidth: 402),
                                          child: ListView.builder(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(
                                                  index);
                                              return ListTile(
                                                leading: const Icon(
                                                    LucideIcons.mapPin,
                                                    color: kBlue, size: 18),
                                                title: Text(
                                                    option['name'] ?? '',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight
                                                            .bold,
                                                        fontSize: 13)),
                                                subtitle: Text(
                                                    option['display_name'] ??
                                                        '', maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: kSlate500)),
                                                onTap: () {
                                                  onSelected(option);
                                                  // Marks safe and clears any errors
                                                  setState(() {
                                                    verifiedLocation = option;
                                                    errorMessage = null;
                                                  });
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),

                                _buildFormLabel("RELIEF CATEGORY"),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(color: kSlate200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCategory,
                                      isExpanded: true,
                                      icon: const Icon(
                                          LucideIcons.chevronDown, size: 16),
                                      items: [
                                        "Flood Relief",
                                        "Food Security",
                                        "Medical Aid"
                                      ]
                                          .map((c) =>
                                          DropdownMenuItem(value: c,
                                              child: Text(c,
                                                  style: const TextStyle(
                                                      fontSize: 14)))).toList(),
                                      onChanged: (val) =>
                                          setState(() =>
                                          selectedCategory = val!),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                _buildFormLabel("URGENCY SCORE"),
                                Container(
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: ["Medium", "High", "Critical"]
                                        .map((u) {
                                      bool isSelected = selectedUrgency == u;
                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () =>
                                              setState(() =>
                                              selectedUrgency = u),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isSelected ? kBlue : Colors
                                                  .transparent,
                                              borderRadius: BorderRadius
                                                  .circular(12),
                                              boxShadow: isSelected ? [
                                                const BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4)
                                              ] : [],
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(u, style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : kSlate500,
                                                fontWeight: isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 13
                                            )),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                _buildFormLabel("FIELD SUMMARY"),
                                TextField(
                                  controller: summaryCtrl,
                                  maxLines: 4,
                                  onChanged: (_) {
                                    if (errorMessage != null) setState(() =>
                                    errorMessage = null);
                                  }, // Clear error when typing
                                  decoration: InputDecoration(
                                    hintText: "Describe the current situation, rising water levels, number of families affected...",
                                    hintStyle: const TextStyle(
                                        color: kSlate400, fontSize: 14),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: kSlate200)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: kSlate200)),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // --- NEW: INLINE ERROR MESSAGE UI ---
                                if (errorMessage != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.red.shade200)
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.alertCircle,
                                            color: Colors.red, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(errorMessage!,
                                            style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold))),
                                      ],
                                    ),
                                  ),
                                // ------------------------------------

                                // Publish Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: kBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                12)),
                                        elevation: 0
                                    ),
                                    onPressed: isPublishing ? null : () async {
                                      // 1. Check text fields
                                      if ((autocompleteController?.text
                                          .isEmpty ?? true) || summaryCtrl.text
                                          .trim()
                                          .isEmpty) {
                                        setState(() =>
                                        errorMessage =
                                        "Please fill in all fields before publishing.");
                                        return;
                                      }

                                      // 2. Check if valid location from dropdown
                                      if (verifiedLocation == null) {
                                        setState(() =>
                                        errorMessage =
                                        "Invalid Location! Please select an exact area from the dropdown map search.");
                                        return;
                                      }

                                      setState(() {
                                        errorMessage = null; // Clear errors
                                        isPublishing = true;
                                      });

                                      try {
                                        double exactLat = double.parse(
                                            verifiedLocation!['lat']
                                                .toString());
                                        double exactLng = double.parse(
                                            verifiedLocation!['lon']
                                                .toString());
                                        String realLocationName = verifiedLocation!['name'] ??
                                            "Unknown Area";

                                        String catKey = 'rel';
                                        if (selectedCategory == 'Food Security')
                                          catKey = 'food';
                                        if (selectedCategory == 'Medical Aid')
                                          catKey = 'med';

                                        int score = selectedUrgency ==
                                            'Critical'
                                            ? 95
                                            : (selectedUrgency == 'High'
                                            ? 80
                                            : 60);

                                        // Format Data for Firebase
                                        // Update this block inside _showNewFieldReportDialog
                                        Map<String, dynamic> newZone = {
                                          "location": realLocationName,
                                          "category": selectedCategory,
                                          "description": "NGO REPORT: ${summaryCtrl
                                              .text.trim()}",
                                          "score": score,
                                          "lat": exactLat,
                                          "lng": exactLng,
                                          "severities": {
                                            catKey: selectedUrgency
                                          },
                                          "needed_items": {catKey: ["Blanket"]},
                                          "isManual": true,
                                          // <--- 1. ADD THIS FLAG
                                        };

                                        // Update Firebase
                                        await _db
                                            .collection('relief_cache')
                                            .doc('current_status')
                                            .update({
                                          'results': FieldValue.arrayUnion(
                                              [newZone])
                                        });

                                        if (context.mounted) {
                                          // Pop the dialog FIRST
                                          Navigator.pop(context);
                                          // Show Success Snackbar on the MAIN SCREEN (so it doesn't get hidden)
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Field report published! Location pinned accurately on the map."),
                                              backgroundColor: Colors.green
                                          ));
                                        }
                                      } catch (e) {
                                        setState(() {
                                          isPublishing = false;
                                          errorMessage =
                                          "Error publishing report: $e";
                                        });
                                      }
                                    },
                                    child: isPublishing
                                        ? const SizedBox(width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                        : const Row(
                                      mainAxisAlignment: MainAxisAlignment
                                          .center,
                                      children: [
                                        Text("Publish Official Report",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        SizedBox(width: 8),
                                        Icon(LucideIcons.arrowRight, size: 18)
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }
            );
          }
      );
    }

  Widget _buildCustomTabBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5))),
      // FIX: Added SingleChildScrollView so the tabs can be swiped horizontally
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _tabItem("Operational Areas", 0),
            const SizedBox(width: 32),
            _tabItem("Physical Goods Requests", 1),
          ],
        ),
      ),
    );
  }

    // --- INVENTORY NEEDED CARD (Dynamic from relief_cache) ---
  Widget _buildInventoryNeededCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX: Changed Row to Wrap so the button drops to the next line if the screen is too small
          Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text("Inventory Needed", style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kSlate800)),
                TextButton.icon(
                  onPressed: () => _showRequestPhysicalGoodsDialog(),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text("Request New Item", style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: kBlue,
                    backgroundColor: kBlue.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
            // --- DYNAMIC AI SUMMARIZATION FROM RELIEF CACHE ---
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('relief_cache').doc(
                  'current_status').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(color: kBlue)));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text(
                        "No items requested yet. Click 'Request New Item' to begin.",
                        style: TextStyle(color: kSlate400))),
                  );
                }

                // 1. Extract Data
                var data = snapshot.data!.data() as Map<String, dynamic>;
                List<dynamic> results = data['results'] ?? [];

                // 2. Map to hold deduplicated items and their highest urgency
                Map<String, String> aggregatedItems = {};

                // Helper to rank urgency for sorting (Critical = Highest)
                int severityWeight(String s) {
                  if (s.toLowerCase() == 'critical') return 3;
                  if (s.toLowerCase() == 'high') return 2;
                  if (s.toLowerCase() == 'medium') return 1;
                  return 0;
                }

                // 3. Loop through every active disaster zone
                for (var zone in results) {
                  Map<String, dynamic> neededItems = zone['needed_items'] ?? {};
                  Map<String, dynamic> severities = zone['severities'] ?? {};

                  // Loop through categories (cloth, edu, food, med, rel)
                  neededItems.forEach((catKey, itemsArray) {
                    String severity = severities[catKey]?.toString() ??
                        'Medium';

                    for (var itemRaw in (itemsArray as List<dynamic>)) {
                      String itemName = itemRaw.toString();
                      if (itemName == "Blanket") continue;

                      if (aggregatedItems.containsKey(itemName)) {
                        if (severityWeight(severity) > severityWeight(
                            aggregatedItems[itemName]!)) {
                          aggregatedItems[itemName] = severity;
                        }
                      } else {
                        aggregatedItems[itemName] = severity;
                      }
                    }
                  });
                }

                // 4. Sort the list so Critical/High items show up FIRST
                var sortedItems = aggregatedItems.entries.toList()
                  ..sort((a, b) =>
                      severityWeight(b.value).compareTo(
                          severityWeight(a.value)));

                if (sortedItems.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text(
                        "All zones currently stable. No physical inventory needed.",
                        style: TextStyle(color: kSlate400))),
                  );
                }

                // --- UPDATED LAYOUT: SCROLLABLE GRID ---
                // IN YOUR _buildInventoryNeededCard WIDGET:

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(24),
                    shrinkWrap: true,
                    itemCount: sortedItems.length,

                    // 👇 REPLACE THE GRID DELEGATE WITH THIS 👇
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      // The minimum width each pill needs to not crash
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 85,
                    ),
                    // 👆 ----------------------------------- 👆

                    itemBuilder: (context, index) {
                      return _buildInventoryItemPill(
                        sortedItems[index].key,
                        sortedItems[index].value,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // --- INVENTORY PILL UI ---
    Widget _buildInventoryItemPill(String itemName, String urgency) {
      bool isCritical = urgency.toLowerCase() == 'critical';
      bool isHigh = urgency.toLowerCase() == 'high';

      Color urgencyTextColor;
      Color urgencyBgColor;

      if (isCritical) {
        urgencyTextColor = const Color(0xFFEF4444); // Strong Red
        urgencyBgColor = const Color(0xFFFEF2F2); // Light Red BG
      } else if (isHigh) {
        urgencyTextColor = Colors.orange.shade800; // Strong Orange
        urgencyBgColor = Colors.orange.shade50; // Light Orange BG
      } else {
        urgencyTextColor = kBlue; // Blue
        urgencyBgColor = kBlue.withOpacity(0.1); // Light Blue BG
      }

      return Container(
        // Removed hardcoded `width` here so it properly expands to fit the GridView column
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        // Adjusted slightly to fit mainAxisExtent nicely
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.package, size: 20, color: kBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                itemName,
                style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: kSlate800), // Minor font size tweak for fitting
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: urgencyBgColor,
                  borderRadius: BorderRadius.circular(12)
              ),
              child: Text(
                  urgency.toUpperCase(),
                  style: TextStyle(color: urgencyTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)
              ),
            )
          ],
        ),
      );
    }

    Widget _tabItem(String title, int index) {
      bool isSelected = _selectedTab == index;
      return GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                    color: isSelected ? const Color(0xFF2563EB) : Colors
                        .transparent,
                    width: 3,
                  )
              )
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF2563EB) : const Color(
                  0xFF94A3B8),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    // 1. MANAGED DISASTER ZONES (Table Layout connected to Firebase)
    // 1. MANAGED DISASTER ZONES (Table Layout connected to Firebase)
    Widget _buildDisasterZonesCard() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text("Managed Disaster Zones", style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B))),
            ),

            // Table Columns
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(flex: 3,
                      child: Text("LOCATION", style: _tableHeaderStyle())),
                  Expanded(flex: 2,
                      child: Text("STATUS", style: _tableHeaderStyle())),
                  Expanded(flex: 2,
                      child: Text("URGENCY", style: _tableHeaderStyle())),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // --- NEW: Firebase Data Stream pointing to AI relief_cache ---
            StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('relief_cache')
                    .doc('current_status')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Padding(padding: EdgeInsets.all(32),
                        child: Center(child: Text(
                            "No active zones. / Tiada zon aktif.")));
                  }

                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  List<dynamic> results = data['results'] ?? [];

                  if (results.isEmpty) {
                    return const Padding(padding: EdgeInsets.all(32),
                        child: Center(child: Text(
                            "No active zones. / Tiada zon aktif.")));
                  }

                  return Column(
                    // Pass the entire zone map to the row builder to extract score/severities
                    children: results.map((zone) {
                      return _buildZoneRow(zone as Map<String, dynamic>);
                    }).toList(),
                  );
                }
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    TextStyle _tableHeaderStyle() =>
        const TextStyle(fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2);

    Widget _buildZoneRow(Map<String, dynamic> zone) {
      String location = zone['location'] ?? "Unknown Zone";

      // Extract the AI score (e.g., 95, 88, 82) to use for Urgency
      double score = (zone['score'] as num? ?? 50.0).toDouble();
      double urgencyValue = score /
          100.0; // Converts 95 to 0.95 for the progress bar

      // Extract Severities to determine the Status
      Map<String, dynamic> severities = zone['severities'] ?? {};
      bool hasCritical = severities.containsValue("Critical");
      bool hasHigh = severities.containsValue("High");

      // --- DYNAMIC STATUS LOGIC ---
      String statusText;
      Color statusColor;
      Color statusBg;

      if (hasCritical) {
        statusText = "Active Response";
        statusColor = Colors.redAccent.shade700;
        statusBg = Colors.red.shade50;
      } else if (hasHigh) {
        statusText = "Dispatching";
        statusColor = Colors.orange.shade700;
        statusBg = Colors.orange.shade50;
      } else {
        statusText = "Monitoring";
        statusColor = const Color(0xFF2563EB); // Blue
        statusBg = const Color(0xFFEFF6FF);
      }

      // --- DYNAMIC URGENCY LOGIC (Based on Score) ---
      String urgencyLabel;
      Color urgencyColor;

      if (score >= 90) {
        urgencyLabel = "Critical ($score)";
        urgencyColor = Colors.redAccent;
      } else if (score >= 80) {
        urgencyLabel = "High ($score)";
        urgencyColor = Colors.orange;
      } else {
        urgencyLabel = "Medium ($score)";
        urgencyColor = const Color(0xFF2563EB);
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            // LOCATION
            Expanded(
                flex: 3,
                child: Text(
                  location,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1E293B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
            ),

            // STATUS (Dynamic Badge)
            Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: statusBg,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(statusText, style: TextStyle(color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
                  ),
                )
            ),

            // URGENCY (Dynamic Progress Bar & Text)
            Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          urgencyLabel,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: urgencyColor)
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: urgencyValue,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          // Light grey background
                          valueColor: AlwaysStoppedAnimation<Color>(
                              urgencyColor), // Dynamic color
                        ),
                      ),
                    ],
                  ),
                )
            ),
          ],
        ),
      );
    }

    // 2. FUNDS SUMMARY CARD (REAL-TIME WALLET)
    Widget _buildFundsSummaryCard(BuildContext context,
        Map<String, dynamic> data) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                    LucideIcons.wallet, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 10),
                Text("Funds Summary", style: GoogleFonts.inter(fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B))),
              ],
            ),
            const SizedBox(height: 20),

            // Inner Light Blue Box with Real-Time Firebase Stream
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collectionGroup(
                      'donations').snapshots(),
                  builder: (context, snapshot) {
                    double totalFunds = 0.0;

                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        var docData = doc.data() as Map<String, dynamic>;
                        if (docData['type'] == 'money') {
                          totalFunds +=
                              (docData['amount'] as num? ?? 0.0).toDouble();
                        }
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            "NGO DIGITAL WALLET",
                            style: TextStyle(fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.5)
                        ),
                        const SizedBox(height: 8),
                        Text(
                            "RM ${totalFunds.toStringAsFixed(2)}",
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                color: const Color(0xFF1E293B))
                        ),
                        const SizedBox(height: 4),
                        const Text("Total Disbursable Relief Funds",
                            style: TextStyle(color: Color(0xFF64748B),
                                fontSize: 12)),
                      ],
                    );
                  }
              ),
            ),
            const SizedBox(height: 16),

            // FIXED: This is the correct Outlined Button to View Detailed Statements
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DetailedStatementScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))
                ),
                child: const Text("View Detailed Statements", style: TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              ),
            )
          ],
        ),
      );
    }

  // ==========================================
  // STRICT RULE: MANUAL ID ENTRY VERIFICATION
  // ==========================================
  Future<void> _verifyReceiptId(String receiptId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))), // Hardcoded NGO Blue
    );

    try {
      var querySnapshot = await FirebaseFirestore.instance.collectionGroup('donations').where('id', isEqualTo: receiptId).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance.collectionGroup('donations').where('qrCodeData', isEqualTo: receiptId).limit(1).get();
      }

      if (querySnapshot.docs.isEmpty) {
        Navigator.pop(context);
        _showErrorSnackBar("Receipt ID not found in the system.");
        return;
      }

      final docReference = querySnapshot.docs.first;
      final data = docReference.data();

      // 1. ROUTE MONEY TO FUNDS DIALOG
      if (data['type'] == 'money') {
        Navigator.pop(context);
        _showFundActionDialog(docReference.reference, data);
        return;
      }

      // 2. STRICT COURIER RULES FOR ITEMS
      bool isCourier = data['deliveryMethod'] == 'driver';
      bool isPickedUpDone = false;
      bool isArrivedAtHubDone = false;
      bool isPledgeConfirmedDone = false;
      bool isReceived = false;
      bool isDistributed = false;

      List<dynamic> milestones = List.from(data['milestones'] ?? []);

      for (var m in milestones) {
        if (m['label'] == 'Picked Up & In Transit' && m['done'] == true) isPickedUpDone = true;
        if (m['label'] == 'Arrived at NGO Hub' && m['done'] == true) isArrivedAtHubDone = true;
        if (m['label'] == 'Pledge Confirmed' && m['done'] == true) isPledgeConfirmedDone = true;
        if (m['label'] == 'Drop-off Verified' && m['done'] == true) isReceived = true;
        if (m['label'] == 'Distributed' && m['done'] == true) isDistributed = true;
      }

      if (isDistributed) {
        Navigator.pop(context);
        _showErrorSnackBar("Action Denied: This donation has already been verified and distributed.");
        return;
      }

      if (!isReceived) {
        // --- STRICT LOGISTICS GUARD ---
        if (isCourier) {
          if (!isPickedUpDone) {
            Navigator.pop(context);
            _showErrorSnackBar("Verification failed: Courier hasn't picked this up from the donor yet.");
            return;
          } else if (!isArrivedAtHubDone) {
            Navigator.pop(context);
            _showErrorSnackBar("Verification failed: Courier hasn't dropped this at the NGO Hub yet.");
            return;
          }
        } else {
          // Self Drop-off Check
          if (!isPledgeConfirmedDone) {
            Navigator.pop(context);
            _showErrorSnackBar("Verification failed: Pledge not confirmed.");
            return;
          }
        }

        Navigator.pop(context);
        _showNGOActionDialog(docReference.reference, data, milestones, 'receive');
      } else {
        Navigator.pop(context);
        _showNGOActionDialog(docReference.reference, data, milestones, 'distribute');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar("Error: ${e.toString()}");
    }
  }

  // ==========================================
  // STRICT RULE: QR SCANNER VERIFICATION
  // ==========================================
  Future<void> _processNGOQrScan(String qrData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))), // Hardcoded NGO Blue
    );

    try {
      var query = await FirebaseFirestore.instance.collectionGroup('donations').where('qrCodeData', isEqualTo: qrData).get();

      if (query.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showErrorSnackBar("Invalid QR Code. Donation package not found.");
        return;
      }

      var doc = query.docs.first;
      var data = doc.data();

      // ROUTE MONEY TO FUNDS DIALOG
      if (data['type'] == 'money') {
        if (mounted) Navigator.pop(context);
        _showFundActionDialog(doc.reference, data);
        return;
      }

      List<dynamic> milestones = List.from(data['milestones'] ?? []);

      bool isCourier = data['deliveryMethod'] == 'driver';
      bool isPickedUpDone = false;
      bool isArrivedAtHubDone = false;
      bool isPledgeConfirmedDone = false;
      bool isReceived = false;
      bool isDistributed = false;

      for (var m in milestones) {
        if (m['label'] == 'Picked Up & In Transit' && m['done'] == true) isPickedUpDone = true;
        if (m['label'] == 'Arrived at NGO Hub' && m['done'] == true) isArrivedAtHubDone = true;
        if (m['label'] == 'Pledge Confirmed' && m['done'] == true) isPledgeConfirmedDone = true;
        if (m['label'] == 'Drop-off Verified' && m['done'] == true) isReceived = true;
        if (m['label'] == 'Distributed' && m['done'] == true) isDistributed = true;
      }

      if (mounted) Navigator.pop(context);

      if (isDistributed) {
        _showErrorSnackBar("Action Denied: This donation has already been distributed.");
        return;
      }

      if (!isReceived) {
        // --- STRICT LOGISTICS GUARD ---
        if (isCourier) {
          if (!isPickedUpDone) {
            _showErrorSnackBar("Scan failed: Courier hasn't picked this up yet.");
            return;
          } else if (!isArrivedAtHubDone) {
            _showErrorSnackBar("Scan failed: Courier hasn't dropped this at the Hub yet.");
            return;
          }
        } else {
          if (!isPledgeConfirmedDone) {
            _showErrorSnackBar("Scan failed: Pledge not confirmed.");
            return;
          }
        }

        _showNGOActionDialog(doc.reference, data, milestones, 'receive');
      } else {
        _showNGOActionDialog(doc.reference, data, milestones, 'distribute');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Error processing QR: $e");
    }
  }

  // ==========================================
  // NEW: FUND VERIFICATION DIALOG
  // ==========================================
  void _showFundActionDialog(DocumentReference docRef, Map<String, dynamic> data) {
    List<dynamic> milestones = List.from(data['milestones'] ?? []);
    bool isAlreadyDistributed = false;

    for (var m in milestones) {
      if (m['label'] == 'Distributed' && m['done'] == true) isAlreadyDistributed = true;
    }

    if (isAlreadyDistributed) {
      _showErrorSnackBar("Action Denied: These funds have already been marked as distributed.");
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool isProcessing = false;
          return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.white,
                    child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: kEmerald.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.banknote, color: kEmerald, size: 40),
                              ),
                              const SizedBox(height: 16),
                              Text("Log Fund Disbursement", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              Text("RM ${(data['amount'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kEmerald)),
                              Text("Target: ${data['target']}", style: const TextStyle(color: Colors.grey)),
                              const Divider(height: 32),
                              const Text("Confirm that this monetary donation is officially being distributed to the beneficiaries.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5)),
                              const SizedBox(height: 24),
                              SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                      icon: const Icon(LucideIcons.checkCircle),
                                      label: const Text("Confirm Disbursement", style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: kEmerald,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                      ),
                                      onPressed: isProcessing ? null : () async {
                                        setState(() => isProcessing = true);
                                        try {
                                          String todayDate = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
                                          for (var m in milestones) {
                                            if (m['label'] == 'Distributed') {
                                              m['done'] = true;
                                              m['date'] = todayDate;
                                            }
                                          }
                                          await docRef.update({
                                            'milestones': milestones,
                                            'status': 'Funds Distributed'
                                          });

                                          await creditImpactIfMilestonesComplete(docRef);

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("Success! Funds distributed to beneficiaries."),
                                                  backgroundColor: kEmerald,
                                                  behavior: SnackBarBehavior.floating,
                                                )
                                            );
                                          }
                                        } catch (e) {
                                          setState(() => isProcessing = false);
                                          _showErrorSnackBar("Error: $e");
                                        }
                                      }
                                  )
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                              )
                            ]
                        )
                    )
                );
              }
          );
        }
    );
  }
    // Helper function to show errors nicely
    void _showErrorSnackBar(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.alertCircle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    // 3. VERIFY RECEIPT CARD (Big Blue QR Card)
    // 3. VERIFY RECEIPT CARD (Big Blue QR Card)
    // 3. VERIFY RECEIPT CARD (Big Blue QR Card)
    Widget _buildVerifyReceiptCard() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB), // Solid Blue
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.qrCode, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              "Verify Receipt",
              style: GoogleFonts.inter(color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Scan a donor's QR code or enter their receipt ID manually to confirm item arrivals.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Option 1: Open Scanner Button (Primary)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(LucideIcons.maximize, size: 18),
                // or LucideIcons.scan
                label: const Text("Scan QR Code", style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 12), // Spacing between buttons

            // Option 2: Enter ID Manually Button (Secondary)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showManualEntryDialog(context),
                icon: const Icon(LucideIcons.keyboard, size: 18),
                label: const Text("Enter ID Manually", style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          ],
        ),
      );
    }

    // --- NEW: VERIFY FUNDS CARD ---
    Widget _buildVerifyFundsCard() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: kEmerald, // Green theme for money
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: kEmerald.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.banknote, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              "Log Fund Disbursement",
              style: GoogleFonts.inter(color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter a donor's monetary receipt ID to officially mark their funds as distributed to victims.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showFundManualEntryDialog(context),
                icon: const Icon(LucideIcons.keyboard, size: 18),
                label: const Text("Enter Receipt ID", style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kEmerald,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            )
          ],
        ),
      );
    }

    // --- NEW: FUNDS MANUAL ENTRY DIALOG ---
    void _showFundManualEntryDialog(BuildContext context) {
      final TextEditingController idController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: kEmerald.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(
                        LucideIcons.banknote, color: kEmerald, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text("Verify Funds", style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87)),
                  const SizedBox(height: 8),
                  const Text(
                      "Type the donor's monetary receipt ID exactly as it appears.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black54, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: idController,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "e.g. KC-12345",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: kEmerald, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final enteredId = idController.text.trim();
                        if (enteredId.isNotEmpty) {
                          Navigator.pop(context);
                          _verifyFundReceiptId(enteredId); // Call logic
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(12)),
                      ),
                      child: const Text("Confirm Disbursement",
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors
                          .grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // --- NEW: FIREBASE LOGIC FOR FUNDS VERIFICATION ---
    Future<void> _verifyFundReceiptId(String receiptId) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
        const Center(child: CircularProgressIndicator(color: kEmerald)),
      );

      try {
        var querySnapshot = await FirebaseFirestore.instance.collectionGroup(
            'donations').where('id', isEqualTo: receiptId).limit(1).get();

        if (querySnapshot.docs.isEmpty) {
          Navigator.pop(context);
          _showErrorSnackBar("Receipt ID not found in the system.");
          return;
        }

        final docReference = querySnapshot.docs.first;
        final data = docReference.data();

        // Ensure this is actually a MONEY donation
        if (data['type'] != 'money') {
          Navigator.pop(context);
          _showErrorSnackBar(
              "This receipt is for a physical item. Please use the Blue Item Scanner above.");
          return;
        }

        bool isAlreadyDistributed = false;
        List<dynamic> milestones = List.from(data['milestones'] ?? []);

        for (var m in milestones) {
          if (m['label'] == 'Distributed' && m['done'] == true) {
            isAlreadyDistributed = true;
          }
        }

        if (isAlreadyDistributed) {
          Navigator.pop(context);
          _showErrorSnackBar(
              "Action Denied: These funds have already been marked as distributed.");
          return;
        }

        String todayDate = DateFormat('dd MMM yyyy, h:mm a').format(
            DateTime.now());

        for (var m in milestones) {
          if (m['label'] == 'Distributed') {
            m['done'] = true;
            m['date'] = todayDate;
          }
        }

        // Update Database
        await docReference.reference.update({
          'status': 'Funds Distributed',
          'milestones': milestones,
        });

        // Give Donor Impact Points!
        await creditImpactIfMilestonesComplete(docReference.reference);

        Navigator.pop(context); // Close spinner

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text("Funds verified & logged as distributed!",
                    style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            backgroundColor: kEmerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } catch (e) {
        Navigator.pop(context);
        _showErrorSnackBar("Error: ${e.toString()}");
      }
    }

    void _showManualEntryDialog(BuildContext context) {
      final TextEditingController idController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Decorative Header Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                        LucideIcons.keyboard, color: Color(0xFF2563EB),
                        size: 32),
                  ),
                  const SizedBox(height: 16),

                  // 2. Title
                  Text(
                    "Enter Receipt ID",
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. Subtitle
                  const Text(
                    "Type the donor's receipt ID or alphanumeric code exactly as it appears.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black54, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // 4. Styled Text Field
                  TextField(
                    controller: idController,
                    textAlign: TextAlign.center,
                    // Centering text looks better for IDs
                    style: GoogleFonts.inter(fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                    textCapitalization: TextCapitalization.characters,
                    // Auto-capitalize for IDs
                    decoration: InputDecoration(
                      hintText: "e.g. REC-12345",
                      hintStyle: TextStyle(color: Colors.grey.shade400,
                          letterSpacing: 0,
                          fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2563EB),
                            width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 24),

                  // 5. Full-Width Primary Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final enteredId = idController.text.trim();
                        if (enteredId.isNotEmpty) {
                          Navigator.pop(context); // Close the popup dialog

                          // Call the validation function
                          _verifyReceiptId(enteredId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(12)),
                        elevation: 0,
                      ),
                      child: const Text("Verify Receipt",
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 6. Full-Width Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(12)),
                      ),
                      child: const Text("Cancel", style: TextStyle(color: Colors
                          .grey, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // ==========================================
    // BACKEND LOGIC ACTIONS
    // ==========================================

    void _openScanner() async {
      final scannedCode = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (scannedCode != null && scannedCode is String) {
        _processNGOQrScan(scannedCode);
      }
    }

    void _showNGOActionDialog(DocumentReference docRef,
        Map<String, dynamic> data, List<dynamic> milestones, String action) {
      bool isReceiving = action == 'receive';

      // Dynamic Text & Colors based on Step
      String title = isReceiving
          ? "Verify Hub Drop-off"
          : "Log Final Distribution";
      String itemText = data['itemName'] ?? "Donation Package";
      String descText = isReceiving
          ? "Confirm that this item has been successfully received at the NGO Hub and logged into inventory."
          : "Confirm that this item is now being handed over to the beneficiaries in the target zone.";
      String btnText = isReceiving
          ? "Confirm Receipt at Hub"
          : "Distribute to Victims";
      IconData icon = isReceiving ? LucideIcons.box : LucideIcons.users;
      Color themeCol = isReceiving
          ? const Color(0xFF2563EB)
          : kEmerald; // Blue for receive, Green for distribute

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            bool isProcessing = false;

            return StatefulBuilder(
                builder: (context, setState) {
                  return Dialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      backgroundColor: Colors.white,
                      child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: themeCol
                                      .withOpacity(0.1), shape: BoxShape
                                      .circle),
                                  child: Icon(icon, color: themeCol, size: 40),
                                ),
                                const SizedBox(height: 16),
                                Text(title, style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    color: const Color(0xFF1E293B))),
                                const SizedBox(height: 8),

                                Text(itemText,
                                    style: TextStyle(fontWeight: FontWeight
                                        .bold, fontSize: 18, color: themeCol)),
                                Text("Target: ${data['target']}",
                                    style: const TextStyle(color: Colors.grey)),

                                const Divider(height: 32),
                                Text(
                                    descText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(
                                        0xFF64748B), fontSize: 13, height: 1.5)
                                ),
                                const SizedBox(height: 24),

                                SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                        icon: const Icon(
                                            LucideIcons.checkCircle),
                                        label: Text(btnText,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: themeCol,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius
                                                    .circular(12))
                                        ),
                                        onPressed: isProcessing
                                            ? null
                                            : () async {
                                          setState(() => isProcessing = true);

                                          try {
                                            String todayDate = DateFormat(
                                                'dd MMM yyyy, h:mm a').format(
                                                DateTime.now());

                                            // Update only the relevant milestone based on the action
                                            for (var m in milestones) {
                                              if (isReceiving && m['label'] ==
                                                  'Drop-off Verified') {
                                                m['done'] = true;
                                                m['date'] = todayDate;
                                              }
                                              if (!isReceiving &&
                                                  m['label'] == 'Distributed') {
                                                m['done'] = true;
                                                m['date'] = todayDate;
                                              }
                                            }

                                            // Status changes to Inventory, then to Distributed
                                            String newStatus = isReceiving
                                                ? "Inventory at Hub"
                                                : "Distributed";

                                            await docRef.update({
                                              'milestones': milestones,
                                              'status': newStatus,
                                            });

                                            // ONLY give the Donor points when it reaches the victims!
                                            if (!isReceiving) {
                                              await creditImpactIfMilestonesComplete(
                                                  docRef);
                                            }

                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger
                                                  .of(context)
                                                  .showSnackBar(
                                                  SnackBar(
                                                    content: Text(isReceiving
                                                        ? "Item logged into inventory!"
                                                        : "Success! Item distributed to beneficiaries."),
                                                    backgroundColor: themeCol,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  )
                                              );
                                            }
                                          } catch (e) {
                                            setState(() =>
                                            isProcessing = false);
                                            ScaffoldMessenger
                                                .of(context)
                                                .showSnackBar(SnackBar(
                                                content: Text("Error: $e"),
                                                backgroundColor: Colors
                                                    .redAccent));
                                          }
                                        }
                                    )
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                    onPressed: isProcessing ? null : () =>
                                        Navigator.pop(context),
                                    child: const Text(
                                        "Cancel", style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold))
                                )
                              ]
                          )
                      )
                  );
                }
            );
          }
      );
    }
  }


// ==========================================
// NEW SCREEN: DETAILED STATEMENTS
// ==========================================
class DetailedStatementScreen extends StatelessWidget {
  const DetailedStatementScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Transaction History", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch the same collection
        stream: FirebaseFirestore.instance.collectionGroup('donations').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No transactions found."));
          }

          // 1. Filter out only 'money' donations
          // 2. Convert to list
          var transactions = snapshot.data!.docs.map((doc) {
            return doc.data() as Map<String, dynamic>;
          }).where((data) => data['type'] == 'money').toList();

          // 3. Sort by date (Newest first)
          transactions.sort((a, b) {
            Timestamp? timeA = a['timestamp'];
            Timestamp? timeB = b['timestamp'];
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA); // Descending order
          });

          if (transactions.isEmpty) {
            return const Center(child: Text("No money transactions found."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) {
              var tx = transactions[index];
              double amount = (tx['amount'] as num? ?? 0.0).toDouble();

              // Handle Date formatting
              DateTime? date;
              if (tx['timestamp'] != null) {
                date = (tx['timestamp'] as Timestamp).toDate();
              }
              String dateString = date != null
                  ? "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}"
                  : "Unknown Date";

              // Get donor name if you save it, otherwise default to Anonymous
              String donorName = tx['donorName'] ?? "Anonymous Donor";

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7), // Light green background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_downward, color: Color(0xFF16A34A)), // Green arrow
                ),
                title: Text(
                  "Donation Received",
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text("From: $donorName", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(dateString, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: Text(
                  "+ RM ${amount.toStringAsFixed(2)}",
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: const Color(0xFF16A34A) // Green text for positive amount
                  ),
                ),
              );
            },
          );
        },
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

// ==========================================
// GLOBAL AI SYNC ENGINE
// ==========================================
bool _isGlobalSyncing = false;

Future<void> ensureReliefDataIsSynced({bool forceRefresh = false}) async {
  if (_isGlobalSyncing) return;
  _isGlobalSyncing = true;

  try {
    final snapshot = await FirebaseFirestore.instance.collection('relief_cache').doc('current_status').get();
    List<dynamic> oldResults = [];

    if (snapshot.exists) {
      final data = snapshot.data()!;
      final Timestamp? timestamp = data['timestamp'] as Timestamp?;

      // If not forced, check if data is fresh (< 30 minutes old)
      if (!forceRefresh && timestamp != null) {
        final DateTime lastFetch = timestamp.toDate();
        if (DateTime.now().difference(lastFetch).inMinutes < 30) {
          _isGlobalSyncing = false;
          return; // It's fresh! Stop here.
        }
      }
      oldResults = data['results'] ?? [];
    }

    // --- RUN AI GENERATION ---
    final apiKey = dotenv.env['GEMINI_KEY'];
    if (apiKey == null) {
      _isGlobalSyncing = false;
      return;
    }
    final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: apiKey);

    final prompt = "Search active disaster situations in Malaysia (Last 48h). Categories: Flood Relief, Food Security, Medical Aid. Return strictly RAW JSON LIST ONLY. Provide exactly 3 specific items for each category in needed_items. Format: [{\"location\": \"string\", \"category\": \"string\", \"description\": \"string\", \"score\": 90, \"lat\": 4.0, \"lng\": 101.0, \"severities\": {\"edu\": \"Medium/High/Critical\", \"cloth\": \"Medium/High/Critical\", \"food\": \"Medium/High/Critical\", \"med\": \"Medium/High/Critical\", \"rel\": \"Medium/High/Critical\"}, \"needed_items\": {\"edu\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"cloth\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"food\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"med\": [\"Item 1\", \"Item 2\", \"Item 3\"], \"rel\": [\"Item 1\", \"Item 2\", \"Item 3\"]}}]";

    final response = await model.generateContent([Content.text(prompt)]);
    String rawJson = response.text ?? "[]";

    // Clean JSON string
    rawJson = rawJson.replaceAll('```json', '').replaceAll('```', '').trim();
    int start = rawJson.indexOf('[');
    int end = rawJson.lastIndexOf(']');
    if (start != -1 && end != -1) rawJson = rawJson.substring(start, end + 1);

    final List<dynamic> newAiResults = jsonDecode(rawJson);

    // --- SMART MERGE LOGIC ---
    List<dynamic> mergedResults = [];

    // Step A: Rescue all Manually Added Locations
    for (var oldZone in oldResults) {
      bool isManual = oldZone['isManual'] == true || (oldZone['description']?.toString().contains("NGO REPORT:") ?? false);
      if (isManual) {
        mergedResults.add(oldZone);
      }
    }

    // Step B: Process New AI Locations & Rescue Items
    for (var aiZone in newAiResults) {
      String aiLoc = aiZone['location'] ?? "";
      int existingIndex = mergedResults.indexWhere((z) => z['location'] == aiLoc);

      if (existingIndex != -1) {
        _globalMergeItems(mergedResults[existingIndex], aiZone);
      } else {
        var oldAiZone = oldResults.firstWhere((z) => z['location'] == aiLoc, orElse: () => null);
        if (oldAiZone != null) {
          _globalMergeItems(aiZone, oldAiZone as Map<String, dynamic>);
        }
        mergedResults.add(aiZone);
      }
    }

    // --- SAVE TO FIRESTORE ---
    await FirebaseFirestore.instance.collection('relief_cache').doc('current_status').set({
      'results': mergedResults,
      'timestamp': FieldValue.serverTimestamp(),
    });

  } catch (e) {
    debugPrint("Global AI Sync Error: $e");
  } finally {
    _isGlobalSyncing = false;
  }
}

// Global Helper
void _globalMergeItems(Map<String, dynamic> target, Map<String, dynamic> source) {
  Map<String, dynamic> targetItems = Map<String, dynamic>.from(target['needed_items'] ?? {});
  Map<String, dynamic> sourceItems = Map<String, dynamic>.from(source['needed_items'] ?? {});

  sourceItems.forEach((key, sourceList) {
    if (sourceList is List) {
      List<dynamic> tList = List.from(targetItems[key] ?? []);
      for (var item in sourceList) {
        String itemStr = item.toString().trim();
        if (itemStr != "Blanket") {
          bool exists = tList.any((t) => t.toString().trim().toLowerCase() == itemStr.toLowerCase());
          if (!exists) {
            tList.add(itemStr);
          }
        }
      }
      targetItems[key] = tList;
    }
  });
  target['needed_items'] = targetItems;
}

class ReliefMap extends StatefulWidget {
  final VoidCallback? onTopUp;
  final String userRole; // <--- 1. ADD THIS

  const ReliefMap({super.key, this.onTopUp, this.userRole = 'donor'}); // <--- 2. UPDATE THIS
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

  // --- THE CORE LOGIC: SYNC BETWEEN FIRESTORE CACHE AND AI ---
  Future<void> _syncReliefData({bool forceRefresh = false}) async {
    setState(() => isLoading = true);

    // 1. Call the Global Engine (It handles AI fetching, merging, and Firestore saving automatically)
    await ensureReliefDataIsSynced(forceRefresh: forceRefresh);

    // 2. Fetch the newly synced data from Firestore to display on the local map UI
    try {
      final snapshot = await FirebaseFirestore.instance.collection('relief_cache').doc('current_status').get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
        _updateUI(data['results'] ?? [], timestamp.toDate());
      }
    } catch (e) {
      debugPrint("Error loading map data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- NEW HELPER: Merges existing NGO items with new AI items ---
  void _mergeItemsIntoTarget(Map<String, dynamic> target, Map<String, dynamic> source) {
    Map<String, dynamic> targetItems = Map<String, dynamic>.from(target['needed_items'] ?? {});
    Map<String, dynamic> sourceItems = Map<String, dynamic>.from(source['needed_items'] ?? {});

    sourceItems.forEach((key, sourceList) {
      if (sourceList is List) {
        List<dynamic> tList = List.from(targetItems[key] ?? []);
        for (var item in sourceList) {
          String itemStr = item.toString().trim();
          // Prevent duplicates and ignore placeholder
          if (itemStr != "Blanket") {
            bool exists = tList.any((t) => t.toString().trim().toLowerCase() == itemStr.toLowerCase());
            if (!exists) {
              tList.add(itemStr);
            }
          }
        }
        targetItems[key] = tList;
      }
    });
    target['needed_items'] = targetItems;
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
                          onPressed: () => _syncReliefData(forceRefresh: true), // <-- Fix is here
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
                    urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
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
          if (widget.userRole == 'donor') ...[
            const SizedBox(height: 16),
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(double.infinity, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          ]
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
                                  });
                                }

                                String todayDate = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
                                DocumentReference newDonationRef = await userRef.collection('donations').add({
                                  'id': "KC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
                                  'target': item['location'] ?? "Relief Project",
                                  'category': item['category'] ?? "Relief Aid",
                                  'status': "Processing", // Changed to Processing initially
                                  'type': 'money',
                                  'amount': donateAmount,
                                  'imageUrl': imageToSave,
                                  'isCredited': false,
                                  'milestones': [
                                    {'label': 'Payment Verified', 'date': todayDate, 'done': true},
                                    {'label': 'NGO Verified', 'date': todayDate, 'done': true},

                                    // ---> CHANGED TO FALSE HERE <---
                                    {'label': 'Distributed', 'date': '', 'done': false}
                                  ],
                                  'timestamp': FieldValue.serverTimestamp(),
                                });

                                // Removed the instant point-crediting so they get points later

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
                              sev['edu'] ?? "Medium",
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
                              sev['cloth'] ?? "Medium",
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
                              sev['food'] ?? "Medium",
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
                              sev['med'] ?? "Medium",
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
                              sev['rel'] ?? "Medium", // 'rel' matches your AI JSON key
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

  Future<String> _saveItemDonationToFirebase(Map<String, dynamic> locationData, String item, String imageUrl, String deliveryMethod) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "ERROR";

    // 1. Generate unique QR Data
    String uniqueId = "KC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
    String qrString = "$uniqueId-${item.substring(0,3).toUpperCase()}";

    // ---> NEW: Get current date formatted as a string <---
    String todayDate = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
    // (Or use: String todayDate = DateFormat('dd MMM yyyy').format(DateTime.now()); if you use the intl package)

    // 2. Setup Milestones based on method
    String initialStatus = deliveryMethod == 'self' ? "Pending Drop-off" : "Awaiting Courier";

    List<Map<String, dynamic>> finalMilestones = deliveryMethod == 'self'
        ? [
      // ---> Changed 'Today' to todayDate <---
      {'label': 'Pledge Confirmed', 'date': todayDate, 'done': true},
      {'label': 'Drop-off Verified', 'date': '', 'done': false},
      {'label': 'Distributed', 'date': '', 'done': false},
    ]
        : [
      // ---> Changed 'Today' to todayDate <---
      {'label': 'Courier Assigned', 'date': todayDate, 'done': true},
      {'label': 'Picked Up & In Transit', 'date': '', 'done': false},
      {'label': 'Arrived at NGO Hub', 'date': '', 'done': false},
      {'label': 'Drop-off Verified', 'date': '', 'done': false},
      {'label': 'Distributed', 'date': '', 'done': false}
    ];

    // 3. Add to Firebase
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('donations')
        .add({
      'id': uniqueId,
      'target': locationData['location'] ?? "Unknown Zone",
      'category': (locationData['category'] is String) ? locationData['category'] : "Relief Aid",
      'status': initialStatus,
      'type': 'item',
      'deliveryMethod': deliveryMethod,
      'itemName': item,
      'imageUrl': imageUrl,
      'qrCodeData': qrString,
      'isCredited': false,
      'milestones': finalMilestones, // Uses the updated list
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
  const NotificationBell({super.key});

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
          .snapshots(),
      builder: (context, snapshot) {
        List<Map<String, dynamic>> notifications = [];

        // ==========================================
        // 1. FIX: CACHE 'NOW' ONCE PER BUILD
        // Prevents the microsecond inversion bug in loops
        // ==========================================
        final DateTime currentBuildTime = DateTime.now();

        DateTime parseDocTime(dynamic ts) {
          if (ts == null) return currentBuildTime;
          if (ts is Timestamp) return ts.toDate();
          if (ts is String) return DateTime.tryParse(ts) ?? currentBuildTime;
          if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
          return currentBuildTime;
        }

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final List<dynamic> milestones = data['milestones'] ?? [];

            final bool isMoney = data['type'] == 'money';
            final String amountStr = data['amount'] != null ? "RM ${data['amount']}" : "Funds";
            final String itemName = data['itemName'] ?? "Item";
            final String target = data['target'] ?? "Unknown Hub";
            final String method = data['deliveryMethod'] ?? "self";

            final DateTime docDateTime = parseDocTime(data['timestamp']);

            for (int i = 0; i < milestones.length; i++) {
              final m = milestones[i] as Map<String, dynamic>;

              if (m['done'] == true) {
                DateTime milestoneDateTime = docDateTime;

                if (m['date'] != null) {
                  String dateStr = m['date'].toString().trim();

                  if (dateStr.toLowerCase() != 'today' && dateStr.toLowerCase() != 'pending' && dateStr.isNotEmpty) {
                    try {
                      // Clean up formatting
                      dateStr = dateStr
                          .replaceAll(RegExp(r'(?i)a\.?m\.?'), 'AM')
                          .replaceAll(RegExp(r'(?i)p\.?m\.?'), 'PM');

                      milestoneDateTime = DateFormat('dd MMM yyyy, h:mm a').parse(dateStr);
                    } catch (e) {
                      // Use the cached time so all failed parses tie perfectly
                      milestoneDateTime = currentBuildTime;
                    }
                  } else if (dateStr.toLowerCase() == 'today') {
                    milestoneDateTime = currentBuildTime;
                  }
                }

                String bodyText;
                IconData iconData;

                if (isMoney) {
                  bodyText = 'Update: Your donation of $amountStr for $target is now marked as ${m['label']}.';
                  iconData = LucideIcons.banknote;
                } else if (method == 'driver') {
                  bodyText = 'Update: Your $itemName for $target has reached this status.';
                  iconData = LucideIcons.truck;
                } else {
                  bodyText = 'Update: Your drop-off of $itemName for $target is verified.';
                  iconData = LucideIcons.box;
                }

                notifications.add({
                  'title': m['label'] ?? 'Update',
                  'body': bodyText,
                  'icon': iconData,
                  'color': i == milestones.length - 1 ? Colors.green : Colors.blue,
                  'timestamp': milestoneDateTime,
                  'docTimestamp': docDateTime, // Saved for tie-breaking
                  'milestoneIndex': i,
                });
              }
            }
          }
        }

        // ==========================================
        // 2. FIX: ROCK-SOLID 3-STEP SORTING
        // ==========================================
        notifications.sort((a, b) {
          final DateTime timeA = a['timestamp'] as DateTime;
          final DateTime timeB = b['timestamp'] as DateTime;

          // STEP 1: Sort by the Milestone's Timestamp (Newest first)
          int timeComparison = timeB.compareTo(timeA);
          if (timeComparison != 0) return timeComparison;

          // STEP 2: If timestamps match (e.g. they both defaulted to currentBuildTime),
          // sort by Document Creation Time (Newer donations first)
          final DateTime docA = a['docTimestamp'] as DateTime;
          final DateTime docB = b['docTimestamp'] as DateTime;
          int docComparison = docB.compareTo(docA);
          if (docComparison != 0) return docComparison;

          // STEP 3: If it's the exact same donation, sort by Milestone Step (Highest step first)
          final int idxA = a['milestoneIndex'] as int;
          final int idxB = b['milestoneIndex'] as int;
          return idxB.compareTo(idxA);
        });

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
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
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

  Widget _buildSheetContent(BuildContext context, List<Map<String, dynamic>> notifications) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Column(
        children: [
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
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(notifications[index]);
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
    final DateTime dt = notif['timestamp'] as DateTime? ?? DateTime.now();
    final String timeAgo = _getTimeAgo(dt);

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
                Text(timeAgo, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);

    if (diff.inDays > 8) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if ((diff.inDays / 7).floor() >= 1) {
      return '1w ago';
    } else if (diff.inDays >= 2) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays >= 1) {
      return '1d ago';
    } else if (diff.inHours >= 2) {
      return '${diff.inHours}h ago';
    } else if (diff.inHours >= 1) {
      return '1h ago';
    } else if (diff.inMinutes >= 2) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inMinutes >= 1) {
      return '1m ago';
    } else if (diff.inSeconds >= 3) {
      return '${diff.inSeconds}s ago';
    } else {
      return 'Just now';
    }
  }
}

// ==========================================
// 5. AI ADVISOR PAGE (DEEPLY INTEGRATED)
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
    _messages = [
      {
        "role": "ai",
        "text": widget.role == 'ngo'
            ? "Selamat Sejahtera! I am KitaCare NGO Support AI. I am connected to your NGO Portal. I can check your wallet, help you log disbursements, or verify incoming drop-offs. How can I assist your mission today?"
            : "Selamat Sejahtera! I am KitaCare AI. I am securely connected to your account. I can check your wallet balance, tell you your Philanthropy Tier, or guide you on how to donate. What do you need help with?"
      }
    ];
  }

  // --- HELPER 1: Calculate Tier ---
  String _calculateTier(double impactScore) {
    if (impactScore >= 5000) return "PLATINUM (National Hero)";
    if (impactScore >= 1000) return "GOLD (Community Pillar)";
    if (impactScore >= 200) return "SILVER (Generous Giver)";
    return "BRONZE (Rising Supporter)";
  }

  // --- HELPER 2: Fetch Live User Context ---
  Future<Map<String, String>> _fetchUserContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (uid.isEmpty) return {"balance": "0.00", "tier": "Unknown", "name": "User"};

    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        double balance = (data['walletBalance'] ?? 0.0).toDouble();
        double impact = (data['impactValue'] ?? 0.0).toDouble();
        String name = data['name'] ?? "User";

        return {
          "balance": balance.toStringAsFixed(2),
          "tier": _calculateTier(impact),
          "name": name,
          "impact": impact.toStringAsFixed(2)
        };
      }
    } catch (e) {
      debugPrint("Context fetch error: $e");
    }
    return {"balance": "0.00", "tier": "Unknown", "name": "User"};
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
      final apiKey = dotenv.env['GEMINI_ADVISOR_KEY'] ?? dotenv.env['GEMINI_KEY'];
      if (apiKey == null || apiKey.isEmpty) throw "API Key not found";

      final model = GenerativeModel(model: 'gemini-3.1-flash-lite-preview', apiKey: apiKey);

      // 1. GET REAL USER DATA
      final userCtx = await _fetchUserContext();

      // 2. GET RELIEF MAP DATA
      String liveMapContext = "Active Zones:\n";
      try {
        final cacheSnap = await FirebaseFirestore.instance.collection('relief_cache').doc('current_status').get();
        if (cacheSnap.exists && cacheSnap.data() != null) {
          List<dynamic> results = cacheSnap.data()!['results'] ?? [];
          for (var zone in results) {
            liveMapContext += "- ${zone['location']} (Needs: ${zone['category']})\n";
          }
        }
      } catch (e) {
        liveMapContext = "Map data currently syncing.";
      }

      // 3. BUILD THE "APP MANUAL"
      String actionTriggers = "If the user wants to top up their wallet, include this tag: [ACTION: TOP_UP]";

      if (widget.role == 'ngo') {
        actionTriggers += "\nIf the user explicitly asks you to verify a physical drop off or scan an item, you MUST include this exact tag: [ACTION: VERIFY_RECEIPT]";
        actionTriggers += "\nIf the user explicitly asks you to verify a money donation or fund disbursement, you MUST include this exact tag: [ACTION: VERIFY_FUNDS]";
      } else {
        actionTriggers += "\nIf the user asks to verify a drop off, politely inform them that only authorized NGOs can perform this action. Do NOT include any action tags.";
      }

      String appManual = """
      --- APP MANUAL & CAPABILITIES ---
      You are the official KitaCare AI.

      USER LIVE PROFILE:
      - Name: ${userCtx['name']}
      - Role: ${widget.role.toUpperCase()}

      HOW TO USE THE APP:
      - How to top-up wallet: "Go to your Dashboard, find the KitaCare Wallet section, and tap 'Top Up Funds'."
      - How to verify physical item drop-off (NGO only): "I can open the item scanner or manual entry for you right here in the chat!"
      - How to verify money/fund disbursement (NGO only): "I can open the secure fund verification terminal for you right here!"
      
      ACTION TRIGGERS (Crucial!):
      $actionTriggers
      """;

      final prompt = """
      $appManual
      
      MAP DATA: $liveMapContext

      USER QUESTION:
      $text
      
      Remember: Answer naturally and conversationally. Use the User Live Profile to answer personal questions directly.
      """;

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
        _messages.add({
          "role": "ai",
          "text": "Sorry, I encountered an error connecting to my system. $e"
        });
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

  // --- UI ACTION INTERCEPTION HANDLERS ---
  void _executeAction(String action) async {
    if ((action == 'SCAN_QR' || action == 'MANUAL_ENTRY' || action == 'VERIFY_FUNDS') && widget.role != 'ngo') {
      _showErrorSnackBar("Access Denied: Only NGOs can verify donations.");
      return;
    }

    if (action == 'SCAN_QR') {
      final scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
      if (scannedCode != null && scannedCode is String) _processNGOQrScan(scannedCode);
    } else if (action == 'MANUAL_ENTRY') {
      _showManualEntryDialog(context);
    } else if (action == 'VERIFY_FUNDS') {
      _showFundManualEntryDialog(context); // NEW: Opens the Green Money Dialog
    } else if (action == 'TOP_UP') {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Navigating... Please go to your Dashboard tab to Top Up."), backgroundColor: widget.role == 'ngo' ? kBlue : kEmerald)
      );
    }
  }

  // ==========================================
  // IN-CHAT VERIFICATION LOGIC
  // ==========================================

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final TextEditingController idController = TextEditingController();
    final themeColor = widget.role == 'ngo' ? kBlue : kEmerald;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(LucideIcons.keyboard, color: themeColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text("Enter Receipt ID", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                const SizedBox(height: 8),
                const Text("Type the donor's receipt ID or alphanumeric code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13, height: 1.5)),
                const SizedBox(height: 24),
                TextField(
                  controller: idController,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "e.g. KC-12345",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeColor, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final enteredId = idController.text.trim();
                      if (enteredId.isNotEmpty) {
                        Navigator.pop(context);
                        _verifyReceiptId(enteredId);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("Verify Receipt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // IN-CHAT VERIFICATION LOGIC (STRICT LOGISTICS)
  // ==========================================

  Future<void> _verifyReceiptId(String receiptId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: widget.role == 'ngo' ? kBlue : kEmerald)),
    );

    try {
      var querySnapshot = await FirebaseFirestore.instance.collectionGroup('donations').where('id', isEqualTo: receiptId).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        querySnapshot = await FirebaseFirestore.instance.collectionGroup('donations').where('qrCodeData', isEqualTo: receiptId).limit(1).get();
      }

      if (querySnapshot.docs.isEmpty) {
        Navigator.pop(context);
        _showErrorSnackBar("Receipt ID not found in the system.");
        return;
      }

      final docReference = querySnapshot.docs.first;
      final data = docReference.data();

      if (data['type'] == 'money') {
        Navigator.pop(context);
        _showErrorSnackBar("Cannot verify money donations. Only physical items.");
        return;
      }

      // --- NEW: Identify Delivery Method ---
      bool isCourier = data['deliveryMethod'] == 'driver';

      bool isPickedUpDone = false;
      bool isArrivedAtHubDone = false;
      bool isPledgeConfirmedDone = false;
      bool isReceived = false;
      bool isDistributed = false;

      List<dynamic> milestones = List.from(data['milestones'] ?? []);

      for (var m in milestones) {
        if (m['label'] == 'Picked Up & In Transit' && m['done'] == true) isPickedUpDone = true;
        if (m['label'] == 'Arrived at NGO Hub' && m['done'] == true) isArrivedAtHubDone = true;
        if (m['label'] == 'Pledge Confirmed' && m['done'] == true) isPledgeConfirmedDone = true;
        if (m['label'] == 'Drop-off Verified' && m['done'] == true) isReceived = true;
        if (m['label'] == 'Distributed' && m['done'] == true) isDistributed = true;
      }

      if (isDistributed) {
        Navigator.pop(context);
        _showErrorSnackBar("Action Denied: This donation has already been verified and distributed.");
        return;
      }

      if (!isReceived) {
        // --- STRICT LOGISTICS GUARD ---
        if (isCourier) {
          if (!isPickedUpDone) {
            Navigator.pop(context);
            _showErrorSnackBar("Verification failed: Courier hasn't picked this up yet.");
            return;
          } else if (!isArrivedAtHubDone) {
            Navigator.pop(context);
            _showErrorSnackBar("Verification failed: Courier hasn't dropped this at the Hub yet.");
            return;
          }
        } else {
          // Self Drop-off
          if (!isPledgeConfirmedDone) {
            Navigator.pop(context);
            _showErrorSnackBar("Verification failed: Pledge not confirmed.");
            return;
          }
        }

        Navigator.pop(context);
        _showNGOActionDialog(docReference.reference, data, milestones, 'receive');
      } else {
        Navigator.pop(context);
        _showNGOActionDialog(docReference.reference, data, milestones, 'distribute');
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar("Error: ${e.toString()}");
    }
  }

  Future<void> _processNGOQrScan(String qrData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: widget.role == 'ngo' ? kBlue : kEmerald)),
    );

    try {
      var query = await FirebaseFirestore.instance.collectionGroup('donations').where('qrCodeData', isEqualTo: qrData).get();

      if (query.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        _showErrorSnackBar("Invalid QR Code. Donation package not found.");
        return;
      }

      var doc = query.docs.first;
      var data = doc.data();
      List<dynamic> milestones = List.from(data['milestones'] ?? []);

      // --- NEW: Identify Delivery Method ---
      bool isCourier = data['deliveryMethod'] == 'driver';

      bool isPickedUpDone = false;
      bool isArrivedAtHubDone = false;
      bool isPledgeConfirmedDone = false;
      bool isReceived = false;
      bool isDistributed = false;

      for (var m in milestones) {
        if (m['label'] == 'Picked Up & In Transit' && m['done'] == true) isPickedUpDone = true;
        if (m['label'] == 'Arrived at NGO Hub' && m['done'] == true) isArrivedAtHubDone = true;
        if (m['label'] == 'Pledge Confirmed' && m['done'] == true) isPledgeConfirmedDone = true;
        if (m['label'] == 'Drop-off Verified' && m['done'] == true) isReceived = true;
        if (m['label'] == 'Distributed' && m['done'] == true) isDistributed = true;
      }

      if (mounted) Navigator.pop(context);

      if (isDistributed) {
        _showErrorSnackBar("Action Denied: This donation has already been distributed.");
        return;
      }

      if (!isReceived) {
        // --- STRICT LOGISTICS GUARD ---
        if (isCourier) {
          if (!isPickedUpDone) {
            _showErrorSnackBar("Scan failed: Courier hasn't picked this up yet.");
            return;
          } else if (!isArrivedAtHubDone) {
            _showErrorSnackBar("Scan failed: Courier hasn't dropped this at the Hub yet.");
            return;
          }
        } else {
          // Self Drop-off
          if (!isPledgeConfirmedDone) {
            _showErrorSnackBar("Scan failed: Pledge not confirmed.");
            return;
          }
        }

        _showNGOActionDialog(doc.reference, data, milestones, 'receive');
      } else {
        _showNGOActionDialog(doc.reference, data, milestones, 'distribute');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar("Error processing QR: $e");
    }
  }

  void _showNGOActionDialog(DocumentReference docRef, Map<String, dynamic> data, List<dynamic> milestones, String action) {
    bool isReceiving = action == 'receive';
    String title = isReceiving ? "Verify Hub Drop-off" : "Log Final Distribution";
    String itemText = data['itemName'] ?? "Donation Package";
    String descText = isReceiving
        ? "Confirm that this item has been successfully received at the NGO Hub and logged into inventory."
        : "Confirm that this item is now being handed over to the beneficiaries in the target zone.";
    String btnText = isReceiving ? "Confirm Receipt at Hub" : "Distribute to Victims";
    IconData icon = isReceiving ? LucideIcons.box : LucideIcons.users;
    Color themeCol = isReceiving ? (widget.role == 'ngo' ? kBlue : kEmerald) : kEmerald;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool isProcessing = false;
          return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.white,
                    child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: themeCol.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(icon, color: themeCol, size: 40),
                              ),
                              const SizedBox(height: 16),
                              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              Text(itemText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeCol)),
                              Text("Target: ${data['target']}", style: const TextStyle(color: Colors.grey)),
                              const Divider(height: 32),
                              Text(descText, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5)),
                              const SizedBox(height: 24),
                              SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                      icon: const Icon(LucideIcons.checkCircle),
                                      label: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: themeCol,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                      ),
                                      onPressed: isProcessing ? null : () async {
                                        setState(() => isProcessing = true);
                                        try {
                                          String todayDate = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
                                          for (var m in milestones) {
                                            if (isReceiving && m['label'] == 'Drop-off Verified') { m['done'] = true; m['date'] = todayDate; }
                                            if (!isReceiving && m['label'] == 'Distributed') { m['done'] = true; m['date'] = todayDate; }
                                          }
                                          String newStatus = isReceiving ? "Inventory at Hub" : "Distributed";
                                          await docRef.update({'milestones': milestones, 'status': newStatus});

                                          if (!isReceiving) {
                                            await creditImpactIfMilestonesComplete(docRef);
                                          }

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(isReceiving ? "Item logged into inventory!" : "Success! Item distributed to beneficiaries."),
                                                  backgroundColor: themeCol,
                                                  behavior: SnackBarBehavior.floating,
                                                )
                                            );
                                          }
                                        } catch (e) {
                                          setState(() => isProcessing = false);
                                          _showErrorSnackBar("Error: $e");
                                        }
                                      }
                                  )
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                              )
                            ]
                        )
                    )
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNgo = widget.role == 'ngo';
    final themeColor = isNgo ? kBlue : kEmerald;
    final titleText = isNgo ? "NGO AI Assistant" : "Donor AI Assistant";

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // HEADER
          Container(
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
                  child: const Icon(LucideIcons.bot, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleText, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: kSlate800)),
                    Text("CONNECTED TO YOUR ACCOUNT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: themeColor, letterSpacing: 1.0)),
                  ],
                )
              ],
            ),
          ),

          // CHAT AREA
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
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const PulsingLoadingText(),
                    ),
                  );
                }

                final msg = _messages[index];
                final isAi = msg['role'] == 'ai';

                // --- ACTION INTERCEPTION LOGIC (DUAL BUTTONS) ---
                // --- ACTION INTERCEPTION LOGIC (DUAL BUTTONS) ---
                String displayText = msg['text'];

                bool hasVerifyAction = (displayText.contains('[ACTION: VERIFY_RECEIPT]') || displayText.contains('[ACTION: SCAN_QR]')) && isNgo;
                bool hasVerifyFundsAction = displayText.contains('[ACTION: VERIFY_FUNDS]') && isNgo; // NEW TRIGGER
                bool hasTopUpAction = displayText.contains('[ACTION: TOP_UP]');

                // Clean the text
                displayText = displayText
                    .replaceAll('[ACTION: VERIFY_RECEIPT]', '')
                    .replaceAll('[ACTION: SCAN_QR]', '')
                    .replaceAll('[ACTION: VERIFY_FUNDS]', '') // Hide new tag
                    .replaceAll('[ACTION: TOP_UP]', '')
                    .trim();

                return Align(
                  alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    child: Column(
                      crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isAi ? Colors.white : themeColor,
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
                            displayText,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.5,
                              color: isAi ? kSlate800 : Colors.white,
                              fontWeight: isAi ? FontWeight.w500 : FontWeight.w600,
                            ),
                          ),
                        ),

                        // --- RENDER DUAL BUTTONS IF VERIFY TAG WAS DETECTED ---
                        if (hasVerifyAction) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _executeAction('SCAN_QR'),
                                icon: const Icon(LucideIcons.camera, size: 16),
                                label: const Text("Scan QR"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _executeAction('MANUAL_ENTRY'),
                                icon: const Icon(LucideIcons.keyboard, size: 16),
                                label: const Text("Enter ID"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: themeColor,
                                    side: BorderSide(color: themeColor, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                ),
                              )
                            ],
                          )
                        ],
                        if (hasVerifyFundsAction) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _executeAction('VERIFY_FUNDS'),
                            icon: const Icon(LucideIcons.banknote, size: 16),
                            label: const Text("Verify Money Receipt"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kEmerald, // Green for money
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          )
                        ],

                        if (hasTopUpAction) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _executeAction('TOP_UP'),
                            icon: const Icon(LucideIcons.wallet, size: 16),
                            label: const Text("Go to Wallet"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // INPUT AREA
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
                      hintText: isNgo ? "Ask to verify a drop-off..." : "Ask what your Philanthropy tier is...",
                      hintStyle: const TextStyle(color: kSlate400, fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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

  // ==========================================
  // SPECIFIC FUND VERIFICATION DIALOG
  // ==========================================
  void _showFundManualEntryDialog(BuildContext context) {
    final TextEditingController idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: kEmerald.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.banknote, color: kEmerald, size: 32),
                ),
                const SizedBox(height: 16),
                Text("Verify Funds", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 8),
                const Text("Type the donor's monetary receipt ID exactly as it appears.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 24),
                TextField(
                  controller: idController,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "e.g. KC-12345",
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kEmerald, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final enteredId = idController.text.trim();
                      if (enteredId.isNotEmpty) {
                        Navigator.pop(context);
                        _verifyFundReceiptId(enteredId); // CALL THE MONEY LOGIC
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kEmerald, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text("Confirm Disbursement", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // AI TAB: FINAL FUND CONFIRMATION DIALOG
  // ==========================================
  void _showFundActionDialog(DocumentReference docRef, Map<String, dynamic> data) {
    List<dynamic> milestones = List.from(data['milestones'] ?? []);

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool isProcessing = false;
          return StatefulBuilder(
              builder: (context, setState) {
                return Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.white,
                    child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: kEmerald.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(LucideIcons.banknote, color: kEmerald, size: 40),
                              ),
                              const SizedBox(height: 16),
                              Text("Log Fund Disbursement", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: const Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              Text("RM ${(data['amount'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: kEmerald)),
                              Text("Target: ${data['target']}", style: const TextStyle(color: Colors.grey)),
                              const Divider(height: 32),
                              const Text("Confirm that this monetary donation is officially being distributed to the beneficiaries.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.5)),
                              const SizedBox(height: 24),
                              SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                      icon: const Icon(LucideIcons.checkCircle),
                                      label: const Text("Confirm Disbursement", style: TextStyle(fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: kEmerald,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                      ),
                                      onPressed: isProcessing ? null : () async {
                                        setState(() => isProcessing = true);
                                        try {
                                          String todayDate = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
                                          for (var m in milestones) {
                                            if (m['label'] == 'Distributed') {
                                              m['done'] = true;
                                              m['date'] = todayDate;
                                            }
                                          }
                                          await docRef.update({
                                            'milestones': milestones,
                                            'status': 'Funds Distributed'
                                          });

                                          // Give Donor Impact Points!
                                          await creditImpactIfMilestonesComplete(docRef);

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text("Success! Funds distributed to beneficiaries."),
                                                  backgroundColor: kEmerald,
                                                  behavior: SnackBarBehavior.floating,
                                                )
                                            );
                                          }
                                        } catch (e) {
                                          setState(() => isProcessing = false);
                                          _showErrorSnackBar("Error: $e");
                                        }
                                      }
                                  )
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                              )
                            ]
                        )
                    )
                );
              }
          );
        }
    );
  }

  Future<void> _verifyFundReceiptId(String receiptId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: kEmerald)),
    );

    try {
      var querySnapshot = await FirebaseFirestore.instance.collectionGroup('donations').where('id', isEqualTo: receiptId).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        Navigator.pop(context);
        _showErrorSnackBar("Receipt ID not found in the system.");
        return;
      }

      final docReference = querySnapshot.docs.first;
      final data = docReference.data();

      // BLOCK ITEMS FROM ENTERING THE MONEY SCANNER
      if (data['type'] != 'money') {
        Navigator.pop(context);
        _showErrorSnackBar("This receipt is for a physical item. Please use the Item Verification tool instead.");
        return;
      }

      bool isAlreadyDistributed = false;
      List<dynamic> milestones = List.from(data['milestones'] ?? []);

      for (var m in milestones) {
        if (m['label'] == 'Distributed' && m['done'] == true) isAlreadyDistributed = true;
      }

      Navigator.pop(context); // Close Loading

      if (isAlreadyDistributed) {
        _showErrorSnackBar("Action Denied: These funds have already been marked as distributed.");
        return;
      }

      // SHOW CONFIRMATION DIALOG (Calling the method we added in the previous steps)
      _showFundActionDialog(docReference.reference, data);

    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar("Error: ${e.toString()}");
    }
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

                  final allDocs = snapshot.data?.docs ?? [];

                  // ========================================================
                  // THE FIX: FILTER DONATIONS WHERE ALL MILESTONES ARE TRUE
                  // ========================================================
                  final completedDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    List<dynamic> milestones = data['milestones'] ?? [];

                    // If there are no milestones, don't count it as complete
                    if (milestones.isEmpty) return false;

                    // Ensure every single milestone is marked as done: true
                    for (var m in milestones) {
                      if (m['done'] != true) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  double totalCash = 0;
                  int totalItems = 0;

                  // ONLY loop through the completed/verified documents
                  for (var doc in completedDocs) {
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
                                    "RM ${NumberFormat.compact().format(totalCash)}",
                                    kEmerald
                                )
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildStatCard(
                                    "Physical Items",
                                    NumberFormat.compact().format(totalItems),
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
                              // ONLY show empty state if there are no COMPLETED donations
                              if (completedDocs.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                        "No completed contributions found yet.\n(Ongoing deliveries are shown on your Dashboard)",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: kSlate400, height: 1.5)
                                    ),
                                  ),
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
                                    // Use completedDocs instead of docs here
                                    rows: completedDocs.map((doc) {
                                      final donationData = doc.data() as Map<String, dynamic>;

                                      // 1. FETCH EXACT CATEGORY FROM THE DONATION RECORD
                                      String matchedCategory = donationData['category']?.toString() ?? "";

                                      // 2. SMART FALLBACK FOR OLD DATA
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
      DataCell(
        SizedBox(
          width: 140,
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
          width: 100,
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
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/KitaCare_Certificate_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(filePath);

      await file.writeAsBytes(await pdf.save());
      final result = await OpenFilex.open(filePath);

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
// ==========================================
// GLOBAL IMPACT CREDITING LOGIC
// ==========================================
Future<void> creditImpactIfMilestonesComplete(DocumentReference donationRef) async {
  try {
    final doc = await donationRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;

    // 1. Prevent double crediting
    if (data['isCredited'] == true) return;

    // 2. Check if ALL milestones are completed
    List<dynamic> milestones = data['milestones'] ?? [];
    if (milestones.isEmpty) return;

    bool allDone = true;
    for (var m in milestones) {
      if (m['done'] != true) {
        allDone = false;
        break;
      }
    }

    // 3. If everything is checked off, calculate and apply impact
    if (allDone) {
      double addedImpact = 0.0;
      int addedLives = 0;

      // Professional Calculation based on Contribution Type
      if (data['type'] == 'money') {
        double amount = (data['amount'] as num? ?? 0.0).toDouble();
        addedImpact = amount;
        addedLives = (amount / 10).floor(); // E.g. RM 10 = 1 life touched
        if (addedLives < 1 && amount > 0) addedLives = 1;
      } else if (data['type'] == 'item') {
        int qty = (data['quantity'] as num? ?? 1).toInt();
        addedImpact = qty * 50.0; // Estimated RM 50 impact value per physical item
        addedLives = qty * 2;     // Estimated 2 lives helped per physical item
      }

      // Safely extract the donor's UID from the document path
      String uid = donationRef.parent.parent!.id;

      // Run a transaction to ensure exact sync
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final freshDoc = await transaction.get(donationRef);

        // --- FIXED LINE HERE ---
        final freshData = freshDoc.data() as Map<String, dynamic>?;
        if (freshData?['isCredited'] == true) return;

        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

        transaction.update(userRef, {
          'impactValue': FieldValue.increment(addedImpact),
          'livesTouched': FieldValue.increment(addedLives),
        });

        transaction.update(donationRef, {
          'isCredited': true,
        });
      });
    }
  } catch (e) {
    debugPrint("Error crediting impact: $e");
  }
}

// ==========================================
// NEW TAB: LOGISTICS DASHBOARD (FULL PAGE)
// ==========================================
class LogisticsDashboard extends StatelessWidget {
  const LogisticsDashboard({super.key});

  // 1. THE LOGIC: CALCULATING REAL DATA FROM FIRESTORE
  Future<Map<String, dynamic>> _fetchRealLogisticsData() async {
    var snapshot = await FirebaseFirestore.instance.collectionGroup('donations').get();

    if (snapshot.docs.isEmpty) {
      return {
        "score": 100.0,
        "active": 0,
        "avg": 0.0,
        "bars": <double>[0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
      };
    }

    int totalItems = 0;
    int activeDrops = 0;

    // --- NEW VARIABLES FOR SCORE ---
    int completedDeliveries = 0;
    int deliveriesWithPhoto = 0;

    double totalDays = 0;
    int completedCount = 0;

    List<int> dailyCounts = List.filled(7, 0);
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);

    for (var doc in snapshot.docs) {
      var d = doc.data() as Map<String, dynamic>;

      if (d['type'] == 'item') {
        totalItems++;

        // --- 1. UPDATED TRANSPARENCY SCORE LOGIC ---
        // Only evaluate transparency if the item has arrived at the NGO/Distributed
        if (d['status'] == 'Drop-off Verified' || d['status'] == 'Inventory at Hub' || d['status'] == 'Distributed') {
          completedDeliveries++;

          // Check specifically if the courier took the time to upload a photo
          if (d.containsKey('proofOfDeliveryUrl') && d['proofOfDeliveryUrl'] != null) {
            deliveriesWithPhoto++;
          }
        }

        // --- 2. ACTIVE DROPS ---
        if (d['status'] != 'Distributed') {
          activeDrops++;
        }

        // --- 3. CHART DATA (Past 7 Days Volume) ---
        if (d['timestamp'] != null) {
          DateTime pledgeDate = (d['timestamp'] as Timestamp).toDate();
          DateTime startOfPledgeDate = DateTime(pledgeDate.year, pledgeDate.month, pledgeDate.day);

          int daysAgo = startOfToday.difference(startOfPledgeDate).inDays;

          // If it happened within the last 7 days (0 = today, 6 = 6 days ago)
          if (daysAgo >= 0 && daysAgo < 7) {
            // Reverse the index so the oldest day is on the left (index 0) and today is on the right (index 6)
            dailyCounts[6 - daysAgo]++;
          }

          // --- 4. AVERAGE DISPATCH TIME ---
          if (d['status'] == 'Distributed') {
            DateTime? distributedDate;
            List<dynamic> milestones = d['milestones'] ?? [];

            // Find the exact date it was marked as Distributed
            for (var m in milestones) {
              if (m['label'] == 'Distributed' && m['done'] == true && m['date'] != null) {
                try {
                  distributedDate = DateFormat('dd MMM yyyy, h:mm a').parse(m['date'].toString());
                } catch (e) {
                  distributedDate = DateTime.now(); // Fallback if parsing fails
                }
              }
            }

            if (distributedDate != null) {
              double daysTaken = distributedDate.difference(pledgeDate).inHours / 24.0;
              // Prevent negative times if dates are weird
              if (daysTaken >= 0) {
                totalDays += daysTaken;
                completedCount++;
              }
            }
          }
        }
      }
    }

    // --- 5. NORMALIZE CHART BARS FOR UI ---
    // The UI chart expects values between 0.1 and 1.0
    int maxCount = 0;
    for (int count in dailyCounts) {
      if (count > maxCount) maxCount = count;
    }

    List<double> normalizedBars = [];
    for (int count in dailyCounts) {
      if (maxCount == 0) {
        normalizedBars.add(0.1); // Minimum bar height if no data
      } else {
        double val = count / maxCount;
        normalizedBars.add(val < 0.1 ? 0.1 : val); // Ensure bar is at least a bit visible
      }
    }

    double finalScore = 100.0; // Default
    if (completedDeliveries > 0) {
      // e.g. 8 photos out of 10 deliveries = 80% Transparency
      finalScore = (deliveriesWithPhoto / completedDeliveries) * 100.0;
    } else if (totalItems > 0 && completedDeliveries == 0) {
      finalScore = 0.0; // Deliveries are happening, but none finished yet
    }

    return {
      "score": finalScore,
      "active": activeDrops,
      "avg": completedCount > 0 ? (totalDays / completedCount) : 0.0,
      "bars": normalizedBars
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC), // Light grey background to match the app
      child: FutureBuilder<Map<String, dynamic>>(
        future: _fetchRealLogisticsData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: kBlue));
          }
          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                    "Mission Operational Data",
                    style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: kSlate800)
                ),
                const Text(
                    "Tracking logistics speed, fund health, and physical inventory.",
                    style: TextStyle(color: kSlate500, fontSize: 14)
                ),
                const SizedBox(height: 32),

                // Cards Layout (Responsive Wrap)
                Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    // Left Column: Chart Card
                    SizedBox(
                      width: MediaQuery.of(context).size.width > 800 ? MediaQuery.of(context).size.width * 0.55 : double.infinity,
                      child: _analyticCard(
                        "LORRY DISPATCH RATE (LAST 7 DAYS)",
                        Column(children: [
                          _buildMiniChart(data['bars'] as List<double>),
                          const SizedBox(height: 16),
                          Text(
                              data['avg'] == 0.0
                                  ? "No completed deliveries yet"
                                  : "Avg. delivery: ${data['avg'].toStringAsFixed(1)} Days",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: kBlue)
                          )
                        ]),
                      ),
                    ),

                    // Right Column: Active Drops & Score Cards
                    SizedBox(
                      width: MediaQuery.of(context).size.width > 800 ? MediaQuery.of(context).size.width * 0.35 : double.infinity,
                      child: Column(
                        children: [
                          _analyticCard(
                            "INCOMING PHYSICAL GOODS",
                            Column(children: [
                              const Icon(LucideIcons.truck, color: kBlue, size: 32),
                              const SizedBox(height: 12),
                              Text("${data['active']} Active Drops",
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: kSlate800)),
                            ]),
                          ),
                          const SizedBox(height: 24),
                          _analyticCard(
                            "TRANSPARENCY SCORE",
                            Center(
                              child: Column(children: [
                                Text("${data['score'].toStringAsFixed(1)}%",
                                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: kBlue)),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // UI Helper for Logistics Cards
  Widget _analyticCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kSlate400, letterSpacing: 1.1)),
          const SizedBox(height: 20),
          child
        ],
      ),
    );
  }

  // UI Helper for Logistics Chart
  Widget _buildMiniChart(List<double> bars) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: bars.map((v) => Container(
        width: 25,
        height: 120 * v, // Scales dynamically based on the max value of the week
        decoration: BoxDecoration(
          color: kBlue.withOpacity(v == 1.0 ? 0.5 : 0.2), // The highest day will be darker blue
          borderRadius: BorderRadius.circular(4),
        ),
      )).toList(),
    );
  }
}