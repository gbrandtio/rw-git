import 'package:rw_git/src/mcp/utils/mcp_argument_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('McpArgumentExtensions', () {
    test('getStringArgument works', () {
      final map = {'key': 'value'};
      expect(map.getStringArgument('key'), 'value');
    });

    test('getStringArgument throws if missing', () {
      final map = <String, dynamic>{};
      expect(() => map.getStringArgument('key'), throwsArgumentError);
    });

    test('getStringArgument throws if wrong type', () {
      final map = {'key': 123};
      expect(() => map.getStringArgument('key'), throwsArgumentError);
    });

    test('getOptionalStringArgument works', () {
      final map = {'key': 'value'};
      expect(map.getOptionalStringArgument('key'), 'value');
      final map2 = <String, dynamic>{};
      expect(map2.getOptionalStringArgument('key'), isNull);
    });

    test('getOptionalStringArgument throws if wrong type', () {
      final map = {'key': 123};
      expect(() => map.getOptionalStringArgument('key'), throwsArgumentError);
    });
  });
}
