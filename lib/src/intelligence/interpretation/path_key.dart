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
    var p = path.trim().replaceAll('\\', '/');
    if (p.startsWith('a/') || p.startsWith('b/')) {
      p = p.substring(2);
    }
    while (p.startsWith('./')) {
      p = p.substring(2);
    }
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  /// The top-level directory/module of a path (its first segment), or `''`
  /// when the path has no directory component. Used to decide whether a
  /// coupled pair spans two declared modules.
  static String topDir(String path) {
    final n = normalize(path);
    final idx = n.indexOf('/');
    return idx == -1 ? '' : n.substring(0, idx);
  }
}
