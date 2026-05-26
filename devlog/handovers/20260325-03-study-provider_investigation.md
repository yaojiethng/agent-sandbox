# Agent Handover

**Session date:** 2026-03-25
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Investigation

## Objective
Close all four provider investigations: Claude Code, Pi, Hermes, and update the parent story.

## Scope
- `investigation_claude_code.md` — resolved and closed
- `investigation_pi.md` — resolved and closed
- `investigation_hermes.md` — resolved and closed
- `story_provider_knowledge_store.md` — all four provider rows updated

## Acceptance criteria

- [x] `investigation_claude_desktop.md` — status Resolved (completed prior session)
- [ ] A second provider can be added under `providers/<n>/` with no changes to `scripts/` or `libs/` — carried from M2.2 implementation sessions; not addressed this session

## Hot files

| File | Why in scope |
|---|---|
| [`docs/discussions/investigation_claude_code.md`](docs/discussions/investigation_claude_code.md) | Resolved this session |
| [`docs/discussions/investigation_pi.md`](docs/discussions/investigation_pi.md) | Resolved this session |
| [`docs/discussions/investigation_hermes.md`](docs/discussions/investigation_hermes.md) | Resolved this session |
| [`docs/discussions/story_provider_knowledge_store.md`](docs/discussions/story_provider_knowledge_store.md) | All four provider rows updated this session |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Claude Code `serve`: Remote Control (first-party); requires claude.ai subscription auth | Outbound HTTPS to Anthropic API; operator connects via `claude.ai/code` or mobile app; no third-party wrapper needed; API key insufficient for this mode | `investigation_claude_code.md` — Resolution |
| Pi `serve`: unsupported; confirmed by Pi developer | No native web UI or remote control equivalent; RPC bridge or open-source web UI over RPC is a viable future path if needed | `investigation_pi.md` — Resolution |
| Hermes `serve`: Open WebUI via compose template | `providers/hermes/` compose template defines Open WebUI service alongside Hermes container; same composition pattern as existing harness | `investigation_hermes.md` — Resolution |
| Hermes Dockerfile complexity: acceptable | Persistent memory and skill creation are genuinely additive for vault workflows; heavier image is the cost | `investigation_hermes.md` — Resolution |
| Compose templates are currently OpenCode-scoped; must be refactored before any second provider `serve` works | Discovered during Hermes investigation; M2.2 implementation prerequisite; needs roadmap task | Handover deferred items |
| No codebase changes from any investigation this session | Investigations are findings-only | This handover |

## Completed this session

| File | Change |
|---|---|
| `docs/discussions/investigation_claude_code.md` | Status Resolved; Remote Control finding recorded; Resolution section written |
| `docs/discussions/investigation_pi.md` | Status Resolved; `serve` declared unsupported; RPC bridge noted as future path; Resolution section written |
| `docs/discussions/investigation_hermes.md` | Status Resolved; Open WebUI compose model recorded; persistent memory capability noted; Resolution section written |
| `docs/discussions/story_provider_knowledge_store.md` | All four provider rows updated to Resolved |

## Deferred items

- Compose templates are currently OpenCode-scoped — must be made provider-agnostic before any second provider's `serve` mode works. Needs a task added to M2.2 roadmap entry.
- `onboard.sh` multi-provider support — all four provider investigations now closed; scoping unblocked.
- Acceptance criterion: "A second provider can be added under `providers/<n>/` with no changes to `scripts/` or `libs/`" — Trigger B cannot fire until met at implementation time.

## Next session

**M2.2 — Reasoning Layer Modularisation — implementation.**

All provider investigations are closed. Next work is implementation:
1. Add compose template refactor task to M2.2 roadmap entry (prerequisite for `serve` on any provider)
2. Scope `onboard.sh` multi-provider support
3. Begin `providers/claude-code/` or `providers/pi/` scaffold

**Watch-out items:**
1. Compose template refactor (OpenCode-scoped → provider-agnostic) must be added to roadmap before implementation begins — it is a prerequisite for `serve` mode on Claude Code, Hermes, and any future provider.
2. `providers/claude-code/run.sh` mode vocabulary: `start`, `dry-run`, `serve` (Remote Control). Remote Control requires `CLAUDE_CODE_OAUTH_TOKEN`; document clearly in provider.
3. `providers/hermes/run.sh` must configure `terminal.backend: local` in the provider image — harness manages isolation, not Hermes.
