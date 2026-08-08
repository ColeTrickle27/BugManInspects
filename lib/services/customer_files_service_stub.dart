import '../models/customer_file.dart';
import 'customer_files_service.dart';

CustomerFilesService createOpsBrainCustomerFilesService() =>
    UnavailableCustomerFilesService();

class UnavailableCustomerFilesService implements CustomerFilesService {
  @override
  bool get isAvailable => false;

  @override
  Future<List<CustomerSearchResult>> searchCustomers(String query) =>
      Future.error(UnsupportedError('Holloman Ops Brain is unavailable.'));

  @override
  Future<List<CustomerLocation>> getLocations(String billToNumber) =>
      Future.error(UnsupportedError('Holloman Ops Brain is unavailable.'));

  @override
  Future<CustomerLocation?> getLocation(
    String billToNumber,
    String locationNumber,
  ) =>
      Future.error(UnsupportedError('Holloman Ops Brain is unavailable.'));
}
