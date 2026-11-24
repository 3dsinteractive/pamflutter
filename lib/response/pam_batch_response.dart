import 'dart:convert';
import 'pam_response.dart';

/// Available server results; entries may be omitted and cannot be matched by index.
class PamBatchResponse {
  final List<PamResponse> results;
  final PamErrorResponse? error;

  PamBatchResponse({List<PamResponse> results = const [], this.error})
    : results = List.unmodifiable(results);

  factory PamBatchResponse.failure(String code, String message) =>
      PamBatchResponse(
        error: PamErrorResponse(code: code, errorMessage: message),
      );

  static PamBatchResponse parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a response object.');
      }
      if (decoded.containsKey('results')) {
        final entries = decoded['results'];
        if (entries is! List) {
          throw const FormatException('Expected a results array.');
        }
        final results = entries.map((entry) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('Expected a result object.');
          }
          final result = PamResponse.parse(jsonEncode(entry));
          if (result == null) throw const FormatException('Invalid result.');
          return result;
        }).toList();
        final outer = PamResponse.parse(body);
        return PamBatchResponse(results: results, error: outer?.error);
      }
      if (decoded.isEmpty) return PamBatchResponse();
      final result = PamResponse.parse(body);
      if (result == null) throw const FormatException('Invalid response.');
      return PamBatchResponse(
        results: result.error == null ? [result] : const [],
        error: result.error,
      );
    } catch (error) {
      return PamBatchResponse.failure('INVALID_RESPONSE', error.toString());
    }
  }
}
