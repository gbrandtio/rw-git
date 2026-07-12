import 'dart:math';

import 'agnostic_metric_algorithm.dart';
import '../lexer/token.dart';
import '../language_profile.dart';
import '../../models.dart';

/// Calculates the ABC Software Size Metric (Fitzpatrick, 1997).
///
/// The ABC score is a 3-vector (Assignments, Branches, Conditions).
/// Unlike Cyclomatic Complexity, ABC captures data-flow complexity (A) that
/// pure control-flow counting misses.
///
/// Thresholds per function: < 15 is good, > 30 signals over-complexity.
class AbcScoreAlgorithm implements AgnosticMetricAlgorithm<AbcScore> {
  static const _assignmentOps = {
    '=',
    '+=',
    '-=',
    '*=',
    '/=',
    '%=',
    '&=',
    '|=',
    '^=',
    '<<=',
    '>>=',
  };

  static const _comparisonOps = {
    '==',
    '!=',
    '<',
    '>',
    '<=',
    '>=',
    '===',
    '!==',
  };

  static const _logicalBranchOps = {'&&', '||', '?'};

  @override
  AbcScore calculate(List<Token> tokens, LanguageProfile profile) {
    int a = 0, b = 0, c = 0;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.type == TokenType.operator) {
        final lex = token.lexeme;
        // Assignment: must not overlap with comparisons (== is not =)
        if (_assignmentOps.contains(lex) && !_comparisonOps.contains(lex)) {
          a++;
        }
        if (_comparisonOps.contains(lex) || _logicalBranchOps.contains(lex)) {
          c++;
        }
      }

      if (token.type == TokenType.identifier) {
        if (profile.isControlFlow(token.lexeme)) {
          c++; // Control flow keywords are conditions (if, while)
        } else {
          // Identify function/method calls for Branches (B)
          // Look ahead for an opening parenthesis '('
          for (var j = i + 1; j < tokens.length; j++) {
            final nextToken = tokens[j];
            if (nextToken.type == TokenType.newline) {
              continue; // skip newlines
            }
            if (nextToken.type == TokenType.punctuation &&
                nextToken.lexeme == '(') {
              b++; // It's a function or method call!
            }
            break; // Stop looking ahead once we hit any non-newline token
          }
        }
      }
    }

    final score = sqrt(a * a + b * b + c * c);
    return AbcScore(
      assignments: a,
      branches: b,
      conditions: c,
      score: double.parse(score.toStringAsFixed(2)),
    );
  }
}
