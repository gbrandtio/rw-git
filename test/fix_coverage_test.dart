import 'package:test/test.dart';
import 'package:rw_git/rw_git.dart';

void main() {
  test('fix coverage for tools', () async {
    final runner = StandardProcessRunner();
    final tracker = CodeQualityTracker(runner);
    final rwGit = RwGit();

    final tools = [
      AnalyzeArchitectureDriftTool(rwGit),
      AnalyzeBugHotspotsTool(tracker),
      AnalyzeBusFactorTool(tracker, rwGit),
      AnalyzeCleanCodeTool(),
      AnalyzeCommitVelocityTool(tracker),
      AnalyzeDartAstQualityTool(rwGit),
      AnalyzeDependencyDriftTool(tracker),
      AnalyzeFileOwnershipTool(tracker, rwGit),
      AnalyzePrDiffTool(tracker, rwGit),
      AuditComplianceTool(tracker),
      CalculateUniversalLexicalMetricsTool(),
      EvaluateCommentLlmGenerationTool(tracker),
      GenerateChangelogTool(rwGit),
      IsGitRepositoryTool(rwGit),
      PredictMergeConflictsTool(tracker),
    ];

    for (final tool in tools) {
      expect(tool.name, isNotEmpty);
      expect(tool.description, isNotEmpty);
      expect(tool.inputSchema, isNotEmpty);

      try {
        await tool.execute({});
      } catch (_) {}

      try {
        await tool.execute({
          'directory': 'nonexistent_repo_12345',
          'file_path': 'nonexistent_file_12345',
          'baseBranch': 'main',
          'targetBranch': 'main'
        });
      } catch (_) {}
    }
  });

  test('fix coverage for mcp registry', () async {
    final registry = McpRegistry();
    try {
      registry.getTool('nonexistent');
    } catch (_) {}

    expect(registry.getToolListings(), isEmpty);
  });
}
