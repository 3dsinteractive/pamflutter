import '../pam.dart';
import 'pam_log_writer.dart';

/// Common request diagnostics; payloads stay at DEBUG, outcomes at INFO/ERROR.
class PamLogRequest {
  static int _sequence = 0;
  final PamLogCategory category;
  final String operation;
  final String id = 'r${++_sequence}';
  final Stopwatch _timer = Stopwatch()..start();

  PamLogRequest(
    this.category,
    this.operation, {
    Map<String, Object?> details = const {},
  }) {
    Pam.log(
      [
        '$operation request_id=$id started '
            '${details.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}',
      ],
      category: category,
      level: PamLogLevel.debug,
    );
  }

  void payload(String value) {
    _detail('payload', [value], PamLogLevel.debug);
  }

  void _detail(String label, List<Object?> values, PamLogLevel level) {
    if (!Pam.shared.isEnableLog) return;
    // Keep request IDs on every payload/stack line, including long chunks,
    // so filtering one concurrent request retains all of its details.
    final lines = PamLogWriter.splitLines(values, maxBytes: 500);
    Pam.log(
      lines.map((line) => '$operation request_id=$id $label $line').toList(),
      category: category,
      level: level,
    );
  }

  void skip(String reason) {
    _timer.stop();
    Pam.log(
      ['$operation request_id=$id skipped reason=$reason'],
      category: category,
      level: PamLogLevel.debug,
    );
  }

  void complete(int status, {String? body}) {
    _timer.stop();
    Pam.log(
      [
        '$operation request_id=$id status=$status duration_ms=${_timer.elapsedMilliseconds}',
      ],
      category: category,
      level: status >= 400 ? PamLogLevel.error : PamLogLevel.info,
    );
    if (body != null) {
      _detail('response_body', [body], PamLogLevel.debug);
    }
  }

  void fail(Object error, StackTrace stackTrace) {
    _timer.stop();
    _detail('failed duration_ms=${_timer.elapsedMilliseconds}', [
      error,
      stackTrace,
    ], PamLogLevel.error);
  }
}
