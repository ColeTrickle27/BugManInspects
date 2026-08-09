import 'marker_defaults_store.dart';
import 'marker_defaults_store_stub.dart'
    if (dart.library.html) 'marker_defaults_store_web.dart';

MarkerDefaultsStore createMarkerDefaultsStore() =>
    createPlatformMarkerDefaultsStore();
