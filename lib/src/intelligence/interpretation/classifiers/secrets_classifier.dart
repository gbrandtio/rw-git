/// ----------------------------------------------------------------------------
/// secrets_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../models/severity.dart';

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
        source: [AnalysisType.detectSecrets],
        severity: Severity.critical,
        subject: normalized.isEmpty ? 'unknown' : normalized,
        metric: 'exposed_secret',
        value: 'redacted',
        band: 'credential exposed in history',
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
