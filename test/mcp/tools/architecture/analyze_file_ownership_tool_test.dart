import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  late StandardProcessRunner runner;
  late RwGit rwGit;
  late AnalyzeFileOwnershipTool tool;
  late Directory testDir;

  setUp(() async {
    runner = StandardProcessRunner();
    rwGit = RwGit();
    tool = AnalyzeFileOwnershipTool(runner, ReadOnlyGitQuery(runner));
    testDir = Directory.systemTemp.createTempSync('rw_git_test_');
    await rwGit.init(testDir.path);

    await runner.run(
        'git',
        [
          'config',
          'user.name',
          'Test User',
        ],
        workingDirectory: testDir.path);
    await runner.run(
        'git',
        [
          'config',
          'user.email',
          'test@example.com',
        ],
        workingDirectory: testDir.path);

    // Create CODEOWNERS with various patterns
    final codeowners = File('${testDir.path}/CODEOWNERS');
    await codeowners.writeAsString('''
*.dart @dart-owner
/lib/src/ @lib-owner
mcp/ @mcp-owner
utils/exact.dart @exact-owner
''');

    // Create files matching different patterns
    final exactFile = File('${testDir.path}/utils/exact.dart');
    await exactFile.create(recursive: true);
    await exactFile.writeAsString('void main() {}');

    final dartFile = File('${testDir.path}/lib/test.dart');
    await dartFile.create(recursive: true);
    await dartFile.writeAsString('void main() {}');

    final libFile = File('${testDir.path}/lib/src/test.txt');
    await libFile.create(recursive: true);
    await libFile.writeAsString('hello');

    final mcpFile = File('${testDir.path}/mcp/test.txt');
    await mcpFile.create(recursive: true);
    await mcpFile.writeAsString('hello');

    final unownedFile = File('${testDir.path}/unowned.txt');
    await unownedFile.writeAsString('hello');

    // Commit the changes
    await runner.run('git', ['add', '.'], workingDirectory: testDir.path);
    await runner.run(
        'git',
        [
          'commit',
          '-m',
          'Initial commit',
          '--author',
          'Author One <one@example.com>',
        ],
        workingDirectory: testDir.path);

    // Create recent changes to trigger drift and multiple changes for sorting
    await dartFile.writeAsString('void main() { print("hello"); }');
    await exactFile.writeAsString('void main() { print("exact"); }');
    await unownedFile.writeAsString('hello world');
    await runner.run('git', ['add', '.'], workingDirectory: testDir.path);
    await runner.run(
        'git',
        [
          'commit',
          '-m',
          'Second commit',
          '--author',
          'Author Two <two@example.com>',
        ],
        workingDirectory: testDir.path);

    await dartFile.writeAsString('void main() { print("hello2"); }');
    await runner.run('git', ['add', '.'], workingDirectory: testDir.path);
    await runner.run(
        'git',
        [
          'commit',
          '-m',
          'Third commit',
          '--author',
          'Author Two <two@example.com>',
        ],
        workingDirectory: testDir.path);
  });

  tearDown(() {
    testDir.deleteSync(recursive: true);
  });

  group('AnalyzeFileOwnershipTool', () {
    test('has valid name and description', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('executes successfully and detects codeowners', () async {
      final resultString = await tool.execute({
        'directory': testDir.path,
        'limit': 3,
      });
      expect(resultString, isNotNull);

      final parsed = jsonDecode(resultString) as Map<String, dynamic>;
      expect(parsed['codeowners_found'], isTrue);

      final unowned = parsed['unowned_files'] as List;
      expect(unowned, contains('unowned.txt'));
    });

    test('handles missing CODEOWNERS', () async {
      await runner.run(
          'git',
          [
            'rm',
            'CODEOWNERS',
          ],
          workingDirectory: testDir.path);
      await runner.run(
          'git',
          [
            'commit',
            '-m',
            'remove codeowners',
            '--author',
            'Author Two <two@example.com>',
          ],
          workingDirectory: testDir.path);

      final resultString = await tool.execute({
        'directory': testDir.path,
        'limit': 3,
      });
      expect(resultString, isNotNull);
      final parsed = jsonDecode(resultString) as Map<String, dynamic>;
      expect(parsed['codeowners_found'], isFalse);
    });
  });
}
