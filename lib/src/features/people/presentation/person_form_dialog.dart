import 'package:flutter/material.dart';

import '../domain/person_summary.dart';
import '../domain/role_definition.dart';

class PersonInput {
  const PersonInput({
    required this.fullName,
    required this.roleCodes,
    this.phoneNumber,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
  });

  final String fullName;
  final Set<String> roleCodes;
  final String? phoneNumber;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
}

class PersonFormDialog extends StatefulWidget {
  const PersonFormDialog({required this.roles, this.person, super.key});

  final PersonSummary? person;
  final List<RoleDefinition> roles;

  @override
  State<PersonFormDialog> createState() => _PersonFormDialogState();
}

class _PersonFormDialogState extends State<PersonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late final Set<String> _selectedRoles;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final person = widget.person;
    _nameController = TextEditingController(text: person?.fullName);
    _phoneController = TextEditingController(text: person?.phoneNumber);
    _emailController = TextEditingController(text: person?.email);
    _addressController = TextEditingController(text: person?.address);
    _notesController = TextEditingController(text: person?.notes);
    _selectedRoles = {...?person?.roleCodes};
    _isActive = person?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.person == null ? 'Add person' : 'Edit person'),
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
                  decoration: const InputDecoration(labelText: 'Full name *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the full name.'
                      : null,
                ),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextFormField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Roles',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...widget.roles.map(
                  (role) => CheckboxListTile(
                    value: _selectedRoles.contains(role.code),
                    contentPadding: EdgeInsets.zero,
                    title: Text(role.displayName),
                    onChanged: (selected) => setState(() {
                      if (selected ?? false) {
                        _selectedRoles.add(role.code);
                      } else {
                        _selectedRoles.remove(role.code);
                      }
                    }),
                  ),
                ),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if (widget.person != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Inactive people stay in records but are hidden by default.',
                    ),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
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
    Navigator.pop(
      context,
      PersonInput(
        fullName: _nameController.text,
        roleCodes: _selectedRoles,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        address: _addressController.text,
        notes: _notesController.text,
        isActive: _isActive,
      ),
    );
  }
}
