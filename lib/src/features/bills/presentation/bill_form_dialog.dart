import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../schemes/domain/scheme_model.dart';
import '../domain/bill_model.dart';

/// Data returned from the bill form on a successful submission.
class BillInput {
  const BillInput({
    required this.schemeId,
    required this.billType,
    this.billNumber,
    required this.billDate,
    required this.amount,
    required this.status,
    this.remarks,
  });

  final String schemeId;
  final String billType;
  final String? billNumber;
  final DateTime billDate;
  final double amount;
  final String status;
  final String? remarks;
}

class BillFormDialog extends StatefulWidget {
  const BillFormDialog({
    this.bill,
    required this.schemes,
    this.preselectedSchemeId,
    super.key,
  });

  final BillModel? bill;
  final List<SchemeModel> schemes;

  /// When opened from a Scheme's detail view, pre-select that scheme.
  final String? preselectedSchemeId;

  @override
  State<BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends State<BillFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _billNumberController;
  late final TextEditingController _amountController;
  late final TextEditingController _remarksController;

  String? _selectedSchemeId;
  late String _selectedBillType;
  late DateTime _billDate;
  late String _selectedStatus;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;

    _selectedSchemeId = bill?.schemeId ?? widget.preselectedSchemeId;
    _selectedBillType = bill?.billType ?? 'initial';
    _billDate = bill?.billDate ?? DateTime.now();
    _selectedStatus = bill?.status ?? 'draft';

    _billNumberController = TextEditingController(text: bill?.billNumber ?? '');
    _amountController = TextEditingController(
      text: bill?.amount != null ? bill!.amount.toStringAsFixed(2) : '',
    );
    _remarksController = TextEditingController(text: bill?.remarks ?? '');
  }

  @override
  void dispose() {
    _billNumberController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSchemeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a scheme.')));
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    Navigator.pop(
      context,
      BillInput(
        schemeId: _selectedSchemeId!,
        billType: _selectedBillType,
        billNumber: _billNumberController.text.trim().isEmpty
            ? null
            : _billNumberController.text.trim(),
        billDate: _billDate,
        amount: amount,
        status: _selectedStatus,
        remarks: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.bill != null;
    final title = isEdit ? 'Edit Bill' : 'Add Bill';

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Scheme ---
              DropdownButtonFormField<String>(
                initialValue: _selectedSchemeId,
                decoration: const InputDecoration(
                  labelText: 'Scheme *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment_outlined),
                ),
                items: widget.schemes.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.schemeCode} — ${s.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSchemeId = val),
                validator: (val) => val == null ? 'Select a scheme' : null,
              ),
              const SizedBox(height: 16),

              // --- Bill Type ---
              DropdownButtonFormField<String>(
                initialValue: _selectedBillType,
                decoration: const InputDecoration(
                  labelText: 'Bill Type *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                items: kBillTypes.map((entry) {
                  final (code, label) = entry;
                  return DropdownMenuItem(value: code, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBillType = val);
                },
                validator: (val) =>
                    val == null || val.isEmpty ? 'Select bill type' : null,
              ),
              const SizedBox(height: 16),

              // --- Bill Number (optional) ---
              TextFormField(
                controller: _billNumberController,
                decoration: const InputDecoration(
                  labelText: 'Bill Reference Number',
                  hintText: 'e.g. Bill No. 3/2026',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tag),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // --- Date ---
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Bill Date *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    '${_billDate.day.toString().padLeft(2, '0')}/'
                    '${_billDate.month.toString().padLeft(2, '0')}/'
                    '${_billDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- Amount ---
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs.) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Enter an amount';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed < 0) return 'Amount must be 0 or more';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // --- Status ---
              DropdownButtonFormField<String>(
                initialValue: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: kBillStatuses.map((entry) {
                  final (code, label) = entry;
                  return DropdownMenuItem(value: code, child: Text(label));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStatus = val);
                },
                validator: (val) =>
                    val == null || val.isEmpty ? 'Select a status' : null,
              ),
              const SizedBox(height: 16),

              // --- Remarks ---
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save Changes' : 'Add Bill'),
        ),
      ],
    );
  }
}
