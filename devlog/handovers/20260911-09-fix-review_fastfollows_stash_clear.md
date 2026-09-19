# Agent Handover

**Date:** 2026-09-11
**Milestone:** M2.6 -- Session Persistence (cross-cutting: seed correctness)
**Type:** Fix
**Status:** Closed

## Objective

Apply the must-fix findings from the thermo-nuclear review of `7e06c4b..HEAD` (fresh `pi -p` subagent, verdict: ship, fast-follows recommended).

## Scope

- Finding 1 (doc): ADR records the unreachable-objects residual of `git stash clear` (refs removed; stash commit objects remain in the volume object store until gc; not reachable through normal git commands or the diff pipeline).
- Finding 2 (code): seed self-verification tripwire checks the `git stash list` exit status -- a git failure dies instead of reading as an empty stack.
- Finding 3 (cosmetic): COPY column alignment in hermes/opencode provider dockerfiles.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | ADR 2026-09-11 entry states the residual explicitly | read | Agent -- pass |
| AC2 | Tripwire dies on git failure (no fail-open path) | read + test | Agent -- pass |
| AC3 | Suite passes | suite | Agent -- pass (734/734) |
| AC4 | Review findings 3 and 5 dispositioned (3 fixed; 5 noted pre-existing, no change) | read | Agent -- pass |

## Completed

| File | Change |
|---|---|
| [`docs/adr/sandbox_delivery_model.md`](docs/adr/sandbox_delivery_model.md) | 2026-09-11 entry records the unreachable-objects residual and its acceptance rationale |
| [`src/capability/seed_volume.sh`](src/capability/seed_volume.sh) | Tripwire checks `git stash list` exit status; a read failure dies instead of reading as an empty stack |
| [`src/reasoning/providers/hermes/provider.dockerfile`](src/reasoning/providers/hermes/provider.dockerfile), [`src/reasoning/providers/opencode/provider.dockerfile`](src/reasoning/providers/opencode/provider.dockerfile) | prompts COPY column alignment restored |
| [`devlog/roadmap.md`](devlog/roadmap.md) | (no change required) |

## Deferred items

None (finding 3's tripwire-branch test coverage accepted as a known gap -- fault injection out of scope; finding 5's `set -euo pipefail` sourcing injection pre-dates the batch, no change).
