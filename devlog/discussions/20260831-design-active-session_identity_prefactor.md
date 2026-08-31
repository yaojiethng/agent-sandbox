# Design — Session Identity Prefactor: is `sandbox_id` still needed?

**Status:** settled
**Type:** design
**Date:** 20260831
**Predecessor (lineage):** supersedes the hash-based identity decision recorded
in `docs/adr/20260722-adr-settled-session_identity_and_container_markers.md`
as a *re-examination of the intermediate*, not a rejection of the model.
**Related discussion:** `devlog/discussions/20260423-design-active-session_identity_hash_based.md`.

---

## Context

The harness identifies sessions with a two-stage content-addressed hash:

```bash
SANDBOX_ID = sha256(SANDBOX_DIR : HOST_HEAD_SHA)[0:8]    # 32 bits
SESSION_ID = sha256(SESSION_TS : SANDBOX_ID)[0:6]        # 24 bits
```

`SESSION_ID` is the working identity: container names
(`sandbox-<project>-<session_id>`, `<provider>-<project>-<session_id>`), the
`.compose/<SESSION_ID>.yml` registry file, artefact paths, compose project
namespace suffix, and the `agent-sandbox.session-id` Docker label all key off
it. `SANDBOX_ID` was introduced (with `RUN_ID`/`SESSION_ID`, M2.7) as a
thinkable intermediate between the primitives and the session id.

This investigation was triggered while diagnosing a prune label-reliability
defect (iterate `20260831-05`/`20260831-06`): leftover volumes show visible
resource removal but prune's label-only Rule 2 does not catch them because the
`agent-sandbox.sandbox-dir`/`.session-id` labels are inconsistent or absent.
One candidate root cause is the identity model itself: if the session identity
is derived from a **non-canonical** path spelling, then the same folder reached
via different path representations produces different ids, and label filters
computed from a different spelling of the same path miss everything.

The operator posed three prefactor questions:

1. **Do we still need `sandbox_id` if `session_id` is a much more effective
   identifier?**
2. **Are we doing superfluous hash operations?**
3. **Does hashing `sandbox_dir` too early lose valuable data** (because
   multiple path representations can point to one folder)?

Scope of this document: **identity analysis only** — what `sandbox_id` does,
which consumers rely on it, whether it can be removed/folded, and what the
lossy early hash costs. Implementation of any resulting change is deferred to
later iterations (and coupled to the prune label-reliability fix).

---

## Investigation: who consumes `sandbox_id`?

Full-tree grep (`grep -rn "SANDBOX_ID" --include="*.sh" --include="*.md" .`,
excluding node_modules), augmented by reading the consuming files:

| Consumer | Lines | Uses `sandbox_id`? |
|---|---|---|
| `scripts/start_agent.sh` | 186 derive, 187 feed `session_id_derive`, 313 debug echo | derive + feed; echo only |
| `scripts/resume_agent.sh` | 259 derive | **derived but never read** (names use `SESSION_ID_ARG`) |
| `src/libs/session_env.sh` | `sandbox_id_derive` def | defines the formula |
| compose templates | — | **none** (volumes/containers label `session-id`) |
| image naming (`src/build/image.sh`) | — | **none** (images are project-only) |
| `build.sh` / `compose.sh` | — | **none** |
| stop/prune filters | — | **none** |
| Docker artifacts (labels) | — | **none** |
| artefact paths | — | **none** |
| tests | `test_checkpoint.sh`, `test_start_agent.sh`, trace tests | contract tests only |

**Finding 1 — `sandbox_id` is a dead intermediate.** Its *only functional*
consumer is `session_id_derive` at a fresh start (`start_agent.sh:187`). On the
resume path it is derived (`resume_agent.sh:259`) but nothing downstream reads
it — `session_env_names` receives `SESSION_ID_ARG`, not `SANDBOX_ID`. It is
exported to no Docker artifact, compose key, name, path, or filter. The
`echo "Sandbox ID: $SANDBOX_ID"` line at `start_agent.sh:313` is the one
surviving non-derivation reference and it feeds nothing (no script parses it).

---

## Investigation: are we doing superfluous hash operations?

Current chain, with entropy at each stage:

| Stage | Formula | Entropy kept |
|---|---|---|
| `sandbox_id_derive` | `sha256(SANDBOX_DIR:HOST_HEAD_SHA)[0:8]` | 32 bits |
| `session_id_derive` | `sha256(SESSION_TS:SANDBOX_ID)[0:6]` | a further 24 bits |

Two SHA-256 invocations and two `cut` truncations are used to produce a single
final handle.

- SHA-256 is already collision-from-any-input resistant, so a second round over
  the *first round's truncated output* adds no security; it only folds `SANDBOX_ID`
  into the mix. The **same combined identity can be produced with one hash over
  all primitives** (`sha256(SANDBOX_DIR:HOST_HEAD_SHA:SESSION_TS)`) — the second
  round and its second truncation are removable without changing what `SESSION_ID`
  denotes.
- The intermediate truncation to 8 hex chars **destroys the higher-order bits of
  the first digest before the second round**. Hashing the primitives directly
  keeps full first-round entropy into the final truncation.

**Finding 2 — the double hash is superfluous for its stated purpose.** The only
reason to keep two stages today is if some consumer needs `sandbox_id` *as a
type* (a stable per-sandbox-and-commit identifier). No consumer does (Finding 1).

---

## Investigation: does hashing `sandbox_dir` too early lose data?

`SANDBOX_DIR` is an **identity factor swallowed into both hashes**. But a given
folder has many path spellings:

- absolute `/home/me/projects/x-sandbox`
- `~`-form `~/projects/x-sandbox`
- relative `projects/x-sandbox` (from a cwd)
- symlinked `/var/symlink/to/x-sandbox`
- trailing-slash `/home/me/projects/x-sandbox/`
- redundant `/home/me/projects/./x-sandbox`

Different spellings hash to **different `SANDBOX_ID`s** and hence **different
`SESSION_ID`s for the same folder**. Because `SESSION_ID` is what names
containers, the registry file, and the `session-id` label, the identity of the
"same" session differs by how the path was spelled when it was created.

**Finding 3a — hashing the raw path is lossy and non-canonical.** The path is
hashed *before* canonicalization, so the id inherits the spelling, not the
folder. This is the exact class of defect behind the prune hang: a label filter
built from the invocation's spelling of `SANDBOX_DIR` cannot match a label built
from a different spelling of the same folder.

**Finding 3b — `HOST_HEAD_SHA` turns session identity into a per-commit
identity.** `HOST_HEAD_SHA` changes whenever the host branch
advances, so `sandbox_id` (and thus `session_id`) is not a folder-only identity;
it identifies a sandbox-at-a-commit, matching its "branch-point tag" semantics.
Whether this is desirable is a *decision*, not a defect: the operator affirms
the state-coupling is wanted (see Decision, keep `HOST_HEAD_SHA` folded) — the
prefactor's real defect is un-canonicalized spelling (F3a) plus the dead
intermediate (F1), not the fact that `HOST_HEAD_SHA` is an input.

---

## Options Considered

### Option A — Keep the two-stage model (status quo)

Keep `SANDBOX_ID` as an intermediate and `SESSION_ID = sha256(SESSION_TS:SANDBOX_ID)`.

- **For:** documented and implemented; no change; the ADR's "double-hashing is
  harmless" claim holds for collision-resistance.
- **Against:** keeps a dead intermediate (Finding 1), a superfluous hash
  (Finding 2), and the lossy early path hash (Finding 3) in the system. Does
  nothing for the prune label-reliability root cause.

### Option B — Fold the intermediate; keep all three identity factors in ONE hash

Drop the `sandbox_id` intermediate and `SANDBOX_DIR` as a distinct identity
variable, but canonicalize the path and keep all three factors in a single
canonical hash:

```bash
SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
```

where `canon(SANDBOX_DIR)` is a deterministic canonical absolute path
(`readlink -f` / `realpath` after `~` expansion). Remove `sandbox_id_derive`,
its derivation sites in `start_agent.sh`/`resume_agent.sh`, the dead resume-path
depth (line 259), the debug echo, and `SANDBOX_ID` from identity docs/tests.

- **For:** removes the dead intermediate (F1) and superfluous hash (F2);
  anchors identity to the canonical folder so all spellings of one folder
  converge to one `SESSION_ID` (F3a) — directly serving the durable
  label/discovery model from `20260831-05`; one hash, one truncation; keeps
  `HOST_HEAD_SHA` as an identity factor so `session_id` stays coupled to sandbox
  state (its established semantic), and so two sessions of the same sandbox
  started within the same second at different host commits do not collide.
- **Concerns:** moving identity outdates old sessions' `session-id` values,
  which is harmless under forward-only adoption (see Decision); resolution
  dependency — an unresolvable `SANDBOX_DIR` is a hard error in the pipeline
  (the dir must exist for start/resume to proceed), so it should fail loudly
  rather than silently degrade.

### Option C — Single canonical `session_id`, branch-point at top level (prefaced, later withdrawn)

An earlier draft dropped `HOST_HEAD_SHA` from the hash, keeping it only as a
label/`SESSION_STATE` field. Reconstructed rationale (see Decision) shows that
dropping it loses two genuinely useful properties — same-second collision
avoidance across host commits, and the session→sandbox-state coupling the
identified intent — for no correctness gain. Retracted in favour of Option B.

### Option D — Keep the two-stage model but canonicalize (no fold)

Retain two stages, but resolve `SANDBOX_DIR` to a canonical form before the
first hash.

- **For:** minimal diff; restores spellings-to-one-folder convergence without
  removing the intermediate.
- **Against:** keeps the dead intermediate (F1) and superfluous hash (F2); the
  canonicalization is an addition layered on an unnecessary two-stage indirection
  rather than the actual simplification the prefactor points at.

---

## Decision

**Recommended: Option B — one canonical hash over all three identity factors.**

```bash
SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
```

**Operator resolutions folded in (20260831):**
1. **Migration = forward-only.** No back-compat code is needed: all sessions
   except the one currently running have been pruned. Resume never re-derives
   `SESSION_ID` — it reads `SESSION_ID_ARG` straight off the record filename
   (`resume_agent.sh:231` → `session_env_names`). The running session's identity
   lives in its `.compose/<id>.yml` and its labels and is read back, never
   recomputed, so adopting the new formula does not disturb it. Old records
   simply disappear (pruned); nothing maps old→new.
2. **Canonicalize = absolute path.** `readlink -f` and `realpath` both return the
   canonical absolute path (symlinks resolved), so canonical = absolute, yes.
   **Resolvability convention:** if `SANDBOX_DIR` is unresolvable, it is a hard
   error — start/resume already require the dir (`.env`, record read, git
   validation), so other functionality that relies on the path breaks anyway;
   we should **fail loudly** rather than silently fall back. In practice a
   canonical sandbox dir is always resolvable; an unresolvable one indicates a
   broken install and merits a loud failure.
3. **Keep `HOST_HEAD_SHA` in the hash.** The reconstructed rationale for it is
   retained (see below): it couples `session_id` to sandbox state, which the
   operator affirms is still relevant.

**Why keep `HOST_HEAD_SHA` (reconstructed rationale):**
- It couples `session_id` to the **sandbox state** the session branched from —
  the established semantic "this sandbox, at this host commit, this run". Two
  sessions of the same canonical folder at the same second but different host
  commits must not collide; since `SESSION_TS` is second-granularity,
  `HOST_HEAD_SHA` is the factor that disambiguates same-folder-same-second
  starts across commits.
- An earlier draft (Option C) proposed dropping it as a top-level label field
  only. Reconstructing the intent shows that leaves same-second collision
  avoidance to luck and decouples the id from sandbox state for no gain — the
  factor is already folded today, is cheap to keep, and is read deterministically
  on resume. So it stays folded.

Evidence recap — the prefactor answers confirm the *shape* of the change, not
which factors go in the hash:
- *Still need the `sandbox_id` intermediate?* **No** — dead variable, single
  consumer `session_id_derive`, resume derives-then-throws-away (F1).
- *Superfluous hashes?* **Yes** — two SHA rounds + two truncations fold an
  already-truncated 32-bit digest; one hash suffices (F2).
- *Lossy early hash?* **Yes** — hashing the un-canonicalized path makes id a
  function of path spelling (F3a); the fix is to canonicalize the path *before*
  the single hash, not necessarily to drop factors.

So the change is: **one hash** over **canon(SANDBOX_DIR) : HOST_HEAD_SHA :
SESSION_TS**, removing the `sandbox_id` intermediate. Every spelling of one
folder converges to one identity — the thing the prune label-reliability fix
needs most — while the canonical folder + state coupling is preserved.

---

## Consequences

### Positive
- **Canonical identity** — all path representations of a folder produce the
  same `SESSION_ID`, so label filters built from any spelling match anything
  created from any other spelling. Directly addresses the prune hang.
- **Simpler model** — one hash, one truncation; one identity variable; the
  dead `sandbox_id` intermediate, its two derivation sites, the orphaned
  resume-path derivation, and the unparsed debug echo are all removed (F1/F2).
- **State coupling preserved** — `HOST_HEAD_SHA` still in the hash keeps
  session→sandbox-state semantics and same-second collision avoidance.

### Negative / Risks
- **Identity change for existing sessions.** Forward-only adoption means old
  `.compose/<id>.yml`/labels (two-stage formula) do not decode under the new
  hash; accepted because the only non-pruned session is the live one, and resume
  reads id from record, not recompute.
- **Resolution dependency is a hard error.** An unresolvable `SANDBOX_DIR` is a
  pipeline-breaking condition (dir required for `.env`/record/git validation);
  we fail loudly on it rather than silently degrade.
- **Coupled to prune label-reliability fix** — the deferred implementation
  (relabeling, Rule 2 discovery key) should be sequenced after this model
  settles, not concurrently.

### Impacted artifacts (once implementation lands)
- `src/libs/session_env.sh` — replace `sandbox_id_derive`/`session_id_derive`
  with a single canonical `session_id_derive`.
- `scripts/start_agent.sh` (186/187/313), `scripts/resume_agent.sh` (259).
- `docs/concepts/sandbox_identity.md`, `docs/concepts/sandbox_host_correspondence_model.md`.
- `tests/test_checkpoint.sh`, `tests/test_start_agent.sh`, trace stubs.
- Compose labels (value semantics unchanged — still `session-id`, now canonical-derived).