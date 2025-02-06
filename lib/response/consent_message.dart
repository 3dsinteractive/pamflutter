import 'dart:ui';
import 'dart:convert';
import '../pam.dart';

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${(a * 255).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(r * 255).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(g * 255).toInt().toRadixString(16).padLeft(2, '0')}'
      '${(b * 255).toInt().toRadixString(16).padLeft(2, '0')}';
}

enum ConsentType { tracking, contacting }

class ConsentDialogStyleConfiguration {
  String? icon;
  Color? primaryColor;
  Color? secondaryColor;
  Color? buttonTextColor;
  Color? textColor;
  ConsentDialogStyleConfiguration(this.icon, this.primaryColor,
      this.secondaryColor, this.buttonTextColor, this.textColor);
}

class ConsentStyleConfiguration {
  Color? backgroundColor;
  Color? textColor;
  double? barBackgroundOpacity;
  Color? buttonBackgroundColor;
  Color? buttonTextColor;
  ConsentDialogStyleConfiguration? dialogStyle;

  ConsentStyleConfiguration(
      this.backgroundColor,
      this.textColor,
      this.barBackgroundOpacity,
      this.buttonBackgroundColor,
      this.buttonTextColor,
      this.dialogStyle);

  static ConsentStyleConfiguration? parse(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    var backgroundColor = json["bar_background_color"]?.toString() ?? "#FFFFFF";
    var textColor = json["bar_text_color"]?.toString() ?? "#000000";
    var barBackgroundOpacity =
        (double.tryParse(json["bar_text_color"]?.toString() ?? "100") ??
                100.0) /
            100.0;
    var buttonBackgroundColor = json["bar_text_color"]?.toString() ?? "#000000";
    var buttonTextColor = json["button_text_color"]?.toString() ?? "#000000";

    var it = json["consent_detail"] as Map<String, dynamic>;

    var icon = it["popup_main_icon"]?.toString() ?? "";
    var primaryColor = it["primary_color"]?.toString() ?? "#cccccc";
    var secondaryColor = it["secondary_color"]?.toString() ?? "#5c5c5c";
    var dialogButtonTextColor =
        it["button_text_color"]?.toString() ?? "#000000";
    var dialogTextColor = it["text_color"]?.toString() ?? "#000000";

    var dialogStyle = ConsentDialogStyleConfiguration(
        icon,
        HexColor.fromHex(primaryColor),
        HexColor.fromHex(secondaryColor),
        HexColor.fromHex(dialogButtonTextColor),
        HexColor.fromHex(dialogTextColor));

    return ConsentStyleConfiguration(
        HexColor.fromHex(backgroundColor),
        HexColor.fromHex(textColor),
        barBackgroundOpacity,
        HexColor.fromHex(buttonBackgroundColor),
        HexColor.fromHex(buttonTextColor),
        dialogStyle);
  }
}

enum Lang { en, th }

class LocalizeText {
  String? en;
  String? th;

  LocalizeText(this.en, this.th);

  String? get(Lang prefer) {
    if (prefer == Lang.en) {
      if (en != null) {
        return en;
      } else if (th != null) {
        return th;
      }
    } else {
      if (th != null) {
        return th;
      } else if (en != null) {
        return en;
      }
    }
    return null;
  }
}

extension ConsentPermissionNameExtension on ConsentPermissionName {
  String get nameStr {
    switch (this) {
      case ConsentPermissionName.termsAndConditions:
        return "Terms and Conditions";
      case ConsentPermissionName.privacyOverview:
        return "Privacy overview";
      case ConsentPermissionName.necessaryCookies:
        return "Necessary cookies";
      case ConsentPermissionName.preferencesCookies:
        return "Preferences cookies";
      case ConsentPermissionName.analyticsCookies:
        return "Analytics cookies";
      case ConsentPermissionName.marketingCookies:
        return "Marketing cookies";
      case ConsentPermissionName.socialMediaCookies:
        return "Social media cookies";
      case ConsentPermissionName.email:
        return "Email";
      case ConsentPermissionName.sms:
        return "SMS";
      case ConsentPermissionName.line:
        return "LINE";
      case ConsentPermissionName.facebookMessenger:
        return "Facebook Messenger";
      case ConsentPermissionName.pushNotification:
        return "Push notification";
    }
  }

  String get key {
    switch (this) {
      case ConsentPermissionName.termsAndConditions:
        return "terms_and_conditions";
      case ConsentPermissionName.privacyOverview:
        return "privacy_overview";
      case ConsentPermissionName.necessaryCookies:
        return "necessary_cookies";
      case ConsentPermissionName.preferencesCookies:
        return "preferences_cookies";
      case ConsentPermissionName.analyticsCookies:
        return "analytics_cookies";
      case ConsentPermissionName.marketingCookies:
        return "marketing_cookies";
      case ConsentPermissionName.socialMediaCookies:
        return "social_media_cookies";
      case ConsentPermissionName.email:
        return "email";
      case ConsentPermissionName.sms:
        return "sms";
      case ConsentPermissionName.line:
        return "line";
      case ConsentPermissionName.facebookMessenger:
        return "facebook_messenger";
      case ConsentPermissionName.pushNotification:
        return "push_notification";
    }
  }
}

enum ConsentPermissionName {
  termsAndConditions,
  privacyOverview,
  necessaryCookies,
  preferencesCookies,
  analyticsCookies,
  marketingCookies,
  socialMediaCookies,
  email,
  sms,
  line,
  facebookMessenger,
  pushNotification,
}

class ValidationResult {
  bool isValid = false;
  String? errorMessage;
  List<String>? errorField;

  ValidationResult(this.isValid, this.errorMessage, this.errorField);
}

class ConsentPermission {
  ConsentPermissionName name;
  LocalizeText? shortDescription;
  LocalizeText? fullDescription;
  bool fullDescriptionEnabled;
  bool require;
  bool allow;

  ConsentPermission(this.name, this.shortDescription, this.fullDescription,
      this.fullDescriptionEnabled, this.require, this.allow);

  static LocalizeText? getText(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    return LocalizeText(json["en"].toString(), json["th"].toString());
  }

  static ConsentPermission? parsePermission(
      Map<String, dynamic>? json, ConsentPermissionName key, bool require) {
    var item = json?[key.key] as Map<String, dynamic>?;
    if (item == null) {
      return null;
    }

    var isEnable = (item["is_enabled"] as bool?) ?? false;
    if (!isEnable) {
      return null;
    }

    var shortDescription = item["brief_description"] as Map<String, dynamic>?;
    var fullDescription = item["full_description"] as Map<String, dynamic>?;

    var fullDescriptionEnabled =
        (item["is_full_description_enabled"] as bool?) ?? false;

    return ConsentPermission(key, getText(shortDescription),
        getText(fullDescription), fullDescriptionEnabled, require, false);
  }

  static List<ConsentPermission> parse(Map<String, dynamic>? json) {
    List<ConsentPermission> list = [];

    var perm =
        parsePermission(json, ConsentPermissionName.termsAndConditions, true);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.privacyOverview, true);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.necessaryCookies, true);
    if (perm != null) {
      list.add(perm);
    }

    perm =
        parsePermission(json, ConsentPermissionName.preferencesCookies, false);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.analyticsCookies, false);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.marketingCookies, false);
    if (perm != null) {
      list.add(perm);
    }

    perm =
        parsePermission(json, ConsentPermissionName.socialMediaCookies, false);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.email, false);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.sms, false);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.line, false);
    if (perm != null) {
      list.add(perm);
    }

    perm =
        parsePermission(json, ConsentPermissionName.facebookMessenger, false);
    if (perm != null) {
      list.add(perm);
    }

    perm = parsePermission(json, ConsentPermissionName.pushNotification, false);
    if (perm != null) {
      list.add(perm);
    }

    return list;
  }

  String getSubmitKey() {
    return "_allow_${name.key}";
  }
}

class ConsentMessage {
  String? id;
  ConsentType? type;
  String? name;
  String? description;
  ConsentStyleConfiguration? style;
  int? version;
  int? revision;
  LocalizeText? displayText;
  LocalizeText? acceptButtonText;
  LocalizeText? consentDetailTitle;
  List<String>? availableLanguages;
  String? defaultLanguage;
  List<ConsentPermission> permission = [];
  LocalizeText? moreInfoButtonText;

  ConsentMessage(
      this.id,
      this.type,
      this.name,
      this.description,
      this.style,
      this.version,
      this.revision,
      this.displayText,
      this.acceptButtonText,
      this.consentDetailTitle,
      this.availableLanguages,
      this.defaultLanguage,
      this.permission,
      this.moreInfoButtonText);

  void allowAll() {
    for (var element in permission) {
      element.allow = true;
    }
  }

  void denyAll() {
    for (var element in permission) {
      element.allow = false;
    }
  }

  void setPermission(ConsentPermissionName name, bool isAllow) {
    for (var element in permission) {
      if (element.name == name) {
        element.allow = isAllow;
      }
    }
  }

  ValidationResult validate() {
    var pass = true;
    List<String>? errorField;
    String? errorMessage;

    for (var p in permission) {
      if (p.require && !p.allow) {
        pass = false;
        errorField ??= [];
        errorField.add(p.name.nameStr);
      }
    }

    if (!pass) {
      var fields = errorField?.join(", ") ?? "";
      errorMessage = "You must accept the required permissions ($fields)";
    }
    return ValidationResult(pass, errorMessage, errorField);
  }

  static ConsentType? getType(Map<String, dynamic> json) {
    var type = json["consent_message_type"]?.toString() ?? "";
    if (type == "tracking_type") {
      return ConsentType.tracking;
    } else if (type == "contacting_type") {
      return ConsentType.contacting;
    }
    return null;
  }

  static LocalizeText? getText(Map<String, dynamic> json) {
    return LocalizeText(json["en"]?.toString(), json["th"]?.toString());
  }

  static ConsentMessage fromJson(Map<String, dynamic> json) {
    var id = json["consent_message_id"].toString();
    var name = json["name"].toString();
    var description = json["description"].toString();
    var style = ConsentStyleConfiguration.parse(json["style_configuration"]);
    var setting = json["setting"] as Map<String, dynamic>?;

    var type = getType(json);

    var version = setting?["version"] ?? 0;
    var revision = setting?["revision"] ?? 0;

    var displayText = getText(setting?["display_text"]);

    var moreInfoButtonText = getText(setting?["more_info"]["display_text"]);

    var acceptButtonText = getText(setting?["accept_button_text"]);
    var consentDetailTitle = getText(setting?["consent_detail_title"]);

    List<String> availableLanguages = [];

    var langs = setting?["available_languages"] as List<dynamic>?;
    if (langs != null) {
      for (var element in langs) {
        availableLanguages.add(element);
      }
    }

    var defaultLanguage = setting?["default_language"] ?? "en";
    var permissions = ConsentPermission.parse(setting);

    return ConsentMessage(
        id,
        type,
        name,
        description,
        style,
        version,
        revision,
        displayText,
        acceptButtonText,
        consentDetailTitle,
        availableLanguages,
        defaultLanguage,
        permissions,
        moreInfoButtonText);
  }

  static ConsentMessage? parse(String jsonStr) {
    try {
      Map<String, dynamic> json = jsonDecode(jsonStr);
      return ConsentMessage.fromJson(json);
    } catch (e) {
      Pam.log(["ConsentMessage.parse Error", e.toString()]);
      return null;
    }
  }
}
