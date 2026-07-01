import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../mcp_tool.dart';
import '../../utils/mcp_argument_extensions.dart';

/// read_report_slice_tool.dart
/// Lets an LLM fetch a targeted slice of a report previously offloaded to
/// disk by [McpToolFileOffloadDecorator], without reading the entire file
/// into context.

class ReadReportSliceTool implements McpTool {
  static const int _defaultLimit = 50;
  static const int _maxLimit = 500;

  @override
  String get name => 'read_report_slice';

  @override
  String get description =>
      'Reads a targeted slice of a JSON report previously offloaded to disk '
      'by another rw_git tool (under .rw_git/reports/), instead of loading '
      'the entire file into context. Use the `path` argument to navigate to '
      'a top-level field (see the `preview` field of the offload summary), '
      'and `offset`/`limit` to page through arrays.';

  @override
  Map<String, dynamic> get inputSchema => {
        'type': 'object',
        'properties': {
          'file': {
            'type': 'string',
            'description':
                'Absolute path to a previously offloaded report file. Must '
                    'reside within a .rw_git/reports directory.',
          },
          'path': {
            'type': 'string',
            'description':
                'Optional dot-separated key path into the JSON (e.g. '
                    '"findings" or "summary.totals"). Omit to operate on '
                    'the root value.',
          },
          'offset': {
            'type': 'integer',
            'description': 'If the resolved value is an array, the start index '
                '(default 0).',
          },
          'limit': {
            'type': 'integer',
            'description': 'If the resolved value is an array, the maximum '
                'number of items to return (default $_defaultLimit, max '
                '$_maxLimit).',
          },
        },
        'required': ['file'],
      };

  Map<String, dynamic>? _previewOf(dynamic value) {
    if (value is Map) {
      final topLevelKeys = <String>[];
      final arrayLengths = <String, int>{};
      value.forEach((key, v) {
        final resourceKey = key.toString();
        topLevelKeys.add(resourceKey);
        if (v is List) arrayLengths[resourceKey] = v.length;
      });
      return {'top_level_keys': topLevelKeys, 'array_lengths': arrayLengths};
    } else if (value is List) {
      return {'top_level_type': 'array', 'length': value.length};
    }
    return null;
  }

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final filePath = arguments.getStringArgument('file');
    final normalizedFile = p.normalize(p.absolute(filePath));

    // The file must sit below an adjacent `.rw_git/reports` component pair;
    // checking the two components independently would accept unrelated paths
    // such as /home/user/reports/.rw_git/x.json.
    final segments = p.split(normalizedFile);
    var insideReportsDirectory = false;
    for (int i = 0; i + 2 < segments.length; i++) {
      if (segments[i] == '.rw_git' && segments[i + 1] == 'reports') {
        insideReportsDirectory = true;
        break;
      }
    }

    if (!insideReportsDirectory) {
      return jsonEncode({
        'error': 'Security violation: file must reside within a '
            '.rw_git/reports directory.',
        'file': normalizedFile,
      });
    }

    final file = File(normalizedFile);
    if (!await file.exists()) {
      return jsonEncode({
        'error': 'File not found',
        'file': normalizedFile,
      });
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } catch (e) {
      return jsonEncode({
        'error': 'Failed to parse file as JSON',
        'details': e.toString(),
      });
    }

    final pathArg = arguments.getOptionalStringArgument('path');
    dynamic resolved = decoded;
    if (pathArg != null && pathArg.trim().isNotEmpty) {
      final segments = pathArg.split('.');
      var traversed = <String>[];
      for (final segment in segments) {
        traversed.add(segment);
        if (resolved is Map && resolved.containsKey(segment)) {
          resolved = resolved[segment];
        } else {
          return jsonEncode({
            'error': 'Path not found',
            'path': traversed.join('.'),
            'available_keys': _previewOf(resolved),
          });
        }
      }
    }

    if (resolved is List) {
      final requestedOffset =
          arguments['offset'] is int ? arguments['offset'] as int : 0;
      final offset = requestedOffset.clamp(0, resolved.length);
      final requestedLimit =
          arguments['limit'] is int ? arguments['limit'] as int : _defaultLimit;
      final limit = requestedLimit.clamp(0, _maxLimit);
      final end = (offset + limit).clamp(0, resolved.length);

      return jsonEncode({
        'path': pathArg ?? '',
        'total_length': resolved.length,
        'offset': offset,
        'limit': limit,
        'data': resolved.sublist(offset, end),
      });
    }

    return jsonEncode({
      'path': pathArg ?? '',
      'data': resolved,
    });
  }
}
