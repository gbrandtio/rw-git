# 0004 — Abstract process execution behind `ProcessRunner`, execute without a shell

- **Status**: Accepted
- **Date**: 2026-07-01
- **Deciders**: rw_git maintainers
- **Governing documents**: [`SECURITY.md`](../SECURITY.md),
  [`ERROR_HANDLING.md`](../ERROR_HANDLING.md), [`CODING_STANDARDS.md`](../CODING_STANDARDS.md)

## Context

`rw_git` is a system-level tool that drives the `git` executable. Two forces
shape how it must invoke processes:

1. **Security.** OS command injection is the primary risk for a CLI wrapper
   (`SECURITY.md` §1). If user- or model-supplied input reaches a shell, strings
   like `main; rm -rf /` become executable.
2. **Testability.** `AGENTS.md` mandates 100% coverage and forbids running real
   `git` in tests ("Use mocked `ProcessRunner` interfaces or create temporary,
   isolated test repositories"). Calling `Process.run` directly from every
   command would make deterministic unit testing impossible.

## Decision

Route **all** OS process execution through a single `ProcessRunner` abstraction,
and never invoke a shell.

- **Dependency Inversion.** High-level code (the `RwGit` facade, every
  `GitCommand`, every MCP tool) depends on the abstract `ProcessRunner`
  interface, not on `Process.run` (`CODING_STANDARDS.md` §3 — DIP). A Factory
  exposes `ProcessRunner.defaultRunner()` (the production
  `StandardProcessRunner`) and a mock variant for tests.
- **Shell-less execution.** The standard runner invokes `git` with
  `runInShell: false` and passes **arguments as a list**, never a concatenated
  command string (`SECURITY.md` Rules 1 & 2). The OS treats each argument as a
  literal, so shell metacharacters have no meaning.
- **Argument hardening.** Inputs that could be misread as flags are guarded with
  the `--` end-of-options convention and validated before use (`SECURITY.md`
  Rule 3), preventing flag injection (e.g. a branch name beginning with `-`).
- **Typed error boundary.** The runner evaluates every `ProcessResult`: a
  non-zero exit code is wrapped in a strongly-typed `RwGitException` carrying the
  exit code and `stderr`; a failure to even launch `git` is caught as a
  `ProcessException` and surfaced as a distinct executable-not-found error
  (`ERROR_HANDLING.md` §2–4). Errors are never swallowed.

## Consequences

- **Positive**: command injection via arguments is structurally impossible on the
  standard runner — there is no shell to interpret metacharacters.
- **Positive**: every command and tool is unit-testable by injecting a
  `MockProcessRunner` that yields controlled stdout/stderr/exit codes, which is
  how the 100% coverage requirement is met without touching a real repository.
- **Positive**: a single, consistent error-translation point means consumers can
  `catch (RwGitException)` for all git failures, with the original exit code and
  `stderr` preserved.
- **Constraint (business rule)**: the abstraction is intentionally *not* a
  general command executor. Per `AGENTS.md` → *Non-Intrusiveness*, the runner is
  only ever handed `git` with vetted arguments; the library exposes no
  `execute_command`-style surface and no remote-mutating operations.
- **Negative**: the `--` / no-shell discipline means genuinely shell-dependent
  invocations (e.g. a Windows `.bat`) are not supported by the standard runner.
  This is an accepted limitation, not a bug.
