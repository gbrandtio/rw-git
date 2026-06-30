# evaluate_comment_llm_generation

## Business Logic

Answers: "Are developers pasting AI-generated comments without review?" LLM-generated comments frequently contain characteristic patterns: hallucinated parameter names, over-verbose boilerplate, meta-language artifacts (`<thinking>`, "Here is a", "As an AI"), excessive enumeration of obvious facts, and certainty hedges. These degrade codebase quality at scale and create a maintenance risk when the LLM's descriptions drift from the actual code behaviour.

## Algorithm

Uses the same **BaseEvaluateCommentsTool** extraction pipeline as the other comment tools:

1. `git log -p --format=%H||%an||%aI||%s` — extract diff patches
2. Parse added comment lines into structured comment blocks
3. Return comment blocks for LLM evaluation against AI-generation detection criteria

The LLM evaluates each comment block for the following AI-generation signatures:
1. **Meta-language artifacts** — `<thinking>`, `<answer>`, "As an AI language model", "I cannot", "Here is a", "Certainly!"
2. **Over-enumeration** — bullet-point lists of obvious facts that the code self-documents (e.g., `/// - This method returns a string`)
3. **Certainty hedges** — "It's important to note", "Please ensure", "Make sure to"
4. **Hallucinated specifics** — parameter names or types that do not match the actual function signature
5. **Boilerplate completeness** — comprehensive Javadoc-style tags on a trivial private method, or a 10-line docstring on a getter
6. **Verbosity ratio** — comment is substantially longer than the code it documents without adding proportional information

## Academic Foundation

### Liu, Tantithamthavorn, Li & Liu (2023) — *Evaluating the Code Quality of AI-Assisted Code Generation Tools*

**Published in:** arXiv preprint (2023)

**Key claim:** AI-generated code (from GitHub Copilot, ChatGPT) passes functional tests at high rates but fails significantly on maintainability metrics — including comment accuracy, naming consistency, and documentation completeness. AI-generated comments in particular tend to be verbose, hallucinate implementation details, and use non-idiomatic phrasing for the language.

**How rw-git uses it:** The "hallucinated specifics" and "verbosity ratio" detection criteria directly address the quality failures documented by Liu et al. The tool gives teams a way to audit whether AI-generated comments have been reviewed before committing.

---

### Vaithilingam, Zhang & Glassman (2022) — *Expectation vs. Experience: Evaluating the Usability of Code Generation Tools Powered by Large Language Models*

**Published in:** CHI, ACM

**Key claim:** Developers frequently accept AI-generated code (and by extension, AI-generated comments) without fully reading them, particularly when under time pressure. The "autocomplete effect" — accepting the first suggested completion — leads to AI-authored content entering the codebase unvetted.

**How rw-git uses it:** The tool is designed specifically for the scenario described in Vaithilingam et al.: detecting content that was accepted from an AI tool without meaningful review. The detection criteria target patterns that a human reviewer would have caught and corrected.

---

### Steidl, Hummel & Jürgens (2013) — *Quality Analysis of Source Code Comments*

**Published in:** ICSE, ACM/IEEE

**Key claim:** Comment noise — redundant or incorrect comments — is the most common quality problem in industrial codebases. AI-generated comments are a new source of systematic noise: they are generated at scale, have consistent stylistic patterns, and often drift from the code immediately (since the LLM generates from the code at a point in time, while the code continues to evolve).

**How rw-git uses it:** The AI-generation detector is a specialisation of Steidl et al.'s comment quality framework, targeting a new noise source that did not exist when the original taxonomy was developed.

---

### Brown et al. (2020) — *Language Models are Few-Shot Learners* (GPT-3)

**Published in:** NeurIPS, Advances in Neural Information Processing Systems

**Key claim:** Large language models generate text with high surface fluency but often with factual inaccuracies ("hallucinations"), particularly when generating specific technical details like method signatures, parameter names, or return types. The more specific the required technical detail, the higher the hallucination rate.

**How rw-git uses it:** The "hallucinated specifics" detection criterion is informed by this paper's finding. AI-generated comments are most likely to be inaccurate in the parts that require the most specificity — parameter types, exception conditions, return value semantics — exactly the parts that matter most in a code review.
