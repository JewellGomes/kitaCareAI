import 'package:flutter/material.dart';
import '../../core/constants.dart';

// ============================================================
// ITEM REQUEST MODAL
// NGOs can request specific physical goods to be posted to
// the donor-facing relief map.
// ============================================================

class ItemRequestModal extends StatefulWidget {
  final void Function(Map<String, String> item) onComplete;

  const ItemRequestModal({super.key, required this.onComplete});

  @override
  State<ItemRequestModal> createState() => _ItemRequestModalState();
}

class _ItemRequestModalState extends State<ItemRequestModal> {
  final _itemController     = TextEditingController();
  final _quantityController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  String _category = '';
  String _urgency  = 'High';
  bool   _loading  = false;

  @override
  void dispose() {
    _itemController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // [BACKEND]: API INTERVENTION
    // Replace with POST /api/ngo/item-requests
    // Body: { category, item, quantity, urgency, ngoId }
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      widget.onComplete({
        'category': _category,
        'item':     _itemController.text,
        'quantity': _quantityController.text,
        'urgency':  _urgency,
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
                      _buildCategoryDropdown(),
                      const SizedBox(height: 16),
                      _buildItemField(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildQuantityField()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildUrgencyDropdown()),
                        ],
                      ),
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
              Text('Request Physical Goods',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('POST TO DONOR MAP',
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

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CATEGORY',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _category.isEmpty ? null : _category,
              hint: const Text('Select Category',
                  style: TextStyle(color: AppColors.slate400, fontSize: 13)),
              items: kItemCategories
                  .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? ''),
            ),
          ),
        ),
        if (_category.isEmpty && _formKey.currentState != null)
          const Padding(
            padding: EdgeInsets.only(top: 4, left: 12),
            child: Text('Category is required',
                style: TextStyle(color: Colors.red, fontSize: 11)),
          ),
      ],
    );
  }

  Widget _buildItemField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SPECIFIC ITEM',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _itemController,
          validator: (v) => (v == null || v.isEmpty) ? 'Item description is required' : null,
          decoration: InputDecoration(
            hintText: 'e.g. 10kg Rice Bags',
            hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
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

  Widget _buildQuantityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('QUANTITY NEEDED',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: AppColors.slate400),
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

  Widget _buildUrgencyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('URGENCY',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.slate400, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.slate200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _urgency,
              items: const [
                DropdownMenuItem(value: 'Critical', child: Text('Critical')),
                DropdownMenuItem(value: 'High',     child: Text('High')),
                DropdownMenuItem(value: 'Medium',   child: Text('Medium')),
              ],
              onChanged: (v) => setState(() => _urgency = v ?? 'High'),
            ),
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
        label: const Text('Publish Item Request',
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