/// ----------------------------------------------------------------------------
/// short_stat_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the output of the git --shortstat command.
class ShortStatDto {
  late int numberOfChangedFiles;
  late int deletions;
  late int insertions;

  ShortStatDto(this.numberOfChangedFiles, this.insertions, this.deletions);
  ShortStatDto.defaultStats() {
    numberOfChangedFiles = -1;
    deletions = -1;
    insertions = -1;
  }
}
