# evaluate_comment_necessity

## Business Logic

Answers: "Are our code comments adding value, or is the code just hard to read?" Comments that merely restate what the code does are a maintenance burden — when the code changes, the comment becomes incorrect and misleads future readers. This tool extracts comment blocks from recent commits and prepares them for LLM evaluation against the necessity criterion: does this comment explain WHY, not WHAT?

## Algorithm

**BaseEvaluateCommentsTool** extraction pipeline:

1. `git log -p --format=%H||%an||%aI||%s --since=<since>` — extract full diff patches from recent commits
2. Parse added lines (lines beginning with `+` in the diff) that are comment lines:
   - Single-line: `//`, `#`, `--`, `%` (language-agnostic)
   - Block comment starters: `/*`, `/**`, `*`, `*/`
   - Doc comment starters: `///`, `'''`, `"""`
3. Group consecutive comment lines into comment blocks
4. Associate each block with: file path, commit hash, author, date, commit subject
5. Return structured list of comment blocks for LLM evaluation

The LLM is provided the comment text alongside the surrounding code context and asked to classify: *Does this comment explain the WHY (non-obvious reason, constraint, workaround) or only the WHAT (a restatement of the code)?*

## Academic Foundation

### Knuth (1984) — *Literate Programming*

**Published in:** The Computer Journal, British Computer Society

**Key claim:** Programs should be written for humans first, computers second. Code should be composed as a work of literature — explaining not just what computations occur but why they are structured as they are. However, when code is self-explanatory, adding comments that restate the obvious degrades readability by increasing visual noise.

**How rw-git uses it:** The necessity criterion ("WHY not WHAT") is the Knuth principle applied negatively: if removing the comment would not confuse a future reader of the code, the comment is unnecessary. The tool extracts comments so an LLM can apply this principle at scale.

---

### Steidl, Hummel & Jürgens (2013) — *Quality Analysis of Source Code Comments*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Empirical study of 9,000+ files across multiple industrial systems found that 60%+ of comments are redundant (restate the code), outdated (no longer match the code), or code comments (commented-out code). Only approximately 15% of comments add genuine information not derivable from reading the code.

Comment taxonomy from the paper:
- **Copyright comments** — licensing headers (always necessary)
- **Header comments** — file/class description (useful if non-obvious)
- **Interface comments** — Javadoc/docstring style (useful for public APIs)
- **Inline comments** — explain a specific line or block (useful only if WHY is non-obvious)
- **Section comments** — divide large functions into sections (indicate functions are too long)
- **Code comments** — commented-out code (always a smell)

**How rw-git uses it:** The extraction pipeline targets inline and section comments — the two types most likely to be redundant by Steidl et al.'s analysis. The taxonomy informs the LLM evaluation prompt: copyright and interface comments are evaluated differently from inline comments.

---

### Martin (2008) — *Clean Code: A Handbook of Agile Software Craftsmanship*

**Published in:** Prentice-Hall

**Key claim:** "Every time you write a comment, you should grimace and feel the failure of your ability to express yourself in code." Good comments are rare: TODO notes with resolution dates, explanation of non-obvious algorithms, legal headers, and warnings of consequences are the main valid cases. All other comments are failures of code clarity.

**How rw-git uses it:** The evaluation criterion used with the LLM is derived from Martin's framework: the comment is necessary only if the *why* it encodes is not expressible through better naming, extraction, or code restructuring.
