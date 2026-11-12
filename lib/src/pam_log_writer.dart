import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../pam_logging.dart';

/// Internal transport. Call Pam.log so enableLog is respected.
@internal
class PamLogWriter {
  static const _channel = MethodChannel('pam_flutter/logging');

  static bool get _usesNative =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> configureNative(bool enabled) async {
    if (!_usesNative) return;
    try {
      await _channel.invokeMethod<void>('configure', {'enabled': enabled});
    } catch (_) {
      // Logging must also work with older native plugins and in Dart-only tests.
    }
  }

  static List<String> splitLines(List<Object?> args, {int maxBytes = 800}) {
    final lines = <String>[];
    // Bound each line by UTF-8 bytes without splitting emoji/surrogate pairs.
    // Use small chunks with room for metadata on both native logging systems.
    for (final value in args) {
      String text;
      try {
        text = value?.toString() ?? '<null>';
      } catch (_) {
        text = '<unprintable>';
      }
      for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
        var chunk = StringBuffer();
        var bytes = 0;
        for (final rune in line.runes) {
          final character = String.fromCharCode(rune);
          final length = utf8.encode(character).length;
          if (bytes + length > maxBytes) {
            lines.add(chunk.toString());
            chunk = StringBuffer();
            bytes = 0;
          }
          chunk.write(character);
          bytes += length;
        }
        lines.add(chunk.toString());
      }
    }
    return lines;
  }

  static Future<void> write(
    List<Object?> args,
    PamLogCategory category,
    PamLogLevel level,
  ) async {
    final lines = splitLines(args);
    if (lines.isEmpty) return;
    if (_usesNative) {
      try {
        await _channel.invokeMethod<void>('log', {
          'category': category.label,
          'level': level.name,
          'lines': lines,
        });
        return;
      } catch (_) {
        // Fall back once; never recursively log a logging failure.
      }
    }
    for (final line in lines) {
      debugPrint('[PAM][${category.label}][${level.label}] $line');
    }
  }
}
