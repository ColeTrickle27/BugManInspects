/// Customer domain models mirrored from Ops Brain's Customer Files.
///
/// These mirror the Bill-To / Location shape Holloman Ops Brain maintains in
/// its `bill-tos/{billToNumber} - {billToName}/{locationNumber} - {locationName}/`
/// R2 prefixes, and returns from its `/api/accounts`, `/api/search`, and
/// `/api/location` routes (see holloman-ops-brain's
/// functions/api/[[path]].js -> normalizeIndexedLocation). The field names
/// intentionally match ColeTrickle27/BugMan-Sales-Brain's
/// `src/types/customer.ts` so both apps reason about the same shape.
///
/// BugMan Graphs does NOT own customer data. It only reads Ops Brain's
/// Bill-To / Location records through [CustomerFilesService]. If a customer
/// cannot be found there, the UI must fall back to manual entry of the exact
/// PestPac identifiers -- never invent or duplicate a customer record.
library;

/// A PestPac Bill-To account, as mirrored inside Ops Brain's Customer Files.
class CustomerBillTo {
  const CustomerBillTo({
    required this.billToNumber,
    required this.billToName,
  });

  /// PestPac Bill-To number. This is the durable identifier, not a UUID.
  final String billToNumber;

  /// Display name for the Bill-To (company name, or "Last, First").
  final String billToName;
}

/// A single serviceable location under a Bill-To, as mirrored inside Ops
/// Brain's Customer Files.
class CustomerLocation {
  const CustomerLocation({
    required this.billToNumber,
    required this.billToName,
    required this.locationNumber,
    required this.locationName,
    this.locationAddress,
    this.lastModified,
    this.prefix,
  });

  final String billToNumber;
  final String billToName;

  /// PestPac location number, unique within the Bill-To.
  final String locationNumber;
  final String locationName;
  final String? locationAddress;

  /// ISO 8601 timestamp of the last change recorded in Ops Brain's index.
  final String? lastModified;

  /// The Ops Brain R2 storage prefix for this location's files. Treat as an
  /// opaque Ops Brain implementation detail -- never construct this here,
  /// only pass through what Ops Brain returns.
  final String? prefix;

  /// Combined "Bill-To Name — Location Name" label for search results.
  String get displayLabel =>
      locationName.isNotEmpty ? '$billToName — $locationName' : billToName;
}

/// Result row of a Customer Files search
/// (see [CustomerFilesService.searchCustomers]).
class CustomerSearchResult {
  const CustomerSearchResult({
    required this.billTo,
    required this.location,
  });

  final CustomerBillTo billTo;
  final CustomerLocation location;
}
