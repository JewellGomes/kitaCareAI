import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';
import '../shared/field_report_modal.dart';
import '../shared/item_request_modal.dart';

// ============================================================
// NGO DASHBOARD
// Verified NGO mission hub: zones, items, funds, QR scanner.
// ============================================================

class NgoDashboard extends StatefulWidget {
  final BankInfo ngoBank;

  const NgoDashboard({super.key, required this.ngoBank});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  bool _isVerified = false;
  _NgoTab _tab = _NgoTab.needs;

  @override
  Widget build(BuildContext context) {
    if (!_isVerified) return _buildPinGate();
    return _buildDashboard();
  }

  // ── PIN gate ───────────────────────────────────────────────

  Widget _buildPinGate() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.slate100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blue50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.fact_check_outlined, color: AppColors.blue600, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('NGO Secure Console',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
            const SizedBox(height: 8),
            const Text('Official MERCY Malaysia Portal. Enter your project PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate500)),
            const SizedBox(height: 24),
            TextField(
              textAlign: TextAlign.center,
              obscureText: true,
              style: const TextStyle(letterSpacing: 12, fontSize: 20),
              decoration: InputDecoration(
                hintText: 'PIN',
                hintStyle: const TextStyle(letterSpacing: 0, color: AppColors.slate400),
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
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // [BACKEND]: API INTERVENTION — Replace with POST /api/ngo/auth/verify-pin
                onPressed: () => setState(() => _isVerified = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue600,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Enter Secure Portal',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main dashboard ─────────────────────────────────────────

  Widget _buildDashboard() {
    final needs = kMockNeeds.map(HumanitarianNeed.fromMap).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildTabBar(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildMain(needs)),
                    const SizedBox(width: 32),
                    SizedBox(width: 300, child: _buildSidebar()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildMain(needs),
                  const SizedBox(height: 24),
                  _buildSidebar(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blue600,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.business, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('MERCY Malaysia',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.blue100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user, color: AppColors.blue600, size: 10),
                        SizedBox(width: 4),
                        Text('Official Partner',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.blue600)),
                      ],
                    ),
                  ),
                ],
              ),
              const Text('PPM-001-10-XXXX • Relief Operational Hub',
                  style: TextStyle(color: AppColors.slate500, fontSize: 12)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _openFieldReport(),
          icon: const Icon(Icons.description_outlined, size: 16, color: Colors.white),
          label: const Text('New Field Report',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue600,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        _TabButton(
          label: 'Operational Areas',
          active: _tab == _NgoTab.needs,
          onTap: () => setState(() => _tab = _NgoTab.needs),
        ),
        _TabButton(
          label: 'Physical Goods Requests',
          active: _tab == _NgoTab.items,
          onTap: () => setState(() => _tab = _NgoTab.items),
        ),
      ],
    );
  }

  Widget _buildMain(List<HumanitarianNeed> needs) {
    return switch (_tab) {
      _NgoTab.needs  => _DisasterZonesTable(needs: needs),
      _NgoTab.items  => _InventoryPanel(
          needs: needs,
          onAddItem: _openItemRequest,
        ),
    };
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        _FundsSummaryCard(bank: widget.ngoBank),
        const SizedBox(height: 16),
        _QrScannerCard(),
      ],
    );
  }

  void _openFieldReport() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FieldReportModal(
        onComplete: (report) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Field Report Published Successfully!')),
          );
        },
      ),
    );
  }

  void _openItemRequest() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemRequestModal(
        onComplete: (item) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item Request Published Successfully!')),
          );
        },
      ),
    );
  }
}

enum _NgoTab { needs, items }

// ── Tab bar button ─────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: active ? AppColors.blue600 : AppColors.slate400,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: active ? 80 : 0,
            color: AppColors.blue600,
          ),
        ],
      ),
    );
  }
}

// ── Disaster zones table ───────────────────────────────────

class _DisasterZonesTable extends StatelessWidget {
  final List<HumanitarianNeed> needs;

  const _DisasterZonesTable({required this.needs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Managed Disaster Zones',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800)),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          ...needs.map((need) => _ZoneRow(need: need)),
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final HumanitarianNeed need;

  const _ZoneRow({required this.need});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate50, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(need.location,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Monitoring',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.blue600)),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: need.score / 100,
                backgroundColor: AppColors.slate100,
                valueColor: const AlwaysStoppedAnimation(AppColors.blue600),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inventory panel ────────────────────────────────────────

class _InventoryPanel extends StatelessWidget {
  final List<HumanitarianNeed> needs;
  final VoidCallback onAddItem;

  const _InventoryPanel({required this.needs, required this.onAddItem});

  @override
  Widget build(BuildContext context) {
    final physicalNeeds = needs.isNotEmpty ? needs.first.physicalNeeds : <String>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inventory Needed',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800)),
                TextButton.icon(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add, size: 14, color: AppColors.blue600),
                  label: const Text('Request New Item',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue600)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.blue50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: physicalNeeds.map((item) => _ItemChip(item: item)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  final String item;

  const _ItemChip({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.blue600, size: 18),
          const SizedBox(width: 10),
          Text(item,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate800)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.red50,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text('Urgent',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.red600)),
          ),
        ],
      ),
    );
  }
}

// ── Funds summary card ─────────────────────────────────────

class _FundsSummaryCard extends StatelessWidget {
  final BankInfo bank;

  const _FundsSummaryCard({required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppColors.blue600, size: 18),
              SizedBox(width: 8),
              Text('Funds Summary',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate800)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blue50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RELIEF ACCOUNT',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue600,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(bank.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
                Text(bank.account,
                    style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.slate200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('View Detailed Statements',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate500)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── QR scanner card ────────────────────────────────────────

class _QrScannerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.blue600,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.blue600.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, color: Colors.white, size: 48, semanticLabel: 'QR Code'),
          const SizedBox(height: 12),
          const Text('Verify Receipt',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Scan donor QR codes at drop-off points to confirm item arrivals.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.blue600,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Open Scanner',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}