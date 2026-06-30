# checkout_branch

## Business Logic

Switch the working tree of an already-cloned repository to a specific branch. Required before file-level static analysis (AST parsing, lexical metrics) on a feature branch, because the analyser reads files from the working tree — not from git's object store directly.

## Algorithm

Executes `git checkout <branch>`. This is a non-destructive, non-network operation from the analysis perspective. It updates HEAD and the working tree to the named branch's tip.

## Academic Foundation

No dedicated academic paper applies to this primitive. Its role is as an enabler for the static analysis tools that follow. The design decision to work from the filesystem (rather than reading blobs directly from git's object store) reflects a practical constraint of language parsers like `dart:analyzer`, which expect a file path on disk.

### Tsantalis et al. (2018) — *Accurate and Efficient Refactoring Detection in Commit History* (RefactoringMiner)

**Published in:** ICSE, ACM/IEEE

**Key claim:** AST-level analysis of changed files requires the file content to be accessible as a local path, not just as a git diff patch. RefactoringMiner checks out commits to compare full file ASTs.

**How rw-git uses it:** `checkout_branch` ensures that `analyze_dart_ast_quality` can pass an absolute file path to `dart:analyzer`'s `parseString()` — the analyser requires a resolvable file URI, not a raw string extracted from a diff.
