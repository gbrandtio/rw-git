# 3.0.10
- **FEAT (Intelligence):** Upgraded the SZZ implementation from MA-SZZ to
  **RA-SZZ** (Refactoring-Aware SZZ — Neto et al., SANER 2018), removing the
  future-work note in `doc/tools/history/find_bugs_by_developer.md`. Two new
  refactoring guards: deleted lines whose content re-appears among the fix
  commit's added lines are treated as moved code and excluded from blame
  (lines under 8 normalized characters are exempt — boilerplate recurs
  naturally, threshold in `raSzzMovedLineMinimumLength`); and attributions
  whose introducing commit subject matches refactoring keywords are
  discarded (subjects fetched once per commit and cached; unresolvable
  subjects fail open). Both are lexical, language-agnostic stand-ins for
  RefDiff's AST-based operation detection — the same trade-off as
  `analyze_refactoring`. Affects `analyze_bug_hotspots` and
  `find_bugs_by_developer`; blame now targets only surviving deleted lines
  (grouped into contiguous ranges) instead of whole pre-image hunk spans.
- **REFACTOR/FEAT (MCP):** `generate_changelog` now delegates its fix
  enrichment to the shared `SzzAlgorithm` core instead of an inline mini-SZZ
  that lacked the MA-SZZ flags and all RA-SZZ guards. `SzzAlgorithm` gained a
  public per-commit entry point (`traceFixCommit`) so tools that select fix
  commits themselves reuse the exact same pipeline; the class doc now states
  it is the package's single SZZ implementation. **BREAKING (output):** each
  `bug_introducing_commits` entry is now an object with `introducing_commit`
  (full 40-char hash), `introduced_date`, and `days_bug_lived` — the
  temporal-context contract `doc/tools/history/generate_changelog.md` always
  documented — instead of a bare abbreviated-hash string.
- **CHORE (Models):** Removed the dead `BugIntroductionDto`
  (`lib/src/models/bug_introduction_dto.dart`) — unexported, untested, and
  unused since the SZZ pipeline moved to `SzzMatch`; it still carried the
  misleading `timeTakenToFixInHours` name.
- **BREAKING (Intelligence/MCP):** Renamed the SZZ "time to fix" metrics to
  **bug lifetime**, reported in **days**. The metric measures the span from
  the bug-introducing commit to the bug-fixing commit (Kim & Whitehead,
  *How long did it take to fix bugs?*, MSR 2006 — median lifetimes of
  100–200 days are normal), not the effort spent fixing — labelling it
  "time to fix" in hours made every report read as thousands of hours of
  fix effort. `BugHotspotDto` fields and JSON keys are now
  `*_average_bug_lifetime_in_days`; `find_bugs_by_developer` returns
  `bug_lifetime_in_days` (fractional days) instead of `time_to_fix_in_hours`;
  the `BugHotspotClassifier` metric/evidence keys and
  `doc/INTERPRETATION_GUIDE.md` follow (ADR-0010 process). The severity bands
  are unchanged — they are relative (1–2x / >2x the repository's own
  average), so the unit change alters no classification.
- **FEAT (MCP):** Per-tool offload thresholds (ADR-0011), resolving the
  single-global-threshold trade-off recorded in ADR-0001.
  `McpToolFileOffloadDecorator` takes an `offloadThresholdBytes` override,
  wired from the `perToolOffloadThresholdBytes` map in
  `lib/src/constants.dart`: report meta-tools offload above 4 KiB (their
  offload summary already carries the findings inline), `get_stats` and
  `get_commits_between` stay inline up to 16 KiB (their output is consumed
  whole), everything else keeps the 8 KiB default. The advertised
  `(>NKB offloaded to disk.)` note now reflects each tool's actual gate.
- **FEAT (MCP):** Structured logging with host-controlled verbosity
  (ADR-0012). Library logging now flows through the `RwGitLogger` facade
  (still mirrored to `dart:developer`); the server advertises the `logging`
  capability, handles `logging/setLevel` (invalid levels rejected as
  JSON-RPC invalid params), and forwards events as `notifications/message`
  filtered by the host-selected minimum level (default: `warning`).
  `GitCommand` start/finish events are `debug`, failures are `error`.
- **DOCS (Process):** `AGENTS.md` Rule 13 forbids future-work statements
  ("will be implemented in the future", "planned", "TODO") in documents;
  deferred capabilities must be raised with the user and either implemented
  or recorded as an explicit decision.

# 3.0.9
- **DOCS (Tools):** Brought `doc/tools/` back in sync with the registered tool surface: merged the three stale comment-tool documents into `doc/tools/static_analysis/evaluate_comments.md`, folded `analyze_code_quality_with_authors.md` into `analyze_code_quality.md` (the `includeAuthors: true` section), added the five missing report meta-tool documents under `doc/tools/reports/`, and added `doc/tools/system/read_report_slice.md`. `README.md` now lists the report meta-tools, the merged `evaluate_comments` tool, and `read_report_slice`.
- **TEST (Docs sync):** Added `test/mcp/tools_docs_sync_test.dart`, asserting bidirectionally that every tool registered in `server_registry.dart` has a matching `doc/tools/**/<name>.md` and vice versa; `AGENTS.md` now codifies the matching Tool Documentation Sync rule and restates the coverage requirement in terms of the `coverage.yml` CI gate.
- **DOCS (ADRs):** Added ADR-0009 (tool-registry ordering is a deliberate small-LLM discoverability ranking — report tools first) and ADR-0010 (interpretation thresholds: classifier code is the single source of truth; `INTERPRETATION_GUIDE.md` must be updated with a stated justification in the same commit).
- **DOCS (Citations):** Consolidated the master academic reference list into `doc/tools/REFERENCES.md` as the single canonical citation index; `TOOLS_ACADEMIC_FOUNDATIONS.md` §7 now points there.
- **CHORE (Skills/Prompts):** Each reporting skill now carries a `<contract>` section pinning the ADR-0001/ADR-0005 payload contract (`summary`/`top_findings`/`compound_findings`, offload `preview`) with a drift fallback; the installation skill references `defaultCommitLimit` in `lib/src/constants.dart` instead of hard-coding the 500-commit default. Prompts regenerated via `tool/sync_prompts.dart`.
- **FIX (Quality):** Added `example/README.md` in order to be able to render multiple examples (core git commands usage, intelligence commands usage) in pub.dev.
- **FEAT (MCP, small-model efficiency):** Added five one-call **report meta-tools** — `generate_repository_audit`, `generate_technical_report`, `generate_security_report`, `generate_pm_report`, `generate_code_review_report`. Each runs the relevant analyses, then applies every severity band and cross-tool compound-risk rule **in Dart**, and returns a small, ranked, already-classified payload (`summary`, `top_findings`, `compound_findings`). This moves interpretation, correlation, and ranking out of the LLM: a small/local model produces a full report from a single call instead of orchestrating ~10 raw tools, reading offloaded files, and applying a 900-word interpretation guide itself. Measured on this repo: a technical report drops from ~9 hops / ~318K worst-case read-tokens to **1 hop / ~1.9K tokens, inline-complete**.
- **FEAT (Intelligence):** New deterministic interpretation layer under `lib/src/intelligence/interpretation/` — a `Severity`/`Finding` model, per-metric classifiers (bus factor, ownership, bug hotspots, complexity, churn, logical coupling, volatility, dependency freshness, compliance, secrets), a `CompoundFindingCorrelator` encoding the four cross-tool AND-rules, and a `ReportOrchestrator`/`ReportPayload`. All reuse the existing analysis algorithms (library-first) and are exported from `package:rw_git/rw_git.dart`.
- **FEAT (MCP):** The offload decorator now surfaces `top_findings`/`compound_findings`/`summary` into the offload `preview`, so an offloaded report stays **actionable inline** — a small model narrates it without a second file read.
- **BREAKING (MCP):** Merged the three comment tools (`evaluate_comment_quality`, `evaluate_comment_necessity`, `evaluate_comment_llm_generation`) into a single **`evaluate_comments`** tool with an `aspects` parameter (defaults to all). Merged `analyze_code_quality_with_authors` into **`analyze_code_quality`** via an `includeAuthors` flag. Net tool-selection surface: −3 near-duplicates, +5 report tools, and `tools/list` is now ~34.6KB (~8.7k tokens) — smaller than the previous ~9k despite the new capability.
- **CHORE (MCP):** Extracted the ~900-word interpretation guide out of the `get_rw_git_documentation` runtime output into `doc/INTERPRETATION_GUIDE.md`; the tool now leads with the report meta-tools and points raw-tool users at the reference. Trimmed the repeated offload boilerplate on every wrapped tool's description.
- **CHORE (Skills/Prompts):** Rewrote all five reporting skills (and their generated prompts) to call the matching report meta-tool and narrate its findings, dropping the "read offloaded files iteratively" and "apply the interpretation bands" instructions that small models could not reliably follow.
- **FEAT (Tooling):** Added `tool/measure_report_quality.dart` (+ `tool/harness/`), a deterministic in-process harness that measures hops-to-report, inline-completeness, and worst-case read-tokens for the raw-tool vs meta-tool flows — the before/after proof and a CI-friendly regression gate.

# 3.0.8
- **FEAT (Library):** Exposed the intelligence/analysis algorithms (bus factor, bug hotspots, logical coupling, code volatility, etc.) directly from `package:rw_git/rw_git.dart`, so consumers can use the same analyses the MCP tools rely on without running the MCP server.
- **FEAT (Intelligence):** Added package freshness check for `analyze_dependency_drift` tool.
- **FEAT (MCP):** `McpToolFileOffloadDecorator` now returns small responses (under 8KB, `offloadSizeThresholdBytes`) inline instead of unconditionally offloading them to disk, eliminating a wasted file-write/file-read round trip for low-volume tools like `get_stats` and `get_contributions_by_author`.
- **FIX (MCP):** Implemented the `return_full_json` opt-out argument on `McpToolFileOffloadDecorator`. It was documented (and referenced in earlier CHANGELOG entries) but never actually wired into the decorator's `execute()` or `inputSchema` — passing it had no effect. It now correctly skips file offloading and returns the full JSON inline.
- **FEAT (MCP):** Offload summaries now include a `preview` field (top-level keys, value types, array lengths) so LLMs can target reads without guessing the offloaded file's shape.
- **FEAT (MCP):** Added `read_report_slice` tool to fetch a targeted key-path/array-slice from a previously offloaded report file, instead of reading the entire file into context.
- **CHORE (MCP):** Shrunk the offload boilerplate appended to all 27 wrapped tools' descriptions from a ~70-word paragraph to one sentence pointing at `get_rw_git_documentation`, reducing the fixed token cost of every `tools/list` call.
- **DOCS:** Updated `get_rw_git_documentation` with the new size threshold, `return_full_json`, `read_report_slice`, and an advisory `format: summary|full` parameter-naming convention for future tools.
- **PERF (MCP):** Cut the fixed `tools/list` cost from ~43KB (~12k tokens) to ~30KB (~8.4k tokens) by deferring the offload contract to `get_rw_git_documentation` instead of stamping a verbose paragraph plus two long property descriptions onto all 35 tool schemas. A regression test (`tools_list_size_test.dart`) now guards the budget. This lowers the floor enough for 8–16K-context local models to hold the full tool surface.
- **FEAT (MCP):** `tools/list` now advertises standard tool **annotations** (`readOnlyHint`/`idempotentHint`) — 30 read-only analysis tools are marked auto-approvable and 5 repository-mutating tools (clone/checkout/init/fetch) are flagged — plus an `outputSchema` on `analyze_bus_factor`. Metadata is attached centrally via `McpToolWithMetadata` without touching individual tools.
- **FEAT (MCP):** Bumped the implemented protocol revision to **2025-06-18** with version negotiation (older revisions still accepted), accurate capability advertisement, and `serverInfo.version` sourced from a single constant.
- **FEAT (MCP):** Offloaded reports are now exposed as MCP **Resources** (`resources/list` / `resources/read`); offload summaries include a `resource_uri`. Only files produced this session are readable. The existing `read_report_slice` path is unchanged for small/local models.
- **FEAT (MCP):** Optional `tools/list` **pagination** (opaque cursor) via the `RW_GIT_TOOLS_PAGE_SIZE` env var, for clients with very small context windows. Off by default (full list returned).
- **REFACTOR (MCP):** Extracted tool/prompt registration into a single `buildDefaultRegistry()` shared by the `rw_git_mcp` executable and the test suite, removing duplication between production and tests.
- **CHORE (Build):** Agent workflows now have a single source of truth — MCP prompt Dart sources are generated from the canonical `.agents/skills/<name>/SKILL.md` via `tool/sync_prompts.dart`, with a drift-guard test (`prompts_sync_test.dart`).
- **DOCS:** Documented all five reporting prompts and the six bundled skills in `README.md`; added a "Adding or modifying prompts and skills" section to `CONTRIBUTING.md`; added `doc/SMALL_LLM_EFFICIENCY_EVALUATION.md` (token-cost model and local/frontier model suitability matrix).

# 3.0.7
- **REFACTOR:** Refactored the MCP tools implementation, adhering to SRP principles and making the repository future-proof and easily extendable.
- **FEAT (Quality):** Based on academic papers, enhanced the MCP tools underlying technical foundations and documented under `doc/tools`.

# 3.0.6
- **TEST (Quality):** Added `documentation_formatting_test.dart` to enforce 80 column wrapping for the README file.
- **DOCS:** Formatted `README.md` and `.agents/skills/**/SKILL.md` to adhere strictly to the 80 column wrap limit.
- **FEAT (MCP):** Added `find_bugs_by_developer` tool to track bugs introduced by specific developers using a sophisticated SZZ algorithm. Extracted SZZ logic into a reusable `SzzAlgorithm` core class.
- **FEAT (MCP):** Added average time to fix a bug / time taken to fix a bug for both bug-hotspots and bugs-per-developer tools.
- **FEAT (SKILL):** Added specialized skills for different aspects of reporting to cover a variety of stakeholders needs.
- **FEAT (Quality):** Removed duplicate SKILL and README files from root repo and distribution/npm. These are now packaged for npm with a pre-package step.
- **REFACTOR (MCP):** Updated the `get_rw_git_documentation` tool to dynamically generate its markdown list of available tools from the `McpRegistry`, eliminating duplicate documentation across the codebase.
- **FIX (MCP):** Implemented safe argument extraction (`getStringArgument`, `getOptionalStringArgument`) for all MCP tools to provide clear, actionable error messages to LLMs when required arguments are missing or malformed, instead of crashing with a cryptic Dart type cast error (`type 'Null' is not a subtype of type 'String' in type cast`).
- **FEAT (MCP):** Implemented `McpToolFileOffloadDecorator` to automatically offload heavy analytical tool JSON responses to the local filesystem by default, preventing LLM context window overflow.
- **FEAT (MCP):** Added `output_file` and `return_full_json` arguments to all verbose analysis tools to allow LLMs to control context ingestion and orchestration paths.
- **FEAT (MCP):**: Implemented 4 new Mining Software Repositories (MSR) algorithms with corresponding MCP tools:
    - **Analyze Logical Coupling**: Detects files that frequently change together to identify architectural decay.
    - **Analyze Bus Factor**: Calculates the project's Truck Factor to highlight knowledge concentration risks.
    - **Analyze Code Volatility**: Predicts defect-prone files based on historical code churn and author count.
    - **Analyze Refactoring**: Detects structural refactorings and code simplifications approximating AST differencing.

# 3.0.5
- **FIX (Quality):** Fixed an issue where the secret scanner (`detect_secrets_in_commits`) produced false positives for integrity hashes in lockfiles (like `package-lock.json`), generic placeholder variables in test files, and CI workflow variables. The scanner now uses improved context-aware risk scoring to exclude lockfiles, broadens test exclusions, and filters out common placeholder patterns.
- **FIX (SKILL):** Overhauled the reporting SKILL to guide LLMs efficiently, especially small/less capable ones which drift easily.

# 3.0.4
- **FEAT (MCP)**: Because many small LLMs completely ignore the file offloading, made the behaviour default and mandatory. This approach saves tokens and increases efficiency.

## 3.0.3
- **FIX (MCP):** Fixed issue with small LLMs hallucinating tool calls and not reading the offloaded JSON results.
- **CHORE (Agent Skills):** Updated agent skills to provide more comprehensive documentation and guidance.

## 3.0.2
- **FIX (MCP):** Implemented safe argument extraction (`getStringArgument`, `getOptionalStringArgument`) for all MCP tools to provide clear, actionable error messages to LLMs when required arguments are missing or malformed, instead of crashing with a cryptic Dart type cast error (`type 'Null' is not a subtype of type 'String' in type cast`).
- **FEAT (MCP):** Implemented `McpToolFileOffloadDecorator` to automatically offload heavy analytical tool JSON responses to the local filesystem by default, preventing LLM context window overflow.
- **FEAT (MCP):** Added `output_file` and `return_full_json` arguments to all verbose analysis tools to allow LLMs to control context ingestion and orchestration paths.

## 3.0.1
- **FIX (MCP/NPM):** Resolved an issue where `npx @gbrandtio/rw-git-mcp` would fail with an `ENOEXEC` error. The npm package's `install.js` script now correctly handles non-200 HTTP responses and expects the raw, uncompressed binary executable to be available on GitHub Releases.
- **CHORE (Distribution):** Updated the GitHub Actions release workflow (`release_mcp.yml`) to upload the raw uncompressed executables in addition to the `.tar.gz` and `.zip` archives.

## 3.0.0
- **BREAKING (Core):** All major Git commands (`branch`, `status`, `diff`, `blame`, `show`, `getCommitsBetween`, `stats`) now return strongly-typed model classes (`GitBranch`, `GitStatus`, `GitDiff`, `GitBlame`, `GitCommit`, etc.) instead of raw Strings or `List<String>`.
- **BREAKING (MCP):** The MCP server now returns structured JSON representations of these Git domain models, enabling LLMs to deterministically parse and reason about Git repository state.
- **PERF (Core):** Migrated internal Git parsing logic to use `Isolate.run()` for large CLI outputs (over 10,000 characters), significantly reducing main-thread blocking in heavy Git operations.
- **FEAT (Core):** Added new models (`GitCommit`, `GitTag`, `GitBranch`, `GitStatus`, `GitFileChange`, `GitDiff`, `GitFileDiff`, `GitBlame`, `GitBlameLine`) under `lib/src/models/git/` to provide a robust object-oriented representation of Git objects.

## 2.0.2
- **FEAT (MCP):** Added AST & architecture analysis tools and metrics (`analyze_dart_ast_quality`, `analyze_architecture_drift`, `analyze_clean_code`).
- **FEAT (MCP):** Added `calculate_universal_lexical_metrics` tool to compute language-agnostic code quality metrics (Cyclomatic, Halstead, Cognitive, Maintainability Index) using a fast zero-allocation FSM Lexer.
- **BREAKING (Core & MCP):** Completely removed `cloneAndGetStatistics` method from `RwGit` facade and its corresponding MCP tool (`clone_and_get_statistics`) as this functionality is fully covered by the core `clone` and `stats` methods.
- **DOCS:** Added explicit documentation restricting LLMs from running intrusive custom commands (e.g., `git push`).
- **CHORE:** Improved and expanded the report orchestration MCP skill with new tools.
- **CHORE:** Added comprehensive tests to achieve 100% test coverage.

## 2.0.1
- **FEAT (MCP):** Added native support for MCP Resources and Prompts protocol capabilities.
- **DOCS:** Added comprehensive agent skills for installing the `rw-git` MCP server and for orchestrating comprehensive repository reports.
- **CHORE (Core):** Removed `git2dart` FFI integration and reverted to process-based executions with latest path dependency.
- **CHORE:** Fixed NPM package configuration, README, and GitHub Actions release workflows (`release_mcp.yml`).

## 2.0.0
- **FEAT (MCP):** Added `analyze_pr_diff` tool to analyze PR diffs for risk signals by combining churn history, bus factor, and secret detection into per-file composite risk scores.
- **FEAT (MCP):** Added `predict_merge_conflicts` tool to identify files modified on both branches since their merge base, predicting potential merge conflicts before a merge attempt.
- **FEAT (MCP):** Added `analyze_commit_velocity` tool to compute time-series commit velocity with per-author breakdown, trend analysis (accelerating/decelerating/stable), and anomaly detection.
- **FEAT (MCP):** Added `analyze_dependency_drift` tool to parse dependency manifests (pubspec.yaml, package.json, requirements.txt, go.mod, Cargo.toml, Gemfile) for supply chain risk analysis.
- **FEAT (MCP):** Added `generate_changelog` tool to generate structured changelogs using Conventional Commits conventions (feat/fix/BREAKING CHANGE).
- **FEAT (MCP):** Added `audit_compliance` tool to scan commit history for unsigned commits, empty messages, and unrecognized author emails.
- **FEAT (MCP):** Added `analyze_file_ownership` tool to cross-reference CODEOWNERS with git blame history for ownership drift detection.
- **FEAT (Core):** Added `findConflictRiskFiles`, `calculateCommitVelocity`, `parseDependencyManifests`, `scanComplianceIssues` methods to `CodeQualityTracker`.
- **FEAT (MCP):** Added `detect_secrets_in_commits` tool to scan commit history for exposed secrets using Isolates.
- **FEAT (MCP):** Added an optional `includeCodeDiff` boolean parameter to the code quality tools to provide actual git diffs for LLM code smell analysis, replacing the previous hardcoded hallucination-prone prompt.
- **BREAKING (MCP):** `analyze_code_quality`, `analyze_code_quality_with_authors`, and all `evaluate_comment_*` tools now return structured JSON instead of prescriptive prose prompts. This aligns them with the `analyze_release_delta` and `analyze_bus_factor` output conventions and significantly reduces token consumption.
- **PERF (MCP):** Replaced `git log --stat` with `git log --shortstat --format=%H %s` in the code quality tools, reducing the raw commit log payload by ~95% for large repositories.
- **FIX (MCP):** Removed the hardcoded "Staff Software Engineer" persona from all analysis and comment evaluation tools to avoid conflicting with the calling LLM's own identity.
- **FIX (MCP):** The `topN` parameter now applies consistently to all lists (suspicious commits, mega commits, high-churn files, classes, and blocks). Previously, suspicious and mega lists were unbounded when `topN` was not set.
- **REFACTOR (MCP):** `BaseEvaluateCommentsTool` hook method changed from `getPromptInstructions()` (returning a String) to `getEvaluationCriteria()` (returning `List<String>`).
- **REFACTOR (MCP):** `BaseAnalyzeCodeQualityTool` hook methods changed from `getChurnMetricsString()`/`getPromptInstructions()` to `getChurnData()`/`getAnalysisGuidance()` returning structured Maps.
- **RENAME (MCP):** The `includeRawLog` parameter has been renamed to `includeCommitLog` to better reflect the compact `--shortstat` format.

- **FEAT (Core):** Implemented the `Result<T, E>` pattern (`Result.getOrThrow()`) across all internal commands and public facades, removing raw Exceptions and unhandled `ProcessException`s from the execution flow.
- **FEAT (Core):** Added 9 new highly-requested git operations to `RwGit`: `branch`, `status`, `pull`, `push`, `diff`, `merge`, `stash`, `blame`, and `show`.
- **FEAT (Core):** Upgraded `GitCommand` execution to support path sanitization (directory traversal protection), observability via `dart:developer` timing logs, and extensibility hooks (`onBeforeRun`, `onAfterRun`).
- **FEAT (Core):** Unified argument handling by allowing `List<String> extraArgs` in all internal git commands.
- **PERF (Quality):** Optimized `CodeQualityTracker.calculateChurn` and `calculateChurnWithAuthors` to stream `git log` output asynchronously, eliminating Out of Memory crashes on massive repositories.
- **FIX (Quality):** Fixed a bug in `RwGitParser.parseGitShortLogStdout` where multi-word author names were incorrectly truncated.
- **CHORE:** Removed `dynamic` typing entirely from the codebase, updated `lints` to `^5.0.0`, and strictly enforced `dart analyze --fatal-infos`.

- Architecture: `RwGit` is now an abstract factory interface, preparing the core library for non-CLI Git operations.
- Architecture: Added `CliRwGit` to encapsulate existing `Process.run` functionality, ensuring no breaking changes to default behavior.
- Tooling: Added `executables` declaration in `pubspec.yaml` to allow running the MCP server globally via `dart pub global activate rw_git`.
- Distribution: Created GitHub Actions workflow `.github/workflows/release_mcp.yml` for automated cross-platform binary compilation.
- Distribution: Created scaffolding for npm packaging.

- [REFACTOR] `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use Template Method pattern (`BaseAnalyzeCodeQualityTool`) eliminating duplicated code logic.

- Exposing RwGitParser through the rw_git package for enhanced flexibility.

- Memory Efficiency: Refactored `CodeQualityTracker` to use an asynchronous stream state-machine (`runStream`) for processing `git log` outputs. This eliminates unbounded memory consumption when analyzing massive diffs in large repositories.
- MCP: Changed the `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use `git log --stat` instead of `git log -p` for their LLM context payload. This significantly reduces token usage and improves LLM accuracy when assessing commit size versus message quality.
- MCP: Rephrased the `get_rw_git_documentation` instructions to prevent LLMs from erroneously attempting to write Python scripts to manually construct JSON-RPC requests to the MCP server.

- MCP: Applied the `limit` parameter to `CodeQualityTracker` methods so that code quality metrics correctly reflect the specified recent commits window instead of parsing the entire repository history.
- MCP: `analyze_code_quality` and `analyze_code_quality_with_authors` now successfully bound their analysis to the requested commit `limit`.

- MCP: Added 10 individual, strongly-typed tools to directly invoke `RwGit` facade methods (`init_repository`, `clone_repository`, `get_stats`, etc.) to provide LLMs with perfect parameter schemas.
- MCP: Cleaned up `execute_git_command` to strictly accept raw git CLI args, preventing hallucination of facade function names.
- MCP: Transformed `get_rw_git_documentation` into a unified Agent Guide to route LLMs natively across all tools.

- Added `streamOutput` opt-in flag across all `RwGit` methods to support real-time streaming of Git standard output and standard error to the console.
- Refactored `ProcessRunner` to use `Process.start` to support seamless output streaming without blocking.
- MCP: Updated tool descriptions to include explicit invocation instructions for better LLM context.
- MCP: Improved code quality tracker outputs for suspicious and mega commits to include author, date, and commit message.

## 1.2.0
- **FEAT**: Added `evaluate_comment_llm_generation` MCP tool to detect LLM artifacts in comments.
- **FEAT**: Added `evaluate_comment_quality` MCP tool to analyze the quality of newly added or modified comments.
- **FEAT**: Added `evaluate_comment_necessity` MCP tool to evaluate whether comments are redundant and if code could be self-documenting instead.
- **REFACTOR**: Consolidated CodeQuality tools.

## 1.1.0
- [REFACTOR] `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use Template Method pattern (`BaseAnalyzeCodeQualityTool`) eliminating duplicated code logic.

## 1.0.4
- MCP: Combined `retrieve_commits_for_ai_review` functionality into `analyze_code_quality` and `analyze_code_quality_with_authors` to provide an internal AI prompt combined with code quality metrics and recent commits for a comprehensive code review context. 
- MCP: Removed `retrieve_commits_for_ai_review`.

## 1.0.2
- Fixed various bugs surfaced from unit testing.
- Code coverage 100%.
- Improved performance and logical output of some commands.

## 1.0.1
- Support for common git commands and operations:
  - `git init`
  - `git clone`
  - `git fetch tags`
  - Count commits between two tags
  - Retrieve statistics regarding code changes (insertions, deletions, number of files changed).
