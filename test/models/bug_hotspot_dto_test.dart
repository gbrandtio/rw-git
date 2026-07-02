import 'package:test/test.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';

void main() {
  test('BugHotspotDto toJson exposes SZZ bug-lifetime metrics in days', () {
    final dto = BugHotspotDto(
      fileHotspots: {'file1': 5},
      authorHotspots: {'author1': 3},
      totalFixCommitsAnalyzed: 10,
      globalAverageBugLifetimeInDays: 24.5,
      fileAverageBugLifetimeInDays: {'file1': 48.0},
      authorAverageBugLifetimeInDays: {'author1': 12.0},
    );
    final json = dto.toJson();
    expect(json['file_hotspots'], {'file1': 5});
    expect(json['author_hotspots'], {'author1': 3});
    expect(json['total_fix_commits_analyzed'], 10);
    expect(json['global_average_bug_lifetime_in_days'], 24.5);
    expect(json['file_average_bug_lifetime_in_days'], {'file1': 48.0});
    expect(json['author_average_bug_lifetime_in_days'], {'author1': 12.0});
  });
}
