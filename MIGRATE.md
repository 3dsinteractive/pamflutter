# Migrating from PAM Flutter SDK 2.x to 3.0

Version 3.0 makes identity routing explicit and removes the SDK's dependency on
Firebase Messaging. This is a major release because existing applications must
update their `PamConfig` and some identity or push-notification calls.

## 1. Update the package version

```yaml
dependencies:
  pam_flutter: ^3.0.0
```

Then refresh the application's dependencies:

```sh
flutter pub get
```

## 2. Configure the CDP identity matcher

`identityMatcher` is required in version 3. Configure it once when creating
`PamConfig`. The application can no longer select a different identity key for
each login.

### Primary key: customer

Version 2 used `customer` when `loginKey` was omitted.

```dart
// Version 2
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
);

// Version 3
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  identityMatcher: PamIdentityMatcher.primary(
    PamPrimaryIdentityKey.customer,
  ),
);
```

### Primary key: email or sms

Replace the old `loginKey` string with the corresponding enum.

```dart
// Version 2
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  loginKey: "email",
);

// Version 3
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  identityMatcher: PamIdentityMatcher.primary(
    PamPrimaryIdentityKey.email,
  ),
);
```

Use one of these values according to the permanent primary key configured in
the CDP:

```dart
PamPrimaryIdentityKey.customer
PamPrimaryIdentityKey.email
PamPrimaryIdentityKey.sms
```

### Secondary key

`LoginOptions` and per-call alternate key selection have been removed. Move the
agreed secondary key into `PamConfig`.

```dart
// Version 2
await Pam.userLogin(
  lineId,
  LoginOptions(alternateKey: "line"),
);

// Version 3
final config = PamConfig(
  endpoint,
  publicDBAlias,
  loginDBAlias,
  trackingConsentMessageID,
  enableLog,
  identityMatcher: PamIdentityMatcher.secondary("line"),
);

await Pam.userLogin(lineId);
```

The SDK sends the secondary-key protocol automatically:

```json
{
  "_key_name": "line",
  "_key_value": "LINE_ID",
  "line": "LINE_ID",
  "_force_create": false
}
```

The configured key must match the permanent CDP configuration. Do not derive it
from application state or allow users to change it while the app is running.

## 3. Update `Pam.userLogin`

`Pam.userLogin` now accepts only the identity value.

```dart
// Version 2
await Pam.userLogin(identity, options);

// Version 3
await Pam.userLogin(identity);
```

`Pam.userLogin()` and `Pam.userLogout()` remain the explicit triggers that
change the SDK's identity state.

## 4. Update push-notification helpers

The SDK no longer exposes or depends on Firebase's `RemoteMessage`. Pass the PAM
data map directly.

```dart
// Version 2
final isPam = Pam.isPushNotiFromPam(message);
final pamMessage = Pam.convertToPamPushMessage(message);

// Version 3
final isPam = Pam.isPushNotiFromPam(message.data);
final pamMessage = Pam.convertToPamPushMessage(message.data);
```

Both helpers now accept:

```dart
Map<String, dynamic>
```

The PAM payload contract remains unchanged: the encoded PAM payload is read
from `data["pam"]`.

### Declare Firebase in the application when needed

`firebase_messaging` is no longer a transitive dependency of the PAM SDK. An
application that uses Firebase Messaging must declare its own compatible
version:

```yaml
dependencies:
  firebase_messaging: <version selected by the application>
```

This allows the application to control its Firebase version and avoids SDK
dependency conflicts. Applications using another push provider do not need
Firebase.

## 5. Provide push tokens explicitly

The SDK does not obtain a device token by itself. Continue passing a token from
the application's chosen push provider:

```dart
await Pam.setPushNotificationToken(deviceToken);
```

Important version 3 behavior:

- `Pam.initialize()` does not automatically send a persisted push token.
- A platform token callback does not automatically register the token.
- `Pam.userLogout()` removes notification media from the logged-in contact and
  does not attach the token to the anonymous contact.
- A token previously provided by the application can be reused during the next
  explicit `Pam.userLogin()` transition.

## 6. Optional identity cross-check

Version 3 can compare the application's current cached authentication state
with the SDK state before sending an event.

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

    if (authRepository.isLoading) {
      return const PamUserState.unknown();
    }

    if (user == null) {
      return const PamUserState.anonymous();
    }

    return PamUserState.identified(user.mobile);
  },
  onIdentityMismatch: (mismatch) {
    final identity = mismatch.newIdentity;
    if (identity == null) {
      Pam.userLogout();
    } else {
      Pam.userLogin(identity.value);
    }
  },
);
```

The provider must synchronously read cached application state. It should not
make an API request.

When a mismatch is found:

- The current event is dropped with `IDENTITY_STATE_MISMATCH`.
- The global mismatch handler is notified once for that mismatch state.
- The handler may trigger `Pam.userLogin()` or `Pam.userLogout()`.
- The next event is evaluated against the resolved state.

This feature is optional. If `identityProvider` is omitted, tracking continues
using the explicit SDK state from `Pam.userLogin()` and `Pam.userLogout()`.

## 7. Tracking and initialization behavior

Existing awaited calls remain valid:

```dart
final response = await Pam.track(
  "add_to_cart",
  payload: {"product_id": "SKU-123"},
);
```

Version 3 still supports both awaited and fire-and-forget usage. Network work is
serialized in an in-memory queue and requests have a timeout. The SDK does not
use a durable outbox, so uncompleted events may be lost if the application is
terminated.

`Pam.initialize()` now initializes local state first and synchronizes consent
with the server in the background. Application startup no longer waits for the
consent API response.

## Migration checklist

- [ ] Change the dependency constraint to `pam_flutter: ^3.0.0`.
- [ ] Add the permanent `identityMatcher` to every `PamConfig`.
- [ ] Remove `loginKey` from `PamConfig`.
- [ ] Remove all `LoginOptions` arguments from `Pam.userLogin()`.
- [ ] Pass `message.data` to the PAM push helpers.
- [ ] Declare `firebase_messaging` directly in the app if Firebase is used.
- [ ] Ensure the app explicitly supplies its device token to PAM.
- [ ] Verify logout no longer expects push registration on the anonymous
      contact.
- [ ] Test customer, email, sms, or secondary-key login against the configured
      CDP environment.
- [ ] Test login, account switching, logout, and push-token cleanup.
