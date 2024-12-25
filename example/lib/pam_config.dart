import 'package:pam_flutter/pam.dart';

class PamConfigProvider {
  static PamConfig getConfig() {
    // Replace the following values with your configuration
    const endpoint = "https://stgx.pams.ai";
    const publicDBAlias = "ecom-public";
    const loginDBAlias = "ecom-login";
    const trackingConsentMessageID = "2VNmHzWrxPYJj0zDiM1cQGeW2S5";

    const debugMode = true; // Enabled log

    return PamConfig(endpoint, publicDBAlias, loginDBAlias,
        trackingConsentMessageID, debugMode);
  }
}
