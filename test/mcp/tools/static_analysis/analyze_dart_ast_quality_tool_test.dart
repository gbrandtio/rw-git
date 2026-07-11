import 'dart:io';
import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/vcs/git_query.dart';
import 'package:test/test.dart';

void main() {
  late StandardProcessRunner runner;
  late RwGit rwGit;
  late AnalyzeDartAstQualityTool tool;
  late Directory tempDir;

  setUp(() async {
    runner = StandardProcessRunner();
    rwGit = RwGit();
    tool = AnalyzeDartAstQualityTool(ReadOnlyGitQuery(runner));
    tempDir = await Directory.systemTemp.createTemp('ast_tool_test');

    await rwGit.init(tempDir.path);

    await runner.run('git', [
      'config',
      'user.name',
      'Test User',
    ], workingDirectory: tempDir.path);
    await runner.run('git', [
      'config',
      'user.email',
      'test@example.com',
    ], workingDirectory: tempDir.path);

    // Create initial commit
    final file1 = File('${tempDir.path}/main.dart');
    await file1.writeAsString('void main() {}');

    // We need 11 files to test the "more than 10 files" branch
    for (var i = 0; i < 11; i++) {
      final f = File('${tempDir.path}/file$i.dart');
      await f.writeAsString('class A$i {}');
    }

    await runner.run('git', ['add', '.'], workingDirectory: tempDir.path);
    await runner.run('git', [
      'commit',
      '-m',
      'Initial',
    ], workingDirectory: tempDir.path);
    await runner.run('git', [
      'branch',
      '-m',
      'master',
    ], workingDirectory: tempDir.path);

    // Create a new branch
    await runner.run('git', [
      'checkout',
      '-b',
      'feature',
    ], workingDirectory: tempDir.path);

    // Modify a file
    await file1.writeAsString('void main() { print("hello"); }');
    await runner.run('git', ['add', '.'], workingDirectory: tempDir.path);
    await runner.run('git', [
      'commit',
      '-m',
      'Update',
    ], workingDirectory: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AnalyzeDartAstQualityTool', () {
    test('has valid name, description, and schema', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });
    test('executes successfully when dart files modified', () async {
      final result = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'master',
        'targetBranch': 'feature',
      });
      expect(result, contains('ast_analysis'));
    });

    test('exceeds scope constraint when 11 files modified', () async {
      // Modify 11 files
      for (var i = 0; i < 11; i++) {
        final f = File('${tempDir.path}/file$i.dart');
        await f.writeAsString('class A$i { int x = 1; }');
      }
      await runner.run('git', ['add', '.'], workingDirectory: tempDir.path);
      await runner.run('git', [
        'commit',
        '-m',
        'Update 11 files',
      ], workingDirectory: tempDir.path);

      final result = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'master',
        'targetBranch': 'feature',
      });
      expect(result, contains('Scope constraint exceeded'));
    });

    test('handles empty merge base or nonexistent branch', () async {
      try {
        final result = await tool.execute({
          'directory': tempDir.path,
          'baseBranch': 'nonexistent',
          'targetBranch': 'feature',
        });
        expect(result, contains('Could not determine merge base'));
      } catch (e) {
        expect(e.toString(), contains('nonexistent'));
      }
    });

    test('handles no dart files modified', () async {
      // Create branch and modify non-dart file
      await runner.run('git', [
        'checkout',
        'master',
      ], workingDirectory: tempDir.path);
      await runner.run('git', [
        'checkout',
        '-b',
        'other',
      ], workingDirectory: tempDir.path);
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsString('hello');
      await runner.run('git', ['add', '.'], workingDirectory: tempDir.path);
      await runner.run('git', [
        'commit',
        '-m',
        'Text',
      ], workingDirectory: tempDir.path);

      final result = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'master',
        'targetBranch': 'other',
      });
      expect(result, contains('No Dart files modified'));
    });

    test('handles deleted dart files gracefully', () async {
      // Create branch and delete a dart file
      await runner.run('git', [
        'checkout',
        'master',
      ], workingDirectory: tempDir.path);
      await runner.run('git', [
        'checkout',
        '-b',
        'delete_test',
      ], workingDirectory: tempDir.path);
      await runner.run('git', [
        'rm',
        'file0.dart',
      ], workingDirectory: tempDir.path);
      await runner.run('git', [
        'commit',
        '-m',
        'Delete',
      ], workingDirectory: tempDir.path);

      final result = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'master',
        'targetBranch': 'delete_test',
      });
      // Will try to read but it's deleted.
      // Files content will be empty
      expect(result, contains('No valid Dart files found on disk to parse'));
    });

    test('handles dart files with syntax errors gracefully', () async {
      await runner.run('git', [
        'checkout',
        'master',
      ], workingDirectory: tempDir.path);
      await runner.run('git', [
        'checkout',
        '-b',
        'syntax_error',
      ], workingDirectory: tempDir.path);

      final file = File('${tempDir.path}/error.dart');
      // Create a file with intentional syntax error
      await file.writeAsString('class A { { { { invalid syntax; }');
      await runner.run('git', ['add', '.'], workingDirectory: tempDir.path);
      await runner.run('git', [
        'commit',
        '-m',
        'Syntax error',
      ], workingDirectory: tempDir.path);

      final result = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'master',
        'targetBranch': 'syntax_error',
      });
      // The AST analyzer shouldn't crash the whole tool
      expect(result, contains('error.dart'));
    });

    test('output includes import_cycles field', () async {
      final result = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'master',
        'targetBranch': 'feature',
      });
      // import_cycles is always present (empty list when no cycles detected)
      expect(result, contains('import_cycles'));
    });
  });
}
