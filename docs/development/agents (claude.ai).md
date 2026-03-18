# agents.md — Claude Chat (claude.ai)

## Interface

Claude Chat (claude.ai). Artifacts are available. The agent has no direct filesystem access — all outputs are produced as artifacts and reviewed by the operator before being applied to the repository.

---

## What a session is

A session is a single claude.ai conversation. Memory does not persist across conversations — every new conversation starts with a completely empty context. There is no residual knowledge of repository files, prior decisions, or session state from previous conversations. The handover document and uploaded files are the complete and only context for any session.

This definition is the basis for the file access gate below. It is not the same as the workflow unit ("a design session," "an implementation session") — a single workflow session may span multiple conversations if interrupted, and each conversation restart resets file knowledge entirely.

---

## File access gate

**Do not produce any output derived from the content of a repository file unless that file has been uploaded to this conversation.**

Reconstructing or approximating file content from memory or prior training is prohibited. Repository files change between sessions; training knowledge of specific repo files is always stale and must not be used as a substitute for the actual file.

If a task requires a file that has not been uploaded:
1. Name the missing file explicitly.
2. Ask for it before proceeding.
3. Do not approximate, infer, or produce partial output while waiting.

This gate applies to every output in the conversation — not only at session start. If a later task requires a file not yet uploaded, stop and ask for it then.

---

## Output mechanism

All document and file outputs are produced as **artifacts**, one artifact per file. Inline chat prose is not a substitute for an artifact when the output is intended for the repository.

Artifacts are considered ready for operator review upon production. The operator will request amendments or restate requirements if changes are needed — no explicit confirmation prompt is required after each artifact.

For multi-file outputs (e.g. a compaction pass touching several roadmap sections), produce one artifact per file.

---

## Session start

At session start, check which files have been uploaded to the conversation. Required reading files that are absent must be requested before proceeding — do not begin session work without them.

The most recent handover (`YYYYMMDD-NN-TYPE-*.md`) and `roadmap.md` are the minimum required uploads for any implementation or workflow session.

---

## Constraints

- No bash, grep, or filesystem access. File content must be uploaded by the operator.
- Read discipline still applies: establish what you need from a file before asking for it. If a section map is needed, ask the operator to share the file — do not ask for the full file when a grep result would suffice.
- Memory does not persist across conversations. The handover and uploaded files are the complete context.

---

## References

| Document | Purpose |
|---|---|
| [`agent_context_brief.md`](agent_context_brief.md) | Collaboration protocol, output format principles, read discipline |
