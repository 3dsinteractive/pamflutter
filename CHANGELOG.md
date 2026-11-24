# 3.2.3

## Fixed

- Block taps and scrolling on the Flutter screen behind App Attention until the native popup closes. Restore interaction after dismissal, action clicks, or presentation errors, including when called from a nested navigator.
- Adapt Full and Large App Attention images and videos to portrait, square, tablet and landscape windows. Full mode fills portrait windows when cropping removes no more than 20% of the media area; otherwise it fits the entire media on a black backdrop. Large mode always fits the entire media within the available space.
- Keep controls and reserved media space stable while loading. Decode images before displaying them and reveal videos when their first frame is ready, without animated resizing or crossfades. Cancel pending media work on dismissal and use the image as a fallback when video fails.
- Accept push notifications with missing or null `flex` without throwing. Return empty `flex` and thumbnail values while preserving the original payload and tracking fields; continue to support text-only messages and messages with images.

## Build and tests

- Align Android Java and Kotlin compilation targets at Java 17 and configure the existing JUnit Platform test runner with Kotlin JUnit 5 dependencies.
- Add regression tests for background interaction, media geometry across window sizes, and push messages with missing, null or empty `flex`.

## Upgrade notes

- Rebuild the host app on both Android and iOS to include the native App Attention changes; hot reload and hot restart do not apply native code changes.
- No API changes or media-dimension fields are required.

# 3.2.2

- Updates the minimum supported SDK version to Flutter 3.44/Dart 3.12.
- Migrates to built-in Kotlin.
- Change dependency on `flutter_secure_storage` to `>=9.2.4 <12.0.0` to avoid conflicts with host apps that use newer versions.

# 3.2.1

## Fixed

- Display Android App Attention edge to edge for both Full and Large layouts, independently of the host app's dialog theme. Hide status and navigation bars while the popup is open and keep controls clear of display cutouts.
- Apply `Bar Color → Background Color` to the fixed bottom section in `Pam.showConsent()`, and use the configured bar text color for its text.
- Apply `Button Color → Background Color` and `Button Color → Text Color` to the consent accept button. Use the button background color for enabled consent switches, with a translucent track.
- Remove the “Required · Always enabled” label from the consent UI in all languages while preserving locked required permissions.

## Upgrade notes

- Rebuild and reinstall the Android app to include the native App Attention changes; hot reload and hot restart do not update native code.

# 3.2.0

## Added

- `Pam.trackBatch()` with `PamTrackEvent` and `PamBatchResponse` to send multiple events for the current user in one request. Reuse one contact and database across the batch; automatically enable `_use_first_contact_id_for_all_events` when no contact ID is available. Apply consent filtering and existing identity and tracking-pause checks. Results may be incomplete and cannot be matched to input events by index; no automatic retry is performed.
- `Pam.showConsent()` with an adaptive consent screen for tracking and contacting permissions, HTML descriptions, language selection, required permissions, and saved or dismissed outcomes through `PamConsentResult`. Preserve choices after save failures, reload details when consent review is required, and prevent duplicate screens or submissions. Dismissal does not save consent.
- `Pam.saveConsent()` with typed `TrackingConsent`, `ContactingConsent`, and `ConsentVersion` selections. Support `fromStatus()` and `copyWith()` to reuse valid stored choices, validate required permissions, and reject selections belonging to a different contact or requiring review. Update local tracking permission only after a successful save of the configured tracking consent message with a returned consent record ID.
- Japanese consent content using PAM's `jp` key and Flutter's `ja` locale, alongside Thai and English. Fall back to available content in Thai, English, then Japanese order.

## Fixed

- Reject batch payloads that override the current contact, database, or identity. Preserve the stored contact when server results contain conflicting IDs or databases, and prevent late batch responses from changing a newer user session's contact or tracking-pause state.
- Accept both direct and `data`-wrapped consent messages, handle missing localized text and optional settings, and fall back safely for invalid consent colors. Read background opacity and button background color from their corresponding settings.
- Parse `latest_version` separately from `last_consent_version`, and support contacting permission responses using `push_notification` with `web_push` as a fallback.
- Only parse consent details and status from successful HTTP responses. Serialize consent saves with startup consent synchronization and queued tracking, and reject stale consent screens after the active session changes.

## Examples and documentation

- Expand the example app with API controls, simulated REST authentication, login/logout and resume synchronization, identity mismatch handling, consent flows, and automated tests. The simulated authentication service is for demonstration only.
- Update consent, initialization, authentication, batch purchase tracking, and example documentation.

## Compatibility and upgrade notes

- Add `flutter_widget_from_html_core` for consent HTML rendering and enable Material icons. `Pam.showConsent()` requires a Material app with a Navigator; existing consent and single-event tracking APIs remain available.
- Raise the plugin's Android compile SDK to 36. Update the example app to Gradle 9.1.0, Android Gradle Plugin 9.0.1, Kotlin 2.3.20, and Java target 17.

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
