# The handoff contract

**Status:** settled

## Context

The workflow ships a **default convention-skill corpus**: seven stubs under the `initialize` skill's `assets/conventions/`, which `initialize` installs into the project's `.agents/skills/`. Nothing reads it. Every workflow step still carries the workflow's own record paths - `devlog/handovers/`, `devlog/roadmap.md`, `docs/adr/` - so a project's conventions are never reached and the corpus is inert.

Fourteen prompts and six skills are affected. The roadmap row is `Wire the handoff into each workflow step`; this document settles the contract the wiring follows.

## Options Considered

The handoff form, being what a step writes when it needs a project convention:

- **A - name the convention and its resolution path.** The step names the convention and the path `initialize` installs, `.agents/skills/<convention>/SKILL.md`. Deterministic, and a missing file is a checkable failure.
- **B - name the convention alone.** The step names the convention and relies on pi's skill discovery. pi keeps the first discovered skill when two share a name, so a project skill that collides with a shipped one is resolved by load order rather than by the step.
- **C - state the need in prose.** The step describes what it needs and the agent resolves the project's layout. The least binding, and the least checkable.

The failure behaviour, being what a step does when the convention-skill is absent or still the stub:

- **State and continue on the workflow's default, marked as a fallback.** Keeps the run moving; the default answers for a project that never chose.
- **State the failure and stop.** Preserves the project's authority; the workflow becomes an enclosing rule.
- **State the failure and hand control to the agent.** The step does its part - it names the gap - and the agent reasons over it with the steering it has loaded.

## Decision

**The handoff form is A.** A step that needs a project convention names the convention and the path `.agents/skills/<convention>/SKILL.md`, and reads that file for the project's structure. The path form is chosen over discovery because it does not depend on which skill pi loaded first, so a name collision cannot change where a step reads.

**The failure behaviour is the hand-over.** At that step control has already passed to the agent. The step states that the skill is absent or is the seeded stub; whether the agent stops or continues is its steering's decision, not the workflow's. The workflow prescribes neither. This holds the line the iteration `20261014-05` drew: the workflow imposes nothing, and the stub is a failure mode for the agent to reason over.

**The two halves.** The workflow keeps the **procedure** - the sequence a step runs. The project's convention-skill holds the **structure** - where the records live and what format they take. A step reads the project's skill for the structure and applies the workflow's procedure over it.

**The step-to-convention mapping.** Each step names the conventions it needs:

| Step | Convention(s) |
|---|---|
| `bootstrap` | `task-list`, `work-log`, `decision-records`, `docs` |
| `gm` | `task-list`, `work-log` |
| `backlog-triage` | `task-list` |
| `iter` | `task-list`, `work-log`, `decision-records`, `docs`, `git-discipline`, `testing` |
| `plan` | `task-list`, `decision-records` |
| `sidequest` | `work-log`, `task-list`, `decision-records` |
| `document` | `docs` |
| `milestone-start` | `task-list`, `work-log` |
| `milestone-close` | `task-list`, `work-log`, `decision-records` |
| `wrapup` | `task-list`, `work-log`, `decision-records`, `git-discipline`, `testing` |
| `record-correction` | `work-log`, `decision-records`, `git-discipline` |
| `merge` | `git-discipline` |
| `rebase` | `git-discipline` |
| `package-eval-snapshot` | `evals` |
| `check-in` (skill) | `task-list`, `work-log` |
| `handover-maintenance` (skill) | `work-log` |
| `roadmap-maintenance` (skill) | `task-list` |
| `doc-maintenance` (skill) | `docs` |
| `eval` (skill) | `evals` |
| `initialize` (skill) | all seven |

The `communication` standard is not a convention and takes no handoff. It is a practice read from the project's always-loaded steering and applies to every text a step writes.

**Failure modes.** A step states the one it meets and hands over:

| Mode | What the step states |
|---|---|
| **Absent** - `.agents/skills/<convention>/SKILL.md` does not exist | the convention is unprovisioned; `initialize` can seed it |
| **Stub** - the file holds the seeded stub | the convention is unstated; the stub's own text says so |
| **Collision** - a project skill shares a name with a shipped skill | not a handoff failure: the path form reads the project's file, and the shipped skill is loaded by the module |

## Consequences

The corpus becomes load-bearing: `initialize` installs the files a step reads, so an uninitialized project meets the absent-mode failure at every handoff.

The mapping has two gaps the corpus does not cover:

- The devlog's `AGENT_FEEDBACK.md` has no convention. `bootstrap`, `check-in`, `wrapup`, `milestone-start` and `milestone-close` all carry it. It is a work record beside the handover and the discussion, so the fit is `work-log` with a third structure, `assets/feedback.md`. Recorded as an open question; the operator settled the seven-convention list, so this is an amendment to it.
- The changelog and `roadmap_future` resolve under `task-list` as the roadmap's companions, since `roadmap-maintenance` maintains all three. No new convention.

The wiring is a separate iteration: this document settles the contract; changing fourteen prompts and six skills to use it is the row's implementation stage.
