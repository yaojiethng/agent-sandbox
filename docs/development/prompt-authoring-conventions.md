# Prompt and Skill Authoring Conventions

## Purpose and scope

This document states the authoring rules for prompts and skills. It answers four questions: what structure a workflow document has, what belongs in a runbook versus an advisor, how to scope a prompt's subject, and how to identify a workflow document. It is the home for the workflow-document presentation rules that the `/document` stub defers here.

The per-prompt quality passes read this document before they edit a prompt. The `fanout` doc pass reads it before it edits that prompt. Any session that writes a new prompt or skill reads it first.

This document owns the authoring bar for workflow documents. The conceptual model behind them stays in [`agent_workflow.md`](../concepts/agent_workflow.md) - the layers, the loading mechanism, and the authority hierarchy. That document says what a prompt or skill is; this document says how to write one. A rule that states a fact about the model, not a rule about writing, lives in `agent_workflow.md`.

The authoring rules borrow from two external references: Claude's Skill authoring best practices (`https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`) and mattpocock's `writing-for-agents` skill (`https://github.com/mattpocock/skills`, under `skills/productivity/writing-for-agents`). Both describe levers for writing documents an agent consumes. The repository's own prompt and skill set is the primary source; the references explain the reasoning. Read this document for the rules.

## Identify the document type

A document an agent consumes is one of three types. The type determines where it lives and how it is written.

**Policy** documents hold the authoritative rules. Write a rule only into a policy document in `docs/operations/`, `docs/architecture/`, `docs/concepts/`, or `docs/development/`.

**Reference** documents state facts consulted on demand. They define terms, list options, or hold data. A reference document states no rule; it serves the rules that live in policy.

**Workflow** documents are prompts and skills. They are execution helpers and iteration tooling. They are consumers of the policy documents: they reference the rules there, or inline a distillation for context efficiency. A workflow document never carries an authoritative rule. This document calls them workflow documents; [`documentation_policy.md`](../operations/documentation_policy.md) excludes them from its scope by the same boundary.

Two tests identify a workflow document:

1. **Who invokes it.** A prompt runs at the operator's word (`/iter`, `/plan`). A skill runs at the model's or the operator's invocation. A policy or reference document is read, not invoked.
2. **Does it carry authoritative rules?** If removing the document leaves a rule unstated anywhere, the document carries that rule and is policy, not workflow. A workflow document that is the only home of a rule is miswritten.

A third test separates the forms a workflow document takes. Is it steps, reference, or judgement? A runbook holds ordered steps. A reference holds facts. An advisor holds judgement rules and a diagnostic checklist. This distinction shapes the structure, described below.

The three-layer model for where prompts and skills live is in [`agent_workflow.md`](../concepts/agent_workflow.md). The provider layer, the sandbox layer, and the user layer load different sets. An author writes for the layer the prompt or skill is baked into and does not change the loading mechanism.

## The information hierarchy

A workflow document is built from ordered steps, reference, or both. The core decision is where each piece of content sits on the information hierarchy. The hierarchy ranges from most immediately needed to most deferred:

1. **In-file step** is the primary tier. It is what the agent does, in order. Every run needs it.
2. **In-file reference** is consulted on demand. It is a set of rules or facts the agent reaches for when a step needs it.
3. **Disclosed reference** is pushed into a separate file, reached by a context pointer, and loaded only when the pointer fires. It spans a sibling file in the same folder through fully external reference.

Progressive disclosure is the move down the ladder, out of the main file and behind a pointer. It keeps the top legible. It protects the hierarchy; it is not a token saving alone. A document that branches is the cleanest disclosure test: inline what every branch needs, and disclose what only some branches reach.

The failure mode is sprawl: a document too long even when every line is live. Attention thins across the excess. The cure is the ladder: disclose reference behind pointers and split by branch so each path carries only what it needs.

Co-location is the within-file companion. Keep a concept's definition, rules, and caveats under one heading rather than scattered. The test: the document should read like documentation written for the agent. Grouped material reads that way; scattered material does not.

**Degrees of freedom.** Match the specificity to the task's fragility. A task with many valid approaches gets high-freedom guidance: heuristics, not fixed commands. A task that is fragile and error-prone gets low-freedom guidance: the exact sequence or the exact command, stated without alternatives. Offer a default where multiple approaches exist, then name the alternative for the exception case.

## Runbook versus advisor versus skill

A **runbook** is a prompt or skill that holds ordered steps. Each step ends on a completion criterion - the condition that tells the agent the work is done. A clear criterion is sharp and checkable: the agent can tell done from not-done. A vague bound invites premature completion, where the agent ends the step before it is genuinely done. Defend in order: sharpen the bound first; only if it is irreducibly fuzzy do you hide the later steps by splitting the sequence.

The four loop prompts (`/iter`, `/plan`, `/milestone-start`, `/milestone-close`) are runbooks. Their steps map the minor and major loop procedures, and the rules stay in the policy documents.

An **advisor** is a prompt or skill that holds reference and judgement, run against a document or a code change to find defects. It is a diagnostic checklist: it identifies what has gone wrong, not what to do instead. The corresponding prescriptive rules live in the policy and the conventions. An audit prompt must not carry an authoritative rule, because a skill is a fast path, not a source of truth.

The advisor-role split is explicit: the advisor names its role, states when to run it, and constructs a brief. The triage and consensus steps after the advisor returns are part of the runbook that dispatched it.

A **skill** is an execution helper, distinct from a prompt by mechanism not by writing. It is a fast path to a rule that lives in policy. A constraint that exists only in a skill is not authoritative. An inline distillation of a rule is a convenience copy; it may go stale, and that is acceptable only because it is not the source of truth.

Subagents receive `pi -p` with a brief; the same brief-writing rules apply. The `/task-queue` prompt forks a fresh subagent per task with a brief that names the task, its segments, its owned files, its report, and the worker protocol.

## Structure of a workflow document

A prompt opens with frontmatter and a body. The frontmatter fields are the prompt's context pointers: they decide when the agent or the operator reaches the document.

**Description.** State what the prompt does and when to use it. Include the trigger terms a reader or the model would say or think. The description is the top-level pointer, forced to stay loaded. Front-load the triggering word, keep one trigger per branch, and cut anything the body already carries. Write the description in the imperative or the third person; pick one for the prompt. The repo prompt set is split: the loop prompts and `task-queue` use the imperative (`iter`: "Open a new iteration..."), `plan` uses the third person ("Runs a plan session... Routes the outcome"). Third person reads better where several sentences share one subject; do not claim one voice for all. The description names the prompt's subject: `iter` names every workflow type it accepts, `milestone-close` names the fractal close, `task-queue` names the operator decision at segment boundaries. The frontmatter is YAML, so a malformed value breaks the prompt. Quote a description that contains a colon followed by a space (YAML reads it as a nested-mapping boundary) or an apostrophe: wrap the value in double quotes and escape any double quote inside it. A colon-space left in an unquoted value fails to parse with `Nested mappings are not allowed in compact mappings`.

**Argument hint.** Where the prompt accepts an argument, state the argument's shape and whether it is optional. The `iter` prompt names its accepted type words; `plan` marks its argument required.

**Skill frontmatter.** A skill opens with `name` and `description`. `disable-model-invocation: true` marks a skill the model cannot fire on its own, only the operator can invoke it by typing its name. The two repo skills that set it (`thermo-nuclear-code-quality-review`, `domain-model`) are user-invoked because the operator triggers them deliberately and the agent should not reach for them unprompted. A model-invoked skill keeps a description the agent can use for discovery. A router skill names the others and when to reach for each, for when user-invoked skills multiply past what the operator can remember.

**Body order.** A finished workflow document follows a stable order:

1. **The opening template line.** A main-agent prompt opens with `> $@` after the frontmatter, then a title and a `Scope` declaration that states the prompt's boundary. A runbook without this declaration makes a misplaced title indistinguishable from a missing one.
2. **Purpose** states what the prompt or skill is for and what it is not. The task-queue prompt leads with what it is a primitive for, then names what it is not in its "Not this template" routing, inside "When to use".
3. **When to use** states the conditions that invoke it and the routing: what it is for, and what replaces it in the cases it is not for. The task-queue prompt names `iter.md` and `fanout-run.md` as the not-this-template cases.
4. **The steps or the reference region** carries the work. A runbook orders its steps and ends each on a completion criterion; a reference region lists its rules consulted on demand.
5. **Non-goals** states what the prompt deliberately does not do, so the agent does not silently extend scope.
6. **Failure modes and invariants** close a runbook: what can go wrong and what the work must not break. The run-style prompts (`auto`, `parallel-auto`, `fanout-run`) and `task-queue` carry them.

The workflow-document presentation rules that the `/document` stub defers here complete the structure: prose in the body follows the writing standards in `documentation_policy.md`. No step-by-step walkthrough repeats a rule the policy already states; the prompt links to the policy at the point of handoff. A prompt is never the only home of a rule.

## Scope a prompt's subject

One subject per prompt. The subject is the class of work the prompt owns. A prompt that owns two subjects is two prompts, or a runbook that dispatches two sub-cases.

Scope earlier shapes the authoring. A prompt's scope statement must not contradict its own success criteria. Name the in-scope targets explicitly. If a criterion can only be met by a change that looks out of scope, make the criterion flag-only or name the target. This restates the prompt-scope discipline in [`iteration_policy.md`](../operations/iteration_policy.md), which applies it both at runtime and to the main agent authoring the prompt. Write the scope so the contradiction cannot arise.

A prompt that hands off to a sub-agent states the target's whole owned-file set, not a per-unit list, and remaps the sandbox boundary to the worktree. The brief-construction lesson applies at authoring time: a file set must be closed under the test surface, and the closure is computed by searching the test tree for each changed file's basename. The `/task-queue` prompt (`src/reasoning/agent/prompts/task-queue.md`) models this: it defines fork, join, and re-queue as the machinery, and the caller supplies the tasks and their owned files.

**Context pointers and trigger branches.** A prompt or skill reaches its content through pointers. The pointer's wording, not its target, decides when the agent reaches the material. Each trigger branch is one distinct case the document handles. One branch one trigger: synonyms that rename a single branch are one branch written twice, and collapse into one. A pointer that states one branch in prose holds a trigger word not yet written. Name the branch with one word and use that word.

## Consumers as fast paths, never sources

A workflow document is a consumer of the policy documents. It may inline a distillation of a rule for context efficiency, under two constraints:

1. The rule still exists in a policy document. The inline is a fast path to it, never a replacement.
2. The inline is labelled as a convenience copy where its staleness would mislead. An inlined rule that a reader takes as current must carry its pointer to the policy.

This is the canonical-owner test applied to prompts and skills. When a rule appears in a workflow document and in a policy document, an agent reads the policy for the authoritative form and the workflow document for the fast path. The policy is the canonical owner.

Construct defensively against two decay modes:

- **No-ops.** An instruction the agent already obeys by default pays load to say nothing. The test is model-relative: does the sentence change behaviour against the default? When a sentence fails, delete the whole sentence rather than trim its words.
- **Stale accumulation.** Content accumulates because adding feels safe and removing feels risky. A document without pruning keeps obsolete content. Prune by relevance: does each line still bear on what the document does? Shorter documents are easier to keep relevant.

`documentation-pass.md` is the diagnostic register for these checks. The prescriptive rules are here and in `documentation_policy.md` (its `### Document depth and verbosity`); `documentation-pass.md` lists the signs to look for. The canonical-owner test appears in both, by design: the two registers serve different readers.

## Naming

A workflow document's name states its subject, not its mechanism. Prefer a noun phrase that names the work (`task-queue`, `milestone-close`) or a gerund that names the activity (`documentation-pass`). Avoid vague names (`helper`, `utils`) and names that restate the loading mechanism.

A name changes when its scope changes. Rename a document whose name no longer matches its subject, and run a doc pass over it at the same time.

## Compliance

The per-prompt quality passes read this document and apply it to one prompt each, starting with `/task-queue`. Each pass must name what it changed and why against a specific rule here. The `fanout` doc pass applies the same reading to that prompt. A session that writes a new prompt or skill applies it at authoring time.

The [`conventions.md`](conventions.md) index links here as the canonical owner for workflow-document authoring. [`documentation-pass.md`](../../workflow/coding-agent/audits/documentation-pass.md) routes workflow-document prescriptive rules here. [`agent_workflow.md`](../concepts/agent_workflow.md) links here from the "How the Workflow is Expressed" section, so a reader from the model finds the authoring bar. The `fanout` rename and doc pass read against this document.
