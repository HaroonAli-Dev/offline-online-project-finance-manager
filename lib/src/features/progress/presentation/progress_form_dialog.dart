import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../schemes/domain/scheme_model.dart';
import '../domain/progress_model.dart';

class ProgressInput {
  const ProgressInput({
    required this.schemeId,
    this.siteId,
    required this.status,
    required this.progressPercentage,
    required this.date,
    this.incompleteReason,
    this.result,
    this.remarks,
  });

  final String schemeId;
  final String? siteId;
  final String status;
  final double progressPercentage;
  final DateTime date;
  final String? incompleteReason;
  final String? result;
  final String? remarks;
}

class ProgressFormDialog extends StatefulWidget {
  const ProgressFormDialog({
    this.progress,
    required this.schemes,
    this.preselectedSchemeId,
    super.key,
  });

  final ProgressModel? progress;
  final List<SchemeModel> schemes;
  final String? preselectedSchemeId;

  @override
  State<ProgressFormDialog> createState() => _ProgressFormDialogState();
}

class _ProgressFormDialogState extends State<ProgressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _percentageController;
  late final TextEditingController _resultController;
  late final TextEditingController _incompleteReasonController;
  late final TextEditingController _remarksController;

  String? _selectedSchemeId;
  late String _selectedStatus;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final p = widget.progress;

    _selectedSchemeId = p?.schemeId ?? widget.preselectedSchemeId;
    _selectedStatus = p?.status ?? 'in_progress';
    _date = p?.date ?? DateTime.now();

    _percentageController = TextEditingController(
      text: p?.progressPercentage != null
          ? p!.progressPercentage.toStringAsFixed(0)
          : '',
    );
    _resultController = TextEditingController(text: p?.result ?? '');
    _incompleteReasonController = TextEditingController(
      text: p?.incompleteReason ?? '',
    );
    _remarksController = TextEditingController(text: p?.remarks ?? '');
  }

  @override
  void dispose() {
    _percentageController.dispose();
    _resultController.dispose();
    _incompleteReasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final scheme = widget.schemes.firstWhere(
        (s) => s.id == _selectedSchemeId,
      );
      final pct = double.tryParse(_percentageController.text) ?? 0.0;

      Navigator.of(context).pop(
        ProgressInput(
          schemeId: _selectedSchemeId!,
          siteId:
              scheme.siteId, // Automatically inherit the site from the scheme
          status: _selectedStatus,
          progressPercentage: pct,
          date: _date,
          incompleteReason: _selectedStatus == 'incomplete'
              ? _incompleteReasonController.text
              : null,
          result: _resultController.text.isNotEmpty
              ? _resultController.text
              : null,
          remarks: _remarksController.text.isNotEmpty
              ? _remarksController.text
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.progress == null
            ? 'Add Progress Update'
            : 'Edit Progress Update',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Scheme *',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedSchemeId,
                items: widget.schemes.map((s) {
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.schemeCode} - ${s.name}'),
                  );
                }).toList(),
                onChanged:
                    widget.progress != null ||
                        widget.preselectedSchemeId != null
                    ? null
                    : (val) {
                        setState(() {
                          _selectedSchemeId = val;
                        });
                      },
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Status *',
                        border: OutlineInputBorder(),
                      ),
                      initialValue: _selectedStatus,
                      items: kProgressStatuses.map((status) {
                        return DropdownMenuItem(
                          value: status.$1,
                          child: Text(status.$2),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                            if (val == 'completed') {
                              _percentageController.text = '100';
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _percentageController,
                      decoration: const InputDecoration(
                        labelText: 'Progress % *',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d*'),
                        ),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final val = double.tryParse(v);
                        if (val == null) return 'Invalid';
                        if (val < 0 || val > 100) return '0-100 only';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date *'),
                subtitle: Text('${_date.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    setState(() => _date = d);
                  }
                },
              ),
              if (_selectedStatus == 'incomplete') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _incompleteReasonController,
                  decoration: const InputDecoration(
                    labelText: 'Incomplete Reason *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (v) {
                    if (_selectedStatus == 'incomplete' &&
                        (v == null || v.isEmpty)) {
                      return 'Reason is required when status is Incomplete';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _resultController,
                decoration: const InputDecoration(
                  labelText: 'Result / Outcome',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Completed 1st floor slab',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('SAVE')),
      ],
    );
  }
}
