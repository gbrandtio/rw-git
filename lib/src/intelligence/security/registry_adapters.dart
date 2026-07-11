import 'dart:convert';

/// ----------------------------------------------------------------------------
/// registry_adapters.dart
/// ----------------------------------------------------------------------------
/// Per-ecosystem package registry lookups: builds the request (URL + any
/// required headers) and extracts the "latest version" field from the JSON
/// response. Kept as pure data/parsing (no networking) so it's testable in
/// isolation from DependencyFreshnessChecker.

/// Everything needed to perform and interpret one registry lookup.
class RegistryRequest {
  final Uri uri;
  final Map<String, String> headers;
  final String? Function(Map<String, dynamic> json) extractVersion;

  const RegistryRequest({
    required this.uri,
    this.headers = const {},
    required this.extractVersion,
  });
}

/// Builds the registry request for [packageName] in the given [ecosystemType].
/// Returns null for ecosystems with no known registry lookup (e.g. unsupported
/// types), so callers can classify those as 'unknown' instead of crashing.
RegistryRequest? buildRegistryRequest(
  String ecosystemType,
  String packageName,
) {
  switch (ecosystemType) {
    case 'dart':
      return RegistryRequest(
        uri: Uri.parse('https://pub.dev/api/packages/$packageName'),
        extractVersion: (json) {
          final latest = json['latest'];
          if (latest is! Map<String, dynamic>) return null;
          return latest['version'] as String?;
        },
      );

    case 'npm':
      return RegistryRequest(
        uri: Uri.parse(
          'https://registry.npmjs.org/${_encodeNpmPackageName(packageName)}/latest',
        ),
        extractVersion: (json) => json['version'] as String?,
      );

    case 'python':
      return RegistryRequest(
        uri: Uri.parse('https://pypi.org/pypi/$packageName/json'),
        extractVersion: (json) {
          final info = json['info'];
          if (info is! Map<String, dynamic>) return null;
          return info['version'] as String?;
        },
      );

    case 'rust':
      return RegistryRequest(
        uri: Uri.parse('https://crates.io/api/v1/crates/$packageName'),
        headers: const {
          'User-Agent': 'rw-git (https://github.com/rw-core/rw-git)',
        },
        extractVersion: (json) {
          final crate = json['crate'];
          if (crate is! Map<String, dynamic>) return null;
          return crate['max_stable_version'] as String?;
        },
      );

    case 'go':
      final escaped = _escapeGoModulePath(packageName);
      if (escaped == null) return null;
      return RegistryRequest(
        uri: Uri.parse('https://proxy.golang.org/$escaped/@latest'),
        extractVersion: (json) => json['Version'] as String?,
      );

    case 'ruby':
      return RegistryRequest(
        uri: Uri.parse('https://rubygems.org/api/v1/gems/$packageName.json'),
        extractVersion: (json) => json['version'] as String?,
      );

    default:
      return null;
  }
}

/// Parses a registry response body as JSON and extracts the latest version
/// using [request]'s extractor. Returns null on any parse/shape failure.
String? extractLatestVersion(RegistryRequest request, String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return null;
    return request.extractVersion(decoded);
  } catch (_) {
    return null;
  }
}

/// npm scoped packages (e.g. "@scope/name") must have the "/" URL-encoded
/// as "%2f" in the registry path.
String _encodeNpmPackageName(String name) {
  if (!name.startsWith('@')) return name;
  final slashIndex = name.indexOf('/');
  if (slashIndex == -1) return name;
  return '${name.substring(0, slashIndex)}%2f${name.substring(slashIndex + 1)}';
}

/// Escapes a Go module path per the Go module proxy protocol: every
/// uppercase letter is replaced with "!" followed by its lowercase form
/// (e.g. "BurntSushi" -> "!burnt!sushi"). Returns null if the input is empty.
String? _escapeGoModulePath(String modulePath) {
  if (modulePath.isEmpty) return null;
  final buffer = StringBuffer();
  for (final rune in modulePath.runes) {
    final char = String.fromCharCode(rune);
    if (char.toUpperCase() == char && char.toLowerCase() != char) {
      buffer.write('!${char.toLowerCase()}');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}
