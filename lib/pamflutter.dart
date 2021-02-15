import 'dart:async';
import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert' show json;

class Pamflutter {
  static const MethodChannel _channel = const MethodChannel('ai.pams.flutter');
  static var mediaName = "";
  static var pamURL = "";

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> get platform async {
    final String version = await _channel.invokeMethod('getPlatform');
    return version;
  }

  static Future<dynamic> methodsHandler(MethodCall methodCall) async {
    switch (methodCall.method) {
      case 'onToken':
        var token = methodCall.arguments;
        print("onToken: $token");
        var payload = {Pamflutter.mediaName: token};
        await Pamflutter.track("save-push-key", payload);
        return '';
      default:
        return '';
    }
  }

  static init(pamURL) {
    if (pamURL.endsWith('/')) {
      Pamflutter.pamURL = pamURL.substring(0, pamURL.length - 1);
    } else {
      Pamflutter.pamURL = pamURL;
    }
    _channel.setMethodCallHandler(Pamflutter.methodsHandler);
  }

  static track(eventName, payload) async {
    print("TRACK RUN");

    var platform = await Pamflutter.platform;
    var platformVersion = await Pamflutter.platformVersion;

    print("Platform = $platform $platformVersion");

    var url = "${Pamflutter.pamURL}/trackers/events";

    print("POST URL = $url");

    Map data = {
      'event': eventName,
      'platform': platform,
      'platform_version': platformVersion,
      'sdk': 'flutter',
      'form_fields': payload,
    };

    String body = json.encode(data);

    http.Response response = await http.post(url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
  }

  static askNotificationPermission(mediaName) {
    Pamflutter.mediaName = mediaName;
    _channel.invokeMethod("askNotificationPermission");
  }
}
