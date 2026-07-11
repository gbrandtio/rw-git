/// ----------------------------------------------------------------------------
/// analysis_type.dart
/// ----------------------------------------------------------------------------
/// Defines the domain concepts for various analytical tools provided by rw_git.
/// This enum decouples the intelligence interpretation layer from specific MCP
/// tool string identifiers.
library;

enum AnalysisType {
  busFactor,
  logicalCoupling,
  architectureDrift,
  dependencyDrift,
  fileOwnership,
  refactoring,
  bugHotspots,
  codeVolatility,
  commitVelocity,
  releaseDelta,
  changelog,
  cleanCode,
  codeQuality,
  dartAstQuality,
  universalLexicalMetrics,
  evaluateComments,
  auditCompliance,
  detectSecrets,
  contributionsByAuthor,
  stats,
  commitsBetween,
  compound,
}
