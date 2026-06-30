# analyze_pr_diff

## Business Logic

Answers: "How risky is merging this pull request?" Provides a per-file risk score from 0.0 to 1.0 combining five independent risk dimensions. Enables data-driven merge decisions, automated PR triage, and prioritisation of reviewer attention toward the highest-risk files.

## Algorithm

For each file changed in the PR, a **weighted composite risk score** is computed:

| Dimension | Weight | Computation |
|---|---|---|
| Change magnitude | 30% | `(insertions + deletions) / max_change_in_pr` — normalised to [0, 1] |
| Historical churn | 30% | File's `volatility_score` from ChurnHeuristic, normalised to [0, 1] |
| Bus factor exposure | 20% | `1.0 − (bus_factor / max_possible_bus_factor)` — low bus factor = high risk |
| Structural complexity | 10% | Control-flow keyword density in the diff (`if|else|for|while|switch|catch` count ÷ total diff lines) |
| Secret exposure | 10% | 1.0 if SecretsScanner detects a secret in the file's diff hunks, else 0.0 |

`final_score = Σ(weight × dimension_score)`, clamped to [0.0, 1.0].

Files are returned sorted descending by `final_score`. Risk categories: < 0.3 = low, < 0.6 = medium, ≥ 0.6 = high.

## Academic Foundation

### Lessmann, Baesens, Mues & Pietsch (2008) — *Benchmarking Classification Models for Software Defect Prediction: A Proposed Framework and a Novel Performance Measure*

**Published in:** IEEE Transactions on Software Engineering

**Key claim:** No single metric dominates defect prediction across datasets. Ensemble and composite models that combine multiple independent signals consistently outperform single-metric predictors. The optimal weights vary by project, but the multi-signal principle holds universally.

**How rw-git uses it:** The five-dimension weighted composite directly implements the ensemble principle. Each dimension captures an orthogonal risk signal; no single dimension would suffice alone.

---

### Nagappan & Ball (2005) — *Use of Relative Code Churn Measures to Predict System Defect Density*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Code churn is a better standalone predictor of defect density than LOC, complexity, or coupling metrics.

**How rw-git uses it:** The historical churn dimension (30% weight) is the highest-weight component, reflecting this paper's finding that churn is the strongest individual signal.

---

### Mockus & Votta (2000) — *Identifying Reasons for Software Changes Using Historic Databases*

**Published in:** ICSM, IEEE

**Key claim:** Large changes (high insertion + deletion counts) have more defects per line than small targeted changes. The relationship is non-linear — very large commits are disproportionately risky.

**How rw-git uses it:** Change magnitude (30% weight) is the change-size risk signal, normalised within the PR so that the largest changed file scores 1.0.

---

### Avelino, Passos, Hora & Valente (2016) — *A Novel Approach for Estimating Truck Factors*

**Published in:** SANER, IEEE

**Key claim:** When a file has a bus factor of 1 (one developer holds most of the knowledge), changes to that file by other developers carry higher risk — the reviewer lacks the context to catch subtle errors.

**How rw-git uses it:** The bus factor exposure dimension (20% weight) converts file-level bus factor into a risk score. A file with bus factor 1 scores 1.0 on this dimension; a file with bus factor 5 scores near 0.

---

### Meli, McNiece & Reaves (2019) — *How Bad Can It Git? Characterizing Secret Leakage in Public GitHub Repositories*

**Published in:** USENIX Security Symposium

**Key claim:** Secrets (API keys, tokens, credentials) are leaked in pull requests far more frequently than in direct pushes to main. PR diffs are a primary vector because developers copy credentials from test environments into feature branches.

**How rw-git uses it:** The secret exposure dimension (10% weight) integrates the secrets scanner output directly into the PR risk score. A PR with a detected secret immediately scores at least 0.1 on this dimension regardless of other signals.
