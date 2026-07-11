// Immutable DTO for a single dependency's freshness check result.

class FreshnessResult {
  final String name;
  final String declaredVersion;
  final String? latestVersion;
  final String
      classification; // current | patch_behind | minor_behind | major_behind | unknown
  final String? error;

  const FreshnessResult({
    required this.name,
    required this.declaredVersion,
    this.latestVersion,
    required this.classification,
    this.error,
  });
}
