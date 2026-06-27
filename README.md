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

Built with a focus on Security and Dependency Inversion, `rw_git` never uses `runInShell: true` and supports unit-testing via a mockable `ProcessRunner`. It now natively supports abstracting the Git execution layer, laying the foundation for mobile support via `libgit2` FFI.

<a href='https://pub.dev/documentation/rw_git/latest/rw_git/rw_git-library.html'><img src="https://img.shields.io/badge/Check-Documentation-blue?style=for-the-badge&logo=readthedocs" alt="Documentation" /></a><br>

## Features

### Core Operations (`RwGit` Facade)
- [x] `init`: Initialize a local GIT directory.
- [x] `clone`: Clone a remote repository into a local folder.
- [x] `checkout`: Checkout a GIT branch.
- [x] `branch`: Create, list, or delete branches.
- [x] `status`: Check the status of the repository.
- [x] `pull`: Fetch from and integrate with another repository or a local branch.
- [x] `push`: Update remote refs along with associated objects.
- [x] `diff`: Show changes between commits, commit and working tree, etc.
- [x] `merge`: Join two or more development histories together.
- [x] `stash`: Stash the changes in a dirty working directory away.
- [x] `blame`: Show what revision and author last modified each line of a file.
- [x] `show`: Show various types of objects.
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

To use the MCP server, you have several distribution options:

#### 1. Pre-compiled Native Binaries (Recommended)
You can download standalone, pre-compiled executables for Windows, macOS, and Linux from the [GitHub Releases](https://github.com/gbrandtio/rw-git/releases) page. These do not require the Dart SDK to be installed.

#### 2. Via pub.dev
If you have the Dart SDK installed, you can activate the MCP server globally:
```bash
dart pub global activate rw_git
```
Then, you can run it simply using the `rw_git_mcp` command.

#### 3. Compile from source
```bash
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
   - **Description**: Invokes the built-in `CodeQualityTracker` to scan the repository for architectural bottlenecks and technical debt. Retrieves the recent commits wrapped in a structured prompt that actively instructs the AI agent to look for bad, low-effort commit messages and assesses change sizes via the `--stat` summary.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits to fetch, default 10).
   - **Returns**: A formatted report highlighting "Suspicious Commits" (containing `TODO`/`FIXME` keywords), "Mega Commits" (commits with >500 lines changed or touching >20 files), comprehensive churn metrics, and a structured AI review prompt with recent commit logs.
   
4. **`analyze_code_quality_with_authors`**
   - **Description**: Identical to `analyze_code_quality`, but additionally computes and formats a breakdown of which authors contributed to each high-churn file, class, and code block.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits to fetch, default 10).
   - **Returns**: A formatted report highlighting suspicious commits, mega commits, churn metrics broken down by contributor name, and a structured AI review prompt with recent commit logs.

5. **`analyze_release_delta`**
   - **Description**: Analyzes the changes between two releases (tags or commits) to identify major architectural shifts, new features, bug fixes, and potential stability risks.
   - **Arguments**: `directory` (path to the repo), `oldVersion` (old tag/hash), `newVersion` (new tag/hash).
   - **Returns**: A formatted string describing the changes.

6. **`analyze_bus_factor`**
   - **Description**: Calculates the "bus factor" by identifying high-risk files where a single author is responsible for a large percentage of the changes.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits).
   - **Returns**: A formatted string listing high-risk files.

7. **`evaluate_comment_llm_generation`**
   - **Description**: Evaluates whether the comments added or modified in the recent commits were likely generated by an LLM.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits).
   - **Returns**: A formatted report highlighting comments that exhibit signs of being LLM generated.

8. **`evaluate_comment_quality`**
   - **Description**: Evaluates whether the comments added or modified in the recent commits are of good quality and follow clean code practices.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits).
   - **Returns**: A formatted report analyzing the quality of the recent comments.

9. **`evaluate_comment_necessity`**
   - **Description**: Evaluates whether the comments added or modified in the recent commits are actually needed, or if the code should be refactored to be self-documenting.
   - **Arguments**: `directory` (path to the repo), `limit` (number of commits).
   - **Returns**: A formatted report advising on whether recent comments are necessary or redundant.

10. **`detect_secrets_in_commits`**
    - **Description**: Scans commit history (deltas) using Isolates for exposed secrets, API keys, or credentials without blocking the main event loop.
    - **Arguments**: `directory` (path to the repo), `limit` (optional, number of commits), `branch` (optional, branch name).
    - **Returns**: A formatted string listing detected secrets (redacted) along with their commit hashes and files.

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

### Exception Handling & Result Pattern
`rw_git` strictly enforces type-safe exception handling via the `Result<T, E>` pattern. It will **never** silently swallow an execution error. All non-zero exit codes return a `Result.failure` containing an `RwGitException` (or a subclass like `GitBranchNotFoundException`) that exposes the underlying `stderr` output. You can elegantly handle success and failure paths or extract the value using `.getOrThrow()`.

```dart
final result = await rwGit.checkout(localDirectoryToCloneInto, 'invalid-branch');
result.fold(
  (success) => print("Checkout successful!"),
  (error) => print("Failed to checkout branch. Exit code: ${error.exitCode}, Stderr: ${error.stderr}"),
);

// Or throw if you prefer try/catch:
try {
  await rwGit.checkout(localDirectoryToCloneInto, 'invalid-branch').then((r) => r.getOrThrow());
} on RwGitException catch (e) {
  print("Caught error: ${e.message}");
}
```

## Additional information

Please file any issues on the [github issue tracker](https://github.com/gbrandtio/rw-git/issues).
