import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/consent_message.dart';
import 'package:pam_flutter/response/pam_push_message.dart';
import 'package:pam_flutter/response/pam_response.dart';

import 'demo_auth_controller.dart';
import 'demo_results.dart';
import 'pam_config.dart';

/// PAM is initialized by main; REST auth is restored on startup and resume.
class SdkDemoPage extends StatefulWidget {
  final DemoAuthController auth;
  final String contactingMessageId;
  const SdkDemoPage({
    super.key,
    required this.auth,
    this.contactingMessageId = PamConfigProvider.contactingMessageId,
  });

  @override
  State<SdkDemoPage> createState() => _SdkDemoPageState();
}

class _SdkDemoPageState extends State<SdkDemoPage> with WidgetsBindingObserver {
  final _customer = TextEditingController(text: 'DEMO-CUSTOMER-001');
  final _event = TextEditingController(text: 'view_product');
  final _payload = TextEditingController(
    text: '{"sku":"DEMO-SKU-001","price":590}',
  );
  final _token = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _pageName = TextEditingController(text: 'home');
  final _pushPayload = TextEditingController(
    text: jsonEncode({
      'pam': jsonEncode({
        'flex': '<p>Demo notification</p>',
        'popup_type': 'message',
        'url': '',
      }),
    }),
  );
  final _scroll = ScrollController();
  final _trackingChoices = <ConsentPermissionName, bool>{};
  final _contactingChoices = <ConsentPermissionName, bool>{};
  TrackingConsent? _previousTracking;
  ContactingConsent? _previousContacting;
  List<PamPushMessage> _messages = [];
  PamPushMessage? _convertedPush;
  int _messageIndex = 0;
  int _section = 0;
  String? _locale;
  bool _busy = false;
  String? _draftCustomer;
  bool get _ready => Pam.shared.config != null && widget.auth.canUsePam;
  bool get _blocked => _busy || widget.auth.busy;
  String _lastApi = 'ผลลัพธ์';
  String _result =
      'PAM เริ่มต้นจาก getDevelopConfig แล้ว กำลังโหลด session จำลอง';

  static const _sections = [
    'การเริ่มต้น / Session',
    'Consent',
    'ตัวตนผู้ใช้',
    'Tracking',
    'Push',
    'App Attention / อุปกรณ์',
  ];

  @override
  void initState() {
    super.initState();
    _draftCustomer = widget.auth.session?.customerId;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshFromLifecycle());
    });
  }

  void _authChanged() {
    if (!mounted) return;
    setState(() {
      final customer = widget.auth.session?.customerId;
      if (widget.auth.sessionKnown && customer != _draftCustomer) {
        _draftCustomer = customer;
        _clearContactDrafts();
      }
    });
  }

  Future<void> _refreshFromLifecycle() async {
    try {
      await widget.auth.refreshSession();
      if (mounted && _lastApi == 'ผลลัพธ์') {
        setState(() => _result = formatDemoResult(widget.auth.snapshot));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _lastApi = 'GET /auth/session / sync PAM';
          _result = 'ไม่สำเร็จ: $error';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshFromLifecycle());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_authChanged);
    for (final controller in [
      _customer,
      _event,
      _payload,
      _token,
      _email,
      _mobile,
      _pageName,
      _pushPayload,
    ]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  String _required(TextEditingController controller, String label) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      throw FormatException('กรุณาระบุ $label');
    }
    return value;
  }

  String _id(bool tracking) {
    final value = tracking
        ? Pam.shared.config?.trackingConsentMessageID ?? ''
        : widget.contactingMessageId;
    if (value.trim().isEmpty || value.contains('[') || value == '..') {
      throw FormatException(
        'กำหนด ${tracking ? "trackingMessageId" : "contactingMessageId"} ใน example/lib/pam_config.dart แล้ว restart แอป',
      );
    }
    return value.trim();
  }

  Map<String, dynamic> _json(TextEditingController controller) {
    final value = jsonDecode(controller.text);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('ต้องเป็น JSON object');
    }
    return value;
  }

  Future<void> _run(String name, Future<Object?> Function() action) async {
    if (_blocked) return;
    setState(() {
      _busy = true;
      _lastApi = name;
      _result = 'กำลังทำงาน…';
    });
    try {
      final value = await action();
      if (value is PamResponse && value.error != null) {
        throw StateError('${value.error!.code}: ${value.error!.errorMessage}');
      }
      if (value is SubmitConsentResult && value.consentID.isEmpty) {
        throw StateError('ไม่พบ consent ID ที่บันทึกสำเร็จ กรุณาดู SDK log');
      }
      if (mounted) {
        setState(
          () => _result = value == null
              ? 'API คืน null หรือไม่มีข้อมูล ตรวจสอบการตั้งค่าและ SDK log'
              : formatDemoResult(value),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _result = 'ไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  // NEW API: build a complete selection, or edit an existing immutable snapshot.
  TrackingConsent _trackingSelection() {
    bool allow(ConsentPermissionName name) => _trackingChoices[name] ?? false;
    final previous = _previousTracking;
    if (previous != null) {
      return previous.copyWith(
        preferencesCookies: allow(ConsentPermissionName.preferencesCookies),
        analyticsCookies: allow(ConsentPermissionName.analyticsCookies),
        marketingCookies: allow(ConsentPermissionName.marketingCookies),
        socialMediaCookies: allow(ConsentPermissionName.socialMediaCookies),
      );
    }
    return TrackingConsent(
      messageId: _id(true),
      termsAndConditions: true,
      privacyOverview: true,
      necessaryCookies: true,
      preferencesCookies: allow(ConsentPermissionName.preferencesCookies),
      analyticsCookies: allow(ConsentPermissionName.analyticsCookies),
      marketingCookies: allow(ConsentPermissionName.marketingCookies),
      socialMediaCookies: allow(ConsentPermissionName.socialMediaCookies),
    );
  }

  ContactingConsent _contactingSelection() {
    bool allow(ConsentPermissionName name) => _contactingChoices[name] ?? false;
    final previous = _previousContacting;
    if (previous != null) {
      return previous.copyWith(
        email: allow(ConsentPermissionName.email),
        sms: allow(ConsentPermissionName.sms),
        line: allow(ConsentPermissionName.line),
        facebookMessenger: allow(ConsentPermissionName.facebookMessenger),
        pushNotification: allow(ConsentPermissionName.pushNotification),
      );
    }
    return ContactingConsent(
      messageId: _id(false),
      termsAndConditions: true,
      privacyOverview: true,
      email: allow(ConsentPermissionName.email),
      sms: allow(ConsentPermissionName.sms),
      line: allow(ConsentPermissionName.line),
      facebookMessenger: allow(ConsentPermissionName.facebookMessenger),
      pushNotification: allow(ConsentPermissionName.pushNotification),
    );
  }

  Future<Object?> _editPrevious(bool tracking) async {
    if (tracking) {
      _previousTracking = null;
      _trackingChoices.clear();
    } else {
      _previousContacting = null;
      _contactingChoices.clear();
    }
    final status = await Pam.loadConsentStatus(_id(tracking));
    if (tracking) {
      final current = TrackingConsent.fromStatus(status);
      _previousTracking = current;
      _trackingChoices.addAll({
        ConsentPermissionName.preferencesCookies: current.preferencesCookies,
        ConsentPermissionName.analyticsCookies: current.analyticsCookies,
        ConsentPermissionName.marketingCookies: current.marketingCookies,
        ConsentPermissionName.socialMediaCookies: current.socialMediaCookies,
      });
    } else {
      final current = ContactingConsent.fromStatus(status);
      _previousContacting = current;
      _contactingChoices.addAll({
        ConsentPermissionName.email: current.email,
        ConsentPermissionName.sms: current.sms,
        ConsentPermissionName.line: current.line,
        ConsentPermissionName.facebookMessenger: current.facebookMessenger,
        ConsentPermissionName.pushNotification: current.pushNotification,
      });
    }
    return {
      'next_step':
          'แก้ switch แล้วกด saveConsent เพื่อส่งผ่าน copyWith โดยเก็บค่าอื่นจากสถานะเดิม',
      'status': demoValue(status),
    };
  }

  Future<Object?> _showConsent(bool tracking) async {
    final result = await Pam.showConsent(
      context,
      messageId: _id(tracking),
      locale: _locale == null
          ? null
          : Locale(_locale == 'jp' ? 'ja' : _locale!),
    );
    // A built-in screen may have saved newer choices; discard the old draft.
    if (result.outcome == PamConsentOutcome.saved) {
      final choices = tracking ? _trackingChoices : _contactingChoices;
      final fields = result.selection!.toFormFields();
      for (final name in ConsentPermissionName.values) {
        if (fields['_allow_${name.key}'] is bool) {
          choices[name] = fields['_allow_${name.key}'] as bool;
        }
      }
      if (tracking) {
        _previousTracking = null;
      } else {
        _previousContacting = null;
      }
    }
    return result;
  }

  // EXISTING API: load the displayed version and fill each permission explicitly.
  Future<ConsentMessage> _legacyMessage(bool tracking) async {
    final message = await Pam.loadConsentMessage(_id(tracking));
    if (message == null) throw StateError('โหลด Consent Message ไม่สำเร็จ');
    final expected = tracking ? ConsentType.tracking : ConsentType.contacting;
    if (message.type != expected) {
      throw StateError('Consent ID มีประเภทไม่ตรงกับแบบที่เลือก');
    }
    final choices = tracking ? _trackingChoices : _contactingChoices;
    for (final permission in message.permission) {
      message.setPermission(
        permission.name,
        permission.require || (choices[permission.name] ?? false),
      );
    }
    final validation = message.validate();
    if (!validation.isValid) {
      throw StateError(validation.errorMessage ?? 'Invalid consent');
    }
    return message;
  }

  Future<Object?> _loadNotifications(
    Future<List<PamPushMessage>?> Function() load,
  ) async {
    final messages = await load();
    if (messages == null) throw StateError('โหลดประวัติไม่สำเร็จ');
    _messages = messages;
    _messageIndex = 0;
    return messages;
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextField(
      key: ValueKey('field-$key'),
      controller: controller,
      enabled: !_blocked,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _action(
    String id,
    String api,
    String description,
    Future<Object?> Function() action, {
    bool needsInit = true,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          key: ValueKey('action-$id'),
          onPressed: !_blocked && enabled && (!needsInit || _ready)
              ? () => _run(api, action)
              : null,
          child: Text(api, textAlign: TextAlign.center),
        ),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _heading(String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(body),
      ],
    ),
  );

  List<Widget> _overview() => [
    _heading(
      'เริ่มต้นอัตโนมัติจาก Code',
      'แก้ example/lib/pam_config.dart แล้ว restart แอป main เรียก getDevelopConfig และ await Pam.initialize ก่อน runApp ไม่มีฟอร์มแก้ config',
    ),
    SelectableText(
      formatDemoResult({
        'server': Pam.shared.config?.pamServer,
        'public_database': Pam.shared.config?.publicDBAlias,
        'login_database': Pam.shared.config?.loginDBAlias,
        'tracking_consent_id': Pam.shared.config?.trackingConsentMessageID,
        'contacting_consent_id': widget.contactingMessageId,
        'enable_log': Pam.shared.config?.enableLog,
        'block_events_if_no_consent': Pam.shared.config?.blockEventsIfNoConsent,
      }),
    ),
    _heading(
      'App session / identityProvider',
      'REST API จำลองใช้ session ของแอปเอง ไม่อ่านตัวตนจาก PAM มาแทนระบบ login',
    ),
    SelectableText(formatDemoResult(widget.auth.snapshot)),
    _action(
      'refresh-session',
      'GET /auth/session → sync PAM',
      'จำลองกลับเข้าแอป ใช้เส้นทางเดียวกับ AppLifecycleState.resumed',
      () async {
        await widget.auth.refreshSession();
        return widget.auth.snapshot;
      },
      needsInit: false,
    ),
    _action(
      'sync-identity',
      'Sync PAM กับ session ล่าสุด',
      'ลองแจ้ง PAM ใหม่เมื่อ REST สำเร็จแต่ PAM ล้มเหลว โดยไม่ย้อน session ของแอป',
      () async {
        await widget.auth.synchronizePam();
        return widget.auth.snapshot;
      },
      needsInit: false,
      enabled: widget.auth.sessionKnown,
    ),
    _action(
      'reset',
      'Pam.reset → sync session ปัจจุบัน',
      'ล้างข้อมูล PAM ในเครื่อง แล้วแจ้งตัวตนตาม app session เดิม ไม่ใช่ logout ระบบสมาชิก',
      () async {
        await Pam.reset();
        _clearContactDrafts();
        if (widget.auth.sessionKnown) await widget.auth.synchronizePam();
        return widget.auth.snapshot;
      },
      needsInit: false,
    ),
  ];

  List<Widget> _consentType(bool tracking) {
    final type = tracking ? 'Tracking' : 'Contacting';
    final prefix = tracking ? 'tracking' : 'contacting';
    final choices = tracking ? _trackingChoices : _contactingChoices;
    final names = tracking
        ? ConsentPermissionName.values.take(7)
        : [
            ConsentPermissionName.termsAndConditions,
            ConsentPermissionName.privacyOverview,
            ...ConsentPermissionName.values.skip(7),
          ];
    return [
      _heading(
        type,
        'ตัวเลือกด้านล่างเป็นข้อมูลทดสอบของ API แบบกำหนดเอง ตรวจรายละเอียด Consent ก่อนกดยืนยัน',
      ),
      _action(
        'show-$prefix',
        'Pam.showConsent — $type',
        'โหลด status และข้อความจริง แสดง UI กลาง แล้วให้ผู้ใช้เลือกก่อนบันทึก',
        () => _showConsent(tracking),
      ),
      _action(
        'message-$prefix',
        'Pam.loadConsentMessage — $type',
        'โหลดข้อความ เวอร์ชัน ภาษา และรายการที่เปิดใช้งาน',
        () => Pam.loadConsentMessage(_id(tracking)),
      ),
      _action(
        'status-$prefix',
        'Pam.loadConsentStatus — $type',
        'โหลดสถานะเดิม หากไม่มี contact จะได้สถานะที่ต้องทบทวนและไม่มี consent ID',
        () => Pam.loadConsentStatus(_id(tracking)),
      ),
      _action(
        'edit-$prefix',
        '${type}Consent.fromStatus → copyWith',
        'โหลดค่าลง switch หากต้องทบทวนหรือยังไม่มี consent ให้ใช้ showConsent แทน',
        () => _editPrevious(tracking),
      ),
      for (final name in names)
        SwitchListTile(
          key: ValueKey('choice-$prefix-${name.key}'),
          title: Text(name.nameStr),
          subtitle: name.index < 3 ? const Text('รายการบังคับ เปิดเสมอ') : null,
          value: name.index < 3 || (choices[name] ?? false),
          onChanged: _blocked || name.index < 3
              ? null
              : (value) => setState(() => choices[name] = value),
        ),
      _action(
        'save-$prefix',
        'Pam.saveConsent — $type',
        'กดเพื่อยืนยันและบันทึกค่าจาก switch เท่านั้น รายการเสริมเริ่มเป็นปิด',
        () => Pam.saveConsent(
          tracking ? _trackingSelection() : _contactingSelection(),
        ),
      ),
      _action(
        'all-$prefix',
        tracking
            ? 'Pam.allowAllTrackingConsent'
            : 'Pam.allowAllContactingConsent',
        'กดปุ่มนี้คือยืนยันยอมรับทุกรายการในเวอร์ชัน latest รวมรายการที่ switch ปิดไว้',
        () => tracking
            ? Pam.allowAllTrackingConsent(_id(true))
            : Pam.allowAllContactingConsent(_id(false)),
      ),
      _action(
        'submit-$prefix',
        'Pam.submitConsent — $type (API เดิม)',
        'โหลด message แล้ว setPermission ตาม switch ก่อน submit โดยใช้เวอร์ชันที่โหลดมา',
        () async => Pam.submitConsent(await _legacyMessage(tracking)),
      ),
    ];
  }

  List<Widget> _consents() => [
    _heading(
      'Consent API',
      'กำหนด Tracking / Contacting ID ใน pam_config.dart ก่อน ตัวอย่างนี้ไม่ยอมรับทั้งหมดโดยอัตโนมัติ',
    ),
    DropdownButtonFormField<String>(
      key: const ValueKey('consent-locale'),
      isExpanded: true,
      initialValue: _locale ?? 'auto',
      decoration: const InputDecoration(
        labelText: 'ภาษาเริ่มต้นของ showConsent',
      ),
      items: const [
        DropdownMenuItem(value: 'auto', child: Text('อัตโนมัติ: th → en → jp')),
        DropdownMenuItem(value: 'th', child: Text('ไทย')),
        DropdownMenuItem(value: 'en', child: Text('English')),
        DropdownMenuItem(value: 'jp', child: Text('日本語')),
      ],
      onChanged: _blocked
          ? null
          : (value) => setState(() => _locale = value == 'auto' ? null : value),
    ),
    ..._consentType(true),
    ..._consentType(false),
    _heading(
      'หลายข้อความ / API เดิม',
      'ใช้ตัวเลือกจาก switch ของทั้งสองประเภท',
    ),
    _action(
      'messages',
      'Pam.loadConsentMessages',
      'โหลดทั้ง Tracking และ Contacting พร้อมกัน',
      () => Pam.loadConsentMessages([_id(true), _id(false)]),
    ),
    _action(
      'submits',
      'Pam.submitConsents',
      'ส่งทั้งสองข้อความ ต้องโหลดได้ครบก่อนจึงเริ่ม submit',
      () async {
        final tracking = await _legacyMessage(true);
        final contacting = await _legacyMessage(false);
        return Pam.submitConsents({
          _id(true): tracking,
          _id(false): contacting,
        });
      },
    ),
    _action(
      'allow-legacy',
      'Pam.allowConsent (API เดิม)',
      'กดปุ่มนี้คือยืนยันยอมรับทุกรายการของ Tracking Consent ไม่ใช้ switch',
      () => Pam.allowConsent(_id(true)),
    ),
  ];

  void _clearContactDrafts() {
    _previousTracking = null;
    _previousContacting = null;
    _trackingChoices.clear();
    _contactingChoices.clear();
    _messages = [];
    _convertedPush = null;
  }

  List<Widget> _identity() => [
    _heading(
      'Login / Logout จำลอง',
      'กรอก customer ID เอง REST API จำลองอยู่ในแอป ส่วนการแจ้ง PAM ใช้ server จริงจาก getDevelopConfig',
    ),
    SelectableText(
      formatDemoResult(widget.auth.snapshot),
      key: const ValueKey('auth-state'),
    ),
    _field('customer', 'Customer ID', _customer),
    _action(
      'login',
      'POST /auth/login → Pam.userLogin',
      'REST สำเร็จ → บันทึก app session → แจ้ง PAM หาก PAM ล้มเหลวยังคง session ของแอปไว้',
      () async {
        await widget.auth.login(_required(_customer, 'Customer ID'));
        return widget.auth.snapshot;
      },
      needsInit: false,
    ),
    _action(
      'logout',
      'POST /auth/logout → Pam.userLogout',
      'REST logout สำเร็จก่อน → ล้าง app session → แจ้ง PAM',
      () async {
        await widget.auth.logout();
        return widget.auth.snapshot;
      },
      needsInit: false,
    ),
    _action(
      'customer-id',
      'Pam.getCustID / app session',
      'เปรียบเทียบตัวตนที่ SDK เก็บไว้กับ session ของแอป',
      () async => {
        'sdk_customer_id': await Pam.getCustID(),
        'app': widget.auth.snapshot,
      },
      needsInit: false,
    ),
    _heading(
      'จำลอง session เปลี่ยนบน server',
      'Login ก่อน แล้วจำลอง session หมดอายุหรือเปลี่ยนบัญชี จากนั้น refresh ตาม lifecycle หรือทดลอง mismatch',
    ),
    _action(
      'expire-session',
      'จำลอง server: session หมดอายุ',
      'ลบ session เฉพาะบน server จำลอง ค่าในแอปยังไม่เปลี่ยนจนกว่าจะ GET session',
      () async {
        await widget.auth.expireOnServer();
        return 'จำลอง session หมดอายุแล้ว ลอง refresh หรือกลับเข้าแอป';
      },
      needsInit: false,
      enabled: widget.auth.session != null,
    ),
    _action(
      'switch-server',
      'จำลอง server: เปลี่ยน Customer ID',
      'ใช้ Customer ID ในช่องด้านบนเปลี่ยนบัญชีเฉพาะบน server จำลอง',
      () async {
        await widget.auth.switchCustomerOnServer(
          _required(_customer, 'Customer ID'),
        );
        return 'เปลี่ยนบัญชีบน server จำลองแล้ว ลอง refresh';
      },
      needsInit: false,
      enabled: widget.auth.session != null,
    ),
    _action(
      'refresh-auth',
      'GET /auth/session → sync PAM (resume)',
      'ใช้ flow เดียวกับการเปิดแอปและการกลับเข้าแอปจริง',
      () async {
        await widget.auth.refreshSession();
        return widget.auth.snapshot;
      },
      needsInit: false,
    ),
    _action(
      'load-session-only',
      'ทดสอบ: โหลด session แต่ยังไม่แจ้ง PAM',
      'จงใจจำลองแอปลืมแจ้ง login/logout เพื่อทดสอบ onIdentityMismatch เท่านั้น',
      () async {
        await widget.auth.loadSessionWithoutPamForDemo();
        return widget.auth.snapshot;
      },
      needsInit: false,
    ),
    _action(
      'probe-identity',
      'Pam.track(test) → ตรวจ identity mismatch',
      'ต้องเคย Login ให้ SDK มี identity ก่อน Event ที่ mismatch ถูกทิ้ง Callback sync ตัวตนใหม่ และไม่ replay event',
      () => Pam.track('test', payload: {'demo': 'identity-mismatch-probe'}),
      needsInit: false,
      enabled: widget.auth.sessionKnown,
    ),
    _action(
      'sync-auth',
      'Sync PAM กับ session ล่าสุด',
      'ใช้เพื่อ retry หรือออกจากโหมดทดสอบ mismatch',
      () async {
        await widget.auth.synchronizePam();
        return widget.auth.snapshot;
      },
      needsInit: false,
      enabled: widget.auth.sessionKnown,
    ),
    _heading(
      'ลำดับเหตุการณ์ Auth / PAM',
      'แสดง HTTP จำลอง การเปลี่ยน session และ callback ล่าสุด',
    ),
    SelectableText(
      widget.auth.events.reversed.join('\n'),
      key: const ValueKey('auth-events'),
    ),
  ];

  List<Widget> _tracking() => [
    _heading(
      'ส่ง Event',
      'เริ่มจากยืนยัน Tracking Consent ก่อน แล้วส่งชื่อ event กับ JSON payload ที่ต้องการทดสอบ',
    ),
    _field('event', 'Event name', _event),
    _field('payload', 'Payload (JSON object)', _payload, lines: 3),
    _action(
      'track',
      'Pam.track',
      'ตัวอย่างรอผลเพื่อแสดงบนหน้าจอ หากถูก block เพราะ consent จะคืน null',
      () =>
          Pam.track(_required(_event, 'Event name'), payload: _json(_payload)),
    ),
    _action(
      'log',
      'Pam.log',
      'เขียน log ตัวอย่าง ดูใน Android Studio / Xcode เมื่อ enableLog เปิดอยู่',
      () async {
        Pam.log(
          ['Demo tracking log'],
          category: PamLogCategory.tracking,
          level: PamLogLevel.info,
        );
        return 'เรียก Pam.log แล้ว ดูผลในเครื่องมือของแพลตฟอร์ม';
      },
    ),
  ];

  PamPushMessage _selectedPush() {
    if (_messages.isEmpty) {
      throw StateError('กรุณาโหลดประวัติและเลือกข้อความก่อน');
    }
    return _messages[_messageIndex];
  }

  List<Widget> _push() => [
    _heading(
      'Push Notification',
      'แอปต้องขอสิทธิ์และรับ device token จากผู้ให้บริการ Push เอง ตัวอย่างนี้ไม่ได้ตั้งค่า Firebase ให้',
    ),
    _field('push-token', 'Device token จริงจากอุปกรณ์ทดสอบ', _token),
    _action(
      'push-token',
      'Pam.setPushNotificationToken',
      'ส่ง token ให้ PAM เรียกซ้ำเมื่อ token เปลี่ยน',
      () => Pam.setPushNotificationToken(_required(_token, 'Device token')),
    ),
    _action(
      'push-history',
      'Pam.loadPushNotifications',
      'โหลดประวัติของ contact ปัจจุบัน ไม่มีการ trackRead ตอนโหลด',
      () => _loadNotifications(Pam.loadPushNotifications),
    ),
    _field('push-email', 'Email สำหรับค้นหาประวัติ', _email),
    _action(
      'push-email',
      'Pam.loadPushNotificationsFromEmail',
      'ค้นหาด้วย email ที่ระบุในฐานข้อมูลปัจจุบัน',
      () => _loadNotifications(
        () => Pam.loadPushNotificationsFromEmail(_required(_email, 'Email')),
      ),
    ),
    _field('push-mobile', 'หมายเลขโทรศัพท์สำหรับค้นหาประวัติ', _mobile),
    _action(
      'push-mobile',
      'Pam.loadPushNotificationsFromMobile',
      'ค้นหาด้วยหมายเลขโทรศัพท์',
      () => _loadNotifications(
        () => Pam.loadPushNotificationsFromMobile(_required(_mobile, 'Mobile')),
      ),
    ),
    _action(
      'push-customer',
      'Pam.loadPushNotificationsFromCustomerID',
      'ใช้ Customer ID จากหมวดตัวตนผู้ใช้',
      () => _loadNotifications(
        () => Pam.loadPushNotificationsFromCustomerID(
          _required(_customer, 'Customer ID'),
        ),
      ),
    ),
    if (_messages.isNotEmpty)
      DropdownButtonFormField<int>(
        key: ValueKey(
          'push-selection-${_messages.length}-${identityHashCode(_messages)}',
        ),
        initialValue: _messageIndex,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'เลือกข้อความที่จะส่ง read / click tracking',
        ),
        items: [
          for (var i = 0; i < _messages.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text(
                '${i + 1}. ${_messages[i].title}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: _blocked
            ? null
            : (value) => setState(() => _messageIndex = value!),
      ),
    _action(
      'push-read',
      'PamPushMessage.trackRead',
      'กดเมื่อผู้ใช้เปิดอ่านข้อความ ส่ง read pixel ของข้อความที่เลือก',
      () async {
        _selectedPush().trackRead();
        return 'เรียก trackRead แล้ว (ส่งแบบไม่รอผล ดู SDK log)';
      },
      enabled: _messages.isNotEmpty,
    ),
    _action(
      'push-click',
      'PamPushMessage.trackPushUrlClick',
      'กดเมื่อผู้ใช้คลิกลิงก์ ส่ง click pixel ของข้อความที่เลือก',
      () async {
        _selectedPush().trackPushUrlClick();
        return 'เรียก trackPushUrlClick แล้ว (ส่งแบบไม่รอผล ดู SDK log)';
      },
      enabled: _messages.isNotEmpty,
    ),
    _heading(
      'แปลง Payload จาก Push',
      'ใช้ JSON ของ notification data โดย key pam ต้องเป็น JSON string การแปลงไม่ส่ง read pixel',
    ),
    _field(
      'push-json',
      'Notification data (JSON object)',
      _pushPayload,
      lines: 4,
    ),
    _action(
      'is-pam-push',
      'Pam.isPushNotiFromPam',
      'ตรวจว่ามี key pam หรือไม่',
      () async => Pam.isPushNotiFromPam(_json(_pushPayload)),
      needsInit: false,
    ),
    _action(
      'convert-push',
      'Pam.convertToPamPushMessage',
      'แปลงข้อมูลจาก notification data เป็น PamPushMessage',
      () async {
        _convertedPush = Pam.convertToPamPushMessage(_json(_pushPayload));
        return _convertedPush;
      },
      needsInit: false,
    ),
  ];

  List<Widget> _device() => [
    _heading(
      'App Attention',
      'ต้องมี Campaign ที่เข้าเงื่อนไข pageName และ contact นี้ ไม่แสดงอัตโนมัติตอนเปิดแอป',
    ),
    _field('page-name', 'Page name', _pageName),
    _action(
      'attention',
      'Pam.appAttention',
      'ตรวจและแสดง popup จาก Campaign หากไม่มีข้อความที่เข้าเงื่อนไขจะไม่แสดง',
      () async {
        await Pam.appAttention(
          context,
          pageName: _required(_pageName, 'Page name'),
          actionButtonLabel: 'ดูรายละเอียด',
          actionButtonColor: '#14203D',
          actionButtonTextColor: '#FFFFFF',
          onBannerClick: (data) {
            debugPrint('App Attention click: $data');
            return false; // Let the SDK open the configured URL.
          },
        );
        return 'จบการตรวจสอบ / ปิด popup แล้ว หากไม่ปรากฏให้ตรวจ Campaign และ SDK log';
      },
    ),
    _heading(
      'อุปกรณ์และ ATT',
      'ATT เป็นสิทธิ์ของ iOS แยกจาก PAM Consent บนแพลตฟอร์มอื่นจะคืน notSupported',
    ),
    _action(
      'platform',
      'Pam.getPlatformVersion',
      'ตรวจเวอร์ชันแพลตฟอร์มของอุปกรณ์',
      Pam.getPlatformVersion,
      needsInit: false,
    ),
    _action(
      'device-id',
      'Pam.identifierForVendor',
      'อ่าน identifier ของอุปกรณ์ตามแพลตฟอร์ม',
      Pam.identifierForVendor,
      needsInit: false,
    ),
    _action(
      'att-status',
      'Pam.trackingAuthorizationStatus',
      'ตรวจสถานะ ATT โดยไม่เปิดคำขอสิทธิ์',
      () async => Pam.trackingAuthorizationStatus,
      needsInit: false,
    ),
    _action(
      'att-request',
      'Pam.requestTrackingAuthorization',
      'กดเพื่อเปิดคำขอสิทธิ์ ATT บน iOS ต้องตั้งค่า Info.plist ก่อน',
      Pam.requestTrackingAuthorization,
      needsInit: false,
    ),
    _action(
      'on-token',
      'Pam.onToken',
      'ลงทะเบียน callback เพื่อแสดง token เมื่อ native ส่งมา ไม่ได้ขอสิทธิ์ Push',
      () async {
        Pam.onToken((token) {
          if (mounted) {
            setState(() {
              _lastApi = 'Pam.onToken callback';
              _result = token;
            });
          }
        });
        return 'ลงทะเบียน callback แล้ว รอ token จาก native';
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = switch (_section) {
      0 => _overview(),
      1 => _consents(),
      2 => _identity(),
      3 => _tracking(),
      4 => _push(),
      _ => _device(),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('PAM SDK Examples')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            key: const ValueKey('demo-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _ready
                    ? 'พร้อมทดสอบ API'
                    : widget.auth.busy
                    ? 'กำลังโหลด session / sync PAM…'
                    : 'session ยังไม่พร้อม หรือรอ sync PAM',
                key: const ValueKey('demo-status'),
              ),
              if (_blocked) const LinearProgressIndicator(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _lastApi,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _result,
                            key: const ValueKey('demo-result'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: const ValueKey('demo-section'),
                initialValue: _section,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'เลือกหมวด API',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var i = 0; i < _sections.length; i++)
                    DropdownMenuItem(value: i, child: Text(_sections[i])),
                ],
                onChanged: _blocked
                    ? null
                    : (value) => setState(() => _section = value!),
              ),
              ...content,
            ],
          ),
        ),
      ),
    );
  }
}
