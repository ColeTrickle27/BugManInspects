import '../models/customer_file.dart';

/// Customer Files service boundary.
///
/// Ops Brain (ColeTrickle27/holloman-ops-brain) is the single system of
/// record that mirrors PestPac's Bill-To / Location structure. BugMan
/// Graphs never owns or invents customer records -- it only searches and
/// reads real Customer File records through Ops Brain's authenticated
/// session and existing `/api/search`, `/api/accounts`, and `/api/location`
/// routes. This mirrors ColeTrickle27/BugMan-Sales-Brain's
/// `CustomerFilesService` interface so both apps resolve the same customer
/// identity the same way.
///
/// If a Bill-To/Location isn't found here, the caller must fall back to
/// manual entry of the exact PestPac identifiers the technician already
/// knows -- never auto-generate or guess a Bill-To or Location number.
abstract class CustomerFilesService {
  /// Whether this service can actually reach Ops Brain from the current
  /// context (e.g. false on non-web platforms, or when the app isn't
  /// served from an origin Ops Brain trusts).
  bool get isAvailable;

  /// Free-text search across Bill-To name, Location name/address, and
  /// customer name.
  Future<List<CustomerSearchResult>> searchCustomers(String query);

  /// All Locations under a Bill-To.
  Future<List<CustomerLocation>> getLocations(String billToNumber);

  /// A single Bill-To/Location pair, if it already exists in Ops Brain.
  /// Returns null (never throws) when the pair cannot be resolved, so
  /// callers can safely treat "not found" as "fall back to manual entry"
  /// without needing to guess an identifier themselves.
  Future<CustomerLocation?> getLocation(
    String billToNumber,
    String locationNumber,
  );
}
