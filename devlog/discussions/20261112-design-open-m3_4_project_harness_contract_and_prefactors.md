# M3.4 - the declaration boundary and the prefactor set

**Status:** open

## Context

M3.4 moves the environment declaration [plane](../../docs/reference/terminology.md#plane) from the harness to the project. A planning session on 2026-11-12 restated the goal and tested the milestone's framing against the tree. Four defects and one gap came out of it, and the operator settled the vocabulary and the owner question.

The milestone was written as a pile of artifacts with no row that asserts the outcome it exists for, and with a close rule ("a sub-milestone closes on a live `spread` run") that cannot apply to its own model and primitive sub-milestones. It named a live test, `spread`, that is dormant and whose reproduction material was never kept, so no row states what a run would prove.

A vocabulary audit found three words carrying more than one sense, and the gate that was built to hold the reserved vocabulary cannot see any of them: `scripts/check_vocabulary.sh` scans only manifest-declared shipped roots with one pattern, qualifier plus `layer`.

## Options Considered

**The plane's owner.** *Contested, with the project as target owner* keeps the transition visible in the model, but contradicts R2 of [`container_execution_model.md`](../../docs/adr/container_execution_model.md), which requires exactly one owner. *The harness owns it today and M3.4 moves it* keeps R2 true as written and gives the milestone a mechanical close check, because `system_overview.md`'s owner cell is the evidence. Chosen.

**The word for an ownership slice.** *Keep `surface` and define it* leaves one word carrying three senses: instruction root, maintenance surface, and the ownership slice. *Name planes by their concern and reserve `interface` for the access contract across one* removes the architecture sense from `surface` and leaves it entirely inside the workflow vocabulary. Chosen. `seam` becomes an unreserved general word, as `unit` already is, and always takes a qualifier.

**The declaration's direction.** *Project to harness only* is what the milestone states, and it is incomplete: the entrypoint installs a hook into every project's `.git/hooks`, and the seeder writes the harness's git identity into every project's `.git/config`. *Bidirectional* states both directions and makes the second one reviewable. Chosen.

**Trust classification.** *The whole declaration is trusted*, *the whole declaration is untrusted*, or *per element*. Not settled; see `## Consequences` and the open question below.

**What proves a prefactor landed.** *The live-run rule applies to every sub-milestone* makes M3.4.1 and M3.4.2 unclosable, since neither changes runtime behaviour. *Four obligations, stated below* lets a prefactor land silently and still be falsifiable. Chosen.

## Decision

The operator's rulings, 2026-11-12:

1. `seam` and `interface` join the `## Usage` treatment `unit` already has in [`terminology.md`](../../docs/reference/terminology.md#usage): not reserved, ordinary in compounds, always qualified, and where a sentence means the plane or the plane's access contract, name that.
2. A plane is named by its concern, so the fifth plane is the **verification plane**, and the environment declaration's access contract is the **declaration interface**.
3. The environment declaration plane is **harness-owned today**; M3.4 moves it to the project. The model keeps R2 intact.
4. The declaration is **bidirectional**: what a project declares to the harness, and what the harness may write into a project's tree.
5. The milestone's objective states the goal in the terms above, and the live-run close rule is scoped to the sub-milestones that consume the run.
6. A prefactor's acceptance is four obligations: **preserved** (the suite is green and no existing test was edited to accommodate the change), **load-bearing** (a gate fails when code bypasses the new structure), **sufficient** (one consumer proves the structure carries the next plane's need), and **diff-scope** (no change to an output format, file layout or CLI surface, or the change is named as one).
7. The sample project is a prefactor instrument, shaped as a base plus named cases. Each case carries the roadmap claim it reproduces, the case, and a check that **fails on the unfixed harness**. Byte-hostile and foreign-format cases belong to it as cases, not as fixtures of their own.

## Consequences

### What the harness writes into a project today

Measured 2026-11-12, against the tree at `HEAD`.

| What crosses | Where it lands | Why it should not |
|---|---|---|
| `.git/hooks/pre-commit`, installed on every copy-delivery start | the project's `.git/hooks/` | [`git_hooks.md`](../../docs/adr/git_hooks.md)'s own scope note forbids imposing the hook on a project checkout; the container path does it to every project |
| the handover-format gate inside that hook | `<project>/scripts/check_handover_format.sh` | requires the project to carry a harness script, and every handover commit fails without it. Undocumented in `git_hooks.md`, which names only the Markdown and ShellCheck gates |
| Markdown and ShellCheck policy | any project staging `.md` or `.sh` | a project's lint policy is the project's; the harness's custom rules do not ship, so the gate degrades to tool defaults |
| `user.email agent@sandbox`, `user.name agent-sandbox` | every seeded project's `.git/config` | authorship is project data, and it breaks a project with a signing or DCO requirement |
| `core.fileMode`, from the host | the project's `.git/config` | a harness decision about the project's git behaviour |
| `agent-sandbox.flatten` | the project's `.git/config` | a harness namespace written into project state |
| `SESSION_STATE` keys | the project's `.git/SESSION_STATE` | already filed as M3.4.3's harness-identity split |

What correctly does not cross, and is the pattern to copy: `Makefile` and `.env` live in `SANDBOX_DIR` beside the project, provider context goes to `AGENT_HOME`, and `.workspace/` and `.compose/<sid>.yml` are host-side.

### The prefactor set

Four, in order: the plan write-back this record lands with, the project-harness contract, the trust posture, and the sample project. M3.4.1 and M3.4.2 follow, then the delivery work. The first two are harness-side and change no runtime behaviour; the fixture changes nothing on its own and is the instrument the rest is read through.

Two scoping defects fall out of obligation 6 above. M3.4.1 has no acceptance-criteria section, so nothing states what "lands silently" means for it. M3.4.2 is not a pure prefactor: `env_load`'s ambient precedence, `SANDBOX_DIR`'s runtime derivation, the timestamp format and the relative-time ladder each change observable behaviour, and they are decisions and visible formats rather than cleanup.

### Resolved 2026-11-12

- **The declaration boundary is two contracts, not one.** The name was shorthand, and it merged a declaration with an imposition: a project declares its environment *to* the harness, and the harness writes *into* the project's tree. The directions have different owners, different trust classes and different authorities, so they are one ADR with two halves, [`project_harness_contract.md`](../../docs/adr/project_harness_contract.md), and the phrase "declaration boundary" is retired.
- **Trust class per element.** Declarative fields are configuration: image, toolchain, dependencies, mounts, volumes, services, lifecycle. Executable fields are code: build steps, hooks, lifecycle commands. The distinction is what makes the posture reviewable, and it is the reason a whole-declaration ruling cannot answer the question.
- **Validation is the bijection, not a run.** Every element of the contract has a grant row in `security.md`, and every grant row names its controls; a gate holds the two sets to each other. A run of the sample project validates the interface when it lands, not the posture.
- **The trust prefactor's split.** State the contract; state the posture; hold the bijection. There is no switchover inside the prefactor: the switchover is the interface's delivery half, which the posture gates.
- **The sample project.** Home `tests/fixtures/sample-project/` with a host-run runner beside `scripts/build_probe.sh`, since onboarding and Docker are operator-side. Base plus named cases, each carrying its roadmap claim and a check that fails on the unfixed harness. The first case set is named in the roadmap row. Byte-hostile paths are generated at run time.
- **M3.4.3 splits.** *State the contract* adds no mount, volume or hook, and can land ahead of the posture; *deliver the contract* follows it. The identity split stays with the stated contract; the hook interface, installation persistence and task logs move under delivery.
- **Ordering.** Contract, then posture, then M3.4.3's delivery half. The sample project gates every live run. The sub-milestone numbers are not the sequence, and the milestone's `## Sequencing` paragraph says so.
