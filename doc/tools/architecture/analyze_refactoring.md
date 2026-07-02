# analyze_refactoring

## Business Logic

Answers: "When did the team refactor, and what did they restructure?" Tracking refactoring activity over time reveals whether technical debt is being paid down, whether refactoring is dangerously bundled with features (a risk pattern), and whether renames indicate intentional architectural evolution.

## Algorithm

**RefactoringDetectionAlgorithm** uses three complementary heuristics:

1. **Keyword detection:**
   `git log --format=%H||%s --no-merges` — match commit subjects against:
   ```
   refactor|rewrite|restructure|clean|cleanup|extract|rename|move|reorganize|simplify|decouple
   ```
   (case-insensitive)

2. **Rename detection:**
   `git log -M --name-status --no-merges` — the `-M` flag activates git's similarity-based rename detector (default threshold: 50% content similarity). Lines beginning with `R` in the name-status output indicate detected renames.

3. **Simplification ratio:**
   `git log --shortstat --no-merges` and for each commit, compute:
   ```
   simplification = deletions > 50 AND insertions < 0.2 × deletions
   ```
   Net code reduction commits (much more deletion than insertion) are classified as simplifications. This a structural refactoring signal independent of commit message language.

A commit is classified as a refactoring if any one of the three heuristics fires. Output per refactoring commit: hash, subject, detected renames, insertion/deletion counts, and trigger reason (keyword / rename / simplification).

## Academic Foundation

### Opdyke (1992) — *Refactoring Object-Oriented Frameworks* (PhD thesis)

**Published at:** University of Illinois at Urbana-Champaign

**Key claim:** Refactoring is a behaviour-preserving source code transformation. The defining property is that a refactoring changes internal structure without changing observable behaviour. This definition distinguishes refactoring from feature changes and bug fixes.

**How rw-git uses it:** The three heuristics operationalise Opdyke's definition. Keyword detection targets declared refactorings; rename detection targets structural rearrangements; simplification ratio targets behaviour-preserving code reduction. All three are proxies for the "behaviour-preserving" property without requiring test execution.

---

### Fowler (1999) — *Refactoring: Improving the Design of Existing Code*

**Published in:** Addison-Wesley

**Key claim:** The refactoring catalogue (72 named transformations in the 1st edition) provides a vocabulary for discussing structural improvements. Key transformations include *Extract Method*, *Move Method*, *Rename*, *Inline Class*, and *Replace Magic Number with Symbolic Constant*. The simplification ratio (more deletions than insertions) is characteristic of *Inline Class*, *Collapse Hierarchy*, and similar consolidation refactorings.

**How rw-git uses it:** The keyword list (`extract`, `rename`, `move`, `inline`) maps directly to Fowler's catalogue. The simplification ratio heuristic captures Fowler's consolidation refactorings that reduce total code volume.

---

### Tsantalis, Mansouri, Eshkevari, Mazinanian & Dig (2018, 2020) — *RefactoringMiner 1.0 / 2.0*

**Published in:** ICSE 2018 / ASE 2020, ACM/IEEE

**Key claim:** AST-level analysis of commit diffs (comparing full file ASTs before and after a commit) achieves 98%+ precision and 87%+ recall in detecting 40+ refactoring types. This is the current state of the art for automatic refactoring detection.

**How rw-git uses it:** The rw-git implementation uses heuristic signals (keywords, renames, deletion dominance) as a lightweight approximation of RefactoringMiner that requires no language-specific parser and works across all languages. The trade-off is lower recall (i.e., some refactorings are missed) but zero false positives from AST parser errors or unsupported language syntax.

---

### Murphy-Hill, Parnin & Black (2009) — *How We Refactor, and How We Know It*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Developers rarely refactor in isolation. 90% of refactoring activity is interleaved with feature development or bug fixing and happens in the same commit. Commits that mix refactoring with features are harder to code-review, more likely to introduce regressions, and harder to revert if a problem is discovered.

**How rw-git uses it:** By identifying which commits are refactoring-attributed, the tool enables detection of "mixed commits" i.e., commits flagged by both a feature/fix keyword and a refactoring keyword. This pattern (refactoring + feature in one commit) is the highest-risk refactoring anti-pattern.

---

### Palomba, Bavota, Di Penta, Fasano, De Lucia & Oliveto (2018) — *Refactoring Does Not Improve Code Maintainability: A Case Study*

**Published in:** MSR, IEEE

**Key claim:** Refactoring activity alone does not reliably improve maintainability metrics. Refactoring that is not accompanied by test coverage improvement or code smell removal has no measurable maintainability effect. This challenges the common assumption that refactoring = quality improvement.

**How rw-git uses it:** The refactoring timeline enables correlation analysis: engineering leaders can use the output alongside `analyze_code_quality` before/after timestamps to check whether refactoring commits are actually followed by complexity reduction and in this way validate or refute the Palomba et al. finding in their specific codebase.
