import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../constants.dart';
import 'mcp_resources.dart';
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

  /// When provided, each offloaded report is registered here so it can be
  /// served via the MCP `resources/read` method (in addition to the existing
  /// `read_report_slice` path).
  final ResourceRegistry? resources;

  /// Upper bound on how many pre-classified findings are echoed into the
  /// offload preview to keep an offloaded report actionable without bloating
  /// the inline summary.
  static const int _previewFindingsLimit = 8;

  McpToolFileOffloadDecorator(this._inner, {this.resources});

  @override
  String get name => _inner.name;

  @override
  String get description => '${_inner.description} '
      '(>${offloadSizeThresholdBytes ~/ 1024}KB offloaded to disk.)';

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
      'description':
          'Optional. Absolute path within the repo to save JSON output.',
    };

    properties['return_full_json'] = {
      'type': 'boolean',
      'description': 'Optional. Return full JSON inline instead of offloading.',
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
          final resourceKey = key.toString();
          topLevelKeys.add(resourceKey);
          if (value is List) {
            arrayLengths[resourceKey] = value.length;
            valueTypes[resourceKey] = 'array';
          } else if (value is Map) {
            valueTypes[resourceKey] = 'object';
          } else {
            valueTypes[resourceKey] = value.runtimeType.toString();
          }
        });
        final preview = <String, dynamic>{
          'top_level_keys': topLevelKeys,
          'array_lengths': arrayLengths,
          'value_types': valueTypes,
        };

        // Actionable-inline convention: if the tool produced already-classified
        // findings (the report meta-tools), surface a bounded slice of them
        // right here so a small model can narrate a report from this summary
        // without a second read of the offloaded file. Purely a passthrough —
        // the decorator stays schema-agnostic and just forwards known keys.
        _carryFindings(decoded, preview);

        return preview;
      } else if (decoded is List) {
        return {'top_level_type': 'array', 'length': decoded.length};
      }
      return {'top_level_type': decoded.runtimeType.toString()};
    } catch (_) {
      return null;
    }
  }

  /// Copies a bounded slice of already-classified findings from [decoded] into
  /// [preview] when present, so an offloaded report remains actionable inline.
  void _carryFindings(Map decoded, Map<String, dynamic> preview) {
    final summary = decoded['summary'];
    if (summary is Map) preview['summary'] = summary;

    for (final key in const ['top_findings', 'compound_findings']) {
      final value = decoded[key];
      if (value is List && value.isNotEmpty) {
        preview[key] = value.take(_previewFindingsLimit).toList();
      }
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

      // Expose the offloaded report as an MCP resource so standards-aware
      // clients can fetch it via resources/read.
      final registry = resources;
      if (registry != null) {
        summary['resource_uri'] = registry.register(outputPath);
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
