/// ----------------------------------------------------------------------------
/// short_log_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the output of the git shortstat -s command.
class ShortLogDto {
  final int numberOfContributions;
  final String authorName;

  const ShortLogDto(this.numberOfContributions, this.authorName);
}
