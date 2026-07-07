<p align="center">
  <img src="https://user-images.githubusercontent.com/72696535/226140405-3bd31f1e-8cbb-4506-99db-1f0abce7c3fe.png" style="width: 20%;" alt="Github logo"/>
</p>
<p align="center">
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/dart.yml/badge.svg" alt="Github action dart.yml badge"/>
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/coverage.yml/badge.svg" alt="Code Coverage"/>
  <a href="https://codecov.io/gh/gbrandtio/rw-git" ><img src="https://codecov.io/gh/gbrandtio/rw-git/branch/main/graph/badge.svg?token=ETZPSI51EH"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
  <a href="https://pub.dev/packages/rw_git"><img src="https://img.shields.io/pub/v/rw_git.svg" alt="Pub Version"></a>
  <a href="https://pub.dev/packages/rw_git/score"><img src="https://img.shields.io/pub/points/rw_git" alt="Pub Points"></a>
</p>

## Preface

Modern software teams generate a vast amount of data in their git history. 
`rw_git` turns that raw history into actionable intelligence, empowering 
engineering leaders to ask and answer critical business questions.

`rw_git` depends on strong technical foundations backed by academic research
and published academic papers (see `doc/tools`). This means that the 
underlying functionality and intel collection is vastly available 
without the need of an LLM / MCP integration (which essentially means that 
you can utilise the raw functionality with or without the MCP tools).

Different stakeholders have different requirements for data insights, which
is the reason why `rw_git` is easily extendable, flexible and highly
configurable.

**Who is this for?** Engineering leaders who need defensible answers about
delivery risk and technical debt, platform/DevEx teams building internal tooling
on top of repository data, security and compliance reviewers auditing commit
history, and individual contributors who want deeper context during code review.

### Why rw_git

- **Zero LLM token cost**: every metric is computed locally by deterministic
  Dart code, not by asking an LLM to read and summarize raw `git log` output.
  AI agents only spend tokens on the finished insight.
- **Evidence-based, not ad hoc**: each algorithm (bug attribution via SZZ,
  secret detection via entropy analysis, bus factor, logical coupling, and more)
  is grounded in peer-reviewed software-engineering research, not a one-off
  heuristic script.
- **Library first, MCP second**: the same analyses are available as a
  standalone Dart API and as MCP tools, so you are never locked into an
  agent-only workflow.
- **Broad coverage**: 30+ tools spanning technical debt, bus factor, security
  and compliance, delivery velocity, and AI-assisted code review, instead of a
  single narrow metric.

## Business Intelligence beyond engineering metrics

Among a variety of questions that `rw_git` answers, below are some examples:

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
to read the finalized, highly structured insights and interact with the 
MCP server. The underlying work of gathering and structuring insights 
and metrics is performed during runtime, by carefully crafted algorithms.

---

## Table of Contents

- [About](#about)
- [Model Context Protocol (MCP) Server](#model-context-protocol-mcp-server)
  - [Available MCP Tools](#available-mcp-tools)
  - [Available Prompts](#available-prompts)
  - [Installing Agent Skills](#installing-agent-skills)
  - [Connecting MCP with Agents](#connecting-mcp-with-agents)
- [Core Git Commands](#core-git-commands)
- [Using rw-git as a Library](#using-rw-git-as-a-library)
- [Getting started](#getting-started)
- [Contributing](#contributing)
- [License](#license)
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

Tools that advertise an `outputSchema` (the report meta-tools and a handful
of fixed-shape tools, per ADR-0013) return their payload as MCP
`structuredContent` alongside the standard text block, so standards-aware
clients get machine-readable results without parsing the text.

The server advertises the MCP `logging` capability: hosts control how much
diagnostic detail they receive (git command timings, failures) by calling
`logging/setLevel` with an RFC 5424 level (`debug` … `emergency`). By default
only `warning` and above are forwarded as `notifications/message`, keeping
the stdio channel quiet.

Large tool outputs are offloaded to `.rw_git/reports/` instead of being
returned inline. The size gate is per tool: report meta-tools offload above
4 KiB (their summaries already carry the findings inline), compact history
tools (`get_stats`, `get_commits_between`) stay inline up to 16 KiB, and all
other tools use the 8 KiB default. Each offload summary carries a compact
`preview` (a `structure` map of top-level keys to type tags, plus any
pre-classified findings) so targeted slices can be fetched with
`read_report_slice` without reading the whole file.

### Available MCP Tools

We provide a comprehensive suite of tools mapped directly to solving 
engineering management and code quality challenges.

**One-Call Report Meta-Tools (recommended starting point):**

Each runs the relevant analyses server-side (independent analyses run
concurrently), applies every severity band and cross-tool compound-risk rule
in Dart, and returns a small, ranked, already-classified payload (`summary`,
`top_findings`, `compound_findings`, and — where churn and complexity both
apply — a ranked Tornhill `refactoring_targets` list). Every finding names
the research behind its band in a compact `basis` tag (e.g. `Truck-factor
estimation (Avelino et al. 2016)`), with a fuller per-finding `rationale`
carried inline, including in the offload preview. All five report tools also
accept optional `since`/`until` parameters (ISO-8601 dates or git relative
phrases, e.g. `"2024-01-01"` or `"6 months ago"`) to scope analysis to a date
window — e.g. "generate a report for 2024" or "for the previous 6 months":
- `generate_repository_audit`: High-level deep audit (technical + security +
  delivery cadence + commit hygiene).
- `generate_technical_report`: Code quality, technical debt, architecture —
  the full genuine lexical suite (McCabe, maintainability index, ABC, NPath,
  cognitive complexity, Halstead delivered-bugs) on top-churn files,
  clean-code heuristics, architecture drift over inferred layers, Dart
  import cycles, and refactoring-aware churn discounting.
- `generate_security_report`: Secrets, compliance, dependency freshness.
- `generate_pm_report`: Knowledge concentration (including the Bird
  minor-contributor signal and author-level knowledge-loss risk), delivery
  bottlenecks, and delivery cadence (velocity trend, author concentration,
  burnout signals).
- `generate_code_review_report`: Risk signals for code under review —
  secrets, the genuine lexical suite, clean-code heuristics, ownership
  structure, bug hotspots — with refactoring-explained churn discounted.

**Dev Metrics & Technical Debt:**
- `analyze_code_quality`: Identifies code smells and technical debt. Pass
  `includeAuthors: true` to correlate metrics with authors.
- `analyze_bug_hotspots`: Calculates bug hotspots using the
  refactoring-aware SZZ algorithm (RA-SZZ). Pass `author` to scope the
  analysis to bugs introduced by a specific developer.
- `analyze_bus_factor`: Calculates the Bus Factor (Truck Factor).
- `analyze_logical_coupling`: Detects implicitly coupled files.
- `analyze_code_volatility`: Predicts defect-prone files via historical churn.
- `analyze_refactoring`: Detects structural refactorings and simplifications.
- `analyze_file_ownership`: Cross-references CODEOWNERS with git blame history.
- `analyze_dart_ast_quality`: Performs deep AST-level analysis of Dart files.
- `analyze_architecture_drift`: Detects architectural drift (cross-layer).
- `analyze_clean_code`: Language-agnostic clean code heuristic analysis.
- `calculate_universal_lexical_metrics`: Calculates Maintainability Index.

**Project Management Metrics:**
- `analyze_commit_velocity`: Computes time-series commit velocity.
- `analyze_release_delta`: Analyzes changes and impact between release tags.
- `get_stats`: Retrieves exact Git statistics (insertions, deletions).
- `get_commits_between`: Lists commits between tags or branches.
- `get_contributions_by_author`: Retrieves commit counts grouped by author.
- `generate_changelog`: Generates high-level progress summaries.

**Security & Compliance:**
- `audit_compliance`: Scans for unsigned commits and empty messages.
- `detect_secrets_in_commits`: Scans commit history for exposed secrets.
- `analyze_dependency_drift`: Parses dependency manifests for pinning risk,
  with an opt-in network-based version freshness check (`check_freshness`).

**Code Review AI Agents:**
- `evaluate_comments`: Evaluates comments added in recent commits across one
  or more aspects (`aspects` parameter): `quality` (professional, accurate,
  correctly formatted), `necessity` (redundant vs. self-documenting), and
  `llm_generation` (AI-generated comment artifacts). Defaults to all aspects.

**Repository Operations:**
- `init_repository`, `clone_repository`, `clone_specific_branch`, 
  `checkout_branch`, `is_git_repository`, `fetch_tags`: Standard git operations.

**Documentation & Discovery:**
- `get_rw_git_documentation`: Retrieves tool documentation directly within the
  MCP session, so agents can self-discover capabilities without external
  lookups.
- `read_report_slice`: Reads a targeted key-path/array-slice of a report
  previously offloaded to `.rw_git/reports/`, instead of loading the entire
  file back into context.

### Available Prompts

The server exposes one native MCP Prompt that hands the agent a ready-made,
token-efficient workflow for every reporting goal. It is generated from a
canonical `SKILL.template.md` (shared boilerplate lives once in
`.agents/skills/_shared/`), which also produces the matching agent skill
(see below). The workflow serves both model classes: the default path is
the compact one-call narrate-the-report flow for small/local models, and a
trailing `<deep_dive>` section routes capable models to the raw analysis
tools plus `read_report_slice` drill-down, with one tool list per report
type. Each `<deep_dive>` tool list is itself generated from the same
`toolHintsCatalog`/`pair_with` data that drives raw-tool hints (see
ADR-0015), so the report's `hints`, its deep-dive routing, and a raw tool's
own hints can never diverge from one another:

- `rw-git-mcp-reporting`: one consolidated reporting workflow with a
  goal-to-tool selection table covering all five report types — full
  repository audit, technical debt and architecture, project management and
  knowledge risk, security and compliance, and code review — plus
  per-report-type deep-dive raw-tool lists.

### Installing Agent Skills

The MCP Prompts above are also shipped as file-based agent skills. To install
them locally:

```bash
npx @gbrandtio/rw-git-mcp install-skills
```
*(Or `rw-git-mcp install-skills` if installed globally)*

This extracts skills to `./.agents/skills/rw-git-mcp/` for local agent usage.
The bundled skills are the consolidated `rw-git-mcp-reporting` workflow listed
under **Available Prompts**, plus `rw-git-mcp-installation`, a step-by-step
setup guide for Claude Desktop, Cursor, and other MCP clients.

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

**Claude Code (CLI)**:
```bash
claude mcp add rw_git --scope user -- npx -y @gbrandtio/rw-git-mcp
```

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

## Using rw-git as a Library

Every analysis behind the MCP tools above is also available as a plain Dart
class, so you can use the same algorithms without running the MCP server.
Each class takes a `ProcessRunner` and returns a strongly-typed DTO:

```dart
import 'package:rw_git/rw_git.dart';

void main() async {
  final runner = ProcessRunner.defaultRunner();

  final busFactor = await BusFactorAlgorithm(runner).execute('./my-project');
  print('Bus factor: ${busFactor.busFactor}');

  // The same DTOs returned by the MCP tools are available directly,
  // including their .toJson() if you still want a JSON representation.
  print(busFactor.toJson());
}
```

Available classes (all in `package:rw_git/rw_git.dart`):

| Class | Returns |
| --- | --- |
| `BusFactorAlgorithm` | `BusFactorDto` |
| `LogicalCouplingAlgorithm` | `List<LogicalCouplingDto>` |
| `RefactoringDetectionAlgorithm` | `List<RefactoringDto>` |
| `CodeVolatilityAlgorithm` | `List<CodeVolatilityDto>` |
| `SzzAlgorithm` | `List<SzzMatch>` |
| `AdvancedMetricsHeuristic` | `AdvancedCodeQualityDto` |
| `BugHotspotsHeuristic` | `BugHotspotDto` |
| `ChurnHeuristic` | `ChurnMetricsDto` / `ChurnMetricsWithAuthorsDto` |
| `CommitVelocityHeuristic` | `CommitVelocityDto` |
| `MegaCommitsHeuristic` | `List<String>` |
| `SuspiciousCommitsHeuristic` | `List<String>` |
| `ComplianceScanner` | `ComplianceReportDto` |
| `DependencyManifestParser` | `DependencyManifestDto` |
| `SecretsScanner` | `List<String>` |
| `DartAstAnalyzer` | `AstAnalysisResult` |

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  rw_git: ^3.1.0
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

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for
details on filing issues, proposing features, setting up a development
environment, and our pull request workflow.

## License

`rw_git` is released under the [MIT License](LICENSE). See
[CHANGELOG.md](CHANGELOG.md) for release history.

## Additional information

Please file any issues on the 
[github issue tracker](https://github.com/gbrandtio/rw-git/issues).
