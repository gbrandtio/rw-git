# get_contributions_by_author

## Business Logic

Answers: "Who contributes how much?". Provides a ranked author contribution table for team reporting, performance review input, onboarding documentation, and spotting contributor drop-off or knowledge concentration risk.

## Algorithm

Executes `git shortlog -sn --no-merges [--since=<date>] [--until=<date>]` and parses the tab-separated output into a list of `(commit_count, author_name)` pairs, sorted descending by commit count.

The `--no-merges` flag excludes merge commits, which inflates counts for maintainers who manage integrations but write less feature code.

Optional `since` and `until` parameters enable scoped queries (e.g., last 90 days, specific sprint window).

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `directory` | yes | The local repository path. |
| `since` | no | Only commits after this date (ISO-8601, e.g. `2024-01-01`, or a git relative phrase, e.g. `6 months ago`). |
| `until` | no | Only commits before this date (ISO-8601, e.g. `2024-12-31`, or a git relative phrase, e.g. `yesterday`). |

## Academic Foundation

### Crowston & Howison (2005) — *The Social Structure of Free and Open Source Software Development*

**Published in:** First Monday, University of Illinois

**Key claim:** Contributor activity in software projects follows a power law (Pareto distribution). A small number of core contributors produce the majority of commits; a large long tail of occasional contributors accounts for the remainder. This "onion model" is stable across projects and over time.

**How rw-git uses it:** The ranked author output directly surfaces the power-law distribution. Engineering leaders can identify the core group (top 10–20% of authors by commit count) who drive most of the project's output, and the long tail who may be at risk of churning unnoticed.

---

### Gini (1912) — *Variability and Mutability*

**Published in:** Studi Economico-Giuridici, Università di Cagliari

**Key claim:** The Gini coefficient measures inequality in a distribution with a single normalised number. Combined with the raw commit counts, the Gini coefficient converts the ranked list into a single bus-factor risk signal.

**How rw-git uses it:** While `get_contributions_by_author` returns the raw ranked list, `analyze_commit_velocity` computes the Gini coefficient over the same data. The two tools are designed to be used together for a complete contribution analysis.

---

### Avelino, Passos, Hora & Valente (2016) — *A Novel Approach for Estimating Truck Factors*

**Published in:** SANER, IEEE

**Key claim:** Commit count per author, while a coarse proxy for knowledge ownership, is a validated approximation of the "truck factor" concept when file-level ownership data is unavailable.

**How rw-git uses it:** The commit count per author is the input data for `analyze_bus_factor`'s knowledge threshold algorithm. `get_contributions_by_author` provides the raw data that bus factor analysis consumes.

---

### Bird, Nagappan, Murphy, Gall & Devanbu (2011) — *Don't Touch My Code!*

**Published in:** FSE, ACM

**Key claim:** Authors who contribute fewer than 5% of a module's changes ("minor contributors") are significantly associated with higher post-release defect density in that module. The contribution count ranking enables identification of minor contributors.

**How rw-git uses it:** Authors near the bottom of the ranked list who are committing to core modules may be contributing as minor authors to those modules. This is a risk signal that `analyze_file_ownership` investigates at the file level.
