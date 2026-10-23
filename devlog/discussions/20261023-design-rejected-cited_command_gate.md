---
status: rejected
date: 2026-10-23
---

# Design - A cited command resolves to a file

## Context

The roadmap row **A cited command resolves to a file, checked mechanically** is the last of the prompt-surface rows. Two prompts named commands that did not ship -- the `-work` dispatch drafts -- and a reader found them: once by the operator asking why a prompt cited a draft at all, once by a hand pass over both files. The chart carries the query as `Dangling dispatch` in `## Checks`, and the chart says in its own opening that the checks are read by hand today.

A hand query is the state the row is filed against. This design makes one of them mechanical over the surface where the defect occurred.

## What the tree says

Measured this iteration, not assumed. A token is a candidate when it is a slash, a lower-case word, and nothing else: a following or a preceding slash disqualifies it, so a path cannot match however it is written.

| Measurement | Result |
|---|---|
| Prompt files under `workflow/coding-agent/prompts/` | 17 |
| Distinct command tokens in those files | 13 |
| Tokens that resolve to a sibling file | 12 |
| Tokens with no file | `/auto` |
| Tokens that are a real command and no prompt file | `/package-branch`, the one capability the prompt tree names |
| Path shapes matched by the token rule | 0 -- `/opt/sandbox/...` and `/docs/...` carry a second slash |
| Bare tokens outside a code span | 8, every one a heading or a frontmatter description naming a command, as in `# /commit - The Delivery Commit` |

Reading only code spans would therefore miss a heading that names a command, so the rule reads the whole file.

The wider instruction surface does not have this shape, and the measurement says why:

| Root | Tokens with no prompt file | What they are |
|---|---|---|
| `docs/reference/` | `/tmp`, `/src`, `/dest` | path fragments written in backticks |
| `docs/reference/` | `/sequential-work`, `/parallel-work` | the two `-work` drafts, named deliberately as drafts |
| `.agents/skills/` | none | -- |
| `src/reasoning/providers/pi/config/agent/skills/` | `/fork`, `/tree` | pi's own TUI commands |

Four classes a repo-wide gate would have to resolve, and one of them, the path fragment, cannot be told from a command by shape. That is a design in its own right, so it is a separate unit rather than a rider on this one.

## Options Considered

1. **A shell gate over the prompt tree, resolving a token to a sibling file, plus two declared sets.** The subject is the closed domain the defect lives in: a prompt may name a command only where a prompt file carries it.
2. **A repo-wide gate with a resolution table per root.** Four namespaces today, and the path-fragment class defeats the shape rule, so the table would carry the exceptions rather than the declaration.
3. **A Node module under the existing document-shape gate.** That gate parses instruction documents for their shape; a token query is a different subject, and the two would share a walk only by coincidence.
4. **Add the query to the chart's `## Checks` as prose.** That is the state the row is filed against.

## Decision

Option 1. One gate, `scripts/check_prompt_commands.sh`, in `scripts/lint.sh`.

| # | Decision | Rationale |
|---|---|---|
| D1 | The subject is every `.md` under `workflow/coding-agent/prompts/`, walked | A new prompt is covered with no gate edit, and the domain is the one the defect lives in |
| D2 | A token is `/` plus a lower-case word, with a slash on either side ruling it out; the whole file is read, including headings and frontmatter | The measurement above: 13 tokens, no path, and 8 command mentions that a code-span-only rule would miss |
| D3 | A token resolves when `<token>.md` is a sibling prompt file | One rule a reader can check without running the gate |
| D4 | A token resolves when the provider layer's `Tools you have access to` list names it, read from `src/reasoning/providers/pi/config/agent/AGENTS.md` | The image's tool surface is declared there, so a gate that hardcodes the names goes stale on the next tool. Precedent: `check_instruction_surfaces.sh` reads the loop inventory from the same layer's table |
| D5 | A token resolves when the gate's `RESERVED` array names it: `/auto` and `/goal`, each with the reason it is absent | A reservation is a claim about a future milestone, so it is declared with its citation and reviewed like code |
| D6 | Anything else is a finding, printed as `file:line token` | The same report shape as the other gates, so a reader needs no new convention |
| D7 | The gate fails closed: no prompt files, or no provider tool list, is a finding | A gate that passes because it read nothing is the failure mode the chart's `Unsatisfied entry` check names |
| D8 | The gate is blocking, and the chart's `## Checks` stops saying every check is a hand query | The chart is the maintenance surface; it states which queries a script now holds |

## Rejected

- **R1 -- A data file listing every command with its source.** It duplicates the directory and drifts from it, which is the defect class this unit exists to catch.
- **R2 -- Extending the walk to skills and reference documents now.** The measurement's four classes each need a resolution rule, and the path fragment needs one that shape cannot give.
- **R3 -- Dropping the slash from `/package-branch` in the two prompts that name it.** The provider layer names it with a slash, so the prompt would disagree with the tool surface, trading one defect for a worse one.

## Consequences

The derived-artifact census (design record `20261023-design-settled-derived_artifacts.md`) parks this design at `draft` and adds a second subject: the chart's `## Commands` table is a 17-row catalog that asserts equality with the prompt directory and no gate regenerates it. The same query answers both, so the row is worked as one unit when it is worked.

The census also found `/auto` carried by two artifacts -- this ADR's M4 reservation and `.agents/prompts/auto.md` -- so a token resolving to a file is not evidence that it resolves to the right one.

One gate and its test file join the umbrella. The chart's `Dangling dispatch` query keeps its subject, the command table, and the gate takes the prose; the two are stated side by side rather than merged, because they read different objects.

The wider instruction surface becomes a roadmap row carrying the measurement above as its brief: four namespaces, one of them not decidable by shape.

`bootstrap.md` states that `/package-branch` names a capability rather than a filesystem path. The gate now enforces that reading instead of trusting it.

## Outcome

Rejected on 2026-10-23, after the operator ruled on the citations half. Pi rejects a command the operator types when no prompt carries it, so that failure is loud at the point of use. The two bad tokens this design was filed against had already been removed, and a resolver over prompted commands cannot be complete, because `/auto` routes to a skill package the operator installs. Gating our prompts against a surface we do not own is coverage the tree does not need.

The second subject survives on its own terms. The chart's `## Commands` table asserts equality with the prompt directory and no gate holds it, so it is filed as an M3.3.3 row in handover `20261023-16`. The measurement in `## What the tree says` is its brief.
