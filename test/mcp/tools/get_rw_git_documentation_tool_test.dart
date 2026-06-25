import 'package:rw_git/src/mcp/tools/get_rw_git_documentation_tool.dart';
import 'package:test/test.dart';

void main() {
  group('GetRwGitDocumentationTool', () {
    late GetRwGitDocumentationTool tool;

    setUp(() {
      tool = GetRwGitDocumentationTool();
    });

    test('has correct name and input schema', () {
      expect(tool.name, 'get_rw_git_documentation');
      expect(tool.description, contains('Retrieve detailed descriptions'));
      expect(tool.inputSchema['type'], 'object');
      expect((tool.inputSchema['required'] as List).isEmpty, isTrue);
    });

    test('execute returns documentation markdown', () async {
      final result = await tool.execute({});

      expect(result, contains('# RwGit Facade and MCP Tools Documentation'));
      expect(result, contains('init(String directoryToInit)'));
      expect(
          result,
          contains(
              'clone(String localDirectoryToCloneInto, String repository)'));
      expect(
          result, contains('runCommand(String directory, List<String> args)'));
      expect(result,
          contains('execute_git_command(String directory, List<String> args)'));
      expect(result,
          contains('analyze_code_quality(String directory, [int limit = 10])'));
      expect(
          result,
          contains(
              'analyze_code_quality_with_authors(String directory, [int limit = 10])'));
    });
  });
}
