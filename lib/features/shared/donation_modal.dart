import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';

// ============================================================
// DONATION MODAL
// Full donation flow: choose money or items, select category,
// AI matching, and confirmed drop-off recommendation.
// ============================================================

class DonationModal extends StatefulWidget {
  final HumanitarianNeed need;
  final UserRole role;
  final VoidCallback onComplete;

  const DonationModal({
    super.key,
    required this.need,
    required this.role,
    required this.onComplete,
  });

  @override
  State<DonationModal> createState() => _DonationModalState();
}

class _DonationModalState extends State<DonationModal> {
  // Flow state
  String? _donateType; // 'money' | 'item'
  int _step = 1;
  bool _loading = false;

  // Money flow
  final _amountController = TextEditingController(text: '50');

  // Item flow
  ItemCategory? _selectedCategory;
  String? _selectedItem;
  AiMatchResult? _aiMatch;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // ── Gemini / AI matching simulation ───────────────────────

  Future<void> _processItemMatch() async {
    setState(() { _loading = true; _step = 3; });

    // [BACKEND]: API INTERVENTION
    // Replace with POST /api/ai/item-match
    //   { "item": selectedItem, "needId": need.id }
    await Future.delayed(const Duration(milliseconds: 1200));

    final randomDrop = DropOffPoint.fromMap(
      kDropOffPoints[Random().nextInt(kDropOffPoints.length)],
    );

    if (mounted) {
      setState(() {
        _aiMatch = AiMatchResult(
          community: widget.need.location,
          ngo: widget.need.verifiedBy,
          priority: widget.need.score > 80 ? 'Critical' : 'Moderate',
          dropOff: randomDrop,
        );
        _loading = false;
        _step = 4;
      });
    }
  }

  Future<void> _processMoneyDonation() async {
    setState(() => _loading = true);

    // [BACKEND]: API INTERVENTION
    // Replace with POST /api/payments/charge
    //   { "amount": amount, "needId": need.id, "bankAccount": need.bank.account }
    // Integrate with Stripe or Billplz for Malaysian ringgit processing.
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() => _loading = false);
      widget.onComplete();
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: AppColors.slate200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: AppColors.emerald600,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contribute to ${widget.need.location}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(widget.need.verifiedBy,
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_donateType == null) return _buildTypeSelection(key: const ValueKey('type'));
    if (_donateType == 'money') return _buildMoneyFlow(key: ValueKey('money-$_step'));
    return _buildItemFlow(key: ValueKey('item-$_step'));
  }

  // ── Type selection ─────────────────────────────────────────

  Widget _buildTypeSelection({Key? key}) {
    return Column(
      key: key,
      children: [
        _DonationTypeButton(
          icon: Icons.payments_outlined,
          title: 'Donate Money',
          subtitle: 'Secured transaction via KitaCare Wallet.',
          color: AppColors.emerald600,
          lightColor: AppColors.emerald100,
          onTap: () => setState(() => _donateType = 'money'),
        ),
        const SizedBox(height: 12),
        _DonationTypeButton(
          icon: Icons.inventory_2_outlined,
          title: 'Donate Items',
          subtitle: 'Contribute physical goods (Books, Food, etc.)',
          color: AppColors.blue600,
          lightColor: AppColors.blue100,
          onTap: () => setState(() => _donateType = 'item'),
        ),
      ],
    );
  }

  // ── Money flow ─────────────────────────────────────────────

  Widget _buildMoneyFlow({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_step == 1) ...[
          // Bank info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TARGET BANK',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate400,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('${widget.need.bank.name} — ${widget.need.bank.account}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate800)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Amount input
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: 'RM ',
              prefixStyle: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate500),
              filled: true,
              fillColor: AppColors.slate50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.emerald600, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Select Wallet',
            icon: Icons.arrow_forward,
            onTap: () => setState(() => _step = 2),
          ),
        ] else ...[
          const Text('CONFIRM SECURE PAYMENT',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Pay RM ${_amountController.text} Secured',
            icon: Icons.lock_outline,
            loading: _loading,
            onTap: _processMoneyDonation,
          ),
        ],
      ],
    );
  }

  // ── Item flow ──────────────────────────────────────────────

  Widget _buildItemFlow({Key? key}) {
    return Column(
      key: key,
      children: [
        if (_step == 1) _buildCategoryGrid(),
        if (_step == 2) _buildItemList(),
        if (_step == 3) _buildAiMatchingLoader(),
        if (_step == 4 && _aiMatch != null) _buildAiMatchResult(),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: kItemCategories.map((cat) => _CategoryCard(
        category: cat,
        onTap: () => setState(() { _selectedCategory = cat; _step = 2; }),
      )).toList(),
    );
  }

  Widget _buildItemList() {
    final cat = _selectedCategory!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT ITEM IN ${cat.name.toUpperCase()}',
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        ...cat.items.map((item) => GestureDetector(
          onTap: () => setState(() => _selectedItem = item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _selectedItem == item ? AppColors.emerald50 : AppColors.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedItem == item ? AppColors.emerald600 : AppColors.slate100,
                width: _selectedItem == item ? 2 : 1,
              ),
            ),
            child: Text(item,
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _selectedItem == item ? AppColors.emerald600 : AppColors.slate600)),
          ),
        )),
        const SizedBox(height: 16),
        _ActionButton(
          label: 'Match with NGO',
          icon: Icons.bolt,
          onTap: _selectedItem != null ? _processItemMatch : null,
        ),
      ],
    );
  }

  Widget _buildAiMatchingLoader() {
    return Column(
      children: const [
        SizedBox(height: 40),
        CircularProgressIndicator(color: AppColors.emerald600),
        SizedBox(height: 16),
        Text('AI is finding local needs...',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
        SizedBox(height: 40),
      ],
    );
  }

  Widget _buildAiMatchResult() {
    final match = _aiMatch!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI match banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.emerald50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emerald100),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.emerald600),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
                    children: [
                      const TextSpan(text: 'AI Match Found! Your '),
                      TextSpan(text: _selectedItem!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: ' is critical for '),
                      TextSpan(text: match.community, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Drop-off recommendation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.slate100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RECOMMENDED DROP-OFF',
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, color: AppColors.blue600, size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.dropOff.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
                      Text(match.dropOff.address,
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('Hours: ${match.dropOff.hours}',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                  const SizedBox(width: 16),
                  Text('Condition: ${match.dropOff.condition}',
                      style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ActionButton(
          label: 'Confirm & Get QR',
          icon: Icons.qr_code_2,
          onTap: widget.onComplete,
        ),
      ],
    );
  }
}

// ── Shared modal widgets ───────────────────────────────────

class _DonationTypeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color lightColor;
  final VoidCallback onTap;

  const _DonationTypeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.slate50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate800)),
                    Text(subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate300),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ItemCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCritical = category.demand == 'Critical';

    return Material(
      color: AppColors.slate50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.slate100),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: AppColors.emerald600, size: 24),
              const SizedBox(height: 4),
              Text(category.name,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCritical ? AppColors.red50 : AppColors.emerald50,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(category.demand,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isCritical ? AppColors.red600 : AppColors.emerald600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, size: 18, color: Colors.white),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald600,
          disabledBackgroundColor: AppColors.slate200,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: AppColors.emerald600.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}