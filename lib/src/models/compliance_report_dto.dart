// Immutable DTO for the compliance audit tool.results.

class ComplianceReportDto {
  final int totalCommitsScanned;
  final List<ComplianceViolation> unsignedCommits;
  final List<ComplianceViolation> emptyMessageCommits;
  final List<ComplianceViolation> unrecognizedAuthorCommits;

  const ComplianceReportDto({
    required this.totalCommitsScanned,
    required this.unsignedCommits,
    required this.emptyMessageCommits,
    required this.unrecognizedAuthorCommits,
  });

  int get totalViolations =>
      unsignedCommits.length +
      emptyMessageCommits.length +
      unrecognizedAuthorCommits.length;
}

class ComplianceViolation {
  final String hash;
  final String author;
  final String email;
  final String message;
  final String date;

  const ComplianceViolation({
    required this.hash,
    required this.author,
    required this.email,
    required this.message,
    required this.date,
  });
}
