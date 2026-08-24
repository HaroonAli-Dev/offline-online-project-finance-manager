import 'package:flutter/material.dart';

import '../../people/domain/person_summary.dart';
import '../../sites/domain/site_model.dart';
import '../domain/scheme_model.dart';

class SchemeInput {
  const SchemeInput({
    required this.schemeCode,
    required this.name,
    this.siteId,
    required this.budget,
    this.engineerId,
    this.startDate,
    this.endDate,
    required this.status,
    required this.progressPercentage,
    this.incompleteReason,
    this.result,
    this.description,
  });

  final String schemeCode;
  final String name;
  final String? siteId;
  final double budget;
  final String? engineerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final double progressPercentage;
  final String? incompleteReason;
  final String? result;
  final String? description;
}

class SchemeFormDialog extends StatefulWidget {
  const SchemeFormDialog({
    this.scheme,
    required this.sites,
    required this.people,
    super.key,
  });

  final SchemeModel? scheme;
  final List<SiteModel> sites;
  final List<PersonSummary> people;

  @override
  State<SchemeFormDialog> createState() => _SchemeFormDialogState();
}

class _SchemeFormDialogState extends State<SchemeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late final TextEditingController _reasonController;
  late final TextEditingController _resultController;
  late final TextEditingController _descriptionController;

  String? _selectedSiteId;
  String? _selectedEngineerId;
  DateTime? _startDate;
  DateTime? _endDate;
  late String _status;
  late double _progress;

  @override
  void initState() {
    super.initState();
    final scheme = widget.scheme;
    _codeController = TextEditingController(text: scheme?.schemeCode ?? '');
    _nameController = TextEditingController(text: scheme?.name ?? '');
    _budgetController = TextEditingController(
      text: scheme?.budget != null ? scheme!.budget.toStringAsFixed(2) : '',
    );
    _reasonController = TextEditingController(
      text: scheme?.incompleteReason ?? '',
    );
    _resultController = TextEditingController(text: scheme?.result ?? '');
    _descriptionController = TextEditingController(
      text: scheme?.description ?? '',
    );

    _selectedSiteId = scheme?.siteId;
    _selectedEngineerId = scheme?.engineerId;
    _startDate = scheme?.startDate;
    _endDate = scheme?.endDate;
    _status = scheme?.status ?? 'initial';
    _progress = scheme?.progressPercentage ?? 0.0;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    _reasonController.dispose();
    _resultController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.scheme == null ? 'Add scheme' : 'Edit scheme'),
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
                          labelText: 'Scheme Code *',
                          hintText: 'e.g. SCH-001',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter code'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Scheme Name *',
                          hintText: 'e.g. Road Paving Project',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty
                            ? 'Enter name'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Budget / Price (Rs.) *',
                    hintText: 'e.g. 500000',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter budget amount.';
                    }
                    final num = double.tryParse(val.trim());
                    if (num == null || num < 0) {
                      return 'Enter valid positive number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedSiteId,
                  decoration: const InputDecoration(labelText: 'Site'),
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
                  initialValue: _selectedEngineerId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Engineer',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None / Unassigned'),
                    ),
                    ...widget.people.map(
                      (person) => DropdownMenuItem(
                        value: person.id,
                        child: Text(person.fullName),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedEngineerId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _startDate == null
                              ? 'Start Date'
                              : 'Start: ${_formatDate(_startDate!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(
                          _endDate == null
                              ? 'End Date'
                              : 'End: ${_formatDate(_endDate!)}',
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _endDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'initial', child: Text('Initial')),
                    DropdownMenuItem(value: 'working', child: Text('Working')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: 'incomplete',
                      child: Text('Incomplete'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _status = val;
                        if (val == 'completed') {
                          _progress = 100.0;
                        } else if (val == 'initial' || val == 'incomplete') {
                          _progress = 0.0;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Progress (${_progress.round()}%)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Slider(
                  value: _progress,
                  min: 0.0,
                  max: 100.0,
                  divisions: 100,
                  label: '${_progress.round()}%',
                  onChanged: (val) => setState(() => _progress = val),
                ),
                if (_status == 'incomplete') ...[
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Incomplete Reason',
                      hintText: 'e.g. Budget exhaustion / weather delay',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _resultController,
                    decoration: const InputDecoration(
                      labelText: 'Result / Outcome',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description / Scope',
                  ),
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
    final budget = double.parse(_budgetController.text.trim());

    Navigator.pop(
      context,
      SchemeInput(
        schemeCode: _codeController.text,
        name: _nameController.text,
        siteId: _selectedSiteId,
        budget: budget,
        engineerId: _selectedEngineerId,
        startDate: _startDate,
        endDate: _endDate,
        status: _status,
        progressPercentage: _progress,
        incompleteReason: _reasonController.text,
        result: _resultController.text,
        description: _descriptionController.text,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
