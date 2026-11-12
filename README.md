# PAM Flutter SDK

A Flutter plugin for integrating PAM Real CDP into Flutter mobile applications. This guide covers SDK v3.1.0.

## Table of Contents

- [Installation](#installation)
- [Migrating from 2.x](#migrating-from-2x)
- [Integration flow](#integration-flow)
- [Configuration](#configuration)
- [Initialization](#initialization)
- [Core Features](#core-features)
  - [Consent Management](#consent-management)
  - [Push Notifications](#push-notifications)
  - [User Tracking](#user-tracking)
  - [App Attention](#app-attention)
- [Logging](#logging)
- [API Reference](#api-reference)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Installation

### Prerequisites

- Flutter SDK version 3.41.0 or later
- Dart SDK version 3.11.0 or later
- Android API 24 or later
- iOS 13.0 or later

### Adding pam_flutter to Your Project

Open a terminal and run the following command to add `pam_flutter` to your Flutter project:

```sh
flutter pub add pam_flutter:^3.1.0
```

## Migrating from 2.x

Version 3 contains breaking identity and push-helper API changes. Follow the
[2.x to 3.0 migration guide](MIGRATE.md) before upgrading an existing
application.

## Integration flow

| Component | Responsibility |
| --- | --- |
| App Server | Authenticate users and sync customer profiles and demographics to the PAM Login DB through your server-to-server integration. Keep server credentials on the server. |
| Flutter app | Initialize PAM, collect consent, signal identity changes, send events, and handle push and App Attention. |
| PAM CDP | Receive anonymous events in the Public DB and route identified activity to the Login DB according to the SDK session. |

For a newly registered user, have the App Server sync the profile using the
same identity key and value configured in PAM. Once the profile is ready,
call `Pam.userLogin(customerId)` in the app and check the result before sending
account-specific events. If profile sync is asynchronous, coordinate readiness
with your backend. A successful app registration can precede PAM profile
availability, and tracking during that gap can return `CONTACT_NOT_FOUND`.

## Configuration

Create `lib/pam_config.dart` in your project and add the following code:

```dart
import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  static PamConfig getConfig() {
    // Replace the following values with your configuration
    const endpoint = "https://[YOUR-DOMAIN]pams.ai";
    const publicDBAlias = "[PAM-PUBLIC-DB-FROM-PAM-CMS]";
    const loginDBAlias = "[PAM-LOGIN-DB-FROM-PAM-CMS]";
    const trackingConsentMessageID = "[CONSENT-MESSAGE-ID-FROM-PAM-CMS]";

    const debugMode = false; // Set to true while debugging.

    return PamConfig(
      endpoint,
      publicDBAlias,
      loginDBAlias,
      trackingConsentMessageID,
      debugMode,
      identityMatcher: PamIdentityMatcher.primary(
        PamPrimaryIdentityKey.customer,
      ),
    );
  }
}
```

## Initialization

In your `main.dart` file, add the following code to the `main()` function to initialize the PAM library:

```dart
import 'package:flutter/material.dart';
import 'package:pam_flutter/pam.dart';
import 'pam_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var pamConfig = PamConfigProvider.getConfig();
  await Pam.initialize(pamConfig);

  runApp(const MyApp());
}
```

Consent synchronization runs in the background after initialization.
Initialization does not register a persisted push token.

## Core Features

### Consent Management

Load the consent message configured in PAM CMS and submit the choices the user confirms. The examples call `allowAll()` for the case where the user explicitly accepts every option in that message.

#### Allow All Consent

Use `Pam.allowAllTrackingConsent()` or `Pam.allowAllContactingConsent()` when
you want to allow every permission on the latest version of a consent message
without loading the consent message first.

Use the tracking helper only for tracking consent messages. It unlocks local
event tracking after the server accepts the consent. Use the contacting helper
for marketing communication consent messages; it does not change local tracking
state.

```dart
import 'package:pam_flutter/pam.dart';

Future<SubmitConsentResult?> allowAllTrackingConsent() async {
  return Pam.allowAllTrackingConsent("[YOUR-TRACKING-CONSENT-MSG-ID]");
}

Future<SubmitConsentResult?> allowAllContactingConsent() async {
  return Pam.allowAllContactingConsent("[YOUR-CONTACTING-CONSENT-MSG-ID]");
}
```

> Reminder: Replace the consent message IDs with your actual consent message IDs from your PAM CMS.

#### Tracking Consent

Tracking Consent allows users to grant permission for tracking events or user behavior. Use the manual flow when you need to inspect the consent message or allow individual permissions selectively:

```dart
import 'package:pam_flutter/pam.dart';

Future<SubmitConsentResult?> allowTrackingConsent() async {
  var trackingConsentMessageID = "[YOUR-TRACKING-CONSENT-MSG-ID]";
  var trackingConsent = await Pam.loadConsentMessage(trackingConsentMessageID);
  trackingConsent?.allowAll();

  if (trackingConsent != null) {
    var result = await Pam.submitConsent(trackingConsent);
    return result;
  }
  return null;
}
```

> Reminder: Replace [YOUR-TRACKING-CONSENT-MSG-ID] with your actual tracking consent message ID from your PAM CMS.

#### Contacting Consent

Contacting Consent allows users to grant permission for communication for marketing purposes. Use the manual flow when you need to inspect the consent message or allow individual permissions selectively:

```dart
import 'package:pam_flutter/pam.dart';

Future<SubmitConsentResult?> allowContactingConsent() async {
  var contactingConsentMessageID = "[YOUR-CONTACTING-CONSENT-MSG-ID]";
  var contactingConsent =
      await Pam.loadConsentMessage(contactingConsentMessageID);
  contactingConsent?.allowAll();

  if (contactingConsent != null) {
    var result = await Pam.submitConsent(contactingConsent);
    return result;
  }
  return null;
}
```

> Reminder: Replace [YOUR-CONTACTING-CONSENT-MSG-ID] with your actual contacting consent message ID from your PAM CMS.

### Push Notifications

#### Saving Push Notification Token

The application owns push setup and token refresh. If your App Server already
uses the device token for system notifications, keep its registration flow
and also register the token with PAM for campaign notifications. This example assumes Firebase
Messaging is already configured in the app. Call this once from your push service
and cancel the subscription when that service is disposed.

```dart
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:pam_flutter/pam.dart';

Future<StreamSubscription<String>> registerPushToken() async {
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
  if (token != null) {
    await savePushToken(token);
  }
  return messaging.onTokenRefresh.listen(savePushToken);
}

Future<void> savePushToken(String token) async {
  final result = await Pam.setPushNotificationToken(token);
  if (result.error != null) {
    // Handle registration failure in your push service.
  }
}
```

The SDK does not fetch a token. If you use the optional `Pam.onToken` platform
callback, call `Pam.setPushNotificationToken` explicitly from your handler.

#### Handling Push Notifications

PAM push helpers accept a `Map<String, dynamic>`. With Firebase Messaging, pass
`message.data`. The integration example responds only to notification taps that
resume the app from the background or launch it from a terminated state. Receiving
a foreground push does not trigger navigation, a banner or popup, or read/click
tracking in this example.

#### Handling Notification Taps

If your app also receives system notifications from your App Server, dispatch
those to its existing handler. Use PAM read tracking for PAM messages.

Use the same handler for a cold start and a tap that resumes the app from the
background. Set up the listener once after PAM initializes and when the app can
handle notification navigation.

```dart
void handlePushTap(RemoteMessage message) {
  if (!Pam.isPushNotiFromPam(message.data)) return;

  final push = Pam.convertToPamPushMessage(message.data);
  if (push == null) return;

  push.trackRead();
  // Navigate using your app's routing rules and push.data.
}

Future<StreamSubscription<RemoteMessage>> listenForPushTaps() async {
  final subscription =
      FirebaseMessaging.onMessageOpenedApp.listen(handlePushTap);
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) handlePushTap(initial);
  return subscription;
}
```

#### Loading Notification History and Tracking Read Status

To load the notification history sent from the PAM system, follow these steps. Please note that the inbox data retrieved is only the raw data, and you'll need to implement the UI to display it.

For the current SDK contact, call `await Pam.loadPushNotifications()`.
You can also load by customer ID with `Pam.loadPushNotificationsFromCustomerID(customerId)`.

For a unified inbox, load PAM campaign messages and your App Server's system
messages, map them to a common app model, and sort by timestamp. Preserve the
source so tapping a row calls `trackRead()` for PAM messages or your existing
read handler for system messages.

##### Load Inbox Data by Email

```dart
import 'package:pam_flutter/pam.dart';

// Load inbox data using the user's email
var userInbox = await Pam.loadPushNotificationsFromEmail("[USER-EMAIL]");
```

##### Load Inbox Data by Mobile Number

```dart
import 'package:pam_flutter/pam.dart';

// Load inbox data using the user's mobile number
var userInbox = await Pam.loadPushNotificationsFromMobile("[USER-MOBILE]");
```

> Reminder: Replace [USER-EMAIL] or [USER-MOBILE] with the actual user's email or mobile number to retrieve their respective inbox.

The userInbox variable will contain an array of messages sent from the PAM system.

##### Track Read Status

```dart
import 'package:pam_flutter/pam.dart';

// Track read status for the first message in the inbox
if (userInbox != null && userInbox.isNotEmpty) {
  userInbox.first.trackRead();
}
```

> By calling trackRead(), you can keep track of whether the user has opened or read the specific message.

> Note: Implement the UI to display the inbox messages as needed.

### User Tracking

#### Signaling User Login

When a user logs into your application, it's important to signal this event to PAM. This helps in associating user activities with their identity for better analytics. Follow these steps to signal user login:

```dart
import 'package:pam_flutter/pam.dart';

// Login key, for example, if your PAM's database uses email to identify users, you can use the user's email
var userIdentity = "[YOUR-LOGIN-IDENTITY]";

// Signal user login to PAM
final result = await Pam.userLogin(userIdentity);
if (result.error != null) {
  // Handle the PAM login failure before sending account-specific events.
}
```

> Note: Replace [YOUR-LOGIN-IDENTITY] with the actual login identity of the user, such as their email or any unique identifier.

By signaling user login to PAM, you ensure that user activities are tracked and associated with their identity for comprehensive analytics.

#### Signaling User Logout

When a user logs out of your application, it's important to signal this event to PAM. This helps in managing user sessions and ensures accurate analytics. Follow these steps to signal user logout:

```dart
import 'package:pam_flutter/pam.dart';

// Signal user logout to PAM
await Pam.userLogout();
```

By signaling user logout to PAM, you contribute to the accurate tracking of user activities and ensure that the analytics reflect the user's session status.

#### Resetting Local PAM Data

To forget the current user's local PAM data, await reset. PAM stays ready to use
with the same app configuration; there is no need to initialize again:

```dart
await Pam.reset();
```

Reset waits for queued operations, removes all PAM keys from secure storage and
SharedPreferences, and clears in-memory contacts, login identity, saved push
token, cached device ID, tracking consent, session, and tracking pause.
App configuration, database aliases, logging settings, and callbacks are preserved.
The next operation chooses the database for the anonymous state from that config.
Other application storage is preserved. Storage failures are thrown so callers
can retry; in-memory state is cleared even if storage cleanup fails.

Reset does not send logout, unlink a server-side push token, or delete server
contacts or tracking history. Use `Pam.userLogout()` first if remote logout is
needed. The OS-provided device ID may be the same when read again; reset does
not change OS tracking or notification permissions. Await reset before
submitting new PAM operations.

`Pam.userLogout()` removes the notification token from the logged-in contact
and does not attach the saved token to the anonymous contact. A token previously
provided by the application remains available for the next explicit
`Pam.userLogin()` transition; the SDK never obtains a token by itself.

#### Optional Identity Cross-Check

You can provide the application's current authentication state as an optional
safety check. `Pam.userLogin()` and `Pam.userLogout()` remain the explicit
triggers that change the SDK session.

```dart
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  identityMatcher: PamIdentityMatcher.primary(
    PamPrimaryIdentityKey.sms,
  ),
  identityProvider: () {
    final user = authRepository.currentUser;
    if (user == null) {
      return const PamUserState.anonymous();
    }

    return PamUserState.identified(user.mobile);
  },
  onIdentityMismatch: (mismatch) async {
    final identity = mismatch.newIdentity;
    if (identity == null) {
      await Pam.userLogout();
    } else {
      await Pam.userLogin(identity.value);
    }
  },
);
```

The identity matcher is fixed for the lifetime of the SDK configuration. Use
one of the CDP primary keys:

```dart
identityMatcher: PamIdentityMatcher.primary(
  PamPrimaryIdentityKey.customer,
)

identityMatcher: PamIdentityMatcher.primary(
  PamPrimaryIdentityKey.email,
)

identityMatcher: PamIdentityMatcher.primary(
  PamPrimaryIdentityKey.sms,
)
```

If your CDP is configured with a secondary matching key, configure it once:

```dart
identityMatcher: PamIdentityMatcher.secondary("line")
```

`Pam.userLogin()` accepts only the identity value. The SDK constructs the
correct primary or secondary identity payload from `identityMatcher`.

The identity provider must synchronously read cached application state. Return
`PamUserState.unknown()` while authentication state is still loading. When the
SDK already has an identity and it does not match the app identity, the current
tracking event is dropped and the global mismatch handler is notified once for
that mismatch state. If the SDK identity is `null`, tracking continues without
calling `onIdentityMismatch`. The first contact can also be created by consent
submission, such as `Pam.allowAllTrackingConsent()`, without `Pam.userLogin()`.

#### Migrating Identity Configuration from 2.x

Version 3 configures the CDP identity matcher once in `PamConfig`.

```dart
// 2.x
Pam.userLogin(
  lineId,
  LoginOptions(alternateKey: "line"),
);

// 3.x
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  identityMatcher: PamIdentityMatcher.secondary("line"),
);

Pam.userLogin(lineId);
```

`LoginOptions` and per-call alternate-key selection were removed in version
3.0.0.

#### Tracking User Events

To track user events and activities, follow these steps:

##### Send Event with Payload

Use the following example code to send an event with a payload:

```dart
import 'package:pam_flutter/pam.dart';

Future<void> trackEvent() async {
  var eventName = "purchase";
  var payload = {
    "product_name": "pizza",
    "size": "big",
    "price": 300
  };
  final result = await Pam.track(eventName, payload: payload);
  if (result?.error != null) {
    // Handle the SDK or server error in your app.
  }
}
```

In this example, the eventName is set to "purchase," and the payload contains additional data related to the purchase event. You can customize the event name and payload based on the specific user activity you want to track.

By calling Pam.track(), you send the event data to PAM for analytics.

##### Tracking order and failures

Await logout before calling login when switching accounts. The SDK serializes
tracking and identity transitions and binds each request to its database and
contact. HTTP requests have a five-second timeout.

When `blockEventsIfNoConsent` is enabled, a regular event blocked by the local
consent check returns `null`. With the optional identity check enabled, an
identity mismatch drops the event and notifies the mismatch handler.

Starting in v3.0.1, the SDK reads the mobile tracking response fields
`error_code`, `error`, and `_database` alongside the legacy fields. PAM errors
such as `UNAUTHORIZED`, `CONTACT_NOT_FOUND`, or `NEED_CONSENT_REVIEW` pause
regular tracking for one hour. During the pause, eligible regular events return
`TRACKING_PAUSED` and are dropped. The next event after the pause can attempt a
new request. The SDK does not replay dropped events.

Login, register, register_success, logout, save_push, test, and allow_consent
can pass the pause check. Successful recovery events such as login, save_push,
and allow_consent can clear the pause early.

## App Attention

App Attention is a comprehensive solution for integrating custom promotional popups into your mobile applications. This feature allows you to display banners, videos, and promotional messages directly within your app, helping to increase user engagement, highlight special offers, and drive traffic to specific URLs.

Designed for flexibility, App Attention provides developers with the ability to customize popup behavior, such as displaying full-screen media or small promotional messages. It supports handling user interactions, such as opening external links or triggering custom app events, ensuring seamless integration into your app's user experience.

#### Campaign and media setup

Create an App Attention campaign in PAM Admin and match its page name to the
app's `pageName`. The original integration guide recommends preparing portrait
creative at 9:16 (720 × 1280), keeping important content roughly 80 px from
each edge at that size. Use those dimensions as a starting point and preview
the chosen campaign layout on representative devices.

#### How to Use

To integrate App Attention into your Flutter application, follow the steps below:

##### Display App Attention

Call the `Pam.appAttention` method to display the App Attention popup. This function can be used to fetch and show banners, videos, or promotional messages based on the pageName you specify.

Here’s an example of how to implement it in your app:

```dart
// Call once when the page is ready, for example from State.initState().
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!context.mounted) return;
  Pam.appAttention(
    context,
    pageName: 'home',
    onBannerClick: (bannerData) {
      return false; // Allow the default banner action.
    },
  );
});
```

##### Explanation

App Attention displays one popup across the app at a time. Calls made while
loading or displaying a popup are skipped for every `pageName`, without a queue.
After dismissal, explicitly call `Pam.appAttention` again to check for another
popup. Empty responses and errors also release the lock. The method returns
`Future<void>` and ignores stale responses/clicks after the calling page or user
session changes. Call it when entering a page, rather than from `build()`.

- `context`: The BuildContext of the current widget tree.
- `pageName`: A string that specifies the current page name, allowing dynamic banners tailored to specific app pages.
- `actionButtonLabel`: Optional label for the action button.
- `actionButtonColor`: Optional button background in `#RRGGBB` format, for example `#0066FF`.
- `actionButtonTextColor`: Optional button text color in `#RRGGBB` format, for example `#FFFFFF`.
- `onBannerClick`: A callback function triggered when the user interacts with the banner. It receives `bannerData` as a parameter, which contains details about the clicked banner. The callback can:
  - Return `true` to stop the default behavior (e.g., open a custom page in your app).
  - Return `false` to proceed with the default behavior (e.g., open the provided URL in the browser).

```dart
Pam.appAttention(
  context,
  pageName: 'home',
  actionButtonLabel: 'View offer',
  actionButtonColor: '#0066FF',
  actionButtonTextColor: '#FFFFFF',
);
```

These options apply on Android and iOS. Colors accept six hex digits with a
leading `#`, in either letter case; invalid colors keep the platform's existing
button color. For each popup payload field (`action_button_label`,
`action_button_color`, `action_button_text_color`), a non-empty API string takes
priority over the corresponding code parameter. Missing, null, empty, or
whitespace-only API values use the code parameter instead. If that parameter is
also omitted, the platform's existing default is used.

The action button is hidden on both platforms when the API's `url` is missing,
null, empty, or whitespace-only, even if a button label or click callback is
provided. The popup content and close button remain available.

## Logging

Set `enableLog` to `true` in `PamConfig` to enable SDK logs. Existing calls still
work; category and level are optional:

```dart
Pam.log(['SDK ready']); // General / INFO
Pam.log(
  ['Failed to load consent'],
  category: PamLogCategory.consent,
  level: PamLogLevel.error,
);
```

Categories: `general`, `tracking`, `identity`, `consent`, `push`, `attention`,
`storage`. Levels: `debug`, `info` (default), `warning`, `error`.
Every output line has a prefix such as `[PAM][Consent][ERROR]`.
`enableLog: false` suppresses all levels.

- **Android Studio Logcat:** use `tag:PAM` for all SDK logs,
  `tag:PAM message:Consent` for consent, or `tag:PAM level:ERROR` for errors.
- **iOS Xcode / Console:** filter subsystem `ai.pams.flutter` and category such
  as `Consent`. DEBUG maps to debug, INFO to info, WARN to default (iOS has no
  warning log type), and ERROR to error. Enable the viewer's info/debug messages
  when inspecting verbose diagnostics. OSLog supports iOS 13 and later.
- **Other platforms or unavailable native logging:** messages fall back to the
  Flutter console, where `[PAM]` and category names can be searched as text.

HTTP logs include a local `request_id`, status, and `duration_ms`. Request and
response bodies are DEBUG; HTTP errors and failed event outcomes are ERROR.
Attention logs explain skipped requests, stale results, popup completion, and
whether each action button setting came from API, code, or defaults. Identity
and storage logs record session changes and reset outcomes.

Rebuild the app after upgrading to include the native logging handlers; hot
reload alone does not install them.

## API Reference

For detailed API documentation, please refer to the source code and inline comments in the `lib/` directory.

Consent submission results include the accepted `consentID` and
`consentMessageID` returned by PAM.

## Examples

Check the `example/` directory for a complete sample application demonstrating the usage of pam_flutter.

## Troubleshooting

- **Configuration Issues**: Ensure all values in `pam_config.dart` are correct, including endpoint, database aliases, and consent message IDs.
- **Debugging**: Set `enableLog` to `true` in `PamConfig`; see Logging above for native console filters.
- **Network and Permissions**: Check internet connection and required permissions (e.g., for push notifications on iOS/Android).
- **PAM CMS Verification**: Verify that keys, IDs, and settings in PAM CMS match your config.
- **Error Checking**: Look for error messages in the console or logs for more details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
