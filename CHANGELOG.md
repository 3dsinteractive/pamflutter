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
