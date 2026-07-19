class Job {
  Job({
    required this.customerName,
    required this.serviceAddress,
    required this.pestPacLocationNumber,
    required this.pestPacBillToNumber,
    required this.serviceType,
    required this.createdBy,
    required this.createdDate,
  });

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
