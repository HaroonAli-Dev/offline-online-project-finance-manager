import 'package:flutter/material.dart';

import '../../people/domain/person_summary.dart';
import '../../sites/domain/site_model.dart';
import '../domain/vehicle_model.dart';

class VehicleInput {
  const VehicleInput({
    required this.vehicleNumber,
    required this.makeModel,
    required this.vehicleType,
    this.assignedSiteId,
    this.assignedDriverId,
    required this.status,
    this.remarks,
  });

  final String vehicleNumber;
  final String makeModel;
  final String vehicleType;
  final String? assignedSiteId;
  final String? assignedDriverId;
  final String status;
  final String? remarks;
}

class VehicleFormDialog extends StatefulWidget {
  const VehicleFormDialog({
    this.vehicle,
    required this.sites,
    required this.people,
    super.key,
  });

  final VehicleModel? vehicle;
  final List<SiteModel> sites;
  final List<PersonSummary> people;

  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _makeController;
  late final TextEditingController _remarksController;

  late String _vehicleType;
  late String _status;
  String? _assignedSiteId;
  String? _assignedDriverId;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _numberController = TextEditingController(text: v?.vehicleNumber ?? '');
    _makeController = TextEditingController(text: v?.makeModel ?? '');
    _remarksController = TextEditingController(text: v?.remarks ?? '');

    _vehicleType = v?.vehicleType ?? 'truck';
    _status = v?.status ?? 'active';
    _assignedSiteId = v?.assignedSiteId;
    _assignedDriverId = v?.assignedDriverId;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _makeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _numberController,
                  textCapitalization: TextCapitalization.characters,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number *',
                    hintText: 'e.g. LEB-1234 / LHR-786',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter registration number.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _makeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Make & Model *',
                    hintText: 'e.g. Hino Dumper Truck 2023',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter make/model.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _vehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: const [
                    DropdownMenuItem(value: 'truck', child: Text('Truck')),
                    DropdownMenuItem(value: 'dumper', child: Text('Dumper')),
                    DropdownMenuItem(
                      value: 'excavator',
                      child: Text('Excavator'),
                    ),
                    DropdownMenuItem(value: 'car', child: Text('Car / Jeep')),
                    DropdownMenuItem(value: 'tractor', child: Text('Tractor')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _vehicleType = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _assignedSiteId,
                  decoration: const InputDecoration(labelText: 'Assigned Site'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...widget.sites.map(
                      (site) => DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _assignedSiteId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _assignedDriverId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Driver',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...widget.people.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.fullName),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _assignedDriverId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'under_maintenance',
                      child: Text('Under Maintenance'),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _status = val);
                  },
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
    Navigator.pop(
      context,
      VehicleInput(
        vehicleNumber: _numberController.text,
        makeModel: _makeController.text,
        vehicleType: _vehicleType,
        assignedSiteId: _assignedSiteId,
        assignedDriverId: _assignedDriverId,
        status: _status,
        remarks: _remarksController.text,
      ),
    );
  }
}

class VehicleLogInput {
  const VehicleLogInput({
    required this.logDate,
    required this.logType,
    required this.amount,
    this.quantityLiters,
    this.driverId,
    this.siteId,
    required this.description,
    this.odometerReading,
  });

  final DateTime logDate;
  final String logType;
  final double amount;
  final double? quantityLiters;
  final String? driverId;
  final String? siteId;
  final String description;
  final double? odometerReading;
}

class VehicleLogFormDialog extends StatefulWidget {
  const VehicleLogFormDialog({
    required this.people,
    required this.sites,
    super.key,
  });

  final List<PersonSummary> people;
  final List<SiteModel> sites;

  @override
  State<VehicleLogFormDialog> createState() => _VehicleLogFormDialogState();
}

class _VehicleLogFormDialogState extends State<VehicleLogFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _litersController;
  late final TextEditingController _descController;
  late final TextEditingController _odometerController;

  late DateTime _logDate;
  String _logType = 'fuel';
  String? _driverId;
  String? _siteId;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _litersController = TextEditingController();
    _descController = TextEditingController();
    _odometerController = TextEditingController();
    _logDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _litersController.dispose();
    _descController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Fuel / Maintenance / Trip Log'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _logType,
                  decoration: const InputDecoration(labelText: 'Log Type *'),
                  items: const [
                    DropdownMenuItem(
                      value: 'fuel',
                      child: Text('Fuel / Diesel'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance / Repair'),
                    ),
                    DropdownMenuItem(
                      value: 'trip',
                      child: Text('Trip Expenditure'),
                    ),
                    DropdownMenuItem(
                      value: 'expenditure',
                      child: Text('General Expense'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _logType = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Date: ${_formatDate(_logDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _logDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _logDate = picked);
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
                          hintText: '5000',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter amount.';
                          }
                          final num = double.tryParse(val.trim());
                          if (num == null || num < 0) {
                            return 'Enter valid amount.';
                          }
                          return null;
                        },
                      ),
                    ),
                    if (_logType == 'fuel') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _litersController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Liters',
                            hintText: '20.0',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description / Purpose *',
                    hintText: 'e.g. Tank refill at Shell / Oil Change',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Enter description.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _odometerController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Odometer Reading (KM)',
                    hintText: '125000',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _driverId,
                  decoration: const InputDecoration(labelText: 'Driver'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...widget.people.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.fullName),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _driverId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _siteId,
                  decoration: const InputDecoration(labelText: 'Site'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...widget.sites.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _siteId = val),
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
        FilledButton(onPressed: _submit, child: const Text('Add Log')),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = double.parse(_amountController.text.trim());
    final liters = double.tryParse(_litersController.text.trim());
    final odo = double.tryParse(_odometerController.text.trim());

    Navigator.pop(
      context,
      VehicleLogInput(
        logDate: _logDate,
        logType: _logType,
        amount: amount,
        quantityLiters: liters,
        driverId: _driverId,
        siteId: _siteId,
        description: _descController.text,
        odometerReading: odo,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
