import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  group('Git Models toJson', () {
    test('GitBranch toJson', () {
      const model = GitBranch(name: 'main', isCurrent: true);
      final json = model.toJson();
      expect(json['name'], 'main');
      expect(json['isCurrent'], true);
    });

    test('GitStatus toJson', () {
      const change =
          GitFileChange(status: GitFileStatus.modified, path: 'file.txt');
      const model = GitStatus(stagedChanges: [change]);
      final json = model.toJson();
      expect(json['stagedChanges'], isA<List>());
      final changes = json['stagedChanges'] as List<dynamic>;
      expect((changes.first as Map<String, dynamic>)['path'], 'file.txt');
    });

    test('GitFileChange toJson', () {
      const model =
          GitFileChange(status: GitFileStatus.added, path: 'new.dart');
      final json = model.toJson();
      expect(json['status'], 'added');
      expect(json['path'], 'new.dart');
    });

    test('GitFileDiff toJson', () {
      const model = GitFileDiff(
          path: 'test.dart',
          additions: 2,
          deletions: 1,
          contentDiff: 'modified');
      final json = model.toJson();
      expect(json['path'], 'test.dart');
      expect(json['additions'], 2);
      expect(json['deletions'], 1);
      expect(json['contentDiff'], 'modified');
    });

    test('GitDiff toJson', () {
      const fileDiff = GitFileDiff(
          path: 'f.txt', additions: 1, deletions: 0, contentDiff: 'added');
      const model =
          GitDiff(files: [fileDiff], shortStat: ShortStatDto(1, 1, 0));
      final json = model.toJson();
      expect(json['files'], isA<List>());
      final shortStat = json['shortStat'] as Map<String, dynamic>;
      expect(shortStat['numberOfChangedFiles'], 1);
      expect(shortStat['insertions'], 1);
      expect(shortStat['deletions'], 0);
    });

    test('GitBlameLine toJson', () {
      final date = DateTime.now();
      final model = GitBlameLine(
          commitHash: 'hash',
          author: 'Alice',
          date: date,
          lineNumber: 1,
          content: 'text');
      final json = model.toJson();
      expect(json['commitHash'], 'hash');
      expect(json['author'], 'Alice');
      expect(json['date'], date.toIso8601String());
      expect(json['lineNumber'], 1);
      expect(json['content'], 'text');
    });

    test('GitBlame toJson', () {
      final line = GitBlameLine(
          commitHash: 'h',
          author: 'A',
          date: DateTime.now(),
          lineNumber: 1,
          content: 'c');
      final model = GitBlame(lines: [line]);
      final json = model.toJson();
      expect(json['lines'], isA<List>());
    });
  });
}
