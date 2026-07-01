# analyze_code_quality

## Business Logic

Answers: "What SOLID principle violations are accumulating in this module?" Runs four complementary heuristics over commit history to surface: suspicious code patterns, scope-creep commits, unstable interfaces, co-change clusters (blast radius), and high-churn methods. Intended for module-level technical debt reviews.

With `includeAuthors: true`, it additionally answers: "Which developers own the violations?" — adding per-author attribution to every churn metric. This enables targeted mentoring, knowledge-transfer planning, and evidence-based ownership decisions — without being punitive. (This was formerly a separate `analyze_code_quality_with_authors` tool; it was folded into this tool as a parameter to shrink the tool-selection surface for small models — see [ADR-0007](../../adr/0007-tools-list-token-budget-and-pagination.md).)

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

---

### Per-author attribution (`includeAuthors: true`)

Author-enriched variants of each heuristic:

- **SuspiciousCommitsHeuristic** — already includes author per commit (same as base)
- **MegaCommitsHeuristic** — already includes author per commit (same as base)
- **ChurnHeuristic with authors:** For each changed file in each commit, accumulate `{file → {author → count}}` in addition to the aggregate `{file → count}`. Returns the top-N most frequent committer per file alongside the churn rank.
- **AdvancedMetricsHeuristic with authors:** Co-change matrix entries include the set of authors whose commits contributed to the co-change count.

Output: all base metrics plus, for each churn entity, a per-author breakdown of change count and percentage.

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

## Academic Foundation — per-author attribution (`includeAuthors: true`)

### Weyuker, Ostrand & Bell (2008) — *Do Too Many Cooks Spoil the Broth?*

**Published in:** Empirical Software Engineering, Springer

**Key claim:** The number of distinct developers who have modified a module is a significant, independent predictor of defect density — even after controlling for module size and churn. Files touched by many developers have higher defect density because of inconsistent application of conventions, implicit coupling assumptions, and diffusion of responsibility.

**How rw-git uses it:** The per-author churn breakdown surfaces the "too many cooks" signal at the file level. Engineering leaders can identify files where many authors each contribute small amounts — the pattern most associated with elevated defect density in Weyuker et al.'s study.

---

### Bird, Nagappan, Murphy, Gall & Devanbu (2011) — *Don't Touch My Code! Examining the Effects of Ownership on Software Quality*

**Published in:** FSE, ACM

**Key claim:** "Minor contributors" — developers who account for < 5% of a module's changes — are significantly associated with higher post-release defect density. Strong ownership (one developer accounting for > 75% of changes) is associated with fewer defects even for complex modules.

**How rw-git uses it:** The per-author percentage breakdown enables direct identification of minor contributors: any author with < 5% of a file's changes is a minor contributor by Bird et al.'s definition. The tool surfaces this data without requiring a threshold to be hard-coded — engineering leaders can apply the 5% rule to the returned percentages.

---

### Mockus & Herbsleb (2002) — *Expertise Browser: A Quantitative Approach to Identifying Expertise*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Author-file touch history is a valid proxy for current expertise. The author with the most recent and most frequent commits to a file is the most qualified to review changes to it. This is quantifiable from git log without human surveys.

**How rw-git uses it:** The per-author churn breakdown identifies the "de facto expert" for each high-churn file: the author with the highest commit count to that file is the best candidate for ownership assignment, regardless of what CODEOWNERS says.

---

### Martin (2000) — *Design Principles and Design Patterns* (author-augmented reading)

**Key claim:** Single Responsibility Principle violations — classes or modules that are changed by many different people for many different reasons — are identifiable from commit history. A module that is touched by developers from three different teams (UI, data, platform) for three different reasons is almost certainly doing more than one thing.

**How rw-git uses it:** The per-author dimension of the co-change matrix reveals cross-team coupling: if a file's co-change partners are modified by different author groups, the file is likely a shared boundary violating SRP. This is the author-augmented version of the architectural drift signal.
