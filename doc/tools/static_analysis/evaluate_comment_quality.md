# evaluate_comment_quality

## Business Logic

Answers: "Are our comments professional, accurate, and correctly formatted?" Flags comments that are vague, profane, outdated, misleading, or written in the wrong format for the language convention (JSDoc vs Dartdoc vs Python docstrings). Poor-quality comments degrade codebase professionalism and actively mislead maintainers when they drift from the code they describe.

## Algorithm

Uses the same **BaseEvaluateCommentsTool** extraction pipeline as `evaluate_comment_necessity`:

1. `git log -p --format=%H||%an||%aI||%s` — extract diff patches
2. Parse added comment lines into structured comment blocks with file/commit context
3. Return comment blocks prepared for LLM evaluation against quality criteria

The LLM evaluates each comment block against four quality dimensions:
1. **Professionalism** — absence of profanity, personal complaints, frustration venting, or TODO notes without owners
2. **Accuracy** — does the comment's claim match what the adjacent code actually does?
3. **Format compliance** — does the comment use the correct style for the language (Dartdoc `///`, JSDoc `/** */`, Python `"""docstring"""`, etc.)?
4. **Completeness** — for public API doc comments: does it document all parameters, return values, and thrown exceptions?

## Academic Foundation

### Steidl, Hummel & Jürgens (2013) — *Quality Analysis of Source Code Comments*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Comment quality can be measured along four dimensions: consistency (format compliance), accuracy (correctness), completeness (for API docs), and absence of noise (no redundancy or outdated content). The paper defines automated rules for each dimension and validates them against expert judgments in industrial codebases.

**How rw-git uses it:** The four LLM evaluation criteria map directly to Steidl et al.'s four quality dimensions. The tool operationalises their quality model using an LLM as the evaluator (since accuracy detection requires reading comprehension, not just pattern matching).

---

### *Dart Documentation Comments Specification* — dart.dev/guides/language/effective-dart/documentation

**Key claim:** Dart uses `///` for all documentation comments. Comments should begin with a single-sentence summary, followed by a blank line and further elaboration. Parameters documented with named parameters in brackets: `[paramName]`. Return values documented with "Returns..." phrasing.

**How rw-git uses it:** Format compliance evaluation includes checking that Dart files use `///` (not `/**` or `//` for doc comments), and that doc comments follow the effective Dart structure.

---

### *JSDoc Reference* — jsdoc.app

**Key claim:** JavaScript and TypeScript documentation comments use `/** ... */` with `@param`, `@returns`, `@throws` tags. Inline `//` comments are not parsed by documentation generators.

**How rw-git uses it:** For `.js` and `.ts` files, format compliance checks that public API comments use `/**` syntax with appropriate tags.

---

### *PEP 257 — Docstring Conventions* (van Rossum et al., 2001) — python.org/dev/peps/pep-0257

**Key claim:** Python docstrings use triple-quoted strings `"""..."""`. One-line docstrings fit on a single line; multi-line docstrings have a summary sentence, a blank line, and elaboration. The first word should not be "This function..." — use imperative mood ("Return the...", "Parse the...").

**How rw-git uses it:** Python file comment extraction looks for triple-quoted strings as doc comments, and format compliance checks for PEP 257 style.

---

### Bird, Nagappan, Murphy, Gall & Devanbu (2011) — *Don't Touch My Code!*

**Published in:** FSE, ACM

**Key claim:** Outdated documentation is more harmful than no documentation — it actively misleads developers into making incorrect assumptions. Files with low ownership clarity (many minor contributors) are more likely to have comments that drift from the code because no one person is responsible for keeping them accurate.

**How rw-git uses it:** The accuracy dimension of comment quality is especially important in high-churn files (where comments are most likely to drift). The tool is most valuable when run on files flagged as high-churn by `analyze_code_quality`.
