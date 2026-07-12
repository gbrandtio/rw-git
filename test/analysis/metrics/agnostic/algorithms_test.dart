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
          if (a) { // depth 0 -> +1 (if)
            if (b) { // depth 1 -> +2 (if)
              while (c) { // depth 2 -> +3 (while)
                 if (d && e || f) {} // depth 3 -> +4 (if) +1 (&&) +1 (||)
              }
            }
          }
        }
      ''');
      final tokens = lexer.tokenize();
      final algorithm = CognitiveComplexityAlgorithm();
      final complexity = algorithm.calculate(tokens, profile);

      expect(complexity, 12);
    });

    test('Cognitive Complexity: function body brace is not nesting', () {
      final tokens = FsmLexer('''
        void main() {
          if (a) {}
        }
      ''').tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(tokens, profile), 1);
    });

    test('Cognitive Complexity: else-if chain scores flat, once per branch',
        () {
      final tokens = FsmLexer('''
        void main() {
          if (a) {} else if (b) {} else {}
        }
      ''').tokenize();
      // if +1, else-if +1, else +1
      expect(CognitiveComplexityAlgorithm().calculate(tokens, profile), 3);
    });

    test('Cognitive Complexity: switch counts once, cases do not', () {
      final tokens = FsmLexer('''
        void main() {
          switch (x) {
            case 1:
            case 2:
              break;
          }
        }
      ''').tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(tokens, profile), 1);
    });

    test('Cognitive Complexity: lambda bodies nest their contents', () {
      final tokens = FsmLexer('''
        void main() {
          items.forEach((x) {
            if (x) {} // lambda depth 1 -> +2
          });
        }
      ''').tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(tokens, profile), 2);
    });

    test('Cognitive Complexity: ternary counts, nullable types do not', () {
      final ternary = FsmLexer('''
        int f() {
          return a ? b : c;
        }
      ''').tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(ternary, profile), 1);

      final nullable = FsmLexer('''
        void f() {
          int? x;
        }
      ''').tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(nullable, profile), 0);
    });

    test('Cognitive Complexity: Python nesting is visible', () {
      final py = DefaultProfiles.python;
      final nested = FsmLexer('''
def f():
    while a:
        for x in xs:
            if b:
                pass
''', py.lexical).tokenize();
      // while +1, for +2, if +3
      expect(CognitiveComplexityAlgorithm().calculate(nested, py), 6);

      final flat = FsmLexer('''
def f():
    if a:
        pass
    if b:
        pass
    if c:
        pass
''', py.lexical).tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(flat, py), 3);
    });

    test('Cognitive Complexity: Python continuation lines do not dedent', () {
      final py = DefaultProfiles.python;
      final tokens = FsmLexer('''
def f():
    if a:
        g(x,
  y)
        if b:
            pass
''', py.lexical).tokenize();
      // if +1, inner if +2 (continuation line `y)` must not pop the frame)
      expect(CognitiveComplexityAlgorithm().calculate(tokens, py), 3);
    });

    test('Cognitive Complexity: Ruby keyword-end nesting', () {
      final rb = DefaultProfiles.ruby;
      final tokens = FsmLexer('''
def f
  if a
    while b
      x = 1 if c
    end
  end
end
''', rb.lexical).tokenize();
      // if +1, while +2, modifier-if +3 (scored at depth, opens no block)
      expect(CognitiveComplexityAlgorithm().calculate(tokens, rb), 6);
    });

    test('Cognitive Complexity: shell if/fi nesting', () {
      final sh = DefaultProfiles.shell;
      final tokens = FsmLexer('''
if a; then
  if b; then
    echo x
  fi
fi
''', sh.lexical).tokenize();
      // if +1, nested if +2
      expect(CognitiveComplexityAlgorithm().calculate(tokens, sh), 3);
    });

    test('Cognitive Complexity: C preprocessor #if is not control flow', () {
      final cProfile = DefaultProfiles.c;
      final tokens = FsmLexer('''
#if DEBUG
int x;
#endif
''', cProfile.lexical).tokenize();
      expect(CognitiveComplexityAlgorithm().calculate(tokens, cProfile), 0);
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

      // Two control frames (if inside if); the function body brace is
      // structural, not nesting.
      expect(result['max_nesting_depth'], 2.0);
      expect(result['average_nesting_depth'], 0.5);
    });

    test('Indentation/Nesting Complexity: empty input keys are consistent',
        () {
      final result = IndentationComplexityAlgorithm().calculate([], profile);
      expect(result.keys,
          containsAll(['max_nesting_depth', 'average_nesting_depth']));
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
