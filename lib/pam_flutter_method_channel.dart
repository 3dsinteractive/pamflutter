import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pam_flutter_platform_interface.dart';

/// An implementation of [PamFlutterPlatform] that uses method channels.
class MethodChannelPamFlutter extends PamFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('pam_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<int> getTrackingAuthorizationStatus() async {
    final status =
        await methodChannel.invokeMethod<int>('getTrackingAuthorizationStatus');
    return status!;
  }

  @override
  Future<int> requestTrackingAuthorization() async {
    final status =
        await methodChannel.invokeMethod<int>('requestTrackingAuthorization');
    return status!;
  }

  @override
  Future<String?> identifierForVendor() async {
    return await methodChannel.invokeMethod<String>('identifierForVendor');
  }

  @override
  Future<Map<String, dynamic>?> appAttentionPopup(
      Map<String, dynamic> params) async {
    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>?>(
        'appAttentionPopup', params);

    print("RESULT----");
    print(result);

    final Map<String, dynamic>? bannerData = result?.map(
      (key, value) => MapEntry(
        key.toString(),
        value,
      ),
    );

    return bannerData;
  }

  @override
  void setOnPlatformCallback(Future<dynamic> Function(MethodCall) callback) {
    methodChannel.setMethodCallHandler(callback);
  }
}
