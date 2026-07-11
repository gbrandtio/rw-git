import 'package:rw_git/src/mcp/utils/json_structure_preview.dart';
import 'package:test/test.dart';

void main() {
  group('buildJsonStructurePreview', () {
    test(
        'maps each top-level key exactly once to a compact type tag, so the '
        'inline preview cost stays one entry per key', () {
      final preview = buildJsonStructurePreview({
        'findings': [1, 2, 3],
        'summary': {'critical': 1},
        'generated_at': '2026-07-02',
        'total': 42,
      });

      expect(preview.keys, equals(['structure']));
      final structure = preview['structure'] as Map<String, String>;
      expect(structure['findings'], equals('array(3)'));
      expect(structure['summary'], equals('object'));
      expect(structure['generated_at'], equals('String'));
      expect(structure['total'], equals('int'));
    });

    test('describes a top-level array by type and length', () {
      final preview = buildJsonStructurePreview([1, 2]);

      expect(preview['top_level_type'], equals('array'));
      expect(preview['length'], equals(2));
    });

    test('describes a scalar root by its runtime type', () {
      expect(
        buildJsonStructurePreview('text')['top_level_type'],
        equals('String'),
      );
      expect(buildJsonStructurePreview(null)['top_level_type'], equals('Null'));
    });

    test(
      'stringifies non-string map keys so the preview stays serializable',
      () {
        final preview = buildJsonStructurePreview({1: 'a'});

        final structure = preview['structure'] as Map<String, String>;
        expect(structure['1'], equals('String'));
      },
    );
  });
}
