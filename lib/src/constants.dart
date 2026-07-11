/// Standard constants used throughout the rw_git library and MCP tools.
const String defaultCommitLimit = '500';
const int defaultTopN = 5;

/// MCP protocol revision implemented by the server. Bump when the wire
/// behaviour is updated to a newer specification.
const String mcpProtocolVersion = '2025-06-18';

/// Older protocol revisions the server still accepts during negotiation, so
/// clients pinned to them continue to work.
const List<String> supportedMcpProtocolVersions = [
  '2025-06-18',
  '2025-03-26',
  '2024-11-05',
];

/// Server version advertised in the MCP `initialize` handshake. Keep in sync
/// with the `version` field in `pubspec.yaml`.
const String rwGitMcpVersion = '3.3.0';

/// JSON-RPC 2.0 error codes used by the MCP server. Per the JSON-RPC
/// specification these are all negative; MCP-specific server errors live in
/// the -32000..-32099 range reserved for implementation-defined errors.
const int jsonRpcMethodNotFound = -32601;
const int jsonRpcInvalidParams = -32602;
const int jsonRpcServerError = -32000;
const int mcpResourceNotFound = -32002;

/// Minutes in a day, used to convert commit-timestamp differences into
/// fractional days for the SZZ bug-lifetime metrics.
const int minutesPerDay = 24 * 60;

/// RA-SZZ moved-line detection: a deleted line is only treated as "moved by a
/// refactoring" (and excluded from blame) when its whitespace-normalized
/// content is at least this long. Shorter lines (`}`, `return;`, `else {`)
/// are language boilerplate that recurs naturally, so a match on them says
/// nothing about code movement.
const int raSzzMovedLineMinimumLength = 8;

/// Below this size (bytes), a wrapped MCP tool's full JSON output is
/// returned inline instead of offloaded to disk, avoiding a wasted
/// file-read round trip for small payloads (~2-3K tokens worst case at 8KB).
/// This is the default; individual tools can override it via
/// [perToolOffloadThresholdBytes] (ADR-0011).
const int offloadSizeThresholdBytes = 8192;

/// Offload threshold for the one-call report meta-tools. Their offload
/// summary already carries the classified findings inline (ADR-0005), so an
/// inline full report duplicates that content without adding signal; a lower
/// threshold keeps even mid-sized reports out of the context window.
const int reportToolOffloadThresholdBytes = 4096;

/// Offload threshold for compact history tools whose output (commit lists,
/// aggregate stats) is typically consumed whole by the model; a higher
/// threshold avoids a pointless write-then-read round trip for payloads the
/// model would immediately fetch in full anyway.
const int compactHistoryToolOffloadThresholdBytes = 16384;

/// Report-grade lexical metrics bounding (ADR-0014): the report meta-tools
/// compute genuine McCabe cyclomatic complexity and the maintainability
/// index only for the highest-churn files — the files where complexity
/// matters most (Nagappan & Ball, ICSE 2005) — so report runtime stays
/// bounded regardless of repository size.
const int maxLexicalMetricsFilesPerReport = 10;

/// Files larger than this are skipped by the report-grade lexical sampler;
/// they are almost always generated or vendored code whose complexity is
/// not actionable, and lexing them would dominate report latency.
const int maxLexicalMetricsFileSizeBytes = 262144;

/// McCabe cyclomatic complexity bands (McCabe, IEEE TSE 1976): 1-10 simple,
/// 11-20 moderate, 21-50 complex/high-risk, 51+ effectively untestable.
const int mccabeElevatedCyclomaticComplexityThreshold = 10;
const int mccabeHighRiskCyclomaticComplexityThreshold = 20;
const int mccabeCriticalCyclomaticComplexityThreshold = 50;

/// Maintainability-index bands (Coleman et al., ICSM 1994; Visual Studio
/// recalibration): >= 85 highly maintainable, 65-85 moderate, < 65 low.
const double maintainabilityIndexModerateBandThreshold = 85;
const double maintainabilityIndexLowBandThreshold = 65;

/// ABC score bands (Fitzpatrick, 1997): the vector magnitude of
/// assignments, branches, and conditions. Above 15 a unit warrants review;
/// above 30 it needs refactoring.
const double abcScoreElevatedThreshold = 15;
const double abcScoreHighThreshold = 30;

/// NPath acyclic-path bands (Nejmeh, CACM 1988): above 200 paths a unit is
/// effectively untestable by path coverage; above 1000 the combinatorial
/// explosion makes reasoning about all behaviours impractical.
const int npathElevatedThreshold = 200;
const int npathHighThreshold = 1000;

/// Cognitive complexity bands (Campbell, SonarSource 2018): unlike McCabe,
/// weights nesting — above 15 a unit is hard to understand, above 25 it
/// actively resists comprehension.
const int cognitiveComplexityElevatedThreshold = 15;
const int cognitiveComplexityHighThreshold = 25;

/// Halstead delivered-bugs estimate (Halstead, 1977: volume / 3000) above
/// which a file's latent-defect estimate is flagged.
const double halsteadDeliveredBugsElevatedThreshold = 2.0;

/// Bird et al. (FSE 2011) minor-contributor rule: an author holding less
/// than this share of a file's changes is a minor contributor, and files
/// touched by many of them are measurably more defect-prone.
const double birdMinorContributorShareThreshold = 0.05;

/// Minimum count of minor contributors on one file before the Bird
/// minor-contributor finding fires.
const int birdMinorContributorMinimumCount = 3;

/// Minimum number of single-owner bug-hotspot files attributed to one
/// author before the author-level knowledge-loss compound fires (Avelino
/// et al. 2016; Fritz et al. 2010).
const int knowledgeLossMinimumFiles = 2;

/// Upper bound on the ranked `refactoring_targets` list in report payloads
/// (Tornhill 2015 hotspot prioritization): churn-percentile x
/// complexity-percentile, most valuable refactoring candidates first.
const int maxRefactoringTargets = 5;

/// Minimum churn-percentile x complexity-percentile product for a file to
/// qualify as a refactoring target; below this the file is either rarely
/// changed or simple enough that refactoring it buys little.
const double refactoringTargetMinimumRiskScore = 0.25;

/// Clean-code heuristics (Martin 2008; Fowler 1999). A file longer than
/// this indicates a probable Single Responsibility violation.
const int cleanCodeFileLengthThreshold = 300;

/// Indentation levels at or above this depth are "arrow code" that resists
/// comprehension and testing (Martin 2008).
const int cleanCodeNestingDepthThreshold = 5;

/// Line length above which readability degrades.
const int cleanCodeLongLineLength = 120;

/// Share of long lines in a file above which readability is flagged.
const double cleanCodeLongLineShareThreshold = 0.1;

/// Magic-number literal count above which a file is flagged (Fowler 1999).
const int cleanCodeMagicNumberThreshold = 10;

/// Duplicate non-blank lines are only counted when longer than this, so
/// recurring language boilerplate (`}`, `return;`) is not read as cloning.
const int cleanCodeDuplicateLineMinimumLength = 5;

/// Share of a file's lines that are duplicates above which Type-1 cloning
/// is flagged (Koschke 2007).
const double cleanCodeDuplicateLineShareThreshold = 0.1;

/// Number of spaces one indentation level represents when measuring
/// nesting depth (tabs count as one level).
const int cleanCodeIndentationUnitSpaces = 4;

/// Clean-code issue count at or above which a file's finding escalates
/// from Elevated to High: multiple independent heuristics agreeing is a
/// stronger maintainability signal than any single one.
const int cleanCodeHighSeverityIssueCount = 3;

/// Architectural smell thresholds (Garcia, Oliveira & Murta 2009). A layer
/// appearing in more than this share of drift commits is a God Component.
const double godComponentDriftShareThreshold = 0.5;

/// Hub-Like Dependency detection is only meaningful with at least this many
/// declared layers; below it every layer trivially couples with "half" the
/// others.
const int hubLikeDependencyMinimumLayers = 4;

/// A drift commit touching at least this many layers at once contributes to
/// the Scattered Functionality smell.
const int scatteredFunctionalityLayerCount = 3;

/// Share of analyzed commits violating layer boundaries above which the
/// repository's architecture is drifting (aligned with the ~15% drift
/// signal in the interpretation guide; Perry & Wolf 1992).
const double couplingRatioElevatedThreshold = 0.15;

/// Fraction of possible layer pairs coupled at least once above which the
/// architecture is entangled rather than layered (Garcia et al. 2009).
const double couplingDensityElevatedThreshold = 0.5;

/// Upper bound on layers inferred from repository structure for the
/// report-grade architecture-drift analysis, keeping the coupling matrix
/// and its findings bounded on monorepos with many top-level directories.
const int maxInferredArchitectureLayers = 8;

/// Minimum distinct inferred layers required to run report-grade
/// architecture-drift analysis; a single-layer repository has no boundaries
/// to violate.
const int minInferredArchitectureLayers = 2;

/// Author-concentration Gini coefficient above which delivery depends on
/// too few people (Gini 1912 applied to commit inequality).
const double giniAuthorConcentrationHighThreshold = 0.6;

/// Share of commits landing in the burnout window (nights/weekends, Claes
/// et al., ICSE 2018) above which sustained off-hours work is flagged.
const double burnoutCommitShareHighThreshold = 0.15;

/// Detected refactoring commits at or above this count are surfaced as a
/// notable tech-debt-paydown signal in the technical report.
const int refactoringActivityNotableThreshold = 5;

/// Sample size for evidence lists on aggregate findings (e.g. mega-commit
/// hashes), mirroring the compliance classifier's sample bound.
const int aggregateFindingEvidenceSampleSize = 5;

/// Inline hint attached to every offload summary. Kept deliberately short:
/// it is re-sent on every offloaded call, so each character is a recurring
/// token cost. The full offload contract lives once in
/// `get_rw_git_documentation` instead of being repeated here.
const String offloadedReportHint =
    'Read targeted slices with read_report_slice (path/offset/limit) using '
    'the preview below; full offload contract: get_rw_git_documentation.';

/// Per-tool overrides for [offloadSizeThresholdBytes], keyed by MCP tool
/// name (ADR-0011). Tools absent from this map use the global default.
const Map<String, int> perToolOffloadThresholdBytes = {
  'generate_repository_audit': reportToolOffloadThresholdBytes,
  'generate_technical_report': reportToolOffloadThresholdBytes,
  'generate_security_report': reportToolOffloadThresholdBytes,
  'generate_pm_report': reportToolOffloadThresholdBytes,
  'generate_code_review_report': reportToolOffloadThresholdBytes,
  'get_commits_between': compactHistoryToolOffloadThresholdBytes,
  'get_stats': compactHistoryToolOffloadThresholdBytes,
};

/// Documentation template for the get_rw_git_documentation MCP tool.
/// The {{toolsMarkdown}} placeholder is replaced at runtime with the list
/// of available tools.
const String rwGitDocumentationTemplate = '''
# RwGit Agent Guide & Documentation

⚠️ **IMPORTANT INSTRUCTIONS FOR AI AGENTS**
You are interacting with the RwGit repository via the MCP tools provided in your environment.
- **Do NOT** attempt to run `rw_git` as a CLI command (e.g., `rw_git --help`). It is not an executable in your shell.
- **Do NOT** write scripts (e.g., Python) to manually send JSON-RPC requests to the server process.
- **Do NOT** perform any custom git commands for the analysis. You MUST use only the tools offered by rw-git.
- **Do** invoke the provided MCP tools directly using your environment's native tool execution capabilities.

## 1. Recommended: one-call report tools
For most reporting tasks, call ONE of these meta-tools instead of orchestrating many raw tools. Each runs the relevant analyses, applies every severity band and cross-tool compound-risk rule in Dart, and returns a small, ranked, already-classified payload (`summary`, `top_findings`, `compound_findings`) you can narrate directly — no thresholds to apply and, for typical repositories, no offloaded files to read:
- **generate_repository_audit** — high-level deep audit (technical + security)
- **generate_technical_report** — code quality, technical debt, architecture
- **generate_security_report** — secrets, compliance, dependency freshness
- **generate_pm_report** — knowledge concentration & delivery bottlenecks
- **generate_code_review_report** — risk signals for code under review

Every finding already carries `severity`, `subject`, `band`, and `message`. Narrate them; do not recompute metrics or thresholds. Reach for the raw tools below only for targeted deep-dives.

## 2. Raw tool notes
⚠️ **Commit Limit (`limit`)**: the default is 500 commits — override it for a broader or tighter window.

⚠️ **Context Offloading**: verbose raw tools offload large JSON to `.rw_git/reports/...` and return a lightweight summary plus a `preview`. To use their content, read the offloaded file — prefer the `read_report_slice` tool (pass the file path, optionally a dot-separated `path` plus `offset`/`limit`); the `preview` lists what is available to slice. Responses under 8KB return inline automatically; pass `return_full_json: true` to force inline, or `output_file` to choose the path.

## 3. Interpreting raw metrics
The report tools in section 1 apply all severity bands automatically. If you call the raw tools directly, classify their numbers using the bands and the four cross-tool compound-risk rules in **doc/INTERPRETATION_GUIDE.md** (bus factor, bug hotspots, complexity vs repo median, logical coupling, architecture drift, dependency freshness, compliance). Never report a raw metric without stating its severity band.

Many payloads also carry a `hints` object (`interpretation`, `caveats`, `pair_with`): research-grounded thresholds, known limitations, and complementary-tool suggestions for that analysis as a whole. Use them instead of inventing thresholds and surface relevant caveats rather than presenting a result as more certain than it is.

## 4. Available Tools

{{toolsMarkdown}}

## 5. Documentation
- **get_rw_git_documentation**: Returns this guide.
''';
