import 'lexer/lexical_profile.dart';

/// Defines the structural characteristics of a specific programming language.
/// This allows the agnostic metrics engine to identify control flow and operators
/// without a full Abstract Syntax Tree (AST).
class LanguageProfile {
  final String name;
  final List<String> fileExtensions;

  /// The comment and string-literal syntax the [FsmLexer] uses for masking.
  final LexicalProfile lexical;

  /// Keywords that introduce a new branch in control flow, increasing
  /// Cyclomatic and Cognitive complexity.
  final Set<String> controlFlowKeywords;

  /// Keywords or tokens that define the start of a structural boundary
  /// like a function, method, or class.
  final Set<String> structuralAnchors;

  /// Keywords that are treated as operators (e.g., 'and', 'or', 'typeof').
  final Set<String> operatorKeywords;

  const LanguageProfile({
    required this.name,
    required this.fileExtensions,
    required this.controlFlowKeywords,
    required this.structuralAnchors,
    required this.operatorKeywords,
    this.lexical = LexicalProfile.cFamily,
  });

  bool isControlFlow(String lexeme) => controlFlowKeywords.contains(lexeme);
  bool isStructuralAnchor(String lexeme) => structuralAnchors.contains(lexeme);
  bool isOperatorKeyword(String lexeme) => operatorKeywords.contains(lexeme);
}
