class Job {
  Job({
    String? id,
    required this.customerName,
    required this.serviceAddress,
    required this.pestPacLocationNumber,
    required this.pestPacBillToNumber,
    required this.serviceType,
    required this.createdBy,
    required this.createdDate,
    this.intakeDetails = const {},
  }) : id = id ?? 'job-${DateTime.now().microsecondsSinceEpoch}';

  final String id;
  final String customerName;
  final String serviceAddress;
  final String pestPacLocationNumber;
  final String pestPacBillToNumber;
  final String serviceType;
  final String createdBy;
  final DateTime createdDate;

  /// Local graph snapshot of optional customer/contact fields; not a customer record.
  final Map<String, String> intakeDetails;

  String get displayName =>
      customerName.trim().isEmpty ? 'Untitled Job' : customerName;
}
