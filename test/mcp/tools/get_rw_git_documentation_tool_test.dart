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

      expect(result, contains('# RwGit Agent Guide & Documentation'));
      expect(result, contains('**IMPORTANT INSTRUCTIONS FOR AI AGENTS**'));
      expect(
          result,
          contains(
              '**execute_git_command**: Use this to execute raw git commands'));
      expect(result,
          contains('**init_repository**: Initializes a new Git repository.'));
      expect(
          result,
          contains(
              '**clone_repository**: Clones the remote repository URL into a local directory.'));
      expect(
          result,
          contains(
              '**get_stats**: Retrieves code statistics (insertions, deletions) between two tags.'));
    });
  });
}
