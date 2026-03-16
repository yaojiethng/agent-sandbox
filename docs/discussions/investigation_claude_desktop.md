# Investigation — Claude Desktop as Knowledge Store Provider

**Status:** Not started.

**Direction:** Direction 1 — Provider replacement (special case: may replace harness entirely)  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence.
> - [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
> - [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report must answer.
> - [investigation_mcp_server.md](investigation_mcp_server.md) — Claude Desktop's viability depends on the MCP server option; read this first.

---

## Note

Claude Desktop is a special case within Direction 1. Unlike other provider candidates, it does not run inside a harness container — it is a desktop application that connects to a Dockerized MCP server directly. If selected, it replaces the agent harness entirely rather than slotting in as a new provider under the M1.7 interface.

Trade-offs to evaluate:
- Eliminates harness integration work
- Weakens security guarantees (no sandbox copy, no diff-and-review unless the MCP server investigation's Strategy B is adopted)
- Creates platform lock-in on Anthropic's desktop product
- Anecdotally reported to work with Dockerized MCP servers

This investigation should be conducted after the MCP server investigation reaches a conclusion on mount strategy, since Claude Desktop's viability is partly dependent on that outcome.

---

## Investigation Questions

See [story_provider_knowledge_store.md — Investigation Questions](story_provider_knowledge_store.md#investigation-questions) for the standard question set. Claude Desktop's answers to questions 1–5 will differ significantly from standard provider candidates given it does not run in a container. Document repository suitability (question 6) is the primary evaluation criterion.

Additional questions specific to this candidate:

- **Harness replacement viability** — can the operator workflow be replicated without the harness (start session, review changes, apply or reject)? What is lost?
- **Security delta** — what security invariants are weakened or lost compared to the current harness model? Are they acceptable for the knowledge-vault use case?
- **Platform lock-in assessment** — what is the migration cost if Claude Desktop is later replaced?

---

## Findings

*To be completed.*

---

## Next Steps

1. Complete MCP server investigation (mount strategy decision)
2. Prototype: connect Claude Desktop to a running MCP server container against a test vault
3. Assess document repository suitability
4. Evaluate security delta and platform lock-in
5. Record recommendation
