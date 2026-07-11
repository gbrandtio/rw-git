import 'package:test/test.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/lexer/fsm_lexer.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/profiles/default_profiles.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/algorithms/cyclomatic_complexity.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/algorithms/halstead_complexity.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/algorithms/cognitive_complexity.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/algorithms/indentation_complexity.dart';
import 'package:rw_git/src/intelligence/static_analysis/metrics/agnostic/algorithms/maintainability_index.dart';

void main() {
  group('Agnostic Algorithms', () {
    final profile = DefaultProfiles.dart;

    test('Cyclomatic Complexity', () {
      final lexer = FsmLexer('''
        void main() {
          if (a) {
            for (var b in c) {
               if (d && e || f) {}
            }
          }
          return a ? b : c;
        }
      ''');
      final tokens = lexer.tokenize();
      final algorithm = CyclomaticComplexityAlgorithm();
      final complexity = algorithm.calculate(tokens, profile);

      // Base (1) + if (1) + for (1) + if (1) + && (1) + ? (1) = 6
      expect(complexity, 7);
    });

    test('Cognitive Complexity penalizes nesting', () {
      final lexer = FsmLexer('''
        void main() {
          if (a) { // depth 1 -> +1 (if)
            if (b) { // depth 2 -> +2 (if)
              while (c) { // depth 3 -> +3 (while)
                 if (d && e || f) {}
              }
            }
          }
        }
      ''');
      final tokens = lexer.tokenize();
      final algorithm = CognitiveComplexityAlgorithm();
      final complexity = algorithm.calculate(tokens, profile);

      expect(complexity, greaterThan(5));
    });

    test('Indentation/Nesting Complexity', () {
      final lexer = FsmLexer('''
        void main() {
          if (a) {
            if (b) {
              print(c);
            }
          }
        }
      ''');
      final tokens = lexer.tokenize();
      final algorithm = IndentationComplexityAlgorithm();
      final result = algorithm.calculate(tokens, profile);

      expect(result['max_nesting_depth'], 3.0);
    });

    test('Halstead Complexity', () {
      final lexer = FsmLexer('int a = 1; int b = 2; int c = a + b; class D {}');
      final tokens = lexer.tokenize();
      final algorithm = HalsteadComplexityAlgorithm();
      final result = algorithm.calculate(tokens, profile);

      expect(result.vocabulary, greaterThan(0));
      expect(result.volume, greaterThan(0));
      expect(result.difficulty, greaterThan(0));
    });

    test('Maintainability Index', () {
      final lexer = FsmLexer(
        'int a = 1;\nint b = 2;\nint c = a + b; class D {}',
      );
      final tokens = lexer.tokenize();
      final algorithm = MaintainabilityIndexAlgorithm();
      final result = algorithm.calculate(tokens, profile);

      // A simple 3-liner should be highly maintainable
      expect(result.score, greaterThan(65.0));
      expect(result.category, 'Moderate');
    });
  });
}
