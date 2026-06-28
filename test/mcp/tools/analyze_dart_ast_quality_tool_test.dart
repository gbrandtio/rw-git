import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

void main() {
  test('AnalyzeDartAstQualityTool properties and error handling', () async {
    final tool = AnalyzeDartAstQualityTool(RwGit());
    expect(tool.name, 'analyze_dart_ast_quality');
    expect(tool.description, isNotEmpty);
    expect(tool.inputSchema, isNotEmpty);

    // Create a temporary git repository for testing
    final tempDir = await Directory.systemTemp.createTemp('rw_git_ast_test_');
    try {
      final rwGit = RwGit();
      await rwGit.init(tempDir.path);

      // Setup initial dart file
      final testFile = File(p.join(tempDir.path, 'test_file.dart'));
      await testFile.writeAsString('void main() {}');

      await rwGit.runCommand(tempDir.path, ['add', 'test_file.dart']);
      await rwGit.runCommand(tempDir.path, ['commit', '-m', 'Initial commit']);

      // Make a change
      await testFile.writeAsString('void main() { print("Hello"); }');
      await rwGit.runCommand(tempDir.path, ['add', 'test_file.dart']);
      await rwGit.runCommand(tempDir.path, ['commit', '-m', 'Second commit']);

      final res = await tool.execute({
        'directory': tempDir.path,
        'baseBranch': 'HEAD~1',
        'targetBranch': 'HEAD'
      });

      expect(res, isNotNull);
      final jsonRes = jsonDecode(res) as Map<String, dynamic>;
      expect(jsonRes['files_analyzed'], contains('test_file.dart'));
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
