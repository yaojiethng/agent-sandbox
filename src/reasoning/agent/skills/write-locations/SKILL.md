---
name: write-locations
description: "Where a file may be written and what happens to it afterwards: whether it reaches the review, how long it survives, and who can see it. Use before writing a path outside the working tree, when choosing where a scratch tool or a measurement instrument goes, and when deciding whether a file must outlive the session."
---

# Write locations

Every root a session can write to has a lifecycle and a visibility, and the two are separate questions. A file is written where its lifecycle is, so the choice of location is a claim about how long the file matters and who is allowed to read it.

## When to use

- Before writing any path outside the working tree.
- When an instrument, a corpus or a comparison script has to be reused by a later session.
- When deciding whether a file may be deleted with the container.

Not this: which folder a document or a record belongs to inside the repository is the `docs` and `work-log` conventions; the session's own working state is the `active-tracker` skill; whether the work is committed is the calling unit's judgement, not a property of a location.

## The roots

| Root | What it holds | Survives | Visible to |
|---|---|---|---|
| the working tree | the deliverable: code, documents and records | the container, because the tree is a volume or a host worktree | the review, because it is the diff |
| `.scratchpad/` | session scratch: throwaway verification, and state a `/fork` or `/tree` must carry across | the container | this session's agent, and the host where the tree is the host worktree |
| `workspace/input/` | the operator's handover, read-only | the session and beyond | the operator |
| `workspace/output/` | the session's result, and any instrument a later session reuses | the session and beyond | the operator |
| `workspace/session-diffs/` | the session diff output | the session | the operator |
| `/tmp` | what the operating system and its tools need while they run | nothing, once the container is recreated | this container |
| `$AGENT_HOME/` | the agent's own configuration | the container, except for the subdirectories the host mounts | this container, and the host for those subdirectories |

The harness's own roots under `/opt/` are image-owned and read-only: they are installed, never written. The manifest `src/build/container-interface.json` declares the session roots and what each holds, so it is the source the table above follows; a root the manifest does not declare is not a place to write.

**Name what a location survives, and never say "durable" alone.** A file in the working tree survives the container, a file in session scratch does not survive the session, and that difference is the whole point: a session-scoped root dies with the session's volume, so it cannot carry work to the next one.

## The judgements

**A file belongs where its lifecycle is.** The failure is a file in a root whose lifecycle is shorter than the file's use. An instrument written to session scratch is gone at exactly the moment it is wanted again; a deliverable written to the output mount never reaches the diff and is never reviewed.

**An instrument a later session reuses is not throwaway.** Throwaway means a file you create only to check something and do not keep. An equivalence harness, a measurement corpus or a comparison script is the opposite: it is the evidence for a claim another session will re-check, so it belongs in the output mount, and the path is recorded where the claim is.

**Nothing outside the working tree reaches the diff.** A file written to scratch, to the output mount, to `/tmp` or to the agent's home is not part of the change set. A change the caller has to review goes in the tree.

**A read-only root is read.** The handover mount is the operator's, so a write there is a write to their handover.

## Non-goals

- Does not choose where a document or a record goes inside the repository. That is the `docs` and `work-log` conventions.
- Does not decide whether work is committed, or which branch carries it.
- Does not describe the diff pipeline, the snapshot or the review step.

## Failure modes

| Failure | What it looks like | What to do |
|---|---|---|
| An instrument in session scratch | the file is gone at the next session, and the claim it backed cannot be re-checked | write it to the output mount, and record the path where the claim is recorded |
| An artifact outside the tree that the review needs | the change set does not carry it, so the reviewer never sees it | move it into the tree |
| A write to the handover mount | the operator's input changes under them, or the write fails | read it, and write the answer where the deliverable goes |
| A path no root declares | a directory in the container layer, gone at the next teardown | use a declared root, and report the missing root rather than inventing one |
