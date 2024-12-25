import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'pam_flutter_method_channel.dart';

abstract class PamFlutterPlatform extends PlatformInterface {
  /// Constructs a PamFlutterPlatform.
  PamFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static PamFlutterPlatform _instance = MethodChannelPamFlutter();

  /// The default instance of [PamFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelPamFlutter].
  static PamFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PamFlutterPlatform] when
  /// they register themselves.
  static set instance(PamFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> getTrackingAuthorizationStatus() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int> requestTrackingAuthorization() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> identifierForVendor() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<String, dynamic>?> appAttentionPopup(Map<String, dynamic> params) {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  void setOnPlatformCallback(Future<dynamic> Function(MethodCall) callback) {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
