import 'dart:convert';

import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

/// Uses a catalog-covered tool name so [McpToolHintsDecorator] has real
/// hints to inject.
class MockCatalogedTool implements McpTool {
  final Map<String, dynamic> Function() payload;

  MockCatalogedTool(this.payload);

  @override
  String get name => 'analyze_bus_factor';

  @override
  String get description => 'mock';

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async =>
      jsonEncode(payload());
}

class MockErrorTool implements McpTool {
  @override
  String get name => 'analyze_bus_factor';

  @override
  String get description => 'mock';

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async =>
      jsonEncode({'error': 'boom'});
}

class MockNonJsonTool implements McpTool {
  @override
  String get name => 'analyze_bus_factor';

  @override
  String get description => 'mock';

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object'};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async =>
      'not json at all';
}

void main() {
  group('McpToolHintsDecorator', () {
    test('injects catalog hints into a successful payload', () async {
      final decorator = McpToolHintsDecorator(
        MockCatalogedTool(() => {'bus_factor': 1}),
        AnalysisType.busFactor,
      );

      final result =
          jsonDecode(await decorator.execute({})) as Map<String, dynamic>;

      expect(result['bus_factor'], 1);
      final hints = result['hints'] as Map<String, dynamic>;
      expect(hints.containsKey('interpretation'), isTrue);
      expect(hints.containsKey('pair_with'), isTrue);
      expect(
        (hints['interpretation'] as List).first,
        contains('Avelino et al. 2016'),
      );
    });

    test(
      'unions a tool-provided conditional hints object with the catalog',
      () async {
        final decorator = McpToolHintsDecorator(
          MockCatalogedTool(
            () => {
              'bus_factor': 1,
              'hints': {
                'interpretation': ['A conditional, argument-driven hint.'],
              },
            },
          ),
          AnalysisType.busFactor,
        );

        final result =
            jsonDecode(await decorator.execute({})) as Map<String, dynamic>;
        final interpretation =
            (result['hints'] as Map)['interpretation'] as List;

        expect(
          interpretation,
          contains('A conditional, argument-driven hint.'),
        );
        expect(
          interpretation.any((h) => h.toString().contains('Avelino')),
          isTrue,
        );
      },
    );

    test('passes error payloads through untouched', () async {
      final decorator = McpToolHintsDecorator(
        MockErrorTool(),
        AnalysisType.busFactor,
      );
      final resultString = await decorator.execute({});
      final result = jsonDecode(resultString) as Map<String, dynamic>;

      expect(result.containsKey('hints'), isFalse);
      expect(result['error'], 'boom');
    });

    test('passes non-JSON output through untouched', () async {
      final decorator = McpToolHintsDecorator(
        MockNonJsonTool(),
        AnalysisType.busFactor,
      );
      final resultString = await decorator.execute({});

      expect(resultString, 'not json at all');
    });

    test(
      'name, description and inputSchema delegate to the inner tool',
      () async {
        final inner = MockCatalogedTool(() => {});
        final decorator = McpToolHintsDecorator(inner, AnalysisType.busFactor);

        expect(decorator.name, inner.name);
        expect(decorator.description, inner.description);
        expect(decorator.inputSchema, inner.inputSchema);
      },
    );
  });
}
