# Coding Standards & Clean Code

This document outlines the coding standards, clean code practices, SOLID principles, and design patterns that must be adhered to when contributing to the `rw_git` Dart package.

## 1. Effective Dart: Style and Best Practices

We strictly adhere to the official [Effective Dart](https://dart.dev/effective-dart) guidelines. 

### Identifiers
- **DO** use `UpperCamelCase` for types (classes, enums, typedefs, type parameters).
- **DO** use `lowercase_with_underscores` for libraries, packages, directories, and source files.
- **DO** use `lowerCamelCase` for constant names, variables, parameters, and named parameters.
- **DO** capitalize acronyms and abbreviations longer than two letters like words (e.g., `Http` instead of `HTTP`, but `ID` and `TV`).
- **PREFER** using wildcards `_` for unused callback parameters.
- **DON'T** use a leading underscore for identifiers that aren't private.

### Formatting
- **DO** format your code using `dart format --line-length=80 .`. This is strictly enforced by CI.
- **PREFER** lines of 80 characters or fewer.
- **DO** use curly braces for all flow control statements to prevent dangling `else` bugs.

### Strict Typing
- **NEVER** use `dynamic`. Always use strong typing. If the type is truly unknown, use `Object?` and perform type checking (`is`) before using it.
- **DO** use the `Result<T>` pattern for operations that can fail, rather than throwing exceptions for expected control flow.

---

## 2. Clean Code Guidelines

Clean code is readable, maintainable, and predictable.

### Naming
- **Variables**: Use intention-revealing names. (`elapsedTimeInDays`, not `d`).
- **Functions**: Should be verbs or verb phrases (`fetchCommits`, `parseOutput`).
- **Booleans**: Should sound like true/false questions (`isInitialized`, `hasError`).

### Functions
- **Small and Focused**: Functions should do exactly one thing (Single Responsibility Principle). If a function is longer than 20 lines, consider extracting parts of it.
- **Pure Functions**: Strive for pure functions that have no side effects and always produce the same output for the same input. This makes unit testing trivial.
- **Avoid Side Effects**: Do not mutate objects passed as arguments unless absolutely necessary and documented. Return new instances instead (immutability).

### Comments
- **Explain "Why", not "What"**: Code should be self-documenting. Use comments to explain the business logic or technical constraints that aren't obvious from reading the code.
- **Never Include Prompts**: Do not include AI generation prompts or thinking processes in code comments.

---

## 3. SOLID Principles in Dart

Every architectural decision and class design must strictly conform to the SOLID principles.

### Single Responsibility Principle (SRP)
A class should have one, and only one, reason to change. 
*Example: A `GitCommandExecutor` is only responsible for running the command. A `GitOutputParser` is only responsible for transforming the raw string output into domain models.*
```dart
// GOOD: Separated responsibilities
class GitExecutor {
  Future<String> run(String command) async { ... }
}
class GitParser {
  List<Commit> parseLog(String output) { ... }
}
```

### Open/Closed Principle (OCP)
Software entities should be open for extension, but closed for modification. 
*Example: Use abstract classes (`interface class` or `abstract class`) for command strategies. Add new commands by creating new classes that implement the interface.*
```dart
// GOOD: Open for extension
abstract class GitCommand {
  Future<String> execute();
}
class FetchCommand implements GitCommand { ... }
class PullCommand implements GitCommand { ... }
```

### Liskov Substitution Principle (LSP)
Derived classes must be substitutable for their base classes without altering the correctness of the program.
*Example: If a function expects a `GitResult`, any subclass of `GitResult` (like `GitSuccess` or `GitFailure`) must behave correctly without requiring `is` checks to avoid crashes or throwing unexpected exceptions.*

### Interface Segregation Principle (ISP)
Make fine-grained interfaces that are client-specific. Do not force classes to implement methods they don't use.
*Example: Don't create a giant `GitService` interface with 50 methods.*
```dart
// GOOD: Segregated interfaces
abstract class BranchManager {
  Future<void> checkout(String branch);
}
abstract class RemoteManager {
  Future<void> fetch();
}
```

### Dependency Inversion Principle (DIP)
Depend on abstractions, not on concretions. High-level modules should not depend on low-level modules. Both should depend on abstractions.
*Example: The `rw_git` facade should depend on an abstract `ProcessRunner` interface, not directly on the concrete `Process.run` implementation.*
```dart
// GOOD: Depending on abstraction
class RwGit {
  final ProcessRunner _runner;
  RwGit(this._runner); // Allows injecting a MockProcessRunner
}
```

---

## 4. Generics and Design Patterns

### Generics
- Use generics to maximize code reuse and type safety.
- **DO** parameterize classes and methods to avoid `dynamic` casting. 
  ```dart
  abstract class Result<T> {}
  class Success<T> extends Result<T> { final T data; Success(this.data); }
  ```

### Key Design Patterns

#### 1. Strategy Pattern
Used extensively for different Git commands. Instead of conditional logic, encapsulate the specific command execution into its own strategy class.
```dart
abstract class GitStrategy<T> {
  Future<T> execute(String directory);
}
```

#### 2. Factory Pattern
Used to instantiate platform-specific or context-specific runners without exposing the instantiation logic to the client.
```dart
abstract class ProcessRunner {
  factory ProcessRunner.defaultRunner() => StandardProcessRunner();
  factory ProcessRunner.mock(String output) => MockProcessRunner(output);
  
  Future<ProcessResult> run(String executable, List<String> args);
}
```

#### 3. Command Pattern
Encapsulates all information needed to perform an action or trigger an event at a later time. Highly useful for building a queue of git operations that need to run sequentially.
```dart
class GitQueue {
  final List<GitCommand> _commands = [];
  void addCommand(GitCommand command) => _commands.add(command);
  Future<void> executeAll() async {
    for (final command in _commands) {
      await command.execute();
    }
  }
}
```

#### 4. Facade Pattern
The `RwGit` class acts as a facade, providing a simplified, high-level interface to a complex subsystem of git command strategies, parsers, and executors. It hides the complexity from the user.

#### 5. Builder Pattern
Useful for constructing complex commands (e.g., a `git log` with many optional flags) step-by-step.
```dart
class GitLogBuilder {
  final List<String> _args = ['log'];
  GitLogBuilder maxCount(int count) { _args.addAll(['-n', count.toString()]); return this; }
  GitLogBuilder author(String name) { _args.addAll(['--author', name]); return this; }
  List<String> build() => _args;
}
```

#### 6. Observer Pattern (Streams)
Useful for tracking the progress of long-running git operations (like `clone` or `fetch`) and emitting events.
```dart
class GitProgressTracker {
  final _controller = StreamController<double>();
  Stream<double> get progress => _controller.stream;
  
  void updateProgress(double percent) => _controller.add(percent);
  void close() => _controller.close();
}
```

#### 7. Decorator Pattern
Used to attach additional responsibilities to an object dynamically, such as adding logging or retry logic to a command.
```dart
class LoggingGitCommand implements GitCommand {
  final GitCommand _inner;
  LoggingGitCommand(this._inner);

  @override
  Future<String> execute() async {
    print('Starting command...');
    final result = await _inner.execute();
    print('Command finished.');
    return result;
  }
}
```

#### 8. Singleton Pattern (Use with Caution)
In Dart, singletons are often implemented using a private constructor and a static instance. However, prefer Dependency Injection (DIP) over Singletons to maintain testability.
```dart
// If absolutely necessary:
class GitConfig {
  static final GitConfig _instance = GitConfig._internal();
  factory GitConfig() => _instance;
  GitConfig._internal();
}
```