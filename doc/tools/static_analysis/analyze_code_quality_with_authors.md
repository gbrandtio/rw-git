# analyze_code_quality_with_authors

## Business Logic

Answers: "What SOLID principle violations are accumulating, and which developers own them?" Identical in scope to `analyze_code_quality` but adds per-author attribution to every metric. Enables targeted mentoring, knowledge-transfer planning, and evidence-based ownership decisions — without being punitive.

## Algorithm

Extends `BaseAnalyzeCodeQualityTool` with author-enriched variants of each heuristic:

- **SuspiciousCommitsHeuristic** — already includes author per commit (same as base)
- **MegaCommitsHeuristic** — already includes author per commit (same as base)
- **ChurnHeuristic with authors:** For each changed file in each commit, accumulate `{file → {author → count}}` in addition to the aggregate `{file → count}`. Returns the top-N most frequent committer per file alongside the churn rank.
- **AdvancedMetricsHeuristic with authors:** Co-change matrix entries include the set of authors whose commits contributed to the co-change count.

Output: all metrics from `analyze_code_quality` plus, for each churn entity, a `per_author` breakdown of change count and percentage.

## Algorithm Foundations

Shares all algorithms with `analyze_code_quality`. See that document for the full algorithmic description (FSM churn streaming, co-change matrix, method-level hunk parsing, mega-commit thresholds).

## Academic Foundation

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

### Martin (2000) — *Design Principles and Design Patterns*

**Published in:** Addison-Wesley

**Key claim:** Single Responsibility Principle violations — classes or modules that are changed by many different people for many different reasons — are identifiable from commit history. A module that is touched by developers from three different teams (UI, data, platform) for three different reasons is almost certainly doing more than one thing.

**How rw-git uses it:** The per-author dimension of the co-change matrix reveals cross-team coupling: if a file's co-change partners are modified by different author groups, the file is likely a shared boundary violating SRP. This is the author-augmented version of the architectural drift signal.
