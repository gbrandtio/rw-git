# 3.0.7
- **REFACTOR:** Refactored the MCP tools implementation, adhering to SRP principles and making the repository future-proof and easily extendable.

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
