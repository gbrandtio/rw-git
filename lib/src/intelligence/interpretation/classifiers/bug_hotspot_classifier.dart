/// ----------------------------------------------------------------------------
/// bug_hotspot_classifier.dart
/// ----------------------------------------------------------------------------
library;

import '../models/analysis_type.dart';

import 'package:rw_git/src/models/bug_hotspot_dto.dart';

import '../models/finding.dart';
import '../utils/path_key.dart';
import '../utils/repo_stats.dart';
import '../models/severity.dart';

/// Classifies bug hotspots two ways: per-file bug lifetime (SZZ introducing
/// commit → fixing commit) against the global average, and hotspot count
/// against the repository's top decile. A file that is a top-decile hotspot
/// is flagged regardless of bug lifetime. Bands are relative (1-2x / >2x the
/// repository's own average), so the unit change from hours to days does not
/// alter any classification.
class BugHotspotClassifier {
  const BugHotspotClassifier();

  List<Finding> classify(BugHotspotDto dto) {
    final global = dto.globalAverageBugLifetimeInDays;
    final decileThreshold = RepoStats.topDecileThreshold(
      dto.fileHotspots.values,
    );

    final files = <String>{
      ...dto.fileHotspots.keys,
      ...dto.fileAverageBugLifetimeInDays.keys,
    };

    final findings = <Finding>[];
    for (final file in files) {
      final lifetimeDays = dto.fileAverageBugLifetimeInDays[file];
      final count = dto.fileHotspots[file] ?? 0;

      var timeSeverity = Severity.normal;
      if (lifetimeDays != null && global > 0) {
        if (lifetimeDays > 2 * global) {
          timeSeverity = Severity.critical;
        } else if (lifetimeDays > global) {
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
        metric = 'file_average_bug_lifetime_in_days';
        value = lifetimeDays;
        band = timeSeverity == Severity.critical
            ? '> 2x global average bug lifetime'
            : '1-2x global average bug lifetime';
      } else {
        metric = 'bug_introductions';
        value = count;
        band = 'top-decile bug-fix count';
      }

      final normalized = PathKey.normalize(file);
      findings.add(
        Finding(
          category: 'bugHotspot',
          source: [AnalysisType.bugHotspots],
          severity: severity,
          subject: normalized,
          metric: metric,
          value: value,
          band: band,
          evidence: {
            'bug_introductions': count,
            if (lifetimeDays != null)
              'file_average_bug_lifetime_in_days': double.parse(
                lifetimeDays.toStringAsFixed(2),
              ),
            'global_average_bug_lifetime_in_days': double.parse(
              global.toStringAsFixed(2),
            ),
            'top_decile': topDecile,
          },
        ),
      );
    }
    return findings;
  }
}
