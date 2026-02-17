import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';

// ============================================================
// NEEDS MAP SCREEN
// AI-correlated relief heatmap with filterable need cards.
// In production, replace the static image with a real map
// widget (e.g. flutter_map + OpenStreetMap, or Google Maps).
// ============================================================

class NeedsMapScreen extends StatefulWidget {
  final void Function(HumanitarianNeed need) onDonate;
  final UserRole role;

  const NeedsMapScreen({
    super.key,
    required this.onDonate,
    required this.role,
  });

  @override
  State<NeedsMapScreen> createState() => _NeedsMapScreenState();
}

class _NeedsMapScreenState extends State<NeedsMapScreen> {
  String _filter = 'All';
  int? _selectedId;

  static const _categories = ['All', 'Flood Relief', 'Food Security', 'Medical Aid'];

  List<HumanitarianNeed> get _needs {
    final all = kMockNeeds.map(HumanitarianNeed.fromMap).toList();
    if (_filter == 'All') return all;
    return all.where((n) => n.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildMapView()),
                    const SizedBox(width: 24),
                    SizedBox(width: 320, child: _buildNeedsList()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildMapView(),
                  const SizedBox(height: 24),
                  _buildNeedsList(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Header + filter chips ──────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Malaysian Relief Heatmap',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
        const SizedBox(height: 4),
        const Text('AI-correlated signal tracking for humanitarian aid.',
            style: TextStyle(color: AppColors.slate500, fontSize: 13)),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) => _FilterChip(
              label: cat,
              selected: _filter == cat,
              onTap: () => setState(() => _filter = cat),
            )).toList(),
          ),
        ),
      ],
    );
  }

  // ── Map view ───────────────────────────────────────────────
  // [BACKEND]: Replace Image.network with a real map widget.
  // Suggested packages: flutter_map, google_maps_flutter.
  // Plot HumanitarianNeed markers using need.coordinates.

  Widget _buildMapView() {
    final needs = _needs;

    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Satellite imagery placeholder
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1548337138-e87d889cc369?auto=format&fit=crop&q=80&w=1200',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppColors.slate200),
              ),
            ),
            // Slight overlay
            Positioned.fill(
              child: Container(color: const Color(0xFF064E3B).withValues(alpha: 0.1)),
            ),
            // Need markers (positioned as fractions of the container)
            ..._buildMarkers(needs),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMarkers(List<HumanitarianNeed> needs) {
    // Hardcoded relative positions mimicking the original React component
    const positions = {
      1: Offset(0.45, 0.25),
      2: Offset(0.35, 0.15),
      3: Offset(0.85, 0.45),
    };

    return needs.map((need) {
      final pos = positions[need.id] ?? const Offset(0.5, 0.5);
      final isSelected = _selectedId == need.id;
      final isUrgent = need.score > 85;

      return Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  left: constraints.maxWidth * pos.dx - 16,
                  top: constraints.maxHeight * pos.dy - 16,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedId = need.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 40 : 32,
                      height: isSelected ? 40 : 32,
                      decoration: BoxDecoration(
                        color: isUrgent ? AppColors.red500 : AppColors.emerald600,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: (isUrgent ? AppColors.red500 : AppColors.emerald600)
                                .withValues(alpha: 0.4),
                            blurRadius: isSelected ? 12 : 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }).toList();
  }

  // ── Needs list ─────────────────────────────────────────────

  Widget _buildNeedsList() {
    final needs = _needs;
    if (needs.isEmpty) {
      return const Center(
        child: Text('No needs found for this category.',
            style: TextStyle(color: AppColors.slate400)),
      );
    }
    return Column(
      children: needs.map((need) => _NeedCard(
        need: need,
        selected: _selectedId == need.id,
        role: widget.role,
        onSelect: () => setState(() => _selectedId = need.id),
        onDonate: () => widget.onDonate(need),
      )).toList(),
    );
  }
}

// ── Filter chip ────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald600 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.emerald600 : AppColors.slate200,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.emerald600.withValues(alpha: 0.3), blurRadius: 8)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppColors.slate500,
          ),
        ),
      ),
    );
  }
}

// ── Need card ──────────────────────────────────────────────

class _NeedCard extends StatelessWidget {
  final HumanitarianNeed need;
  final bool selected;
  final UserRole role;
  final VoidCallback onSelect;
  final VoidCallback onDonate;

  const _NeedCard({
    required this.need,
    required this.selected,
    required this.role,
    required this.onSelect,
    required this.onDonate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.emerald600 : AppColors.slate100,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.emerald600.withValues(alpha: 0.15), blurRadius: 8)]
              : [const BoxShadow(color: Color(0x08000000), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(need.category.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate400,
                        letterSpacing: 1)),
                const Text('VERIFIED',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emerald600,
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 4),
            Text(need.location,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate800)),
            const SizedBox(height: 4),
            Text(need.description,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.slate500, height: 1.4)),
            const SizedBox(height: 12),
            if (role == UserRole.donor)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onDonate,
                  icon: const Icon(Icons.arrow_outward, size: 14, color: Colors.white),
                  label: const Text('Contribute Now',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                    shadowColor: AppColors.emerald600.withValues(alpha: 0.3),
                  ),
                ),
              ),
            if (role == UserRole.ngo)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate100),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user, size: 12, color: AppColors.slate400),
                    const SizedBox(width: 6),
                    Text('Logged by ${need.verifiedBy}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.slate400)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}