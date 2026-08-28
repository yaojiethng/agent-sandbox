# Agent Handover

**Session date:** 2026-05-30
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Session type:** Design
**Status:** Closed

## Objective

Design the `agent-sandbox help` system, flag group taxonomy, and the streamlined dispatch architecture. The output is a design document that specs what changes to make, in what order, and why. No implementation.

## Scope

**Design outputs:**

1. **`agent-sandbox help <subcommand>`** — Spec for a help subcommand that prints a usage string per subcommand. Spec for consistent error handling: invalid flags → print subcommand's usage string (not an ad-hoc error). Cover how usage strings are stored (inline? separate file?).

2. **Flag group taxonomy** — Catalogue of flag groups with their behavioural boundary definitions. For each group: which flags belong, which subcommands share them, what the consistent interface looks like (flag name, value type), and the decision rule for placing a new flag into a group vs leaving it as a subcommand-specific passthrough.

3. **Streamlined dispatch architecture** — Spec for `parse_flags` to only extract universal + group-level flags, forwarding every other flag untouched to the `exec`'d subcommand. No parse-and-re-serialize.

**Not in scope:**
- Implementation of any of the above
- Changes to `scripts/` or `src/` files

**Design questions:** None.

## Carried forward

None.

## Acceptance criteria

| # | Criterion |
|---|---|
| 1 | Design document exists in `devlog/discussions/design-dispatch-cleanup-and-help-system.md` |
| 2 | Document specifies `agent-sandbox help <subcommand>` behaviour, usage string format, and storage location |
| 3 | Document defines flag group taxonomy with grouping criteria and full group catalogue (universal, provider, build, git-state, routing, package, interactive) |
| 4 | Document specifies streamlined dispatch: `parse_flags` limited to group flags, `UNPARSED` array passed through |
| 5 | Document includes implementation sequence (phases 1-3) |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/discussions/design-dispatch-cleanup-and-help-system.md` | Design document produced this session |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Usage strings stored inline in each subcommand script's `usage()` function | Co-locates help with implementation. Each subcommand script is independently executable — `--help` should work when called directly. | Design document rule 1.2 |
| Flag groups are documentation, not code enforcement | The taxonomy catalogs shared flags and their canonical parsers. No group-level variables or enforcement. Shared parsing logic lives in libs/ files called by multiple subcommands. | Design document rule 2.1 |
| `parse_flags` extracts only 3 universal flags (`--name`, `--project`, `--sandbox`) | All other flags pass through via `PASSTHROUGH` untouched. No parse-and-re-serialize. No `rebuild_flags()` or `require_provider_args()` at dispatch level. | Design document rule 3.1–3.2 |
| `agent-sandbox help` uses hardcoded subcommand list | Discovery from filesystem adds complexity. Flagged as future improvement in roadmap. | Design document rule 1.5 |
| `--help` flag triggers `usage()` in each subcommand script | Consistent with `agent-sandbox help <subcommand>` — both paths call the same `usage()` function. | Design document rule 1.2 |
| `require_base_args` is the only validation at dispatch level | Checks `--sandbox`, `--project`, `--name`. Subcommand scripts validate their own required flags. | Design document rule 3.2 |

## Mid-session findings

| Finding | Description | Triaged to |
|---|---|---|
| `rebuild_flags()` and `require_provider_args()` don't need to be at dispatch level | `--rebuild`, `--refresh`, `--provider` pass through to `start_agent.sh` via `PASSTHROUGH`. The dispatch layer doesn't need them. | Design document rule 3.2 — removed from spec |
| Repeat-back-to-confirm is a useful alignment tool but not documented | The pattern of restating understanding after a clarification arose naturally. Should be formalised in AGENTS.md or the grill-me skill. | Future — process doc update |
| Mid-session findings should be written immediately, not accumulated | Findings were generated during grilling but not persisted until the design doc was written. The grill-me skill should recommend inline recording. | Future — grill-me skill update |

## Completed this session

| File | Change summary |
|---|---|
| `devlog/discussions/design-dispatch-cleanup-and-help-system.md` | Design document — help system spec, flag group taxonomy with grouping criteria, streamlined dispatch architecture, 3-phase implementation plan |

## Deferred items

None.

## Next session

Done — see completed session 20260530-02 for implementation.

## Conclusions from this session

- Help system designed: `agent-sandbox help <subcommand>`, hybrid storage (central `help.sh` + inline per workflow)
- Flag group taxonomy defined: 7 groups with clear grouping criteria (multi-subcommand, dispatch-level relevance, identical parsing)
- Streamlined dispatch specified: group flags only, `UNPARSED` array for everything else
- 3 implementation phases sequenced with dependencies
