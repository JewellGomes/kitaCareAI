import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/models.dart';

// ============================================================
// DONOR ANALYTICS SCREEN
// Shows impact summary, philanthropy tier, and donation audit.
// ============================================================

class DonorAnalyticsScreen extends StatelessWidget {
  final List<Donation> donations;

  const DonorAnalyticsScreen({super.key, required this.donations});

  double get _totalRM =>
      donations.where((d) => d.type == 'money').fold(0, (sum, d) => sum + d.amount);

  int get _totalItems => donations.where((d) => d.type == 'item').length;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildStatsRow(context),
          const SizedBox(height: 32),
          _buildAuditTable(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('My Charitable Journey',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
        SizedBox(height: 4),
        Text('Quantifying your impact across the Malaysian community.',
            style: TextStyle(color: AppColors.slate500, fontSize: 13)),
      ],
    );
  }

  // ── Stats grid ─────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(
          label: 'Cash Support',
          value: 'RM ${_totalRM.toStringAsFixed(0)}',
          color: AppColors.emerald600,
        ),
        _StatCard(
          label: 'Physical Items',
          value: '$_totalItems Donated',
          color: AppColors.blue600,
        ),
        _PhilanthropyTierCard(),
      ],
    );
  }

  // ── Audit table ────────────────────────────────────────────

  Widget _buildAuditTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Contribution Audit & Certificates',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.slate800)),
          ),
          const Divider(height: 1, color: AppColors.slate100),
          // Table header
          _tableHeader(),
          const Divider(height: 1, color: AppColors.slate50),
          // Table rows
          ...donations.map((d) => _AuditRow(donation: d)),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    const headers = ['Date', 'Type', 'Cause', 'NGO', 'Impact', 'Action'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: headers.map((h) => Expanded(
          child: Text(h.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate400,
                  letterSpacing: 1)),
        )).toList(),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate400,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

// ── Philanthropy tier card ─────────────────────────────────

class _PhilanthropyTierCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.emerald900,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.emerald900.withValues(alpha: 0.4), blurRadius: 20),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(Icons.emoji_events_rounded,
                size: 100, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PHILANTHROPY TIER',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0x99FFFFFF),
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              const Text('Community Pillar',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('You are in the top 10% of Malaysian supporters this year.',
                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 11)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('GOLD',
                    style: TextStyle(
                        color: AppColors.emerald900,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Audit table row ────────────────────────────────────────

class _AuditRow extends StatelessWidget {
  final Donation donation;

  const _AuditRow({required this.donation});

  @override
  Widget build(BuildContext context) {
    final isMoney = donation.type == 'money';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(donation.date,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMoney ? AppColors.emerald50 : AppColors.blue50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                donation.type.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isMoney ? AppColors.emerald600 : AppColors.blue600),
              ),
            ),
          ),
          Expanded(
            child: Text(donation.target,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          ),
          Expanded(
            child: Text(donation.ngo,
                style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          ),
          Expanded(
            child: Text(
              isMoney ? 'RM ${donation.amount.toStringAsFixed(0)}' : (donation.itemDetails ?? ''),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate500),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating e-Certificate...')),
                );
              },
              icon: const Icon(Icons.download_outlined, size: 12),
              label: const Text('Certificate', style: TextStyle(fontSize: 10)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.slate500,
                backgroundColor: AppColors.slate100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}