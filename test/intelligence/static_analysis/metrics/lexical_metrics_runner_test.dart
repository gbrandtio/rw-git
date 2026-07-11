import 'package:rw_git/rw_git.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/lexical_metrics_runner.dart';
import 'package:test/test.dart';

void main() {
  group('LexicalMetricsRunner', () {
    test('computes metrics synchronously for a given source string', () {
      const sourceCode = '''
        void main() {
          if (true) {
            print('hello');
          }
        }
      ''';

      final metrics = LexicalMetricsRunner.execute('test.dart', sourceCode);

      expect(metrics.filePath, 'test.dart');
      expect(metrics.cyclomaticComplexity, greaterThan(0));
      expect(metrics.maintainabilityIndex, greaterThan(0));
      expect(metrics.abcScore, greaterThanOrEqualTo(0));
      expect(metrics.npathComplexity, greaterThan(0));
      expect(metrics.cognitiveComplexity, greaterThanOrEqualTo(0));
      expect(metrics.halsteadDeliveredBugs, greaterThanOrEqualTo(0));
    });
  });
}
