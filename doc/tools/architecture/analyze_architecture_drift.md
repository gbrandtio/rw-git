# analyze_architecture_drift

## Business Logic

Answers: "Are our architectural layers leaking into each other?" Detects commits that simultaneously modify two or more logical architectural layers (e.g., UI + data access, presentation + domain), indicating coupling violations, leaky abstractions, or missing boundary enforcement. Also classifies the coupling pattern into named architectural smells.

## Algorithm

1. **Commit and file extraction:**
   `git log --since=<date> --format=%H||%s --name-only` — commits with full file path lists

2. **Layer matching:**
   For each commit, match every changed file path against user-supplied layer regex patterns (e.g., `lib/ui/.*` → `ui`, `lib/data/.*` → `data`). Record which layers each commit touches.

3. **Drift detection:**
   A commit touching ≥ 2 distinct layers is a **drift commit**. Each layer-pair it touches is recorded in the **coupling matrix** (a symmetric count map: `(layerA, layerB) → count`).

4. **Metrics:**
   - `coupling_ratio = drift_commits / total_commits` — proportion of commits that cross layer boundaries
   - `coupling_density = unique_coupled_pairs / max_possible_pairs` — how densely interconnected the layers are
   - `max_possible_pairs = n × (n − 1) / 2` for n layers

5. **Architectural smell classification:**
   - **God Component** — a layer appears in > 50% of all drift commits (one layer is coupled to everything)
   - **Hub-Like Dependency** — a layer is coupled with ≥ n/2 other layers (when n ≥ 4), creating a hub node in the coupling graph
   - **Scattered Functionality** — any commit touches ≥ 3 distinct layers simultaneously (a single feature spread across too many layers)

## Academic Foundation

### Perry & Wolf (1992) — *Foundations for the Study of Software Architecture*

**Published in:** ACM SIGSOFT Software Engineering Notes

**Key claim:** Software architecture has three components: elements (what exists), form (how they relate), and rationale (why that form was chosen). **Architectural drift** is the divergence of the actual form from the intended rationale over time — it is measurable from commit history because each cross-layer commit is a small form violation.

**How rw-git uses it:** Each drift commit is a direct measurement of Perry & Wolf's "form deviation" — a commit where the actual change pattern violates the intended layer separation. The coupling ratio quantifies the aggregate drift.

---

### Garcia, Oliveira & Murta (2009) — *Identifying Architectural Bad Smells*

**Published in:** CBSOFT/SBES, IEEE

**Key claim:** Architectural bad smells are recurring patterns of structural violation that predict high maintenance cost. The paper formalises four smells: God Component (one module knows everything), Hub-Like Dependency (one module connects to many), Scattered Functionality (one concept spread across many modules), and Cyclic Dependency (circular dependencies).

**How rw-git uses it:** The `architectural_smells` output is a direct implementation of this taxonomy. God Component, Hub-Like Dependency, and Scattered Functionality are detected from the coupling matrix and per-commit layer touch counts.

---

### Gall, Hajek & Jazayeri (1998) — *Detection of Logical Coupling Based on Product Release History*

**Published in:** ICSM, IEEE

**Key claim:** Files that change together are logically coupled, even if they have no explicit import relationship. Co-change data from version history is a reliable proxy for hidden architectural dependencies.

**How rw-git uses it:** The drift commit concept is a layer-aggregated form of logical coupling: instead of tracking file-to-file co-changes, it tracks layer-to-layer co-changes. The coupling matrix is a layer-level co-change matrix.

---

### Newman & Girvan (2004) — *Finding and Evaluating Community Structure in Networks*

**Published in:** Physical Review E, American Physical Society

**Key claim:** Network modularity Q measures how well a network decomposes into non-overlapping communities. A perfectly modular architecture (Q = 1) has no inter-layer edges; a fully coupled architecture (Q = 0) has equal intra- and inter-layer density.

**How rw-git uses it:** `coupling_density` is a simplified approximation of Q's inter-community edge density. It quantifies how far the observed coupling matrix departs from a perfectly modular architecture.

---

### Lippert & Roock (2006) — *Refactoring in Large Software Projects*

**Published in:** Wiley

**Key claim:** Inter-module coupling density is the primary predictor of maintenance cost in large systems. Systems with high coupling density require coordinated changes across many modules for any single feature, dramatically increasing change cost.

**How rw-git uses it:** `coupling_density` is reported alongside `coupling_ratio` to give both a frequency signal (how often drift occurs) and a structural signal (how pervasive the coupling is across the layer graph).
