# RwGit Architecture

This document describes the refactored architecture of the `rw_git` package, adhering to the project's coding standards.

## 1. Core Principles

- **Separation of Concerns**: Parsing, execution, and strategy logic are strictly decoupled.
- **Security by Default**: All OS process execution is done without a shell (`runInShell: false`) to prevent command injection, adhering to `SECURITY.md`.
- **Concurrency**: High-cpu/blocking tasks, such as regex parsing and log processing, are offloaded to background threads using Dart's `Isolate.run()`, ensuring the main event loop remains responsive as per `DART_PERFORMANCE_AND_CONCURRENCY.md`.
- **Testability**: Process execution is abstracted behind a `ProcessRunner` interface, enabling deterministic unit testing via `MockProcessRunner`.

## 2. Components

### 2.1 Facade (`RwGit`)
The `RwGit` class serves as the primary entry point for consumers. It is a Facade that provides a simplified, high-level API over complex Git commands. It delegates actual work to specific Command Strategy implementations.

### 2.2 Process Runner (`ProcessRunner`)
Instead of calling `Process.run` directly everywhere, `rw_git` uses a `ProcessRunner` interface.
- **`StandardProcessRunner`**: The default implementation for production. It safely executes standard OS processes and parses exit codes.
- **`MockProcessRunner`**: Used for unit tests. It allows developers to mock standard output, standard error, and exit codes for specific commands.

### 2.3 Command Strategies (`GitCommand<T>`)
Every Git operation is implemented as an encapsulated strategy extending `GitCommand<T>`. This allows the addition of new commands without modifying the core facade. Examples include:
- `CloneCommand`
- `StatsCommand`
- `FetchTagsCommand`

### 2.4 Code Quality Tracker (`CodeQualityTracker`)
A specialized subsystem that runs complex heuristics on repositories to flag code quality issues.
- Relies heavily on **Isolates** to process massive git diffs and logs without hanging the UI or parent applications.
- Supports detecting "Mega-Commits" (excessive insertions/deletions) and suspicious commits (containing keywords like `TODO`, `FIXME`, or commented-out code blocks).

### 2.5 MCP Server (`bin/rw_git_mcp.dart`)
An implementation of the Model Context Protocol (MCP) using a standard I/O JSON-RPC loop.
- Allows AI Agents to consume `rw_git`'s capabilities dynamically via the `analyze_code_quality` and `retrieve_commits_for_ai_review` tools.
- Runs as an independent script that binds to standard input and output streams.

## 3. Error Handling
Following `ERROR_HANDLING.md`:
- Git execution errors are never swallowed. 
- If a `ProcessResult` yields a non-zero exit code, a strongly-typed `RwGitException` is thrown, encapsulating the underlying exit code and standard error output.
- Clients are expected to handle `RwGitException` appropriately depending on their use cases.
