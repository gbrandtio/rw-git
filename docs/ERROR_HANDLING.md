# Error Handling Architecture

This document describes the unified error handling architecture for the `rw_git` Dart package, focusing on how we intercept, parse, and bubble up operating system-level execution errors to the consumer of the package in a safe, strongly-typed manner.

## 1. Core Principles

- **Never Swallow Errors Silently**: An unhandled or swallowed error in a system CLI wrapper leads to inconsistent state and frustrated developers.
- **Strong Typing**: We do not throw raw `String` messages or generic `Exception`s. All execution errors must be wrapped in a strongly-typed custom exception hierarchy.
- **Preserve Context**: Always retain the original exit code and standard error output (`stderr`) from the OS process.

---

## 2. ProcessResult Evaluation

When executing a command using `Process.run`, Dart returns a `ProcessResult` object. The `rw_git` package must diligently evaluate this object before assuming success.

### Evaluating Exit Codes
By Unix/POSIX standards, a process that completes successfully returns an exit code of `0`. Any non-zero exit code indicates an error.

```dart
final result = await Process.run('git', ['checkout', 'main']);

if (result.exitCode != 0) {
  // An error occurred! We must handle it.
  throw RwGitException(
    message: 'Git checkout failed.',
    exitCode: result.exitCode,
    stderr: result.stderr.toString(),
  );
}

// Proceed with parsing stdout
```

---

## 3. Custom Exception Hierarchy

To provide predictable behavior for developers using `rw_git`, we maintain a custom exception hierarchy.

### The Base Exception: `RwGitException`
All custom exceptions thrown by this package must implement or extend the base `RwGitException`. This allows consumers to catch all git-related errors easily:
```dart
try {
  await rwGit.checkout('invalid-branch');
} on RwGitException catch (e) {
  print('Failed with exit code: ${e.exitCode}');
  print('Git says: ${e.stderr}');
}
```

### Specific Exceptions
For common, recognizable errors, we should parse the `stderr` string and throw specific exceptions:
- `GitBranchNotFoundException`
- `GitMergeConflictException`
- `GitNotInitializedException`

Example parsing logic:
```dart
if (result.exitCode != 0) {
  final errOutput = result.stderr.toString().toLowerCase();
  
  if (errOutput.contains('did not match any file(s) known to git')) {
    throw GitBranchNotFoundException(branchName);
  } else if (errOutput.contains('not a git repository')) {
    throw GitNotInitializedException(directory);
  }
  
  // Fallback to generic exception
  throw RwGitException(message: "Command failed", exitCode: result.exitCode, stderr: errOutput);
}
```

---

## 4. Handling `ProcessException`

In addition to non-zero exit codes, the `Process.run` call itself can throw a `ProcessException`. This usually happens when the executable (`git`) is not found on the system's `PATH`, or the host OS denies execution permissions.

You **must** wrap `Process.run` calls in a `try/catch` block to handle this specifically:

```dart
try {
  final result = await Process.run('git', ['status']);
  // ... handle ProcessResult ...
} on ProcessException catch (e) {
  // Git is likely not installed or not in PATH
  throw GitExecutableNotFoundException(
    message: 'Failed to execute git. Ensure git is installed and in the system PATH.',
    originalException: e,
  );
}
```

---

## 5. Developer Best Practices

- **When to Throw**: Throw an `RwGitException` (or subclass) if the git command failed and the intended operation cannot be completed.
- **When to Return a Result Type**: If you are using functional programming paradigms (e.g., `Result<Success, Failure>`), encapsulate the error within a Failure object rather than throwing. This follows the package's `CODING_STANDARDS.md`.
- **Sanitize stderr**: Be cautious about blindly passing `stderr` to the UI or logs in the consuming application, as it may contain sensitive paths or credentials.
