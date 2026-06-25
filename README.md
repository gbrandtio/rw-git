<p align="center">
  <img src="https://user-images.githubusercontent.com/72696535/226140405-3bd31f1e-8cbb-4506-99db-1f0abce7c3fe.png" style="width: 20%;" alt="Github logo"/>
</p>
<p align="center">
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/dart.yml/badge.svg" alt="Github action dart.yml badge"/>
  <img src="https://github.com/gbrandtio/rw-git/actions/workflows/coverage.yml/badge.svg" alt="Code Coverage"/>
  <a href="https://codecov.io/gh/gbrandtio/rw-git" ><img src="https://codecov.io/gh/gbrandtio/rw-git/branch/main/graph/badge.svg?token=ETZPSI51EH"/></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/license-MIT-purple.svg" alt="License: MIT"></a>
</p>

## About

`rw_git` is a robust git wrapper that facilitates the out-of-the-box execution of common git operations, provides advanced code quality heuristics via Isolates, and exposes an MCP server for AI agent integration.

Built with a focus on Security and Dependency Inversion, `rw_git` never uses `runInShell: true` and supports unit-testing via a mockable `ProcessRunner`.

<a href='https://pub.dev/documentation/rw_git/latest/rw_git/rw_git-library.html'><img src="https://img.shields.io/badge/Check-Documentation-blue?style=for-the-badge&logo=readthedocs" alt="Documentation" /></a><br>

## Features

### Core Operations (`RwGit` Facade)
- [x] `init`: Initialize a local GIT directory.
- [x] `clone`: Clone a remote repository into a local folder.
- [x] `checkout`: Checkout a GIT branch.
- [x] `fetchTags`: Retrieve a list of tags of the specified repository.
- [x] `getCommitsBetween`: Retrieve a list of commits between two given tags.
- [x] `stats`: Get the number of lines inserted, deleted, and files changed.
- [x] `contributionsByAuthor`: Returns the number of contributions for every author of the repository.
- [x] `runCommand`: Execute any arbitrary git command securely.

### Code Quality & AI Integrations
- **`CodeQualityTracker`**: Offloads heavy parsing to background `Isolate`s to compute repository health metrics, detecting "mega-commits" and suspicious messages (TODO/FIXME).

## Model Context Protocol (MCP) Server

`rw_git` ships with an embedded Model Context Protocol (MCP) server (`bin/rw_git_mcp.dart`) that allows AI agents and IDEs (like Claude Desktop, Antigravity, or Cursor) to interact directly with your git repositories. It communicates over standard I/O using JSON-RPC 2.0.

### Installation & Configuration

To use the MCP server, you can run it directly via Dart or compile it to a standalone executable:

```bash
# Run directly
dart run bin/rw_git_mcp.dart

# Or compile to a standalone executable for faster startup
dart compile exe bin/rw_git_mcp.dart -o rw_git_mcp
```

If you are configuring it for an MCP client, here are ready-to-use JSON configurations. Be sure to replace `/absolute/path/to/rw-git` with the actual path to your repository.

#### Claude Desktop
Add this to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "dart",
      "args": ["run", "/absolute/path/to/rw-git/bin/rw_git_mcp.dart"]
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
      "command": "dart",
      "args": ["run", "/absolute/path/to/rw-git/bin/rw_git_mcp.dart"]
    }
  }
}
```

#### Antigravity (AGY CLI / Web IDE)
For Google Antigravity or `agy-cli`, add this to your MCP configuration block in the agent definition:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "dart",
      "args": ["run", "/absolute/path/to/rw-git/bin/rw_git_mcp.dart"]
    }
  }
}
```

#### Gemini CLI
For Gemini CLI integrations supporting MCP plugins:
```json
{
  "mcpServers": {
    "rw_git": {
      "command": "dart",
      "args": ["run", "/absolute/path/to/rw-git/bin/rw_git_mcp.dart"]
    }
  }
}
```

### Available AI Tools

When the MCP server connects to an AI agent, it exposes the following tools:

1. **`get_rw_git_documentation`**
   - **Description**: Retrieve detailed descriptions and parameter requirements for all RwGit facade out-of-the-box operations and MCP tools.
   - **Arguments**: None.
   - **Returns**: A markdown-formatted string documenting the available commands and tools.

2. **`execute_git_command`**
   - **Description**: Allows the agent to run arbitrary git commands safely on the local file system.
   - **Arguments**: `directory` (path to the repo), `args` (array of strings, e.g., `["log", "-n", "5"]`).
   
3. **`analyze_code_quality`**
   - **Description**: Invokes the built-in `CodeQualityTracker` to scan the repository for architectural bottlenecks and technical debt. Retrieves the recent commits wrapped in a structured prompt that actively instructs the AI agent to look for bad, low-effort commit messages or commented-out code blocks left behind in the diff.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits to fetch, default 10).
   - **Returns**: A formatted report highlighting "Suspicious Commits" (containing `TODO`/`FIXME` keywords), "Mega Commits" (commits with >500 lines changed or touching >20 files), comprehensive churn metrics, and a structured AI review prompt with recent commit logs.
   
4. **`analyze_code_quality_with_authors`**
   - **Description**: Identical to `analyze_code_quality`, but additionally computes and formats a breakdown of which authors contributed to each high-churn file, class, and code block.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits to fetch, default 10).
   - **Returns**: A formatted report highlighting suspicious commits, mega commits, churn metrics broken down by contributor name, and a structured AI review prompt with recent commit logs.

## Getting started

Add the package to your `pubspec.yaml`:
```yaml
dependencies:
  rw_git: ^2.0.0
```

## Usage

### Basic Initialization
```dart
import 'package:rw_git/rw_git.dart';

RwGit rwGit = RwGit();
```

### Mocking for Tests
You can inject a `MockProcessRunner` to unit test your code without making actual git calls or hitting the file system:
```dart
final mockRunner = MockProcessRunner();
mockRunner.setMockResult('git', ['clone', 'https://...', 'dir'], 0, 'Cloned!', '');
RwGit rwGit = RwGit(runner: mockRunner);
```

### Examples

Clone a remote repository:
```dart
String localDirectoryToCloneInto = "./my-project";
await rwGit.clone(localDirectoryToCloneInto, "https://github.com/google/material-design-lite");
```

Fetch tags of a remote repository:
```dart
List<String> tags = await rwGit.fetchTags(localDirectoryToCloneInto);
print("Number of tags: ${tags.length}");
```

Retrieve the commits between two tags:
```dart
List<String> commits = await rwGit.getCommitsBetween(localDirectoryToCloneInto, oldTag, newTag);
print("Number of commits between $oldTag and $newTag: ${commits.length}");
```

Retrieve code-change statistics between two tags:
```dart
ShortStatDto shortStatDto = await rwGit.stats(localDirectoryToCloneInto, oldTag, newTag);
print('Insertions: ${shortStatDto.insertions}, Deletions: ${shortStatDto.deletions}, Files Changed: ${shortStatDto.numberOfChangedFiles}');
```

Run an arbitrary Git command:
```dart
String logOutput = await rwGit.runCommand(localDirectoryToCloneInto, ['log', '-n', '5', '--oneline']);
print(logOutput);
```

### Streaming Output
You can opt-in to streaming the standard output and standard error of any Git command directly to the console in real-time by passing `streamOutput: true`. This is especially useful for long-running operations like clones or fetching large repositories:

```dart
await rwGit.clone(localDirectoryToCloneInto, "https://github.com/google/flutter", streamOutput: true);
```

### Exception Handling
`rw_git` strictly enforces type-safe exception handling. It will **never** silently swallow an execution error. All non-zero exit codes throw a `RwGitException` (or a subclass like `GitBranchNotFoundException`) that exposes the underlying `stderr` output.

```dart
try {
  await rwGit.checkout(localDirectoryToCloneInto, 'invalid-branch');
} on RwGitException catch (e) {
  print("Failed to checkout branch. Exit code: ${e.exitCode}, Stderr: ${e.stderr}");
}
```

## Additional information

Please file any issues on the [github issue tracker](https://github.com/gbrandtio/rw-git/issues).
