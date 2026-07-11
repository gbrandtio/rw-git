/// logical_coupling_dto.dart
class LogicalCouplingDto {
  final String fileA;
  final String fileB;
  final int coChangeCount;
  final double
  confidence; // optional: how often A changes when B changes (or vice versa)

  LogicalCouplingDto({
    required this.fileA,
    required this.fileB,
    required this.coChangeCount,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'file_a': fileA,
      'file_b': fileB,
      'co_change_count': coChangeCount,
      'confidence_percentage': (confidence * 100).toStringAsFixed(2),
    };
  }
}
