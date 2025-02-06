import 'pam_flutter_platform_interface.dart';

class PamFlutter {
  Future<String?> getPlatformVersion() {
    return PamFlutterPlatform.instance.getPlatformVersion();
  }
}
