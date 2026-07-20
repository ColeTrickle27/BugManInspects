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
  }) : id = id ?? 'job-${DateTime.now().microsecondsSinceEpoch}';

  final String id;
  final String customerName;
  final String serviceAddress;
  final String pestPacLocationNumber;
  final String pestPacBillToNumber;
  final String serviceType;
  final String createdBy;
  final DateTime createdDate;

  String get displayName =>
      customerName.trim().isEmpty ? 'Untitled Job' : customerName;
}
