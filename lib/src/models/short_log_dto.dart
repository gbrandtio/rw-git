/// ----------------------------------------------------------------------------
/// short_log_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the output of the git shortstat -s command.
class ShortLogDto {
  int numberOfContributions;
  String authorName;

  ShortLogDto(this.numberOfContributions, this.authorName);
}