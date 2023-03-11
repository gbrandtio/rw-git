/// ----------------------------------------------------------------------------
/// short_stat_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the output of the git --shortstat command.
class ShortStatDto {
  int numberOfChangedFiles;
  int deletions;
  int insertions;

  ShortStatDto(this.numberOfChangedFiles, this.insertions, this.deletions);
}