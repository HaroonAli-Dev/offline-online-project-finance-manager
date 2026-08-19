import 'package:flutter/material.dart';

import '../../people/domain/person_summary.dart';
import '../../schemes/domain/scheme_model.dart';
import '../../sites/domain/site_model.dart';
import '../domain/transaction_model.dart';

class TransactionInput {
  const TransactionInput({
    required this.transactionCode,
    required this.transactionDate,
    required this.type,
    this.personId,
    required this.amount,
    this.quantity,
    required this.purpose,
    required this.paymentMethod,
    this.referenceNumber,
    this.remarks,
    this.schemeId,
    this.siteId,
  });

  final String transactionCode;
  final DateTime transactionDate;
  final String type;
  final String? personId;
  final double amount;
  final double? quantity;
  final String purpose;
  final String paymentMethod;
  final String? referenceNumber;
  final String? remarks;
  final String? schemeId;
  final String? siteId;
}

class TransactionFormDialog extends StatefulWidget {
  const TransactionFormDialog({
    this.transaction,
    required this.people,
    required this.schemes,
    required this.sites,
    super.key,
  });

  final TransactionModel? transaction;
  final List<PersonSummary> people;
  final List<SchemeModel> schemes;
  final List<SiteModel> sites;

  @override
  State<TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _amountController;
  late final TextEditingController _quantityController;
  late final TextEditingController _purposeController;
  late final TextEditingController _referenceController;
  late final TextEditingController _remarksController;

  late DateTime _txnDate;
  late String _type; // 'received' or 'paid'
  late String _paymentMethod;
  String? _selectedPersonId;
  String? _selectedSchemeId;
  String? _selectedSiteId;

  @override
  void initState() {
    super.initState();
    final txn = widget.transaction;
    _codeController = TextEditingController(text: txn?.transactionCode ?? '');
    _amountController = TextEditingController(
      text: txn?.amount != null ? txn!.amount.toStringAsFixed(2) : '',
    );
    _quantityController = TextEditingController(
      text: txn?.quantity != null ? txn!.quantity.toString() : '',
    );
    _purposeController = TextEditingController(text: txn?.purpose ?? '');
    _referenceController = TextEditingController(
      text: txn?.referenceNumber ?? '',
    );
    _remarksController = TextEditingController(text: txn?.remarks ?? '');

    _txnDate = txn?.transactionDate ?? DateTime.now();
    _type = txn?.type ?? 'received';
    _paymentMethod = txn?.paymentMethod ?? 'cash';
    _selectedPersonId = txn?.personId;
    _selectedSchemeId = txn?.schemeId;
    _selectedSiteId = txn?.siteId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    _quantityController.dispose();
    _purposeController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.transaction == null ? 'Add Transaction' : 'Edit Transaction',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'received',
                      label: Text('Money Received'),
                      icon: Icon(Icons.arrow_downward, color: Colors.green),
                    ),
                    ButtonSegment(
                      value: 'paid',
                      label: Text('Money Paid'),
                      icon: Icon(Icons.arrow_upward, color: Colors.red),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (val) {
                    if (val.isNotEmpty) setState(() => _type = val.first);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Txn Code *',
                          hintText: 'TXN-001',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter code'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Date: ${_formatDate(_txnDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _txnDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _txnDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (Rs.) *',
                          hintText: '1000.00',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter amount.';
                          }
                          final num = double.tryParse(val.trim());
                          if (num == null || num <= 0) {
                            return 'Enter positive amount.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantity (Optional)',
                          hintText: 'e.g. 50 bags',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purposeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Purpose / Details *',
                    hintText: 'e.g. Cement Purchase / Vendor Payment',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter transaction purpose.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentMethod = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number',
                    hintText: 'Cheque No / Transaction Ref',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedPersonId,
                  decoration: const InputDecoration(
                    labelText: 'Person / Vendor / Bank',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None / Unassigned'),
                    ),
                    ...widget.people.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.fullName),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedPersonId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedSchemeId,
                  decoration: const InputDecoration(
                    labelText: 'Related Scheme',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None / Unassigned'),
                    ),
                    ...widget.schemes.map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.schemeCode} - ${s.name}'),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedSchemeId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedSiteId,
                  decoration: const InputDecoration(labelText: 'Related Site'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None / Unassigned'),
                    ),
                    ...widget.sites.map(
                      (site) => DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedSiteId = val),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = double.parse(_amountController.text.trim());
    final quantity = double.tryParse(_quantityController.text.trim());

    Navigator.pop(
      context,
      TransactionInput(
        transactionCode: _codeController.text,
        transactionDate: _txnDate,
        type: _type,
        personId: _selectedPersonId,
        amount: amount,
        quantity: quantity,
        purpose: _purposeController.text,
        paymentMethod: _paymentMethod,
        referenceNumber: _referenceController.text,
        remarks: _remarksController.text,
        schemeId: _selectedSchemeId,
        siteId: _selectedSiteId,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
