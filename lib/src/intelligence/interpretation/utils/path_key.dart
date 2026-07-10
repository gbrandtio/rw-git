/// ----------------------------------------------------------------------------
/// path_key.dart
/// ----------------------------------------------------------------------------
/// Path normalisation so findings from different tools (which quote paths with
/// `a/`/`b/` diff prefixes, leading `./`, or back-slashes) line up on the same
/// join key inside the compound-finding correlator.
library;

/// Normalises file paths for cross-tool joins.
class PathKey {
  const PathKey._();

  /// Canonical form: forward slashes, no `a/`/`b/` diff prefix, no leading
  /// `./` or `/`.
  static String normalize(String path) {
    var normalizedPath = path.trim().replaceAll('\\', '/');
    if (normalizedPath.startsWith('a/') || normalizedPath.startsWith('b/')) {
      normalizedPath = normalizedPath.substring(2);
    }
    while (normalizedPath.startsWith('./')) {
      normalizedPath = normalizedPath.substring(2);
    }
    while (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }
    return normalizedPath;
  }

  /// The top-level directory/module of a path (its first segment), or `''`
  /// when the path has no directory component. Used to decide whether a
  /// coupled pair spans two declared modules.
  static String topDir(String path) {
    final normalizedPath = normalize(path);
    final idx = normalizedPath.indexOf('/');
    return idx == -1 ? '' : normalizedPath.substring(0, idx);
  }
}
