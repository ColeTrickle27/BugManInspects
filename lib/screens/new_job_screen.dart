import 'dart:async';

import 'package:flutter/material.dart';

import '../models/customer_file.dart';
import '../models/job.dart';
import '../services/customer_files_service.dart';
import '../services/customer_files_service_factory.dart';
import 'graph_canvas_screen.dart';

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({
    required this.onCreateJob,
    this.initialJob,
    this.editOnly = false,
    this.preselectedLocation,
    this.resolutionWarning,
    this.customerFilesService,
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

  /// A Bill-To/Location already resolved against Ops Brain (e.g. by a
  /// Sales Brain "Create New" deep link). When set, the customer identity
  /// fields are pre-filled and locked instead of requiring a fresh search.
  final CustomerLocation? preselectedLocation;

  /// Set when a deep link supplied a Bill-To/Location that could not be
  /// resolved against Ops Brain (not found, or the lookup failed). Shown
  /// as a warning banner; the technician must search or enter manually --
  /// the unresolved identifiers themselves are never used.
  final String? resolutionWarning;

  /// Overrides the Customer Files service used for search. Exposed for
  /// tests; production code should leave this null so the real
  /// Ops-Brain-backed implementation is used.
  final CustomerFilesService? customerFilesService;

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _locationNameController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _pestPacLocationController = TextEditingController();
  final _pestPacBillToController = TextEditingController();
  final _createdByController = TextEditingController();
  final _searchController = TextEditingController();
  late final TextEditingController _dateController;
  late DateTime _createdDate;
  late final CustomerFilesService _customerFilesService;

  String _serviceType = 'Inspection';

  CustomerLocation? _selectedLocation;
  bool _manualEntryOverride = false;
  bool _searching = false;
  String? _searchError;
  List<CustomerSearchResult> _searchResults = const [];
  Timer? _searchDebounce;
  bool _warningDismissed = false;

  bool get _searchFlowEnabled =>
      !widget.editOnly && _customerFilesService.isAvailable;

  bool get _showingLocationSummary =>
      _searchFlowEnabled && !_manualEntryOverride && _selectedLocation != null;

  bool get _showingSearch =>
      _searchFlowEnabled && !_manualEntryOverride && _selectedLocation == null;

  @override
  void initState() {
    super.initState();
    _customerFilesService =
        widget.customerFilesService ?? createCustomerFilesService();
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
    final preselected = widget.preselectedLocation;
    if (preselected != null) {
      _selectedLocation = preselected;
      _applyLocation(preselected);
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
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _applyLocation(CustomerLocation location) {
    _locationNameController.text = location.locationName.isNotEmpty
        ? location.locationName
        : location.billToName;
    _locationAddressController.text = location.locationAddress ?? '';
    _pestPacLocationController.text = location.locationNumber;
    _pestPacBillToController.text = location.billToNumber;
  }

  void _clearLocationFields() {
    _locationNameController.clear();
    _locationAddressController.clear();
    _pestPacLocationController.clear();
    _pestPacBillToController.clear();
  }

  void _selectLocation(CustomerLocation location) {
    setState(() {
      _selectedLocation = location;
      _applyLocation(location);
      _searchResults = const [];
      _searchController.clear();
      _searchError = null;
    });
  }

  void _changeCustomer() {
    setState(() {
      _selectedLocation = null;
      _clearLocationFields();
      _searchResults = const [];
      _searchController.clear();
      _searchError = null;
    });
  }

  void _toggleManualEntry(bool manual) {
    setState(() {
      _manualEntryOverride = manual;
      if (manual) {
        _selectedLocation = null;
      } else {
        _clearLocationFields();
        _searchResults = const [];
        _searchController.clear();
        _searchError = null;
      }
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = const [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _customerFilesService.searchCustomers(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searchResults = const [];
        _searching = false;
        _searchError = 'Customer search failed. Try again or enter manually.';
      });
    }
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
            if (widget.resolutionWarning != null && !_warningDismissed)
              _ResolutionWarningBanner(
                message: widget.resolutionWarning!,
                onDismiss: () => setState(() => _warningDismissed = true),
              ),
            if (widget.resolutionWarning != null && !_warningDismissed)
              const SizedBox(height: 12),
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
            if (_showingLocationSummary) ..._buildLocationSummary(),
            if (_showingSearch) ..._buildCustomerSearch(),
            if (!_searchFlowEnabled || _manualEntryOverride)
              ..._buildManualFields(),
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

  List<Widget> _buildLocationSummary() {
    final location = _selectedLocation!;
    return [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Customer File selected',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('change-customer-button'),
                    onPressed: _changeCustomer,
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                location.locationName.isNotEmpty
                    ? location.locationName
                    : location.billToName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if ((location.locationAddress ?? '').isNotEmpty)
                Text(location.locationAddress!),
              const SizedBox(height: 4),
              Text(
                'Bill-To # ${location.billToNumber} · Location # ${location.locationNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildCustomerSearch() {
    return [
      TextField(
        key: const ValueKey('customer-search-field'),
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          labelText: 'Search Customer Files',
          hintText: 'Name, address, Bill-To, or Location #',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
      ),
      const SizedBox(height: 8),
      if (_searchError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _searchError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_searchResults.isNotEmpty)
        Card(
          margin: EdgeInsets.zero,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              key: const ValueKey('customer-search-results'),
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                final location = result.location;
                return ListTile(
                  title: Text(location.displayLabel),
                  subtitle: Text(
                    [
                      if ((location.locationAddress ?? '').isNotEmpty)
                        location.locationAddress!,
                      'Bill-To # ${location.billToNumber} · Location # ${location.locationNumber}',
                    ].join('\n'),
                  ),
                  isThreeLine: (location.locationAddress ?? '').isNotEmpty,
                  onTap: () => _selectLocation(location),
                );
              },
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const ValueKey('manual-entry-toggle'),
          onPressed: () => _toggleManualEntry(true),
          child: const Text('Customer not found -- enter manually'),
        ),
      ),
      const SizedBox(height: 4),
    ];
  }

  List<Widget> _buildManualFields() {
    return [
      if (_searchFlowEnabled)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('search-instead-toggle'),
            onPressed: () => _toggleManualEntry(false),
            child: const Text('Search Customer Files instead'),
          ),
        ),
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
    ];
  }

  static String _formatDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';
}

class _ResolutionWarningBanner extends StatelessWidget {
  const _ResolutionWarningBanner({
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: scheme.onErrorContainer, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
