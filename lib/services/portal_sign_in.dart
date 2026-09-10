export 'portal_sign_in_stub.dart'
    if (dart.library.html) 'portal_sign_in_web.dart';

/// Mounted Graphs stays in its current OpsBrain environment, including Preview.
String opsBrainHomeUrl(Uri page) => page.path.startsWith('/bugman-graphs/')
    ? '${page.origin}/'
    : 'https://ops.holloman-ext.com/';
