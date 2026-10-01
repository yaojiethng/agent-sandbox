# pi bump: extension compatibility status

**Status:** draft. Awaiting an operator decision on the four questions below. Nothing here has been applied to the pinned version.

## Context

The `pi-bump` skill's verification step checked the version pin, the settings record, and the changelog note. It did not look at the two extensions this repository ships under `src/reasoning/providers/pi/config/agent/extensions/`. A bump that removes a name they import does not fail anything in this repository. It fails at container start, inside an extension, with a stack trace pointing at the extension rather than at the bump.

The operator asked for four questions: is a bump seamless, what is the blast radius, can the agent update the self-written extensions, and if so what is the implementation plan. This document answers all four from measurement. The measurement was taken by installing the candidate into a temporary prefix and probing it, not by reading a changelog.

The installed version is 0.87.1. The candidate is 0.99.2, which is what `https://pi.dev/api/latest-version` reports. The gap is twelve patch numbers across one minor line.

## Is a bump seamless?

On the extension import surface, yes, and this was measured rather than inferred.

`scripts/lint/pi-extension-compat.mjs` reads the named imports out of both extension sources and probes a pi install for each. Against the installed 0.87.1 it reports clean over six names. Against 0.99.2 it also reports clean over the same six. A deliberate break, an import of a name pi does not export, turns it red; the file was restored and compared byte-identical afterwards.

The full runtime export surface was compared directly. Between 0.87.1 and 0.99.2 pi removed nothing. It added four exports: `VIRTUAL_MODEL_STATE_ENTRY`, `createCodemodeExtension`, `createMcpExtension`, and `createToolSearchExtension`. A pure addition is the best case a bump can have.

`RefreshModelsContext`, the one external interface `model-refresh` reads, is identical in shape across the two versions. Its `allowNetwork`, `stored`, and `signal` fields, the three the extension uses, are present in both.

Seamless is too strong a word for the whole bump, and the reason is in the next section.

## What is the blast radius?

Three surfaces, in descending order of how much they would hurt.

**The import surface is clean.** Measured above. Nothing to do.

**The extension assumption table has already moved.** `model-refresh/README.md` carries fourteen rows, each naming the code that would falsify it. One is already false: A12 recorded that `mergeModels` is unreachable from an extension on 0.87.1, and noted that 0.99.1 exports it from its module while the package entry still does not re-export it. A3 was retired during this work for a different reason. So two of fourteen rows are known to have drifted, and a bump must walk the remaining twelve by hand. The checker cannot do this: it proves a name is exported, never that the behaviour behind it held.

**The model-refresh extension's own regression is fixed upstream, which removes its reason to exist as written.** The extension exists because pi shipped a frozen 29-id catalog for `opencode-go` against a 43-model endpoint, and because a legacy `ProviderConfig` registration replaces the provider's whole catalog rather than extending it. Both are pi defects, reported upstream in [`20260930-report-draft-opencode_go_provider_bug_report.md`](20260930-report-draft-opencode_go_provider_bug_report.md). A bump that fixes either one changes what the extension does, and an extension whose reason has been fixed upstream is a new failure mode rather than a solved problem. Which of the two defects 0.99.2 fixes was not measured here, and it should be before a bump, because the answer decides whether the extension is deleted, narrowed, or kept.

**The harness layers below pi are not in the blast radius and should not be assumed to be.** Nothing in `src/libs/`, `src/capability/`, or the compose files references a pi version, so the bump is contained to the reasoning layer and the image rebuild.

## Can the agent update the self-written extensions?

Yes, for the classes of change that actually occur, and no for one class that has already occurred.

**Yes, mechanically.** A name removed from pi has one correct repair: find its replacement in the candidate's declarations and change the import. The checker names the missing name; the candidate's `.d.ts` names the replacement. That is a mechanical edit an agent makes reliably, and the checker then proves it.

**Yes, for a moved type member.** A field removed from `RefreshModelsContext` or `ExtensionContext` is a type-level break, caught by the checker's member test, and the repair is to read the replacement field. The upgrade note in the release is the evidence.

**No, for a semantic change that keeps the same name.** This is the class that has already bitten. `mergeModels` did not disappear between 0.87.1 and 0.99.1; it became reachable, which changed what an extension could do without changing a single import. A checker over names cannot see that. It is found by reading the extension's assumption table against the candidate, which is a judgement task, and judgement is exactly what the operator is being asked to approve here.

## Implementation plan

**Done in this iteration, and it is the whole of the mechanical part.**

`scripts/lint/pi-extension-compat.mjs` derives the required surface from the extension sources, so an extension that starts importing a new name is covered without editing the checker. It resolves the installed pi, or installs a candidate into a temporary prefix, and reports every absent name. It distinguishes a value import from a type-only specifier, because `type` binds per specifier rather than to the statement, and a value that vanishes is a load-time break while a type that moves is a compile-time one.

The `pi-bump` skill's verification step now runs it, first in the list, and says why it is not optional. The same step now also requires walking the assumption table, with the reason that a clean checker run is necessary and not sufficient.

**Not done, and each needs a decision.**

Walking the twelve remaining assumption rows against 0.99.2 is a unit of work, not a step in this one. It produces an updated table, and a table with a row per falsified assumption is what tells a later bump whether the extension is still load-bearing.

Deciding what happens to `model-refresh` if upstream fixed the catalog defect is a design question with two honest answers. Delete the extension and take the upstream fix, which loses the union guarantee the extension was written to provide. Or keep it and accept that it now guards a defect that is gone, which is code maintained for a condition that no longer reproduces.

Deciding whether the checker belongs in `make lint` is separate from whether it belongs in the skill. In `make lint` it would run on every change and need network, which the other four gates do not. In the skill it runs once per bump, where the network is already required by the version API call. The current answer is the skill, and the cost of that answer is that a breaking import lands in `main` without a gate until the next bump notices.

## Recommendation

Bump to 0.99.2, and do it in three units rather than one. The recommendation is not the interesting part; the ordering is.

The import surface is clean and measured, so no unit exists to unblock the bump on that account. What blocks it is the two unknown semantic questions, and both are answerable by reading rather than by guessing, which is why they are units and not steps.

Unit one walks the twelve unverified assumption rows in `model-refresh/README.md` against 0.99.2 and updates the table. It produces no code. Until it runs, nobody can say whether the extension is still load-bearing, and that answer decides unit three.

Unit two is the bump itself: the pin, the settings record, the roadmap note, and the checker's clean run. It is small, and it is deliberately placed after unit one so the pin is not moved before the assumptions behind it have been read.

Unit three decides what happens to `model-refresh` if upstream fixed the catalog defect, and deletes or narrows it accordingly. It is last because it is a design call the operator owns, and it is better argued with the assumption table updated than with it stale.

The checker does not go into `make lint` in this cycle. The reasoning is in the implementation plan and it does not change with the answer to the four questions.

## Records this supersedes

None. This study is new, and the `pi-bump` skill is amended rather than replaced.
