---
description: Bootstrap the agent-sandbox content layer on a project. Investigates the actual project state first, then creates only the records that are missing.
argument-hint: "[workflow intent and branch line - optional; e.g. full loop, work lands on main]"
---

> $@

## Mandate

You are initializing the agent-sandbox content layer on this repository. The harness plumbing is already provisioned: pi config, prompt templates, staging paths, and the diff pipeline all work. Your deliverable is the content layer - the project records that check-ins and iterations consume.

Two rules govern this run.

First, never assume the project's completion state. The repository may be an empty git init, or it may carry mature conventions. Investigate, classify, then act.

Second, write no file before the operator answers the decisions section. Ask for the two top decisions as soon as the gap report is ready; collect the rest during this iteration.

## State investigation

Investigate before any file output. Do not write files during the investigation. Apply grep-first read discipline when inspecting the project.

Delivery and git:

- `git status`, `git log --oneline -5`, `git branch -vv`. Is this a fresh repo or a historical one? Read the current branch against `main`: commit count and time ahead and behind. This decides where the delivery commit lands.
- Read `.gitignore`. Is `.env` excluded? Assume no credentials exist in this container either way.

Harness records - record each as present, missing, or stale:

- Repo-root `AGENTS.md`, the project layer
- `devlog/roadmap.md`, including its `active-milestone` frontmatter
- `docs/operations/` policy set: `iteration_policy.md`, `git_policy.md`, `documentation_policy.md`, plus `discussion_policy.md` and `adr_policy.md`
- `devlog/handovers/`
- `devlog/AGENT_FEEDBACK.md` and `devlog/GOTCHAS.md`
- `devlog/discussions/`

Project conventions - evidence of life, in whatever form it exists:

- Build and test: Makefile, CI configuration (`.github/workflows/` and similar), test framework and its directory, linting setup
- Language and style: source files, package manifest, formatter configuration. Extract style rules from code and comments; do not invent them.
- Documentation: readme, `CONTEXT.md`, `docs/adr/`, any existing architecture docs

Environment:

- Which runtimes exist in this container: python3, node, make, pytest, and anything the project needs. This decides the verification contract wording.
- Where the policy sources live: `/opt/sandbox/docs/operations/`
- Whether `~/workspace/input/` exists for operator-supplied files

## Classify

| State | Trigger | Action |
|---|---|---|
| fresh | git repo; no harness records, no conventions | Create everything in the materialize section. |
| conventions-present | code, tests, and CI exist; no harness records | Create the records. Extract the conventions from the code; do not rewrite them. |
| partial | some records exist | Fill the gaps. Repair stale links. Keep sound content. |
| initialized | records exist and the policy links resolve | Validate against this prompt's checklist. Report. Change nothing unless the operator asks. |

## Report gaps

Present the record table: one row per record, its status, and its source - copy from `/opt/sandbox/docs/operations/`, or write new.

Name the expected deviations; do not treat them as breakage:

- Dead `docs/operations/` links on a first run are expected before the setup; they must resolve after it.
- `/opt/sandbox/lib` differs between the two containers by design. A file missing in one container is not a regression.
- `/package-branch` names a capability, not a filesystem path. Verify the tool at first package time.
- Skills that assume `CONTEXT.md` and `docs/adr/` are inert until that content exists. That is fine.

## Decisions

Answer these two first. They decide what gets created at all.

1. Workflow intent: the full loop (roadmap, check-ins, one typed commit per iteration, handover chain), or a light mode (records only, no handovers, no `AGENT_FEEDBACK.md` and `GOTCHAS.md` files)?
2. Branch line: does the current branch stay the working line, or must work land on `main` first? If the branch is far ahead of `main`, state the numbers and ask. Never guess.

If the argument already names the workflow intent and the branch line, use them; ask only for what is missing.

Answer these four during this iteration.

1. Project primer: one to three sentences on what the project does; which parts are current and which are legacy; where config lives; anything that must not be touched.
2. Goal and definition of done: the first milestone line for `roadmap.md`.
3. Verification contract: tests run operator-side or in the capability layer - this container may lack the runtimes. State the test command. State whether network calls are permitted; assume offline-only unless the operator says otherwise.
4. Convention overrides: commit-type vocabulary, language, and whether feedback and gotchas entries are welcome.

## Materialize

Only after the decisions. One iteration. In this order.

1. `docs/operations/` - copy the minimum policy set verbatim from `/opt/sandbox/docs/operations/`: `iteration_policy.md`, `git_policy.md`, `documentation_policy.md`. Add `discussion_policy.md` and `adr_policy.md`. The repository owns its copies; the policies are generic by design. These files are the link targets and wording authority for what follows.
2. Repo-root `AGENTS.md` - the project layer. Contains the primer from decision 3, links to the policy set, the verification contract from decision 5, and the workflow intent from decision 1. Follow the wording rules of `documentation_policy.md`.
3. `devlog/roadmap.md` - the `active-milestone` frontmatter, the goal and definition of done from decision 4, and the first task row: the setup iteration itself, closing with handover 1.
4. `devlog/handovers/` - the directory, ready for handover 1 at this wrap-up.
5. `devlog/AGENT_FEEDBACK.md` and `devlog/GOTCHAS.md` - empty accumulation files, only under the full loop.
6. `devlog/discussions/` - create it only when the first design doc lands. Not now.

The delivery commit lands on the branch from decision 2.

## Verify before close

- Every link inside the new `AGENTS.md` and `roadmap.md` resolves inside the repo.
- `git status` shows exactly the intended files, on the decided branch.
- The record checklist of this prompt matches reality: nothing the operator asked for is missing.
- A fresh check-in would yield a clean inventory with no dead links.

## Close

Present a short summary: the state class, the files created, the two decisions as recorded, and the verification contract in force. The first wrap-up produces handover 1 and the loop starts. Under light mode, name what is intentionally absent.
