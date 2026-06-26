/// ----------------------------------------------------------------------------
/// short_stat_dto.dart
/// ----------------------------------------------------------------------------
/// A model representation of the output of the git --shortstat command.
class ShortStatDto {
  final int numberOfChangedFiles;
  final int deletions;
  final int insertions;

  const ShortStatDto(
      this.numberOfChangedFiles, this.insertions, this.deletions);
  const ShortStatDto.defaultStats()
      : numberOfChangedFiles = -1,
        deletions = -1,
        insertions = -1;
}
