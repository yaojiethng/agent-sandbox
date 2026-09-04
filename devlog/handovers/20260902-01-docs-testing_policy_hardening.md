# Handover 20260902-01 — docs harden testing policy (seven proposals) + retire discovery_ prefix

**Milestone:** M2.6 - Session Persistence (supporting policy work)
**Type:** docs
**Status:** Closed
**Date:** 2026-09-02

## Objective

Operator-driven reflection on this session's test output surfaced seven policy gaps in the testing documents. This iteration proposes the policy edits (one section at a time, per `documentation_policy.md`), logs the finding, and files the cleanup items. The first deliverable is the retirement of the non-conforming `discovery_` test prefix.

## Proposals (queue)

1. `testing-conventions.md` Anti-Pattern 6 — change-mirror test (presented, awaiting apply).
2. `testing_policy.md` `make test` invariant — prerequisite failure vs assertion failure (presented, awaiting apply).
3. `testing_policy.md` knowledge-test prefixes — retire `discovery_`, fold probes into `knowledge_` (revised for the operator's prefix list, pending).
4. `testing-conventions.md` checklist — output-contract propagation checklist item.
5. `testing-conventions.md` checklist — pins carry a rationale.
6. `testing-conventions.md` checklist — dead-test liveness (defined-but-unregistered).
7. `testing_policy.md` Keeping Tests Current — untested behaviour branches.

No policy text is written until the operator approves each proposal. Application happens after approval; the code cleanup items below are a separate pass.

## Completed

| Task | Evidence |
|---|---|
| Proposals 1 through 7 applied | `docs/development/testing-conventions.md` (Anti-Pattern 6, checklist items: rationale-pin, liveness, output-contract) and `docs/development/testing_policy.md` (prerequisite rule, probe + diagnose one-liners, untested-branch rule) |
| Finding logged | `devlog/AGENT_FEEDBACK.md` entry |
| Cleanup items filed | `devlog/roadmap.md` M2.6 general track |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | `discovery_` prefix retired; probes use `knowledge_` | operator: `discovery_` is vague; probe content is external-tool behaviour, which is the knowledge category |
| D2 | Cleanup items are roadmap entries, not policy text | `documentation_policy.md`: future work belongs in `roadmap.md` |
| D3 | Findings logged in AGENT_FEEDBACK, attributed [A] (agent-introduced) | the prefix non-conformance came from this session's work |

## Findings

- **Non-conforming `discovery_` prefix.** The tar feasibility probes landed in `tests/knowledge/` as `discovery_tar_*.sh`, a prefix the testing policy does not list. Their content (external-tool behaviour: rsync negation leak, tar `--transform`) is the knowledge category; the name is the defect. Cleanup: rename to `knowledge_tar_*.sh`.

## Deferred / cleanup items (roadmap)

- Rename `tests/knowledge/discovery_tar_*.sh` to `knowledge_tar_*.sh`; update the two cross-references (`docs/concepts/copy_delivery.md`).
- Register or delete the dead test `test_list_no_sig_when_field_empty` in `tests/test_resume.sh`.
- Add the dead-test liveness check (every `test_*()` registered; every `run_test` target resolves) and the prerequisite-liveness check (stub executable, shim present) — mechanical checkers.
