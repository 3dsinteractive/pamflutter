import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  // Edit this file, then restart the example. Runtime uses getDevelopConfig only.
  static const endpoint = 'https://[example].pams.ai';
  static const publicDatabase = 'database-develop';
  static const loginDatabase = '';
  static const trackingMessageId = '';
  static const contactingMessageId = '';

  static PamConfig getDevelopConfig(
    PamIdentityProvider? identityProvider,
    PamIdentityMismatchHandler? onIdentityMismatch,
  ) {
    return _createConfig(
      endpoint: endpoint,
      publicDBAlias: publicDatabase,
      loginDBAlias: loginDatabase,
      trackingConsentMessageID: trackingMessageId,
      enableLog: true,
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }

  static PamConfig getProductionConfig(
    PamIdentityProvider? identityProvider,
    PamIdentityMismatchHandler? onIdentityMismatch,
  ) {
    return _createConfig(
      endpoint: endpoint,
      publicDBAlias: 'database',
      loginDBAlias: loginDatabase,
      trackingConsentMessageID: trackingMessageId,
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
    return PamConfig(
      endpoint,
      publicDBAlias,
      loginDBAlias,
      trackingConsentMessageID,
      enableLog,
      identityMatcher: PamIdentityMatcher.primary(
        PamPrimaryIdentityKey.customer,
      ),
      identityProvider: identityProvider,
      onIdentityMismatch: onIdentityMismatch,
    );
  }
}
