# analyze_commit_velocity

## Business Logic

Answers: "Is our team's delivery pace healthy, and where is it heading?".Produces a time-series of commits per configurable period (day / week / month), surfaces burnout signals (off-hours commits), detects anomalous spikes, quantifies commit inequality across authors, and fits a linear trend to the velocity data. Feeds DORA Deployment Frequency benchmarking.

## Algorithm

**CommitVelocityHeuristic** runs the following pipeline:

1. `git log --format=%H||%an||%aI --no-merges` retrieve all commits with author and ISO-8601 timestamp.
2. **Bucketing**: group commits into periods using ISO week / calendar month arithmetic; count commits per bucket per author.
3. **Burnout detection**: commits with a local hour outside 09:00–17:00 are flagged as `burnout_commits`; the count is reported as a team signal.
4. **Trend classification** compare mean commit rate in the first half of history vs. the second half:
   - second_half_mean > first_half_mean × 1.2 → `accelerating`
   - second_half_mean < first_half_mean × 0.8 → `decelerating`
   - otherwise → `stable`
5. **Anomaly detection**: any period whose commit count exceeds μ + 2σ is flagged as an anomaly.
6. **Gini coefficient**: measures how unevenly commits are distributed across authors:
   - Formula: `G = Σ|x_i − x_j| / (2 × n × Σx_i)`, equivalent to the sum-of-absolute-differences form.
   - 0.0 = perfectly equal contribution; 1.0 = one author made all commits
7. **Linear regression slope (OLS)** fit a straight line through the sequence of per-bucket commit counts:
   - `slope = (n·Σxy − Σx·Σy) / (n·Σx² − (Σx)²)`
   - Positive slope = accelerating trend; negative = decelerating; near-zero = stable

## Academic Foundation

### Forsgren, Humble & Kim (2018) — *Accelerate: The Science of Lean Software and DevOps*

**Published in:** IT Revolution Press

**Key claim:** Deployment Frequency is one of four DORA metrics that predict organisational performance. Elite teams deploy multiple times per day; low performers deploy fewer than once per month. Velocity trends distinguish healthy pace from unsustainable crunch.

**How rw-git uses it:** Commit velocity is used as a proxy for deployment frequency when release tags are absent. The trend classification (`accelerating` / `decelerating`) directly maps to DORA Deployment Frequency trajectory.

---

### Claes, Mens & Grosjean (2018) — *Do Programmers Work at Night or During the Weekend?*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Off-hours commits correlate with tight deadlines, reduced code quality, and developer burnout. Teams with sustained high off-hours commit rates show measurably higher defect density in the following release.

**How rw-git uses it:** The `burnout_commits` count directly implements this finding. Engineering managers can use it as an early warning signal before burnout manifests as attrition or quality regression.

---

### Gini (1912) — *Variability and Mutability* (*Variabilità e Mutabilità*)

**Published in:** Studi Economico-Giuridici, Università di Cagliari

**Key claim:** The Gini coefficient, derived from the Lorenz curve, provides a single normalised number for the inequality of a distribution. A Gini of 0 means all individuals contribute equally; 1 means one individual holds everything.

**How rw-git uses it:** Applied to commit counts per author, the Gini coefficient is a precise bus-factor-adjacent metric: a high Gini (> 0.6) signals that commit knowledge is heavily concentrated in one or two developers which constitutes a knowledge silo and continuity risk.

---

### Shewhart (1924) — *Economic Control of Quality of Manufactured Product*

**Published in:** Van Nostrand

**Key claim:** A process is statistically "in control" when its output stays within ±3σ of the mean. Points beyond 2σ are early warnings; beyond 3σ are assignable-cause signals.

**How rw-git uses it:** Periods exceeding μ + 2σ in commit count are flagged as anomalies. This is the standard Statistical Process Control threshold for identifying unusual events without requiring domain-specific tuning.

---

### DeMarco & Lister (1987) — *Peopleware: Productive Projects and Teams*

**Published in:** Dorset House

**Key claim:** Predictable, sustainable velocity (not maximum velocity) is the hallmark of high-performing teams. Velocity spikes followed by troughs indicate deadline-driven crunch, which degrades long-term throughput.

**How rw-git uses it:** The combination of trend slope, anomaly flags, and burnout commits operationalises the "sustainable pace" concept from Peopleware into measurable signals.
