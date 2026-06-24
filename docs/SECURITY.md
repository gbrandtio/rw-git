# Secure Dart Code Best Practices

This document outlines the essential security standards and best practices required when contributing to the `rw_git` package. Given that `rw_git` is a system-level tool that interacts directly with the host operating system via shell commands, security is paramount.

## 1. OS Command Execution Security

The most significant security risk in a wrapper package like `rw_git` is **OS Command Injection**. If user-supplied input is improperly passed to the system shell, malicious users can execute arbitrary commands on the host machine.

### Rule 1: Never Use Shell Execution (Unless Absolutely Necessary)
By default, Dart's `Process.run()` and `Process.start()` take a `runInShell` parameter. **This must almost always be set to `false` (the default).**
- **Why?**: When `runInShell: true`, the OS passes the entire command string to a shell (like `bash` or `cmd.exe`). Shells interpret special characters (like `|`, `&&`, `;`, `$`), which opens the door for command injection.
- **When is it allowed?**: Only if executing a `.bat` or `.cmd` file on Windows, which technically requires a shell.

### Rule 2: Pass Arguments as a List, Not a Concatenated String
Never manually concatenate a string to build a command. Always use the `arguments` list provided by `Process.run`.
```dart
// EXTREMELY DANGEROUS: Susceptible to command injection if 'branchName' is 'main; rm -rf /'
Process.run('git checkout $branchName', [], runInShell: true);

// SECURE: The OS treats the arguments as literal strings, not executable commands.
Process.run('git', ['checkout', branchName], runInShell: false);
```

### Rule 3: Rigorous Parameter Sanitization
Even when `runInShell` is false, malicious flags could be passed. If an attacker passes `--exec=...` as a branch name, `git` might try to execute it.
- Validate input parameters before passing them to the process.
- If a parameter represents a file path or branch name, ensure it doesn't start with a hyphen `-` to prevent flag injection.
- Alternatively, use the double dash `--` convention to signal the end of command options.
  ```dart
  // SECURE: Git knows everything after '--' is a path or branch, not a flag.
  Process.run('git', ['checkout', '--', branchName]);
  ```

---

## 2. Secure File System Operations

When interacting with the file system (e.g., initializing a repo, cloning, reading configs), we must prevent path traversal and ensure we are acting within the expected boundaries.

### Preventing Path Traversal
If a user specifies a directory to clone into, ensure they cannot use `../` to break out of the intended working directory and overwrite sensitive files.
- Always `normalize()` paths using the `path` package.
- Verify that the resolved absolute path still resides within the expected base directory.

### Secure File Permissions
When creating files (if applicable in `rw_git`), be mindful of the default permissions. Avoid making files world-writable unless strictly necessary.

---

## 3. General Secure Dart Code Practices

### Avoid Exposing Sensitive Information
- If the git command fails, the `stderr` might contain sensitive repository URLs, usernames, or access tokens (especially in clone/push errors).
- Before throwing an exception or printing logs, sanitize the output to strip out obvious credentials (e.g., regex matching `https://user:password@github.com`).

### Dependency Security
- Periodically run `dart pub outdated` and audit dependencies.
- Pin dependency versions securely. Do not use extremely loose version constraints that might automatically pull in an compromised update.

### Immutability
- Strive to make data structures immutable (`final` fields, `const` constructors). Immutable objects are inherently thread-safe and less susceptible to state-tampering bugs.
