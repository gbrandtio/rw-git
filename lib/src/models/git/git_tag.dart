/// ----------------------------------------------------------------------------
/// git_tag.dart
/// ----------------------------------------------------------------------------
/// Represents a Git tag.
class GitTag {
  final String name;

  const GitTag({
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
      };
}
