import 'dart:io';

import '../core/platform/platform_capabilities.dart';

PlatformCapabilities currentPlatformCapabilities() {
  if (Platform.isAndroid || Platform.isIOS) {
    return PlatformCapabilities.mobile;
  }
  return PlatformCapabilities.desktop;
}
