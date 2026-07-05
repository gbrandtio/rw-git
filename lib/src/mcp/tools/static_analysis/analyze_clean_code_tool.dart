import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_clean_code_tool.dart
/// Thin MCP wrapper over [CleanCodeAnalyzer] (library-first, ADR-0005):
/// language-agnostic clean-code heuristics for a specific file.

class AnalyzeCleanCodeTool implements McpTool {
  AnalyzeCleanCodeTool();

  @override
  String get name => 'analyze_clean_code';

  @override
  String get description => 'Language-agnostic tool to analyze basic clean '
      'code heuristics of a specific file. Detects '
      'excessive length, deep nesting (arrow code), '
      'long lines, magic numbers, and duplicate lines, which violate SOLID '
      'single responsibility principles.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description': 'The absolute path to the repository root. '
                'Used to scope file access and prevent path traversal.',
          },
          'file_path': {
            'type': 'string',
            'description': 'Path to the file to analyze, absolute or relative '
                'to directory.',
          }
        },
        'required': ['directory', 'file_path'],
      };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final directory = arguments.getStringArgument('directory');
    final filePath = arguments.getStringArgument('file_path');

    final canonicalDir = p.canonicalize(directory);
    final resolvedPath = p.isAbsolute(filePath)
        ? p.canonicalize(filePath)
        : p.canonicalize(p.join(directory, filePath));

    if (!p.isWithin(canonicalDir, resolvedPath)) {
      return jsonEncode({
        'error': 'file_path must resolve within directory.',
      });
    }

    final file = File(resolvedPath);

    if (!await file.exists()) {
      return jsonEncode({'error': 'File not found'});
    }

    final metrics = const CleanCodeAnalyzer()
        .analyzeSource(resolvedPath, await file.readAsString());

    return jsonEncode({
      'file': resolvedPath,
      'total_lines': metrics.totalLines,
      'max_indentation_level': metrics.maxIndentationLevel,
      'long_lines': metrics.longLines,
      'magic_numbers': metrics.magicNumbers,
      'duplicate_lines': metrics.duplicateLines,
      'clean_code_issues': metrics.issues,
      'risk_level': metrics.issues.isEmpty
          ? 'low'
          : metrics.issues.length == 1
              ? 'medium'
              : 'high',
    });
  }
}
