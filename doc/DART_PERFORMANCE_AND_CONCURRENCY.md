# Dart Performance & Concurrency Standards

This document establishes the industry standards for high-performance Dart code, asynchronous programming, and concurrency (multi-threading via Isolates) for the `rw_git` package.

## 1. High-Performance Dart Best Practices

### Memory Management and Object Allocation
- **Avoid Unnecessary Allocations**: In performance-critical loops (e.g., parsing massive `git log` outputs), minimize object instantiations. Reuse objects where possible.
- **Use `const` Constructors**: Whenever a class or widget can be immutable, provide a `const` constructor. Instantiate with `const` to allow Dart to canonicalize the instance at compile time, saving memory and avoiding garbage collection overhead.
- **Efficient String Concatenation**: When building large strings (e.g., buffering stderr or stdout), use `StringBuffer` rather than the `+` operator or repetitive string interpolation.
  ```dart
  // GOOD
  final buffer = StringBuffer();
  buffer.writeln('First line');
  buffer.writeln('Second line');
  
  // BAD
  String output = 'First line\n';
  output += 'Second line\n';
  ```
- **List Iteration**: Use standard `for` loops or `for-in` for performance-critical iterations. `forEach` incurs a slight closure overhead.

### Collections
- Prefer strong typing in collections (`List<String>` rather than `List<dynamic>`).
- If a collection's size is known in advance, pre-allocate it or avoid dynamic resizing where possible.

---

## 2. Asynchronous Programming Industry Standards

Dart is fundamentally single-threaded in its main execution context, utilizing an Event Loop for asynchronous operations.

### Optimal Use of `async`/`await`
- **Use `await` explicitly**: Always `await` Futures. Avoid "fire-and-forget" asynchronous calls unless explicitly documented as intentional background tasks.
- **Return Futures without `async` when possible**: If a function simply returns the result of another Future, do not mark it as `async`. This avoids wrapping the Future in another unnecessary Future and saves Event Loop ticks.
  ```dart
  // GOOD
  Future<int> fetchNumber() => _db.getNumber();
  
  // BAD
  Future<int> fetchNumber() async {
    return await _db.getNumber();
  }
  ```
- **Concurrent Awaits**: If multiple independent asynchronous operations need to occur, run them concurrently using `Future.wait()` rather than awaiting them sequentially.
  ```dart
  // GOOD
  final results = await Future.wait([
    fetchBranches(),
    fetchTags(),
  ]);
  
  // BAD
  final branches = await fetchBranches();
  final tags = await fetchTags();
  ```

### Streams
- Use `Stream` for handling chunks of data over time, such as processing continuous standard output from long-running `git` processes.
- **Backpressure & Transformation**: Use `StreamTransformers` to filter or manipulate data streams without loading the entire dataset into memory.
- Always close `StreamControllers` when they are no longer needed to prevent memory leaks.

---

## 3. Concurrency and Multi-threading (Isolates)

Because Dart is single-threaded, intensive CPU operations (like parsing massive JSON outputs, applying complex regular expressions on megabytes of git logs, or encrypting large files) will block the Event Loop.

A blocked Event Loop means the application cannot process other microtasks or IO events, leading to unresponsiveness.

### Industry Standards for Isolates

To achieve true multi-threading in Dart, use **Isolates**. Isolates have their own memory heap and do not share state with the main thread. They communicate exclusively via message passing.

#### When to Use Isolates
- Parsing massive strings or deeply nested JSON structures (e.g., massive `git status` or `git log` outputs).
- Heavy cryptographic computations.
- Complex data transformations.

#### The `compute` Function (or `Isolate.run`)
For short-lived, heavy computations, use `Isolate.run()` (Dart 2.19+) or `compute` (from Flutter/foundation, though `Isolate.run` is preferred in pure Dart environments).
```dart
// Efficiently parsing a massive git log off the main thread
Future<List<Commit>> parseLargeGitLog(String rawOutput) async {
  // Spawns an isolate, runs the parsing, returns the result, and tears down the isolate.
  return await Isolate.run(() => _expensiveParsingLogic(rawOutput));
}

// Top-level or static function required for the isolate
List<Commit> _expensiveParsingLogic(String output) {
  // Heavy computation here...
}
```

#### Long-Lived Isolates
If the package requires continuous background processing (e.g., a constant stream of git events being parsed), manually manage an Isolate using `Isolate.spawn()`, setting up `ReceivePort` and `SendPort` for two-way communication. This avoids the overhead of constantly spinning up and tearing down isolates.

### Isolate Best Practices
- **Data Transfer Overhead**: Passing massive amounts of data between isolates requires copying the memory (unless using specialized shared memory). Ensure that the computational cost saved by moving work off the main thread outweighs the cost of copying the data across the isolate boundary.
- **Stateless Workers**: Ensure isolate entry point functions are pure or stateless, as they cannot access variables from the main isolate's heap.
