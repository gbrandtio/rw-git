import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/mcp/mcp_prompt.dart';
import 'package:test/test.dart';

class DummyTool implements McpTool {
  @override
  String get name => 'dummy_tool';
  @override
  String get description => 'A dummy tool';
  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};
  @override
  Future<String> execute(Map<String, dynamic> arguments) async => 'done';
}

class DummyPrompt implements McpPrompt {
  @override
  String get name => 'dummy_prompt';
  @override
  String get description => 'A dummy prompt';
  @override
  List<Map<String, dynamic>> get messages => [];
}

void main() {
  group('McpRegistry', () {
    test('Tool registration and lookup', () {
      final registry = McpRegistry();
      final tool = DummyTool();
      registry.registerTool(tool);

      expect(registry.getTool('dummy_tool'), isNotNull);
      expect(registry.getTool('non_existent'), isNull);

      final listings = registry.getToolListings();
      expect(listings.length, 1);
      expect(listings.first['name'], 'dummy_tool');
      expect(listings.first['description'], 'A dummy tool');
      expect(listings.first['inputSchema'], isA<Map>());
    });

    test('Prompt registration and lookup', () {
      final registry = McpRegistry();
      final prompt = DummyPrompt();
      registry.registerPrompt(prompt);

      expect(registry.getPrompt('dummy_prompt'), isNotNull);
      expect(registry.getPrompt('non_existent'), isNull);

      final listings = registry.getPromptListings();
      expect(listings.length, 1);
      expect(listings.first['name'], 'dummy_prompt');
      expect(listings.first['description'], 'A dummy prompt');
    });
  });
}
