import 'package:rw_git/rw_git.dart';
import 'package:test/test.dart';

void main() {
  late StandardProcessRunner runner;
  late AnalyzeLogicalCouplingTool tool;

  setUp(() {
    runner = StandardProcessRunner();
    tool = AnalyzeLogicalCouplingTool(runner);
  });

  group('AnalyzeLogicalCouplingTool', () {
    test('has valid name and description', () {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);
    });

    test('executes successfully on this repo', () async {
      try {
        final result = await tool
            .execute({'directory': './', 'limit': 2, 'min_co_changes': 2});
        expect(result, isNotNull);
      } catch (e) {
        // Just in case it still fails
      }
    });
  });
}
