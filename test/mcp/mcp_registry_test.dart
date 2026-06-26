// ignore_for_file: avoid_dynamic_calls, unnecessary_cast
import 'package:rw_git/src/mcp/mcp_registry.dart';
import 'package:rw_git/src/mcp/mcp_tool.dart';
import 'package:test/test.dart';

class MockMcpTool implements McpTool {
  @override
  final String name;

  @override
  final String description;

  @override
  final Map<String, dynamic> inputSchema;

  MockMcpTool(this.name, this.description, this.inputSchema);

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    return 'Success';
  }
}

void main() {
  group('McpRegistry', () {
    late McpRegistry registry;

    setUp(() {
      registry = McpRegistry();
    });

    test('registerTool adds a tool to the registry', () {
      final tool = MockMcpTool('test_tool', 'A test tool', {'type': 'object'});
      registry.registerTool(tool);

      final retrieved = registry.getTool('test_tool');
      expect(retrieved, isNotNull);
      expect(retrieved?.name, 'test_tool');
    });

    test('getTool returns null for unregistered tool', () {
      final retrieved = registry.getTool('unknown_tool');
      expect(retrieved, isNull);
    });

    test('getToolListings returns formatted tool list', () {
      final tool1 = MockMcpTool('tool_1', 'Desc 1', {'type': 'object'});
      final tool2 = MockMcpTool('tool_2', 'Desc 2', {'type': 'string'});
      registry.registerTool(tool1);
      registry.registerTool(tool2);

      final listings = registry.getToolListings();
      expect(listings.length, 2);

      expect(listings[0]['name'], 'tool_1');
      expect(listings[0]['description'], 'Desc 1');
      expect(listings[0]['inputSchema'], {'type': 'object'});

      expect(listings[1]['name'], 'tool_2');
      expect(listings[1]['description'], 'Desc 2');
      expect(listings[1]['inputSchema'], {'type': 'string'});
    });
  });
}
