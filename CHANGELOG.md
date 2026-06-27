## 3.3.0
- **FEAT (MCP):** Added `detect_secrets_in_commits` tool to scan commit history for exposed secrets using Isolates.
- **FEAT (MCP):** Added an optional `includeCodeDiff` boolean parameter to the code quality tools to provide actual git diffs for LLM code smell analysis, replacing the previous hardcoded hallucination-prone prompt.
- **BREAKING (MCP):** `analyze_code_quality`, `analyze_code_quality_with_authors`, and all `evaluate_comment_*` tools now return structured JSON instead of prescriptive prose prompts. This aligns them with the `analyze_release_delta` and `analyze_bus_factor` output conventions and significantly reduces token consumption.
- **PERF (MCP):** Replaced `git log --stat` with `git log --shortstat --format=%H %s` in the code quality tools, reducing the raw commit log payload by ~95% for large repositories.
- **FIX (MCP):** Removed the hardcoded "Staff Software Engineer" persona from all analysis and comment evaluation tools to avoid conflicting with the calling LLM's own identity.
- **FIX (MCP):** The `topN` parameter now applies consistently to all lists (suspicious commits, mega commits, high-churn files, classes, and blocks). Previously, suspicious and mega lists were unbounded when `topN` was not set.
- **REFACTOR (MCP):** `BaseEvaluateCommentsTool` hook method changed from `getPromptInstructions()` (returning a String) to `getEvaluationCriteria()` (returning `List<String>`).
- **REFACTOR (MCP):** `BaseAnalyzeCodeQualityTool` hook methods changed from `getChurnMetricsString()`/`getPromptInstructions()` to `getChurnData()`/`getAnalysisGuidance()` returning structured Maps.
- **RENAME (MCP):** The `includeRawLog` parameter has been renamed to `includeCommitLog` to better reflect the compact `--shortstat` format.

## 3.2.0
- **FEAT (Core):** Implemented the `Result<T, E>` pattern (`Result.getOrThrow()`) across all internal commands and public facades, removing raw Exceptions and unhandled `ProcessException`s from the execution flow.
- **FEAT (Core):** Added 9 new highly-requested git operations to `RwGit`: `branch`, `status`, `pull`, `push`, `diff`, `merge`, `stash`, `blame`, and `show`.
- **FEAT (Core):** Upgraded `GitCommand` execution to support path sanitization (directory traversal protection), observability via `dart:developer` timing logs, and extensibility hooks (`onBeforeRun`, `onAfterRun`).
- **FEAT (Core):** Unified argument handling by allowing `List<String> extraArgs` in all internal git commands.
- **PERF (Quality):** Optimized `CodeQualityTracker.calculateChurn` and `calculateChurnWithAuthors` to stream `git log` output asynchronously, eliminating Out of Memory crashes on massive repositories.
- **FIX (Quality):** Fixed a bug in `RwGitParser.parseGitShortLogStdout` where multi-word author names were incorrectly truncated.
- **CHORE:** Removed `dynamic` typing entirely from the codebase, updated `lints` to `^5.0.0`, and strictly enforced `dart analyze --fatal-infos`.
- **MCP:** Added native support for MCP Resources and Prompts protocol capabilities.

## 3.1.0
- Architecture: `RwGit` is now an abstract factory interface, preparing the core library for non-CLI Git operations.
- Architecture: Added `CliRwGit` to encapsulate existing `Process.run` functionality, ensuring no breaking changes to default behavior.
- Architecture: Added `LibGit2RwGit` stub implementation to lay the foundation for mobile support via `libgit2` FFI.
- Tooling: Added `executables` declaration in `pubspec.yaml` to allow running the MCP server globally via `dart pub global activate rw_git`.
- Distribution: Created GitHub Actions workflow `.github/workflows/release_mcp.yml` for automated cross-platform binary compilation.
- Distribution: Created scaffolding for npm and Homebrew packaging.

## 3.0.4
- [REFACTOR] `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use Template Method pattern (`BaseAnalyzeCodeQualityTool`) eliminating duplicated code logic.

## 3.0.3
- Exposing RwGitParser through the rw_git package for enhanced flexibility.

## 2.3.0
- Memory Efficiency: Refactored `CodeQualityTracker` to use an asynchronous stream state-machine (`runStream`) for processing `git log` outputs. This eliminates unbounded memory consumption when analyzing massive diffs in large repositories.
- MCP: Changed the `analyze_code_quality` and `analyze_code_quality_with_authors` tools to use `git log --stat` instead of `git log -p` for their LLM context payload. This significantly reduces token usage and improves LLM accuracy when assessing commit size versus message quality.
- MCP: Rephrased the `get_rw_git_documentation` instructions to prevent LLMs from erroneously attempting to write Python scripts to manually construct JSON-RPC requests to the MCP server.

## 2.2.1
- MCP: Applied the `limit` parameter to `CodeQualityTracker` methods so that code quality metrics correctly reflect the specified recent commits window instead of parsing the entire repository history.
- MCP: `analyze_code_quality` and `analyze_code_quality_with_authors` now successfully bound their analysis to the requested commit `limit`.

## 2.2.0
- MCP: Added 10 individual, strongly-typed tools to directly invoke `RwGit` facade methods (`init_repository`, `clone_repository`, `get_stats`, etc.) to provide LLMs with perfect parameter schemas.
- MCP: Cleaned up `execute_git_command` to strictly accept raw git CLI args, preventing hallucination of facade function names.
- MCP: Transformed `get_rw_git_documentation` into a unified Agent Guide to route LLMs natively across all tools.

## 2.1.0
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
