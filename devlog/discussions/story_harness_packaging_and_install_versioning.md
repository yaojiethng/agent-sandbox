# Story — Harness Packaging and Install Versioning

**Status:** Investigation in progress

---

## Context

The harness is currently installed by dropping a dispatcher binary into the user's bin path. The full harness source — `scripts/`, `libs/`, `providers/` — is always read from the working tree at invocation time. This means there is no stable installed version: any change to the working tree affects all invocations immediately, including sessions intended to use a known-good harness state.

This story was extracted from the session identity and harness versioning story, where it was identified as a prerequisite for meaningful installed-vs-local isolation. It is scoped as a future large task and does not block the sig model defined in the parent story.

---

## Pain Points

**No stable installed version.** `make install` installs a dispatcher, not a snapshot. Changes to `scripts/` or `libs/` in the working tree take effect immediately for all invocations — there is no way to pin to a known-good state without manually reverting the working tree.

**Dogfooding has no safe recovery path.** The harness is used to develop itself. A breaking change to the working tree leaves the harness unable to run, with no fallback. The operator must manually revert or patch before they can invoke the harness again.

**`HARNESS_DIR` override is insufficient alone.** Pointing `HARNESS_DIR` at a different directory only helps if that directory contains an independent, self-contained copy of the harness source. Without a snapshotted install, both the "stable" and "dev" invocations read from the same working tree.

**`harness-sig` cannot guarantee isolation.** The sig model (defined in the session identity story) can detect that the working tree has drifted from the last install, but it cannot prevent that drift from affecting a running session. Meaningful isolation requires the installed copy to be genuinely independent.

---

## Constraints

- The installed copy must be self-contained: its own `scripts/`, `libs/`, `providers/` snapshot, independent of the working tree.
- Multiple installed versions must be able to coexist on the same machine.
- The project `.env` or a make flag (`HARNESS_DIR`) must be able to point to either an installed snapshot or a local working tree.
- The install mechanism must remain low-ceremony for operators who do not need version isolation.
- The `harness-sig.ref` written at install time must live inside the installed snapshot so it travels with that version.

---

## Open Questions

1. **Snapshot mechanism:** How is the installed snapshot produced? Options: `rsync` copy of the working tree at `make install` time, a git archive of a tagged release, or a self-contained tarball. The git archive approach ties well to the release tagging convention but requires a tag to exist before install.

2. **Version identity:** How is an installed snapshot identified? Options: the git tag it was built from, a `VERSION` file written at install time, the `harness-sig` of its `libs/` content. These are not mutually exclusive.

3. **Install path layout:** Where do versioned snapshots live? Proposed: `~/.agent-sandbox/<version>/` with a symlink at `~/.agent-sandbox/current/` pointing to the active version. The dispatcher binary resolves `HARNESS_DIR` against `current/` unless overridden.

4. **`make install` workflow:** What does the new install sequence look like? Likely: compute version identity → snapshot working tree (or archive from tag) → write to versioned path → update `current/` symlink → write `harness-sig.ref` into snapshot.

5. **Relationship to `HARNESS_DIR` override:** Once versioned installs exist, `HARNESS_DIR` becomes an escape hatch for local dev testing. Project `.env` normally unset (uses `current/`). For dogfooding: `HARNESS_DIR=/path/to/local/agent-sandbox make start`. This composites cleanly with the versioned install model.

6. **Upgrade and cleanup:** How does the operator upgrade to a new version? How are old snapshots pruned? A parallel to the checkpoint tag pruning model (keep last N) may apply here.

---

## Relationship to Other Stories

**Blocks partial resolution of:** [`story_session_identity_and_harness_versioning.md`](story_session_identity_and_harness_versioning.md) — specifically OQ3 (storage of `harness-sig`) and OQ4 (installed-vs-local model). Those questions are noted as deferred in the parent story pending resolution here. The sig model itself does not require this story to be resolved — it is useful immediately as a drift warning mechanism.

---

## Resolution

_Not yet written — future task, not yet scheduled._
