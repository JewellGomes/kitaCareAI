import 'package:flutter/material.dart';
import '../../core/constants.dart';

// ============================================================
// FIELD REPORT MODAL
// NGO can publish operational field reports from this modal.
// ============================================================

class FieldReportModal extends StatefulWidget {
  final void Function(Map<String, String> report) onComplete;

  const FieldReportModal({super.key, required this.onComplete});

  @override
  State<FieldReportModal> createState() => _FieldReportModalState();
}

class _FieldReportModalState extends State<FieldReportModal> {
  final _locationController    = TextEditingController();
  final _descriptionController = TextEditingController();
  String _urgency = 'High';
  bool _loading = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // [BACKEND]: API INTERVENTION
    // Replace with POST /api/ngo/field-reports
    // Body: { location, urgency, description, ngoId }
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      widget.onComplete({
        'location':    _locationController.text,
        'urgency':     _urgency,
        'description': _descriptionController.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationField(),
                      const SizedBox(height: 16),
                      _buildUrgencySelector(),
                      const SizedBox(height: 16),
                      _buildDescriptionField(),
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(color: AppColors.slate200, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.blue600,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Field Report',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('OPERATIONAL INTELLIGENCE',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ZONE / AREA NAME',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _locationController,
          validator: (v) => (v == null || v.isEmpty) ? 'Location is required' : null,
          decoration: InputDecoration(
            hintText: 'e.g. Kuala Krai, Kelantan',
            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
            prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.slate400, size: 20),
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.slate200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.slate200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.blue600, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildUrgencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('URGENCY SCORE',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Row(
          children: ['Medium', 'High', 'Critical'].map((level) {
            final selected = _urgency == level;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _urgency = level),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.blue600 : AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected ? AppColors.blue600 : AppColors.slate200),
                    ),
                    child: Text(level,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: selected ? Colors.white : AppColors.slate400)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FIELD SUMMARY',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          validator: (v) => (v == null || v.isEmpty) ? 'Description is required' : null,
          decoration: InputDecoration(
            hintText: 'Describe the current situation, rising water levels, number of families affected...',
            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 12),
            filled: true,
            fillColor: AppColors.slate50,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.slate200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.slate200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.blue600, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _submit,
        icon: _loading
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
        label: const Text('Publish Official Report',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue600,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: AppColors.blue600.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}