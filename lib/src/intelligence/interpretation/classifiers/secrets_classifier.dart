/// ----------------------------------------------------------------------------
/// secrets_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../finding.dart';
import '../path_key.dart';
import '../severity.dart';

/// Classifies detected secrets. Any exposed credential is Critical; the file
/// path is parsed from the scanner's report line so it can correlate with a
/// vulnerable dependency's configuration.
class SecretsClassifier {
  const SecretsClassifier();

  List<Finding> classify(List<String> rawFindings) {
    final findings = <Finding>[];
    for (final raw in rawFindings) {
      final file = _extractFile(raw);
      final normalized = file.isEmpty ? '' : PathKey.normalize(file);
      findings.add(Finding(
        category: 'secret',
        source: 'detect_secrets_in_commits',
        severity: Severity.critical,
        subject: normalized.isEmpty ? 'unknown' : normalized,
        metric: 'exposed_secret',
        value: 'redacted',
        band: 'credential exposed in history',
        message: normalized.isEmpty
            ? 'Potential secret exposed in commit history.'
            : 'Potential secret exposed in $normalized.',
        evidence: {'detail': raw},
      ));
    }
    return findings;
  }

  String _extractFile(String raw) {
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('File:')) {
        return trimmed.substring('File:'.length).trim();
      }
    }
    return '';
  }
}
