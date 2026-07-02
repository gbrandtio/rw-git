import '../constants.dart';
import '../core/process_runner.dart';
import '../intelligence/history/algorithms/szz_algorithm.dart';
import '../vcs/git_query.dart';
import '../vcs/rw_git_facade.dart';
import 'mcp_registry.dart';
import 'mcp_tool.dart';
import 'mcp_tool_file_offload_decorator.dart';
import 'mcp_tool_metadata_decorator.dart';

import 'tools/static_analysis/analyze_code_quality_tool.dart';
import 'tools/history/analyze_bug_hotspots_tool.dart';
import 'tools/history/find_bugs_by_developer_tool.dart';
import 'tools/system/get_rw_git_documentation_tool.dart';
import 'tools/system/read_report_slice_tool.dart';
import 'tools/core/init_repository_tool.dart';
import 'tools/core/is_git_repository_tool.dart';
import 'tools/core/clone_repository_tool.dart';
import 'tools/core/checkout_branch_tool.dart';
import 'tools/core/fetch_tags_tool.dart';
import 'tools/core/get_commits_between_tool.dart';
import 'tools/history/get_stats_tool.dart';
import 'tools/history/get_contributions_by_author_tool.dart';
import 'tools/core/clone_specific_branch_tool.dart';
import 'tools/history/analyze_release_delta_tool.dart';
import 'tools/architecture/analyze_bus_factor_tool.dart';
import 'tools/architecture/analyze_logical_coupling_tool.dart';
import 'tools/history/analyze_code_volatility_tool.dart';
import 'tools/architecture/analyze_refactoring_tool.dart';
import 'tools/static_analysis/evaluate_comments_tool.dart';
import 'tools/security/detect_secrets_tool.dart';
import 'tools/history/analyze_pr_diff_tool.dart';
import 'tools/history/predict_merge_conflicts_tool.dart';
import 'tools/history/analyze_commit_velocity_tool.dart';
import 'tools/architecture/analyze_dependency_drift_tool.dart';
import 'tools/history/generate_changelog_tool.dart';
import 'tools/security/audit_compliance_tool.dart';
import 'tools/architecture/analyze_file_ownership_tool.dart';
import 'tools/static_analysis/analyze_dart_ast_quality_tool.dart';
import 'tools/architecture/analyze_architecture_drift_tool.dart';
import 'tools/static_analysis/analyze_clean_code_tool.dart';
import 'tools/static_analysis/calculate_universal_lexical_metrics_tool.dart';
import 'tools/reports/generate_technical_report_tool.dart';
import 'tools/reports/generate_security_report_tool.dart';
import 'tools/reports/generate_pm_report_tool.dart';
import 'tools/reports/generate_code_review_report_tool.dart';
import 'tools/reports/generate_repository_audit_tool.dart';

import 'prompts/rw_git_mcp_reporting_prompt.dart';
import 'prompts/rw_git_mcp_code_review_reporting_prompt.dart';
import 'prompts/rw_git_mcp_pm_reporting_prompt.dart';
import 'prompts/rw_git_mcp_security_reporting_prompt.dart';
import 'prompts/rw_git_mcp_technical_reporting_prompt.dart';

/// server_registry.dart
///
/// Single source of truth for the set of MCP tools and prompts the rw_git
/// server exposes. Both the `rw_git_mcp` executable and the test suite build
/// the registry through [buildDefaultRegistry] so the wired-up surface can
/// never drift between production and tests.
/// Read-only analysis tools never mutate the repository and are safe to repeat,
/// so clients may auto-approve them.
const Map<String, dynamic> _readOnly = {
  'readOnlyHint': true,
  'idempotentHint': true,
};

/// Tools that change repository or working-tree state (clone, checkout, init,
/// fetch). Advertised so clients know they are not safe to auto-run.
const Map<String, dynamic> _mutating = {'readOnlyHint': false};

/// Shared, compact output shape for the one-call report meta-tools. Advertised
/// so a model knows the payload structure — pre-classified, ranked findings —
/// without reading anything first.
const Map<String, dynamic> _reportOutputSchema = {
  'type': 'object',
  'properties': {
    'report_type': {'type': 'string'},
    'summary': {'type': 'object'},
    'top_findings': {'type': 'array'},
    'compound_findings': {'type': 'array'},
  },
};

/// Shared by the mutating tools that only report whether the underlying git
/// operation succeeded.
const Map<String, dynamic> _successOutputSchema = {
  'type': 'object',
  'properties': {
    'success': {'type': 'boolean'},
  },
};

McpRegistry buildDefaultRegistry({ProcessRunner? runner, RwGit? rwGit}) {
  final processRunner = runner ?? ProcessRunner.defaultRunner();
  final git = rwGit ?? RwGit(runner: processRunner);
  final gitQuery = ReadOnlyGitQuery(processRunner);

  final registry = McpRegistry();

  // Read-only analysis tools (offloaded), with standard annotations attached
  // as the outermost wrapper so the registry can advertise them.
  void registerReadOnly(McpTool tool, {Map<String, dynamic>? outputSchema}) =>
      registry.registerTool(McpToolWithMetadata(tool,
          annotations: _readOnly, outputSchema: outputSchema));

  void offloadedRo(McpTool inner, {Map<String, dynamic>? outputSchema}) =>
      registerReadOnly(
          McpToolFileOffloadDecorator(inner,
              resources: registry.resources,
              // Per-tool size gate (ADR-0011); global default when unlisted.
              offloadThresholdBytes: perToolOffloadThresholdBytes[inner.name] ??
                  offloadSizeThresholdBytes),
          outputSchema: outputSchema);

  void mutating(McpTool tool, {Map<String, dynamic>? outputSchema}) =>
      registry.registerTool(McpToolWithMetadata(tool,
          annotations: _mutating, outputSchema: outputSchema));

  // One-call, pre-interpreted report meta-tools. Registered first so they are
  // the prominent choice for small models: a single call returns a complete,
  // band-classified, ranked report instead of forcing the model to orchestrate
  // many raw tools, read offloaded files, and apply the interpretation guide
  // itself. Registration order is a deliberate discoverability ranking
  // (ADR-0009): report tools must stay at the top of tools/list; do not
  // reorder alphabetically or append new tools blindly.
  offloadedRo(GenerateRepositoryAuditTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateTechnicalReportTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateSecurityReportTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GeneratePmReportTool(processRunner),
      outputSchema: _reportOutputSchema);
  offloadedRo(GenerateCodeReviewReportTool(processRunner),
      outputSchema: _reportOutputSchema);

  // Stable, compact shapes are advertised below via `outputSchema:` so a
  // model knows an offloaded file's structure without reading it first.
  // `get_rw_git_documentation` (returns Markdown, not JSON), `read_report_slice`
  // (three mutually-exclusive shapes depending on path/error), and
  // `analyze_dart_ast_quality` (three mutually-exclusive early-exit shapes plus
  // a dynamic per-file map) are deliberately left without one — their output
  // doesn't have a single stable shape a compact schema could usefully pin down.
  offloadedRo(AnalyzeCodeQualityTool(processRunner, gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'suspicious_commits': {'type': 'array'},
      'mega_commits': {'type': 'array'},
      'total_commits': {'type': 'integer'},
      'high_churn_files': {'type': 'array'},
      'top_churned_classes': {'type': 'array'},
      'top_churned_blocks': {'type': 'array'},
      'advanced_metrics': {'type': 'object'},
      'analysis_hints': {'type': 'array'},
      'commit_log': {'type': 'string'},
      'code_diff': {'type': 'string'},
    },
  });
  offloadedRo(AnalyzeBugHotspotsTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'total_fix_commits_analyzed': {'type': 'integer'},
      'global_average_bug_lifetime_in_days': {'type': 'number'},
      'top_bug_hotspot_files': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'file': {'type': 'string'},
            'bug_introductions': {'type': 'integer'},
            'average_bug_lifetime_in_days': {'type': 'number'},
          },
        },
      },
      'top_bug_hotspot_authors': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'author': {'type': 'string'},
            'bug_introductions': {'type': 'integer'},
            'average_bug_lifetime_in_days': {'type': 'number'},
          },
        },
      },
      'analysis_hints': {'type': 'array'},
    },
  });
  offloadedRo(FindBugsByDeveloperTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'author_analyzed': {'type': 'string'},
      'bugs_introduced_count': {'type': 'integer'},
      'bug_introductions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'file': {'type': 'string'},
            'introducing_commit': {'type': 'string'},
            'fixing_commit': {'type': 'string'},
            'bug_lifetime_in_days': {'type': 'number'},
          },
        },
      },
    },
  });
  registerReadOnly(GetRwGitDocumentationTool(registry));
  registerReadOnly(ReadReportSliceTool());
  mutating(InitRepositoryTool(git), outputSchema: _successOutputSchema);
  registerReadOnly(IsGitRepositoryTool(git, gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'isGitRepository': {'type': 'boolean'},
      'health_dashboard': {
        'type': 'object',
        'properties': {
          'current_branch': {'type': 'string'},
          'has_uncommitted_changes': {'type': 'boolean'},
          'last_commit_date': {'type': 'string'},
          'total_commits': {'type': 'integer'},
        },
      },
    },
  });
  mutating(CloneRepositoryTool(git), outputSchema: _successOutputSchema);
  mutating(CheckoutBranchTool(git), outputSchema: _successOutputSchema);
  mutating(FetchTagsTool(git), outputSchema: const {
    'type': 'object',
    'properties': {
      'tags': {'type': 'array'},
    },
  });
  offloadedRo(GetCommitsBetweenTool(git), outputSchema: const {
    'type': 'object',
    'properties': {
      'commits': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'hash': {'type': 'string'},
            'authorName': {'type': 'string'},
            'authorEmail': {'type': 'string'},
            'date': {'type': 'string'},
            'message': {'type': 'string'},
          },
        },
      },
    },
  });
  offloadedRo(GetStatsTool(git, gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'numberOfChangedFiles': {'type': 'integer'},
      'insertions': {'type': 'integer'},
      'deletions': {'type': 'integer'},
      'stats_by_extension': {'type': 'object'},
    },
  });
  offloadedRo(GetContributionsByAuthorTool(git), outputSchema: const {
    'type': 'object',
    'properties': {
      'contributions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'authorName': {'type': 'string'},
            'numberOfContributions': {'type': 'integer'},
          },
        },
      },
    },
  });
  mutating(CloneSpecificBranchTool(git), outputSchema: _successOutputSchema);
  offloadedRo(AnalyzeReleaseDeltaTool(gitQuery, processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'total_commits': {'type': 'integer'},
      'total_insertions': {'type': 'integer'},
      'total_deletions': {'type': 'integer'},
      'files_changed': {'type': 'integer'},
      'active_contributors': {'type': 'integer'},
      'top_modified_files': {'type': 'array'},
      'authors_breakdown': {'type': 'object'},
      'commits': {'type': 'array'},
    },
  });
  offloadedRo(AnalyzeBusFactorTool(processRunner, git), outputSchema: const {
    'type': 'object',
    'properties': {
      'bus_factor': {'type': 'integer'},
      'total_developers_analyzed': {'type': 'integer'},
      'top_contributors': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'author': {'type': 'string'},
            'contributions': {'type': 'integer'},
            'percentage': {'type': 'string'},
          },
        },
      },
    },
  });
  offloadedRo(AnalyzeLogicalCouplingTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'commits_analyzed': {'type': 'string'},
      'coupled_pairs_found': {'type': 'integer'},
      'logical_coupling': {'type': 'array'},
    },
  });
  offloadedRo(AnalyzeCodeVolatilityTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'commits_analyzed': {'type': 'string'},
      'highly_volatile_files_found': {'type': 'integer'},
      'top_volatile_files': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'file_path': {'type': 'string'},
            'total_changes': {'type': 'integer'},
            'unique_authors': {'type': 'integer'},
            'volatility_score': {'type': 'string'},
          },
        },
      },
    },
  });
  offloadedRo(AnalyzeRefactoringTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'commits_analyzed': {'type': 'string'},
      'refactorings_detected': {'type': 'integer'},
      'refactoring_commits': {'type': 'array'},
    },
  });
  offloadedRo(EvaluateCommentsTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'status': {'type': 'string'},
      'message': {'type': 'string'},
      'aspects': {'type': 'array'},
      'evaluation_criteria': {'type': 'object'},
      'changed_comments': {'type': 'array'},
    },
  });
  offloadedRo(DetectSecretsTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'secrets_found': {'type': 'integer'},
      'message': {'type': 'string'},
      'findings': {'type': 'array'},
    },
  });
  offloadedRo(AnalyzePrDiffTool(processRunner, gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'total_files_changed': {'type': 'integer'},
      'overall_risk_level': {'type': 'string'},
      'changed_files': {'type': 'array'},
    },
  });
  offloadedRo(PredictMergeConflictsTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'merge_base': {'type': 'string'},
      'risk_level': {'type': 'string'},
      'logical_conflicting_files_count': {'type': 'integer'},
      'logical_conflicting_files': {'type': 'array'},
      'textual_conflicting_files_count': {'type': 'integer'},
      'textual_conflicting_files': {'type': 'array'},
      'files_only_on_a': {'type': 'array'},
      'files_only_on_b': {'type': 'array'},
    },
  });
  offloadedRo(AnalyzeCommitVelocityTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'total_commits': {'type': 'integer'},
      'average_per_period': {'type': 'number'},
      'trend': {'type': 'string'},
      'velocity_slope': {'type': 'number'},
      'gini_coefficient': {'type': 'number'},
      'total_burnout_commits': {'type': 'integer'},
      'granularity': {'type': 'string'},
      'time_series': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'period': {'type': 'string'},
            'total_commits': {'type': 'integer'},
            'burnout_commits': {'type': 'integer'},
            'authors': {'type': 'object'},
          },
        },
      },
      'anomalies': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'period': {'type': 'string'},
            'total_commits': {'type': 'integer'},
          },
        },
      },
    },
  });
  offloadedRo(AnalyzeDependencyDriftTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'ecosystems': {'type': 'array'},
      'total_dependencies': {'type': 'integer'},
      'total_floating': {'type': 'integer'},
      'missing_lock_files': {'type': 'integer'},
      'overall_risk': {'type': 'string'},
      'freshness_summary': {'type': 'object'},
    },
  });
  // Shares the single RA-SZZ core with the other SZZ-backed tools so
  // changelog bug linkage cannot drift from hotspot/developer attribution.
  offloadedRo(GenerateChangelogTool(gitQuery, SzzAlgorithm(processRunner)),
      outputSchema: const {
        'type': 'object',
        'properties': {
          'total_commits': {'type': 'integer'},
          'contributors': {'type': 'array'},
          'features': {'type': 'array'},
          'fixes': {'type': 'array'},
          'breaking_changes': {'type': 'array'},
          'other': {'type': 'array'},
          'raw_log': {'type': 'string'},
        },
      });
  offloadedRo(AuditComplianceTool(processRunner), outputSchema: const {
    'type': 'object',
    'properties': {
      'total_commits_scanned': {'type': 'integer'},
      'total_violations': {'type': 'integer'},
      'unsigned_commits': {'type': 'array'},
      'empty_message_commits': {'type': 'array'},
      'unrecognized_author_commits': {'type': 'array'},
      'non_conventional_commits': {'type': 'array'},
    },
  });
  offloadedRo(AnalyzeFileOwnershipTool(processRunner, gitQuery),
      outputSchema: const {
        'type': 'object',
        'properties': {
          'codeowners_found': {'type': 'boolean'},
          'total_files_analyzed': {'type': 'integer'},
          'drift_count': {'type': 'integer'},
          'unowned_files': {'type': 'array'},
          'files': {'type': 'array'},
        },
      });
  offloadedRo(AnalyzeDartAstQualityTool(gitQuery));
  offloadedRo(AnalyzeArchitectureDriftTool(gitQuery), outputSchema: const {
    'type': 'object',
    'properties': {
      'total_commits_analyzed': {'type': 'integer'},
      'commits_with_drift': {'type': 'integer'},
      'coupling_ratio': {'type': 'number'},
      'coupling_density': {'type': 'number'},
      'coupling_matrix': {'type': 'object'},
      'architectural_smells': {'type': 'array'},
      'drift_commits': {'type': 'array'},
    },
  });
  offloadedRo(AnalyzeCleanCodeTool(), outputSchema: const {
    'type': 'object',
    'properties': {
      'file': {'type': 'string'},
      'total_lines': {'type': 'integer'},
      'max_indentation_level': {'type': 'integer'},
      'long_lines': {'type': 'integer'},
      'magic_numbers': {'type': 'integer'},
      'duplicate_lines': {'type': 'integer'},
      'clean_code_issues': {'type': 'array'},
      'risk_level': {'type': 'string'},
    },
  });
  offloadedRo(CalculateUniversalLexicalMetricsTool(), outputSchema: const {
    'type': 'object',
    'properties': {
      'language_profile': {'type': 'string'},
      'cyclomatic_complexity': {'type': 'integer'},
      'npath_complexity': {'type': 'integer'},
      'abc_score': {'type': 'object'},
      'cognitive_complexity': {'type': 'integer'},
      'indentation_complexity': {'type': 'object'},
      'halstead_metrics': {'type': 'object'},
      'maintainability_index': {'type': 'object'},
    },
  });

  registry.registerPrompt(RwGitMcpReportingPrompt());
  registry.registerPrompt(RwGitMcpCodeReviewReportingPrompt());
  registry.registerPrompt(RwGitMcpPmReportingPrompt());
  registry.registerPrompt(RwGitMcpSecurityReportingPrompt());
  registry.registerPrompt(RwGitMcpTechnicalReportingPrompt());

  return registry;
}
