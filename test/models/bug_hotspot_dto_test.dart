import 'package:test/test.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';

void main() {
  test('BugHotspotDto toJson', () {
    final dto = BugHotspotDto(
      fileHotspots: {'file1': 5},
      authorHotspots: {'author1': 3},
      totalFixCommitsAnalyzed: 10,
      globalAverageTimeToFixInHours: 24.5,
      fileAverageTimeToFixInHours: {'file1': 48.0},
      authorAverageTimeToFixInHours: {'author1': 12.0},
    );
    final json = dto.toJson();
    expect(json['file_hotspots'], {'file1': 5});
    expect(json['author_hotspots'], {'author1': 3});
    expect(json['total_fix_commits_analyzed'], 10);
    expect(json['global_average_time_to_fix_in_hours'], 24.5);
    expect(json['file_average_time_to_fix_in_hours'], {'file1': 48.0});
    expect(json['author_average_time_to_fix_in_hours'], {'author1': 12.0});
  });
}
