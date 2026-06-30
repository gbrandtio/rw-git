import '../lexer/token.dart';
import '../language_profile.dart';

/// Base interface for all language-agnostic metric algorithms.
abstract class AgnosticMetricAlgorithm<T> {
  /// Calculates the metric given a stream of tokens and the language profile.
  T calculate(List<Token> tokens, LanguageProfile profile);
}
