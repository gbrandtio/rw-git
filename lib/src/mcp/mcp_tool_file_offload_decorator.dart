import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../constants.dart';
import 'mcp_tool.dart';
import 'utils/mcp_argument_extensions.dart';

/// A decorator that adds file-offloading capabilities to any [McpTool].
///
/// This enforces a mandatory default behavior: large JSON responses are written
/// to disk (either to an auto-generated file or an LLM-provided `output_file`)
/// instead of being returned to the LLM, keeping the context window pristine.
/// Responses smaller than [offloadSizeThresholdBytes] are returned inline
/// instead, since offloading them would only add a wasted file-read round
/// trip. The LLM can explicitly opt out by passing `return_full_json: true`.
class McpToolFileOffloadDecorator implements McpTool {
  final McpTool _inner;

  McpToolFileOffloadDecorator(this._inner);

  @override
  String get name => _inner.name;

  @override
  String get description {
    return '${_inner.description}\n\n'
        '(Large responses are offloaded to disk by default — see '
        'get_rw_git_documentation for details. Responses under '
        '${offloadSizeThresholdBytes ~/ 1024}KB are returned inline; pass '
        '`return_full_json: true` to force an inline response.)';
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
      'description': 'Optional. If true, skips file offloading entirely and '
          'returns the full JSON response inline regardless of size. Use '
          'only when you specifically need the full payload in-context.',
    };

    schema['properties'] = properties;
    return schema;
  }

  /// Builds a shallow, schema-agnostic structural index of [decoded] so the
  /// caller can target reads (e.g. via `read_report_slice`) without loading
  /// the entire offloaded file into context.
  Map<String, dynamic>? _buildPreview(dynamic decoded) {
    try {
      if (decoded is Map) {
        final topLevelKeys = <String>[];
        final arrayLengths = <String, int>{};
        final valueTypes = <String, String>{};
        decoded.forEach((key, value) {
          final k = key.toString();
          topLevelKeys.add(k);
          if (value is List) {
            arrayLengths[k] = value.length;
            valueTypes[k] = 'array';
          } else if (value is Map) {
            valueTypes[k] = 'object';
          } else {
            valueTypes[k] = value.runtimeType.toString();
          }
        });
        return {
          'top_level_keys': topLevelKeys,
          'array_lengths': arrayLengths,
          'value_types': valueTypes,
        };
      } else if (decoded is List) {
        return {'top_level_type': 'array', 'length': decoded.length};
      }
      return {'top_level_type': decoded.runtimeType.toString()};
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    // Extract base directory if available.
    String? directory = arguments.getOptionalStringArgument('directory');

    if (directory == null) {
      final filePath = arguments.getOptionalStringArgument('file_path');
      if (filePath != null) {
        directory = p.dirname(filePath);
      }
    }

    // Execute the inner tool to get the raw JSON
    final rawOutput = await _inner.execute(arguments);

    dynamic decoded;
    try {
      decoded = jsonDecode(rawOutput);
      if (decoded is Map && decoded.containsKey('error')) {
        // Return errors directly
        return rawOutput;
      }
    } catch (_) {
      // Not JSON, write/return it anyway
    }

    // Explicit opt-out always wins: skip disk entirely.
    final returnFullJson =
        arguments.getOptionalBoolArgument('return_full_json') ?? false;
    if (returnFullJson) {
      return rawOutput;
    }

    final providedOutputFile =
        arguments.getOptionalStringArgument('output_file');

    // For small payloads with no explicit output_file request, returning
    // inline avoids a wasted file-write + file-read round trip.
    if ((providedOutputFile == null || providedOutputFile.trim().isEmpty) &&
        utf8.encode(rawOutput).length < offloadSizeThresholdBytes) {
      return rawOutput;
    }

    String outputPath;

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

      final summary = <String, dynamic>{
        'status': 'success',
        'message':
            'Tool execution successful. Output offloaded to disk to preserve context window.',
        'file_size_bytes': await file.length(),
        'file': outputPath,
        'hint':
            'To generate a meaningful report, you MUST use your file reading tools to inspect this file and extract the concrete metrics. Do not just inform the user that the file was created. For large files, prefer the read_report_slice tool with this file path and the preview below to fetch only the data you need, instead of reading the whole file.'
      };

      final preview = _buildPreview(decoded);
      if (preview != null) {
        summary['preview'] = preview;
      }

      return jsonEncode(summary);
    } on FileSystemException catch (e) {
      return jsonEncode({
        'error': 'Failed to write output to file',
        'details': e.message,
      });
    }
  }
}
