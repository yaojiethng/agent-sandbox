# The cross-document duplication map

**Status:** settled

## What the map is

Two files. `scripts/lint/norm-ownership.tsv` is generated: one row per prose line of `documentation_policy.md` and `prompt-authoring-conventions.md`, keyed by a hash of the text, carrying each row's kind and observer. `scripts/lint/norm-judgements.tsv` is hand-maintained: hash, group, note. The grouping is the only hand data, because which judgement a sentence states is a reading; the class, the site count and the document count are derived by `scripts/check_norm_ownership.sh --groups`, which also fails when a judgement line is ungrouped, when a grouping row outlives its line, or when a group's note disagrees with the number of documents stating it.

The map covers judgements and nothing else. The 21 gated and 17 reviewed rows already name the artifact that catches their breach, so the home rule leaves no question about them, and the 49 descriptions ask nothing of the reader.

## The result

Run `scripts/check_norm_ownership.sh --groups` for the table; it is derived, and a count written here would go stale the next time a sentence moves. What the table states, over the 75 judgement lines:

- **One class-1 group.** `j-copy-points-to-its-source`, seven sites across both documents: the durable-target rule in `documentation_policy.md`, and the fast-path rules in `prompt-authoring-conventions.md` that label an inline copy and point it at the policy it copies. Its home already exists, so this group files no new skill: the filing repoints the six convention sites at `principle-one-home-per-rule`.
- **Eleven class-2 groups**, each stated by one document, each flagged as a candidate and none landed. They are `j-write-plainly` (five sites), `j-handoff-by-naming-the-boundary` (six), `j-own-the-step-you-write` (five), `j-describe-only-what-is-true` (two), `j-end-a-step-on-a-check` (two), and one site each for `j-one-term-one-meaning`, `j-define-before-you-use`, `j-co-location`, `j-match-guidance-to-fragility`, `j-one-subject-per-prompt`, `j-pointer-wording`.
- **Thirty-eight local groups**, which stay in the document that states them.

## What this changes

The filing was scoped on the claim, recorded by `20261019-06`, that three surfaces declare the same rules. At the judgement level that claim is largely unsupported: the two documents state one judgement in common, and `prompt-authoring-conventions.md` delegates prose style to `documentation_policy.md` in terms rather than restating it. What duplicates is inside each document, and in the scaffolder's template.

So the filing keeps its reason and loses most of its size. It files no new skill; it repoints six sites at a skill that already exists; it aligns the scaffolder. The twelve-group tranche is not what the map found, and the re-plan page's refusal to forecast the tranche is vindicated by the count.

## The twelve proposed names, and what became of them

The spec census proposed twelve principle skills. Six were already filed before this iteration: `attach-as-you-read`, `cut-what-carries-nothing`, `name-the-value-not-a-literal`, `only-derive-what-you-own`, `show-dont-describe`, `write-for-the-reader`. Of the other six, the map's class-2 notes carry the names that survived reading, and two do not survive:

- **`one-term-one-meaning` stays a candidate, recommended for rejection** on the evidence the sentence-structure study recorded: its stated test bans a rotating synonym, while the failures behind it were one word carrying two meanings, which is a different judgement. Filing it would name a rule the events do not support.
- **`write-plainly`** absorbs five sites, three of which are already gated by `doc-ascii` and the numbering gate. Its remaining content is ASD-STE100 conformance, which the policy states as a standard rather than as a drafting decision, so a reviewer should ask whether a skill adds anything to the pointer.

A class-2 candidate lands only when someone reads its sites and says the judgement is general. Until then the note is the whole record, and `check_norm_ownership.sh --groups` will not let it drift into `skill:` without a second document to justify it.

## The scaffolder

`skill-scaffolder` existed only in the agent config home, in neither repository skill root, which is why its template survived two days of cleanup. Its body template and its `paths:` frontmatter restated a skill's section shape. It now carries a frontmatter skeleton as a labelled convenience copy and defers the body's section shape to `prompt-authoring-conventions.md`, and it has a repository copy at `src/reasoning/providers/pi/config/agent/skills/skill-scaffolder/SKILL.md`, so the alignment ships instead of living in one container. The installed copy is byte-identical to the repository copy. That the pi-config tree is the seed for `$AGENT_HOME/agent/` is an inference from where the other skills sit, not a step in a script this repository holds; the filing confirms it against the image build.

## Consequences

- The filing's work list is the class-1 group plus the scaffolder, not a tranche of skills.
- `20261019-design-draft-prose_standards_specs.md` is `rejected`; its grouping and its names now live in `norm-judgements.tsv`. Its archive move waits while the W2 run brief names it.
- Any future prose line the ledger classes as a judgement fails the gate until it is grouped, so the map cannot rot silently.
