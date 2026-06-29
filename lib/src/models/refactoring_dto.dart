/// refactoring_dto.dart
class RefactoringDto {
  final String commitHash;
  final String date;
  final String author;
  final String message;
  final List<String> renamedFiles;
  final int linesInserted;
  final int linesDeleted;
  final bool
      isSimplification; // True if significantly more lines deleted than inserted

  RefactoringDto({
    required this.commitHash,
    required this.date,
    required this.author,
    required this.message,
    required this.renamedFiles,
    required this.linesInserted,
    required this.linesDeleted,
    required this.isSimplification,
  });

  Map<String, dynamic> toJson() {
    return {
      'commit_hash': commitHash,
      'date': date,
      'author': author,
      'message': message,
      'renamed_files': renamedFiles,
      'lines_inserted': linesInserted,
      'lines_deleted': linesDeleted,
      'is_simplification': isSimplification,
    };
  }
}
