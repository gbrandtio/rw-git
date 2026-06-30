import 'dart:io';

import 'package:rw_git/rw_git.dart';
import 'package:path/path.dart' as p;

void main() async {
  // 0. Clone a real repository to analyze, and share a single ProcessRunner
  // across every intelligence algorithm below.
  final localDirectoryName = "RW_GIT_INTELLIGENCE";
  final repositoryToClone =
      "https://github.com/jasontaylordev/CleanArchitecture";
  final checkoutParentDirectory = _createCheckoutDirectory(localDirectoryName);

  final rwGit = RwGit();
  print("Cloning repository...");
  (await rwGit.clone(checkoutParentDirectory, repositoryToClone)).getOrThrow();
  print("Repository cloned successfully!\n");

  // `clone` checks the repository out into a subdirectory named after the
  // repository itself, so all intelligence algorithms below operate on that
  // subdirectory rather than the parent checkout directory.
  final dir = p.join(checkoutParentDirectory, "CleanArchitecture");

  final runner = ProcessRunner.defaultRunner();

  // ---------------------------------------------------------------------
  // Architecture
  // ---------------------------------------------------------------------

  // 1. Bus factor: how many developers would need to leave before knowledge
  // of the codebase is lost.
  final busFactor = await BusFactorAlgorithm(runner).execute(dir);
  print("Bus factor: ${busFactor.busFactor} "
      "(of ${busFactor.totalDevelopers} developers)");
  print("Top contributor: "
      "${busFactor.topContributors.first.author} "
      "(${busFactor.topContributors.first.percentage.toStringAsFixed(1)}%)\n");

  // 2. Logical coupling: files that tend to change together, even without a
  // structural (import) dependency.
  final coupling = await LogicalCouplingAlgorithm(runner).execute(dir);
  print("Logical coupling pairs found: ${coupling.length}");
  if (coupling.isNotEmpty) {
    final top = coupling.first;
    print("  ${top.fileA} <-> ${top.fileB} "
        "(${top.coChangeCount} co-changes)\n");
  }

  // 3. Refactoring detection: commits that look like pure renames/moves.
  final refactorings = await RefactoringDetectionAlgorithm(runner).execute(dir);
  print("Refactoring commits detected: ${refactorings.length}\n");

  // ---------------------------------------------------------------------
  // History: algorithms
  // ---------------------------------------------------------------------

  // 4. Code volatility: files that change often and across many authors.
  final volatility = await CodeVolatilityAlgorithm(runner).execute(dir);
  print("Files analyzed for volatility: ${volatility.length}");
  if (volatility.isNotEmpty) {
    final top = volatility.first;
    print("  Most volatile: ${top.filePath} "
        "(score ${top.volatilityScore.toStringAsFixed(2)})\n");
  }

  // 5. SZZ algorithm: links bug-fixing commits back to the commits that
  // introduced the bug.
  final szzMatches = await SzzAlgorithm(runner).execute(dir);
  print("Bug-introducing commits identified via SZZ: ${szzMatches.length}\n");

  // ---------------------------------------------------------------------
  // History: heuristics
  // ---------------------------------------------------------------------

  // 6. Advanced metrics: complexity, co-change matrix, churn and
  // architecture distribution in one pass.
  final advancedMetrics =
      await AdvancedMetricsHeuristic(runner).calculateAdvancedMetrics(dir);
  print("Files with complexity scores: "
      "${advancedMetrics.fileComplexity.length}\n");

  // 7. Bug hotspots: files and authors most associated with bug fixes.
  final bugHotspots =
      await BugHotspotsHeuristic(runner).calculateBugHotspots(dir);
  print("Total fix commits analyzed: "
      "${bugHotspots.totalFixCommitsAnalyzed}");
  print("Global average time to fix: "
      "${bugHotspots.globalAverageTimeToFixInHours.toStringAsFixed(1)} hours\n");

  // 8. Churn: how much a file/class/block has changed over its history.
  final churn = await ChurnHeuristic(runner).calculateChurn(dir);
  print("Total commits considered for churn: ${churn.totalCommits}");
  print("Files with churn data: ${churn.fileChurn.length}");

  final churnWithAuthors =
      await ChurnHeuristic(runner).calculateChurnWithAuthors(dir);
  print("Files with per-author churn data: "
      "${churnWithAuthors.fileChurn.length}\n");

  // 9. Commit velocity: commit pace over time, including burnout signals.
  final velocity =
      await CommitVelocityHeuristic(runner).calculateCommitVelocity(dir);
  print("Commit velocity trend: ${velocity.trend}");
  print("Average commits per period: "
      "${velocity.averagePerPeriod.toStringAsFixed(2)}\n");

  // 10. Conflict risk: files touched by both sides of two divergent
  // branches, which are likely to merge-conflict.
  final branches = (await rwGit.branch(dir, extraArgs: ["-a"]))
      .getOrThrow()
      .where((b) => !b.name.contains("->"))
      .toList();
  if (branches.length >= 2) {
    final branchA = branches[0].name;
    final branchB = branches[1].name;
    final conflictRisk = await ConflictRiskHeuristic(runner)
        .findConflictRiskFiles(dir, branchA, branchB);
    print("Conflict-risk files between $branchA and $branchB: "
        "${conflictRisk.length}\n");
  } else {
    print("Skipping conflict risk demo: fewer than 2 branches available.\n");
  }

  // 11. Mega commits: unusually large commits that are hard to review.
  final megaCommits = await MegaCommitsHeuristic(runner).findMegaCommits(dir);
  print("Mega commits found: ${megaCommits.length}\n");

  // 12. Suspicious commits: messages/patterns that hint at low-quality or
  // risky changes.
  final suspiciousCommits =
      await SuspiciousCommitsHeuristic(runner).findSuspiciousCommits(dir);
  print("Suspicious commits found: ${suspiciousCommits.length}\n");

  // ---------------------------------------------------------------------
  // Security
  // ---------------------------------------------------------------------

  // 13. Compliance: unsigned, empty-message, unrecognized-author and
  // non-conventional commits.
  final compliance = await ComplianceScanner(runner).scanComplianceIssues(dir);
  print("Commits scanned for compliance: "
      "${compliance.totalCommitsScanned}");
  print("Non-conventional commits: "
      "${compliance.nonConventionalCommits.length}\n");

  // 14. Dependency manifests: declared dependencies per ecosystem, and
  // whether they are version-pinned.
  final manifests =
      await DependencyManifestParser(runner).parseDependencyManifests(dir);
  print("Dependency ecosystems found: ${manifests.ecosystems.length}");
  for (final eco in manifests.ecosystems) {
    print("  ${eco.type}: ${eco.totalDependencies} dependencies "
        "(${eco.pinnedCount} pinned, ${eco.floatingCount} floating)");
  }
  print("");

  // 15. Secrets: credentials/keys accidentally committed to history.
  final secrets = await SecretsScanner(runner).findSecrets(dir);
  print("Potential secrets found in history: ${secrets.length}\n");

  // ---------------------------------------------------------------------
  // Static analysis
  // ---------------------------------------------------------------------

  // 16. Dart AST analysis: imports, public API surface and method
  // invocations for a single Dart file. CleanArchitecture is a .NET
  // repository, so we analyze a small inline Dart snippet instead.
  const sampleDartSource = '''
import 'dart:io';

class Greeter {
  String greet(String name) => "Hello, \$name!";

  void printGreeting(String name) {
    print(greet(name));
  }
}
''';
  final astResult =
      DartAstAnalyzer().analyzeFile("greeter.dart", sampleDartSource);
  print("Imports: ${astResult.imports}");
  print("Public API signatures: ${astResult.apiSignatures}");
}

/// Creates the directory where the repository will be checked out.
/// If the directory already exists, it will delete it along with any content inside
/// and a new one will be created.
String _createCheckoutDirectory(String directoryName) {
  Directory checkoutDirectory = Directory(directoryName);
  try {
    checkoutDirectory.deleteSync(recursive: true);
  } catch (e) {
    // Handle the exception, e.g. directory doesn't exist
  }
  checkoutDirectory.createSync();

  return "${Directory.current.path}${Platform.pathSeparator}$directoryName";
}
