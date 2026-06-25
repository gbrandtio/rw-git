## 2.2.0
- MCP: Added 10 individual, strongly-typed tools to directly invoke `RwGit` facade methods (`init_repository`, `clone_repository`, `get_stats`, etc.) to provide LLMs with perfect parameter schemas.
- MCP: Cleaned up `execute_git_command` to strictly accept raw git CLI args, preventing hallucination of facade function names.
- MCP: Transformed `get_rw_git_documentation` into a unified Agent Guide to route LLMs natively across all tools.

## 2.1.0
- Added `streamOutput` opt-in flag across all `RwGit` methods to support real-time streaming of Git standard output and standard error to the console.
- Refactored `ProcessRunner` to use `Process.start` to support seamless output streaming without blocking.
- MCP: Updated tool descriptions to include explicit invocation instructions for better LLM context.
- MCP: Improved code quality tracker outputs for suspicious and mega commits to include author, date, and commit message.

## 1.0.4
- MCP: Combined `retrieve_commits_for_ai_review` functionality into `analyze_code_quality` and `analyze_code_quality_with_authors` to provide an internal AI prompt combined with code quality metrics and recent commits for a comprehensive code review context. 
- MCP: Removed `retrieve_commits_for_ai_review`.

## 1.0.1
- Support for common git commands and operations:
  - `git init`
  - `git clone`
  - `git fetch tags`
  - Count commits between two tags
  - Retrieve statistics regarding code changes (insertions, deletions, number of files changed).

## 1.0.2
- Fixed various bugs surfaced from unit testing.
- Code coverage 100%.
- Improved performance and logical output of some commands.

## 1.0.3
- Exposing RwGitParser through the rw_git package for enhanced flexibility.
