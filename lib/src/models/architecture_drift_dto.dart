/// architecture_drift_dto.dart
/// Result of the architecture-drift analysis: commits that modify multiple
/// architectural layers at once, the layer-pair coupling matrix, the derived
/// entanglement ratios, and the detected architectural smells (Garcia,
/// Oliveira & Murta 2009).
class ArchitectureDriftDto {
  /// Total commits inspected in the analysis window.
  final int totalCommitsAnalyzed;

  /// Commits whose file set spans more than one architectural layer.
  final List<DriftCommit> driftCommits;

  /// Symmetric layer-pair co-change counts: `matrix[a][b]` is how many drift
  /// commits touched both layer `a` and layer `b`.
  final Map<String, Map<String, int>> couplingMatrix;

  /// Share of analyzed commits that violate layer boundaries.
  final double couplingRatio;

  /// Fraction of possible layer pairs that are coupled at least once.
  final double couplingDensity;

  /// Architectural smells detected from the drift data.
  final List<ArchitecturalSmell> smells;

  const ArchitectureDriftDto({
    required this.totalCommitsAnalyzed,
    required this.driftCommits,
    required this.couplingMatrix,
    required this.couplingRatio,
    required this.couplingDensity,
    required this.smells,
  });

  /// An analysis over an empty history window: nothing to report.
  const ArchitectureDriftDto.empty()
      : totalCommitsAnalyzed = 0,
        driftCommits = const [],
        couplingMatrix = const {},
        couplingRatio = 0,
        couplingDensity = 0,
        smells = const [];
}

/// One commit that modified more than one architectural layer.
class DriftCommit {
  final String hash;
  final String message;
  final List<String> layersCoupled;

  const DriftCommit({
    required this.hash,
    required this.message,
    required this.layersCoupled,
  });

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'message': message,
        'layers_coupled': layersCoupled,
      };
}

/// One detected architectural smell (Garcia, Oliveira & Murta 2009):
/// God Component, Hub-Like Dependency, or Scattered Functionality.
class ArchitecturalSmell {
  final String type;

  /// The offending layer, when the smell is layer-specific (God Component,
  /// Hub-Like Dependency); null for repo-wide smells.
  final String? layer;

  /// Occurrence count, when the smell is count-based (Scattered
  /// Functionality); null otherwise.
  final int? count;

  final String description;

  const ArchitecturalSmell({
    required this.type,
    this.layer,
    this.count,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        if (layer != null) 'layer': layer,
        if (count != null) 'count': count,
        'description': description,
      };
}
