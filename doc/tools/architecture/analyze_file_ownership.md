# analyze_file_ownership

## Business Logic

Answers: "Who really owns this code, and does it match our CODEOWNERS file?" Ownership drift refers to situations where the declared owner has not committed in months while someone else does most of the actual work. This situation creates review bottlenecks, stale approvals, and knowledge gaps. Flags files with no declared owner, drifted ownership, and recently inactive owners.

## Algorithm

1. **CODEOWNERS parsing:**
   Read `.github/CODEOWNERS`, `CODEOWNERS`, or `docs/CODEOWNERS` (checked in order). Parse each non-comment line as a glob pattern → list of owner handles.

2. **Actual committer extraction:**
   For each file matched by a CODEOWNERS pattern, run:
   ```
   git log --follow --format=%an -- <file>
   ```
   with `--since=1 year ago` and `--since=90 days ago` for two time windows.
   Count commits per author in each window.

3. **Drift detection:**
   - **Ownership drift**: declared owner's handle does not appear as the top committer in the 90-day window. The actual top committer is surfaced.
   - **Inactive owner**: declared owner has zero commits to the file in the 90-day window.
   - **No owner**: file path matches no CODEOWNERS pattern.

4. **Output per file:** declared owner(s), top 90-day committer(s), drift flag, inactive flag, and raw commit counts per author.

## Academic Foundation

### Mockus & Herbsleb (2002) — *Expertise Browser: A Quantitative Approach to Identifying Expertise*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Author-file touch history from version control is a reliable proxy for developer expertise. The *Experience Atoms* model weights recent touches more than old ones because expertise decays over time. Developers who have touched a file recently are more likely to correctly review changes to it than those who touched it years ago.

**How rw-git uses it:** The 90-day window is a direct implementation of "recency-weighted expertise." A CODEOWNERS entry that was accurate 18 months ago but has seen no activity in 90 days represents decayed expertise and the declared owner may no longer be the appropriate reviewer.

---

### Bird, Nagappan, Murphy, Gall & Devanbu (2011) — *Don't Touch My Code! Examining the Effects of Ownership on Software Quality*

**Published in:** FSE, ACM

**Key claim:** There is a strong, statistically significant relationship between weak ownership and post-release defects. The strongest predictor of defect density is the fraction of changes made by "minor contributors" (authors with < 5% of a module's commits). The higher the minor-contributor fraction, the more defects. Clear, accurate ownership reduces minor-contributor exposure.

**How rw-git uses it:** Ownership drift means that changes are increasingly being made by the person who *should* be a reviewer (the actual active committer) while the declared owner rubber-stamps reviews without depth. This is the Bird et al. minor-contributor risk pattern applied to code ownership.

---

### Fritz, Ou, Murphy & Murphy-Hill (2010) — *A Degree-of-Knowledge Model to Capture Source Code Familiarity*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Developer knowledge of a specific file degrades over time without re-engagement. The Degree-of-Knowledge (DoK) model shows that a developer who touched a file 12 months ago retains approximately 50% of the contextual knowledge they had immediately after the change.

**How rw-git uses it:** The inactive owner flag directly operationalises DoK decay: a CODEOWNERS entry whose declared owner has not committed in 90+ days is flagged because their effective DoK has decayed significantly. The 1-year vs 90-day dual window shows both the historical and recent ownership picture.

---

### Conway (1968) — *How Do Committees Invent?*

**Published in:** Datamation

**Key claim:** Code ownership should mirror team structure (Conway's Law). When actual commit ownership drifts away from declared ownership, it is often a signal that the organisational boundary has shifted but the CODEOWNERS file has not been updated to reflect it.

**How rw-git uses it:** Systematic ownership drift (many files whose declared owners have been inactive) is an organisational signal as much as a technical one. It indicates that team responsibilities have reorganised without the codebase governance being updated.
