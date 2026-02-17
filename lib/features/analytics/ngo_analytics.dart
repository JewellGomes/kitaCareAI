import 'package:flutter/material.dart';
import '../../core/constants.dart';

// ============================================================
// NGO ANALYTICS SCREEN
// Tracks lorry dispatch rate, incoming goods, transparency.
// ============================================================

class NgoAnalyticsScreen extends StatelessWidget {
  const NgoAnalyticsScreen({super.key});

  static const _dispatchData = [30, 60, 45, 80, 55, 90, 70];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _DispatchRateCard(data: _dispatchData),
              _ActiveDropsCard(),
              _TransparencyScoreCard(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('Mission Operational Data',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate800)),
        SizedBox(height: 4),
        Text('Tracking logistics speed, fund health, and physical inventory.',
            style: TextStyle(color: AppColors.slate500, fontSize: 13)),
      ],
    );
  }
}

// ── Dispatch rate bar chart ────────────────────────────────

class _DispatchRateCard extends StatefulWidget {
  final List<int> data;

  const _DispatchRateCard({required this.data});

  @override
  State<_DispatchRateCard> createState() => _DispatchRateCardState();
}

class _DispatchRateCardState extends State<_DispatchRateCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LORRY DISPATCH RATE',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate400,
                  letterSpacing: 1.5)),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: widget.data.map((value) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: FractionallySizedBox(
                            heightFactor: (value / 100) * _animation.value,
                            alignment: Alignment.bottomCenter,
                            child: Container(color: AppColors.blue100),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12, color: AppColors.slate800),
              children: [
                TextSpan(text: 'Avg. delivery: '),
                TextSpan(
                  text: '3.4 Days',
                  style: TextStyle(color: AppColors.blue600, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active drops card ──────────────────────────────────────

class _ActiveDropsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.local_shipping_outlined, color: AppColors.blue600, size: 40),
          SizedBox(height: 12),
          Text('84 Active Drops',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate800)),
          SizedBox(height: 4),
          Text('INCOMING PHYSICAL GOODS',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate400,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

// ── Transparency score card ────────────────────────────────

class _TransparencyScoreCard extends StatefulWidget {
  @override
  State<_TransparencyScoreCard> createState() => _TransparencyScoreCardState();
}

class _TransparencyScoreCardState extends State<_TransparencyScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _countUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _countUp = Tween<double>(begin: 0, end: 98.2)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _countUp,
            builder: (context, _) => Text(
              '${_countUp.value.toStringAsFixed(1)}%',
              style: const TextStyle(
                  fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.blue600),
            ),
          ),
          const SizedBox(height: 8),
          const Text('TRANSPARENCY SCORE',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.slate400,
                  letterSpacing: 1.5)),
        ],
      ),
    );
  }
}