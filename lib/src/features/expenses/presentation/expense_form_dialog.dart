import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../people/domain/person_summary.dart';
import '../../schemes/domain/scheme_model.dart';
import '../../sites/domain/site_model.dart';
import '../domain/expense_model.dart';

class ExpenseInput {
  const ExpenseInput({
    required this.expenseCode,
    required this.expenseDate,
    required this.category,
    required this.amount,
    required this.purpose,
    this.siteId,
    this.schemeId,
    this.personId,
    this.remarks,
    this.attachmentPath,
  });

  final String expenseCode;
  final DateTime expenseDate;
  final String category;
  final double amount;
  final String purpose;
  final String? siteId;
  final String? schemeId;
  final String? personId;
  final String? remarks;
  final String? attachmentPath;
}

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({
    this.expense,
    required this.sites,
    required this.schemes,
    required this.people,
    super.key,
  });

  final ExpenseModel? expense;
  final List<SiteModel> sites;
  final List<SchemeModel> schemes;
  final List<PersonSummary> people;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _amountController;
  late final TextEditingController _purposeController;
  late final TextEditingController _remarksController;
  late final TextEditingController _attachmentController;

  late DateTime _expenseDate;
  late String _category;
  String? _selectedSiteId;
  String? _selectedSchemeId;
  String? _selectedPersonId;

  @override
  void initState() {
    super.initState();
    final exp = widget.expense;
    _codeController = TextEditingController(text: exp?.expenseCode ?? '');
    _amountController = TextEditingController(
      text: exp?.amount != null ? exp!.amount.toStringAsFixed(2) : '',
    );
    _purposeController = TextEditingController(text: exp?.purpose ?? '');
    _remarksController = TextEditingController(text: exp?.remarks ?? '');
    _attachmentController = TextEditingController(
      text: exp?.attachmentPath ?? '',
    );

    _expenseDate = exp?.expenseDate ?? DateTime.now();
    _category = exp?.category ?? 'office';
    _selectedSiteId = exp?.siteId;
    _selectedSchemeId = exp?.schemeId;
    _selectedPersonId = exp?.personId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    _purposeController.dispose();
    _remarksController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Expense Code *',
                          hintText: 'EXP-001',
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
                        label: Text('Date: ${_formatDate(_expenseDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expenseDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _expenseDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items: const [
                    DropdownMenuItem(
                      value: 'personal',
                      child: Text('Personal'),
                    ),
                    DropdownMenuItem(value: 'labour', child: Text('Labour')),
                    DropdownMenuItem(value: 'vehicle', child: Text('Vehicle')),
                    DropdownMenuItem(value: 'office', child: Text('Office')),
                    DropdownMenuItem(
                      value: 'security',
                      child: Text('Security'),
                    ),
                    DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    DropdownMenuItem(
                      value: 'material',
                      child: Text('Material'),
                    ),
                    DropdownMenuItem(
                      value: 'miscellaneous',
                      child: Text('Miscellaneous'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (Rs.) *',
                    hintText: '500.00',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter expense amount.';
                    }
                    final num = double.tryParse(val.trim());
                    if (num == null || num <= 0) {
                      return 'Enter positive amount.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purposeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Purpose / Description *',
                    hintText: 'e.g. Fuel for Site Inspection Vehicle',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter purpose.'
                      : null,
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
                  initialValue: _selectedPersonId,
                  decoration: const InputDecoration(
                    labelText: 'Person / Vendor',
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _attachmentController,
                        decoration: const InputDecoration(
                          labelText: 'Receipt / Attachment',
                          hintText: 'No file selected',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.attach_file),
                      tooltip: 'Select Receipt File',
                      onPressed: () async {
                        final files = await FilePicker.pickFiles(
                          dialogTitle: 'Select Receipt or Bill File',
                          type: FileType.any,
                        );
                        if (files.length == 1 && files.single.path != null) {
                          setState(() {
                            _attachmentController.text = files.single.path!;
                          });
                        }
                      },
                    ),
                  ],
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

    Navigator.pop(
      context,
      ExpenseInput(
        expenseCode: _codeController.text,
        expenseDate: _expenseDate,
        category: _category,
        amount: amount,
        purpose: _purposeController.text,
        siteId: _selectedSiteId,
        schemeId: _selectedSchemeId,
        personId: _selectedPersonId,
        remarks: _remarksController.text,
        attachmentPath: _attachmentController.text,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
