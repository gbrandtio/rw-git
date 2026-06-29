---
name: rw-git-mcp-reporting
description: "Comprehensive workflow for orchestrating rw_git MCP tools to generate thorough repository reports, code quality assessments, and risk analysis."
---

# `rw-git` MCP Reporting Workflow

This skill instructs you on how to orchestrate the complete suite of MCP tools provided by the `rw_git` server to generate a comprehensive, structured report of a repository.
When a user asks you to analyze the repository, assess code quality, evaluate an entire project, or generate a report, strictly follow this step-by-step workflow to ensure no stone is left unturned.

## 1. Environment & Scope Preparation
Before diving into analysis, you **MUST** understand the context and establish the baseline environment.
- **Is it a remote or local repo?** Use `clone_repository` or `clone_specific_branch` to fetch it remotely. If you need to initialize a fresh local repository for analysis from scratch, use `init_repository`.
- **Local Verification:** If working locally, use `is_git_repository` to ensure you are in a valid Git directory.
- **Branch Context:** Use `checkout_branch` to switch to the appropriate target branch before running analysis, if needed.
- **Reference Gathering:** Use `fetch_tags` to get a list of available tags if you need to perform release comparisons.
- **Internal Docs:** If you ever need to understand how the underlying `rw_git` commands execute or handle errors, run `get_rw_git_documentation`.
- **Scope Resolution:** Resolve the exact arguments you will need for downstream tools (e.g., `limit`, `since`, `until`, `oldVersion`, `newVersion`, `branchA`, `branchB`).
  - ⚠️ **CRITICAL (Commit Limit):** The default limit for code quality analysis tools is **500 commits**. This is a conservative baseline. If your analysis scope requires more (or less) history, you **MUST explicitly override the `limit` argument**.
  - ⚠️ **CRITICAL (Context Offloading)**: ALL verbose analytical tools will offload their massive JSON responses to the local filesystem (e.g. `.rw_git/reports/...`) to prevent your context window from overflowing. You will only receive a lightweight summary and the file path. You can optionally specify the exact `output_file` path (must be within the repository) for better organization.

## 2. General Statistics & Contributor Activity
Start by building a foundational understanding of the codebase's size, scope, and primary drivers.
- **Overall Stats:** Run `get_stats` to get a high-level view of insertions, deletions, and total files changed.
- **Commit History:** Run `get_commits_between` to retrieve the raw sequence of commits in the target range to understand the context of the work.
- **Contributor Breakdown:** Run `get_contributions_by_author` to identify the most active contributors in the repository.

## 3. Targeted Assessment & Velocity
Dive into the specific changes, analyzing their impact and how fast the team is moving.
- **For Branch/PR Comparisons:** Run `analyze_pr_diff` to get a breakdown of the specific risks introduced in a Pull Request.
- **For Tag/Release Comparisons:** Run `analyze_release_delta` to understand the structural changes between versions.
- **Code Quality:** Run `analyze_code_quality` (or `analyze_code_quality_with_authors` if the breakdown of contributors is important) to spot code smells, complex files, and technical debt.
- **Bug Hotspots:** Run `analyze_bug_hotspots` to identify files that are frequently modified in bug-fix commits, highlighting areas that may need refactoring.
- **Trend Analysis:** Run `analyze_commit_velocity` to gather time-series trend data, exposing anomalies in commit frequency and tracking team productivity over time.
- **Deep Inspection:** If you are analyzing Dart code, use `analyze_dart_ast_quality` for AST-level insights into dead code, public signature diffs, and dependency graphs. Use `analyze_clean_code` on individual files to check basic SOLID principles and readability heuristics. Use `calculate_universal_lexical_metrics` for fast, language-agnostic lexical complexity metrics (Cyclomatic, Halstead, Cognitive) on any text-based source file.

## 4. Security & Compliance Check
Ensure the code being analyzed meets security policies and project compliance standards. This step is critical for CI/CD environments.
- **Secret Scanning:** Run `detect_secrets_in_commits` to aggressively flag any exposed credentials, API keys, or tokens.
- **Compliance Auditing:** Run `audit_compliance` to ensure commit signatures exist, email addresses match recognized domains, and project commit message policies (like conventional commits or no empty messages) are being followed.

## 5. Risk Analysis
Detect architectural bottlenecks, ownership risks, and potential integration disasters.
- **Knowledge Silos:** Run `analyze_bus_factor` and `analyze_file_ownership` to identify "mega-files" that have drifted in ownership or rely too heavily on a single author (low bus factor).
- **Integration Risk:** If you are analyzing a branch intended for integration (PR), run `predict_merge_conflicts` to proactively surface files that will conflict with the base branch.
- **Architecture Integrity:** Run `analyze_architecture_drift` to ensure that commits are not simultaneously modifying disparate architectural layers (which could signal leaky abstractions or tight coupling).

## 6. Code Review & Ecosystem Health
Deep dive into the contents of the changes, focusing on dependencies and documentation.
- **Supply Chain Risks:** Use `analyze_dependency_drift` to flag vulnerable, unpinned, or floating dependencies across ecosystem manifests (e.g., `pubspec.yaml`, `package.json`).
- **AI-Assisted Code Review:** Evaluate the quality and origin of code comments using `evaluate_comment_quality` and `evaluate_comment_necessity`. Use `evaluate_comment_llm_generation` to detect if documentation was hastily generated by an LLM without human oversight, helping maintain a clean, self-documenting codebase.

## 7. Release Notes & Changelogs
If the user's request involves summarizing changes between releases or wrapping up a large feature branch, prepare the user-facing documentation.
- **Changelog Generation:** Run `generate_changelog` to retrieve a structured, human-readable list of features, fixes, and breaking changes. Note that this tool also structurally links fixes to bug-introducing commits via SZZ.

## 8. Synthesis & Formatting
Aggregate the outputs from all the invoked tools into a highly structured, unified Markdown artifact. 
- **Analyze Offloaded Data (CRITICAL):** Because the tools offload their detailed JSON responses to the filesystem, you MUST actively analyze these files to extract business value. Do not just regurgitate that the analysis was completed or that files were offloaded. You must read the offloaded JSON files (e.g., using file reading tools, or by writing and executing a short script to parse and aggregate the top issues) to extract concrete metrics, problematic file paths, and specific findings to include in your final report.
- Present the information with a clear executive summary followed by detailed sections.
- Use Github-flavored markdown alerts (`> [!WARNING]`, `> [!IMPORTANT]`, `> [!CAUTION]`) to highlight critical risks, exposed secrets, severe compliance violations, or likely merge conflicts.
- **Leverage Structured Data:** The underlying `rw_git` tools return highly structured Git models (e.g., `GitCommit`, `GitDiff`, `GitStatus`, `GitTag`, `RwGitStats`) making the outputs strongly typed and predictable. Leverage these rich structures to confidently generate tables, summaries, and charts without brittle string parsing.
- **Do not dump raw JSON.** Synthesize the metrics into readable tables, lists, and actionable insights. Use mermaid diagrams if it helps visualize complex relationships like contributor ownership.
- Point the user directly to the most critical files requiring attention based on the analysis.
