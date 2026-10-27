import 'package:http/http.dart' as http;
import 'package:http/http.dart' show Response;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HttpClient {
  static const Duration requestTimeout = Duration(seconds: 5);

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

  static Future<Response> get(Uri url,
      {Map<String, String>? headers, Duration? timeout}) async {
    var newHeader = _defaultHeaders(headers);
    final effectiveTimeout = timeout ?? requestTimeout;
    var client = http.Client();
    try {
      return await client.get(url, headers: newHeader).timeout(effectiveTimeout,
          onTimeout: () {
        client.close();
        throw TimeoutException("GET request timed out.", effectiveTimeout);
      });
    } finally {
      client.close();
    }
  }

  static Future<Response> post(Uri url,
      {Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
      Duration? timeout}) async {
    var newHeader = _defaultHeaders(headers);
    final effectiveTimeout = timeout ?? requestTimeout;
    var client = http.Client();
    try {
      return await client
          .post(url,
              body: jsonEncode(body), encoding: encoding, headers: newHeader)
          .timeout(effectiveTimeout, onTimeout: () {
        client.close();
        throw TimeoutException("POST request timed out.", effectiveTimeout);
      });
    } finally {
      client.close();
    }
  }
}
