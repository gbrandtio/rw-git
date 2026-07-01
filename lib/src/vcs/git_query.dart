import '../core/exceptions.dart';
import '../core/process_runner.dart';
import '../core/result.dart';

/// ----------------------------------------------------------------------------
/// git_query.dart
/// ----------------------------------------------------------------------------
/// Internal read-only git query surface for the MCP analysis tools.
///
/// Deliberately NOT part of the public [RwGit] facade and NOT exported from
/// the package: AGENTS.md forbids offering arbitrary command execution, so
/// raw git access is restricted to an allowlist of inspection subcommands.
abstract class GitQuery {
  Future<Result<String, RwGitException>> run(
      String directory, List<String> args);
}

/// [ProcessRunner]-backed implementation that refuses any git subcommand
/// capable of mutating repository, working-tree, or remote state.
class ReadOnlyGitQuery implements GitQuery {
  final ProcessRunner runner;

  ReadOnlyGitQuery(this.runner);

  static const Set<String> _readOnlySubcommands = {
    'blame',
    'branch',
    'cat-file',
    'describe',
    'diff',
    'log',
    'ls-files',
    'merge-base',
    'rev-list',
    'rev-parse',
    'shortlog',
    'show',
    'status',
    'tag',
  };

  @override
  Future<Result<String, RwGitException>> run(
      String directory, List<String> args) async {
    if (args.isEmpty || !_readOnlySubcommands.contains(args.first)) {
      throw ArgumentError.value(args.join(' '), 'args',
          'Only read-only git subcommands may be executed');
    }

    final result =
        await runner.run('git', args, workingDirectory: directory);
    try {
      evaluateProcessResult(result);
    } on RwGitException catch (e) {
      return Failure(e);
    }
    return Success(result.stdout?.toString() ?? '');
  }
}
