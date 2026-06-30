# rw_git Examples

This directory contains examples demonstrating how to use the `rw_git` package.

## 1. Basic Git Operations

The [rw_git_example.dart](rw_git_example.dart) example demonstrates core Git operations such as:
* Cloning a repository
* Checking branches and current checkout status
* Listing files and checking local modifications (working directory status)
* Retrieving HEAD commit details
* Fetching and diffing tags
* Retrieving lines of code changed (insertions/deletions) and changed file statistics between tags

To run this example:
```bash
dart run example/rw_git_example.dart
```

---

## 2. Repository Intelligence

The [rw_git_intelligence_example.dart](rw_git_intelligence_example.dart) example demonstrates advanced system-level analysis, intelligence algorithms, and heuristics:
* **Architecture**: Calculates bus factor, top contributors, logical coupling (files changing together), and refactoring/renaming detection.
* **History & Algorithms**: Runs the SZZ algorithm to link bug-fixing commits back to bug-introducing commits, and measures code volatility.
* **History Heuristics**: Evaluates file complexity, bug hotspots, churn metric tracking, commit velocity, merge conflict risks, mega commits, and suspicious/low-quality commit message flags.
* **Security Scanners**: Scans for compliance issues (non-conventional commits, unsigned commits), parses dependency manifests to detect version-pinning status, and scans repository history for secrets (credentials/keys).
* **Static Analysis**: Analyzes Dart AST structures to extract public API signatures, imports, and method invocations.

To run this example:
```bash
dart run example/rw_git_intelligence_example.dart
```
