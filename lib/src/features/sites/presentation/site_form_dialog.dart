import 'package:flutter/material.dart';

import '../domain/site_model.dart';

class SiteInput {
  const SiteInput({
    required this.name,
    this.roadInfo,
    this.latitude,
    this.longitude,
    required this.status,
    this.notes,
  });

  final String name;
  final String? roadInfo;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? notes;
}

class SiteFormDialog extends StatefulWidget {
  const SiteFormDialog({this.site, super.key});

  final SiteModel? site;

  @override
  State<SiteFormDialog> createState() => _SiteFormDialogState();
}

class _SiteFormDialogState extends State<SiteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _roadInfoController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _notesController;
  late String _status;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _nameController = TextEditingController(text: site?.name);
    _roadInfoController = TextEditingController(text: site?.roadInfo);
    _latController = TextEditingController(
      text: site?.latitude != null ? site!.latitude.toString() : '',
    );
    _lngController = TextEditingController(
      text: site?.longitude != null ? site!.longitude.toString() : '',
    );
    _notesController = TextEditingController(text: site?.notes);
    _status = site?.status ?? 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roadInfoController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.site == null ? 'Add site' : 'Edit site'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Site name *',
                    hintText: 'e.g. Ring Road Segment A',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the site name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roadInfoController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Road information',
                    hintText: 'e.g. KM 12 - KM 24, GT Road',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          hintText: '31.5204',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < -90 || parsed > 90) {
                            return 'Valid lat (-90 to 90)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          hintText: '74.3587',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed < -180 || parsed > 180) {
                            return 'Valid lng (-180 to 180)';
                          }
                          return null;
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
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                    DropdownMenuItem(value: 'planned', child: Text('Planned')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Additional details or landmarks...',
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
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    Navigator.pop(
      context,
      SiteInput(
        name: _nameController.text,
        roadInfo: _roadInfoController.text,
        latitude: lat,
        longitude: lng,
        status: _status,
        notes: _notesController.text,
      ),
    );
  }
}
