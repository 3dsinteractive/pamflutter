import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/pam_response.dart';

import 'demo_auth_api.dart';

/// Application auth state and lifecycle. The provider never performs HTTP.
class DemoAuthController extends ChangeNotifier {
  late final DemoAuthApi api;
  DemoAuthSession? session;
  bool sessionKnown = false;
  bool requiresPamSync = false;
  bool _loadingSession = true;
  bool _pamSyncFailed = false;
  int _pending = 0;
  int _sequence = 0;
  Future<void>? _tail;
  Future<void>? _refresh;
  final _events = <String>[];

  DemoAuthController({DemoAuthApi? api}) {
    this.api = api ?? DemoAuthApi(onRequest: record);
  }

  Future<void> get whenIdle => _tail ?? Future<void>.value();
  bool get busy => _pending > 0;
  List<String> get events => List.unmodifiable(_events);
  bool get canUsePam => sessionKnown && !requiresPamSync && !busy;

  Map<String, dynamic> get snapshot => {
    'app_state': identityProvider().type.name,
    'customer_id': session?.customerId,
    'session_known': sessionKnown,
    'requires_pam_sync': requiresPamSync,
    'busy': busy,
  };

  void record(String message) {
    _events.add('${++_sequence}. $message');
    if (_events.length > 40) _events.removeAt(0);
    notifyListeners();
  }

  PamUserState identityProvider() {
    if (_loadingSession || !sessionKnown) return const PamUserState.unknown();
    final current = session;
    return current == null
        ? const PamUserState.anonymous()
        : PamUserState.identified(current.customerId);
  }

  Future<T> _operation<T>(
    String name,
    Future<T> Function() body, {
    bool loadingSession = false,
  }) {
    _pending++;
    notifyListeners();
    final result = (_tail ?? Future<void>.value()).then((_) async {
      _loadingSession = loadingSession;
      record(name);
      try {
        return await body();
      } catch (error) {
        record('ไม่สำเร็จ: $error');
        rethrow;
      } finally {
        _loadingSession = false;
        _pending--;
        notifyListeners();
      }
    });
    // A failed REST/PAM call must not poison later operations.
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  void _publish(DemoAuthSession? value) {
    session = value;
    sessionKnown = true;
    requiresPamSync = true;
    _loadingSession = false;
    record('App session → ${value?.customerId ?? "anonymous"}');
  }

  Future<void> _syncPamNow() async {
    if (!sessionKnown) throw StateError('โหลด session ให้สำเร็จก่อน sync PAM');
    final target = session?.customerId;
    final current = await Pam.getCustID();
    if (current != target || _pamSyncFailed) {
      requiresPamSync = true;
      _pamSyncFailed = true;
      if (target == null) {
        record('Pam.userLogout()');
        await Pam.userLogout();
      } else {
        record('Pam.userLogin($target)');
        final response = await Pam.userLogin(target);
        _checkPam(response);
      }
    }
    if (await Pam.getCustID() != target) {
      throw StateError('PAM identity ยังไม่ตรงกับ app session');
    }
    _pamSyncFailed = false;
    requiresPamSync = false;
    record('PAM identity ตรงกับ app session แล้ว');
  }

  void _checkPam(PamResponse response) {
    if (response.error != null) {
      throw StateError(
        'PAM ${response.error!.code}: ${response.error!.errorMessage}',
      );
    }
  }

  Future<void> login(String customerId) =>
      _operation('Login ผ่าน REST API จำลอง', () async {
        _publish(await api.login(customerId));
        await _syncPamNow();
      }, loadingSession: true);

  Future<void> logout() => _operation('Logout ผ่าน REST API จำลอง', () async {
    await api.logout();
    _publish(null);
    await _syncPamNow();
  }, loadingSession: true);

  Future<void> _loadSession({required bool synchronizePam}) async {
    try {
      _publish(await api.loadSession());
    } catch (_) {
      // A network/500 error is unknown, not a logout. HTTP 401 means guest.
      sessionKnown = false;
      requiresPamSync = true;
      rethrow;
    }
    if (synchronizePam) {
      await _syncPamNow();
    } else {
      requiresPamSync =
          _pamSyncFailed || (await Pam.getCustID()) != session?.customerId;
      record('โหมดทดสอบ: อ่าน session แล้ว แต่ยังไม่แจ้ง PAM');
    }
  }

  /// Cold start and real/simulated resume use this same path.
  Future<void> refreshSession() {
    final existing = _refresh;
    if (existing != null) return existing;
    final pending = _operation(
      'เริ่มโหลด session (identityProvider = unknown)',
      () => _loadSession(synchronizePam: true),
      loadingSession: true,
    );
    _refresh = pending;
    pending.then(
      (_) {
        _refresh = null;
      },
      onError: (Object error, StackTrace stack) {
        _refresh = null;
      },
    );
    return pending;
  }

  Future<void> loadSessionWithoutPamForDemo() => _operation(
    'จำลองแอปลืมแจ้ง PAM',
    () => _loadSession(synchronizePam: false),
    loadingSession: true,
  );

  Future<void> synchronizePam() =>
      _operation('Sync PAM กับ session ล่าสุด', _syncPamNow);

  Future<void> onIdentityMismatch(PamIdentityMismatch mismatch) async {
    record(
      'onIdentityMismatch: ${mismatch.oldIdentity?.value} → ${mismatch.newIdentity?.value}, event=${mismatch.event}',
    );
    // Queue behind any pending REST operation, then read current app state again.
    // Never replay the dropped event or blindly use an old callback identity.
    await synchronizePam();
  }

  Future<void> expireOnServer() =>
      _operation('จำลอง session หมดอายุบน server', api.expireOnServer);
  Future<void> switchCustomerOnServer(String id) => _operation(
    'จำลอง server เปลี่ยนบัญชีเป็น $id',
    () => api.switchCustomerOnServer(id),
  );

  @override
  void dispose() {
    api.close();
    super.dispose();
  }
}
