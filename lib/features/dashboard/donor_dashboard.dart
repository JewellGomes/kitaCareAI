import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';

// ============================================================
// DONOR DASHBOARD
// Shows active donation tracking, milestones, and wallet.
// ============================================================

class DonorDashboard extends StatelessWidget {
  final List<Donation> donations;
  final List<PaymentMethod> savedMethods;
  final void Function(PaymentMethod) onAddMethod;
  final void Function(String id) onDeleteMethod;

  const DonorDashboard({
    super.key,
    required this.donations,
    required this.savedMethods,
    required this.onAddMethod,
    required this.onDeleteMethod,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildTracking()),
                    const SizedBox(width: 32),
                    SizedBox(width: 300, child: _buildSidebar()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildTracking(),
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

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Hello, Ahmad',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
            SizedBox(height: 4),
            Text('Empowering Malaysian communities through KitaCare AI.',
                style: TextStyle(color: AppColors.slate500, fontSize: 13)),
          ],
        ),
        Wrap(
          spacing: 12,
          children: const [
            _StatChip(label: 'Impact Value', value: 'RM 400.00', color: AppColors.emerald600),
            _StatChip(label: 'Lives Touched', value: '~120', color: AppColors.blue600),
          ],
        ),
      ],
    );
  }

  // ── Active tracking ─────────────────────────────────────────

  Widget _buildTracking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.history, color: AppColors.emerald600, size: 20),
            SizedBox(width: 8),
            Text('Active Tracking',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800)),
          ],
        ),
        const SizedBox(height: 16),
        ...donations.map((d) => _DonationCard(donation: d)),
      ],
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────

  Widget _buildSidebar() {
    return _WalletCard(savedMethods: savedMethods, onDelete: onDeleteMethod);
  }
}

// ── Donation Card ──────────────────────────────────────────

class _DonationCard extends StatelessWidget {
  final Donation donation;

  const _DonationCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final isMoney = donation.type == 'money';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFAF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMoney ? AppColors.emerald100 : AppColors.blue100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isMoney ? Icons.payments_outlined : Icons.inventory_2_outlined,
                    color: isMoney ? AppColors.emerald600 : AppColors.blue600,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(donation.id,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.slate400,
                              letterSpacing: 1)),
                      Text(donation.target,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: AppColors.slate800)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(donation.status,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald600)),
                ),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Milestones or item summary
                Expanded(
                  child: isMoney
                      ? _MilestoneList(milestones: donation.milestones)
                      : _ItemSummary(donation: donation),
                ),
                const SizedBox(width: 16),
                // Evidence photo
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    donation.evidence,
                    width: 120,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      height: 100,
                      color: AppColors.slate100,
                      child: const Icon(Icons.image_outlined, color: AppColors.slate400),
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
}

class _MilestoneList extends StatelessWidget {
  final List<DonationMilestone> milestones;

  const _MilestoneList({required this.milestones});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(milestones.length, (i) {
        final m = milestones[i];
        final isLast = i == milestones.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: m.done ? AppColors.emerald600 : AppColors.slate200, width: 2),
                      color: Colors.white,
                    ),
                    child: m.done
                        ? const Icon(Icons.check, size: 10, color: AppColors.emerald600)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: m.done ? AppColors.emerald600 : AppColors.slate100,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: m.done ? AppColors.slate800 : AppColors.slate400)),
                      Text(m.date,
                          style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ItemSummary extends StatelessWidget {
  final Donation donation;

  const _ItemSummary({required this.donation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Item Summary',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate400,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(donation.itemDetails ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate800)),
          const SizedBox(height: 4),
          Text('Verified by ${donation.ngo}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.slate500, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

// ── Wallet Card ────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final List<PaymentMethod> savedMethods;
  final void Function(String) onDelete;

  const _WalletCard({required this.savedMethods, required this.onDelete});

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
          Row(
            children: const [
              Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.emerald600, size: 20),
              SizedBox(width: 8),
              Text('KitaCare Wallet',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.slate800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          ...savedMethods.map((m) => _WalletMethodRow(method: m, onDelete: () => onDelete(m.id))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.emerald100),
            ),
            child: Row(
              children: const [
                Icon(Icons.lock_outline, color: AppColors.emerald600, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Secured by Malaysian Banking AI Standards.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF065F46))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletMethodRow extends StatelessWidget {
  final PaymentMethod method;
  final VoidCallback onDelete;

  const _WalletMethodRow({required this.method, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.slate400, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(method.bank,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: AppColors.slate400,
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Shared stat chip ────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1)),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}