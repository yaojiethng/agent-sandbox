---
date: 2026-10-16
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Implementation
status: Closed
---

# Handover - The dispatch seam consumer path and the ownership question

## Objective

Make the `opencode-dispatch` skill reach the runner seam in any project, and file the question of who owns dispatch logic for M3.6.3.

## Scope

The `opencode-dispatch` skill's reference to the runner seam, in its script and its skill file, and the design record that holds the ownership question for M3.6.3. The operator-owned `model-recommendations.md` lives outside the repository, so its values are not part of this record. The launch-site sweep and the seam's own behaviour are out of scope; the sweep is M3.6.3's.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill sources the image's seam, not the project tree | `grep -n 'source /opt/sandbox/lib/dispatch.sh' src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh` | Agent [x] |
| The installed skill copy matches the repository source | `diff -q` the repository path against `$AGENT_HOME/agent/skills/opencode-dispatch/dispatch.sh` | Agent [x] |
| The script is shellcheck clean | `shellcheck -S warning` on the script | Agent [x] |
| The ownership question is filed for M3.6.3 | the roadmap row references the design record | Agent [x] |
| Gates clean | `bash scripts/lint.sh`, clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill sources `/opt/sandbox/lib/dispatch.sh` | a container-deployed file follows the container convention; the project-tree path exists only when the project under work is agent-sandbox itself | the script header; [`context_resolution.md`](../../../docs/development/context_resolution.md) |
| The seam keeps its shared home | `scripts/dispatch.sh` is a first-class consumer, and all of `src/libs/` is baked into every provider image; bundling the seam with the skill would fork the flag mapping | the design record |
| The ownership question is deferred to M3.6.3 | it reverses a settled design assumption, so it earns its own iteration rather than a silent change here | the roadmap row; the design record |
| The seam is held as an M3.6 stopgap | it serves the current goal, and the ownership question is M3.6.3's to answer | the design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The seam has one live consumer, the `opencode-dispatch` skill. The front door `scripts/dispatch.sh` has no live caller, and the `.agents/drafts` launch sites are not invoked. | measurement | the M3.6.3 sweep's justification; the design record |
| `pi-reviewer-dispatch` pins its reviewer pair and does not read `_REVIEWER`; the pin is design, because the review task needs a specific reviewer to be effective. It is a specialized dispatch, not a seam launch site. | design boundary | the launch-site sweep records it as a keep-own-form site |
| The model resolver tries an exact `id` match before a fuzzy match, so the full id `z-ai/glm-5.3-flash` binds to itself and not to the `flashx` or `:batch` variants. | measurement | no action; the `AGENT_FEEDBACK.md` entry holds |

## Completed

| File | Change |
|---|---|
| [`dispatch.sh`](../../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh) | sources `/opt/sandbox/lib/dispatch.sh` instead of the project tree |
| [`SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md) | the seam path in the form description |
| [`20261016-design-active-dispatch_ownership.md`](../../discussions/20261016-design-active-dispatch_ownership.md) | new: the ownership question, its options and a provisional lean |
| [`roadmap.md`](../../roadmap.md) | the M3.6.3 row `Who owns dispatch logic` |
