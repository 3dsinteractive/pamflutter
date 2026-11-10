import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  static PamConfig getDevelopConfig(PamIdentityProvider? identityProvider,
      PamIdentityMismatchHandler? onIdentityMismatch) {
    return _createConfig(
      endpoint: 'https://[example].pams.ai',
      publicDBAlias: 'database-develop',
      loginDBAlias: '',
      trackingConsentMessageID: '..',
      enableLog: true,
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }

  static PamConfig getProductionConfig(PamIdentityProvider? identityProvider,
      PamIdentityMismatchHandler? onIdentityMismatch) {
    return _createConfig(
      endpoint: 'https://[example].pams.ai',
      publicDBAlias: 'database',
      loginDBAlias: '',
      trackingConsentMessageID: '..',
      enableLog: false,
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }

  static PamConfig _createConfig({
    required String endpoint,
    required String publicDBAlias,
    required String loginDBAlias,
    required String trackingConsentMessageID,
    required bool enableLog,
    required PamIdentityProvider? identityProvider,
    required PamIdentityMismatchHandler? onIdentityMismatch,
  }) {
    return PamConfig(endpoint, publicDBAlias, loginDBAlias,
        trackingConsentMessageID, enableLog,
        identityMatcher: PamIdentityMatcher.primary(
          PamPrimaryIdentityKey.customer,
        ),
        identityProvider: identityProvider,
        onIdentityMismatch: onIdentityMismatch);
  }
}
