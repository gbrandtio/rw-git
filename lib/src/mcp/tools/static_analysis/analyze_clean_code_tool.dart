import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../../rw_git.dart';
import '../../utils/mcp_argument_extensions.dart';

/// analyze_clean_code_tool.dart
/// Language-agnostic tool to analyze basic clean code heuristics.

class AnalyzeCleanCodeTool implements McpTool {
  AnalyzeCleanCodeTool();

  @override
  String get name => 'analyze_clean_code';

  @override
  String get description => 'Language-agnostic tool to analyze basic clean '
      'code heuristics of a specific file. Detects '
      'excessive length, deep nesting (arrow code), '
      'and long lines, which violate SOLID single '
      'responsibility principles.';

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

    final lines = await file.readAsLines();
    final totalLines = lines.length;

    int maxIndentation = 0;
    int longLines = 0;
    int magicNumbers = 0;
    int duplicateLines = 0;
    final seenLines = <String, int>{};

    // Matches numeric literals that are not 0, 1, or -1, and not inside a
    // string or comment (best-effort lexical approximation).
    final magicNumberRegex = RegExp(
      r'(?<!["\w.])\b([2-9]\d*|\d{2,})\b(?!["w.])',
    );
    // Strip inline comments before scanning (// ... and # ...)
    final commentStripRegex = RegExp(r'//.*$|#.*$');

    for (final line in lines) {
      if (line.length > 120) {
        longLines++;
      }

      // Indentation (spaces or tabs)
      int indent = 0;
      for (int i = 0; i < line.length; i++) {
        if (line[i] == ' ') {
          indent++;
        } else if (line[i] == '\t') {
          indent += 4;
        } else {
          break;
        }
      }
      final indentLevel = indent ~/ 4;
      if (indentLevel > maxIndentation) {
        maxIndentation = indentLevel;
      }

      // Magic number detection on code content (stripped of comments).
      final stripped = line.replaceAll(commentStripRegex, '').trim();
      if (stripped.isNotEmpty) {
        magicNumbers += magicNumberRegex.allMatches(stripped).length;

        // Duplicate line detection (ignore blank or very short lines).
        if (stripped.length > 5) {
          seenLines[stripped] = (seenLines[stripped] ?? 0) + 1;
        }
      }
    }

    for (final count in seenLines.values) {
      if (count > 1) duplicateLines += count - 1;
    }

    final issues = <String>[];
    if (totalLines > 300) {
      issues.add(
          'File is too long ($totalLines lines), indicating potential violation of Single Responsibility Principle.');
    }
    if (maxIndentation >= 5) {
      issues.add(
          'Deep nesting detected (max $maxIndentation levels). Consider extracting methods to reduce complexity.');
    }
    if (longLines > totalLines * 0.1) {
      issues.add(
          '$longLines lines are longer than 120 characters, which may affect readability.');
    }
    if (magicNumbers > 10) {
      issues.add(
          '$magicNumbers magic number literals detected. Replace with named constants to improve clarity.');
    }

    return jsonEncode({
      'file': resolvedPath,
      'total_lines': totalLines,
      'max_indentation_level': maxIndentation,
      'long_lines': longLines,
      'magic_numbers': magicNumbers,
      'duplicate_lines': duplicateLines,
      'clean_code_issues': issues,
      'risk_level': issues.isEmpty
          ? 'low'
          : issues.length == 1
              ? 'medium'
              : 'high',
    });
  }
}
