/// json_structure_preview.dart
/// Builds a shallow, schema-agnostic structural index of a decoded JSON value
/// so an LLM can target reads (e.g. via `read_report_slice`) without loading
/// the whole document into context.
///
/// For a JSON object the index is a single `structure` map from each top-level
/// key to a compact type tag: `array(<length>)`, `object`, or the scalar
/// runtime type. A single map keeps the recurring inline token cost of every
/// offload summary minimal — one entry per key instead of repeating each key
/// across parallel maps.
Map<String, dynamic> buildJsonStructurePreview(dynamic decoded) {
  if (decoded is Map) {
    final structure = <String, String>{};
    decoded.forEach((key, value) {
      final structureKey = key.toString();
      if (value is List) {
        structure[structureKey] = 'array(${value.length})';
      } else if (value is Map) {
        structure[structureKey] = 'object';
      } else {
        structure[structureKey] = value.runtimeType.toString();
      }
    });
    return {'structure': structure};
  } else if (decoded is List) {
    return {'top_level_type': 'array', 'length': decoded.length};
  }
  return {'top_level_type': decoded.runtimeType.toString()};
}
