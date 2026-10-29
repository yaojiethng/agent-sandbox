# Sources

The paths below name files inside `payload.tar.gz`, not files beside it. The archive is the frozen unit and its pin is `SHA256SUMS`; the table is provenance for a reader, so it survives the seal.

Every file under `room/` and `briefs/` is a byte-identical copy of one source file, taken from commit `ba7d0f922b56` on 2026-10-26. `tools/` holds the two generators that composed the briefs, copied from the session scratch, which is gitignored and does not survive the session: this copy is their only tracked form.

A copy is inert by design. Each carries an `.orig` suffix so that the documentation and linking gates read nothing here: a verbatim copy of a document with relative links cannot resolve them from a new location, and a snapshot must not be edited to satisfy a lint rule. Verify integrity rather than content with `sha256sum -c SHA256SUMS`.

| Fixture file | Source path | Source blob | Bytes |
|---|---|---|---|
| `room/kelsey-code-reviewer.skill.md.orig` | `.agents/audits/kelsey-code-reviewer.skill.md` | `3a31db635da5` | 10959 |
| `room/architecture-doc-reviewer.skill.md.orig` | `.agents/audits/architecture-doc-reviewer.skill.md` | `ee73e7f5a6a4` | 14041 |
| `room/dhh-code-audit.skill.md.orig` | `.agents/audits/dhh-code-audit.skill.md` | `6733ceedc1e0` | 5714 |
| `room/bash-audit.skill.md.orig` | `.agents/audits/bash-audit.skill.md` | `1c6efda94e44` | 1462 |
| `room/test-quality-campaign.md.orig` | `.agents/audits/test-quality-campaign.md` | `6e0668865989` | 7417 |
| `room/test-assertion-sweep-brief.md.orig` | `.agents/audits/test-assertion-sweep-brief.md` | `c532f35fa190` | 6098 |
| `room/instruction-cleanup-a.md.orig` | `workflow/coding-agent/prompts/instruction-cleanup.md` | `02c95699468c` | 15558 |
| `room/instruction-cleanup-b.md.orig` | `.agents/drafts/instruction-cleanup-goal-only.md` | `cb2359465d85` | 2281 |
| `room/bash-coding-conventions.md.orig` | `docs/development/bash-coding-conventions.md` | `29919f3d3647` | 22798 |
| `room/test_harness_mechanism.md.orig` | `docs/development/test_harness_mechanism.md` | `4dcb4a372326` | 11764 |
| `room/conventions.md.orig` | `docs/development/conventions.md` | `2a543df93496` | 1576 |
| `room/skills/testing-SKILL.md.orig` | `.agents/skills/testing/SKILL.md` | `035ab3ee98ab` | 5786 |
| `room/skills/docs-SKILL.md.orig` | `.agents/skills/project-documentation/SKILL.md` | `f37bebe3e9a7` | 6905 |
| `room/skills/linking-SKILL.md.orig` | `.agents/skills/linking/SKILL.md` | `f2d1bb4101c0` | 3771 |
| `briefs/brief-a.md.orig` | `.scratchpad/cmp/brief-a.md` | `- (never tracked)` | 16989 |
| `briefs/brief-b.md.orig` | `.scratchpad/cmp/brief-b.md` | `- (never tracked)` | 3716 |
| `tools/census-gen.mjs.orig` | `.scratchpad/census/gen.mjs` | `- (never tracked)` | 1564 |
| `tools/ablation-gen.mjs.orig` | `.scratchpad/ablation/gen.mjs` | `- (never tracked)` | 3277 |
| `tools/census-gen.mjs` | `.scratchpad/census/gen.mjs` | `- (never tracked)` | 1564 |
| `tools/ablation-gen.mjs` | `.scratchpad/ablation/gen.mjs` | `- (never tracked)` | 3277 |

## `reports/` - the answer key, never handed to a run

These carry the case's ground truth and its account. They were copied here and deleted from `devlog/discussions/` on operator direction 2026-10-28, so the archive now holds their only form: the drift this table once guarded against cannot happen, because no record is left to drift from.

| Fixture file | Source path | Source blob | Bytes |
|---|---|---|---|
| `reports/20261026-report-settled-census_six_carriers.md` | `devlog/discussions/20261026-report-settled-census_six_carriers.md` | `394029689138` | 135625 |
| `reports/20261026-report-settled-instruction_cleanup_comparison.md` | `devlog/discussions/20261026-report-settled-instruction_cleanup_comparison.md` | `19c8e5b1edc1` | 16873 |
| `reports/20261026-report-settled-carrier_fates.md` | `devlog/discussions/20261026-report-settled-carrier_fates.md` | `353e0368006b` | 10216 |
| `reports/20261026-report-draft-ablation_problems_found.md` | `devlog/discussions/20261026-report-draft-ablation_problems_found.md` | `dda0a3b6b038` | 5976 |

They sit outside `room/` for the reason the run depends on: the census names every fault site, so a run that could read it would read the answer key. The extraction that seeds a run hands over `room/` and nothing else.
