# The carrier census

**Status:** draft

## Context

One model of how a harness input reaches a reader was needed before M3.4.2 could be designed. This record is the census that produced it: every value-entry and value-read site in `src/` and `scripts/`, the persistent record key sets read from their writers, and the precedence rule each reader implements.

The census ran as a read-only reviewer dispatch on 2026-10-16, against the tree of that day. Its decisions landed in [`resolution_model.md`](../../docs/adr/resolution_model.md) and three defect rows under M3.4.2 in [`roadmap.md`](../roadmap.md).

**This file is a working record.** Delete it once every entry in `## Resolution status` is resolved. It is not a durable design artifact. The decisions it fed live in the ADR; the defects it found live in the roadmap. This record must not outlive its open entries.

When the census ran, the ADR was named `env_resolution.md`. It is now `resolution_model.md`; the census's line references to it are to the same file.

## The brief

Read the tree and answer four questions. Which carriers can supply each key? Which reader implements which precedence rule? Where do two readers of one key disagree? Would a single resolution ADR subsume the eleven documents the M3.4 run named, and which marker mechanic applies to an ADR whose claims move? Two constraints were given: cite a file and a line for every claim, and do not restate a rule from a document without reading the code that implements it.

## Compact log of actions

| Idiom | Command | Lines | Occurrences | Distinct tokens |
|---|---|---|---|---|
| env | `grep -rnE 'AGENT_SANDBOX_[A-Z_]+' src scripts` | 49 | 54 | 4 |
| loader | `grep -rnE 'env_load\|env_file_value\|_env_value' src scripts` | 10 | 10 | 2 |
| resolver | `grep -rnE 'env_resolve_one\|env_resolve_identity\|default_env_file' src scripts` | 21 | 21 | 3 |
| parser | `grep -rnE 'parse_args\|parse_args_collect' src scripts` | 23 | -- | 14 call sites |
| session record | `grep -rnE 'session_state_read\|env_field\|record_label\|record_provider' src scripts` | 43 | 43 | 4 |
| Make layer | `grep -rnE '\$\((if\|or\|and) ' scripts/templates` | 35 | -- | 1 file |
| process env | `grep -rnE '^\s*export [A-Z_]+\|env [A-Z_]+=' src scripts` | 34 | -- | `export VAR` 34, `env VAR=` 0 |

Env-idiom token breakdown: `AGENT_SANDBOX_REPO` 49, `AGENT_SANDBOX_PROJECT_DIR` 3, `AGENT_SANDBOX_PROJECT_NAME` 1, `AGENT_SANDBOX_SANDBOX_DIR` 1. So 49 of 54 occurrences are a key that is not an identity key, and exactly three lines in the tree read an `AGENT_SANDBOX_*` key as a resolution level, all in `src/libs/env_resolve.sh` (96, 107, 114).

Carrier site census: 14 `parse_args`/`parse_args_collect` call sites, with `scripts/agent-sandbox.sh:145` the only collect site; 34 `export VAR` lines; `env_load` called from `src/libs/session_env.sh:52`; `env_resolve_identity` at four sites; `.compose/<sid>.yml` read through `record_provider`/`record_label`/`env_field`; `.git/SESSION_STATE` read by `session_state_read` at 12 call sites; the worktree git config key `agent-sandbox.flatten` at `scripts/start_agent.sh:438` and `scripts/resume_agent.sh:267`; and the Docker labels, read only through `record_label` on the persisted `.compose` file, because no live `docker inspect` label reader sits in the resolution path.

## Mid-run adjustments

The dispatch ran the pinned reviewer pair. The `openrouter` half returned `401 API key expired` and produced nothing, so one report stands and the census is single-model. That is a T12 row, not this milestone's.

`make` is absent from the container, so the Make-layer rows are read from source and are marked unverified.

The brief named `docs/concepts/env_resolution_layers.md`. No `docs/concepts/` tree exists on this branch. That is an error in the brief: the file is a draft-branch artifact, not a mainline document. Every claim the census would have attributed to it is unverified, and none was used.

## Findings summary

### The carrier matrix

Columns: the key, the carriers that can supply it, its readers, the precedence order implemented, and the top of the ladder. "Runtime derivation" means the code computes the value and passes it as the explicit argument.

| key | carriers | reader(s) | precedence implemented | top |
|---|---|---|---|---|
| `PROJECT_NAME` | argument `--name`; env `AGENT_SANDBOX_PROJECT_NAME`; `.env` | `env_resolve_one` `env_resolve.sh:107`; `session_env_common_init` `session_env.sh:35-58` | explicit arg > `AGENT_SANDBOX_PROJECT_NAME` > `.env` > hard error | argument |
| `PROJECT_DIR` | argument `--project`; env `AGENT_SANDBOX_PROJECT_DIR`; `.env` | `env_resolve_one` `env_resolve.sh:114`; a second read at `resume_agent.sh:115` | explicit arg > `AGENT_SANDBOX_PROJECT_DIR` > `.env` > hard error | argument |
| `SANDBOX_DIR` | argument `--sandbox`; runtime derivation `start_agent.sh:333-337`; env `AGENT_SANDBOX_SANDBOX_DIR`; `.env` | `env_resolve_one` `env_resolve.sh:96`; `sandbox_dir_canon` `common.sh:39-50` | runtime derivation, passed as the explicit arg, > `AGENT_SANDBOX_SANDBOX_DIR` > `.env` > hard error | runtime derivation |
| `ENV_FILE` / `ENV_REL` | argument `--env`; derived `<sandbox>/.env`; derived `$CWD/.env` | `default_env_file` `env_resolve.sh:37-46`; Make `ENV_FILE := $(CURDIR)/.env` `Makefile.template:88` | absolute `--env` > `<sandbox>/.env` > `$CWD/.env` | argument |
| `SERVE_PORT` | `.env` through `env_load`; process env | `run_agent.sh:165-171` with default 46553; compose `${SERVE_PORT}` `compose.sh:70` | `.env` overwrites the ambient env, then a hard default | `.env` |
| `AUTOSAVE_INTERVAL` | `.env`; process env; container env | `docker-compose.yml:97`; `entrypoint.sh:66, 330` | container env literal with a `:-60` fallback | container env |
| `INSTALL_DIR` | process env; repo-root `.env`; `~/.local/bin` default | `install_dir` `install.sh:124-131` | env > `$REPO_ROOT/.env` > `~/.local/bin` | process env |
| `MAKEFILE_VERSION` | `.env` only | no reader; grep finds only `onboard.sh:181, 196, 251` | n/a | none |
| `DELIVERY` | argument `--delivery`; make variable `SANDBOX_TYPE` -> `--delivery` `Makefile.template:172`; `.env` key leaked by `env_load` | `run_agent.sh:123-129, 148-151`; `start_agent.sh:256, 281-287, 403` | argument only; `run_agent` refuses an empty value; an ambient value is flagged and ignored at `resume_agent.sh:223-225` | argument |
| `SANDBOX_TYPE` (record literal) | make variable; argument as `--delivery`; persisted compose env literal; container env | `env_field` `session_inventory.sh:67-71` read at `resume_agent.sh:214` and `prune.sh:131`; `entrypoint.sh:41` | on resume the record wins and an ambient value warns; on start `--delivery` > `copy` default | record on resume |
| `FLATTEN` | argument `--flatten`; make variable `Makefile.template:114, 173`; `.env` key leaked by `env_load`; compose env literal; container env; worktree git config `agent-sandbox.flatten` | `start_agent.sh:261, 425-458`; `run_agent.sh:110-140`; `resume_agent.sh:234-242, 266-271`; `entrypoint.sh:44, 114` | start: `--flatten` > worktree git config, which must agree or the start is refused. resume: the record wins and the worktree config disagreement only warns | argument on start, record on resume |
| `--provider` | argument `--provider`; make variable; recovered from the session record | `start_agent.sh:356-362` with no default; `run_agent.sh:131-134`; `resume_agent.sh:209` through `record_provider` `session_inventory.sh:46-53`; `prune.sh:241` as a filter | argument on start, record-derived on resume | argument / record |
| `VERBOSE` | argument `-v`/`-vv`; process env | `run_tests.sh:19, 209, 292-293, 345` | `-v`/`-vv` overwrites `VERBOSE="${VERBOSE:-0}"` | argument |
| `INIT_SHA` / `init_sha` | derived at the delivery boundary; persisted to `SESSION_STATE`; overridable by `--baseline` | writer `session_state.sh:63`; writers `seed_volume.sh:168-170, 208-209` and `entrypoint.sh:113-124`; readers `package_branch.sh:97, 342`, `diff.sh:265`, `routing.sh:43-45`, `session_save_policy.sh:83, 109`, `package_eval_snapshot.sh:340` | `--baseline` > `init_sha`, with four variant rules among the readers (see below) | `--baseline` |
| `SESSION_ID` | derived hash; record filename; record label | `session_id_derive` `session_env.sh:124-128`; writers `start_agent.sh:199, 207`; readers `resume_agent.sh:200`, `package_branch.sh:497`, `package_eval_snapshot.sh:334, 508` | derived at start, read off the record at resume and never recomputed | derived |
| `SESSION_TS` | derived `date -u`; record label | `start_agent.sh:197`; `resume_agent.sh:253` through `record_label` | derived at start, the record at resume | derived |
| `HOST_HEAD_SHA` | derived `git rev-parse HEAD`; record label | `start_agent.sh:198`; `resume_agent.sh:255`; `entrypoint.sh:158` | derived at start, the record at resume | derived |
| `CHANGES_DIR` / `INPUT_DIR` / `OUTPUT_DIR` | `SESSION_STATE`; derived by `dirs_resolve`; container env literal | `routing.sh:40-55`; `dirs.sh:82-94`; `entrypoint.sh:126-128, 161-163` | the `SESSION_STATE` key wins over `dirs_resolve`, which fills the gaps | record |
| `PROVIDER_FILTER` | argument `--provider` on resume and prune | `session_inventory.sh:167`; `resume_agent.sh:173-177`; `prune.sh:241, 327` | argument only | argument |
| `RESET_VOLUME` | boolean argument `--reset-volume`; make has no variable | `run_agent.sh:103-104, 118, 370, 411`; `entrypoint.sh:141`; `start_agent.sh:509, 521` | argument; `run_agent` clobbers the ambient value with `false` first | argument |
| `WORKTREE_DIR` | process env; derived `${SANDBOX_DIR}/.worktree` | `session_env.sh:113`; `compose.sh:156`; `resume_agent.sh:266` | env > derived default | process env |
| `AGENT_SANDBOX_REPO` | process env; derived from `readlink -f $0` | `agent-sandbox.sh:46-47`; ambient use in `workflows/{apply,confirm,draft,reject}.sh`, `interactive.sh`, `cli.sh:9` | env > `$0`-derived | process env |
| `INTERACTIVE_MAX_ENTRIES` | process env; hard-coded default 10 | `common.sh:28`; `resume_agent.sh:34` | env > 10 | process env |

### The persistent records and their key sets

**`.env`**, 7 keys, written by `_write_env_file` at `onboard.sh:231-260`: `PROJECT_NAME` (242), `PROJECT_DIR` (245), `SANDBOX_DIR` (246), `MAKEFILE_VERSION` (251), `INSTALL_DIR` (255), `SERVE_PORT` (257), `AUTOSAVE_INTERVAL` (259). `--refresh` rewrites `PROJECT_DIR`, `SANDBOX_DIR`, `PROJECT_NAME` and `MAKEFILE_VERSION` in place (`onboard.sh:193-204`) and deliberately leaves `INSTALL_DIR` alone.

**`.git/SESSION_STATE`**, 8 keys. Five from `session_state_write_set` at `session_state.sh:60-70`: `init_sha` (63), `session_ts` (64), `session_id` (65), `host_head_sha` (66), `interface_contract_version` (69). Three written directly by the capability entrypoint: `changes_dir` (`entrypoint.sh:126, 161`), `input_dir` (`:127, 162`), `output_dir` (`:128, 163`).

**`.compose/<sid>.yml`**. Labels from `docker-compose.yml:36-57`: `project-name`, `sandbox-dir`, `host-head-sha`, `host-branch`, `session-ts`, `session-id`, `agent-image-digest`, `sandbox-image-digest`, `interface-contract-version`, 9 labels. Copy-mode volume labels (`docker-compose.copy.yml:20-26`): 6, with no digest and no contract version. Service `environment:` literals (`docker-compose.yml:92-102`, `copy.yml:34-36, 69-72`, `mount.yml:19-21`): `CHANGES_DIR`, `INPUT_DIR`, `OUTPUT_DIR`, `SANDBOX_DIR_NAME`, `AUTOSAVE_INTERVAL`, `SESSION_TS`, `SANITIZED_HOST_BRANCH`, `HOST_HEAD_SHA`, `SESSION_ID`, `RESET_VOLUME`, `SANDBOX_TYPE`, `FLATTEN`, `SEED_FLATTEN`, 13 literals.

**`.draft-state`**, 9 keys, written by `draft_write_state` `draft_state.sh:68-90`: `source_branch`, `from_hash`, `author`, `session_ts`, `host_branch`, `diff_count`, `exported_at`, `drafted_at`, `session_id`. The accepted set is the allowlist `_DRAFT_STATE_FIELDS` at `:21`.

**`.compose/<sid>.log`**, the fifth record, which the brief did not name. Written by `session_log_set` `session_inventory.sh:222-247`, read by `session_log_read` at `resume_list.sh:29, 151-152`. Keys `last_started`, `last_stopped`, written at `run_agent.sh:319, 430-431`.

### Where two readers of one key disagree

Five readers of `init_sha` implement four baseline rules, and every one is a live site.

| Site | Rule implemented |
|---|---|
| `package_branch.sh:335-350` (`_resolve_baseline`) | `--baseline` validated by `git_commit_exists`, else `init_sha`, then `git merge-base init_sha HEAD`, falling back to `init_sha` |
| `package_branch.sh:95-117` (`package_commits`) | `SINCE_SHA` or `init_sha` literally, with no merge-base and no commit validation |
| `package_eval_snapshot.sh:339-352` | `--baseline` or `init_sha` literally |
| `diff.sh:265-272` (`write_all_changes_diff`) | `SINCE_SHA` or `init_sha` literally |
| `session_save_policy.sh:83, 109` | `init_sha` literally |

`sandbox_host_interface.md:80` and `sandbox_lifecycle.md:40` both state the merge-base rule for all readers. Only one reader implements it.

`FLATTEN` has two precedence rules on two paths. `start_agent.sh:427, 438-458` refuses the start unless the worktree git config equals the requested value, and refuses an absent or non-boolean value. `resume_agent.sh:266-271` lets the record win and only warns on the disagreement.

`SESSION_STATE` readers disagree on the duplicate-key hazard. `session_state_read` (`session_state.sh:30-35`) returns the first match and stops; `session_state_write` (`:53`) appends without dedup. The entrypoint upgrade path (`entrypoint.sh:153-159`) deliberately appends a second `session_id`, `session_ts` and `host_head_sha`, so a migrated volume carries two values and the older one wins permanently.

### Contested classifications

`FLATTEN` is **state** with an argument-shaped front. The argument side cites `start_agent.sh:257-261`, `run_agent.sh:106-110, 140` and `sandbox_delivery_model.md:11`. The state side is stronger: `resume_agent.sh:234-242` recovers it from the record, `start_agent.sh:427` persists it to a second record, `docker-compose.copy.yml:36` and `docker-compose.mount.yml:21` persist it as a container env literal, and `Makefile.template:114` makes it a make variable. Four carriers persist it and two independent precedence rules consume it, so the ADR sentence describes one carrier out of five.

`VERBOSE` is **argument**, uncontested in the code and absent from every document. Its only sites are `run_tests.sh:19, 209, 280, 292-293, 345` and `tests/test_cli_lib.sh:208-214`. It is evidence that a unified resolution model does not extend to the test harness.

`--provider` is **argument** at start and **state-derived** at resume, and the split has an unstated constraint. `session_inventory.sh:51-52` takes `${agent_img%%-agent-*}`, so a provider name containing `-agent-` is silently mis-recovered. No document states the naming constraint the resume path depends on.

`DELIVERY` and `SANDBOX_TYPE` are **argument and state**, one value under two names across four carriers: the argument `--delivery`, the make variable, the persisted compose env literal, and the container ambient env with a `:-copy` default at `entrypoint.sh:41`. The claim "Delivery is a command input, never an ambient variable" (`execution_model.md:98`) is true of the host readers and false of the system.

`INSTALL_DIR` is **configuration with a broken carrier**. `onboard.sh:253-255` writes it into the sandbox `.env` under the heading "Operator configuration", and `install.sh:124-131` resolves it from the process env, then `$REPO_ROOT/.env`, then `~/.local/bin`. The sandbox `.env` is never read, so the key has a writer and no reader on the path it advertises. This is defect N5. **Resolved 2026-10-16, handover `20261016-11`:** `install.sh` resolves through `env_resolve_one`, takes `--env`, and the repo-root rung is gone. The intermediate read the port introduced for this key, `env_file_value`, is removed with it.

`init_sha` is **state**, and the ADR claim about its resolution is wrong in four of five readers. The shell identifier `INIT_SHA` is a function-local name and never a carrier-supplied input; the persisted key is `init_sha`.

### Claims no document states

| # | Claim | Evidence |
|---|---|---|
| N1 | `AGENT_SANDBOX_REPO` is a fourth `AGENT_SANDBOX_*` key, read from the ambient env with an `$0`-derived fallback, and is not an identity key. 49 of 54 env-idiom occurrences are this key. R4's wording "only `AGENT_SANDBOX_*` keys are the environment level" literally claims it. | `agent-sandbox.sh:46-47`; the 49/54 tally |
| N2 | `start_agent.sh:333-337` derives `SANDBOX_DIR` as `dirname PROJECT_DIR / basename PROJECT_DIR-sandbox` at runtime and passes it as the explicit argument, so it beats `AGENT_SANDBOX_SANDBOX_DIR` and the `.env`. The old entry's E14 rejects exactly this pattern and E12 states its opposite. | `start_agent.sh:333-337, 375`; `env_resolve.sh:92-99`; verified by execution |
| N3 | `env_load` overwrites unconditionally (`env.sh:47`), and `session_env.sh:52` calls it after resolution. Only the identity triple is re-asserted (`session_env.sh:54-58`), so every non-identity `.env` key implements file-beats-ambient-env, the defect E13 records as removed. | `env.sh:47`; `session_env.sh:52, 54-58`; verified by execution: ambient `SERVE_PORT=9999` with `.env` `SERVE_PORT=46553` resolves to `46553` |
| N4 | A `.env` key named `FLATTEN` or `SANDBOX_TYPE` is loaded into the ambient env of the whole run, contaminating keys the code and the ADR call "never an ambient variable". | verified by execution: `.env` `FLATTEN=true` against ambient `FLATTEN=false` resolves to `true` |
| N5 | `INSTALL_DIR` has a writer and no reader on its advertised path. **Resolved 2026-10-16, handover `20261016-11`.** | `onboard.sh:253-255, 375`; `install.sh:21, 124-131`; `Makefile:16, 23-24` |
| N6 | `MAKEFILE_VERSION` is written and refreshed but has no reader anywhere. | grep over `src` and `scripts` returns only `onboard.sh:181, 196, 251` |
| N7 | Five readers of `init_sha` implement four baseline rules, and only one applies the merge-base the documents claim for all. | the table above |
| N8 | `session_state_write` appends without dedup and `session_state_read` returns the first match, so the entrypoint upgrade path permanently shadows its own correction. | `session_state.sh:30-35, 53`; `entrypoint.sh:153-159` |
| N9 | The `--provider` resume recovery parses `<provider>-agent-<project>` and takes the prefix before the first `-agent-`, so a provider name containing `-agent-` is silently mis-recovered. | `session_inventory.sh:46-53` |
| N10 | `agent-sandbox.project-dir` is documented as a container label in the label schema and the stability table, and no compose template emits it. | `sandbox_identity.md:55, 80, 87`; `grep 'project-dir' src/build/` returns no label |
| N11 | The `SESSION_STATE` schema in `sandbox_identity.md` lists 4 keys and omits 4 of the 8 the writers emit: `interface_contract_version`, `changes_dir`, `input_dir`, `output_dir`. | `sandbox_identity.md:103-114` against `session_state.sh:63-69` and `entrypoint.sh:126-128, 161-163` |
| N12 | `sandbox_identity.md:101` says "On resume, `start_agent.sh` reads this file and exports the values". `start_agent.sh` has no resume branch; `resume_agent.sh:200-256` does it. | `sandbox_identity.md:101`; `start_agent.sh:381-384` |
| N13 | `docs/development/context_resolution.md:75-80` documents an `@@AGENT_SANDBOX_REPO@@` build-time macro replaced by `sed` at install. No such string exists in `scripts/` or `src/`; the mechanism is the self-locating symlink dispatcher. | `grep -rn '@@' scripts src` returns nothing; `agent-sandbox.sh:41-47`; `install.sh:139` |
| N14 | `tool_interface.md:233` says provider variables "are appended from `src/reasoning/providers/<n>/.env.example` at onboard time". `onboard` renames `env.stub` to `.env` inside `.$provider/` and never appends to the sandbox `.env`. | `tool_interface.md:233`; `onboard.sh:289-292` |
| N15 | `VERBOSE` is a live configuration key with a flag and an ambient default, and no document mentions it. | `run_tests.sh:19, 292-293` |
| N16 | A fifth persistent record, `.compose/<sid>.log` with `last_started` and `last_stopped`, exists and the session-record claims never name it. | `session_inventory.sh:196-247`; `resume_list.sh:29, 151-152`; `run_agent.sh:319, 430-431` |
| N17 | A sixth carrier, the worktree git config key `agent-sandbox.flatten`, has its own refusal rule and no document names it as a resolution surface. | `start_agent.sh:427, 438-458`; `resume_agent.sh:267-269` |
| N18 | `SANDBOX_TYPE` is carried by four carriers under two names, and the "never an ambient variable" claim holds only of the host path. | the classification above |

### Claims stated in more than one document

The identity four-level precedence: the old `env_resolution.md:22-29` and `sandbox_identity.md:128`. The `.env` location three-level precedence: `env_resolution.md:31-35` and `sandbox_identity.md:128`. The `make -C` contract: `env_resolution.md:39-43` and `Makefile.template:88`. `canon(SANDBOX_DIR)`: `session_identifier.md:13`, `sandbox_identity.md:29`, `common.sh:39-50`. The `SESSION_ID` formula: `session_identifier.md:10`, `sandbox_identity.md:24, 27`, `session_env.sh:124-128`. The Docker label schema: `session_identifier.md:39` and `sandbox_identity.md:51-87`. The `init_sha` baseline merge-base: `sandbox_host_interface.md:80`, `sandbox_lifecycle.md:40`, `execution_model.md:112`. The domain, sub-domain and plane model: `container_execution_model.md:16`, `system_overview.md:26-46`, `terminology.md:103-160`. The correction marker vocabulary: `closed_record_corrections.md:32` and `.agents/skills/task-list/SKILL.md:117-125`.

## Resolution methods

The census's items were split into four lanes.

**Lane 1, the model.** The three carrier classes and the one precedence primitive landed as the `2026-10-16` entry in `docs/adr/resolution_model.md`, with the Requirements table widened by R6. Closed.

**Lane 2, the defects with a decision.** N2, N3 and N5 landed as three rows under M3.4.2 in `devlog/roadmap.md`. Each needs a decision that is not the model's, so each is a row rather than a fix. Closed as census entries, open as work.

**Lane 3, the claims that need a decision.** N1, N4 and N6 through N9, and the contested classifications. Open.

**Lane 4, the document corrections.** N10 through N14 are documents describing a label, a key set, a reader or a mechanism that does not exist. None needs a design decision; each needs a correction. Open.

## Post-review learnings and process adjustments

The proposal the census was asked to judge was wrong in two specific ways, and both corrections are now the model.

**The ADRs are not redundant.** Of the eleven documents named, only the resolution ADR is wholly a resolution document. The proposal to mark the ADRs whose claims it restates as superseded would, applied literally, have superseded `session_identifier.md`, `harness_versioning.md`, `interface_contract_compatibility.md`, `container_execution_model.md` and `coding_agent_project_bindings.md`, none of which is about value resolution. The model now takes the resolution surface and leaves every other subject with its owner.

**The task-list marker does not exist for the record type.** `[SUPERSEDED in MX.X]` is defined at `.agents/skills/task-list/SKILL.md:117` for a roadmap or changelog row. An ADR has its own mechanic: a dated entry inside the file, `**Reason superseded by <date>:**` on the demoted entry, and archive only on full supersession (`adr_policy.md:108-110`). The marker belongs on roadmap rows that claim an ADR is closed, never on the ADR.

## Final output artifacts

| Artifact | Home |
|---|---|
| The three carrier classes and the precedence primitive | `docs/adr/resolution_model.md`, the `2026-10-16` entry |
| R6, the carrier-class requirement | the same file, the Requirements table |
| The three defect rows, N2, N3 and N5 | `devlog/roadmap.md`, M3.4.2 |
| The census matrix and the unstated-claim list | this file |

## Resolution status

Closed: the model, the subsumption verdict, the marker verdict, and the three defects that have a roadmap row.

Open: N1, N4, N6, N7, N8, N9 and N16 through N18, which each need a decision; the contested classifications of `FLATTEN`, `--provider` and `SANDBOX_TYPE`, whose code has not moved; and N10 through N15, the document corrections.

This file is deleted when that open set is empty.

## Records this supersedes

None. This record supersedes no document.
