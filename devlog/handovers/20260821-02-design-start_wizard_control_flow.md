# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Design
**Status:** Closed

## Objective
F2 **design session** for the interactive `start`-command control flow (roadmap L151). The `20260818-02` walk settled the *wizard shape* (run inventory → resume-N or new; config prefilled from the newest run; prints the full non-interactive command; `--run=<id>` resumes; no subcommand split). **Operator steering (D1/D2) reverses Q7's "interactive-by-default" to an explicit `--interactive` opt-in, and makes malformed invocations route to help.** What remains unsettled and lands here is the **interactive control flow itself** — how the wizard is driven, incl. rework of the existing `start_agent.sh` prompt/picker control flow. The `--interactive` flag surface is already wired-but-not-implemented from the previous `fix` iteration (errors `not yet implemented`, pending F2) and is the ready attachment point.

## Outcome
The F2 design walk is complete (decisions D1–D11) and the D4 sweep is done: the design record Q7 and roadmap L151–L152 now carry the settled two-command start/resume design, and the record is coherent with no `§`/stale-`--run` residue. No implementation this iteration — that is the follow-on F2 `impl` iteration (wire `start`/`resume` control flow, `--session-id` pass-through, F-dryrun delivery-awareness).

## Decisions
*Resolved in-session (operator `2026-08-21`); numbered monotonically. Persistent records reference these by descriptive name/validating link, not transient chat numbers (documentation_policy [Numbering and cross-references](../../docs/operations/documentation_policy.md#numbering-and-cross-references)).*

**D1 — Interactive is an explicit opt-in; fast = supplied args, slow = `--interactive`.** Interactive-behavior is never the default: the fast path supplies required args (`make start PROVIDER=pi`, `make resume SESSION_ID=<id>`) and runs non-interactively; the slow path is an explicit `--interactive` flag used when extra help is needed. This reverses the settled Q7 "interactive-by-default wizard" reading (design record Q7 / roadmap L151). Recorded as a **cross-command interface convention** (not start/resume-specific): fast mode = default (supplied args), slow mode = explicit `--interactive`. Args already provided override the interaction's suggested default rather than being re-prompted.

**D2 — Malformed invocations print help; help explicitly recommends `--interactive`.** Unknown flags / missing mode / malformed args route to the help screen (exit non-zero) rather than a bare error line. Help, alongside describing args, must explicitly recommend `--interactive` as the preferred way to start a session.

**D3 — Resume-by-id flag is `--session-id=<id>` (not `--run=<id>`).** The terminology sweep named `session` (not `run`) the reserved term and `SESSION_ID` the canonical entity; `stop.sh` already uses `--session-id=<id>`. `--run=<id>` predates the sweep and must not survive the rename. This satisfies the finding-1 blocked-on (roadmap L152): `make stop` can print `make resume SESSION_ID=<id>`.

**D4 — Post-walk sweep to unify the design record.** Because Q7 / roadmap L151–L152 still carry stale `--run`/"interactive-by-default" wording, a targeted correction of the affected docs is performed after the design walk so the record is unified and coherent by iteration end.

**D5 — Two-command split: `make start` (new session) / `make resume` (resume entrypoint).** Resume is its own command rather than a mode/flag on `start`. `start` drops the resume-specific args `--resume`/`--session-id` and the `_auto_resume_or_new` heuristics; `resume` owns them (`--session-id=<id>` direct; `PROVIDER=` as a filter). `--interactive` remains on `start` but repurposed as the config wizard (D9). This restates Q7's "no subcommand split" as a command split — new vs resume are different intents — and lands finding-1/L152 directly.

**D6 — `make start` unconditionally starts a new session.** `start` has no resume branch — its default path always starts new. `_auto_resume_or_new`, the `--resume` flag, and volume-discovery-on-start are dead in `start` and relocate to `resume`. `--refresh`/`--rebuild` build knobs remain on `start`.

**D7 — Speculative resume inventory: `.compose/*.yml` is the single unified inventory (both deliveries), with secondary existence checks.** Every session — copy or mount — writes a registry record at `.compose/<session-id>.yml`, so the registry is by itself the unified inventory. It is a *record*, not the backing-state truth: a secondary check (`docker volume inspect` for copy, `docker ps`/container lookup for mount) confirms the volume/container exists before presenting resume as valid. (Extends the registry-fold decision, design record N2.)

**D8 — `make resume` args are filters; `SESSION_ID` shortlists-to-one and is the direct bypass.** Each arg (`PROVIDER=`, `SESSION_ID=`, ...) narrows the inventory; `SESSION_ID=` filters to exactly one, which is why it is a valid direct resume bypass. `PROVIDER=` narrows to matching sessions only.

**D9 — Silent-auto resume is strictly `SESSION_ID=`-gated (option A).** `SESSION_ID=` can narrow to at most one container, so `make resume SESSION_ID=<id>` resumes silently (no picker/confirm) after the existence check. Any other filter — even `PROVIDER=` narrowing to a single candidate — still goes through the picker/confirm (slow mode), because `SESSION_ID=` is the explicit "resume THIS one" bypass while `PROVIDER=` is a scoping filter whose single result still merits a confirm. Resume's silent/auto behavior is independent of inventory cardinality when `SESSION_ID=` is absent.

**D10 — `make resume` interface: `--list` lists (fast); `--interactive` opens the picker (slow); bare `resume` prints help.** `resume --list` is the fast listing surface to construct a follow-on command; `resume --interactive` opens the picker + confirm (slow, starts immediately with no subsequent command needed); a bare `resume` (no `--list`/`--interactive`/`--session-id`/filter) routes to help, which hints both surfaces and describes when each is used. The confirm step applies to `--interactive` and any picker path whose selection is not a `--session-id` direct resume. Fast flow = `resume --list` then `resume --session-id=<id>`; slow flow = `resume --interactive` or a filter that lands in the picker.

**D11 — `make start --interactive` is a provider/config wizard.** Since `start` unconditionally begins a new session with nothing to browse, its `--interactive` is a config wizard: selection menus + D6-style confirm over `PROVIDER` (and other optional start settings), then starts new. Fast path = supply `PROVIDER=` directly.

## Findings
| Finding | Type | Impact |
|---|---|---|
| Handover decision record overloaded while editing in several steps (transient D# labels; overlapping final/reworked decisions; out-of-order insertion) — reworked once, at close, to a monotonic final-decisions-only record; also repeatedly clobbered sibling entries in piecewise block edits | process | resolved this iteration — renumbered D1–D11, only final decisions persisted; **routed** to AGENT_FEEDBACK `[A] did-the-write-land reflex` (additional-resurfacing note) |
| Introduced prohibited `§` symbols in this handover's cross-references (design record `§Q7`, `§N2`, `§Numbering`); documentation_policy Character set prohibits `§`. The design record itself uses plain `Q7`/`N2` headings and its `§` count is 0 — the violation was mine | process | resolved this iteration — replaced with plain names/anchor links; design record left clean; **routed** to AGENT_FEEDBACK `[A] Non-ASCII punctuation` (resurfaced note) |

## Completed
| File | Change |
|---|---|
| `devlog/handovers/20260821-02-design-start_wizard_control_flow.md` | Created this design handover (opens the F2 interactive-`start`/`resume` control-flow design session); settled the two-command split (D1–D11): interactive-as-opt-in cross-command convention, malformed→help, `--session-id` flag, start (new, config wizard) / resume (`.compose`-registry inventory, `--list`/`--interactive`, `--session-id` bypass) split. Decision record rewritten to monotonic numbering (final decisions only); removed prohibited `§` symbols |
| `devlog/discussions/20260730-design-settled-mount_model.md` | D4 sweep: corrected Q7 in place (current, not-yet-implemented design → edit-in-place, no new record) to the settled two-command start/resume design; `--run` → `--session-id` wording |
| `devlog/roadmap.md` | D4 sweep: L151–L152 updated to the two-command start/resume design + `--session-id` pass-through landing with `make resume`; removed stale `--run`/"interactive-by-default merged wizard" wording |

## What's Next
- The F2 `start`/`resume` **design** is settled (this session, D1–D11) and the D4 sweep is complete.
- **Follow-on F2 `impl` iteration**: implement the two-command split — `make resume` (`.compose`-registry inventory, `--session-id=<id>` direct resume, `PROVIDER=` filter, `--list`/`--interactive`, malformed→help) and `make start` new-only with `--interactive` config wizard; remove `_auto_resume_or_new`/`--resume` from `start`; wire `stop.sh` to print `make resume SESSION_ID=<id>` (finding-1/L152); F-dryrun delivery-awareness.