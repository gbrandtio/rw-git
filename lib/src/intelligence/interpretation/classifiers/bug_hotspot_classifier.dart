/// ----------------------------------------------------------------------------
/// bug_hotspot_classifier.dart
/// ----------------------------------------------------------------------------
library;

import 'package:rw_git/src/models/bug_hotspot_dto.dart';

import '../finding.dart';
import '../path_key.dart';
import '../repo_stats.dart';
import '../severity.dart';

/// Classifies bug hotspots two ways: per-file time-to-fix against the global
/// average, and hotspot count against the repository's top decile. A file that
/// is a top-decile hotspot is flagged regardless of fix time.
class BugHotspotClassifier {
  const BugHotspotClassifier();

  List<Finding> classify(BugHotspotDto dto) {
    final global = dto.globalAverageTimeToFixInHours;
    final decileThreshold =
        RepoStats.topDecileThreshold(dto.fileHotspots.values);

    final files = <String>{
      ...dto.fileHotspots.keys,
      ...dto.fileAverageTimeToFixInHours.keys,
    };

    final findings = <Finding>[];
    for (final file in files) {
      final fixHours = dto.fileAverageTimeToFixInHours[file];
      final count = dto.fileHotspots[file] ?? 0;

      var timeSeverity = Severity.normal;
      if (fixHours != null && global > 0) {
        if (fixHours > 2 * global) {
          timeSeverity = Severity.critical;
        } else if (fixHours > global) {
          timeSeverity = Severity.elevated;
        }
      }

      final topDecile =
          count > 0 && decileThreshold > 0 && count >= decileThreshold;
      final countSeverity = topDecile ? Severity.high : Severity.normal;

      final severity = Severity.max(timeSeverity, countSeverity);
      if (!severity.isMaterial) continue;

      final String metric;
      final Object? value;
      final String band;
      if (severity == timeSeverity && timeSeverity.rank >= countSeverity.rank) {
        metric = 'file_average_time_to_fix_in_hours';
        value = fixHours;
        band = timeSeverity == Severity.critical
            ? '> 2x global average fix time'
            : '1-2x global average fix time';
      } else {
        metric = 'bug_introductions';
        value = count;
        band = 'top-decile bug-fix count';
      }

      final normalized = PathKey.normalize(file);
      findings.add(Finding(
        category: 'bugHotspot',
        source: 'analyze_bug_hotspots',
        severity: severity,
        subject: normalized,
        metric: metric,
        value: value,
        band: band,
        message: 'Bug hotspot $normalized: $count bug-fix commit(s)'
            '${fixHours != null ? ', avg fix ${fixHours.toStringAsFixed(1)}h' : ''}'
            ' (global avg ${global.toStringAsFixed(1)}h).',
        evidence: {
          'bug_introductions': count,
          if (fixHours != null)
            'file_average_time_to_fix_in_hours':
                double.parse(fixHours.toStringAsFixed(2)),
          'global_average_time_to_fix_in_hours':
              double.parse(global.toStringAsFixed(2)),
          'top_decile': topDecile,
        },
      ));
    }
    return findings;
  }
}
