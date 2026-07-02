# analyze_logical_coupling

## Business Logic

Answers: "Which files are secretly coupled even though there is no explicit import between them?" Files that always change together reveal hidden design dependencies referred to as the *Shotgun Surgery* code smell at the repository level. Informs refactoring opportunities, blast radius estimation, and identification of modules that violate the Single Responsibility Principle.

## Algorithm

**LogicalCouplingAlgorithm** mines co-change transactions:

1. `git log --name-only --format=%H --no-merges` — parse each commit as a "transaction" containing its set of changed files
2. For each pair of files (A, B) that appear in the same transaction, increment `co_change_count(A, B)` in a symmetric matrix
3. Filter pairs where `co_change_count < threshold` (default: 3 = must have co-changed at least 3 times)
4. For each surviving pair, compute **confidence** (asymmetric conditional probability):
   - `P(B|A) = co_change_count(A, B) / total_changes_to_A`
   - `P(A|B) = co_change_count(A, B) / total_changes_to_B`
   - Reported confidence = `max(P(B|A), P(A|B))`
5. Return pairs sorted descending by `co_change_count`

## Academic Foundation

### Gall, Hajek & Jazayeri (1998) — *Detection of Logical Coupling Based on Product Release History*

**Published in:** ICSM, IEEE

**Key claim:** Files that co-change across releases are logically coupled, even if no static import or call relationship exists between them. This "logical coupling" is detectable from version history and predicts which files will need to change together in future. The method was validated on industrial release histories.

**How rw-git uses it:** The co-change transaction model (commit = transaction, file pair = co-change) is a direct implementation of Gall et al.'s algorithm, adapted from release-level to commit-level granularity.

---

### Zimmermann, Zeller, Weissgerber & Diehl (2004) — *Mining Version Histories to Guide Software Changes*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Confidence scores (conditional probabilities P(B|A) and P(A|B)) make co-change data actionable for impact analysis. When a developer changes file A, files with high P(B|A) should be reviewed as likely co-changes. The paper validated this prediction mechanism on Eclipse development history.

**How rw-git uses it:** The confidence metric is taken directly from this paper. It answers: "Given that file A was changed, what is the probability that file B also needs to change?" High-confidence pairs are the most actionable output.

---

### Fowler (1999) — *Refactoring: Improving the Design of Existing Code*

**Published in:** Addison-Wesley

**Key claim:** *Shotgun Surgery* is a code smell where a single conceptual change requires modifications to many different files scattered across the codebase. It indicates that related functionality is poorly encapsulated (the concept that should be one class, is spread across many).

**How rw-git uses it:** High-confidence co-change pairs with many coupled files are the commit-history signature of Shotgun Surgery. The tool surfaces exactly the file pairs that a refactoring to address Shotgun Surgery would need to consolidate.

---

### D'Ambros, Lanza & Robbes (2009) — *An Extensive Comparison of Bug Prediction Approaches*

**Published in:** ICSM, IEEE

**Key claim:** Logical coupling is one of the strongest standalone bug predictors and in some projects, stronger than structural metrics like complexity or LOC. Files with many logical couplings accumulate more defects because cross-file coupling creates hidden channels for defect propagation.

**How rw-git uses it:** The tool's output can be used as a defect prediction input: file pairs with high co-change count and high confidence are both a refactoring target and a defect risk signal.
