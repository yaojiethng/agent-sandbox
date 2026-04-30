# Recovery — Change B (Section B: Interactive confirmation flag)

**Purpose:** consolidated record of Section B's design state going into reconstruction. This file replaces the lost session 03/04/08 design fragments — handover 08 was confirmed to lift from 03 unchanged, and 04's partition concern is no longer relevant since we're collapsing the multi-stage scope back into a single design.

**Status:** Section B is **not started**. A.1 / A.4 / A.2 / A.3 reconstruction must complete first.

---

## Working assumption about state

We do not know exactly what was in the lost timeline's session-08 handover or in the agent's context that did not get persisted. Treat everything in this file as either:

- **Settled** — confirmed by handover content from before the loss and not contradicted since
- **Open** — surfaced as a question, not yet answered
- **Surfaced during recovery** — emerged from the reconstruction process; record verbatim here as it comes up

When reconstruction reveals something that should be in Section B's scope (e.g. a contract decision that needs a corresponding interactive-mode behaviour), add it under "Findings during recovery" with a date and which A.x commit raised it.

---

## Settled scope

These items are confirmed by handover 08 (which lifts from 03) and are not in dispute.

### Functional requirements

- Add `--interactive` flag to `agent-sandbox.sh` for both `apply` and `draft` subcommands.
- For `draft`: present a numbered table of recent sessions with availability indicators (`session: ✓/✗`, `autosave: ✓/✗`, `uncommitted: ✓/✗`). Operator picks by number. Selection feeds into the existing channel resolution.
- For `apply`: simpler flow — show the resolved `uncommitted.diff` path, prompt for confirmation, abort on rejection without applying.
- Pre-fill from `SESSION=<name>` Makefile variable when both `--interactive` and `SESSION` are supplied: the named session becomes the default, selectable by pressing enter on empty input.
- Add `INTERACTIVE=1` Makefile flag mapping to `--interactive`.
- Update `libs/_templates/Makefile.template` with `INTERACTIVE=1` mapping.

### Non-functional requirements

- Interactive prompts must not break in CI / automated environments. Activation only when the flag is explicitly set; do not auto-detect TTY.
- Non-interactive mode (no flag) behaviour is unchanged.

### Test scope

- Confirmation proceeds: input matches expected behaviour.
- Rejection aborts without applying.
- File list (or diff path) matches the resolved session.
- Default-on-empty: pressing enter selects the pre-filled `SESSION=<name>` default.
- Abort on `q` or `n`.
- Direct unit tests for `interactive_select_sessions` (added based on the deferred-items trace finding — Router 1's tests slipped to integration-only and got lost; do not let Router 2 do the same).

### Where this lives

- New utility: `interactive_select_sessions` (location TBD — likely `libs/session.sh` alongside `resolve_session_dir`, but confirm placement at session start).
- Wiring: `scripts/agent-sandbox.sh` consumes the utility for both `apply` and `draft` paths.

---

## Open questions (must resolve before B implementation)

### Q-B-1 — Should `draft --interactive` show `output/diffs/` entries?

**Origin:** deferred-items trace, item #4. Originally raised in handover 03, never resolved.

**Background:** The channel boundary established in A.2 says `apply` consumes `output/diffs/`, `draft` consumes `session-diffs/` and `output/bundles/`. Under that boundary, the answer is presumptively **no** — `draft`'s interactive table should not show `output/diffs/` entries because draft cannot use them.

**Why this needs an explicit answer:** the boundary was implicit before A.2. Now it's explicit, and the interactive UI is the place where boundary violations would be most visible to the operator. If someone runs `draft --interactive` and sees an `output/diffs/` entry that they then can't actually draft from, that's a UX failure.

**Recommendation:** answer "no, draft only shows draft-eligible channels." Document in design doc.

### Q-B-2 — Where does `interactive_select_sessions` live?

**Background:** the function's job is to scan a directory, present a table, read stdin, return a session name. It's CLI-coupled (stdin/stdout) but logic-light.

**Candidates:**

- `libs/session.sh` — co-located with `resolve_session_dir`. Logical home if the function is generic.
- `scripts/agent-sandbox.sh` — co-located with `resolve_source_for_draft` and `resolve_diff_for_apply`. Logical home if the function is CLI-specific.
- New file (e.g. `libs/interactive.sh`) — logical home if interactive primitives will grow beyond this one function.

**Recommendation:** start with `libs/session.sh` for simplicity. Promote to its own file if a second interactive primitive appears.

### Q-B-3 — Behaviour when scanned directory has zero entries

**Background:** what does `draft --interactive` do when there are no sessions in `session-diffs/`?

**Candidates:**

- Print "no sessions available" and exit non-zero.
- Print the same and exit zero (operator's choice to do nothing is not a failure).
- Skip interactive prompt entirely and fall back to the non-interactive default-resolution path (which would then also fail with a clearer error).

**Recommendation:** print message, exit non-zero. Symmetric with `make apply` failing when no diff is present.

### Q-B-4 — Maximum number of entries displayed

**Background:** original handover 03 mentioned "5 entries" as a possible cap. Should there be a cap, and what's the behaviour when there are more sessions than the cap?

**Candidates:**

- Hard cap at 5; older entries not selectable interactively.
- Hard cap at N (configurable).
- No cap; show all.
- Cap with a "more available, run with `SESSION=...`" hint.

**Recommendation:** cap at 5 by default with a hint about using `SESSION=` for older entries. Configurable via env var if needed later. Keep it simple for the first cut.

### Q-B-5 — Behaviour of `--interactive` combined with explicit `--session=<name>` (no `--interactive` selection needed)

**Background:** if operator passes both `--interactive` and `--session=foo`, the session is named — does interactive mode still prompt?

**Candidates:**

- Yes: pre-fill `foo` as the default; operator can confirm with enter or override by selecting another row. Use as sanity check.
- No: explicit `--session` takes precedence; skip the prompt entirely.

**The original handover wording suggested option 1** ("yet also fulfil the SESSION= selection, and also would serve as a sanity check"). Confirm this is still the intended behaviour at session start.

---

## Items deliberately punted (not for Section B)

### `package_diff` cross-write into `session-diffs/`

**Status:** non-decision. Considered, not adopted, no concrete use case. Recorded here so it doesn't reappear as a "lost" item next time someone reads the handover chain.

**Future destination:** if a use case appears, raise as a separate design question. Do not bundle into Section B.

### `draft_run` folder shape contract ownership

**Status:** unresolved (see `recovery-change-a.md` cross-cutting notes). Not Section B's concern. Recovery does not redesign this; a future session can.

---

## Findings during recovery

This section is empty at file creation. Add entries here as reconstruction surfaces things that should affect Section B's scope.

Format:

```
### YYYY-MM-DD — <short title>

**Raised during:** <pre-clean task ID | A.x reconstruction>
**Finding:** <verbatim>
**Disposition:** <add to settled scope | new open question Q-B-N | punt to backlog>
```

---

## Exit criteria before Section B implementation begins

1. Change A is fully landed and verified.
2. All open questions Q-B-1 through Q-B-5 are resolved (in this file or in the consolidated design doc).
3. The 20260430 design handover (the consolidated record replacing 03/04/08) exists and references this file.
4. Findings during recovery have been integrated into either settled scope or open questions; nothing left in limbo.
5. A new implementation handover (e.g. `20260430-NN-impl-b_interactive.md`) is created at session start per `handover_policy.md`. This file becomes its primary input.
