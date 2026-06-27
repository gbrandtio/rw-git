// Immutable DTO for parsed dependency manifests.

class DependencyManifestDto {
  final List<EcosystemReport> ecosystems;

  const DependencyManifestDto({required this.ecosystems});
}

class EcosystemReport {
  final String type;
  final String manifestFile;
  final int totalDependencies;
  final int pinnedCount;
  final int floatingCount;
  final bool hasLockFile;

  const EcosystemReport({
    required this.type,
    required this.manifestFile,
    required this.totalDependencies,
    required this.pinnedCount,
    required this.floatingCount,
    required this.hasLockFile,
  });
}
