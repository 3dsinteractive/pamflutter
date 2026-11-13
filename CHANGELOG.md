# 3.1.2

## Fixed

- Disable theme-provided background dimming on the Android App Attention dialog so it does not stack with the existing 70% black overlay. Match the iOS backdrop opacity without changing the host app's theme or Activity window.
- Rebuild the Android app after upgrading to include this native change; hot reload alone is insufficient.

# 3.1.1

## Fixed

- Do not call `onIdentityMismatch` or drop tracking events when `oldIdentity` is `null`. Continue checking existing user identities for account switches and logout mismatches, independently of `contactID`.

# 3.1.0

## Added

- Optional `PamLogCategory` and `PamLogLevel` enums for `Pam.log`; existing `Pam.log([...])` calls continue to use General / INFO. Android logs use tag `PAM`; iOS uses OSLog subsystem `ai.pams.flutter` and feature categories. Every line includes a searchable prefix, including stack traces and long Unicode messages, with Flutter console fallback if native logging is unavailable.
- Categorized SDK diagnostics with request IDs, HTTP status and duration, event destinations and error codes, Attention skip reasons and button setting sources, identity session changes, reset outcomes, and native tracking-pixel failures. Payloads and response bodies use DEBUG; failed requests and event outcomes use ERROR. Remove duplicate response output and decorative separators.
- Optional `actionButtonLabel`, `actionButtonColor`, and `actionButtonTextColor` on `Pam.appAttention` for Android and iOS. Colors accept `#RRGGBB`. Non-empty API fields take priority over code values; missing, null, empty, or whitespace-only API fields fall back to code, then native defaults.
- `Pam.reset()` clears PAM user data in secure storage, legacy preferences, and memory after queued work and consent synchronization finish. Preserve configuration, logging settings, and callbacks; do not send logout, delete server data, or require reinitialization. Attempt all storage keys and still clear memory if storage cleanup fails.
- Support public-only and login-only database configurations. Skip tracking with `TRACKING_DISABLED` when no database alias exists for the current session. Public-only login/logout use the public database without database-transfer media cleanup.

## Fixed

- Hide the App Attention action button on Android and iOS when the API's `url` is missing, null, empty, or whitespace-only; keep the popup content and close button available.
- Allow only one pending or visible App Attention across the app. Skip concurrent calls for all page names without queuing. Release the lock after dismissal, empty responses, and errors; require an explicit new call to display another popup.
- Return `Future<void>` from `Pam.appAttention`, contain storage and request failures, and discard responses/clicks after the calling page or user session changes. Move SDK examples out of `build()`.
- Complete native Attention results exactly once after dismissal. Handle Android Back, activity detachment, and missing activities; use the active iOS scene's topmost presenter and report presentation failures instead of leaving pending calls unresolved.
- Serialize enabling tracking consent with consent submission, and await consent preference writes so reset and queued tracking cannot overtake them.
- Remove legacy preference values even when secure-storage deletion fails.

## Compatibility and upgrade notes

- Require Dart 3.11+, Flutter 3.41+, Android API 24+, and iOS 13+.
- Update dependencies, including `flutter_secure_storage` 11.x and `flutter_lints` 6.x. Remove `android_id`; obtain the Android identifier through the SDK's native method channel.
- Rebuild Android and iOS apps after upgrading to include native popup and logging changes; hot reload alone is insufficient. `enableLog: false` continues to disable SDK logs at every level.

# 3.0.4

- Fixed bugs

# 3.0.3

- Add quick allow-all consent helpers for tracking and contacting consent messages.
- Keep manual consent submission unchanged for selective permission use cases.
- Parse `consent_message_id` from `allow_consent` responses and expose it on `AllowConsentResult`.
- Only unlock local tracking after `allowAllTrackingConsent` succeeds.

# 3.0.2

- Remove `package_info_plus` and `device_info_plus` as SDK dependencies so host apps can choose their own versions.
- Read the host app name, version, build number, and OS version directly on Android and iOS. Preserve the existing tracking payload fields and formatting.
- Remove the `uuid` dependency. Generate new session IDs as UUID v4 using Dart's `Random.secure()`. The SDK continues to reuse the ID within a session.

# 3.0.1

    Support the mobile tracking response contract with error_code/error and _database fields.
    Pause normal tracking for one hour when PAM reports authorization, contact, or consent readiness errors.
    Allow login, register, logout, save_push, test, and allow_consent events to pass while tracking is paused.
    Unpause normal tracking after successful recovery events such as allow_consent or login.

# 3.0.0

    Breaking: configure a fixed primary or secondary identity matcher in PamConfig.
    Breaking: remove LoginOptions and per-call alternate-key selection from userLogin().
    Breaking: PamUserState.identified() now accepts only the identity value.
    Breaking: rename mismatch identities to oldIdentity and newIdentity.
    Build primary and secondary CDP identity payloads from the immutable configuration.
    Cancel active HTTP clients on timeout so later identity operations cannot overtake them.
    Prevent local storage errors from skipping remote logout media cleanup.
    Do not re-register a saved push token on the anonymous contact after logout.
    Fix setAllowTracking(false) leaving tracking enabled in memory.
    Stop automatically registering tokens received by the optional platform callback.
    Remove the firebase_messaging dependency; push helpers now accept the PAM data map directly.
    Add a complete 2.x to 3.0 migration guide.
    Run consent synchronization in the background so initialize() does not wait for the server.
    Stop automatically sending a persisted push token during initialize().
    Add an optional identity provider that cross-checks app and SDK identity before tracking.
    Drop mismatched events and report each identity mismatch state once through a global handler.

# 2.4.15

    Preserve the existing public API while making tracking and identity transitions safer.
    Route each event with an immutable database and contact destination.
    Serialize login, logout, account switching, and tracking operations in an in-memory queue.
    Delete push notification media from the previous contact before login or logout.
    Prevent push tokens from being rebound when identity transition requests fail.
    Add a five-second HTTP timeout and allow queued events to continue after timeout or error.

# 2.4.14

    Store string preferences in secure storage instead of plain text SharedPreferences.
    Migrate legacy plain text string preferences so existing users keep their saved IDs and tokens after upgrading.

# 2.4.13

    add click url tracking for push notifications `message.trackPushUrlClick()`

# 2.4.12

    Media will not be deleted when the app attempts to re-login.

# 2.4.11

    use device_info_plus version '>=10.0.1 <12.0.0'

# 2.4.10

    change getDatabaseAlias() to async

# 2.4.9

    PAM will print stacktrace when exception happen

# 2.4.6

    Fixed Android Pixel tracking function

# 2.4.5

    Fixed Empty web attention

# 2.4.4

    Fixed deprecated code.

# 2.4.2

    Fixed, Web attention will work properly.

# 2.4.1

    Added a feature that will send a tracking event to track that the user viewed the App Attention popup.

# 2.4.0

    Added App Attention that allows creating a Banner from CMS to display on any page of the app.

# 2.3.5

Fixed the time display to be correct.

# 2.3.4

Fixed: getContactID

## 2.3.2

Convert timezone for push notification

## 2.3.1

Fixed: pam_flutter will never crash when server response incorrect format

## 2.3.0

Add utility function to handle push notifications

## 2.2.0

Added the ability to log in with a secondary key.

## 2.1.0

Fixed many bugs, added new methods with an emphasis on making them easier to use.

## 2.0.5

Update the dependencies

## 2.0.4

Fixed push notification history reading only for current platform (iOS/Android)

## 2.0.1

fixed bugs

## 2.0.0

Version2
