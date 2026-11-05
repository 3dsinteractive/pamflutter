import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  /// Pass a provider that reads the application's current authentication state.
  /// Replace `authRepository` with your application's authentication store:
  ///
  /// ```dart
  /// final config = PamConfigProvider.getConfig(
  ///   identityProvider: () {
  ///     if (authRepository.isLoading) {
  ///       return const PamUserState.unknown();
  ///     }
  ///
  ///     final user = authRepository.currentUser;
  ///     if (user == null) {
  ///       return const PamUserState.anonymous();
  ///     }
  ///
  ///     // Use the customer ID matching PamPrimaryIdentityKey.customer below.
  ///     return PamUserState.identified(user.customerId);
  ///   },
  /// );
  /// ```
  ///
  /// Read live state inside the callback so account changes are picked up.
  /// Normal login/logout flows must still call Pam.userLogin/Pam.userLogout.
  static PamConfig getConfig({PamIdentityProvider? identityProvider}) {
    // Replace the following values with your configuration
    const endpoint = "https://stgx.pams.ai";
    const publicDBAlias = "ecom-public";
    const loginDBAlias = "ecom-login";
    const trackingConsentMessageID = "2VNmHzWrxPYJj0zDiM1cQGeW2S5";

    const debugMode = true; // Enabled log

    return PamConfig(
      endpoint,
      publicDBAlias,
      loginDBAlias,
      trackingConsentMessageID,
      debugMode,
      identityMatcher: PamIdentityMatcher.primary(
        PamPrimaryIdentityKey.customer,
      ),
      identityProvider: identityProvider,
      // The mismatched event is skipped. Sync the SDK for subsequent events.
      onIdentityMismatch: (mismatch) async {
        final identity = mismatch.newIdentity;
        if (identity == null) {
          await Pam.userLogout();
        } else {
          await Pam.userLogin(identity.value);
        }
      },
    );
  }
}
