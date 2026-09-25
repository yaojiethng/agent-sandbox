# Mutation Bite Corpus

This directory is a draft capture of the mutation ("bite") corpus produced by the 2026-09-24/25 test-suite read-through. The read-through ran 49 throwaway scripts from `/tmp/bite*.sh`; the harness does not snapshot `/tmp`, so the scripts are copied here, unchanged in behaviour, to keep the executable record alive. The readable record, with the recorded verdicts, is the register [`devlog/discussions/20260924-design-active-test_suite_readthrough.md`](../../devlog/discussions/20260924-design-active-test_suite_readthrough.md), whose 19 bites tables carry 245 rows.

## Status

The corpus is a draft capture, not a runnable suite. Nothing wires it into a runner or a gate, and it is kept only so the executable record survives. Several mutations in it are known to be ineffective; read the register and the Known-bad mutations section before replaying any of them.

## Discovery

`scripts/run_tests.sh` discovers only `tests/test_*.sh` at the top level, and `scripts/check_test_liveness.sh` uses the same glob. A file under `tests/mutations/` matches neither, so no file here is run or registered as a test. `scripts/check_shell.sh` scans `tests/` recursively for `*.sh`, so `scripts/lint.sh` and the pre-commit hook still lint every file here with `shellcheck -S warning`.

## Index

The mutation count is the number of `bite <name> '<old>' '<new>'` triples parsed in the file; a count of `0` means the file uses one of the older harnesses (`run_bite` with a `sed` expression, `run_case`, `run_mut`, `mut`, `run_one`, or an in-line `awk` line replacement) or carries a subject copy. The class is `sweep` for a per-file sweep and `method` for a file that carries a subject or harness copy rather than a runnable sweep.

| File | Subject | Mutations | Class |
|---|---|---|---|
| `bite.sh` | `src/libs/session_inventory.sh` | 0 | sweep |
| `bite2.sh` | `src/libs/session_inventory.sh` | 0 | sweep |
| `bite3.sh` | `src/libs/session_inventory.sh` | 0 | sweep |
| `bite4.sh` | `src/libs/session_inventory.sh` | 0 | sweep |
| `bite5.sh` | `src/libs/session_inventory.sh` | 0 | sweep |
| `bite6.sh` | `src/libs/session_inventory.sh` | 0 | sweep |
| `bite_apply.sh` | `scripts/workflows/apply.sh` | 22 | sweep |
| `bite_apply2.sh` | `scripts/workflows/apply.sh` | 3 | sweep |
| `bite_bs.sh` | `scripts/build.sh` | 11 | sweep |
| `bite_cli.sh` | `src/libs/cli.sh` | 0 | sweep |
| `bite_common.sh` | `src/libs/common.sh` | 0 | method |
| `bite_confirm.sh` | `scripts/workflows/confirm.sh` | 24 | sweep |
| `bite_cs.sh` | `src/build/compose.sh` | 21 | sweep |
| `bite_de.sh` | `src/libs/diff_export.sh` | 0 | sweep |
| `bite_diff.sh` | `src/libs/diff.sh` | 0 | sweep |
| `bite_dirs.sh` | `src/libs/dirs.sh` | 0 | method |
| `bite_dispatch.sh` | `scripts/agent-sandbox.sh` | 20 | sweep |
| `bite_dispatch2.sh` | `scripts/agent-sandbox.sh` | 12 | sweep |
| `bite_draft.sh` | `scripts/workflows/draft.sh` | 39 | sweep |
| `bite_draftstate.sh` | `src/libs/draft_state.sh` | 0 | sweep |
| `bite_env.sh` | `src/libs/env.sh` | 0 | method |
| `bite_env_resolve.sh` | `src/libs/env_resolve.sh` | 0 | method |
| `bite_ep.sh` | `src/capability/entrypoint.sh` | 14 | sweep |
| `bite_hints.sh` | `src/libs/session_hints.sh` | 0 | sweep |
| `bite_hook.sh` | `src/capability/git-hooks/pre-commit.sh` | 9 | sweep |
| `bite_img.sh` | `src/build/image.sh` | 0 | sweep |
| `bite_img2.sh` | `src/build/image.sh` | 0 | sweep |
| `bite_in.sh` | `scripts/install.sh` | 11 | sweep |
| `bite_int.sh` | `scripts/workflows/interactive.sh` | 0 | sweep |
| `bite_interface_contract.sh` | `src/libs/interface_contract.sh` | 0 | method |
| `bite_mk.sh` | `scripts/templates/Makefile.template` | 0 | sweep |
| `bite_onboard.sh` | `scripts/onboard.sh` | 0 | sweep |
| `bite_pb.sh` | `src/libs/package_branch.sh` | 0 | sweep |
| `bite_prune.sh` | `scripts/prune.sh` | 0 | sweep |
| `bite_ra.sh` | `scripts/run_agent.sh` | 0 | sweep |
| `bite_ra2.sh` | `scripts/run_agent.sh` | 4 | sweep |
| `bite_ra3.sh` | `scripts/run_agent.sh` | 0 | sweep |
| `bite_reject.sh` | `scripts/workflows/reject.sh` | 0 | sweep |
| `bite_resume.sh` | `scripts/resume_agent.sh` | 21 | sweep |
| `bite_resume2.sh` | `scripts/resume_agent.sh` | 10 | sweep |
| `bite_routing.sh` | `src/libs/routing.sh` | 0 | sweep |
| `bite_se.sh` | `src/libs/session_env.sh` | 0 | sweep |
| `bite_snap.sh` | `src/capability/snapshot.sh` | 9 | sweep |
| `bite_ssp.sh` | `src/libs/session_save_policy.sh` | 0 | sweep |
| `bite_ssp2.sh` | `src/libs/session_save_policy.sh` | 0 | sweep |
| `bite_ssp3.sh` | `src/libs/session_save_policy.sh` | 0 | sweep |
| `bite_st.sh` | `scripts/stop.sh` | 11 | sweep |
| `bite_start.sh` | `scripts/start_agent.sh` | 0 | sweep |
| `bite_sv.sh` | `src/capability/seed_volume.sh` | 15 | sweep |

## Call forms

Two forms appear. The recommended form is the literal triple, where the script passes each literal through the environment to `perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/'` so a variable inside the literal is not interpolated by the shell:

```bash
bite A1 'if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then exit 1; fi' 'if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then :; fi'
```

The older form runs the mutation with a `run_bite` wrapper and a `sed` expression, or with an in-line `awk` line replacement.

## Naming

The corpus labels its mutations with per-pass letter series: A1 to A22, R1 to R14, B6 to B12, I1 to I9, V1 to V4, and others. The read-through-run prompt, `workflow/coding-agent/prompts/read-through-run.md`, now requires a `bite <row>.<n>` label derived from the finding row the bite supports. The corpus predates that rule, so its labels are not row-derived, and the mapping from series label to finding row is not done yet.

## Known-bad mutations

Two forms in the record are not mutations and must not be replayed as they stand. Appending `&& false` inside `[[ ]]` is a no-op, because the right-hand operand is a string test on a non-empty literal; the corpus uses that form at A2, A3, A4, and A6 in `bite_resume.sh` and at R3 in `bite_ra.sh`. An `-n /dev/null` probe has the same defect; the record carries it as a probe rather than as a captured bite. One bite was redone: R3 in `bite_ra.sh` is superseded by R3c in `bite_ra2.sh` and `bite_ra3.sh`. The corrected resume bites are A2b, A3b, and A4b in `bite_resume2.sh`.

## Cost

The corpus holds 318 `bite`/`run_bite` call sites by count, 256 of which parse as literal triples. Each run executes the full suite, so a full sweep is roughly an hour serial.

## State at capture

247 of the 256 parsed anchors still match their subject file. The recorded verdicts are a 671-to-722-unit baseline, while the suite is now 782 units. Every captured script passes `shellcheck -S warning`.
