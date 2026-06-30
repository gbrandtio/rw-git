<p align="center">
  <img src="https://user-images.githubusercontent.com/72696535/226140405-3bd31f1e-8cbb-4506-99db-1f0abce7c3fe.png" style="width: 20%;" alt="Github logo"/>
</p>
<p align="center">
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/dart.yml/badge.svg" alt="Github action dart.yml badge"/>
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/coverage.yml/badge.svg" alt="Code Coverage"/>
  <a href="https://codecov.io/gh/gbrandtio/rw-git" ><img src="https://codecov.io/gh/gbrandtio/rw-git/branch/main/graph/badge.svg?token=ETZPSI51EH"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

Modern software teams generate a vast amount of data in their git history. 
`rw_git` turns that raw history into actionable intelligence, empowering 
engineering leaders to ask and answer critical business questions.

With that being said, `rw-git` can be integrated via the MCP with your AI agent, or used as a library where your application orchestrates the insights gathering *without any LLM participation*. 

Among a variety of questions that `rw-git` answers, below are some examples:

- **Where is our technical debt accumulating?** We identify implicitly coupled 
  files and high-churn code to highlight architectural decay and predict 
  defect-prone areas.
- **Are we at risk of critical knowledge loss?** We calculate the "Bus Factor" 
  and ownership drift, showing exactly where project knowledge is concentrated 
  in too few developers.
- **Who introduced a bug, and why?** Using algorithms like SZZ, we trace bugs 
  back to their origin commits, providing context on how and why defects were 
  introduced.
- **Is our supply chain secure and compliant?** We scan commit history for 
  exposed secrets, unsigned commits, and dependency drift, ensuring your 
  repository remains secure over time.
- **Is our team's delivery velocity healthy?** We compute time-series commit 
  velocity and analyze release deltas to track team productivity trends and 
  delivery impact.

### Zero LLM Token Consumption for Metric Extraction

A key differentiator of the `rw_git` Model Context Protocol (MCP) server is its 
**zero-cost metric generation**. The library performs the heavy lifting:
parsing massive git histories, running algorithms like SZZ, 
and computing metrics *entirely in runtime locally*. 

When you use AI agents to analyze your repository, the LLM only consumes tokens 
to read the finalized, highly structured insights and interact with the MCP server. The underlying work of gathering and structuring insights and metrics is performed during runtime, by carefully crafted algorithms.

---

## Table of Contents

- [About](#about)
- [Model Context Protocol (MCP) Server](#model-context-protocol-mcp-server)
  - [Available MCP Tools](#available-mcp-tools)
  - [Available Prompts](#available-prompts)
  - [Installing Agent Skills](#installing-agent-skills)
  - [Connecting MCP with Agents](#connecting-mcp-with-agents)
- [Core Git Commands](#core-git-commands)
- [Getting started](#getting-started)
- [Additional information](#additional-information)

## About

`rw_git` is a powerful Git operations library and Model Context Protocol (MCP) 
server designed to provide AI agents, IDEs, and developers with deep, 
out-of-the-box metrics and data analysis. Whether you are building an automated 
reporting pipeline or an intelligent code reviewer, `rw_git` supplies the 
structured harness needed to perform comprehensive repository analyses safely 
and efficiently.

## Model Context Protocol (MCP) Server

`rw_git` ships with an embedded MCP server that allows AI agents and IDEs to 
interact directly with your git repositories over standard I/O using 
JSON-RPC 2.0.

### Available MCP Tools

We provide a comprehensive suite of tools mapped directly to solving 
engineering management and code quality challenges.

**Dev Metrics & Technical Debt:**
- `analyze_code_quality`: Identifies code smells and technical debt.
- `analyze_code_quality_with_authors`: Correlates metrics with authors.
- `analyze_bug_hotspots`: Calculates bug hotspots using the SZZ algorithm.
- `analyze_bus_factor`: Calculates the Bus Factor (Truck Factor).
- `analyze_logical_coupling`: Detects implicitly coupled files.
- `analyze_code_volatility`: Predicts defect-prone files via historical churn.
- `analyze_refactoring`: Detects structural refactorings and simplifications.
- `analyze_file_ownership`: Cross-references CODEOWNERS with git blame history.
- `analyze_pr_diff`: Analyzes PR diffs for risk signals like high churn.
- `predict_merge_conflicts`: Identifies files modified on multiple branches.
- `analyze_dart_ast_quality`: Performs deep AST-level analysis of Dart files.
- `analyze_architecture_drift`: Detects architectural drift (cross-layer).
- `analyze_clean_code`: Language-agnostic clean code heuristic analysis.
- `calculate_universal_lexical_metrics`: Calculates Maintainability Index.

**Project Management Metrics:**
- `find_bugs_by_developer`: Finds bugs introduced by specific developers (SZZ).
- `analyze_commit_velocity`: Computes time-series commit velocity.
- `analyze_release_delta`: Analyzes changes and impact between release tags.
- `get_stats`: Retrieves exact Git statistics (insertions, deletions).
- `get_commits_between`: Lists commits between tags or branches.
- `get_contributions_by_author`: Retrieves commit counts grouped by author.
- `generate_changelog`: Generates high-level progress summaries.

**Security & Compliance:**
- `audit_compliance`: Scans for unsigned commits and empty messages.
- `detect_secrets_in_commits`: Scans commit history for exposed secrets.
- `analyze_dependency_drift`: Parses dependency manifests for risks.

**Code Review AI Agents:**
- `evaluate_comment_llm_generation`: Detects AI-generated code comments.
- `evaluate_comment_necessity`: Evaluates if comments are redundant.
- `evaluate_comment_quality`: Analyzes the usefulness of newly added comments.

**Repository Operations:**
- `init_repository`, `clone_repository`, `clone_specific_branch`, 
  `checkout_branch`, `is_git_repository`, `fetch_tags`: Standard git operations.

### Available Prompts

The server exposes native MCP Prompts that provide AI agents with workflows:

- `rw-git-mcp-reporting`: A step-by-step workflow instructing the AI on 
  orchestrating tools to generate comprehensive repository reports.

### Installing Agent Skills

To install bundled AI agent skills locally:

```bash
npx @gbrandtio/rw-git-mcp install-skills
```
*(Or `rw-git-mcp install-skills` if installed globally)*

This extracts skills to `./.agents/skills/rw-git-mcp/` for local agent usage.

### Connecting MCP with Agents

**NPM / NPX (Recommended for Claude/Cursor/AGY)**:
```bash
npx -y @gbrandtio/rw-git-mcp
```

**Dart SDK**:
```bash
dart pub global activate rw_git
```

**Pre-compiled Binaries**: Download native executables from 
[GitHub Releases](https://github.com/gbrandtio/rw-git/releases).

#### Client Configurations

**Claude Desktop** (`claude_desktop_config.json`):
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

**Cursor** (`.cursor/mcp.json`):
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

## Core Git Commands

`rw_git` also provides a clean, fluent Dart API for standard Git operations. 
All commands return strongly-typed domain models wrapped in a predictable 
`Result` pattern.

- `init`, `clone`, `checkout`, `branch`, `status`, `pull`, `diff`, `merge`, 
  `stash`, `blame`, `show`, `fetchTags`, `getCommitsBetween`, `stats`.

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  rw_git: ^2.0.0
```

### Quick Start

```dart
import 'package:rw_git/rw_git.dart';

void main() async {
  RwGit rwGit = RwGit();
  String localDir = "./my-project";
  
  await rwGit.clone(localDir, "https://github.com/google/flutter");
  final stats = await rwGit.stats(localDir, "old-tag", "new-tag");
  print('Files Changed: ${stats.numberOfChangedFiles}');
}
```

For full API details, see our 
[official documentation](https://pub.dev/documentation/rw_git/latest/).

## Additional information

Please file any issues on the 
[github issue tracker](https://github.com/gbrandtio/rw-git/issues).
