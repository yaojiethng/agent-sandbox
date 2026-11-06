---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Implementation
status: Closed
---

# Handover - the norm census gains a home column and resolves its observers

## Objective

Make the norm census fit to measure the principles refactor: it derives each line's skill home instead of counting a citation as an observer, resolves an observer through the declared instruction roots, and reports the lines a refactor still has to convert.

## Scope

The three open census rows of M3.3.4: **The norm ledger names a principle skill as an observer**, **Twelve ledger rows name an observer they do not have**, and **The ledger cannot see a judgement stated in a convention skill**. The gate, its two data files and its test are the whole of the change; no source document's judgement was repointed.

Out of scope: the communication-surface filing and the plain-wording standard, which decide which document owns a rule, and covering the convention skills as census sources, which the third row's second ending settles as a stated limit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A judgement that cites a skill records that skill as its home, and a hand edit fails | `tests/test_norm_ownership.sh` cases `test_generate_derives_the_home`, `test_hand_edited_home_is_rejected` | Agent [x] |
| A judgement citing a skill no declared root holds fails, and two cited skills fail as ambiguous | cases `test_cited_skill_must_exist`, `test_two_cited_skills_are_ambiguous` | Agent [x] |
| The ledger holds each row to its own source document | case `test_row_source_is_checked` | Agent [x] |
| A `review:` observer must be a skill a prompt names as a whole name | cases `test_review_observer_must_be_dispatched`, `test_review_observer_dispatched_passes`, `test_observer_name_matches_whole` | Agent [x] |
| A group whose note names no skill fails, and a group two documents state needs a home | cases `test_group_note_must_resolve`, `test_class_one_group_needs_a_home` | Agent [x] |
| A map row that disagrees with a homed line fails | case `test_stale_map_row_for_a_homed_line` | Agent [x] |
| `--regroup` derives a homed line's group, keeps a hand group for the rest, and drops a row whose line is gone | cases `test_regroup_groups_a_homed_line`, `test_regroup_drops_a_gone_row` | Agent [x] |
| The census and the map are clean, and the summary reports the home count | `bash scripts/check_norm_ownership.sh --check` prints `clean across 150 row(s) ... 13 homed` | Agent [x] |
| The scan-set limit is stated where a reader reads the class | read the script header and the map preamble | Agent [x] |
| The gates and the suite are green | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` | Agent [x] |
| Every decision this iteration records is realized in the files | read `## Decisions` against the tree | Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A home is derived from the skill path a judgement cites, never typed | the ledger read a cited home as an observer, which is why 14 lines were called misclassified; the citation is in the text, so the column can be recomputed and a hand edit caught. A description and a rule carry no home, so a citation in one of them records no ownership | `scripts/check_norm_ownership.sh` `derive_home`, the ledger's `home` column |
| A cited skill is a home, not an observer | an observer is an artifact that fails on a breach and a home is not; the pointer row was a home all along, which is why the row asked for the wrong fix | this record, and the closed roadmap rows |
| A `review:` observer must be a skill a prompt names as a whole name | the reference admits a skill only as one a prompt dispatches; a whole-name test keeps `docs` in `docs/policies/` and `doc` in `doc-maintenance` from reading as dispatches. Prose that mentions a skill without dispatching it is indistinguishable, and the header states that limit | `named_in`, `observer_resolves` |
| Observer and home roots are read from the manifest, plus `.agents/skills` | a gate that hand-lists its subject set misses a live root, and the manifest already declares all three shipped skill roots and four prompt roots. The project convention corpus is read from the repository, so the header names it as an addition rather than pretending the manifest carries it | `src/build/container-interface.mjs` `source_roots`, `roots --kind` |
| A homed line needs no hand grouping, and `--regroup` writes its row | the group is derivable from the home, so a stale hand row can only disagree; deriving it removes the drift on 13 of 68 judgement lines | `--regroup`, the map preamble |
| The scan set stays the two source documents, with the limit stated | covering the convention skills would classify several hundred lines for no decision the filing makes | script header, map preamble |
| Two descriptions that instructed were reclassified, not left as descriptions | a rule marked description reports as unobserved, which understates the gate's coverage; the markdown gate does fail on a registered rule that runs nowhere | the two rows in `scripts/lint/norm-ownership.tsv` |
| The upstream skill path is cited as a URL | an external project's `skills/` folder looked like a local home, so the citation is one URL that the derivation strips | `docs/development/prompt-authoring-conventions.md:11` |
| The root reads and the observer verdicts are cached | the uncached gate cost 2.9s per run, which pushed `test_lint_umbrella.sh` past its 20s deadline; it now costs 0.6s | `scripts/check_norm_ownership.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first form of the gate cost 2.9s per run, and `test_lint_umbrella.sh` timed out at 20s under the suite | regression, caught by the suite | a red suite blocks every commit | fixed in place: cached roots and observers, 0.6s |
| `grep -q` on a pipeline under `pipefail` reported the writer's SIGPIPE as a non-match, so every observer read as unresolvable | language trap, hit twice while building the gate | the gate failed closed on a correct tree | `devlog/AGENT_FEEDBACK.md` entry of 2026-10-20, and `bash-coding-conventions.md` 1.20 |
| An independent review found the rewrite had dropped the per-source check: `present` was keyed by text alone, so a row's `source` column went unverified and the same line in both documents counted once | defect, found by review | a wrong source passed silently, and the class count followed it | fixed in place: the keys carry the source, and `test_row_source_is_checked` holds it |
| The rewrite also dropped the class-1 home failure, and `review:` admitted a skill on a substring match | regression, found by review | a duplicate group and an undispatched observer both passed | fixed in place: the class-1 home check is restored and observer names match whole |

## Completed

| Artifact | Change |
|---|---|
| `scripts/check_norm_ownership.sh` | `derive_home` for a judgement, the per-source and home checks, whole-name observer resolution through the manifest, derived grouping for homed lines, the class-1 home failure, and cached roots |
| `src/build/container-interface.mjs` | `source_roots`, and a `roots --kind skills\|prompts` subcommand |
| `scripts/lint/norm-ownership.tsv` | regenerated with the `home` column; two descriptions reclassified |
| `scripts/lint/norm-judgements.tsv` | regrouped: 14 homed rows derived, the pointer group gone, and the scan-set limit stated |
| `tests/test_norm_ownership.sh` | new: 16 behavioural cases over a fixture tree |
| `docs/policies/documentation_policy.md` | the ledger paragraph names the home and the derived-column rule |
| `docs/development/instruction-surface-conventions.md` | the gate list names the census and its manifest read |
| `docs/development/prompt-authoring-conventions.md` | the upstream skill reference is one URL |
| `docs/development/bash-coding-conventions.md` | 1.20, the early-exit reader under `pipefail` |
| `devlog/AGENT_FEEDBACK.md` | one entry for the pipefail trap |
| `devlog/roadmap.md` | the three census rows closed with their landing notes |
