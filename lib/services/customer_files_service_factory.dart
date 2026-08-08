import 'customer_files_service.dart';
import 'customer_files_service_stub.dart'
    if (dart.library.html) 'customer_files_service_web.dart';

CustomerFilesService createCustomerFilesService() =>
    createOpsBrainCustomerFilesService();
