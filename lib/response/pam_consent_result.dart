import '../pam.dart' show SubmitConsentResult;
import 'consent_selection.dart';

enum PamConsentOutcome { saved, dismissed }

/// Closing the screen never implies consent or writes a consent event.
final class PamConsentResult {
  final PamConsentOutcome outcome;
  final ConsentSelection? selection;
  final SubmitConsentResult? submission;

  const PamConsentResult.dismissed()
    : outcome = PamConsentOutcome.dismissed,
      selection = null,
      submission = null;

  const PamConsentResult.saved({
    required ConsentSelection this.selection,
    required SubmitConsentResult this.submission,
  }) : outcome = PamConsentOutcome.saved;
}
