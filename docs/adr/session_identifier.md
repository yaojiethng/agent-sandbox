# Session Identifier

**Current:** 2026-08-31

## 2026-08-31 -- Single canonical hash over all identity factors

**Decision:** The session identifier is derived in one hash over all three
identity factors, with the sandbox directory canonicalized first:

```
SESSION_ID = sha256(canon(SANDBOX_DIR) : HOST_HEAD_SHA : SESSION_TS)[0:6]
```

The former `SANDBOX_ID` intermediate is removed — no two-stage derivation, no
`sandbox_id_derive`. `HOST_HEAD_SHA` stays folded into the hash (session→
sandbox-state coupling, and it disambiguates same-folder same-second starts
across host commits). `canon(SANDBOX_DIR)` is `readlink -f`/`realpath` after
leading-`~` expansion; an unresolvable `SANDBOX_DIR` is a hard error (start and
resume already require the directory for `.env`, record read, and git
validation, so the pipeline fails loudly rather than silently degrading).
Migration is forward-only: resume reads `SESSION_ID` off the record filename
and never recomputes, so the live session's identity is untouched and old
records simply disappear with their sessions.

**Rationale:** The two-stage model had three defects surfaced by the prune
label-reliability investigation (design `20260831`): (1) `SANDBOX_ID` was a
dead intermediate — its only functional consumer was `session_id_derive` at a
fresh start; it appeared in no compose label, image name, stop/prune filter,
or Docker artefact; (2) two SHA-256 rounds and two truncations produce one
final handle, and the intermediate truncation destroys higher-order bits
before the second round; (3) hashing the raw `SANDBOX_DIR` before
canonicalization made the identifier a function of path *spelling*, not
folder — the same folder reached two ways yielded different identifiers, so a
prune label filter built from one spelling could not match a label built from
another.

**Rejected alternatives:**
- *Keep the two-stage model* — preserves the dead intermediate, the
  superfluous hash, and the spelling-dependent identifier; does nothing for
  the prune root cause.
- *Single hash, drop `HOST_HEAD_SHA`* — loses session→sandbox-state coupling
  and same-second collision avoidance across host commits, for no gain.
- *Keep two stages, canonicalize only* — restores convergence but keeps the
  dead intermediate and the superfluous hash; layered, not simplified.

**Edge cases / drivers:** Prune label-reliability defect (iterations
`20260831-05/06`): leftover volumes showed visible removal but label-only
Rule 2 missed them because `sandbox-dir`/`session-id` labels were inconsistent
or absent. Canonical convergence of all path spellings makes label filters
spelling-independent. 24-bit entropy (6 hex) is sufficient for session
disambiguation within a sandbox instance. Full primitive/consumption detail:
[sandbox_identity.md](../concepts/sandbox_identity.md).

## 2026-07-22 -- Hash-based identifier, two-stage derivation

**Decision:** Container identity is hash-based, not timestamp-based, derived
from two factors — sandbox instance (`SANDBOX_DIR` + `HOST_HEAD_SHA`) and
session timestamp (`SESSION_TS`) — encoded as a short hash in container names
and artefact paths:

```
SANDBOX_ID = sha256(SANDBOX_DIR : HOST_HEAD_SHA)[0:8]
SESSION_ID = sha256(SESSION_TS : SANDBOX_ID)[0:6]
```

Container naming `<role>-<project>-<SESSION_ID>`; a fixed Docker label schema
(`project-name`, `sandbox-dir`, `host-head-sha`, `host-branch`, `session-ts`,
`session-id`) on every container makes lifecycle operations (stop, prune,
inspect) label-filtered rather than name-parsed. The compound
`project-name` + `sandbox-dir` label pair is the key for all lifecycle
operations; `session-ts` is the sole chronological sort key.

**Rationale:** Raw timestamps give no identity guarantees — they encode
neither sandbox instance nor host commit, cannot be verified against source
state, and collide for parallel worktree sessions started in the same second.
Labels are the only runtime-verifiable filtering mechanism at scale
(`docker stop --filter label=X`), and deterministic naming makes exports and
audits reproducible from identity inputs. A UUID alternative was rejected at
the time for being non-deterministic — replaying a session from the same
state would produce a different identity, breaking artefact correlation
without an external registry.

**Reason superseded by 2026-08-31:** The two-stage formula carried a dead
intermediate, a superfluous second hash, and a lossy raw-path first hash —
the identifier was a function of path spelling rather than folder, which the
prune label-reliability defect exposed. The canonical single hash converges
every spelling of a folder to one identifier. The marker/label schema and
label-based lifecycle-filtering decisions of this entry remain in force and
are governed by the [container marker schema](../concepts/sandbox_identity.md#docker-label-schema);
image-version marking later moved to [harness_versioning.md](harness_versioning.md).
