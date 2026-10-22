# Seeded corpus and shipped surfaces: which layer names which path

**Status:** settled

## Context

`initialize` ships a default convention-skill corpus in `workflow/coding-agent/skills/initialize/assets/conventions/`, and its Procedure step 1 calls that list "the workflow's declaration of the conventions it expects". The corpus holds seven conventions. This repository states nine, adding `numbering` and `linking`, so the roadmap row **The seeded convention corpus is short of the project's own** read the gap as a missing seeding step.

The pointers say otherwise. Six pointers in five shipped files name the two project-scoped paths, and the project-scoped carriers of the same paths are five files of this repository: the shipped carriers outnumber the local ones. Nothing is missing a link; a shipped document names a path a receiving project may not have.

A census over the shipped roots widens the class. Twenty-five mentions of a concrete `.agents/` path sit across thirteen shipped files, and they split four ways. The paths a shipped mechanism guarantees are sound: `work-log` and `task-list` come from the corpus `initialize` seeds, and `.agents/model-recommendations.md` is written by the shipped skill that names it. The paths nothing guarantees are the defect: `numbering` and `linking`, which no seeded convention covers; `.agents/drafts/sequential-work.md`, which `iteration_policy.md` names as the home of the work-unit table's definition; and `.agents/drafts/history-cleanup/inversions.mjs`, named by a shipped prompt. Two merge-provenance comments name removed audit files, which reads as history rather than a live pointer.

The operator then ruled the intention that decides the question: `.agents/` is the directory for project-scoped content, read only by developers of this project. `.agents/prompts/` is consistent with that intention, because its cell's runtime path is `/home/agentuser/sandbox/.agents/prompts/` - inside this project's tree, carried by the launch command for this project's sessions, and absent from every other project's image. So the intention contradicts no resident of `.agents/`, and it makes the rule decidable: a shipped document may name a `.agents/` path only where a shipped mechanism guarantees the path exists.

## Options Considered

**A. Seed the two stubs and leave the pointers.** The corpus grows to nine and every shipped pointer resolves. The cost is that every project states a numbering convention and a reference convention it did not choose, which is the opposite of `initialize`'s stated boundary that the stubs are failure directions and not defaults. It also leaves the draft citations, so the rule the operator stated stays false.

**B. Remove the six pointers, ship the judgement, and give the taxonomy a scope axis in the same iteration.** The axis means a scope value per document class, the `AGENTS.md` row split into its two layers, the `.agents/prompts/` against `.agents/skills/` reach pair, and the `docs/development/` reach. It writes a value for `docs/policies/` and `docs/reference/` while the open row **Drop the policy bundle** disputes whether those bundles ship at all, so it states a fact an open row may falsify. It also delivers two outcomes, which is the policy's definition of a split.

**C. Remove the six pointers, ship the judgement, and file the axis.** One outcome: no shipped pointer names a path the receiving project may not have. The axis becomes its own row, and its design question is open - a hand-written scope column in the taxonomy, or a view derived from the interface manifest and held to it by a gate.

**D. Name `.agents/` generically in the shipped text.** Not an alternative to C but its wording. Once `.agents/` is the project's own surface by intention, a shipped document can say "the project's convention under `.agents/skills/`, where the project states one" - true for every project, and stable. Under A the same sentence would be false wherever the corpus seeded a stub.

## Decision

C, with the wording of D. The six pointers lose their concrete project paths: the judgement goes to a shipped principle, `communication-principle-link-what-the-reader-can-open`, and the structure stays in the project's `linking` convention. `numbering` and `linking` stay project-scoped, and the corpus stays at seven.

One sentence ships to make the intention available to a receiving project, in `docs/reference/documentation_taxonomy.md` `## Boundary`: everything under a project's `.agents/` is read by that project's sessions only, and a document whose reach is wider names a path there only where a mechanism that ships guarantees it. This is not the scope axis - it states one directory's reach, and the axis stays the filed row's subject.

Reach is named by the declaring unit rather than by shipping, because a module is a declared unit and not a future one: `workflow/<module>/{prompts,skills}/` lands on `/opt/workflow/agent/modules/<module>/`, the shipped settings enable it by naming the module directory beside the harness root `/opt/workflow/agent`, and `scripts/check_container_layout.sh` already refuses a module root no settings entry enables. So `module-scoped` names a gated class with one instance, and the same value covers the harness payload root because one `packages` key enables both. `ships` stays a verb, and three values carry the axis: `module-scoped`, `provider-scoped` for the config home under `$AGENT_HOME/`, and `project-scoped` for this project's own tree.

Two reaches the axis cannot cover yet, and neither becomes a value. `docs/reference/` and `docs/policies/` land in every image by a dockerfile `COPY`, wider than any module and gated by none, while the open row **Drop the policy bundle** disputes whether they should ship at all; the axis states them as an exception until that row settles. And `module` itself carries two senses in the tree - the payload toggle unit, and any directory under `workflow/`, where `knowledge-vault/` holds scripts and a changelog and `vscode/` holds one image config file - so the axis's definition must name the payload unit and say which directories are not of that kind.

The gate derives its subject set from the seeded corpus rather than listing it: `scripts/lint/linking.mjs` fails when a shipped document names `.agents/skills/<name>/SKILL.md` for a name the corpus does not seed. A name the corpus seeds passes, because `initialize` guarantees it, and the generic `<name>` form passes, because it claims no specific convention.

## Consequences

The corpus row closes on its second ending - the difference is stated where `initialize` is read - without adding a stub, so no project inherits a convention it did not choose. The two conventions stay this project's own, and their paths appear only in this repository's tree and in the wider-reach text's generic form.

The census's other classes are filed, not fixed here: the two draft citations are the same defect the gate does not reach, because the guarantee behind a draft is a task, not a mechanism, and the provenance comments are history. Each needs a row with its reason.

The axis row inherits the design question this decision deliberately left open. Recording reach twice is what produced four disagreeing vocabularies, so the row's first option is a committed view rendered from `src/build/container-interface.json` and checked by the lint umbrella, as `scripts/check_norm_ownership.sh` renders `norm-ownership.tsv`; its second is a hand-written column. `communication-principle-only-derive-what-you-own` argues for the first, and the row decides it.
