import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'mcp_tool.dart';

/// A decorator that adds file-offloading capabilities to any [McpTool].
///
/// This enforces a mandatory default behavior: large JSON responses are written
/// to disk (either to an auto-generated file or an LLM-provided `output_file`)
/// instead of being returned to the LLM, keeping the context window pristine.
/// The LLM can explicitly opt out by passing `return_full_json: true`.
class McpToolFileOffloadDecorator implements McpTool {
  final McpTool _inner;

  McpToolFileOffloadDecorator(this._inner);

  @override
  String get name => _inner.name;

  @override
  String get description {
    return '${_inner.description}\n\n'
        '**CONTEXT OFFLOADING (MANDATORY DEFAULT)**: By default, the full JSON '
        'response of this tool is written to a file on disk rather than returned '
        'in the chat, to prevent context window overflow. You will receive a '
        'summary and the file path. You can optionally specify the exact '
        '`output_file` path (must be within the repository). '
        'If you absolutely need the raw JSON returned in the chat, set '
        '`return_full_json: true`.';
  }

  @override
  Map<String, dynamic> get inputSchema {
    final schema = Map<String, dynamic>.from(_inner.inputSchema);

    // Ensure properties map exists
    if (!schema.containsKey('properties')) {
      schema['properties'] = <String, dynamic>{};
    }

    final properties = Map<String, dynamic>.from(schema['properties'] as Map);

    properties['output_file'] = {
      'type': 'string',
      'description': 'Optional. Absolute path to save the JSON output. '
          'MUST reside within the target repository directory.',
    };

    properties['return_full_json'] = {
      'type': 'boolean',
      'description': 'Optional. Set to true to opt out of file offloading '
          'and receive the raw JSON in the chat response. (Default: false)',
    };

    schema['properties'] = properties;
    return schema;
  }

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final returnFullJson = arguments['return_full_json'] as bool? ?? false;

    // Extract base directory if available. Many tools require 'directory'.
    final directory = arguments['directory'] as String?;

    // Execute the inner tool to get the raw JSON
    final rawOutput = await _inner.execute(arguments);

    if (returnFullJson) {
      return rawOutput;
    }

    // If the output is an error or already a tiny summary, maybe we shouldn't write it to file?
    try {
      final decoded = jsonDecode(rawOutput);
      if (decoded is Map && decoded.containsKey('error')) {
        // Return errors directly
        return rawOutput;
      }
    } catch (_) {
      // Not JSON, write it anyway
    }

    String outputPath;
    final providedOutputFile = arguments['output_file'] as String?;

    if (providedOutputFile != null && providedOutputFile.trim().isNotEmpty) {
      // Validate path traversal
      outputPath = p.normalize(p.absolute(providedOutputFile));

      if (directory != null) {
        final normalizedDir = p.normalize(p.absolute(directory));
        if (!p.isWithin(normalizedDir, outputPath)) {
          return jsonEncode({
            'error':
                'Security violation: output_file must reside within the repository directory.',
            'directory': normalizedDir,
            'output_file': outputPath,
          });
        }
      }
    } else {
      // Auto-generate file path
      if (directory == null) {
        // If no directory is passed, we must return the full JSON because we don't know where to write securely.
        return rawOutput;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final reportsDir = p.join(directory, '.rw_git', 'reports');
      final reportsDirObj = Directory(reportsDir);

      if (!await reportsDirObj.exists()) {
        await reportsDirObj.create(recursive: true);
      }

      outputPath = p.join(reportsDir, '${_inner.name}_$timestamp.json');
    }

    // Write to file
    try {
      final file = File(outputPath);

      // Ensure parent directory exists for provided output_file
      if (providedOutputFile != null) {
        final parent = file.parent;
        if (!await parent.exists()) {
          await parent.create(recursive: true);
        }
      }

      await file.writeAsString(rawOutput);

      return jsonEncode({
        'status': 'success',
        'message':
            'Tool execution successful. Output offloaded to disk to preserve context window.',
        'file_size_bytes': await file.length(),
        'file': outputPath,
        'hint':
            'You can use file reading tools to inspect this file, or inform the user of its location.'
      });
    } on FileSystemException catch (e) {
      return jsonEncode({
        'error': 'Failed to write output to file',
        'details': e.message,
      });
    }
  }
}
