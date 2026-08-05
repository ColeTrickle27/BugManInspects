import 'bugman_portal_service.dart';
import 'bugman_portal_service_stub.dart'
    if (dart.library.html) 'bugman_portal_service_web.dart';

BugManPortalService createBugManPortalService() => createPortalService();
