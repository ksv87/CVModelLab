export 'annotated_image_saver_stub.dart'
    if (dart.library.html) 'annotated_image_saver_web.dart'
    if (dart.library.io) 'annotated_image_saver_desktop.dart';
