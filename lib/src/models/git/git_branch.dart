/// ----------------------------------------------------------------------------
/// git_branch.dart
/// ----------------------------------------------------------------------------
/// Represents a Git branch.
class GitBranch {
  final String name;
  final bool isCurrent;

  const GitBranch({required this.name, this.isCurrent = false});

  Map<String, dynamic> toJson() => {'name': name, 'isCurrent': isCurrent};
}
