import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';
import '../dashboard/donor_dashboard.dart';
import '../dashboard/ngo_dashboard.dart';
import '../map/needs_map_screen.dart';
import '../advisor/ai_advisor_screen.dart';
import '../analytics/donor_analytics.dart';
import '../analytics/ngo_analytics.dart';
import 'donation_modal.dart';

// ============================================================
// APP SHELL
// Wraps authenticated screens with a collapsible sidebar nav.
// Uses a persistent Scaffold with Drawer for narrow screens,
// and a permanent side panel for wide (desktop/tablet) layouts.
// ============================================================

class AppShell extends StatefulWidget {
  final UserRole role;
  final VoidCallback onLogout;

  const AppShell({super.key, required this.role, required this.onLogout});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  _NavTab _activeTab = _NavTab.dashboard;
  HumanitarianNeed? _pendingDonation;

  // [BACKEND]: Replace with user profile service
  final List<PaymentMethod> _savedMethods = [
    const PaymentMethod(id: '1', bank: 'Maybank', account: '1140-XXXX-5521'),
  ];
  final BankInfo _ngoBank = const BankInfo(
    name: 'Maybank',
    account: '5140-XXXX-2241',
    holder: 'MERCY Malaysia Relief Fund',
  );

  Color get _accent =>
      widget.role == UserRole.ngo ? AppColors.blue600 : AppColors.emerald600;

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.slate50,
          drawer: isWide ? null : _buildDrawer(),
          body: Stack(
            children: [
              isWide ? _buildWideLayout() : _buildNarrowLayout(),
              if (_pendingDonation != null)
                _buildDonationOverlay(_pendingDonation!),
            ],
          ),
        );
      },
    );
  }

  // ── Wide layout: permanent sidebar + content ───────────────

  Widget _buildWideLayout() {
    return Row(
      children: [
        SizedBox(width: 240, child: _buildSidebar(permanent: true)),
        const VerticalDivider(width: 1, color: AppColors.slate200),
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ── Narrow layout: hamburger top bar + content ─────────────

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _NarrowTopBar(
          role: widget.role,
          accent: _accent,
          onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: _buildSidebar(permanent: false),
    );
  }

  // ── Shared sidebar ─────────────────────────────────────────

  Widget _buildSidebar({required bool permanent}) {
    return SafeArea(
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _accent, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800),
                    children: [
                      const TextSpan(text: 'KitaCare '),
                      TextSpan(
                          text: 'AI', style: TextStyle(color: _accent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: _navItems.map((item) => _NavItem(
                  icon: item.icon,
                  label: item.label,
                  selected: _activeTab == item.tab,
                  accent: _accent,
                  onTap: () {
                    setState(() => _activeTab = item.tab);
                    if (!permanent) Navigator.pop(context);
                  },
                )).toList(),
              ),
            ),
          ),
          // User footer
          const Divider(color: AppColors.slate100, height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.slate100,
                      child: Text(
                        widget.role == UserRole.donor ? 'D' : 'N',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.role == UserRole.donor ? 'Ahmad S.' : 'MERCY MY',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate700),
                          ),
                          Text(
                            widget.role.name.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, size: 16, color: AppColors.red600),
                    label: const Text('Logout',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.red600)),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Content area ───────────────────────────────────────────

  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _screenForTab(_activeTab),
    );
  }

  Widget _screenForTab(_NavTab tab) {
    final donations = kInitialDonations.map(Donation.fromMap).toList();

    if (tab == _NavTab.dashboard) {
      return widget.role == UserRole.donor
          ? DonorDashboard(
              key: const ValueKey('donor-dash'),
              donations: donations,
              savedMethods: _savedMethods,
              onAddMethod: (m) => setState(() => _savedMethods.add(m)),
              onDeleteMethod: (id) =>
                  setState(() => _savedMethods.removeWhere((m) => m.id == id)),
            )
          : NgoDashboard(
              key: const ValueKey('ngo-dash'),
              ngoBank: _ngoBank,
            );
    }
    if (tab == _NavTab.map) {
      return NeedsMapScreen(
        key: const ValueKey('map'),
        role: widget.role,
        onDonate: (need) => setState(() => _pendingDonation = need),
      );
    }
    if (tab == _NavTab.advisor) {
      return AiAdvisorScreen(
        key: ValueKey('advisor-${widget.role}'),
        role: widget.role,
      );
    }
    // analytics
    return widget.role == UserRole.ngo
        ? const NgoAnalyticsScreen(key: ValueKey('ngo-analytics'))
        : DonorAnalyticsScreen(
            key: const ValueKey('donor-analytics'),
            donations: donations,
          );
  }

  // ── Donation overlay ───────────────────────────────────────

  Widget _buildDonationOverlay(HumanitarianNeed need) {
    return GestureDetector(
      onTap: () => setState(() => _pendingDonation = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: DonationModal(
              need: need,
              role: widget.role,
              onComplete: () {
                setState(() => _pendingDonation = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contribution Successful! Thank you for your kindness.'),
                    backgroundColor: AppColors.emerald600,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Nav item definitions ───────────────────────────────────

  List<_NavItemData> get _navItems => [
    _NavItemData(
      tab: _NavTab.dashboard,
      icon: Icons.dashboard_outlined,
      label: widget.role == UserRole.ngo ? 'Mission Hub' : 'Dashboard',
    ),
    _NavItemData(tab: _NavTab.map, icon: Icons.map_outlined, label: 'Relief Map'),
    _NavItemData(tab: _NavTab.advisor, icon: Icons.chat_bubble_outline, label: 'AI Advisor'),
    _NavItemData(
      tab: _NavTab.analytics,
      icon: Icons.bar_chart_rounded,
      label: widget.role == UserRole.ngo ? 'Logistics Data' : 'My Impact',
    ),
  ];
}

enum _NavTab { dashboard, map, advisor, analytics }

class _NavItemData {
  final _NavTab tab;
  final IconData icon;
  final String label;
  const _NavItemData({required this.tab, required this.icon, required this.label});
}

// ── Nav item widget ────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? accent : AppColors.slate400, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selected ? accent : AppColors.slate400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Narrow top bar ─────────────────────────────────────────

class _NarrowTopBar extends StatelessWidget {
  final UserRole role;
  final Color accent;
  final VoidCallback onMenuTap;

  const _NarrowTopBar({
    required this.role,
    required this.accent,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 4)],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.slate700),
              onPressed: onMenuTap,
            ),
            const SizedBox(width: 8),
            Text('KitaCare AI',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.slate800)),
          ],
        ),
      ),
    );
  }
}