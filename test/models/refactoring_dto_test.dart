import 'package:test/test.dart';
import 'package:rw_git/src/models/refactoring_dto.dart';

void main() {
  test('RefactoringDto toJson', () {
    final dto = RefactoringDto(
        commitHash: 'a',
        author: 'b',
        date: 'c',
        message: 'd',
        renamedFiles: [],
        linesInserted: 1,
        linesDeleted: 1,
        isSimplification: false);
    expect(dto.toJson(), isNotNull);
  });
}
