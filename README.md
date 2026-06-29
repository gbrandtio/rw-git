<p align="center">
  <img src="https://user-images.githubusercontent.com/72696535/226140405-3bd31f1e-8cbb-4506-99db-1f0abce7c3fe.png" style="width: 20%;" alt="Github logo"/>
</p>
<p align="center">
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/dart.yml/badge.svg" alt="Github action dart.yml badge"/>
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/coverage.yml/badge.svg" alt="Code Coverage"/>
  <a href="https://codecov.io/gh/gbrandtio/rw-git" ><img src="https://codecov.io/gh/gbrandtio/rw-git/branch/main/graph/badge.svg?token=ETZPSI51EH"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

## Table of Contents

- [About](#about)
- [Model Context Protocol (MCP) Server](#model-context-protocol-mcp-server)
  - [Available MCP Tools](#available-mcp-tools)
  - [Available Prompts](#available-prompts)
  - [Connecting MCP with Agents](#connecting-mcp-with-agents)
- [Core Git Commands](#core-git-commands)
- [Getting started](#getting-started)
  - [Quick Start](#quick-start)
- [Additional information](#additional-information)

## About

`rw_git` intends to provide useful Git commands and Git harness that AI agents are looking for. 

The library and MCP server tools that it offers, provide out-of-the-box metrics, information and data that can contribute significantly in structured harness that LLMs / AI Agents need in order to perform deep analyses and create reports based on git (or use the harness as part of a bigger picture).

All these while keeping the token consumption to a *minimum*.

## Model Context Protocol (MCP) Server

`rw_git` ships with an embedded Model Context Protocol (MCP) server that allows AI agents and IDEs to interact directly with your git repositories. It communicates over standard I/O using JSON-RPC 2.0. The MCP can also be installed with bundled AI agent skills that provide structured workflows and detailed instructions for repository analysis.

### Available MCP Tools

`rw_git` provides a comprehensive suite of tools for AI agents to analyze your repository.

⚠️ **CRITICAL: Commit Limit (limit argument)**
For code quality and analysis tools, the default commit analysis limit is 500 commits (`limit = 500`). This is a conservative default for safety and predictability. If your analysis requires a broader historical scope or a tighter window, AI Agents **must explicitly override the `limit` argument**.

⚠️ **CRITICAL: Context Offloading (Preventing Overflow)**
To prevent your context window from overflowing, all verbose analytical tools will offload their massive JSON responses to the local filesystem by default (e.g., `.rw_git/reports/...`) and return only a lightweight summary. **CRITICAL:** You CANNOT generate a meaningful report with just this lightweight summary. You MUST actively read the offloaded JSON file (e.g., using your file reading tools or a script) to extract concrete metrics, lists, and actionable insights to include in your final response. You can specify a custom `output_file` path (must be within the repository) for better organization. If you absolutely need to ingest the raw JSON into your chat context, you must explicitly pass `return_full_json: true`.

**Repository Operations:**
- `init_repository`: Initializes a new Git repository.
- `clone_repository`: Clones a remote repository.
- `clone_specific_branch`: Clones a specific branch of a remote repository.
- `checkout_branch`: Switches branches.
- `is_git_repository`: Checks if a directory is a valid Git repository.
- `fetch_tags`: Retrieves all tags from the repository.

**Analysis & Metrics:**
- `analyze_code_quality`: Analyzes recent commits to identify code smells and technical debt.
- `analyze_code_quality_with_authors`: Analyzes code quality metrics along with author contributions.
- `analyze_bus_factor`: Calculates the "bus factor" by analyzing file ownership and contribution concentration.
- `analyze_commit_velocity`: Computes time-series commit velocity to track team productivity trends.
- `analyze_dependency_drift`: Parses dependency manifests for supply chain risk analysis.
- `analyze_file_ownership`: Cross-references CODEOWNERS with git blame history for ownership drift.
- `analyze_pr_diff`: Analyzes PR diffs for risk signals like high churn and exposed secrets.
- `analyze_release_delta`: Analyzes the changes and impact between two release tags.
- `predict_merge_conflicts`: Identifies files modified on both branches to predict merge conflicts.
- `analyze_dart_ast_quality`: Performs deep AST-level analysis of Dart files.
- `analyze_architecture_drift`: Analyzes git history to detect architectural drift by identifying commits that modify multiple layers.
- `analyze_clean_code`: Language-agnostic tool to analyze basic clean code heuristics.
- `calculate_universal_lexical_metrics`: Calculates language-agnostic code quality metrics (Cyclomatic, Halstead, Cognitive, Maintainability Index) for any source file.
- `get_stats`: Retrieves Git statistics like insertions and deletions.
- `get_commits_between`: Lists commits between two tags or branches.
- `get_contributions_by_author`: Retrieves commit counts grouped by author.

**Security & Compliance:**
- `audit_compliance`: Scans commit history for unsigned commits, empty messages, and unrecognized author emails.
- `detect_secrets_in_commits`: Scans commit history for exposed secrets or credentials.

**Code Review AI Agents:**
- `evaluate_comment_llm_generation`: Detects if code comments were likely generated by an LLM.
- `evaluate_comment_necessity`: Evaluates if comments are redundant or if the code could be self-documenting.
- `evaluate_comment_quality`: Analyzes the quality and usefulness of newly added comments.

### Available Prompts

The server natively exposes MCP Prompts that provide AI agents with detailed instructions and workflows on how to effectively use the repository tools:

- `rw-git-mcp-reporting`: A comprehensive, step-by-step workflow instructing the AI on how to orchestrate the analysis tools to generate thorough repository reports, code quality assessments, and risk analysis.

You can review the available skills under `.agents/skills` or in the repository directly.

### Installing Agent Skills

To install the bundled AI agent skills directly into your local workspace, you can use `npx`:
```bash
npx @gbrandtio/rw-git-mcp install-skills
```

Alternatively, if you have installed the package globally via `npm install -g`, you can simply run:
```bash
rw-git-mcp install-skills
```

This will extract the skills to `./.agents/skills/rw-git-mcp/` in your current directory, making them available for your local agents.

### Connecting MCP with Agents

To use the MCP server, you can choose from several installation methods depending on your environment.

**NPM / NPX (Recommended for Claude/Cursor/AGY)**
The easiest way is to run the server via `npx` (requires Node.js):
```bash
npx -y @gbrandtio/rw-git-mcp
```

**Dart SDK (For Dart/Flutter developers)**
```bash
dart pub global activate rw_git
```

**Pre-compiled Binaries**
You can also download standalone native executables for Windows, macOS (Intel/Apple Silicon), and Linux from the [GitHub Releases](https://github.com/gbrandtio/rw-git/releases) page.

#### Claude Desktop
Add this to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "npx",
      "args": ["-y", "@gbrandtio/rw-git-mcp"]
    }
  }
}
```

#### Cursor
In Cursor's `mcp.json` or `.cursor/mcp.json`:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "npx",
      "args": ["-y", "@gbrandtio/rw-git-mcp"]
    }
  }
}
```

#### Antigravity (AGY CLI / Web IDE)
Add this to your MCP configuration block:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "npx",
      "args": ["-y", "@gbrandtio/rw-git-mcp"]
    }
  }
}
```

*(Note: If you installed via Dart global activate, or downloaded the binaries, replace `npx` and its `args` with the absolute path to the executable, e.g., `["/path/to/rw_git_mcp"]`).*

## Core Git Commands

Provides a clean, fluent API for all standard Git operations with robust, type-safe error handling. All Git commands return strongly-typed domain models (e.g., `GitCommit`, `GitStatus`, `GitDiff`) wrapped in a `Result` pattern for predictable error propagation.

- `init`: Initializes a new Git repository.
- `clone`: Clones a remote repository to a local directory.
- `checkout`: Switches branches or restores working tree files.
- `branch`: Lists, creates, or deletes branches.
- `status`: Displays the state of the working directory and the staging area.
- `pull`: Fetches from and integrates with another repository or a local branch.
- `diff`: Shows changes between commits, commit and working tree, etc.
- `merge`: Joins two or more development histories together.
- `stash`: Stashes the changes in a dirty working directory away.
- `blame`: Shows what revision and author last modified each line of a file.
- `show`: Shows various types of objects (commits, trees, tags).
- `fetchTags`: Fetches all tags from the remote repository.
- `getCommitsBetween`: Retrieves a list of commits between two tags or branches.
- `stats`: Retrieves code-change statistics (insertions, deletions, files changed) between two points.

---

## Getting started

Add the package to your `pubspec.yaml`:
```yaml
dependencies:
  rw_git: ^2.0.0
```

### Quick Start

Initialize the facade and start executing Git operations seamlessly:

```dart
import 'package:rw_git/rw_git.dart';

void main() async {
  // 1. Initialize the wrapper
  RwGit rwGit = RwGit();

  // 2. Clone a repository
  String localDir = "./my-project";
  await rwGit.clone(localDir, "https://github.com/google/flutter");

  // 3. Retrieve code-change statistics
  final stats = await rwGit.stats(localDir, "old-tag", "new-tag");
  print('Files Changed: ${stats.numberOfChangedFiles}');
}
```

For comprehensive API details, please check our [official documentation](https://pub.dev/documentation/rw_git/latest/).

## Additional information

Please file any issues on the [github issue tracker](https://github.com/gbrandtio/rw-git/issues).
