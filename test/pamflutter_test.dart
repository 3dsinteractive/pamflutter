import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pamflutter/pamflutter.dart';

void main() {
  const MethodChannel channel = MethodChannel('pamflutter');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await Pamflutter.platformVersion, '42');
  });
}
