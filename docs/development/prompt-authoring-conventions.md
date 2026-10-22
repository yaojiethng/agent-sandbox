# Prompt and Skill Authoring Conventions

## Purpose and scope

This document states the authoring rules for prompts and skills. It answers four questions: what structure a workflow document has, what belongs in a runbook versus an advisor, how to scope a prompt's subject, and how to identify a workflow document. It is the source of truth for the workflow-document presentation rules that the `/document` stub defers here.

The per-prompt quality passes read this document before they edit a prompt. The `fanout` doc pass reads it before it edits that prompt. Any session that writes a new prompt or skill reads it first.

This document owns the authoring bar for workflow documents. The conceptual model behind them stays in [`agent_workflow.md`](../reference/agent_workflow.md) - the layers, the loading mechanism, and the authority hierarchy. That document says what a prompt or skill is; this document says how to write one. A rule that states a fact about the model, not a rule about writing, lives in `agent_workflow.md`.

The authoring rules borrow from two external references: Claude's Skill authoring best practices (`https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`) and mattpocock's `writing-for-agents` skill (`https://github.com/mattpocock/skills/tree/main/skills/productivity/writing-for-agents`). Both describe levers for writing documents an agent consumes. The repository's own prompt and skill set is the primary source; the references explain the reasoning. Read this document for the rules.

## Identify the document type

A document an agent consumes is one of three types. The type determines where it lives and how it is written.

**Policy** documents hold the rules an observer detects, and the judgements their own workflow produces. A policy document lives in `docs/policies/`, `docs/reference/`, or `docs/development/`.

**Reference** documents state facts consulted on demand. They define terms, list options, or hold data. A reference document states facts; a rule it stated would make it a policy document, per the type test below.

**Workflow** documents are prompts and skills. They are execution helpers and iteration tooling. They hold the rules their own procedure runs, and they point at the source of truth of every rule they borrow, or inline a distillation for context efficiency. A judgement used by more than one document lives in a principle skill, and that skill is its only source of truth. This document calls them workflow documents; the `docs` convention, `.agents/skills/docs/SKILL.md` excludes them from its scope by the same boundary, because skill files and prompt templates are not documentation.

Two tests identify a workflow document:

1. **Who invokes it.** A prompt runs at the operator's word (`/iter`, `/plan`). A skill runs at the model's or the operator's invocation. A policy or reference document is read, not invoked.
2. **Who observes it?** A document that a gate, a lint rule or a routine read observes is policy. A document whose rules its own steps run is workflow.

A third test separates the forms a workflow document takes. Is it steps, reference, or judgement? A runbook holds ordered steps. A reference holds facts. An advisor holds judgements and a diagnostic checklist. This distinction shapes the structure, described below.

The three-layer model for where prompts and skills live is in [`agent_workflow.md`](../reference/agent_workflow.md). The provider layer, the sandbox layer, and the user layer load different sets. An author writes for the layer the prompt or skill is baked into and does not change the loading mechanism.

## The information hierarchy

A workflow document is built from ordered steps, reference, or both. The core decision is where each piece of content sits on the information hierarchy. The hierarchy ranges from most immediately needed to most deferred:

1. **In-file step** is the primary tier. It is what the agent does, in order. Every run needs it.
2. **In-file reference** is consulted on demand. It is a set of rules or facts the agent reaches for when a step needs it.
3. **Disclosed reference** is pushed into a separate file, reached by a context pointer, and loaded only when the pointer fires. It spans a sibling file in the same folder through fully external reference.

Progressive disclosure is the move down the ladder, out of the main file and behind a pointer. It keeps the top legible. It protects the hierarchy; it is not a token saving alone. A document that branches is the cleanest disclosure test: inline what every branch needs, and disclose what only some branches reach.

The failure mode is sprawl: a document too long even when every line is live. Attention thins across the excess. The cure is the ladder: disclose reference behind pointers and split by branch so each path carries only what it needs.

**Co-location is the within-file companion of progressive disclosure.** The judgement is the `communication-principle-keep-a-subject-near` skill at `$AGENT_HOME/agent/skills/communication-principle-keep-a-subject-near/SKILL.md`.

**Match the precision to the stakes.** An instruction narrows as its stakes rise: how far a wrong move reaches, whether it can be undone, and whether anything reports it. The judgement is the `principle-match-precision-to-stakes` skill at `$AGENT_HOME/agent/skills/principle-match-precision-to-stakes/SKILL.md`.

**No magic constants in a snippet.** The judgement is the `communication-principle-name-the-value-not-a-literal` skill at `$AGENT_HOME/agent/skills/communication-principle-name-the-value-not-a-literal/SKILL.md`.

## Runbook versus advisor versus skill

A **runbook** is a prompt or skill that holds ordered steps. Each step ends on a criterion that says when the step is done; the judgement is the `principle-say-what-done-looks-like` skill at `$AGENT_HOME/agent/skills/principle-say-what-done-looks-like/SKILL.md`. The reference region of a prompt is different: it lists rules consulted on demand and has no step to finish.

The loop prompts (`/iter`, `/plan`, `/sidequest`, `/milestone-start`, `/milestone-close`) are runbooks. Their steps map the iteration and milestone workflow procedures, and each rule they state belongs to the procedure.

An **advisor** is a prompt or skill that holds reference and judgement, run against a document or a code change to find defects. It is a diagnostic checklist: it identifies what has gone wrong, not what to do instead. The corresponding prescriptive rules live in the policy and the conventions, so an advisor names the rule a document broke rather than restating it.

The advisor-role split is explicit: the advisor names its role, states when to run it, and constructs a brief. The triage and consensus steps after the advisor returns are part of the runbook that dispatched it.

A **skill** is an execution helper, distinct from a prompt by mechanism not by writing. It may be the source of truth for a rule its own procedure runs, and it may inline a distillation of a rule whose source of truth is elsewhere: the inline is a convenience copy, it may go stale, and it names that source. A judgement used by more than one document lives in a principle skill, per `### Norm kinds` in [`agent_workflow.md`](../reference/agent_workflow.md#norm-kinds).

**Where a check goes is a judgement.** A check reads evidence and produces a decision, so its placement is stated in the `principle-check-placement` skill at `$AGENT_HOME/agent/skills/principle-check-placement/SKILL.md`, and a skill that holds checks points there.

Subagents receive `pi -p` with a brief; the same brief-writing rules apply. The `/task-queue` prompt forks a fresh subagent per task with a brief that names the task, its segments, its owned files, its report, and the worker protocol.

## Structure of a workflow document

A prompt opens with frontmatter and a body. The frontmatter fields are the prompt's context pointers: they decide when the agent or the operator reaches the document.

**Description.** State what the prompt does and when to use it. Include the trigger terms a reader or the model would say or think. The description is the top-level pointer, forced to stay loaded. Front-load the triggering word, keep one trigger per branch, and cut anything the body already carries. Write the description in the imperative or the third person; pick one for the prompt. The repo prompt set is split: the loop prompts and `task-queue` use the imperative (`iter`: "Open a new iteration..."), `plan` uses the third person ("Runs a plan session... Routes the outcome"). Third person reads better where several sentences share one subject; do not claim one voice for all. The description names the prompt's subject: `iter` names every workflow type it accepts, `milestone-close` names the fractal close, `task-queue` names the operator decision at segment boundaries. The frontmatter is YAML, so a malformed value breaks the prompt. An unquoted value cannot hold a colon, a leading dash, or a trailing colon, because YAML reads each as structure; wrap such a value in double quotes and escape any inner double quote. An apostrophe needs no quoting. Pi drops a prompt whose frontmatter does not parse, with no session message, so it never appears in the command list, and `scripts/check_document_shape.sh` fails the gate on any unparseable block in the tree.

**Argument hint.** Where the prompt accepts an argument, state the argument's shape and whether it is optional. The `iter` prompt names its accepted type words; `plan` marks its argument required.

**Skill frontmatter.** A skill opens with `name` and `description`. `disable-model-invocation: true` removes a skill from the model's prompt, so the model can neither discover nor fire it; only the operator invokes it, by typing its name. Set it on a skill the operator fires deliberately: the two quality skills and the two loop runbooks set it in this tree. A judgement skill does not set it, because a writer reaches for a judgement mid-draft and must find it, and the field's value is a boolean, held by the frontmatter gate. A hidden skill's description is read from the operator's skill list, so write it for the operator, while a model-invoked skill's description is for the agent's discovery. A router skill names the others and when to reach for each, for when user-invoked skills multiply past what the operator can remember.

**Suggested skill name.** The judgement is the `principle-skill-signposting` skill at `$AGENT_HOME/agent/skills/principle-skill-signposting/SKILL.md`. This document holds the scheme this repository uses, which is a suggestion and not a rule; nothing in the tree checks a skill name, and the norm-ownership ledger records it as a judgement with no observer. A principle follows `[<domain>-]principle-<judgement>`: a bare `principle-` when the judgement holds for any agentic work, and the domain prefix when it is confined to one, as in `principle-guard-the-context-window`, `communication-principle-write-for-the-reader`, and `bash-coding-principle-<judgement>` for language-specific work. The scheme shadows the one the `poteto` skill set uses at its fork source, `pstack`, so a name states the class and never the provenance; the skill's maintenance record states where it came from. Every other skill follows `<verb-noun>`, so that `/<action>` reads to the operator as "do <action>", the same shape as `node run <action>` and `uv run <action>`. A mode keeps the `-mode` suffix `poteto-mode` established.

**Body order.** A finished workflow document follows a stable order:

1. **The opening template line.** A main-agent prompt opens with `> $@` after the frontmatter, then a title and a `Scope` declaration that states the prompt's boundary. A runbook without this declaration makes a misplaced title indistinguishable from a missing one.
2. **Purpose** states what the prompt or skill is for and what it is not. The task-queue prompt leads with what it is a primitive for, then names what it is not in its "Not this template" routing, inside "When to use".
3. **When to use** states the conditions that invoke it and the routing: what it is for, and what replaces it in the cases it is not for. The task-queue prompt names `iter.md` and `fanout-run.md` as the not-this-template cases.
4. **The steps or the reference region** carries the work. A runbook orders its steps and ends each on a completion criterion; the judgement is the `principle-say-what-done-looks-like` skill at `$AGENT_HOME/agent/skills/principle-say-what-done-looks-like/SKILL.md`. A reference region lists rules consulted on demand, so it has no step to finish.
5. **The handoff.** A runbook that ends by handing to another prompt names the boundary. The judgement is the `communication-principle-hand-off-by-naming-the-boundary` skill at `$AGENT_HOME/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md`. A prompt that ends inside its own scope omits it.
6. **Non-goals** states what the prompt deliberately does not do, so the agent does not silently extend scope.
7. **Failure modes and invariants** close a runbook: what can go wrong and what the work must not break. The run-style and work-style prompts (`sequential-work`, `parallel-work`, `fanout-run`) and `task-queue` carry them.

**The project conventions block.** A workflow document that reads or writes project records opens with a `## Project conventions` section before its first step. It lists the conventions the document uses, each read at `.agents/skills/<name>/SKILL.md`, and states the failure when that file is absent or holds the seeded stub: control passes to the agent, which decides with the steering it has loaded, and the workflow prescribes no fallback. The block names the convention, never the project's paths - the workflow keeps the procedure and the project's convention-skill holds the structure - so a project with a different layout is served by its own skill. The fourteen loop prompts and the six module skills are the model, and `gm` is the minimal case.

The workflow-document presentation rules that the `/document` stub defers here complete the structure: prose in the body follows the writing standards in the `communication-principle-*` corpus. No step-by-step walkthrough repeats a rule its source already states; the prompt links to that source at the point of handoff. A prompt is never the only source of truth for a rule.

## The principle shape

A principle skill states one judgement, and every principle in the corpus carries the same parts, file by file, so a writer filing a new one copies a single exemplar. The decision and its rejected alternatives are in [`principle_skill_shape.md`](../adr/principle_skill_shape.md), and `scripts/check_document_shape.sh` holds the shape against every file the name selects.

The subject is the name. A skill whose directory name carries `principle-` carries the shape. A skill that holds ordered steps is a runbook, keeps the runbook shape, and sits outside this section.

| Part | What it carries |
|---|---|
| `# <the judgement as a sentence>` | the title, in sentence case, and the file's only heading |
| one sentence | the judgement, stated plainly, before the pattern |
| `**The pattern.**` | the wrong form beside the right form, as a table where a contrast exists and a list where the parts are steps |
| `**Why.**` | the reason the wrong form fails |
| `**<label>.**` | zero or more named parts, each named for the situation it addresses |
| `**The test.**` | the question the writer asks their own draft |

The order is fixed: the pattern, the why, the named parts, the test. A label ends on a period, so a reader scanning the file sees the parts as one set. A bullet that opens with a bold label is not a part, because the list marker opens it.

The exemplar is `communication-principle-show-dont-describe`, at `$AGENT_HOME/agent/skills/communication-principle-show-dont-describe/SKILL.md`.

## The principle claims

Every principle applies one claim, and the claim is how a reader finds the family of principles that bears on a problem they cannot name yet. The five claims serve one goal, alignment. A text succeeds when the reader holds the model the writer holds, and each claim names a kind of gap between the two. A principle declares its claim in its frontmatter, under the `metadata` key pi documents for extra fields: `metadata:` then `claim: <name>`. `scripts/check_document_shape.sh` reads the declaration and fails a principle that carries none or names one this table does not state, and its `--map` mode prints the corpus grouped by claim.

| Claim | The claim a skill of this family makes |
|---|---|
| `evidence` | a claim carries the artifact that proves it, or the sentence says it is an inference |
| `source` | a restated fact is a copy and the source owns it, so a copy goes wrong when the source changes and nothing reports it |
| `scope` | a pointer, a label or a literal names something the reader finds only where the text is read |
| `reader` | the reader holds what the text gives them, in the order it arrives |
| `authority` | a document owns the scope it declares and no more |

Two skills may apply one claim when they act on different objects, because each states a different test. `only-derive-what-you-own` and `single-source-of-truth` both apply `source`, and one asks whether the reader can recompute a number while the other asks whether every copy of a rule points at one source of truth. Two skills may not state the same rule.

This table is the only place that decides the set, and the gate reads the set from here. The gate decides that a claim is stated and that the table holds it; which claim a given skill picks stays a judgement, so no gate reads it.

## Scope a prompt's subject

**One subject per prompt.** The subject is what the prompt hands on: one artifact to one next step. A prompt that hands on two artifacts, or hands one to two next steps, is two prompts, or a runbook that dispatches two sub-cases. The judgement is `principle-own-the-scope-you-declare` at `$AGENT_HOME/agent/skills/principle-own-the-scope-you-declare/SKILL.md`.

Scope earlier shapes the authoring. A prompt's scope statement must not contradict its own success criteria. Name the in-scope targets explicitly. If a criterion can only be met by a change that looks out of scope, make the criterion flag-only or name the target. This restates the prompt-scope discipline in [`iteration_policy.md`](../policies/iteration_policy.md), which applies it both at runtime and to the main agent authoring the prompt. Write the scope so the contradiction cannot arise.

A prompt that hands off to a sub-agent states the target's whole owned-file set, not a per-unit list, and remaps the sandbox boundary to the worktree. The brief-construction lesson applies at authoring time: a file set must be closed under the test surface, and the closure is computed by searching the test tree for each changed file's basename. The `/task-queue` prompt (`.agents/drafts/task-queue.md`, draft pending operator review) models this: it defines fork, join, and re-queue as the machinery, and the caller supplies the tasks and their owned files.

**A skill's name and description are its signpost.** A skill is advertised by its name and its description, and its body loads only after a reader decides, so those two fields carry the words that steer, and the description summarises to the name. The judgement is the `principle-skill-signposting` skill at `$AGENT_HOME/agent/skills/principle-skill-signposting/SKILL.md`.

## A fast path names its source of truth

A workflow document may inline a distillation of a rule for context efficiency: the inline names the source of truth, and where staleness would mislead it is labelled a convenience copy. The judgement and the fast path are `principle-single-source-of-truth` at `$AGENT_HOME/agent/skills/principle-single-source-of-truth/SKILL.md`, which is their only source of truth.

The source of truth is decided by the kind, not by the layer, per `### Norm kinds` in [`agent_workflow.md`](../reference/agent_workflow.md#norm-kinds).

Construct defensively against two decay modes, both the delete test applied to an instruction surface: `communication-principle-cut-what-carries-nothing` at `$AGENT_HOME/agent/skills/communication-principle-cut-what-carries-nothing/SKILL.md`. A **no-op** is an instruction the agent already obeys by default. **Stale accumulation** is content kept because removing it feels risky.

The diagnostic register for these checks is `## The diagnostic register` in the [`doc-maintenance`](../../workflow/coding-agent/skills/doc-maintenance/SKILL.md) skill. The prescriptive rules are here and in [`agent_workflow.md`](../reference/agent_workflow.md#prompt-templates); the register lists the signs to look for.

## A workflow document owns the scope it declares

A workflow document owns the scope it declares, holds everything that scope owes, and describes no work outside it. The judgement is the `principle-own-the-scope-you-declare` skill at `$AGENT_HOME/agent/skills/principle-own-the-scope-you-declare/SKILL.md`, which is its only source of truth. A top-down view of the whole flow belongs to a concept document or an ADR, and that document names the steps rather than replacing them.

## The workflow handoff pattern

A runbook that ends by handing to another prompt names the boundary in four moves. The judgement is the `communication-principle-hand-off-by-naming-the-boundary` skill at `$AGENT_HOME/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md`, which is its only source of truth. Four prompts apply the shape: [`/iter`](../../workflow/coding-agent/prompts/iter.md) and [`/plan`](../../workflow/coding-agent/prompts/plan.md) hand to `/wrapup` Part B, [`/sidequest`](../../workflow/coding-agent/prompts/sidequest.md) hands the same way, and [`/document`](../../workflow/coding-agent/prompts/document.md) hands at its close.

## A reference resolves where the workflow document runs

A reference is legal when its target is delivered to the reader the citing document reaches. An image-mounted document may cite another image-mounted root, or a project root the project's own setup fills. A document read only where the repository tree is present may cite anything, because its reader holds the tree. Where nothing delivers the target, the citing document states the rule, which is what promotion looks like when the dependency is a rule. A path under `.agents/skills/` is legal from a shipped document only where `initialize` seeds that name, because the seeding is what delivers it. Reach and delivery are axes of [`documentation_taxonomy.md`](../reference/documentation_taxonomy.md#reach), and they belong to a root rather than to a document.

A prompt runs at its image path. A skill runs from the root that carries it, `$AGENT_HOME/agent/skills/<name>/` for a provider-scoped skill and `.agents/skills/<name>/` for a project-scoped one. The harness prompts run from `/opt/workflow/agent/prompts/`, from `src/reasoning/agent/prompts/`. A workflow module's prompts run from the module's own root, `/opt/workflow/agent/modules/<module>/prompts/`, from `workflow/<module>/prompts/`, because the module is the unit a provider enables or leaves out. A provider's own prompt runs from that provider's root: pi's `pi-agent.md` runs from `$AGENT_HOME/agent/prompts/` -- `/home/agentuser/.pi/agent/prompts/` -- which the image seeds from `src/reasoning/providers/pi/config/agent/prompts/` through the config template. The repository tree is not there. The link check resolves a link in an instruction file in the image's path space rather than the repository's, so a target that exists only in the repository is a finding, and a link in the old repository-relative form no longer passes.

A prompt links a document that ships. The policy corpus ships at `/opt/sandbox/docs/policies/`, and the reference layer ships beside it at `/opt/sandbox/docs/reference/`. The link names the path the document has in the image, which reads the same from every instruction root and needs no depth arithmetic. A prompt in one instruction root links a document in another by the image path, not the source path.

A prompt names a document that does not ship -- a record, a draft, an ADR, a development document -- in plain text or a code span. Name it by the path a reader can find, and do not link it: the link would pass no reader in the container and fail the check. A reference to a project file, such as the project `AGENTS.md` or `devlog/roadmap.md`, is the same case, because the project tree is the reader's working directory rather than the prompt's.

When the content behind the reference matters to the agent working in the container, it belongs in the prompt or in a shipped file, and the record is the place the decision is argued -- not the place the running agent is sent.

The same rule covers the inverse: a rule whose only source of truth is a record is unreachable from the container, whether or not a link points at it. If the agent must obey it, it is stated where the agent reads.

The rule holds for a bundled document too. A document under `docs/reference/` or `docs/policies/` ships into the container, where the repository tree is absent, so a link from it reaches only a path that ships: a relative link between the two bundled folders resolves because their destinations keep the repository's shape, and an image path resolves for the same reason. A target that ships nowhere -- a record, an ADR, a development document -- is named in a code span carrying its repository path, never linked. [`linking.mjs`](../../scripts/lint/linking.mjs) fails the gate on a link from a shipped file that resolves only in the repository.

## Naming

A workflow document's name states its subject, not its mechanism. Prefer a noun phrase that names the work (`task-queue`, `milestone-close`) or a gerund that names the activity (`documentation-pass`). Avoid vague names (`helper`, `utils`) and names that restate the loading mechanism.

A name changes when its scope changes. Rename a document whose name no longer matches its subject, and run a doc pass over it at the same time.

## Draft status and the switch-over gate

A prompt or skill that is not yet operator-reviewed is a draft. The durable gate is the location: drafts live in `.agents/drafts/` -- a root the frontmatter gate does not scan, the dispatch conventions do not read, and live dispatch never references -- so an unreviewed prompt is structurally unreachable by the run paths that would trust it. The file itself carries `**Status:** draft` as the human-readable marker. A draft is released from draft status only with explicit operator direction; the release is one commit that moves the file from `drafts/` into its live root (or the agent-facing prompt tree), runs a documentation pass over it at the same time, and the move is the promotion -- there is no separate promotion step to forget. A prompt written by an autonomous worker unit is a draft by default, whatever its author claimed; the `maintenance` dispatch prompt's premature switch-over (it became load-bearing in the session that wrote it, and carried a merge-back contract that produced seven `merge:` commits) is the recorded incident this gate exists to stop.

## Compliance

The per-prompt quality passes read this document and apply it to one prompt each, starting with `/task-queue`. Each pass must name what it changed and why against a specific rule here. The `fanout` doc pass applies the same reading to that prompt. A session that writes a new prompt or skill applies it at authoring time.

The [`conventions.md`](conventions.md) index links here as the canonical owner for workflow-document authoring. [`doc-maintenance`](../../workflow/coding-agent/skills/doc-maintenance/SKILL.md) routes workflow-document prescriptive rules here. [`agent_workflow.md`](../reference/agent_workflow.md) links here from the "How the Workflow is Expressed" section, so a reader from the model finds the authoring bar. The `fanout` rename and doc pass read against this document.
