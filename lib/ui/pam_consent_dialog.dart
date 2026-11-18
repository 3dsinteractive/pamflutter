import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../pam.dart' show SubmitConsentResult;
import '../response/consent_message.dart';
import '../response/consent_selection.dart';
import '../response/customer_consent_status.dart';
import '../response/pam_consent_result.dart';

const _japaneseUi = <String, String>{
  "Unable to open link.": "リンクを開けませんでした。",
  "Read more": "全文を読む",
  "Privacy settings": "プライバシー設定",
  "Back": "戻る",
  "Close": "閉じる",
  "Required · Always enabled": "必須・常に有効",
  "Loading consent": "同意内容を読み込み中",
  "The account has changed. Close and reopen this screen.":
      "アカウントが変更されました。この画面を閉じて、もう一度開いてください。",
  "Unable to load consent details.": "同意内容を読み込めませんでした。",
  "Consent details have changed. Please review your choices.":
      "同意内容が変更されました。選択内容を確認してください。",
  "Unable to save. Your choices are kept. Please try again.":
      "保存できませんでした。選択内容は保持されています。もう一度お試しください。",
  "Save failed": "保存できませんでした",
  "Only the selected permissions will be saved.": "選択した項目のみ保存されます。",
  "Saving…": "保存中…",
  "Accept and save choices": "同意して選択内容を保存",
  "Try again": "再試行",
};

const _japanesePermissions = <ConsentPermissionName, String>{
  ConsentPermissionName.termsAndConditions: "利用規約",
  ConsentPermissionName.privacyOverview: "プライバシーの概要",
  ConsentPermissionName.necessaryCookies: "必須Cookie",
  ConsentPermissionName.preferencesCookies: "設定Cookie",
  ConsentPermissionName.analyticsCookies: "分析Cookie",
  ConsentPermissionName.marketingCookies: "マーケティングCookie",
  ConsentPermissionName.socialMediaCookies: "ソーシャルメディアCookie",
  ConsentPermissionName.email: "メール",
  ConsentPermissionName.sms: "SMS",
  ConsentPermissionName.line: "LINE",
  ConsentPermissionName.facebookMessenger: "Facebook Messenger",
  ConsentPermissionName.pushNotification: "プッシュ通知",
};

typedef ConsentScreenSaver =
    Future<SubmitConsentResult> Function(
      ConsentSelection selection,
      String? sourceContactId,
    );

/// Internal presenter used by Pam.showConsent. API work stays outside widgets.
Future<PamConsentResult> presentPamConsent(
  BuildContext context, {
  required String messageId,
  required Future<String?> Function() getContactId,
  required Future<CustomerConsentStatus> Function() loadStatus,
  required Future<ConsentMessage?> Function() loadMessage,
  required ConsentScreenSaver save,
  required bool Function() isSessionCurrent,
  Locale? locale,
}) async {
  final result = await showGeneralDialog<PamConsentResult>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    routeSettings: const RouteSettings(name: 'pam-consent'),
    pageBuilder: (context, animation, secondaryAnimation) => _ConsentPage(
      messageId: messageId,
      getContactId: getContactId,
      loadStatus: loadStatus,
      loadMessage: loadMessage,
      save: save,
      isSessionCurrent: isSessionCurrent,
      locale: locale,
    ),
  );
  return result ?? const PamConsentResult.dismissed();
}

class _ConsentPage extends StatefulWidget {
  final String messageId;
  final Future<String?> Function() getContactId;
  final Future<CustomerConsentStatus> Function() loadStatus;
  final Future<ConsentMessage?> Function() loadMessage;
  final ConsentScreenSaver save;
  final bool Function() isSessionCurrent;
  final Locale? locale;

  const _ConsentPage({
    required this.messageId,
    required this.getContactId,
    required this.loadStatus,
    required this.loadMessage,
    required this.save,
    required this.isSessionCurrent,
    this.locale,
  });

  @override
  State<_ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<_ConsentPage> {
  ConsentMessage? _message;
  String? _sourceContactId;
  final _choices = <ConsentPermissionName, bool>{};
  final _scrollController = ScrollController();
  static const _languagePriority = ['th', 'en', 'jp'];
  String _language = 'th';
  List<String> _languages = ['th'];
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _saveFailed = false;
  bool _sessionChanged = false;
  bool _needsReview = false;
  ConsentPermission? _detail;

  bool get _thai => _language == 'th';
  String _say(String en, String th) => _thai
      ? th
      : _language == 'jp'
      ? _japaneseUi[en] ?? en
      : en;

  // PAM uses jp in JSON; Flutter uses ja for the Japanese locale.
  String? _languageCode(String? code) => code == 'ja' ? 'jp' : code;

  @override
  void initState() {
    super.initState();
    final preferred = _languageCode(widget.locale?.languageCode);
    _language = {'th', 'en', 'jp'}.contains(preferred) ? preferred! : 'th';
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _text(LocalizeText? text, [String fallback = '']) {
    for (final language in {_language, ..._languagePriority}) {
      final value = text?.forLanguage(language);
      if (value?.trim().isNotEmpty == true) return value!;
    }
    return fallback;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _saveFailed = false;
      _detail = null;
    });
    try {
      if (!widget.isSessionCurrent()) throw StateError('Session changed');
      _sourceContactId = await widget.getContactId();
      CustomerConsentStatus? status;
      if (_sourceContactId?.isNotEmpty == true) {
        try {
          status = await widget.loadStatus();
        } catch (_) {
          // Per API contract, every status error is treated as first consent.
        }
      }
      final message = await widget.loadMessage();
      if (!mounted) return;
      if (!widget.isSessionCurrent()) {
        setState(() {
          _loading = false;
          _sessionChanged = true;
        });
        return;
      }
      if (message == null ||
          message.id != widget.messageId ||
          message.type == null ||
          message.version == null ||
          message.version! <= 0) {
        throw StateError('Invalid consent message');
      }
      final translatedLanguages = {
        ...?message.displayText?.availableLanguages,
        ...?message.consentDetailTitle?.availableLanguages,
        ...?message.acceptButtonText?.availableLanguages,
        for (final permission in message.permission)
          ...?permission.shortDescription?.availableLanguages,
        for (final permission in message.permission)
          if (permission.fullDescriptionEnabled)
            ...?permission.fullDescription?.availableLanguages,
      };
      _languages = (message.availableLanguages ?? <String>[])
          .map((language) => _languageCode(language)!)
          .where(
            (language) =>
                _languagePriority.contains(language) &&
                translatedLanguages.contains(language),
          )
          .toSet()
          .toList();
      if (_languages.isEmpty) {
        _languages = _languagePriority
            .where(translatedLanguages.contains)
            .toList();
      }
      if (_languages.isEmpty) _languages = ['th'];
      final preferred = _languageCode(widget.locale?.languageCode);
      _language = _languages.contains(preferred)
          ? preferred!
          : _languagePriority.firstWhere(_languages.contains);
      final type = message.type == ConsentType.tracking
          ? 'tracking_type'
          : 'contacting_type';
      final canReuse =
          status != null &&
          status.error == null &&
          status.consentId?.isNotEmpty == true &&
          status.contactId == _sourceContactId &&
          status.consentMessageId == message.id &&
          status.consentMessageType == type;
      _choices.clear();
      if (!canReuse) {
        // First presentation preselects enabled permissions only. Nothing is
        // persisted until the user confirms; existing choices are loaded below.
        for (final permission in message.permission) {
          _choices[permission.name] = true;
        }
      }
      if (canReuse) {
        final tracking = status.trackingPermission;
        final contacting = status.contactingPermission;
        if (message.type == ConsentType.tracking && tracking != null) {
          _choices.addAll({
            ConsentPermissionName.preferencesCookies:
                tracking.preferencesCookies,
            ConsentPermissionName.analyticsCookies: tracking.analyticsCookies,
            ConsentPermissionName.marketingCookies: tracking.marketingCookies,
            ConsentPermissionName.socialMediaCookies:
                tracking.socialMediaCookies,
          });
        } else if (message.type == ConsentType.contacting &&
            contacting != null) {
          _choices.addAll({
            ConsentPermissionName.email: contacting.email,
            ConsentPermissionName.sms: contacting.sms,
            ConsentPermissionName.line: contacting.line,
            ConsentPermissionName.facebookMessenger:
                contacting.facebookMessenger,
            ConsentPermissionName.pushNotification: contacting.webPush,
          });
        }
      }
      setState(() {
        _message = message;
        _needsReview =
            canReuse &&
            (status!.needConsentReview || status.version != message.version);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _sessionChanged = !widget.isSessionCurrent();
      });
    }
  }

  bool _required(ConsentPermissionName name) =>
      name == ConsentPermissionName.termsAndConditions ||
      name == ConsentPermissionName.privacyOverview ||
      name == ConsentPermissionName.necessaryCookies;

  bool _allowed(ConsentPermissionName name) =>
      _required(name) || (_choices[name] ?? false);

  List<ConsentPermission> get _permissions {
    final tracking = _message!.type == ConsentType.tracking;
    final names = tracking
        ? ConsentPermissionName.values.take(7)
        : [
            ConsentPermissionName.termsAndConditions,
            ConsentPermissionName.privacyOverview,
            ...ConsentPermissionName.values.skip(7),
          ];
    return [
      for (final name in names)
        if (_required(name) || _message!.permission.any((p) => p.name == name))
          _message!.permission.where((p) => p.name == name).firstOrNull ??
              ConsentPermission(name, null, null, false, true, true),
    ];
  }

  ConsentSelection _selection() {
    final version = ConsentVersion.number(_message!.version!);
    if (_message!.type == ConsentType.tracking) {
      return TrackingConsent(
        messageId: widget.messageId,
        version: version,
        termsAndConditions: true,
        privacyOverview: true,
        necessaryCookies: true,
        preferencesCookies: _allowed(ConsentPermissionName.preferencesCookies),
        analyticsCookies: _allowed(ConsentPermissionName.analyticsCookies),
        marketingCookies: _allowed(ConsentPermissionName.marketingCookies),
        socialMediaCookies: _allowed(ConsentPermissionName.socialMediaCookies),
      );
    }
    return ContactingConsent(
      messageId: widget.messageId,
      version: version,
      termsAndConditions: true,
      privacyOverview: true,
      email: _allowed(ConsentPermissionName.email),
      sms: _allowed(ConsentPermissionName.sms),
      line: _allowed(ConsentPermissionName.line),
      facebookMessenger: _allowed(ConsentPermissionName.facebookMessenger),
      pushNotification: _allowed(ConsentPermissionName.pushNotification),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      if (!widget.isSessionCurrent()) {
        throw const ConsentSaveException('SESSION_CHANGED', null);
      }
      final selection = _selection();
      final result = await widget.save(selection, _sourceContactId);
      if (!mounted) return;
      // Enable popping first: PopScope also guards programmatic pops.
      setState(() => _saving = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(
            PamConsentResult.saved(selection: selection, submission: result),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (error is ConsentSaveException &&
          error.code == 'NEED_CONSENT_REVIEW') {
        setState(() => _saving = false);
        await _load();
        if (mounted) setState(() => _needsReview = true);
        return;
      }
      setState(() {
        _saving = false;
        _saveFailed = true;
        _sessionChanged =
            !widget.isSessionCurrent() ||
            (error is ConsentSaveException && error.code == 'SESSION_CHANGED');
      });
    }
  }

  String _label(ConsentPermissionName name) {
    if (_language == 'jp') return _japanesePermissions[name]!;
    if (!_thai) return name.nameStr;
    return switch (name) {
      ConsentPermissionName.termsAndConditions => 'ข้อกำหนดและเงื่อนไข',
      ConsentPermissionName.privacyOverview => 'ภาพรวมความเป็นส่วนตัว',
      ConsentPermissionName.necessaryCookies => 'คุกกี้ที่จำเป็น',
      ConsentPermissionName.preferencesCookies => 'คุกกี้เพื่อการปรับแต่ง',
      ConsentPermissionName.analyticsCookies => 'คุกกี้เพื่อการวิเคราะห์',
      ConsentPermissionName.marketingCookies => 'คุกกี้เพื่อการตลาด',
      ConsentPermissionName.socialMediaCookies => 'คุกกี้โซเชียลมีเดีย',
      ConsentPermissionName.email => 'อีเมล',
      ConsentPermissionName.sms => 'SMS',
      ConsentPermissionName.line => 'LINE',
      ConsentPermissionName.facebookMessenger => 'Facebook Messenger',
      ConsentPermissionName.pushNotification => 'การแจ้งเตือนแบบพุช',
    };
  }

  Future<bool> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !{'https', 'http', 'mailto', 'tel'}.contains(uri.scheme)) {
      return true;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw StateError('Link unavailable');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _say('Unable to open link.', 'ไม่สามารถเปิดลิงก์ได้'),
            ),
          ),
        );
      }
    }
    return true;
  }

  Widget _html(String html, Color color) => HtmlWidget(
    html,
    textStyle: TextStyle(color: color, fontSize: 15, height: 1.5),
    onTapUrl: _openLink,
  );

  Widget _row(
    ConsentPermission permission,
    Color primary,
    Color secondary,
    Color text,
  ) {
    final required = _required(permission.name);
    final brief = _text(permission.shortDescription);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(permission.name),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: text,
                      ),
                    ),
                    if (required)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _say(
                            'Required · Always enabled',
                            'จำเป็น · เปิดใช้งานเสมอ',
                          ),
                          style: TextStyle(color: text, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: _label(permission.name),
                child: Switch(
                  key: ValueKey('pam-consent-${permission.name.key}'),
                  value: _allowed(permission.name),
                  activeThumbColor: primary,
                  activeTrackColor: primary.withValues(alpha: 0.25),
                  onChanged: required || _saving
                      ? null
                      : (value) => setState(() {
                          _choices[permission.name] = value;
                          _saveFailed = false;
                        }),
                ),
              ),
              if (required)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Icon(Icons.lock_outline, size: 16, color: text),
                ),
            ],
          ),
          if (brief.isNotEmpty) _html(brief, text),
          if (permission.fullDescriptionEnabled &&
              _text(permission.fullDescription).isNotEmpty)
            TextButton(
              key: ValueKey('pam-consent-detail-${permission.name.key}'),
              style: TextButton.styleFrom(foregroundColor: secondary),
              onPressed: _saving
                  ? null
                  : () => setState(() => _detail = permission),
              child: Text(_say('Read more', 'อ่านเพิ่มเติม')),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _message?.style;
    final primary = style?.dialogStyle?.primaryColor ?? const Color(0xFF14203D);
    final secondary = style?.dialogStyle?.secondaryColor ?? primary;
    // Remote bar/text colors are for the branded banner. Keep the reading
    // surface neutral, including permission details and the language menu.
    const text = Color(0xFF212121);
    final title = _detail != null
        ? _label(_detail!.name)
        : _text(
            _message?.consentDetailTitle,
            _say('Privacy settings', 'การตั้งค่าความเป็นส่วนตัว'),
          );
    return PopScope(
      canPop: !_saving && _detail == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving && _detail != null) {
          setState(() => _detail = null);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final height =
              (constraints.maxHeight * (compact ? 1 : 0.9) -
                      MediaQuery.paddingOf(context).vertical)
                  .clamp(0.0, double.infinity);
          final content = Scaffold(
            key: ValueKey(
              compact ? 'pam-consent-fullscreen' : 'pam-consent-dialog',
            ),
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: height * 0.35),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                            child: Row(
                              children: [
                                if (_detail != null)
                                  IconButton(
                                    key: const ValueKey(
                                      'pam-consent-detail-back',
                                    ),
                                    tooltip: _say('Back', 'กลับ'),
                                    color: text,
                                    onPressed: () =>
                                        setState(() => _detail = null),
                                    icon: const Icon(Icons.arrow_back),
                                  )
                                else ...[
                                  Icon(
                                    style?.dialogStyle?.icon == 'gdpr'
                                        ? Icons.public
                                        : Icons.verified_user_outlined,
                                    color: primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: const ValueKey('pam-consent-close'),
                                  tooltip: _say('Close', 'ปิด'),
                                  color: text,
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                          if (_languages.length > 1 &&
                              !_loading &&
                              !_loadFailed &&
                              !_sessionChanged)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: DropdownButton<String>(
                                  key: const ValueKey('pam-consent-language'),
                                  value: _language,
                                  dropdownColor: Colors.white,
                                  iconEnabledColor: text,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(color: text),
                                  items: [
                                    for (final language in _languages)
                                      DropdownMenuItem(
                                        value: language,
                                        child: Text(switch (language) {
                                          'th' => 'ไทย',
                                          'jp' => '日本語',
                                          _ => 'English',
                                        }),
                                      ),
                                  ],
                                  onChanged: _saving
                                      ? null
                                      : (value) =>
                                            setState(() => _language = value!),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  Expanded(
                    child: _loading
                        ? Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: _say(
                                'Loading consent',
                                'กำลังโหลดความยินยอม',
                              ),
                            ),
                          )
                        : _sessionChanged
                        ? _notice(
                            _say(
                              'The account has changed. Close and reopen this screen.',
                              'ผู้ใช้เปลี่ยนไปแล้ว กรุณาปิดและเปิดหน้าจอนี้อีกครั้ง',
                            ),
                            text,
                          )
                        : _loadFailed
                        ? _notice(
                            _say(
                              'Unable to load consent details.',
                              'โหลดรายละเอียดความยินยอมไม่สำเร็จ',
                            ),
                            text,
                            retry: _load,
                          )
                        : SingleChildScrollView(
                            key: ValueKey(
                              _detail == null
                                  ? 'pam-consent-list'
                                  : 'pam-consent-detail',
                            ),
                            controller: _detail == null
                                ? _scrollController
                                : null,
                            primary: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_detail != null)
                                  _html(_text(_detail!.fullDescription), text)
                                else ...[
                                  if (_needsReview)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Text(
                                        _say(
                                          'Consent details have changed. Please review your choices.',
                                          'รายละเอียดความยินยอมมีการเปลี่ยนแปลง กรุณาทบทวนตัวเลือกก่อนบันทึก',
                                        ),
                                        style: TextStyle(
                                          color: text,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  _html(_text(_message!.displayText), text),
                                  for (final permission in _permissions) ...[
                                    _row(permission, primary, secondary, text),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                  ),
                  if (!_loading &&
                      !_loadFailed &&
                      !_sessionChanged &&
                      _detail == null)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: height * 0.4),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_saveFailed)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    _say(
                                      'Unable to save. Your choices are kept. Please try again.',
                                      'บันทึกไม่สำเร็จ ตัวเลือกของคุณยังอยู่ กรุณาลองใหม่',
                                    ),
                                    key: const ValueKey(
                                      'pam-consent-save-error',
                                    ),
                                    style: TextStyle(color: text),
                                    semanticsLabel: _say(
                                      'Save failed',
                                      'บันทึกไม่สำเร็จ',
                                    ),
                                  ),
                                ),
                              Text(
                                _say(
                                  'Only the selected permissions will be saved.',
                                  'บันทึกความยินยอมตามรายการที่เลือก',
                                ),
                                style: TextStyle(fontSize: 12, color: text),
                              ),
                              const SizedBox(height: 8),
                              FilledButton(
                                key: const ValueKey('pam-consent-save'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor:
                                      style?.dialogStyle?.buttonTextColor ??
                                      Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _saving ? null : _save,
                                child: Text(
                                  _saving
                                      ? _say('Saving…', 'กำลังบันทึก…')
                                      : _text(
                                          _message?.acceptButtonText,
                                          _say(
                                            'Accept and save choices',
                                            'ยอมรับและบันทึกตัวเลือก',
                                          ),
                                        ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
          if (compact) return content;
          return SafeArea(
            child: Center(
              child: SizedBox(
                width: 600,
                height: constraints.maxHeight * 0.9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: content,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notice(String message, Color color, {VoidCallback? retry}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
          if (retry != null)
            TextButton(
              key: const ValueKey('pam-consent-retry'),
              onPressed: retry,
              child: Text(_say('Try again', 'ลองใหม่')),
            ),
        ],
      ),
    ),
  );
}
