import 'package:test/test.dart';
import 'package:rw_git/src/models/bug_hotspot_dto.dart';

void main() {
  test('BugHotspotDto toJson', () {
    final dto = BugHotspotDto(
      fileHotspots: {'file1': 5},
      authorHotspots: {'author1': 3},
      totalFixCommitsAnalyzed: 10,
    );
    final json = dto.toJson();
    expect(json['file_hotspots'], {'file1': 5});
    expect(json['author_hotspots'], {'author1': 3});
    expect(json['total_fix_commits_analyzed'], 10);
  });
}
