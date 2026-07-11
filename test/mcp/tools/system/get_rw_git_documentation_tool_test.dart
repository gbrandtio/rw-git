// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'package:rw_git/src/mcp/tools/system/get_rw_git_documentation_tool.dart';
import 'package:rw_git/src/mcp/mcp_registry.dart';
import 'package:rw_git/src/mcp/mcp_tool.dart';
import 'package:test/test.dart';

class DummyTestTool implements McpTool {
  @override
  String get name => 'dummy_test_tool';

  @override
  String get description =>
      'A dummy tool used for testing the documentation generation.';

  @override
  Map<String, dynamic> get inputSchema => {};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async => '';
}

void main() {
  group('GetRwGitDocumentationTool', () {
    late McpRegistry registry;
    late GetRwGitDocumentationTool tool;

    setUp(() {
      registry = McpRegistry();
      registry.registerTool(DummyTestTool());
      tool = GetRwGitDocumentationTool(registry);
    });

    test('has correct name and input schema', () {
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema.isNotEmpty, isTrue);
      expect(tool.name, 'get_rw_git_documentation');
      expect(tool.description, contains('Retrieve detailed descriptions'));
      expect(tool.inputSchema['type'], 'object');
      expect((tool.inputSchema['required'] as List).isEmpty, isTrue);
    });

    test(
      'execute returns documentation markdown dynamically generated from registry',
      () async {
        final result = await tool.execute({});

        expect(result, contains('# RwGit Agent Guide & Documentation'));
        expect(result, contains('**IMPORTANT INSTRUCTIONS FOR AI AGENTS**'));

        // Verify the dynamically injected dummy tool
        expect(
          result,
          contains(
            '**dummy_test_tool**: A dummy tool used for testing the documentation generation.',
          ),
        );
      },
    );
  });
}
