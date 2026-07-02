import 'package:flutter/material.dart';

import '../models/job.dart';
import 'graph_canvas_screen.dart';

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({
    required this.onCreateJob,
    super.key,
  });

  static const String routeName = '/new-job';

  final ValueChanged<Job> onCreateJob;

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _serviceAddressController = TextEditingController();
  final _pestPacAccountController = TextEditingController();
  final _createdByController = TextEditingController();

  String _serviceType = 'Termite Inspection';

  @override
  void dispose() {
    _customerNameController.dispose();
    _serviceAddressController.dispose();
    _pestPacAccountController.dispose();
    _createdByController.dispose();
    super.dispose();
  }

  void _createJob() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final job = Job(
      customerName: _customerNameController.text.trim(),
      serviceAddress: _serviceAddressController.text.trim(),
      pestPacAccountNumber: _pestPacAccountController.text.trim(),
      serviceType: _serviceType,
      createdBy: _createdByController.text.trim(),
      createdDate: DateTime.now(),
    );

    widget.onCreateJob(job);

    Navigator.of(context).pushReplacementNamed(
      GraphCanvasScreen.routeName,
      arguments: job,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Job'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _customerNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Customer name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serviceAddressController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Service address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pestPacAccountController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'PestPac account number',
                  prefixIcon: Icon(Icons.confirmation_number_outlined),
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _serviceType,
                decoration: const InputDecoration(
                  labelText: 'Service type',
                  prefixIcon: Icon(Icons.bug_report_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Termite Inspection',
                    child: Text('Termite Inspection'),
                  ),
                  DropdownMenuItem(
                    value: 'Termite Treatment',
                    child: Text('Termite Treatment'),
                  ),
                  DropdownMenuItem(
                    value: 'Rodent Inspection',
                    child: Text('Rodent Inspection'),
                  ),
                  DropdownMenuItem(
                    value: 'General Pest',
                    child: Text('General Pest'),
                  ),
                ],
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
              TextFormField(
                controller: _createdByController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Created by',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: _required,
                onFieldSubmitted: (_) => _createJob(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _createJob,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Create Graph'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }
}
