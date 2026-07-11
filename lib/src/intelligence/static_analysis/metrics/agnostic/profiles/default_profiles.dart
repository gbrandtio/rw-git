import '../language_profile.dart';

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
  );

  static const javascript = LanguageProfile(
    name: 'JavaScript/TypeScript',
    fileExtensions: ['.js', '.jsx', '.ts', '.tsx'],
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
  );

  static const java = LanguageProfile(
    name: 'Java/C#',
    fileExtensions: ['.java', '.cs'],
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
  );

  static LanguageProfile getProfileForFile(String filePath) {
    if (filePath.endsWith('.dart')) {
      return dart;
    }
    if (filePath.endsWith('.py')) {
      return python;
    }
    if (filePath.endsWith('.js') ||
        filePath.endsWith('.ts') ||
        filePath.endsWith('.jsx') ||
        filePath.endsWith('.tsx')) {
      return javascript;
    }
    if (filePath.endsWith('.java') || filePath.endsWith('.cs')) {
      return java;
    }
    if (filePath.endsWith('.go')) {
      return go;
    }
    return fallback;
  }
}
