# Documentation Status

Session-scoped hot file list for the current milestone. Cold files are not listed — absence from this list means the file is not expected to change this milestone.

For a full project file index with freeze status and architecture layer assignments, see [`project_index.md`](project_index.md).

---

## Current Milestone: M1.5 — Workflow Convergence & Directory Restructuring

Task list and completion criteria: [`roadmap.md`](roadmap.md) — M1.5 section.

---

## Hot Files

Files expected to change this milestone. Read fresh at session start. Use `grep -n "^##"` to get section map before reading content.

| File | Why hot | Relevant section |
|---|---|---|
| `scripts/start_agent.sh` | Primary implementation target — `PROJECT_ROOT` → `PROJECT_DIR`, `SANDBOX_DIR` derivation, mount updates | Variable declarations block, `docker run` invocation, mount construction |
| `scripts/agent-sandbox.sh` | CLI wrapper — `--root` flag rename to `--project` | Flag parsing section |
| `providers/opencode/build_agent.sh` | May reference `PROJECT_ROOT` — confirm and update | Variable declarations |
| `container-entrypoint.sh` | Input channel — copy `input/` contents into `sandbox/` at startup | Startup/init section |
| `libs/snapshot.sh` | Path derivation — `PROJECT_ROOT` references | Path variable block |
| `docs/architecture/execution_model.md` | New directory layout, updated terminology, updated mount shape table | Directory layout section, mount shape table |
| `docs/concepts/agent_workflow.md` | Updated operator directory layout and pre-run setup instructions | Pre-run setup section |

---

## Warm Files

Referenced this milestone but not expected to change unless implementation reveals a need.

| File | Why warm |
|---|---|
| `libs/diff.sh` | May reference project paths — confirm clean via grep before session ends |
| `libs/image.sh` | Same as above |
| `docs/architecture/security.md` | Input channel adds a new mount — confirm no new invariants required |

---

## Notes

- `execution_model.md` and `agent_workflow.md` are updated last — after all script changes are confirmed working
- `libs/` files: run `grep -rn "PROJECT_ROOT" libs/` at session start; only open files that appear in results
- Do not touch `docs/development/roadmap.md` mid-session; update task checkboxes in a single pass at session end
