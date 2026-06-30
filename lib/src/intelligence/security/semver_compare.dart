/// ----------------------------------------------------------------------------
/// semver_compare.dart
/// ----------------------------------------------------------------------------
/// Minimal MAJOR.MINOR.PATCH comparison used to classify how far a declared
/// dependency version is behind the latest available release. Deliberately
/// hand-rolled (no semver package dependency), consistent with the rest of
/// this parser's regex-based approach, and intentionally narrow: pre-release
/// tags, build metadata, and non-numeric segments are not supported and
/// classify as 'unknown' rather than guessed.
library;

class _Version {
  final int major;
  final int minor;
  final int patch;

  const _Version(this.major, this.minor, this.patch);
}

final RegExp _semverPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

_Version? _parse(String raw) {
  var version = raw.trim();
  // Strip common specifier prefixes before parsing.
  for (final prefix in ['^', '~', '>=', '<=', '>', '<', '=', 'v']) {
    if (version.startsWith(prefix)) {
      version = version.substring(prefix.length).trim();
      break;
    }
  }
  final match = _semverPattern.firstMatch(version);
  if (match == null) return null;
  return _Version(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Classifies [declaredVersion] against [latestVersion] as one of:
/// 'current', 'patch_behind', 'minor_behind', 'major_behind', or 'unknown'
/// (when either version cannot be parsed as MAJOR.MINOR.PATCH).
String classifyFreshness(String declaredVersion, String latestVersion) {
  final declared = _parse(declaredVersion);
  final latest = _parse(latestVersion);
  if (declared == null || latest == null) {
    return 'unknown';
  }

  if (declared.major < latest.major) {
    return 'major_behind';
  }
  if (declared.major > latest.major) {
    return 'current';
  }
  if (declared.minor < latest.minor) {
    return 'minor_behind';
  }
  if (declared.minor > latest.minor) {
    return 'current';
  }
  if (declared.patch < latest.patch) {
    return 'patch_behind';
  }
  return 'current';
}
