# Harness Architecture Assessment (design)

**Status:** active -- feeds the T4 `Bash "architecture" review`; settles when that review concludes.
**Raised from:** handover `20260922-15`.

## Context

The operator opened the harness architecture as a concern in the preceding iteration (`20260922-14`). Three claims were filed, then checked against the code: two god entrypoints that mirror each other, record duplication in governance, and record duplication in general process. Every claim was tested by reading code, build files, and records, not by directory shape. Two claims did not survive the checks. Their retraction, with the evidence, is part of this record.

**Claim 1 (two god entrypoints that mirror each other) -- retracted.** `src/capability/entrypoint.sh` (375 lines) and `src/reasoning/entrypoint.sh` (245 lines) share zero function names: the sets are `_preflight_crit _preflight_warn _session_export` against `_require_var _provision_agent_home`. The lifecycle is asymmetric by design. The capability entrypoint is a long-running server: EXIT trap to `_session_export`, TERM trap to `exit 0`, autosave loop, `wait`. The reasoning entrypoint is a thin launcher that provisions AGENT_HOME, runs preflight, then hands control to the provider entrypoint as a synchronous foreground child; its header states "The shared entrypoint stays generic". Neither is a god object: the heavy logic is already extracted to sourced libs (`session_state.sh`, `snapshot.sh`, `diff_export.sh`, `routing.sh`). The one shared concern, preflight of the baked container libs, is factored into `src/libs/dirs.sh` as `_source_lib` and `lib_preflight`, consumed by both entrypoints. That is the extraction working, not a duplication.

**Claim 2 (record duplication in governance) -- survived with a corrected mechanism.** See the finding below. The corrected claim is filed as roadmap row `Roadmap decision-row format drift` under T8.

**Sourced-lib boundary finding.** `src/libs/` holds 20 files totalling 3210 lines (35 to 387 lines each), sourced from 97 sites across `src/` and `scripts/`; fan-in ranges from 1 (`dry_run_record.sh`) to 14 (`cli.sh`). The boundary is documented and partially enforced, which is more precise than "convention plus reviewer attention". `docs/development/bash-coding-conventions.md` states the sourcing topology (scripts source libs; libs source libs only; build sources build and libs) and the no-flag library regime. `scripts/check_lib_contract.sh` enforces rules 3.1 (no `exit` in a function body) and 4.4 (guarded while-read redirect), nothing else. `scripts/check_lib_liveness.sh` rejects orphaned libs. `src/libs/interface_contract.sh` and ADR `interface_contract_compatibility.md` pin the cross-boundary contract version between host source, baked image labels, and session records. What is NOT enforced is the internal lib interface: no global-name namespace or prefix rule exists in the conventions (libs self-namespace `_self_*` by habit only), and no lib declares an output contract. Concrete instance: `src/libs/dry_run_harness.sh` accumulates the bare globals `CRITICAL_FAILS`, `WARN_FAILS`, and `CURRENT_LAYER`; `scripts/dry_run_reasoning.sh` and `scripts/dry_run_capability.sh` read them after sourcing. Bash reads an absent variable as empty, so a consumer that names an output wrong fails at comparison time, not at load time, and no checker is involved.

**Two-layer lib deployment finding.** The `/opt/sandbox/lib/` deployment has no single manifest. Four Dockerfiles repeat the library COPY: `src/capability/dockerfile` and the three provider tier-3 Dockerfiles under `src/reasoning/providers/` (`hermes`, `opencode`, `pi`). The capability image additionally hand-installs `src/capability/snapshot.sh` into the lib namespace; the reasoning images do not carry it. The divergence is one file and intentional, but it is unguarded: no build-time or test-time assertion pins the per-image inventory. `lib_preflight` checks only the libs an entrypoint names, and `check_lib_liveness.sh` scans the repo tree, not the images, so an image that silently gains or loses an unreferenced lib passes both gates. The shared `src/reasoning/node.dockerfile` bakes nothing into the lib dir.

**Governance record duplication finding.** The layered record model is prescribed by `roadmap_policy.md` and `handover_policy.md`: the roadmap is the milestone decision log, the handover the iteration log, the ADR the durable decision record, the discussion doc the decision history. That layering is not the defect. The defect is roadmap rows that grow into summary blocks that duplicate the ADR and the settled discussion: the test-harness decision (keep-current runner, bats-core rejected) is restated across 11 files, including a roadmap row that embeds the branch-comparison narrative the ADR and the settled design doc already carry. The roadmap's own Filing rule prescribes "a short decision statement, rationale, and a link to the full record".

## Options Considered

**Full directed rewrite.** Rejected. A rewrite with no evidence-prioritized target spends iterations refactoring what annoys the person proposing it, and the language-level decision is already scheduled under the T4 `Bash "architecture" review`. This assessment narrows that review rather than pre-empting it.

**Symptom-driven fixes.** Adopted where a claim survived its check, dropped where it did not. Claim 2 became the T8 format-drift row and this document's record of the mechanism. The bash-language framing became the T8 boundary-framing row, with the actionable review under T4. The refuted claims produced no work.

**Evidence-grounded assessment feeding the scheduled reviews.** Adopted; this document. The findings feed the T4 review and the T8 rows; only genuinely new findings are filed as new roadmap rows.

## Decision

1. Record this assessment as a `design` discussion record in `active` status. It settles when the T4 `Bash "architecture" review` concludes.
2. File one new roadmap row under T4: `Per-image lib inventory manifest and drift test`. It is the only finding not already covered by an existing row.
3. Do not re-file findings that existing rows already carry: the lib output-contract gap belongs to the T8 boundary-framing row, the decision-row duplication to the T8 format-drift row, the language choice to the T4 `Bash "architecture" review` row.
4. Keep claim 1 retracted. The mirror framing is not carried into any record.

## Consequences

The T4 review starts with a scoped evidence base: the retracted claim is excluded, the lib-boundary and lib-deployment findings are its input, and the inventory row has a named deliverable (one inventory declaration per image plus a test asserting the baked set). The assessment forecloses a premature refactor and any nushell work outside the review outcome. Future architecture claims against this harness can be checked against the durable evidence in this document instead of being re-argued from directory shape.
