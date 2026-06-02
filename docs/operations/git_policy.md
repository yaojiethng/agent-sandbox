# Git Policy

**Status:** Stub. Adopted types and branch naming are active. Scope field and future types are parked until usage patterns stabilise.

Policy for commit messages and branch naming in agent-sandbox. Commit types are aligned with the session types defined in [`handover_policy.md`](handover_policy.md) so that the git log and session history tell the same story.

---

## Commit Message Format

```
type: short description
```

Lower-case type prefix, colon, space, imperative summary. No scope field for now — scope may be introduced later when component boundaries are clearer.

The short description completes the sentence "this commit will..." — e.g. `feat: add snapshot validation gate`, not `feat: added snapshot validation gate`.

Body and footer are optional. Use a body when the "why" is not obvious from the summary. Use a footer for references (`Closes #12`, `See roadmap M2.1`).

---

## Active Types

These types are adopted now. Each maps to one or more session types from `handover_policy.md`.

| Type | When to use | Session type mapping |
|---|---|---|
| `feat` | New capability or behaviour | Implementation (`impl`) |
| `fix` | Bug fix — corrects broken behaviour | Implementation (`impl`) |
| `refactor` | Code restructuring with no behaviour change | Implementation (`impl`), Housekeeping (`chore`) |
| `docs` | Documentation-only changes | Design (`design`), Spec (`spec`), Story (`story`), Investigation (`study`), Planning (`plan`) |
| `chore` | Inert maintenance — stale refs, index cleanup, linting, formatting | Housekeeping (`chore`) |
| `workflow` | Changes that affect how other branches work — policy changes, CI/CD rules, branch restrictions, linter config, governance | Workflow (`workflow`) |
| `test` | Adding or updating tests only | Implementation (`impl`) |
| `build` | Changes to Dockerfile, build scripts, image pipeline | Implementation (`impl`) |

### Choosing between types

A commit that changes both code and documentation uses the type of the primary change. A snapshot pipeline implementation that also updates `execution_model.md` is `feat`, not `docs`. A documentation session that only touches markdown files is `docs` even if the content describes a new feature.

`refactor` vs `feat`: if the system behaves identically before and after, it is a refactor. If an operator or agent can do something they could not do before, it is a feat.

`chore` vs `workflow`: a chore is inert — it does not change how work is done, only tidies what exists. A workflow commit changes the rules: a new policy, a CI/CD gate, a linter configuration, a branch protection change. If merging the commit would require other contributors to change their behaviour, it is `workflow`, not `chore`.

`chore` vs `docs`: if the change fixes stale links, updates an index, or cleans up formatting without changing the substance of what a document says, it is a chore. If the change updates the documented system reality, it is `docs`.

---

## Future Types

Parked until the project has a use case. Introduce them when the first commit would naturally use them — not before.

| Type | Intended use | When to introduce |
|---|---|---|
| `perf` | Performance improvement with no behaviour change | When profiling or optimisation work begins |
| `revert` | Reverts a previous commit | When the first revert is needed |
| `ci` | CI/CD pipeline changes (distinct from `workflow` — `ci` is pipeline plumbing, `workflow` is governance) | When CI/CD is introduced (M3+) |
| `style` | Code formatting, whitespace — no logic change | When a formatter or linter is enforced |

---

## Branch Naming

```
type/milestone_description
```

Type matches the commit type. Milestone is the sub-milestone ID with dots replaced by underscores. Description is lowercase and hyphen-separated. Underscore is reserved for the milestone separator — do not use it in the description.

Examples:
- `feat/m2_1-snapshot-pipeline`
- `fix/m2_1-diff-baseline-sha`
- `docs/m2_1-two-layer-model`
- `chore/m2_1-stale-refs-cleanup`
- `workflow/m2_1-handover-policy-restructure`
- `build/m2_1-capability-layer-dockerfile`

When a change is not tied to a specific sub-milestone (e.g. a cross-cutting policy change), omit the milestone:
- `workflow/git-policy`
- `chore/readme-typos`

### Protected branches

`main` is the only long-lived branch. All work happens on type-prefixed branches and merges via review. Branch protection rules are defined in [`standard_operating_procedures.md`](standard_operating_procedures.md) — Human / Operational Protocols.

---

## Branching Strategy

### Simple case — one branch per sub-milestone

Most sub-milestones fit in one to three sessions and produce a single branch. The branch is created at session start, receives commits across sessions, and merges to `main` when the sub-milestone is complete and reviewed.

```
main ──────────────────────────────●── ...
        \                         /
         feat/m2_1-snapshot ─────
```

### Chunky sub-milestones — integration branch

When a sub-milestone is too large or too varied for a single branch — multiple functional areas, different commit types, or enough sessions that the branch becomes unwieldy — use an integration branch.

The integration branch is named for the sub-milestone without a type prefix:

```
milestone/m2_1
```

Session branches are created from the integration branch and merged back into it as each session or functional slice completes. The integration branch merges to `main` when the full sub-milestone is reviewed and approved.

```
main ──────────────────────────────────────────●── ...
        \                                      /
         milestone/m2_1 ──────●────────●──────
              \              /    \         /
               feat/m2_1-snapshot  feat/m2_1-diff
```

### When to use an integration branch

Use an integration branch when any of these apply:
- The sub-milestone spans more than three sessions
- The sub-milestone produces branches with different type prefixes (e.g. `feat` + `docs` + `build`)
- Intermediate merges to `main` would leave the system in an incomplete state
- The operator wants to review the sub-milestone as a single coherent unit

If none of these apply, the simple single-branch model is preferred.

### Branch lifecycle

A session branch is merged or discarded when its session work is complete. An integration branch is merged when the sub-milestone is complete. Stale branches with no activity for two milestones are deleted.

---

## Multi-File Commits

A single commit should be a coherent unit of change. Prefer fewer, meaningful commits over many granular ones. Guidelines:

- A policy restructuring session that touches six policy files is one `workflow` commit, not six.
- An implementation that adds a script and its tests is one `feat` commit, not separate `feat` + `test`.
- A session that produces both a feature and an unrelated chore fix is two commits — do not bundle unrelated changes.

---

## Checkpointing

A session that ends with uncommitted work is a risk — the handover records intent, but the filesystem is the only copy. Commit at session end even if the work is incomplete.

**Rules:**
- At session close, commit all work-in-progress on the active branch with a clear message: `wip: description of incomplete state`
- `wip` is not a commit type — it is a prefix that signals the commit is not reviewable. The next session amends or follows up.
- Do not leave uncommitted changes across session boundaries. The handover cannot reconstruct files; the commit can.
- On integration branches, session branches should be merged (not left dangling) before the session ends, even if the integration branch itself is not ready for `main`.

This is the git-level equivalent of the `autosave.diff` pattern in the execution model — a checkpoint that preserves state without implying completeness.

---

## Merge Policy

### Session branch → integration branch

**Squash merge.** Each session branch becomes a single commit on the integration branch. The squash message uses the appropriate commit type and summarises the session's contribution. Individual session commits are implementation detail — the integration branch reads as a sequence of coherent steps.

### Session branch → `main` (simple case)

**Squash merge.** Same rationale — the branch collapses to one commit on `main`. If the branch has only one commit already, a fast-forward merge is acceptable.

### Integration branch → `main`

**Merge commit.** Preserves the sub-milestone as a visible unit in `main`'s history. The merge commit message follows the format:

```
feat: complete M2.1 — snapshot pipeline and diff workflow
```

Use the dominant commit type for the sub-milestone. If the sub-milestone is mixed (feat + docs + build), use `feat` if it delivers new capability, or `docs` if it is primarily documentation.

### Review gate

No branch merges to `main` without operator review and approval. This restates the system invariant: all repository mutation is operator-initiated. For integration branches, the operator may review incrementally (session branch merges) or as a whole (integration branch merge to `main`), but the final merge to `main` always requires explicit approval.

### Conflict resolution

The operator resolves conflicts. When two session branches on the same integration branch touch overlapping files, the second branch to merge resolves conflicts against the integration branch before merging. Conflicts on merge to `main` are resolved on the integration branch, not on `main`.

---

## Tagging

**Status:** Convention defined. Adopt when the first use case arises — currently parked.

Tags mark major milestone boundaries on `main`. The tag is placed on the merge commit that completes the milestone.

**Format:**
```
m1
m1.5
m2.1
```

Lower-case `m`, milestone number, dot-separated sub-milestone. No `v` prefix — these are milestone markers, not version releases.

**When tagging becomes active:**
- CI/CD triggers off milestone tags (M3+)
- Reproducing a run against a specific milestone state (`git checkout m2.1`)
- Diffing between milestones (`git log m1.5..m2.1`)
- Sharing the repo with contributors who need stable reference points

Until one of these applies, tagging is optional. The changelog and handover chain provide the same historical record in prose form.

---

## Scope Field

Not adopted. When component boundaries are stable enough to name consistently (e.g. `snapshot`, `diff`, `mcp`, `entrypoint`), scope can be introduced as `type(scope): description`. Until then, the short description carries enough context.

---

## References

| Document | Purpose |
|---|---|
| [`handover_policy.md`](handover_policy.md) | Session types that map to commit types |
| [`contributors.md`](contributors.md) | General contribution rules and branch protection |
| [`standard_operating_procedures.md`](standard_operating_procedures.md) | Human / Operational Protocols |
| [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) | Upstream specification this policy draws from |

---

## [FINDINGS: 2026-05-22] — Proposed Rules from Session Practice

This section captures rule proposals derived from hands-on git operations during sessions. These are **not adopted policy** — they are candidates observed to solve recurring problems. After multiple sessions produce overlapping proposals, common patterns will be distilled and elevated into the main policy sections above.

Each entry states the observed symptom, the provisional rule that addressed it, and the reasoning. Refer to the handover chain for full session context.

---

### Finding 1: In-sandbox commits are safe — the pipeline handles them

**Observed:** The sandbox-level AGENTS.md states "Committing inside the sandbox corrupts the diff pipeline." In practice, commits made inside the sandbox are captured correctly by the startup-baseline / exit-diff pipeline. Multiple correction commits and this session's three-commit sequence confirmed the diff pipeline handles intervening commits without corruption.

**Proposed rule:** The AGENTS.md constraint should be corrected to: "Commits are permitted but optional; the session diff captures all changes between session start and exit regardless of commit state." The original wording risks unnecessary avoidance of legitimate git operations.

**Scope:** Policy document correction (AGENTS.md, not git_policy.md). Listed here because the practice of committing during a session is the subject of several other findings below.

---

### Finding 2: Stash only single-session work — commit session boundaries

**Observed:** A single stash contained changes from two distinct sessions (handover 11 and handover 12). Splitting them afterward required patch extraction, selective reset, and per-commit `git apply`. The interleaved changes in `roadmap.md` could not be cleanly separated without manual patch editing.

**Proposed rule:** A stash should only hold in-progress changes from one session. If work spans multiple sessions (e.g., a planning session followed by an investigation session), commit the first session's output before starting the second — even if the branch is not yet ready for review. Use `wip:` prefix for incomplete states per the Checkpointing section above.

**Rationale:** Session boundaries are the natural unit of git policy. Stashing across them merges independent intent into one diff, making later separation expensive and error-prone.

---

### Finding 5: `amend` for corrections, new commits for new work

**Observed:** When the EPERM correction commit already existed and we needed to add the resolution + story document, `git commit --amend` folded the new content into the existing commit cleanly — including an updated commit message documenting what was added. This was better than creating a separate "add resolution" follow-up commit.

**Proposed rule:** Use `git commit --amend` to fold post-hoc discoveries, corrections, or additions into their parent commit when the new content is a completion of the same logical unit. Create a separate commit when the new content is substantively new work, a different type, or would make the parent commit's message misleading.

**Rationale:** Amending preserves history shape and avoids orphaned one-line follow-up commits that clutter the log. The rule aligns with "a commit should be a coherent unit of change" — a correction to a commit is part of that unit, not a separate unit.

---

### Finding 6: `mv` for untracked files, `git mv` for tracked; grep for cross-references

**Observed:** Renaming an untracked handover file (`20260513-13` → `12`) required plain `mv` — `git mv` rejects untracked files. The renamed file then needed to be `git add`-ed explicitly. Cross-references to the old filename in other docs were caught by `grep -rn` across the tree.

**Proposed rule (git operation):**
- Use `git mv` for tracked files (preserves history, stages the rename automatically).
- Use plain `mv` for untracked files, then `git add` the new path.
- Before committing any rename, run `grep -rn "<old filename>" docs/` and update every reference.

**Rationale:** Untracked files have no history to preserve — `git mv` adds ceremony without benefit. Tracked files need `git mv` so git detects the rename instead of recording a delete+add pair.

**Proposed rule (elevation to AGENTS.md — see next section):** See §Rules for Elevation to AGENTS.md below.

---

### Finding 7: Patch-based staging for files touched by multiple sessions

**Observed:** `roadmap.md` was modified by both handover 11 and handover 12 sessions. Splitting the interleaved changes into two commits required: `git diff > file.patch`, `git checkout HEAD -- file`, then `git apply` per commit. This produced clean, reviewable commits with no cross-session noise.

**Proposed rule:** When a single file contains changes from multiple sessions that must be split into separate commits:

1. Save the full diff: `git diff > file.patch`
2. Reset to HEAD: `git checkout HEAD -- file`
3. For each commit, apply only the relevant hunks: `git apply file.patch` (then stage and commit)
4. Repeat for each remaining session's changes

If the file cannot be split by hunk boundaries (interleaved changes to the same logical section), consider splitting into two files or restructuring the changes so each session's work is disjoint. Modifying a file in multiple sessions without hunk-level separation is a signal that the sessions should have been committed sequentially.

**Rationale:** This avoids interactive `git add -p`, produces a consistent file state per commit, and leaves a recoverable patch file while staging. The patch file can be discarded after all commits are created.

---

## §Rules for Elevation to AGENTS.md

Some operational patterns recur frequently enough that they should become first-class rules in the project-layer `AGENTS.md` — the document that governs agent behaviour in every session. Elevating a pattern there makes it discoverable without reading session-specific findings.

**Gate for elevation:** A pattern observed in three or more sessions, or confirmed as structurally load-bearing (failure to follow it causes data loss or non-recoverable state).

### Candidate: Rename protocol (from Finding 6)

**Pattern:** Renaming a file requires updating all cross-references to the old name across the repository.

**Draft AGENTS.md rule:**

> **Rename protocol.** When renaming a file or directory, before committing:
> 1. Search the entire repository for references to the old name: `grep -rn "<old name>" .`
> 2. Update every reference — including paths in documentation, configuration files, and code comments.
> 3. For tracked files, use `git mv` to preserve history. For untracked files, use plain `mv` then `git add`.
> 4. Do not leave stale references to the old name. A rename is incomplete until its old name produces zero grep matches outside the git reflog.

**Reasoning:** Renaming is cheap in git (the rename is detected automatically) but expensive in documentation (paths are scattered across handovers, design docs, architecture docs, and READMEs). The stale reference from the 13→12 rename (`devlog/discussions/design_session_identity_hash_based.md` still referenced `20260513-12-design-two_sig_model.md`) was caught only because the operator noticed it — not because the protocol existed.

### Candidate: Amend protocol (from Finding 5)

**Pattern:** Post-hoc corrections or completions should be folded into their parent commit rather than creating follow-up commits.

**Draft AGENTS.md rule:**

> **Amend for corrections.** When new information completes or corrects work from the current session's prior commit (not a prior session's commit), use `git commit --amend` to fold the change in. Create a separate commit only when the new work is substantively different in type, scope, or intent from the parent commit.

**Reasoning:** Amending keeps the log linear and avoids clutter from "oops — also this" commits. The boundary is clear: correction of the same logical unit → amend; new work → new commit.
