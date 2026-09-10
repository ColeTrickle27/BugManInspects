import '../models/customer_file.dart';

/// Read-only customer lookup boundary.
///
/// Ops Brain (ColeTrickle27/holloman-ops-brain) is the single system of
/// record that mirrors PestPac's Bill-To / Location structure. BugMan
/// Graphs never owns or invents customer records -- it only searches and
/// reads through Ops Brain's authenticated session. Search and pair resolution
/// use `/api/customer-identity/search`, selecting complete permanent identities
/// like SalesBrain. The legacy accounts method remains for file listings.
///
/// A new-customer graph can be an unassigned draft. Never generate, guess or
/// manually register customer identifiers from Graphs.
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
  /// Returns null when no matching permanent identity can be resolved.
  /// Authentication and connection errors remain distinct failures.
  Future<CustomerLocation?> getLocation(
    String billToNumber,
    String locationNumber,
  );
}
