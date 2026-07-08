# calculate_universal_lexical_metrics

## Business Logic

Answers: "How complex is this file, and will it be easy to maintain?". Provides seven orthogonal complexity dimensions for any source file in any programming language, using a single FSM-based lexer as the computational engine. No language-specific parser is required since the lexer tokenises source into a universal token stream that all seven algorithms operate on.

## Algorithm

**FsmLexer** tokenises source code using a zero-allocation finite-state machine. States: normal, line_comment, block_comment, string_literal. The FSM produces a flat token stream of types: `identifier`, `operator`, `punctuation`, `number`, `newline`, `unknown`. Comments and string literal content are masked before metrics are computed.

Seven algorithms run on the token stream:

---

### 1. Cyclomatic Complexity (McCabe, 1976)

**Formula:** `CC = 1 + #{control_flow_identifiers} + #{logical_operators}`

Control flow identifiers: `if`, `else if`, `elif`, `for`, `foreach`, `while`, `do`, `case`, `catch`, `when`
Logical operators: `&&`, `||`, `?` (ternary)

Each addition represents one new independent execution path. Base value 1 represents the single path through a function with no branches.

**Thresholds:** CC ≤ 10 = testable; 11–20 = review required; > 20 = nearly impossible to fully test.

---

### 2. NPath Complexity (Nejmeh, 1988)

**Formula:** `NPath = 2^#{decision_points}`

Decision points are control-flow keywords that add new acyclic execution paths. `else` and `catch` are excluded because they do not add new paths rather they handle the path already opened by their corresponding `if` or `try`. Clamped at `1 << 30` (~1 billion) to prevent integer overflow.

**Thresholds:** NPath > 200 (≈ 8 decisions) = more test cases than a team can realistically write.

---

### 3. ABC Score (Fitzpatrick, 1997)

Three counts extracted from the token stream:
- **A (Assignments):** `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`
- **B (Branches):** control-flow keywords + `&&`, `||`, `?`
- **C (Conditions):** `==`, `!=`, `<`, `>`, `<=`, `>=`, `===`, `!==`

**Formula:** `score = sqrt(A² + B² + C²)`

**Thresholds:** score > 15 = elevated; > 30 = refactor.

---

### 4. Halstead Metrics (Halstead, 1977)

From the token stream:
- n₁ = unique operator types; n₂ = unique operand types.
- N₁ = total operator occurrences; N₂ = total operand occurrences.

**Derived metrics:**
- `vocabulary = n₁ + n₂`
- `length = N₁ + N₂`
- `volume = length × log₂(vocabulary)`: information content in bits
- `difficulty = (n₁ / 2) × (N₂ / n₂)`: error-proneness
- `effort = difficulty × volume`: cognitive effort to implement
- `time_to_implement = effort / 18`: estimated implementation time in seconds
- `delivered_bugs = volume / 3000`: estimated bugs delivered

---

### 5. Cognitive Complexity (SonarSource, 2018)

For each control-flow keyword:
- Flat increment: +1
- Nesting penalty: +current_nesting_depth (depth increments at each `{` or block-opening keyword)

Logical operators `&&` and `||` add +1 with no nesting penalty.

Models human comprehension difficulty: deeply nested code is harder to read than a flat sequence of the same number of branches.

---

### 6. Indentation Complexity

Track bracket depth: increment on `{`, `[`, `(`; decrement on `}`, `]`, `)`.

Reports `max_nesting_depth` and `average_nesting_depth`. Language-agnostic structural proxy.

---

### 7. Maintainability Index (Coleman / Visual Studio 2014)

**Formula:**
```
MI = max(0, (171 − 5.2 × ln(V) − 0.23 × G − 16.2 × ln(LOC)) × 100 / 171)
```
where V = Halstead volume, G = cyclomatic complexity, LOC = source lines of code.

**Categories:** ≥ 85 = highly maintainable; 65–84 = moderate; < 65 = needs refactoring.

## Academic Foundation

### McCabe (1976) — *A Complexity Measure*

**Published in:** IEEE Transactions on Software Engineering

**Key claim:** The number of linearly independent paths through a program equals `E − N + 2` in its control flow graph (CFG). For structured programs this equals `1 + number of predicate nodes`. Empirically, modules with CC > 10 are significantly harder to test and more defect-prone.

**How rw-git uses it:** The CC algorithm counts predicate nodes (branch-adding keywords and logical operators) as a linear proxy for the CFG computation. This equivalence holds for structured programs without `goto`.

---

### Nejmeh (1988) — *NPATH: A Measure of Execution Path Complexity and Its Applications*

**Published in:** Communications of the ACM (CACM)

**Key claim:** NPath counts the number of acyclic execution paths through a function, a number that grows exponentially with branching depth. Functions with NPath > 200 are statistically associated with significantly higher field defect rates. NPath is stricter than CC because it captures the "combinatorial explosion" of test cases required by nested branching.

**How rw-git uses it:** `2^decisions` is an approximation of the exact NPath formula that avoids summing path products per construct. For standard structured programs it produces equivalent results. The `1 << 30` (~1 billion) cap prevents nonsensical values for functions with extreme nesting.

---

### Fitzpatrick (1997) — *Applying the ABC Metric to C, C++ and Java*

**Published in:** C++ Report

**Key claim:** The ABC metric captures complexity that Cyclomatic Complexity misses. A function with 20 assignments and no branches has CC = 1 (trivial) but an ABC of 20+ (significant data-flow complexity). ABC is a better correlate of defect density than pure control-flow metrics in data-heavy code.

**How rw-git uses it:** ABC is computed as the third metric specifically to catch complexity that CC and NPath under-report in assignment-heavy or condition-heavy code.

---

### Halstead (1977) — *Elements of Software Science*

**Published in:** Elsevier North-Holland

**Key claim:** Software has measurable information-theoretic properties derivable from operator and operand counts alone. Volume, Difficulty, Effort, and Delivered Bugs are derived metrics that predict implementation time and defect density without executing the program. Halstead's Bug metric (`Volume / 3000`) has been repeatedly validated against industrial defect data.

**How rw-git uses it:** The `delivered_bugs` estimate is the most practically useful Halstead output. It gives an upper-bound estimate of how many bugs a function of that volume is likely to contain, independent of testing.

---

### Campbell (2018) — *Cognitive Complexity: A New Way of Measuring Understandability*

**Published by:** SonarSource (White paper)

**Key claim:** Cyclomatic Complexity treats all branches as equally difficult to understand. Human comprehension studies show that nesting multiplies difficulty. For example, a condition 4 levels deep is much harder to reason about than 4 sequential conditions. Cognitive Complexity adds a nesting depth penalty, producing scores that better correlate with human code-reading time.

**How rw-git uses it:** Cognitive Complexity is computed alongside CC to provide both perspectives: CC is the testability metric; Cognitive is the readability metric. A function can score low on CC but high on Cognitive (flat but many logical operators) or vice versa.

---

### Coleman, Ash, Lowther & Oman (1994) — *Using Metrics to Evaluate Software System Maintainability*

**Published in:** IEEE Computer

**Key claim:** A composite maintainability index combining Halstead volume, cyclomatic complexity, and LOC is a better predictor of maintenance effort than any single metric. The original SEI formula included a comment-density term.

---

### van Deursen / Visual Studio team (2014) — *Maintainability Index Revisited*

**Key claim:** The comment-density term in Coleman et al.'s formula is unreliable across languages (docstring conventions differ; auto-generated comments inflate the score artificially). Removing it and normalising the result to [0, 100] produces a more robust and language-agnostic index. Adding `max(0, ...)` prevents negative scores for extremely large or complex files.

**How rw-git uses it:** The 2014 three-factor, normalised formula is the version implemented. The comment term was deliberately excluded to ensure the metric is comparable across Dart, Python, TypeScript, and other languages.
