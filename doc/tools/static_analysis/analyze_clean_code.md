# analyze_clean_code

## Business Logic

Answers: "Does this file respect clean code principles at the surface level?" A fast, language-agnostic first-pass quality gate that any developer can run on any file. Checks five structural signals that correlate with Single Responsibility Principle violations, poor readability, and copy-paste-driven development.

## Algorithm

Five checks run on the raw file content:

1. **File length** — count total non-empty lines. Flag if > 300 lines. Threshold: large files tend to violate SRP by doing too many things.

2. **Indentation depth** — scan each line's leading whitespace, convert to indentation levels (tab = 1 level; 4 spaces = 1 level). Flag if `max_indentation_level ≥ 5`. Threshold: deeply nested code (arrow code / callback hell) has exponentially more execution paths than flat code.

3. **Long lines** — count lines > 120 characters. Flag if > 10% of lines exceed this threshold. Threshold: long lines indicate complex expressions, missing extractions, or deeply nested closures that should be decomposed.

4. **Magic numbers** — strip comment regions using a comment-stripping regex, then count integer literals with absolute value > 1 in remaining lines using:
   ```
   \b(?!0\b|1\b)\d+\b
   ```
   Flag if count > 10. Threshold: unnamed integer constants are a readability and maintainability hazard.

5. **Duplicate lines** — build a frequency map of all non-blank, trimmed lines longer than 5 characters (so recurring language boilerplate such as `}` is not counted). Count excess occurrences (frequency − 1) for any line appearing more than once. Flag as a clean-code issue when duplicates exceed 10% of the file's lines (Type-1 cloning, Koschke 2007).

**Risk classification:** 0 issues = low risk; 1 issue = medium; 2+ issues = high.

The analysis core is the library-first `CleanCodeAnalyzer` (ADR-0005), shared with the technical, code-review, and audit report meta-tools, which run it automatically on the bounded top-churn sample (ADR-0014) and classify the results (any crossed heuristic → Elevated; 3+ heuristics agreeing → High).

## Academic Foundation

### Martin (2008) — *Clean Code: A Handbook of Agile Software Craftsmanship*

**Published in:** Prentice-Hall

**Key claim:** Functions should be small (< 20 lines) and classes should be small (< a few hundred lines). A class that is too long is doing more than one thing — violating the Single Responsibility Principle. "The first rule of functions is that they should be small. The second rule of functions is that they should be smaller than that."

**How rw-git uses it:** The file length check (> 300 lines) is a practical, coarser-grained version of this principle. It catches the most egregious SRP violations without requiring AST-based class/function boundary detection.

---

### Wulf & Shaw (1973) — *Global Variable Considered Harmful*

**Published in:** ACM SIGPLAN Notices

**Key claim:** Deep nesting — code that requires tracking multiple simultaneously active scopes — is a primary source of programming errors. The cognitive load of maintaining a mental stack of active conditions grows with nesting depth.

**How rw-git uses it:** The max indentation depth check (≥ 5 levels) operationalises this principle. Five levels of nesting means a reader must simultaneously hold 5 conditional contexts in working memory to understand the code.

---

### Atwood (2006) — *Flattening Arrow Code* (Coding Horror blog post)

**Key claim:** "Arrow code" — highly indented code shaped like an arrow pointing right — is universally recognised as a readability problem. Guard clauses, early returns, and extracted functions are the canonical remedies.

**How rw-git uses it:** The indentation depth flag provides the signal; the guidance text suggests guard clause extraction as the remedy.

---

### Fowler (1999) — *Refactoring: Improving the Design of Existing Code*

**Published in:** Addison-Wesley

**Key claim:** *Magic Number* is a code smell: unexplained numeric literals scattered through code make the intent opaque and make future changes brittle (changing the value requires finding every occurrence). The refactoring is *Replace Magic Number with Symbolic Constant*.

*Duplicate Code* is the most fundamental code smell: any time the same code appears in more than one place, the design can be improved by extracting the duplication into a shared location.

**How rw-git uses it:** Both the magic number count and the duplicate line count are direct operationalisations of Fowler's smells. The magic number regex targets integer literals > 1 because 0 and 1 are idiomatic in control flow and are not typically in need of naming.

---

### Koschke (2007) — *Survey of Research on Software Clones*

**Published in:** Dagstuhl Seminar Proceedings

**Key claim:** Code clones (duplicate code blocks) are the most commonly identified quality issue in industrial codebase audits. Type 1 clones (exact textual duplicates) are the easiest to detect and the most straightforwardly removable. Type 1 duplicates carry the same defects in each copy — fixing one copy while missing others is a systematic maintenance hazard.

**How rw-git uses it:** The duplicate line detection (frequency map of non-blank lines) targets Type 1 clones at the line level. It is a lightweight proxy for full clone detection that requires no AST parsing and works across languages.
