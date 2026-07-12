import 'lexer/lexical_profile.dart';

/// How a language expresses block structure, which determines the strategy
/// the [NestingResolver] uses to compute control-flow nesting depth.
enum BlockStructure {
  /// Blocks are delimited by `{ ... }` (C, Dart, JS, Go, Java).
  braces,

  /// Blocks are expressed by indentation (Python).
  indentation,

  /// Blocks open with a keyword and close with a terminator keyword such as
  /// `end`, `fi`, or `done` (Ruby, Lua, shell).
  keywordEnd,
}

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

  /// The block-delimiting style the [NestingResolver] should assume.
  final BlockStructure blockStructure;

  /// [BlockStructure.keywordEnd] only: keywords that open a *control-flow*
  /// block when they appear in statement position (e.g. Ruby `if`, `while`).
  final Set<String> blockOpeners;

  /// [BlockStructure.keywordEnd] only: keywords that open a *structural*
  /// (non-control) block such as a function or class body (e.g. `def`,
  /// `function`). These bound scopes but do not count as cognitive nesting.
  final Set<String> structuralBlockOpeners;

  /// [BlockStructure.keywordEnd] only: keywords that open an anonymous
  /// function / closure block (e.g. Ruby's `do`). Counted as nesting, like
  /// lambdas in brace languages.
  final Set<String> lambdaBlockOpeners;

  /// [BlockStructure.keywordEnd] only: keywords that close a block
  /// (e.g. `end`, `fi`, `done`, `esac`).
  final Set<String> blockClosers;

  /// [BlockStructure.braces] only: operator lexemes that introduce a lambda
  /// body, so a `{` following one opens a lambda frame (e.g. `=>` in JS,
  /// `->` in Java).
  final Set<String> lambdaIntroducers;

  const LanguageProfile({
    required this.name,
    required this.fileExtensions,
    required this.controlFlowKeywords,
    required this.structuralAnchors,
    required this.operatorKeywords,
    this.lexical = LexicalProfile.cFamily,
    this.blockStructure = BlockStructure.braces,
    this.blockOpeners = const {},
    this.structuralBlockOpeners = const {},
    this.lambdaBlockOpeners = const {},
    this.blockClosers = const {},
    this.lambdaIntroducers = const {},
  });

  bool isControlFlow(String lexeme) => controlFlowKeywords.contains(lexeme);
  bool isStructuralAnchor(String lexeme) => structuralAnchors.contains(lexeme);
  bool isOperatorKeyword(String lexeme) => operatorKeywords.contains(lexeme);
}
