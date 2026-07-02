# analyze_bus_factor

## Business Logic

Answers: "How many developers could we lose before the project stalls?" A bus factor of 1 means one developer holds critical knowledge making him a single point of failure. Informs hiring strategy, onboarding investment, documentation priorities, and rotation policies.

## Algorithm

**BusFactorAlgorithm** uses a knowledge-threshold approach:

1. `git log --format=%an --no-merges` to accumulate commit counts per author across the full history
2. Sort authors by commit count descending
3. Compute total commits across all authors
4. Walk the sorted list, summing each author's commit count until the cumulative sum ≥ 50% of total commits
5. **Bus factor** = the number of authors required to cross the 50% threshold
6. Output per top contributor: name, commit count, percentage of total, and cumulative percentage

The 50% threshold is configurable. A lower threshold (e.g., 40%) produces a more conservative (lower) bus factor; a higher threshold (e.g., 70%) produces a more generous (higher) one.

## Academic Foundation

### Avelino, Passos, Hora & Valente (2016) — *A Novel Approach for Estimating Truck Factors*

**Published in:** SANER, IEEE

**Key claim:** The "truck factor" (bus factor) of a project is the minimum number of developers who, if suddenly unavailable, would make the project stall due to lack of knowledge. Studying 133 GitHub projects, the median truck factor is 2, meaning half of studied projects would stall if two specific developers left. A commit-count-based threshold algorithm is a validated approximation that matches expert judgment in 70–80% of cases.

**How rw-git uses it:** The threshold-based algorithm (walk sorted authors until 50% of commits are covered) is a direct implementation of Avelino et al.'s TF (Truck Factor) algorithm. The 50% threshold is the default used in the original paper.

---

### Ferreira, Cesar, Hora, Tulio & Valente (2017) — *A Quantitative Study of Social Structures in the Linux Kernel*

**Published in:** Journal of Systems and Software, Elsevier

**Key claim:** Commit count is a reliable but coarse proxy for developer knowledge. File-level ownership (counting per-developer line contributions per file) produces more precise bus factor estimates, but commit count is sufficient for project-level analysis.

**How rw-git uses it:** The current implementation uses commit count as the knowledge proxy. This is the Avelino et al. approximation valid for project-level bus factor estimation. File-level ownership precision is available in `analyze_file_ownership`.

---

### Gini (1912) - *Variability and Mutability*

**Published in:** Studi Economico-Giuridici, Università di Cagliari

**Key claim:** The Lorenz curve and Gini coefficient provide a geometric interpretation of inequality. The bus factor threshold (50% of commits held by N authors) is the commit-distribution equivalent of finding the Lorenz curve point where the bottom 50% of contributors accumulate half the total commits.

**How rw-git uses it:** The bus factor algorithm is an inverted Lorenz-curve reading: instead of "what fraction of commits do the top X% of authors hold," it asks "how many authors hold 50% of commits." The Gini coefficient (computed by `analyze_commit_velocity`) is the complementary aggregate view.

---

### Conway (1968) — *How Do Committees Invent?*

**Published in:** Datamation

**Key claim:** Knowledge silos in a codebase mirror the communication structure of the organisation. When one team owns a module exclusively, the module's bus factor equals that team's size and knowledge does not diffuse across teams.

**How rw-git uses it:** A bus factor of 1 or 2 in a large organisation often signals a Conway's Law alignment problem: the team owns the module but the organisation has not invested in cross-team knowledge transfer. The bus factor result is an input to organisational design conversations, not just a technical metric.
