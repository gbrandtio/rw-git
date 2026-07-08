# evaluate_comments

## Business Logic

Answers: "Are the comments entering our codebase valuable, professional, and human-reviewed?". A single tool covering three evaluation aspects (selectable via the `aspects` parameter, defaulting to all):

- **quality**: Are comments professional, accurate, and correctly formatted? Flags comments that are vague, profane, outdated, misleading, or written in the wrong format for the language convention (JSDoc vs Dartdoc vs Python docstrings).
- **necessity**: Are comments adding value, or is the code just hard to read? Comments that merely restate what the code does are a maintenance burden. When the code changes, the comment becomes incorrect and misleads future readers.
- **llm_generation**: Are developers pasting AI-generated comments without review? LLM-generated comments frequently contain characteristic patterns: hallucinated parameter names, over-verbose boilerplate, meta-language artifacts (`<thinking>`, "Here is a", "As an AI"), and certainty hedges.

## Algorithm

**Extraction pipeline** (shared across all aspects):

1. `git log -p --format=%H||%an||%aI||%s`: extract full diff patches from recent commits (bounded by `limit`, default 500).
2. Parse added lines (lines beginning with `+` in the diff) that are comment lines:
   - Single-line: `//`, `#`, `--`, `%` (language-agnostic).
   - Block comment starters: `/*`, `/**`, `*`, `*/`.
   - Doc comment starters: `///`, `'''`, `"""`.
3. Group consecutive comment lines into comment blocks.
4. Associate each block with: file path, commit hash, author, date, commit subject.
5. Return the structured comment blocks together with the evaluation criteria for each requested aspect.

The response is prepared for **LLM evaluation**: extraction is deterministic and zero-token; classification (does this comment explain WHY? is it AI boilerplate?) requires reading comprehension, so the calling LLM applies the returned `evaluation_criteria` to the returned `changed_comments`.

### Aspect: quality

The LLM evaluates each comment block against four quality dimensions:
1. **Professionalism**: absence of profanity, personal complaints, frustration venting, or TODO notes without owners
2. **Accuracy**: does the comment's claim match what the adjacent code actually does?
3. **Format compliance**: does the comment use the correct style for the language (Dartdoc `///`, JSDoc `/** */`, Python `"""docstring"""`, etc.)?
4. **Completeness** (for public API doc comments): does it document all parameters, return values, and thrown exceptions?

### Aspect: necessity

The LLM classifies each comment: *Does this comment explain the WHY (non-obvious reason, constraint, workaround) or only the WHAT (a restatement of the code)?* For comments explaining complex logic, it also considers whether extracting a well-named function or variable would eliminate the need for the comment entirely.

### Aspect: llm_generation

The LLM evaluates each comment block for AI-generation signatures:
1. **Meta-language artifacts**: `<thinking>`, `<answer>`, "As an AI language model", "I cannot", "Here is a", "Certainly!".
2. **Over-enumeration**: Bullet-point lists of obvious facts that the code self-documents (e.g., `/// - This method returns a string`).
3. **Certainty hedges**: "It's important to note", "Please ensure", "Make sure to".
4. **Hallucinated specifics**: Parameter names or types that do not match the actual function signature.
5. **Boilerplate completeness**: Comprehensive Javadoc-style tags on a trivial private method, or a 10-line docstring on a getter.
6. **Verbosity ratio**: Comment is substantially longer than the code it documents without adding proportional information.

## Academic Foundation

### Steidl, Hummel & Jürgens (2013) — *Quality Analysis of Source Code Comments*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Comment quality can be measured along four dimensions: consistency (format compliance), accuracy (correctness), completeness (for API docs), and absence of noise (no redundancy or outdated content). Their empirical study of 9,000+ files across multiple industrial systems found that 60%+ of comments are redundant (restate the code), outdated (no longer match the code), or commented-out code. Only approximately 15% of comments add genuine information not derivable from reading the code.

Comment taxonomy from the paper:
- **Copyright comments**: Licensing headers (always necessary).
- **Header comments**: File/class description (useful if non-obvious).
- **Interface comments**: Javadoc/docstring style (useful for public APIs).
- **Inline comments**: Explain a specific line or block (useful only if WHY is non-obvious).
- **Section comments**: Divide large functions into sections (indicate functions are too long).
- **Code comments**: Commented-out code (always a smell).

**How rw-git uses it:** The four **quality** evaluation criteria map directly to Steidl et al.'s quality dimensions. The extraction pipeline targets inline and section comments (the two types most likely to be redundant by their analysis) and the taxonomy informs the **necessity** evaluation (copyright and interface comments are evaluated differently from inline comments). The **llm_generation** aspect is a specialisation of the same framework, targeting a new systematic noise source that did not exist when the taxonomy was developed.

---

### Knuth (1984) — *Literate Programming*

**Published in:** The Computer Journal, British Computer Society

**Key claim:** Programs should be written for humans first, computers second, explaining not just what computations occur but why they are structured as they are. However, when code is self-explanatory, adding comments that restate the obvious degrades readability by increasing visual noise.

**How rw-git uses it:** The **necessity** criterion ("WHY not WHAT") is the Knuth principle applied negatively: if removing the comment would not confuse a future reader of the code, the comment is unnecessary.

---

### Martin (2008) — *Clean Code: A Handbook of Agile Software Craftsmanship*

**Published in:** Prentice-Hall

**Key claim:** "Every time you write a comment, you should grimace and feel the failure of your ability to express yourself in code." Good comments are rare: TODO notes with resolution dates, explanation of non-obvious algorithms, legal headers, and warnings of consequences are the main valid cases.

**How rw-git uses it:** The **necessity** evaluation criterion is derived from Martin's framework: a comment is necessary only if the *why* it encodes is not expressible through better naming, extraction, or code restructuring.

---

### Bird, Nagappan, Murphy, Gall & Devanbu (2011) — *Don't Touch My Code!*

**Published in:** FSE, ACM

**Key claim:** Outdated documentation is more harmful than no documentation as it actively misleads developers into making incorrect assumptions. Files with low ownership clarity (many minor contributors) are more likely to have comments that drift from the code because no one person is responsible for keeping them accurate.

**How rw-git uses it:** The accuracy dimension of the **quality** aspect is especially important in high-churn files (where comments are most likely to drift). The tool is most valuable when run on files flagged as high-churn by `analyze_code_quality`.

---

### Liu, Tantithamthavorn, Li & Liu (2023) — *Evaluating the Code Quality of AI-Assisted Code Generation Tools*

**Published in:** arXiv preprint (2023)

**Key claim:** AI-generated code (from GitHub Copilot, ChatGPT) passes functional tests at high rates but fails significantly on maintainability metrics including comment accuracy, naming consistency, and documentation completeness. AI-generated comments in particular tend to be verbose, hallucinate implementation details, and use non-idiomatic phrasing for the language.

**How rw-git uses it:** The "hallucinated specifics" and "verbosity ratio" criteria of the **llm_generation** aspect directly address the quality failures documented by Liu et al., giving teams a way to audit whether AI-generated comments were reviewed before committing.

---

### Vaithilingam, Zhang & Glassman (2022) — *Expectation vs. Experience: Evaluating the Usability of Code Generation Tools Powered by Large Language Models*

**Published in:** CHI, ACM

**Key claim:** Developers frequently accept AI-generated code (and by extension, AI-generated comments) without fully reading them, particularly when under time pressure. The "autocomplete effect" (accepting the first suggested completion) leads to AI-authored content entering the codebase unvetted.

**How rw-git uses it:** The **llm_generation** aspect targets exactly this scenario: detecting content that was accepted from an AI tool without meaningful review. Its detection criteria target patterns that a human reviewer would have caught and corrected.

---

### Brown et al. (2020) — *Language Models are Few-Shot Learners* (GPT-3)

**Published in:** NeurIPS, Advances in Neural Information Processing Systems

**Key claim:** Large language models generate text with high surface fluency but often with factual inaccuracies ("hallucinations"), particularly when generating specific technical details like method signatures, parameter names, or return types.

**How rw-git uses it:** AI-generated comments are most likely to be inaccurate in the parts that require the most specificity (parameter types, exception conditions, return value semantics) exactly the parts that matter most in a code review. The "hallucinated specifics" criterion of the **llm_generation** aspect is informed by this finding.

---

### Language documentation conventions (format-compliance references)

- *Effective Dart: Documentation* (dart.dev) — Dart uses `///` for all documentation comments, beginning with a single-sentence summary; parameters documented as `[paramName]`.
- *JSDoc Reference* (jsdoc.app) — JavaScript/TypeScript documentation comments use `/** ... */` with `@param`, `@returns`, `@throws` tags.
- *PEP 257 — Docstring Conventions* (van Rossum et al., 2001) — Python docstrings use triple-quoted strings with a summary sentence in imperative mood.

**How rw-git uses it:** The format-compliance dimension of the **quality** aspect checks comments against the convention for the file's language.
