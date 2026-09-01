# ADR — Single Canonical Session Identity

**Status:** settled

## Summary

Session identity is derived in **one** hash over all three identity factors,
with the sandbox directory canonicalized first, replacing the former two-stage
model's separate `SANDBOX_ID` intermediate:

```bash
SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
```

## Context

The identity model (ADR 20260722) used a two-stage content-addressed hash:

```bash
SANDBOX_ID = sha256(SANDBOX_DIR : HOST_HEAD_SHA)[0:8]   # 32 bits
SESSION_ID = sha256(SESSION_TS : SANDBOX_ID)[0:6]       # 24 bits
```

A prune label-reliability defect surfaced (iterations 20260831-05/06): leftover
volumes showed visible resource removal but prune's label-only Rule 2 did not
catch them because the `agent-sandbox.sandbox-dir`/`.session-id` labels were
inconsistent or absent. Investigation (design 20260831) examined whether the
identity model itself contributed:

1. **`SANDBOX_ID` is a dead intermediate.** Its only functional consumer is
   `session_id_derive` at a fresh start (`start_agent.sh`). On resume it is
   derived (`resume_agent.sh`) but nothing downstream reads it — names use
   `SESSION_ID_ARG`. It appears in no compose label, image name, stop/prune
   filter, or Docker artifact; the debug echo that referenced it is unparsed.
2. **Superfluous hash.** Two SHA-256 rounds and two `cut` truncations produce
   one final handle; the same identity is a single hash over the primitives.
   The intermediate truncation to 8 hex chars destroys higher-order bits before
   the second round.
3. **Lossy early hash.** `SANDBOX_DIR` has many path spellings for one folder
   (`~`, absolute, relative, symlink, trailing-slash, `./`). Hashing the raw
   path before canonicalization makes the id a function of spelling, not folder
   — so the same folder reached two ways yields different ids, and a prune label
   filter built from one spelling cannot match a label built from another.

## Options Considered

- **Option A — keep two-stage model.** Documented and implemented; but preserves
  the dead intermediate, superfluous hash, and lossy early path hash. Does
  nothing for the prune root cause.
- **Option B — single canonical hash over all three factors (adopted).** One
  hash over `canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS`; drop `SANDBOX_ID`.
- **Option C — single hash, drop `HOST_HEAD_SHA` from the hash.** Rejected: loses
  session→sandbox-state coupling and same-second collision avoidance across host
  commits for no gain.
- **Option D — keep two stages, only canonicalize.** Restores convergence but
  preserves the dead intermediate and superfluous hash; layered not simplified.

## Decision

Adopt **Option B**. `HOST_HEAD_SHA` stays folded (session→sandbox-state
coupling + disambiguates same-folder, same-second starts across host commits).
Operator resolutions:

1. **Forward-only migration, no back-compat.** All sessions but the running one
   are pruned. Resume reads `SESSION_ID_ARG` off the record filename and never
   recomputes, so the live session's identity is untouched; old records simply
   disappear.
2. **Canonicalize to absolute path.** `readlink -f`/`realpath` after leading-`~`
   expansion. An unresolvable `SANDBOX_DIR` is a **hard error** — start/resume
   already require the dir for `.env`, record read, and git validation, so it
   fails loudly rather than silently degrading.
3. **Keep `HOST_HEAD_SHA` folded.**
4. **Remove `sandbox_id_derive`** and its derivation sites in
   `start_agent.sh`/`resume_agent.sh`, the debug echo, and `SANDBOX_ID` from
   identity contract docs/tests.

## Consequences

### Positive
- **Canonical identity** — all path spellings of one folder converge to one
  `SESSION_ID`, so label filters built from any spelling match anything created
  from any other. Directly serves the prune label-reliability fix.
- **Simpler model** — one hash, one truncation; one identity variable; dead
  intermediate and its sites removed.
- **State coupling preserved** — `HOST_HEAD_SHA` still in the hash keeps
  session→sandbox-state semantics and same-second collision avoidance.

### Negative
- **Forward-only identity break.** Old `.compose/<id>.yml`/labels (two-stage
  formula) do not decode under the new hash; accepted because the only
  non-pruned session is the live one and resume reads id from record.
- **Resolution dependency is a hard error.** Unresolvable `SANDBOX_DIR` breaks
  the pipeline loudly (dir already required for `.env`/record/git validation).
- **Coupled to the deferred prune label-reliability fix**, sequenced separately.

### Impacted artifacts
- `src/libs/session_env.sh` — `sandbox_dir_canon` + single `session_id_derive`.
- `scripts/start_agent.sh`, `scripts/resume_agent.sh` — dropped `SANDBOX_ID`.
- `docs/concepts/sandbox_identity.md`, `docs/concepts/sandbox_host_correspondence_model.md`.
- `tests/test_checkpoint.sh`, `tests/test_start_agent.sh`, trace stubs.

## Supersedes

Partially supersedes the derivation section of:
[`docs/adr/20260722-adr-settled-session_identity_and_container_markers.md`](20260722-adr-settled-session_identity_and_container_markers.md)
— replaces the `SANDBOX_ID`/`RUN_ID` two-stage formula with the single canonical
hash. The container marker/label schema and lifecycle-filtering decisions from
that ADR remain in force.