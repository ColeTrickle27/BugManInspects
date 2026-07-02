class Job {
  Job({
    required this.customerName,
    required this.serviceAddress,
    required this.pestPacAccountNumber,
    required this.serviceType,
    required this.createdBy,
    required this.createdDate,
  });

  final String customerName;
  final String serviceAddress;
  final String pestPacAccountNumber;
  final String serviceType;
  final String createdBy;
  final DateTime createdDate;
}
