export 'project_file_io_stub.dart'
    if (dart.library.html) 'project_file_io_web.dart'
    if (dart.library.io) 'project_file_io_desktop.dart';
