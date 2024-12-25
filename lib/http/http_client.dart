import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;
import 'dart:convert';
import 'dart:io';

class HttpClient {
  static Map<String, String> _defaultHeaders(Map<String, String>? headers) {
    Map<String, String> newHeader;
    if (headers != null) {
      newHeader = headers;
    } else {
      newHeader = {};
    }
    if (Platform.isAndroid) {
      newHeader["platform"] = "android";
    } else if (Platform.isIOS) {
      newHeader["platform"] = "ios";
    }
    newHeader["Content-Type"] = "application/json";

    return newHeader;
  }

  static Future<Response> get(Uri url, {Map<String, String>? headers}) async {
    var newHeader = _defaultHeaders(headers);
    return http.get(url, headers: newHeader);
  }

  static Future<Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    var newHeader = _defaultHeaders(headers);
    return http.post(url,
        body: jsonEncode(body), encoding: encoding, headers: newHeader);
  }
}
