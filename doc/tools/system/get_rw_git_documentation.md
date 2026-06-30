# get_rw_git_documentation

## Business Logic

Answers: "What tools does rw-git expose, and how do I use them correctly?" Provides an in-context reference guide so that AI agents and human callers know which tools exist, what parameters they require, what their defaults are, and how to interpret their output. Prevents hallucination of non-existent tools and reduces tool misuse at inference time.

## Algorithm

Returns a static markdown string containing:
- Full list of all MCP tools with their parameter schemas and descriptions
- Default values and limits (e.g., the 500-commit limit on history tools, the 10-file limit on AST analysis)
- Output field descriptions for key tools
- The file-offload pattern explanation (`.rw_git/reports/` for large JSON outputs)
- Guidance on combining tools for common analysis workflows

No git commands are executed. The response is generated from in-memory constants.

## Design Rationale

The tool exists because AI agents operating against MCP servers need reliable in-context documentation to:

1. **Know which tools exist** — LLM parametric knowledge of rw-git's specific tool names and parameters is unreliable (rw-git is a specialised library, not a widely-known API)
2. **Use correct parameter names** — tool schemas are provided via MCP's tool-listing protocol, but schema alone is insufficient for understanding parameter semantics
3. **Interpret outputs correctly** — complex JSON outputs (SZZ chains, Halstead metric objects, architectural smell lists) require prose explanation to be actionable

## Academic Foundation

### Brown et al. (2020) — *Language Models are Few-Shot Learners*

**Published in:** NeurIPS, Advances in Neural Information Processing Systems

**Key claim:** In-context learning — providing examples and documentation within the prompt context window — dramatically reduces hallucination and improves task accuracy compared to relying on parametric knowledge (knowledge baked into model weights). This effect is especially strong for specialised domains and APIs not well-represented in training data.

**How rw-git uses it:** `get_rw_git_documentation` is the in-context learning mechanism for the rw-git MCP server. By returning comprehensive tool documentation in-context, it replaces reliance on parametric knowledge (which would produce hallucinated parameter names and incorrect tool descriptions) with grounded, authoritative documentation.

---

### Mialon, Dessì, Lomeli, Nalmpantis, Pasunuru, Raileanu, Rozière, Schick, Dwivedi-Yu, Celikyilmaz, Grave, LeCun & Scialom (2023) — *Augmented Language Models: A Survey*

**Published in:** Transactions on Machine Learning Research (TMLR)

**Key claim:** Language models augmented with tools and retrieval dramatically outperform non-augmented models on tasks requiring up-to-date or specialised knowledge. The retrieval mechanism (whether RAG, tool calls, or in-context documentation) must be reliable — hallucinated tool names or parameter schemas cause augmented LMs to fail even when the model's reasoning is correct.

**How rw-git uses it:** rw-git is itself an "augmented LM" tool — a MCP server that provides LLM agents with git intelligence. `get_rw_git_documentation` ensures that the augmentation works reliably by providing accurate, in-context tool schemas rather than allowing the agent to infer parameters from hallucinated knowledge.

---

### Schick & Schütze (2021) — *Exploiting Cloze Questions for Few Shot Text Classification and Natural Language Inference*

**Published in:** EACL

**Key claim:** The framing and specificity of in-context instructions significantly affect LLM task performance. Vague instructions ("use the rw-git tools") produce poor results; specific, grounded instructions ("call `analyze_bug_hotspots` with `directory` and `maxResults` parameters") produce reliable tool use.

**How rw-git uses it:** The documentation format — explicit parameter names, types, defaults, and example invocations — is structured to maximise the "specific instruction" effect. The goal is zero ambiguity in tool invocation for an AI agent reading the documentation cold.
