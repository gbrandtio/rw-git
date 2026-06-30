# analyze_code_volatility

## Business Logic

Answers: "Which files are most at risk of containing latent defects, even if no bug has been filed against them?" High change frequency combined with high author count is one of the strongest predictors of defect density discovered by empirical software engineering research. Enables prioritisation of test investment and defensive code review before bugs are reported.

## Algorithm

**ChurnHeuristic** processes the full repository history:

1. `git log --name-only --format=%H||%an --no-merges` — parse each commit's changed file list and author
2. For each file path accumulate:
   - `change_frequency` — number of distinct commits that modified this file
   - `author_set` — set of unique author names who committed to this file
3. Compute `author_count = author_set.length`
4. Compute **volatility score**: `score = change_frequency × author_count`
   - Multiplicative: a file changed 100 times by one author scores lower than a file changed 50 times by 10 authors
5. Sort all files descending by `score`; return the top 50

## Academic Foundation

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Relative code churn (lines added + deleted ÷ total lines) is a better predictor of post-release defect density than absolute LOC. Change frequency is the counting-level version of this metric: it captures how many times a file was touched without requiring line-level counting.

**How rw-git uses it:** `change_frequency` is the churn dimension of the volatility score. The empirically validated claim that high-churn files have higher defect density directly justifies using `change_frequency` as a risk signal.

---

### Ostwald, Weyuker & Bell (2004) — *Predicting the Location and Number of Faults in Large Software Systems*

**Published in:** ISSTA, ACM

**Key claim:** Files with the highest number of changes across releases are disproportionately defect-prone. The relationship is super-linear: doubling change frequency more than doubles expected fault count.

**How rw-git uses it:** Confirms the value of `change_frequency` as the primary dimension of the volatility score, and justifies the multiplicative (rather than additive) combination with `author_count`.

---

### Weyuker, Ostrand & Bell (2008) — *Do Too Many Cooks Spoil the Broth? Using the Number of Developers to Enhance Defect Prediction Models*

**Published in:** Empirical Software Engineering, Springer

**Key claim:** Adding developer count per module as a feature to defect prediction models significantly improves prediction accuracy. Files touched by many developers have higher defect density independent of their churn rate — diffusion of responsibility, inconsistent conventions, and implicit coupling are the mechanisms.

**How rw-git uses it:** `author_count` is the second dimension of the volatility score, directly implementing this paper's finding. The multiplicative combination means both dimensions must be elevated for a file to rank highly.

---

### Conway (1968) — *How Do Committees Invent?*

**Published in:** Datamation

**Key claim:** Systems mirror the communication structure of the organisations that build them (Conway's Law). A module touched by many developers who do not coordinate closely will have hidden coupling and inconsistencies — structural defects that accumulate invisibly.

**How rw-git uses it:** High `author_count` is not just a statistical signal — it reflects a structural reality: many-author files have implicit coordination overhead. The volatility score surfaces this organisational risk as a measurable metric.
