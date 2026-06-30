import 'dart:io';

import 'package:path/path.dart' as p;

/// Tracks the offloaded report files produced during a server session and
/// exposes them as MCP Resources (`resources/list` / `resources/read`).
///
/// Only files registered here are readable, so the resource surface cannot be
/// used to read arbitrary paths. This gives standards-aware clients a native
/// way to fetch a full offloaded report, while small/local models can keep
/// using `read_report_slice` for targeted reads.
class ResourceRegistry {
  /// Maps a resource `uri` to its absolute filesystem path.
  final Map<String, String> _uriToPath = {};

  /// Registers an offloaded report [absolutePath] and returns its resource URI.
  String register(String absolutePath) {
    final uri = Uri.file(absolutePath).toString();
    _uriToPath[uri] = absolutePath;
    return uri;
  }

  /// Whether [uri] refers to a registered resource.
  bool contains(String uri) => _uriToPath.containsKey(uri);

  /// Resource descriptors for the `resources/list` MCP method.
  List<Map<String, dynamic>> listings() {
    return _uriToPath.entries.map((e) {
      return {
        'uri': e.key,
        'name': p.basename(e.value),
        'mimeType': 'application/json',
      };
    }).toList();
  }

  /// Reads the contents of the resource [uri], or returns null if it is not a
  /// registered resource or no longer exists on disk.
  Future<String?> read(String uri) async {
    final path = _uriToPath[uri];
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
