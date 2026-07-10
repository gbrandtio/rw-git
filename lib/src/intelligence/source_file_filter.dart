/// ----------------------------------------------------------------------------
/// source_file_filter.dart
/// ----------------------------------------------------------------------------
/// Scopes hotspot-style interpretation to source-code files. Tornhill's
/// hotspot method ("Your Code as a Crime Scene", 2015) is defined over
/// source files: churn x complexity is a refactoring signal only where the
/// "complexity" measures code. The control-flow keyword proxy matches
/// English prose ("if", "for", "while"), so without this scope a
/// constantly-churning CHANGELOG or README outranks genuine code hotspots.
///
/// Deliberately a *denylist* of definitely-not-code files, not an allowlist
/// of known languages: an allowlist would silently drop every language the
/// list doesn't know (Rust, Ruby, C++, ...), which is a worse failure than
/// letting an unknown extension through. Unknown extensions pass.
library;

/// Decides whether a repository path is source code for the purposes of
/// complexity interpretation (refactoring targets, complexity bands, the
/// bounded lexical sample). Raw metric tools stay unfiltered — this scope
/// belongs to the interpretation layer only.
class SourceFileFilter {
  const SourceFileFilter._();

  /// Compact citation tag for the scoping decision.
  static const String researchBasis =
      'Hotspot analysis scoped to source files (Tornhill 2015)';

  /// File extensions (lower-case, with dot) that are definitely not source
  /// code: prose, data/config, lockfiles, media, fonts, archives, logs.
  static const Set<String> nonSourceExtensions = {
    // Prose and documentation.
    '.md', '.markdown', '.mdx', '.rst', '.txt', '.adoc', '.asciidoc', '.tex',
    // Data and configuration.
    '.json', '.yaml', '.yml', '.toml', '.ini', '.cfg', '.conf', '.properties',
    '.csv', '.tsv', '.xml', '.plist', '.env',
    // Lockfiles and checksums.
    '.lock', '.sum',
    // Media.
    '.png', '.jpg', '.jpeg', '.gif', '.svg', '.ico', '.webp', '.bmp', '.pdf',
    '.mp3', '.mp4', '.wav', '.mov',
    // Fonts.
    '.ttf', '.otf', '.woff', '.woff2', '.eot',
    // Archives, binaries, and compiled objects.
    '.zip', '.gz', '.tar', '.jar', '.bin', '.exe', '.dll', '.so', '.dylib',
    '.class', '.o', '.obj', '.a', '.lib', '.out', '.pdb', '.ilk',
    // Project and IDE configuration.
    '.csproj', '.vcxproj', '.fsproj', '.vbproj', '.sln', '.suo', '.user',
    '.targets', '.props', '.filters', '.iml', '.map',
    // Logs.
    '.log',
  };

  /// Basenames (lower-case) that are definitely not source code regardless
  /// of extension — mostly extensionless repo prose and VCS/tooling config.
  static const Set<String> nonSourceBasenames = {
    'license',
    'licence',
    'notice',
    'copying',
    'authors',
    'contributors',
    'changelog',
    'readme',
    'codeowners',
    'owners',
    'version',
    '.gitignore',
    '.gitattributes',
    '.gitmodules',
    '.editorconfig',
    '.npmignore',
    '.dockerignore',
    '.pubignore',
    '.env',
    '.classpath',
    '.project',
    '.packages',
  };

  /// True when [path] may be source code: its extension and basename are
  /// not on the denylists. Unknown extensions (and extensionless files
  /// such as `Makefile`) count as source.
  static bool isSource(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    final basename = normalized.split('/').last.toLowerCase();
    if (nonSourceBasenames.contains(basename)) return false;

    final dot = basename.lastIndexOf('.');
    if (dot <= 0) return true; // No extension, or a dotfile like `.zshrc`.
    return !nonSourceExtensions.contains(basename.substring(dot));
  }
}
