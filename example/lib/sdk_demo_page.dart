import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import 'package:pam_flutter/response/customer_consent_status.dart';
import 'package:pam_flutter/response/pam_response.dart';

import 'demo_auth_controller.dart';
import 'pam_config.dart';

/// A small shopping app that demonstrates the guest-to-member journey.
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
  final _scroll = ScrollController();
  final _pageName = TextEditingController(text: 'home');
  bool _busy = false;
  bool _viewingProduct = false;
  bool _favorite = false;
  String? _customerId;
  int _resetRevision = 0;
  String _notice = 'ลองดูสินค้าก่อนได้ โดยยังไม่ต้องเข้าสู่ระบบ';
  bool _failed = false;
  final _actionResults = <String, ({String message, bool failed})>{};
  final _actionResultKeys = <String, GlobalKey>{};
  CustomerConsentStatus? _trackingStatus;
  CustomerConsentStatus? _contactingStatus;

  bool get _member => widget.auth.session != null;
  bool get _blocked => _busy || widget.auth.busy;
  bool get _ready => Pam.shared.config != null && widget.auth.canUsePam;

  @override
  void initState() {
    super.initState();
    _customerId = widget.auth.session?.customerId;
    _resetRevision = widget.auth.resetRevision;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshSession());
    });
  }

  void _authChanged() {
    if (!mounted) return;
    setState(() {
      if (_resetRevision != widget.auth.resetRevision) {
        _resetRevision = widget.auth.resetRevision;
        _clearDemoState();
      }
      final next = widget.auth.session?.customerId;
      if (widget.auth.sessionKnown && next != _customerId) {
        _customerId = next;
        // Never display consent from a different identity as the current one.
        _trackingStatus = null;
        _contactingStatus = null;
        _actionResults.clear();
        _notice = next == null
            ? 'กลับมาเป็นผู้เยี่ยมชมแล้ว ลองใช้งานต่อได้'
            : 'เข้าสู่ระบบแล้ว ตรวจสอบ Consent ของบัญชีนี้ได้ด้านล่าง';
        _failed = false;
      }
    });
  }

  Future<void> _refreshSession() async {
    try {
      await widget.auth.refreshSession();
    } catch (_) {
      if (mounted) {
        setState(() {
          _notice = 'ตรวจสอบ session ไม่สำเร็จ กรุณาลองเชื่อมต่ออีกครั้ง';
          _failed = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.auth.removeListener(_authChanged);
    _customer.dispose();
    _pageName.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(
    String command,
    Future<String> Function() action, {
    String? resultSection,
  }) async {
    if (_blocked) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() {
      _busy = true;
      _failed = false;
      if (resultSection == null) {
        _notice = 'กำลังทำงาน…';
      } else {
        _actionResults[resultSection] = (message: 'กำลังทำงาน…', failed: false);
      }
    });
    Pam.log(['Example button: $command'], category: PamLogCategory.general);
    try {
      final message = await action();
      if (mounted) _report(message, resultSection: resultSection);
    } catch (error) {
      Pam.log(
        ['Example failed: $command', error],
        category: PamLogCategory.general,
        level: PamLogLevel.error,
      );
      if (mounted) {
        _report(
          'ทำรายการไม่สำเร็จ กรุณาลองใหม่ ดูรายละเอียดใน Log',
          failed: true,
          resultSection: resultSection,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(String message, {bool failed = false, String? resultSection}) {
    if (resultSection != null) {
      setState(
        () =>
            _actionResults[resultSection] = (message: message, failed: failed),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = _actionResultKeys[resultSection]?.currentContext;
        if (target != null) {
          unawaited(
            Scrollable.ensureVisible(
              target,
              alignment: 0.5,
              duration: const Duration(milliseconds: 200),
            ),
          );
        }
      });
      return;
    }
    setState(() {
      _notice = message;
      _failed = failed;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _consentId(bool tracking) {
    final id = tracking
        ? Pam.shared.config?.trackingConsentMessageID ?? ''
        : widget.contactingMessageId;
    if (id.trim().isEmpty || id.contains('[') || id == '..') {
      throw StateError('กำหนด Consent Message ID ใน pam_config.dart ก่อน');
    }
    return id.trim();
  }

  Future<String> _checkConsent(bool tracking) async {
    final status = await Pam.loadConsentStatus(_consentId(tracking));
    if (status.error != null) {
      throw StateError(status.error!.errorMessage ?? 'โหลด Consent ไม่สำเร็จ');
    }
    if (mounted) {
      setState(() {
        if (tracking) {
          _trackingStatus = status;
        } else {
          _contactingStatus = status;
        }
      });
    }
    return 'ตรวจสอบ Consent แล้ว ดูสถานะและตัวเลือกด้านล่าง';
  }

  Future<String> _showConsent(bool tracking) async {
    final result = await Pam.showConsent(
      context,
      messageId: _consentId(tracking),
    );
    if (result.outcome == PamConsentOutcome.dismissed) {
      return 'ปิดหน้าต่างแล้ว ยังไม่ได้เปลี่ยน Consent';
    }
    // Submission succeeded; a failed status refresh must not imply save failed.
    if (mounted) {
      setState(() {
        if (tracking) {
          _trackingStatus = null;
        } else {
          _contactingStatus = null;
        }
      });
    }
    try {
      await _checkConsent(tracking);
      return 'บันทึก Consent แล้ว ใช้งานแอปต่อได้';
    } catch (error) {
      Pam.log([
        'Consent saved; status refresh failed',
        error,
      ], category: PamLogCategory.consent);
      return 'บันทึก Consent แล้ว แต่โหลดสถานะล่าสุดไม่สำเร็จ กดตรวจสอบอีกครั้งได้';
    }
  }

  Map<String, dynamic> get _productPayload => {
    'sku': 'DEMO-SKU-001',
    'product_name': 'Everyday Bag',
    'price': 590,
    'demo_stage': _member ? 'member' : 'guest',
  };

  Future<String> _trackProduct() async {
    final response = await Pam.track('view_product', payload: _productPayload);
    if (response == null) {
      return 'ยังไม่ได้ส่ง Event ตรวจสอบ Tracking Consent และ Log แล้วลองอีกครั้ง';
    }
    _checkResponse(response);
    return 'ส่ง Event ดูสินค้า${_member ? 'หลังเข้าสู่ระบบ' : 'ในฐานะผู้เยี่ยมชม'}แล้ว';
  }

  Future<String> _trackFavorite() async {
    final response = await Pam.track(
      'favorite_product',
      payload: {..._productPayload, 'is_favorite': _favorite},
    );
    if (response == null) {
      return 'เปลี่ยนรายการที่ชอบแล้ว แต่ยังไม่ได้ส่ง Event ตรวจสอบ Consent และ Log';
    }
    _checkResponse(response);
    return 'เปลี่ยนรายการที่ชอบและส่ง Event แล้ว';
  }

  void _checkResponse(PamResponse response) {
    if (response.error != null) {
      throw StateError(response.error!.errorMessage ?? 'ส่ง Event ไม่สำเร็จ');
    }
  }

  static const _orderItems = [
    (sku: 'DEMO-SKU-001', title: 'Everyday Bag', price: 590, quantity: 1),
    (sku: 'DEMO-SKU-002', title: 'Everyday Bottle', price: 250, quantity: 2),
  ];

  int get _orderTotal =>
      _orderItems.fold(0, (total, item) => total + item.price * item.quantity);

  Future<String> _trackPurchaseOrder() async {
    // A real app uses its confirmed order ID. Each demo click creates a new order.
    final orderId = 'DEMO-ORDER-${DateTime.now().microsecondsSinceEpoch}';
    final items = _orderItems;
    final response = await Pam.trackBatch([
      PamTrackEvent(
        event: 'purchase_order',
        payload: {
          'order_id': orderId,
          'total_amount': _orderTotal,
          'currency': 'THB',
        },
      ),
      for (final item in items)
        PamTrackEvent(
          event: 'purchase_order_item',
          payload: {
            'order_id': orderId,
            'sku': item.sku,
            'title': item.title,
            'price': item.price,
            'quantity': item.quantity,
            'line_total': item.price * item.quantity,
            'currency': 'THB',
          },
        ),
    ]);
    if (response == null) {
      return 'ยังไม่ได้ส่งคำสั่งซื้อ ตรวจสอบ Tracking Consent และ Log แล้วลองอีกครั้ง';
    }
    if (response.error != null) {
      throw StateError(
        response.error!.errorMessage ?? 'ส่งคำสั่งซื้อไม่สำเร็จ',
      );
    }
    final failures = response.results
        .where((result) => result.error != null)
        .length;
    if (failures > 0) {
      return 'คำสั่งซื้อ $orderId มีผลตอบกลับผิดพลาด $failures รายการ '
          'ตรวจรายละเอียดใน Log ก่อนตัดสินใจส่งซ้ำ';
    }
    return 'ส่งคำขอซื้อสินค้า $orderId แล้ว (ยอดรวม ฿$_orderTotal) '
        'ได้รับผลกลับมา ${response.results.length} รายการ ดูรายละเอียดใน Log '
        'ผลตอบกลับอาจไม่ครบทุก Event';
  }

  Future<String> _showAppAttention() async {
    final pageName = _pageName.text.trim();
    if (pageName.isEmpty) return 'กรุณากรอก PageName ก่อนทดสอบ';
    FocusScope.of(context).unfocus();
    Pam.log([
      'Example appAttention pageName=$pageName',
    ], category: PamLogCategory.attention);
    await Pam.appAttention(context, pageName: pageName);
    return 'จบการตรวจสอบ App Attention / ปิด Popup แล้ว '
        'หากไม่มี Popup ให้ตรวจ Campaign ที่ตรงกับ PageName และดู Log';
  }

  Future<String> _reset() async {
    await widget.auth.logoutAndReset();
    return 'ออกจากระบบและล้างข้อมูลในเครื่องแล้ว เริ่มลองใหม่ในฐานะผู้เยี่ยมชมได้';
  }

  void _clearDemoState() {
    _actionResults.clear();
    _trackingStatus = null;
    _contactingStatus = null;
    _viewingProduct = false;
    _favorite = false;
    _customer.text = 'DEMO-CUSTOMER-001';
    _pageName.text = 'home';
  }

  Widget _button(
    String id,
    String label,
    String command,
    Future<String> Function() action, {
    bool enabled = true,
    String? resultSection,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton(
        key: ValueKey('action-$id'),
        onPressed: !_blocked && enabled
            ? () => _run(command, action, resultSection: resultSection)
            : null,
        child: Text(label),
      ),
    );
  }

  Widget _step(
    int number,
    String title,
    String description,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$number. $title',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  List<Widget> _consentControls(
    bool tracking,
    String prefix, {
    required bool enabled,
  }) {
    final status = tracking ? _trackingStatus : _contactingStatus;
    final permission = status?.trackingPermission;
    final contacting = status?.contactingPermission;
    return [
      _button(
        'status-$prefix',
        'ตรวจสอบ Consent',
        'Pam.loadConsentStatus(${tracking ? 'tracking' : 'contacting'}MessageId)',
        () => _checkConsent(tracking),
        enabled: enabled && _ready,
        resultSection: prefix,
      ),
      _button(
        'show-$prefix',
        'เปิดเพื่อเลือกหรือปรับ Consent',
        'Pam.showConsent(context, messageId: ${tracking ? 'tracking' : 'contacting'}MessageId)',
        () => _showConsent(tracking),
        enabled: enabled && _ready,
        resultSection: prefix,
      ),
      if (enabled) _feedback(prefix),
      if (enabled && status != null) ...[
        Text(
          status.consentId?.isNotEmpty != true
              ? 'ยังไม่พบ Consent ที่บันทึกไว้'
              : status.needConsentReview
              ? 'มี Consent เดิมที่ต้องทบทวน กรุณาเปิดเพื่อตรวจและยืนยันอีกครั้ง'
              : 'มี Consent ที่บันทึกไว้แล้ว',
          key: ValueKey('consent-status-$prefix'),
        ),
        if (permission != null)
          Wrap(
            spacing: 8,
            children: [
              _permission('การตั้งค่า', permission.preferencesCookies),
              _permission('วิเคราะห์การใช้งาน', permission.analyticsCookies),
              _permission('การตลาด', permission.marketingCookies),
              _permission('โซเชียลมีเดีย', permission.socialMediaCookies),
            ],
          ),
        if (contacting != null)
          Wrap(
            spacing: 8,
            children: [
              _permission('อีเมล', contacting.email),
              _permission('SMS', contacting.sms),
              _permission('LINE', contacting.line),
              _permission('Messenger', contacting.facebookMessenger),
              _permission('Push', contacting.webPush),
            ],
          ),
      ],
    ];
  }

  Widget _feedback(String prefix, {String keyPrefix = 'consent-result'}) {
    final result = _actionResults[prefix];
    if (result == null) return const SizedBox.shrink();
    final resultKey = _actionResultKeys.putIfAbsent(prefix, () => GlobalKey());
    return Padding(
      key: resultKey,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              result.failed ? Icons.error_outline : Icons.info_outline,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(result.message, key: ValueKey('$keyPrefix-$prefix')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permission(String name, bool allowed) => Chip(
    avatar: Icon(allowed ? Icons.check : Icons.close, size: 16),
    label: Text('$name: ${allowed ? 'อนุญาต' : 'ไม่อนุญาต'}'),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PAM · ลองใช้งานจริง')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            key: const ValueKey('demo-scroll'),
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'จากผู้เยี่ยมชม สู่สมาชิก',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'ลองตามลำดับ หรือเข้าสู่ระบบเมื่อพร้อม ทุกปุ่มที่เรียก SDK '
                'จะระบุคำสั่งใน Log เพื่อเปิดดูและทำตามจากโค้ดได้',
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_member ? Icons.person : Icons.person_outline),
                title: Text(
                  !widget.auth.sessionKnown
                      ? 'กำลังตรวจสอบ Session'
                      : _member
                      ? 'สมาชิก: ${widget.auth.session!.customerId}'
                      : 'ผู้เยี่ยมชม · ยังไม่ได้เข้าสู่ระบบ',
                  key: const ValueKey('auth-state'),
                ),
                subtitle: const Text(
                  'Auth เป็นระบบจำลอง · PAM ใช้ค่าจาก pam_config.dart',
                ),
              ),
              if (_blocked) const LinearProgressIndicator(),
              Semantics(
                liveRegion: true,
                child: ListTile(
                  leading: Icon(
                    _failed ? Icons.error_outline : Icons.info_outline,
                  ),
                  title: Text(_notice, key: const ValueKey('demo-result')),
                ),
              ),
              if (!_ready && !_blocked) ...[
                _button(
                  'refresh-session',
                  'ลองตรวจสอบ Session อีกครั้ง',
                  'GET /auth/session → sync PAM',
                  () async {
                    await widget.auth.refreshSession();
                    return 'ตรวจสอบ Session และเชื่อมต่อ PAM แล้ว';
                  },
                ),
                if (widget.auth.sessionKnown)
                  _button(
                    'sync-identity',
                    'เชื่อมต่อ PAM อีกครั้ง',
                    'auth.synchronizePam()',
                    () async {
                      await widget.auth.synchronizePam();
                      return 'เชื่อมต่อ PAM กับ Session ปัจจุบันแล้ว';
                    },
                  ),
              ],
              const SizedBox(height: 16),
              _step(
                1,
                'ลองใช้แอปก่อน Login',
                'ดูสินค้าและเก็บรายการที่ชอบได้ทันที พร้อมเรียก Pam.track ตามการกดใช้งาน การส่ง Event ขึ้นอยู่กับ Consent และ config ของ SDK',
                [
                  const Icon(Icons.shopping_bag_outlined, size: 64),
                  const Text(
                    'Everyday Bag · ฿590',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    key: const ValueKey('browse-product'),
                    onPressed: _blocked
                        ? null
                        : () {
                            setState(() => _viewingProduct = true);
                            unawaited(
                              _run(
                                "Pam.track('view_product', payload: product)",
                                _trackProduct,
                                resultSection: 'product-actions',
                              ),
                            );
                          },
                    child: const Text('ดูรายละเอียดสินค้า'),
                  ),
                  if (_viewingProduct)
                    const Text(
                      'กระเป๋าสำหรับทุกวัน น้ำหนักเบา พกของจำเป็นได้ครบ',
                    ),
                  OutlinedButton.icon(
                    key: const ValueKey('favorite-product'),
                    onPressed: _blocked
                        ? null
                        : () {
                            setState(() => _favorite = !_favorite);
                            unawaited(
                              _run(
                                "Pam.track('favorite_product', payload: productWithFavoriteState)",
                                _trackFavorite,
                                resultSection: 'product-actions',
                              ),
                            );
                          },
                    icon: Icon(
                      _favorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(
                      _favorite
                          ? 'อยู่ในรายการที่ชอบแล้ว'
                          : 'เก็บไว้ในรายการที่ชอบ',
                    ),
                  ),
                  _feedback('product-actions', keyPrefix: 'action-result'),
                ],
              ),
              _step(
                2,
                'เลือก Consent ก่อน Login',
                _member
                    ? 'เข้าสู่ระบบแล้ว จัดการ Consent ของสมาชิกในขั้นที่ 5'
                    : 'เปิดอ่านข้อความจริงและเลือกด้วยตัวเอง การปิดหน้าต่างจะไม่ถือว่ายอมรับ',
                [
                  ..._consentControls(
                    true,
                    'guest-tracking',
                    enabled: !_member,
                  ),
                ],
              ),
              _step(
                3,
                'ส่ง Event ก่อน Login',
                'ลองส่งเหตุการณ์ดูสินค้าในฐานะผู้เยี่ยมชม หากยังไม่มีสิทธิ์ Tracking '
                    'SDK จะจัดการตาม config และแจ้งใน Log',
                [
                  _button(
                    'track-guest',
                    'ส่ง Event ดูสินค้า · ผู้เยี่ยมชม',
                    "Pam.track('view_product', payload: guestProduct)",
                    _trackProduct,
                    enabled: !_member && _ready,
                  ),
                ],
              ),
              _step(
                4,
                'พร้อมแล้วค่อย Login',
                'เข้าสู่ระบบเมื่ออยากเป็นสมาชิก โดยไม่บังคับให้ทำขั้นก่อนหน้าครบ',
                [
                  if (!_member)
                    TextField(
                      key: const ValueKey('field-customer'),
                      controller: _customer,
                      enabled: !_blocked,
                      decoration: const InputDecoration(
                        labelText: 'Customer ID สำหรับจำลองสมาชิก',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  _button(
                    'login',
                    _member ? 'เข้าสู่ระบบแล้ว' : 'เข้าสู่ระบบ',
                    'POST /auth/login → Pam.userLogin(customerId)',
                    () async {
                      final customer = _customer.text.trim();
                      if (customer.isEmpty) {
                        return 'กรุณากรอก Customer ID ก่อนเข้าสู่ระบบ';
                      }
                      await widget.auth.login(customer);
                      return 'เข้าสู่ระบบแล้ว ตรวจสอบ Consent ของสมาชิกในขั้นถัดไป';
                    },
                    enabled: !_member && _ready,
                  ),
                ],
              ),
              _step(
                5,
                'ตรวจสอบหรือปรับ Consent หลัง Login',
                'โหลดสถานะของสมาชิกอีกครั้ง อย่าใช้สถานะผู้เยี่ยมชมมาแทน '
                    'จากนั้นเปิดหน้าต่างเดิมเพื่อปรับตัวเลือกได้',
                [
                  ..._consentControls(
                    true,
                    'member-tracking',
                    enabled: _member,
                  ),
                  if (widget.contactingMessageId.trim().isNotEmpty) ...[
                    const Divider(),
                    const Text('Consent สำหรับการติดต่อ'),
                    ..._consentControls(
                      false,
                      'member-contacting',
                      enabled: _member,
                    ),
                  ],
                ],
              ),
              _step(
                6,
                'ส่ง Event หลัง Login',
                'ส่งเหตุการณ์ดูสินค้าเดิมอีกครั้ง คราวนี้ใช้ตัวตนสมาชิก '
                    'เปรียบเทียบคำสั่งและเส้นทางส่งข้อมูลได้ใน Log',
                [
                  _button(
                    'track-member',
                    'ส่ง Event ดูสินค้า · สมาชิก',
                    "Pam.track('view_product', payload: memberProduct)",
                    _trackProduct,
                    enabled: _member && _ready,
                  ),
                  const Divider(),
                  Text(
                    'จำลองคำสั่งซื้อ',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final item in _orderItems)
                    Text(
                      '${item.title} × ${item.quantity} · ฿${item.price * item.quantity}',
                    ),
                  Text('ยอดรวม ฿$_orderTotal · THB'),
                  const SizedBox(height: 8),
                  const Text(
                    'ส่ง purchase_order 1 Event และ purchase_order_item '
                    'ตามสินค้า 2 รายการ ในคำขอเดียว โดยใช้ order_id เดียวกัน '
                    'การกดแต่ละครั้งจำลองคำสั่งซื้อใหม่ ไม่ใช่การชำระเงินจริง',
                  ),
                  _button(
                    'purchase-order',
                    'จำลองซื้อสินค้า · ส่งแบบ Batch',
                    'Pam.trackBatch([purchase_order, for (final item in items) purchase_order_item])',
                    _trackPurchaseOrder,
                    enabled: _member && _ready,
                    resultSection: 'purchase-order',
                  ),
                  _feedback('purchase-order', keyPrefix: 'action-result'),
                ],
              ),
              _step(
                7,
                'ทดสอบ App Attention',
                'กรอก PageName ให้ตรงกับ Campaign แล้วกดตรวจสอบ Popup '
                    'ทดสอบได้ทั้งก่อนและหลัง Login โดยต้องมี Campaign ที่เข้าเงื่อนไขผู้ใช้ปัจจุบัน',
                [
                  TextField(
                    key: const ValueKey('field-page-name'),
                    controller: _pageName,
                    enabled: !_blocked,
                    decoration: const InputDecoration(
                      labelText: 'PageName',
                      hintText: 'เช่น home หรือ product_detail',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  _button(
                    'app-attention',
                    'ทดสอบ App Attention',
                    'Pam.appAttention(context, pageName: pageName)',
                    _showAppAttention,
                    enabled: _ready,
                    resultSection: 'app-attention',
                  ),
                  _feedback('app-attention', keyPrefix: 'action-result'),
                ],
              ),
              _step(
                8,
                'Logout และเริ่มใหม่',
                'ออกจากระบบจำลอง แจ้ง PAM แล้ว Reset ข้อมูล SDK ในเครื่อง '
                    'พร้อมล้างรายการที่ชอบและสถานะในหน้านี้ เพื่อเริ่มรอบใหม่ '
                    'ข้อมูลที่เคยส่งไปยัง server ยังคงอยู่',
                [
                  _button(
                    'logout-reset',
                    'ออกจากระบบและล้างข้อมูลในเครื่อง',
                    'POST /auth/logout → Pam.userLogout → Pam.reset',
                    _reset,
                    enabled:
                        Pam.shared.config != null && widget.auth.sessionKnown,
                  ),
                ],
              ),
              const Text(
                'ดูคำสั่งของแต่ละปุ่มและผลการส่งข้อมูลใน SDK Log '
                'ผ่าน Debug Console / Android Studio / Xcode',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
