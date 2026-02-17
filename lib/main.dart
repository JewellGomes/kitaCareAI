import 'package:flutter/material.dart';
import 'core/models.dart';
import 'features/auth/auth_screen.dart';
import 'features/shared/app_shell.dart';

void main() {
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
      theme: _buildTheme(),
      home: const _RootNavigator(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF059669), // emerald-600
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // slate-50
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}

// ── Root navigator: toggles between auth and app shell ─────

class _RootNavigator extends StatefulWidget {
  const _RootNavigator();

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  UserRole? _loggedInRole;

  @override
  Widget build(BuildContext context) {
    if (_loggedInRole == null) {
      return AuthScreen(
        onLogin: (UserRole role) => setState(() => _loggedInRole = role),
      );
    }

    return AppShell(
      role: _loggedInRole!,
      onLogout: () => setState(() => _loggedInRole = null),
    );
  }
}