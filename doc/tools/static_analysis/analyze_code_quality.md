# analyze_code_quality

## Business Logic

Answers: "What SOLID principle violations are accumulating in this module?" Runs four complementary heuristics over commit history to surface: suspicious code patterns, scope-creep commits, unstable interfaces, co-change clusters (blast radius), and high-churn methods. Intended for module-level technical debt reviews.

## Algorithm

**BaseAnalyzeCodeQualityTool** orchestrates four heuristics in parallel via Dart Isolates:

---

### Heuristic 1: SuspiciousCommitsHeuristic

`git log -p --format=%H||%an||%aI||%s` — extract full diff patches.

Scan commit subjects and added lines (`+` prefixed) against keyword patterns:
- Technical debt markers: `fixme|hack|workaround|kludge|temp|wip|todo`
- Security anti-patterns: `password|secret|api_key|bypass|backdoor|hardcode`
- Quality signals: `magic|duplicate|messy|spaghetti`

Each match is a "suspicious commit" entry with hash, author, date, and matched keyword.

---

### Heuristic 2: MegaCommitsHeuristic

`git log --shortstat --format=%H||%an||%aI||%s` — commit stats.

Flag commits where:
- `insertions + deletions > 500 lines` (large change volume), OR
- `files_changed > 20` (large blast radius)

Mega commits are inherently hard to review — reviewers cannot hold the full context of 500+ lines in working memory. They also frequently bundle unrelated changes, making rollback difficult.

---

### Heuristic 3: ChurnHeuristic

`git log --name-only --format=%H --no-merges` — file touch frequency.

Track `change_frequency` per file path. Return top-N most frequently changed files. High churn = unstable interface or violation of the Open-Closed Principle (OCP): a class or file should be open for extension but closed for modification. Repeated modification signals it is not closed.

---

### Heuristic 4: AdvancedMetricsHeuristic

Three sub-computations:

**Co-change matrix:** For each commit, record all pairs of changed files. Build a `(fileA, fileB) → count` map. High co-change pairs indicate hidden coupling (Blast Radius analysis, SRP violation at module level).

**Method churn:** Parse diff hunks at the function signature level — detect repeated modification to the same function body across commits. High method-level churn = Open-Closed Principle violation.

**Control-flow density:** Count `if|for|while|switch|catch` keyword occurrences in diff hunks relative to total diff lines. High density = structurally complex changes; low density = data or configuration changes.

## Academic Foundation

### Martin (2000, 2002) — *Design Principles and Design Patterns*; *Agile Software Development, Principles, Patterns, and Practices*

**Published in:** Addison-Wesley

**Key claim:** The five SOLID principles — Single Responsibility (SRP), Open-Closed (OCP), Liskov Substitution, Interface Segregation, Dependency Inversion — are the foundational design principles for maintainable object-oriented software. Violations are detectable from history: SRP violations appear as high co-change coupling; OCP violations appear as high churn on the same class.

**How rw-git uses it:** The heuristics are direct measurements of SOLID violations. Co-change matrix → SRP violations. Churn per file → OCP violations. Mega commits → SRP and OCP violations at commit scope.

---

### Mantyla & Lassenius (2006) — *Subjective Evaluation of Software Evolvability*

**Published in:** Empirical Software Engineering, Springer

**Key claim:** Code smells are subjective but correlate with objective maintenance difficulty. Keywords like FIXME, HACK, and TODO in commit messages and code comments are strong subjective signals of technical debt acknowledged by the developer at the time of introduction.

**How rw-git uses it:** SuspiciousCommitsHeuristic's keyword list directly operationalises this finding. When a developer writes `// HACK: ...` or commits with subject `fixme: workaround for...`, they are explicitly flagging debt. These explicit flags are more reliable than inferred smells.

---

### Mockus & Votta (2000) — *Identifying Reasons for Software Changes Using Historic Databases*

**Published in:** ICSM, IEEE

**Key claim:** Large changes (high insertion + deletion counts) have significantly more defects per line than small targeted changes. Review effectiveness drops rapidly as change size increases — reviewers cannot maintain the cognitive context required for large commits.

**How rw-git uses it:** MegaCommitsHeuristic's 500-line and 20-file thresholds are calibrated against this finding. Commits above these thresholds are flagged because their review quality is empirically degraded.

---

### Tornhill (2015) — *Your Code as a Crime Scene*

**Published in:** Pragmatic Bookshelf

**Key claim:** High-churn methods are the "crime scene hotspots" that resist change because they break for every new feature. A method that has been modified in every sprint for the past year is an Open-Closed Principle violation in practice: it is not "closed for modification" even though its interface may be stable.

**How rw-git uses it:** The method churn sub-computation in AdvancedMetricsHeuristic is a direct implementation of Tornhill's hotspot concept, extended to the method level (rather than file level).

---

### D'Ambros, Lanza & Robbes (2009) — *An Extensive Comparison of Bug Prediction Approaches*

**Published in:** ICSM, IEEE

**Key claim:** Logical coupling (co-change data) is one of the top-performing bug predictors. Files with high co-change counts are significantly more likely to contain defects than structurally isolated files.

**How rw-git uses it:** The co-change matrix from AdvancedMetricsHeuristic provides both a blast radius signal (how many files are implicitly coupled to any given file) and a defect risk signal (high co-change pairs correlate with future defects).
