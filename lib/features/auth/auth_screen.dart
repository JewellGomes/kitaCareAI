import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';

// ============================================================
// AUTH SCREEN
// Handles role selection, login, and sign-up flows.
// ============================================================

class AuthScreen extends StatefulWidget {
  final void Function(UserRole role) onLogin;

  const AuthScreen({super.key, required this.onLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthView _view = _AuthView.selection;
  UserRole? _selectedRole;

  void _selectRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _view = _AuthView.login;
    });
  }

  void _goBack() {
    setState(() {
      _view = _AuthView.selection;
      _selectedRole = null;
    });
  }

  void _goToSignUp() => setState(() => _view = _AuthView.signup);
  void _goToLogin()  => setState(() => _view = _AuthView.login);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.network(
            'https://images.unsplash.com/photo-1548337138-e87d889cc369?auto=format&fit=crop&q=80&w=2000',
            fit: BoxFit.cover,
          ),
          // Dark overlay
          Container(color: AppColors.slate900.withValues(alpha: 0.6)),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return isWide
                    ? _buildWideLayout()
                    : _buildNarrowLayout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(child: _buildBranding()),
        Expanded(child: Center(child: _buildFormCard())),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildBranding(),
          const SizedBox(height: 32),
          _buildFormCard(),
        ],
      ),
    );
  }

  // ── Left / top branding panel ──────────────────────────────

  Widget _buildBranding() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emerald600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(text: 'KitaCare '),
                    TextSpan(text: 'AI', style: TextStyle(color: AppColors.emerald600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Rakyat Menjaga\nRakyat.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'The Malaysian disaster relief ecosystem powered by AI. '
            'Transparency, real-time logistics, and verified impact.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _BadgeChip(icon: Icons.verified_user, label: 'Verified ROS/SSM NGOs'),
              _BadgeChip(icon: Icons.bolt, label: 'Real-time Relief Map'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Right / bottom form card ───────────────────────────────

  Widget _buildFormCard() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(40),
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildActiveView(),
      ),
    );
  }

  Widget _buildActiveView() {
    if (_view == _AuthView.selection) {
      return _RoleSelectionView(onSelect: _selectRole);
    }
    if (_view == _AuthView.login && _selectedRole != null) {
      return _LoginView(
        role: _selectedRole!,
        onBack: _goBack,
        onSignUp: _goToSignUp,
        onLogin: () => widget.onLogin(_selectedRole!),
      );
    }
    if (_view == _AuthView.signup && _selectedRole != null) {
      return _SignUpView(
        role: _selectedRole!,
        onBack: _goToLogin,
        onComplete: () => widget.onLogin(_selectedRole!),
      );
    }
    return _RoleSelectionView(onSelect: _selectRole);
  }
}

enum _AuthView { selection, login, signup }

// ── Role Selection ─────────────────────────────────────────

class _RoleSelectionView extends StatelessWidget {
  final void Function(UserRole) onSelect;

  const _RoleSelectionView({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selamat Datang',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.slate800),
        ),
        const SizedBox(height: 4),
        const Text('Select your account type to continue',
            style: TextStyle(color: AppColors.slate500)),
        const SizedBox(height: 32),
        _RoleButton(
          role: UserRole.donor,
          title: 'Individual Donor',
          subtitle: 'Track impact of your contributions',
          icon: Icons.person_outline,
          accentColor: AppColors.emerald600,
          accentLight: AppColors.emerald50,
          onTap: () => onSelect(UserRole.donor),
        ),
        const SizedBox(height: 16),
        _RoleButton(
          role: UserRole.ngo,
          title: 'Malaysian NGO',
          subtitle: 'Manage field ops & verified needs',
          icon: Icons.business_outlined,
          accentColor: AppColors.blue600,
          accentLight: AppColors.blue50,
          onTap: () => onSelect(UserRole.ngo),
        ),
      ],
    );
  }
}

class _RoleButton extends StatelessWidget {
  final UserRole role;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color accentLight;
  final VoidCallback onTap;

  const _RoleButton({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.accentLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.slate50,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate200),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Login ──────────────────────────────────────────────────

class _LoginView extends StatelessWidget {
  final UserRole role;
  final VoidCallback onBack;
  final VoidCallback onSignUp;
  final VoidCallback onLogin;

  const _LoginView({
    required this.role,
    required this.onBack,
    required this.onSignUp,
    required this.onLogin,
  });

  Color get _accent => role == UserRole.ngo ? AppColors.blue600 : AppColors.emerald600;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.slate500),
              onPressed: onBack,
            ),
            Text(
              '${role.name.toUpperCase()} Login',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate800),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _AuthTextField(hint: 'Email Address', icon: Icons.email_outlined),
        const SizedBox(height: 12),
        _AuthTextField(hint: 'Password', icon: Icons.lock_outline, obscure: true),
        const SizedBox(height: 24),

        // [BACKEND]: API INTERVENTION
        // Replace with POST /api/auth/login using email/password fields above.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Sign In',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: onSignUp,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(color: AppColors.slate400, fontSize: 13),
                children: [
                  TextSpan(text: "Don't have an account? "),
                  TextSpan(
                    text: 'Create New Account',
                    style: TextStyle(
                      color: AppColors.emerald600,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sign Up ────────────────────────────────────────────────

class _SignUpView extends StatefulWidget {
  final UserRole role;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const _SignUpView({
    required this.role,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  bool _loading = false;

  Color get _accent => widget.role == UserRole.ngo ? AppColors.blue600 : AppColors.emerald600;

  void _submit() async {
    setState(() => _loading = true);

    // [BACKEND]: API INTERVENTION
    // Replace with POST /api/auth/register with form field values.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _loading = false);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.slate500),
                onPressed: widget.onBack,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'New ${widget.role.name} registration',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate500,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Create Account',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          const SizedBox(height: 4),
          const Text('Provide official details to verify your identity.',
              style: TextStyle(color: AppColors.slate500, fontSize: 13)),
          const SizedBox(height: 24),

          _AuthTextField(
            hint: widget.role == UserRole.ngo
                ? 'Official NGO Name (MERCY Malaysia)'
                : 'Full Name as per MyKad',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 12),
          if (widget.role == UserRole.ngo) ...[
            _AuthTextField(
                hint: 'Registration Number (PPM-001-10-XXXX)',
                icon: Icons.verified_user_outlined),
            const SizedBox(height: 12),
          ],
          _AuthTextField(
              hint: 'Identity ID (MyKad XXXXXX-XX-XXXX)', icon: Icons.receipt_outlined),
          const SizedBox(height: 12),
          _AuthTextField(hint: 'Official Email', icon: Icons.email_outlined),
          const SizedBox(height: 12),
          _AuthTextField(hint: 'Secure Password', icon: Icons.lock_outline, obscure: true),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Register Account',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────

class _AuthTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;

  const _AuthTextField({
    required this.hint,
    required this.icon,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slate400, size: 20),
        filled: true,
        fillColor: AppColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.emerald600, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.emerald600, size: 16),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }
}