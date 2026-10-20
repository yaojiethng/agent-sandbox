# The plain-wording draft

**Status:** draft

This directory holds a draft. No dispatch path reaches it: `.agents/drafts/` is a root the frontmatter gate does not scan and live dispatch does not reference. `SKILL.md` is a bridge, not an authority; `documentation_policy.md` `## Communication Standards` holds these rules today.

## Why it is not filed yet

The duplication map measured the judgement it would own at five sites in one document, three of which a gate already holds: `doc-ascii` catches the punctuation and the numbering gate catches the numbered units, so a skill adds nothing there. The rest is ASD-STE100 conformance, which the policy states as a standard a writer meets rather than as a drafting decision. The filing's test is a judgement two documents state, and this judgement is stated by one.

## What it becomes

One home for the plain-wording rules, with every other carrier pointing at it:

- `documentation_policy.md` `## Communication Standards` keeps the rules a checker holds and points here for the rest.
- The provider-layer `AGENTS.md` restates the same standard today, so it becomes the same pointer, edited in the repository source and the installed copy together. That restatement is the duplication class this draft exists to end, and it is the same one the scaffolder's template presented.
- `/technical-writing` is subsumed for documentation prose. It is operator-invoked and installed at `$AGENT_HOME/agent/skills/technical-writing/SKILL.md`, outside this repository, which is the state `skill-scaffolder` was in before the map iteration. Its provenance is a fork from the `pont`/`pstack` skill set that the `poteto` skills come from, recorded without a revision, in the shape `principle-guard-the-context-window/MAINTENANCE.md` uses. Its scope is wider than this repository's documents: READMEs, RFCs, pull request bodies and commit messages, with slop detection delegated to `unslop`. Subsuming it means this standard becomes the home of the findings that made those rules necessary, and `/technical-writing` either points here for documentation prose or retires.
- The ledger rows for the pointer sentences take a kind decided with the filing, not here.

## What blocks promotion

1. The kind the pointer sentences take in `norm-ownership.tsv`, decided by the filing.
2. A repository home for the subsumed skill, so the standard ships instead of living in one container.
3. The `AGENTS.md` restatement moving in both trees in one commit, so the running context and the shipped config never disagree.
4. Each borrowed standard carrying a fetch date, so a reader can tell whether the spec has moved.

## How it is promoted

By operator direction, as one commit that moves this directory into a live root and runs a documentation pass over it at the same time. The move is the promotion; there is no separate step to forget.
