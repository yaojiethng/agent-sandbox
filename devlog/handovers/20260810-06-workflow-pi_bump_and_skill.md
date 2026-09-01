# Agent Handover

**Date:** 2026-08-10
**Milestone:** (none — M7 Dependency Security parked; cross-cutting provider maintenance + skill codification)
**Type:** Workflow (single `workflow:` commit)
**Status:** Closed

## Objective
Bump the pinned pi version in the provider Dockerfile and its config record, and
codify the exact pi bump procedure into a reusable skill so future sessions do
not reconstruct the steps.

## Scope
- Perform the pi bump `0.80.9` → `0.84.1`:
  - `src/reasoning/providers/pi/base.dockerfile` — update pinned
    `@earendil-works/pi-coding-agent@0.80.9` → `@0.84.1`
  - `src/reasoning/providers/pi/config/agent/settings.json` — update
    `lastChangelogVersion` to `0.84.1`
  - `devlog/roadmap_future.md` — refresh stale pinned-version note in the M7
    Dependency Security checklist from `0.75.4` to `0.84.1`
- Add a skill that codifies the full bump procedure (what to edit, how to force
  a rebuild, how to verify).
- Live `~/.pi/agent/settings.json` (current container) will be reseeded by copy-in
  on the next container start; no manual edit needed there.
- **Not in scope:** image rebuild (needs Docker on the host — not available in
  this reasoning container); lockfile for transitive deps (existing open roadmap
  item); changelog entry (bumps are not milestone completions).

## Carried forward
None.

## Acceptance criteria
- The three repo files carry the new pin/record/note and the file contents are
  internally consistent (all `0.84.1`).
- A `workflow/` skill exists documenting: version discovery, the exact files to
  edit, the rebuild command (`agent-sandbox build --rebuild` — required because
  the provider base tier only builds when missing), and the verification steps.
- Two commits: `chore:` (bump) and `workflow:` (skill).

## Hot files
| File | Why in scope |
|---|---|
| `src/reasoning/providers/pi/base.dockerfile` | Pinned pi version to bump |
| `src/reasoning/providers/pi/config/agent/settings.json` | `lastChangelogVersion` record |
| `devlog/roadmap_future.md` | Stale pin note under M7 Dependency Security |
| `src/reasoning/agent/skills/pi-bump/SKILL.md` | New skill codifying the procedure |

## Decisions made this session
| Decision | Rationale | Where recorded |
|---|---|---|
| Pin whatever version `pi update --self` actually installs (not a pre-picked target) | Guarantees repo pin and running container never drift | `pi-bump` skill |
| `lastChangelogVersion` bump must happen AFTER the changelog from `pi update --self` is reviewed | An older `lastChangelogVersion` triggers pi to show the changelog on the version's first start; matching it suppresses the repeated changelog on subsequent starts | `pi-bump` skill |
| Update is in-container (`pi update --self`), no Docker rebuild | pi lives in the container; rebuild tier 2 only builds when missing and would pull latest anyway | `pi-bump` skill |
| (operator) KEEP `PI_SKIP_VERSION_CHECK=1` in the compose overlay | Preserves clean startup behavior (no version-check noise). `pi update --self` accordingly cannot run in-container — documented, not worked around | `docker-compose.pi.yml` unchanged |
| (operator) Source latest version by calling the API directly | Since `pi update --self` can't run in-container, query `https://pi.dev/api/latest-version` manually to source the target. Same result as the probe | `pi-bump` skill |
| (operator) Runtime update lands at image rebuild; not in-container | Chose `Option A`: commit repo pins; the running container updates pi at next rebuild (root `npm install -g`), because `/usr/local` is root-owned and not writable by `agentuser` at runtime | `pi-bump` skill |
| (operator) Single `workflow:` commit for all changes | Wrap the whole bump + skill in one workflow commit, not two | commit message |

## Mid-session findings
| Finding | Type | Impact |
|---|---|---|
| Docker binary is not available inside this reasoning container, so the image rebuild must be run on the host by the operator (`agent-sandbox build --rebuild`). | scope change | Rebuild step is documented in the skill, not executed here |

## Completed this session
| File | Change summary |
|---|---|
| `src/reasoning/providers/pi/base.dockerfile` | Bumped pin 0.80.9 → 0.84.1 |
| `src/reasoning/providers/pi/config/agent/settings.json` | `lastChangelogVersion` 0.80.9 → 0.84.1 |
| `devlog/roadmap_future.md` | Refreshed stale M7 Dependency Security pin note to 0.84.1 |
| `src/reasoning/agent/skills/pi-bump/SKILL.md` | New skill codifying the bump procedure |
| `~/.pi/agent/settings.json` | `lastChangelogVersion` bumped to 0.84.1 (live record; outside sandbox, reseeded on next start) |

## Deferred items
None.

## Next session
Context-only. The operator must run the documented rebuild + verification steps
from the host to complete the runtime side of the bump.
