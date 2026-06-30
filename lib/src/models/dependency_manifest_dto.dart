// Immutable DTO for parsed dependency manifests.

class DependencyManifestDto {
  final List<EcosystemReport> ecosystems;

  const DependencyManifestDto({required this.ecosystems});
}

/// A single dependency entry as declared in a manifest, e.g. `lodash: ^4.17.21`.
class DependencyEntry {
  final String name;
  final String declaredVersion;
  final bool isPinned;

  const DependencyEntry({
    required this.name,
    required this.declaredVersion,
    required this.isPinned,
  });
}

class EcosystemReport {
  final String type;
  final String manifestFile;
  final int totalDependencies;
  final int pinnedCount;
  final int floatingCount;
  final bool hasLockFile;
  final List<DependencyEntry> dependencies;

  const EcosystemReport({
    required this.type,
    required this.manifestFile,
    required this.totalDependencies,
    required this.pinnedCount,
    required this.floatingCount,
    required this.hasLockFile,
    this.dependencies = const [],
  });
}
