export 'platform_capabilities_stub.dart'
    if (dart.library.html) 'platform_capabilities_web.dart'
    if (dart.library.io) 'platform_capabilities_io.dart';
