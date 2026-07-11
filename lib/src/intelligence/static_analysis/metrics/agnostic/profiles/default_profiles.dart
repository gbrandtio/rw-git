import '../language_profile.dart';
import '../lexer/lexical_profile.dart';

class DefaultProfiles {
  static const dart = LanguageProfile(
    name: 'Dart',
    fileExtensions: ['.dart'],
    controlFlowKeywords: {
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'catch',
      '?',
      '??',
    },
    structuralAnchors: {
      'class',
      'mixin',
      'extension',
      'void',
      'Future',
      'Stream',
    },
    operatorKeywords: {'as', 'is'},
    lexical: LexicalProfile.dart,
  );

  static const python = LanguageProfile(
    name: 'Python',
    fileExtensions: ['.py'],
    controlFlowKeywords: {
      'if',
      'elif',
      'else',
      'for',
      'while',
      'try',
      'except',
      'finally',
      'with',
      'match',
      'case',
    },
    structuralAnchors: {'def', 'class', 'async'},
    operatorKeywords: {'and', 'or', 'not', 'in', 'is'},
    lexical: LexicalProfile.python,
  );

  static const javascript = LanguageProfile(
    name: 'JavaScript/TypeScript',
    fileExtensions: ['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs'],
    controlFlowKeywords: {
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'catch',
      '?',
    },
    structuralAnchors: {'function', 'class', 'const', 'let', 'var'},
    operatorKeywords: {'typeof', 'instanceof', 'void', 'delete', 'in', 'of'},
    lexical: LexicalProfile.javascript,
  );

  static const java = LanguageProfile(
    name: 'Java/C#',
    fileExtensions: ['.java', '.cs', '.kt', '.scala', '.swift'],
    controlFlowKeywords: {
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'catch',
      '?',
    },
    structuralAnchors: {'class', 'interface', 'public', 'private', 'protected'},
    operatorKeywords: {'instanceof', 'typeof', 'is', 'as'},
    lexical: LexicalProfile.cLike,
  );

  static const c = LanguageProfile(
    name: 'C/C++',
    fileExtensions: ['.c', '.h', '.cpp', '.hpp', '.cc', '.hh', '.cxx'],
    controlFlowKeywords: {
      'if',
      'else',
      'for',
      'while',
      'do',
      'switch',
      'case',
      'catch',
      '?',
    },
    structuralAnchors: {'class', 'struct', 'union', 'enum', 'void', 'template'},
    operatorKeywords: {'sizeof', 'typeof', 'new', 'delete'},
    // cLike keeps `#` tokenized, so preprocessor directives (#include,
    // #define, #if) count as code instead of vanishing as comments.
    lexical: LexicalProfile.cLike,
  );

  static const go = LanguageProfile(
    name: 'Go',
    fileExtensions: ['.go'],
    controlFlowKeywords: {
      'if',
      'else',
      'for',
      'switch',
      'case',
      'select',
      'defer',
      'go',
    },
    structuralAnchors: {'func', 'type', 'struct', 'interface'},
    operatorKeywords: {},
    lexical: LexicalProfile.go,
  );

  static const ruby = LanguageProfile(
    name: 'Ruby',
    fileExtensions: ['.rb', '.rake', '.gemspec'],
    controlFlowKeywords: {
      'if',
      'elsif',
      'else',
      'unless',
      'case',
      'when',
      'while',
      'until',
      'for',
      'rescue',
      'ensure',
      'retry',
    },
    structuralAnchors: {'def', 'class', 'module'},
    operatorKeywords: {'and', 'or', 'not'},
    lexical: LexicalProfile.ruby,
  );

  static const lua = LanguageProfile(
    name: 'Lua',
    fileExtensions: ['.lua'],
    controlFlowKeywords: {
      'if',
      'elseif',
      'else',
      'for',
      'while',
      'repeat',
      'until',
    },
    structuralAnchors: {'function', 'local'},
    operatorKeywords: {'and', 'or', 'not'},
    lexical: LexicalProfile.lua,
  );

  static const shell = LanguageProfile(
    name: 'Shell',
    fileExtensions: ['.sh', '.bash', '.zsh'],
    controlFlowKeywords: {
      'if',
      'elif',
      'else',
      'case',
      'for',
      'while',
      'until',
    },
    structuralAnchors: {'function'},
    operatorKeywords: {},
    lexical: LexicalProfile.shell,
  );

  static const xml = LanguageProfile(
    name: 'XML/HTML',
    fileExtensions: ['.xml', '.html', '.htm', '.svg', '.xaml'],
    controlFlowKeywords: {},
    structuralAnchors: {},
    operatorKeywords: {},
    lexical: LexicalProfile.xml,
  );

  static const fallback = LanguageProfile(
    name: 'Generic/C-Family',
    fileExtensions: [],
    controlFlowKeywords: {
      'if',
      'else',
      'for',
      'while',
      'switch',
      'case',
      'catch',
    },
    structuralAnchors: {'class', 'function', 'def', 'func', 'void'},
    operatorKeywords: {},
    lexical: LexicalProfile.cFamily,
  );

  /// All profiles with extension mappings, consulted in order by
  /// [getProfileForFile].
  static const List<LanguageProfile> all = [
    dart,
    python,
    javascript,
    java,
    c,
    go,
    ruby,
    lua,
    shell,
    xml,
  ];

  static LanguageProfile getProfileForFile(String filePath) {
    final lower = filePath.toLowerCase();
    for (final profile in all) {
      for (final extension in profile.fileExtensions) {
        if (lower.endsWith(extension)) {
          return profile;
        }
      }
    }
    return fallback;
  }
}
