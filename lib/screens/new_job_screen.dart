import 'package:flutter/material.dart';

import '../models/job.dart';
import 'graph_canvas_screen.dart';

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({
    required this.onCreateJob,
    this.initialJob,
    this.editOnly = false,
    super.key,
  });

  static const String routeName = '/new-job';
  static const List<String> serviceTypes = [
    'Inspection',
    'WDIR',
    'ATBS Installation',
    'General Use',
  ];

  final ValueChanged<Job> onCreateJob;
  final Job? initialJob;
  final bool editOnly;

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _locationNameController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _pestPacLocationController = TextEditingController();
  final _pestPacBillToController = TextEditingController();
  final _createdByController = TextEditingController();
  late final TextEditingController _dateController;
  late DateTime _createdDate;

  String _serviceType = 'Inspection';

  @override
  void initState() {
    super.initState();
    final initialJob = widget.initialJob;
    _createdDate = DateUtils.dateOnly(
      initialJob?.createdDate ?? DateTime.now(),
    );
    _dateController = TextEditingController(text: _formatDate(_createdDate));
    if (initialJob != null) {
      _locationNameController.text = initialJob.customerName;
      _locationAddressController.text = initialJob.serviceAddress;
      _pestPacLocationController.text = initialJob.pestPacLocationNumber;
      _pestPacBillToController.text = initialJob.pestPacBillToNumber;
      _createdByController.text = initialJob.createdBy;
      _serviceType = NewJobScreen.serviceTypes.contains(initialJob.serviceType)
          ? initialJob.serviceType
          : 'Inspection';
    }
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _pestPacLocationController.dispose();
    _pestPacBillToController.dispose();
    _createdByController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _createdDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _createdDate = DateUtils.dateOnly(selectedDate);
      _dateController.text = _formatDate(_createdDate);
    });
  }

  void _createJob() {
    final job = Job(
      id: widget.initialJob?.id,
      customerName: _locationNameController.text.trim(),
      serviceAddress: _locationAddressController.text.trim(),
      pestPacLocationNumber: _pestPacLocationController.text.trim(),
      pestPacBillToNumber: _pestPacBillToController.text.trim(),
      serviceType: _serviceType,
      createdBy: _createdByController.text.trim(),
      createdDate: _createdDate,
    );

    widget.onCreateJob(job);

    if (widget.editOnly) {
      Navigator.of(context).pop(job);
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      GraphCanvasScreen.routeName,
      arguments: job,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editOnly ? 'Edit Job' : 'New Job'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const ValueKey('job-date-field'),
              controller: _dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                suffixIcon: Icon(Icons.edit_calendar_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Location Name',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationAddressController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Location Address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pestPacLocationController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PestPac Location #',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pestPacBillToController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'PestPac Bill-To #',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _serviceType,
              decoration: const InputDecoration(
                labelText: 'Service Type',
                prefixIcon: Icon(Icons.bug_report_outlined),
              ),
              items: NewJobScreen.serviceTypes
                  .map(
                    (serviceType) => DropdownMenuItem(
                      value: serviceType,
                      child: Text(serviceType),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _serviceType = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _createdByController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Created By',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              onSubmitted: (_) => _createJob(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createJob,
              icon: Icon(
                  widget.editOnly ? Icons.save_outlined : Icons.arrow_forward),
              label: Text(widget.editOnly ? 'Save Changes' : 'Create Graph'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}
