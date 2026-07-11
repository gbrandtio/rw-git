import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

SzzMatch _match({
  required String file,
  required String author,
  required DateTime introducingDate,
  required DateTime fixingDate,
  String introducingCommitHash = 'intro',
  String fixingCommitHash = 'fix',
}) => SzzMatch(
  introducingCommitHash: introducingCommitHash,
  introducingDate: introducingDate,
  introducingAuthor: author,
  fixingCommitHash: fixingCommitHash,
  fixingDate: fixingDate,
  filePath: file,
);

void main() {
  group('BugHotspotsHeuristic.aggregate', () {
    test('aggregates file and author hotspots from a match list', () {
      final matches = [
        _match(
          file: 'file1.dart',
          author: 'Target',
          introducingDate: DateTime.utc(2023, 1, 1, 12),
          fixingDate: DateTime.utc(2023, 1, 2, 12),
        ),
      ];

      final res = BugHotspotsHeuristic().aggregate(matches);

      expect(res.fileHotspots, {'file1.dart': 1});
      expect(res.authorHotspots, {'Target': 1});
      expect(res.totalFixCommitsAnalyzed, 1);
      // Introduced 2023-01-01T12:00Z, fixed 2023-01-02T12:00Z: the SZZ bug
      // lifetime is exactly one day. The metric must be expressed in days so
      // that months-long lifetimes read as such instead of as thousands of
      // hours of "fix time".
      expect(res.globalAverageBugLifetimeInDays, 1.0);
      expect(res.fileAverageBugLifetimeInDays['file1.dart'], 1.0);
      expect(res.authorAverageBugLifetimeInDays['Target'], 1.0);
    });

    test('returns empty aggregates for an empty match list', () {
      final res = BugHotspotsHeuristic().aggregate(const []);

      expect(res.fileHotspots, isEmpty);
      expect(res.authorHotspots, isEmpty);
      expect(res.totalFixCommitsAnalyzed, 0);
      expect(res.globalAverageBugLifetimeInDays, 0.0);
    });

    test('deduplicates fix commits shared by multiple attributions', () {
      final matches = [
        _match(
          file: 'file1.dart',
          author: 'A',
          introducingDate: DateTime.utc(2023, 1, 1),
          fixingDate: DateTime.utc(2023, 1, 2),
          fixingCommitHash: 'shared-fix',
        ),
        _match(
          file: 'file2.dart',
          author: 'B',
          introducingDate: DateTime.utc(2023, 1, 1),
          fixingDate: DateTime.utc(2023, 1, 3),
          fixingCommitHash: 'shared-fix',
        ),
      ];

      final res = BugHotspotsHeuristic().aggregate(matches);

      expect(res.totalFixCommitsAnalyzed, 1);
      expect(res.fileHotspots.length, 2);
    });
  });
}
