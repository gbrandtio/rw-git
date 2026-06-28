// Immutable DTO for the compliance audit tool.results.

class ComplianceReportDto {
  final int totalCommitsScanned;
  final List<ComplianceViolation> unsignedCommits;
  final List<ComplianceViolation> emptyMessageCommits;
  final List<ComplianceViolation> unrecognizedAuthorCommits;
  final List<ComplianceViolation> nonConventionalCommits;

  const ComplianceReportDto({
    required this.totalCommitsScanned,
    required this.unsignedCommits,
    required this.emptyMessageCommits,
    required this.unrecognizedAuthorCommits,
    required this.nonConventionalCommits,
  });

  int get totalViolations =>
      unsignedCommits.length +
      emptyMessageCommits.length +
      unrecognizedAuthorCommits.length +
      nonConventionalCommits.length;
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
