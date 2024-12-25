import 'package:flutter/src/services/message_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pam_flutter/pam_flutter.dart';
import 'package:pam_flutter/pam_flutter_platform_interface.dart';
import 'package:pam_flutter/pam_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPamFlutterPlatform
    with MockPlatformInterfaceMixin
    implements PamFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> appAttentionPopup(Map<String, dynamic> params) {
    // TODO: implement appAttentionPopup
    throw UnimplementedError();
  }

  @override
  Future<int> getTrackingAuthorizationStatus() {
    // TODO: implement getTrackingAuthorizationStatus
    throw UnimplementedError();
  }

  @override
  Future<String?> identifierForVendor() {
    // TODO: implement identifierForVendor
    throw UnimplementedError();
  }

  @override
  Future<int> requestTrackingAuthorization() {
    // TODO: implement requestTrackingAuthorization
    throw UnimplementedError();
  }

  @override
  void setOnPlatformCallback(Future Function(MethodCall p1) callback) {
    // TODO: implement setOnPlatformCallback
  }
}

void main() {
  final PamFlutterPlatform initialPlatform = PamFlutterPlatform.instance;

  test('$MethodChannelPamFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPamFlutter>());
  });

  test('getPlatformVersion', () async {
    PamFlutter pamFlutterPlugin = PamFlutter();
    MockPamFlutterPlatform fakePlatform = MockPamFlutterPlatform();
    PamFlutterPlatform.instance = fakePlatform;

    expect(await pamFlutterPlugin.getPlatformVersion(), '42');
  });
}
