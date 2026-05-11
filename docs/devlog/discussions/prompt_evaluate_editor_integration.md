# Prompt — Evaluate &lt;&lt;TOOL&gt;&gt; as a UI Option for agent-sandbox

> *Operator: copy this prompt, replace `<<TOOL>>` with the editor/UI you want to evaluate (e.g. VSCode, JetBrains, Helix, Neovim+plugin), and paste it as the first task message of a fresh session. Upload `story_editor_integration_template.md` and the most recent handover before sending. The prompt assumes the agent will produce a single artefact: `story_<<tool>>_integration.md`, structured as a copy of the template with the tool-specific sections filled in.*

---

## Context for the agent

I want to evaluate **&lt;&lt;TOOL&gt;&gt;** as a candidate operator-side UI for agent-sandbox. The output is a story document at `story_<<tool>>_integration.md`, mirroring the structure of the existing Zed and Warp evaluations so the three (or more) can be read in parallel.

The template at `story_editor_integration_template.md` has the tool-independent backbone — Pain Points, Constraints, framing axiom, standing rejected approaches — already in place. Your job is to fill in the tool-specific sections by working through the steps below.

The Pain Points, Constraints, framing axiom, and standing rejections are **stable across all tools**. Do not modify them except for the spots where the template explicitly invites tool-specific adjustment (constraint 6, standing rejections that the tool changes the argument for).

---

## What I want the output to be

A single artefact: `story_<<tool>>_integration.md`. Markdown. Structure mirrors the template. Every `<<TOOL>>` placeholder replaced; every guidance block deleted; every tool-specific section filled with the result of your research and clarifying questions.

Status line set honestly:

- **"Investigation pre-experiment"** — tool feature set documented but no hands-on yet, no experiments planned yet.
- **"Investigation in progress"** — at least one hand-rolled session has run and findings are recorded; more sessions planned.
- **"Investigation complete"** — all questions are resolved, deferred, or shelved; no further experiments planned.
- **"Ready for resolution"** — the story is graduating per `story_policy.md`.

For a fresh evaluation that's purely desk-research at the time of writing, "Investigation pre-experiment" is usually the right starting point — unless the tool turns out to be desk-research-shaped (like Warp), in which case "Investigation complete" may be reachable in a single session.

---

## How to do this

### Step 1 — Verify-before-claiming discipline

Before filling any tool-specific section, internalise this discipline. **It is the single most important instruction in this prompt.**

For every claim about &lt;&lt;TOOL&gt;&gt;'s features, mark the source:

- **Documentation** — official &lt;&lt;TOOL&gt;&gt; docs, changelogs, or vendor-published reference material.
- **Marketing** — landing pages, blog posts, sales material. Treat with extra scepticism; marketing routinely overstates feature scope.
- **Screenshot** — operator-supplied or other screenshots showing the feature working.
- **Hands-on** — the operator (or you, in a session that has hands-on access) has confirmed the feature works as described.
- **Inferred** — your own deduction from related facts. Lowest confidence; flag explicitly.

When the source is anything other than documentation or hands-on, mark the claim with **(unverified — &lt;source&gt;)** in the draft so the operator sees it. The Warp evaluation's first draft made two load-bearing claims (CMD+I as agent-integration, Project Explorer in remote sessions) that turned out to be wrong because they were marketing-derived and not flagged. Avoid that failure mode.

If the operator pushes back on an unverified claim with corrected information, treat that correction as authoritative and update the draft accordingly. Do not defend the original claim from documentation if the operator says hands-on contradicts it.

### Step 2 — Establish what drew the operator to this tool

Before researching anything, ask the operator:

1. **What specific features of &lt;&lt;TOOL&gt;&gt; motivated considering it?** Two or three concrete features, not "it looks nice." Examples: "first-class Dev Container support," "AI assistant that wraps the terminal PTY," "remote-mode editor over SSH," "first-class Vim mode."
2. **What's the relationship to other parallel evaluations?** Is this replacing an earlier candidate, an alternative to one already in evaluation, or standalone?
3. **Are there any tool-specific constraints to bake in upfront?** E.g. "we don't want to use the paid tier," or "we already know feature X is unavailable on Linux."

These answers shape the Context section's "What drew us to &lt;&lt;TOOL&gt;&gt;" subsection. Keep them short — two or three bullets, each with the source flagged per Step 1.

### Step 3 — Build the existing-primitives row set

Most rows in the existing-primitives table are stable harness primitives — copy them verbatim from the template. The tool-specific rows are the bottom half of the table. For each, determine:

- **Does &lt;&lt;TOOL&gt;&gt; offer task / workflow primitives?** What's the configuration shape (file, in-app config, command palette)?
- **Does &lt;&lt;TOOL&gt;&gt; support multiple terminal panes per window?**
- **Does &lt;&lt;TOOL&gt;&gt; support multiple folder workspaces per window?** Tabs or true multi-root?
- **Does &lt;&lt;TOOL&gt;&gt; have container integration?** What kind — Dev Container, SSH remote, exec attach, custom protocol? **For each integration mechanism, separately determine: does it deliver editor features (file tree, file editor, diffs) inside the container, or just terminal chrome?** This is exactly where Warp surprised us — terminal chrome but no Project Explorer in remote sessions. Don't assume the integration delivers all features.
- **Does &lt;&lt;TOOL&gt;&gt; have a first-class agent surface?** ACP client? MCP host? Custom protocol? Vendor-specific AI? **If vendor-specific AI — is it a third-party integration surface or only the vendor's own agent?** Warp's CMD+I tripped on this distinction.

Each row gets a primitive name, source link (to vendor docs), and a use description. Mark unverified claims per Step 1.

### Step 4 — Document concrete shapes

For each integration shape &lt;&lt;TOOL&gt;&gt; offers, write a "Shape &lt;ID&gt;" subsection. Be concrete: include code blocks, config snippets, or step-by-step descriptions a reader can recreate. The Zed story used 4 shapes; the Warp story used 6. Use as many as the tool's complexity warrants.

For each shape, name:

- What it accomplishes.
- What harness change (if any) it requires.
- Known limitations.
- Whether it has been hands-on confirmed or is documentation-only.

### Step 5 — Fill the axes

Axes A, B, C, D have stable structures. Most values are stable across tools (A1, A2, A3 for lifecycle; B0–B3 for terminal; C0, C1, C3 for editor; D1, D2, D3 for edit policy). Tool-specific values get added with new IDs:

- **Axis A** — does &lt;&lt;TOOL&gt;&gt; require a tool-specific lifecycle option beyond A1/A2/A3? Warp added A4 for the `MODE=warp` overlay. Zed considered but rejected an A3-shaped wrapper.
- **Axis C** — does C2 (container workspace) exist for this tool? If yes, describe the mechanism. If no, mark N/A and explain why (e.g. "remote sessions do not provide editor features"). C4 should generally remain rejected by the standing rejection on bind-mounting.
- **Tool-specific axis E and beyond** — only add if the tool offers an integration choice that doesn't fit any of A–D. Don't invent axes for features that already fit. Warp didn't end up needing one (the original draft had Axis E for CMD+I, but that collapsed when CMD+I was reclassified). VSCode might justify one for its extension/agent-protocol surface, but verify before adding.

### Step 6 — Update rejected approaches

The standing rejections are stable. Only edit them if the tool genuinely changes the underlying argument — e.g. if a future tool ships a security model that makes bind-mount safe.

Add tool-specific rejections as research surfaces them. Examples from prior evaluations:

- Warp: "sshd in reasoning layer container" (rejected because `docker exec` Warpify delivers the same features without the network listener).
- Warp: "CMD+I as a third-party agent integration surface" (rejected because Warp Agent does not accept third-party agents).
- Zed: "Shape 3 — compose-based devcontainer + `initializeCommand`" (rejected for three compounding blockers).

Each tool-specific rejection should name what the rejected approach is, why, and what would change the rejection.

### Step 7 — Build the coverage table

Fill the seven-column coverage table for each axis value. Use:

- `✓` — the value covers the use case.
- `partial` — partial fit (often via shell when a richer surface would be better).
- `—` — does not address.
- `?` — pending experimental confirmation. Use this honestly: a feature claimed by docs but not hands-on confirmed is `?`, not `✓`.
- `rejected for <reason>` — for closed values like A2 for pi.

After the table, write a 2–4 bullet "Reading the table" prose summary mirroring the Zed and Warp stories: which cluster covers the cheap use cases without harness change; which use cases are uncovered; which axis values are closed.

### Step 8 — Generate open questions

For each tool-specific feature where research did not give a confident answer, write an open question. Use a tool-specific prefix (Q-V for VSCode, Q-J for JetBrains, etc.) so cross-story references don't collide.

Group questions by status — Resolved during research, Resolved by hand-rolling (empty initially), Closed by workaround (empty initially), Active, Still open, New questions surfaced by Session N (empty initially).

A question is well-formed when it (a) names a specific uncertainty, (b) describes what evidence would resolve it, and (c) maps to a coverage-table cell that is currently `?`. Avoid open questions that are just "investigate &lt;&lt;TOOL&gt;&gt; more" — those are not questions, they are unstructured curiosity.

### Step 9 — Plan experiments

For each Active question, write an experiment that resolves it. Use the format from the Zed and Warp stories:

- **Goal** — what the session resolves.
- **Why this is the right next experiment** — usually "answers the load-bearing question for the cheapest cluster" or "tests the highest-value uncertain feature."
- **Phased structure** — if applicable, with each phase a precondition for the next.
- **Pass criterion** — what success means.

If the tool turns out to be desk-research-shaped (no hands-on session can resolve more than research already has), say so explicitly: "No further experiments planned. Tool feature set is documented; the integration is composition of existing primitives." That's a valid outcome — Warp landed there.

### Step 10 — Decide on Status

Set the Status line based on what you actually produced:

- All tool-specific sections filled, no hands-on yet, experiments planned → **Investigation pre-experiment**.
- Hand-rolled session(s) recorded under Investigation Findings, more planned → **Investigation in progress**.
- All questions resolved/deferred/shelved, no more experiments planned → **Investigation complete**.

Don't claim a more-advanced status than the artefact actually supports. The Zed story is "Investigation in progress" because Session 2 is scoped but not run; the Warp story is "Investigation complete" because no experiments are planned.

---

## Operator-side responsibilities

You will need to ask the operator for:

- **What drew them to &lt;&lt;TOOL&gt;&gt;** (Step 2 questions).
- **Confirmation or correction of unverified claims** as they appear in the draft. Mark each, ask the operator to confirm or correct, update accordingly.
- **Hands-on observations** if the operator has any. Screenshots are ideal; descriptions are usable.
- **Tool-specific scope decisions** — which features matter, which are paid-tier-and-out-of-scope, which are platform-conditional.

If the operator hasn't yet used &lt;&lt;TOOL&gt;&gt; hands-on at all, the draft will be desk-research only — that's fine, just be honest about it in the Status line and in the source flags throughout the document.

---

## Failure modes to avoid

The following patterns have appeared in prior evaluations and should be actively guarded against.

### Treating marketing claims as confirmed features

Marketing copy often describes feature *intent* rather than *behaviour*. "AI-powered terminal" can mean anything from "the prompt has a button that opens a chat" to "the terminal autocompletes commands using a remote LLM." Always check what the feature actually does before claiming it covers a use case. Flag the source per Step 1.

### Conflating "tool has a feature" with "feature works in our integration shape"

Warp has File Tree. Warp also has remote sessions. Therefore Warp has File Tree in remote sessions, right? No. Verify the feature works in the *specific integration shape* you're proposing. The ergonomics in a host-side workspace and the ergonomics in a Warpify'd-into-container session can be radically different.

### Adding a tool-specific axis for a feature that fits an existing axis

If the tool has a "send selection to AI" command, that's not a new axis — it's a custom-command primitive that fits naturally within the existing axes. Only add a tool-specific axis when the tool offers an integration choice that genuinely does not fit A, B, C, or D. The Warp draft's first version added Axis E for CMD+I and then deleted it when CMD+I turned out to be a Warp-Agent-only feature. Save a step by checking before adding.

### Acting on a tool's roadmap as if it were a current feature

"Coming soon" features don't cover use cases today. Document them as "on the roadmap; not currently shipping" and mark the relevant axis value as N/A or `?`. Don't write evaluation prose as if the future feature is present.

### Rejecting a candidate without naming "would change if"

Every rejection in the rejected-approaches table has a "Would change if" column. This isn't optional. A rejection without a reversal condition is brittle — it doesn't tell future readers what new evidence would re-open the question. Always fill that column.

### Skipping the verify-before-claiming flag because the source seems obvious

Even when the source is the vendor's official docs, flag it as "documentation." This makes it possible for the operator to scan the draft and see at a glance what's confirmed vs. inferred. Skipping the flag because "it's obvious" defeats the purpose.

---

## End state

When you're done, the operator should have a `story_<<tool>>_integration.md` that:

- Stands alone as a complete evaluation document — no `<<TOOL>>` placeholders, no template guidance comments.
- Reads cleanly alongside the Zed and Warp stories with parallel structure.
- Names every unverified claim explicitly.
- Has a Status line that honestly reflects the state of investigation.
- Lists open questions that are answerable, scoped, and mapped to specific coverage-table cells.
- Plans experiments only for questions that hand-rolling can answer; closes the rest in research.

If the artefact diverges from this in a load-bearing way, the operator will tell you and you'll iterate. If it diverges in a small way, the operator will edit it directly. Do not over-anchor on the first draft being final.
