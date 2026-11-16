import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class DemoAuthSession {
  final String customerId;
  const DemoAuthSession(this.customerId);

  factory DemoAuthSession.fromJson(Map<String, dynamic> json) {
    final id = json['customer_id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Auth response has no customer_id');
    }
    return DemoAuthSession(id);
  }
}

class DemoAuthException implements Exception {
  final int statusCode;
  final String message;
  const DemoAuthException(this.statusCode, this.message);
  @override
  String toString() => 'Auth API $statusCode: $message';
}

/// In-process REST transport: no sockets, remote server, or real credentials.
/// Replacing this transport with a real client belongs to the host app.
class SimulatedAuthServer extends http.BaseClient {
  final Duration latency;
  final _sessions = <String, String>{};
  int _nextToken = 0;

  SimulatedAuthServer({this.latency = const Duration(milliseconds: 400)});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final payload = bytes.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final authorization = request.headers['authorization'] ?? '';
    final token = authorization.startsWith('Bearer ')
        ? authorization.substring(7)
        : '';
    final customer = _sessions[token];
    final path = request.url.path;
    var status = 200;
    Map<String, dynamic> body;
    if (request.method == 'POST' && path == '/auth/login') {
      final id = payload['customer_id'];
      if (id is! String || id.trim().isEmpty) {
        status = 422;
        body = {'message': 'customer_id is required'};
      } else {
        final newToken = 'demo-token-${++_nextToken}';
        if (token.isNotEmpty) _sessions.remove(token);
        _sessions[newToken] = id.trim();
        body = {'token': newToken, 'customer_id': id.trim()};
      }
    } else if (request.method == 'POST' && path == '/auth/logout') {
      _sessions.remove(token);
      body = {'logged_out': true};
    } else if (request.method == 'GET' && path == '/auth/session') {
      if (customer == null) {
        status = 401;
        body = {'message': 'Session expired or not logged in'};
      } else {
        body = {'customer_id': customer};
      }
    } else if (request.method == 'POST' && path == '/demo/expire') {
      _sessions.remove(token);
      body = {'expired': true};
    } else if (request.method == 'POST' &&
        path == '/demo/switch-customer' &&
        customer != null) {
      final id = payload['customer_id'];
      if (id is! String || id.trim().isEmpty) {
        status = 422;
        body = {'message': 'customer_id is required'};
      } else {
        _sessions[token] = id.trim();
        body = {'customer_id': id.trim()};
      }
    } else {
      status = path == '/demo/switch-customer' ? 401 : 404;
      body = {'message': 'Login first, or check the simulated endpoint'};
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

/// Owns the application's demo token. PAM is never used as the auth source.
class DemoAuthApi {
  final http.Client _client;
  final void Function(String)? onRequest;
  String? _token;

  DemoAuthApi({http.Client? client, this.onRequest})
    : _client = client ?? SimulatedAuthServer();

  Future<Map<String, dynamic>?> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool guestOn401 = false,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('https://demo-auth.invalid$path'),
    )..headers['content-type'] = 'application/json; charset=utf-8';
    if (_token != null) request.headers['authorization'] = 'Bearer $_token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    onRequest?.call('$method $path → ${response.statusCode}');
    if (response.statusCode == 401 && guestOn401) {
      _token = null;
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DemoAuthException(
        response.statusCode,
        json['message']?.toString() ?? 'Request failed',
      );
    }
    return json;
  }

  Future<DemoAuthSession> login(String customerId) async {
    final json = (await _request(
      'POST',
      '/auth/login',
      body: {'customer_id': customerId},
    ))!;
    final session = DemoAuthSession.fromJson(json);
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing demo auth token');
    }
    _token = token;
    return session;
  }

  Future<void> logout() async {
    await _request('POST', '/auth/logout');
    _token = null;
  }

  Future<DemoAuthSession?> loadSession() async {
    final json = await _request('GET', '/auth/session', guestOn401: true);
    return json == null ? null : DemoAuthSession.fromJson(json);
  }

  Future<void> expireOnServer() async {
    await _request('POST', '/demo/expire');
  }

  Future<void> switchCustomerOnServer(String id) async {
    await _request('POST', '/demo/switch-customer', body: {'customer_id': id});
  }

  void close() => _client.close();
}
