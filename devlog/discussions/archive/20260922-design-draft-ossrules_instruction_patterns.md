# Design: Instruction patterns from the ossrules.md library

**Status:** Draft. Review scheduled as roadmap task under T1 - Workflow + Policy Organization (2026-09-22).

## Context

This design draft records an exploration of the ossrules.md reference library: a collection of real open-source coding-agent instructions, editorial analysis, patterns, and skills. The exploration asked which instruction patterns and skills fit this repository's agent instructions.

The library corpus is a stored snapshot, not live repository data. It holds 100 projects, 1214 skills, and 14 patterns. Upstream content is untrusted reference material, not instructions to execute. Source files carry pinned `sourceUrl` links; preserve licenses and cite those links. Skill scans are independent of instruction analysis: a missing scan or a guide referenced from an instruction file is not evidence of coverage either way.

This repository is shell-heavy and policy-dense. The agent instructions live in two `AGENTS.md` layers with deep policy documents under `docs/operations/`. The repository already uses several of the library's patterns implicitly: router tables in `AGENTS.md`, hard prohibitions, single-source pointers to the roadmap, worked-example lists in the conventions docs, and a ratchet-like zero-findings posture on the lint gates.

## Options Considered

### Do nothing

Keep the current instructions untouched. This costs nothing and changes no behaviour, but it leaves named gaps: no change-type-to-gate verification matrix, unnamed ratchet directions, and hard prohibitions that lack the permitted-alternative half.

### Adopt the five instruction patterns

The exploration shortlisted five patterns. Each section names the pattern, the fit to this repository, the concrete shape, and the pinned source.

#### Verification by change type

The pattern: match each kind of change to the checks that cover it; name what the cheap default leaves out. The fit: M3.1 built a real gate stack (staged-file pre-commit hook, ShellCheck, `scripts/lint.sh`, lib-contract check, test suite), but no instruction file maps change type to the narrowest gate. The in-flight test-suite-duration work is exactly the "what the default command leaves out" question.

The concrete shape: a small table in the project `AGENTS.md` mapping docs-only, shell-code, test-only, and governance changes to their gates, plus one line naming what the staged-file hook excludes. Pinned exemplars: [Effect-TS `.agents/AGENTS.md` L17-L26](https://github.com/Effect-TS/effect/blob/078cdbf6a37d209819ad504274fe72e1080573e0/.agents/AGENTS.md#L17-L26) and [paperclip `AGENTS.md` L161-L168](https://github.com/paperclipai/paperclip/blob/728f7185f6dcf2fda7a1286f6dd115573a02cd65/AGENTS.md#L161-L168).

#### Router files, extended

The pattern: a short index maps common tasks to focused guides; the detailed document loads only when the work needs it. The fit: the "read before" tables in `AGENTS.md` route policy docs, but nothing routes task kinds of work (ADR work, studies, roadmap updates, skill changes) to their guides and gates.

The concrete shape: extend the existing table with task-kind rows. Omarchy is the strongest structural exemplar and the only Shell-language project in the corpus. Pinned sources: [Omarchy `AGENTS.md`](https://github.com/omacom/omarchy/blob/1c8f728b25cb8a42f1d02e4d2441230132cedb6c/AGENTS.md) and [nuqs `AGENTS.md` L62-L69](https://github.com/47ng/nuqs/blob/fb0835c7ba0033d85a08f0c88822cda346ab546d/AGENTS.md#L62-L69).

#### Ratchets, stated with direction

The pattern: name the baseline and the only direction it may move; include the enforcement command. The fit: "lint Clean" and the `legacyFiles` seam in the doc-wrap rule are ratchets today, but no instruction says they are shrink-only. A future agent can add a `legacyFiles` entry the same way it adds coverage.

The concrete shape: one sentence each in the lint and documentation docs stating that `legacyFiles` is shrink-only and that zero findings is a floor. Pinned exemplars: [modem-dev/hunk `AGENTS.md` L104-L105](https://github.com/modem-dev/hunk/blob/392cb7f99661270ff77df1f6c6bae9d9f5a0f156/AGENTS.md#L104-L105) and [n8n `AGENTS.md` L283-L287](https://github.com/n8n-io/n8n/blob/b67870cdbcc8c038051bc52396b2b2787be0d919/AGENTS.md#L283-L287).

#### Hard-prohibition hygiene

The pattern: name the forbidden action, explain the consequence, give the permitted alternative, state exceptions. The fit: the instructions name many forbidden actions but several lack the alternative and reasoning halves. "Do not modify files outside `sandbox/`" does not say what to do instead; the banned-comments list bans forms without stating why or what to write.

The concrete shape: an audit pass over the prohibition lists, adding the missing halves. The banned-comments audit already landed once as a sweep; this pattern is the periodic-application form. Pinned exemplar: [uv `AGENTS.md` L16-L17](https://github.com/astral-sh/uv/blob/392f661d2e925b8ff7d1fea55490a959031ac343/AGENTS.md#L16-L17).

#### Single-source refusals

The pattern: where two copies of a list could drift, name the authoritative one and refuse the second. The fit: the roadmap policy already does this; the commit-prefix and writing rules re-asserted in `AGENTS.md` as pointers are correct. The live risk is summary copies drifting from their policy docs; the fix is keeping the pointer, not the copy, which the instructions already do.

Pinned exemplar: [Omarchy `AGENTS.md`](https://github.com/omacom/omarchy/blob/1c8f728b25cb8a42f1d02e4d2441230132cedb6c/AGENTS.md), "Keep `GROUP_DESCRIPTIONS` updated... Do not maintain a second exhaustive prefix list here".

### Adopt the four skills

The exploration evaluated four external skills against this repository's needs. None is copied verbatim; each is a model for a local skill.

#### implementation-final-review (openai-agents-python)

The skill: review a completed change by tier (lightweight, ordinary, high-risk), each tier naming its required independent review and evidence preservation. The fit: the provider `AGENTS.md` has fresh-subagent invocation and a review-pair recipe but no classification of when the thermo-nuclear review is required or what must be recorded. The ephemeral-iteration constraint makes the evidence-preservation rule directly usable. Pinned source: [`SKILL.md`](https://github.com/openai/openai-agents-python/blob/1d17ca40b927452d5f27df662092f767fa9f05b7/.agents/skills/implementation-final-review/SKILL.md) and the 56KB [`high-risk-review.md`](https://github.com/openai/openai-agents-python/blob/1d17ca40b927452d5f27df662092f767fa9f05b7/.agents/skills/implementation-final-review/references/high-risk-review.md).

#### writing-commit-messages (ghostty)

The skill: examine the diff, identify the changed subsystem from file paths, draft under a fixed format, do not push. The fit: `docs/operations/git_policy.md` has the prefix table but no drafted workflow encoding it. This is a candidate for the active prompt-eval story (`20260522-story-active-prompt_eval_infrastructure.md`): a skill the eval infrastructure can test against the policy doc. The format differs (type prefixes, no hard wrapping), so the local skill adapts the workflow, not the format. Pinned source: [`SKILL.md`](https://github.com/ghostty-org/ghostty/blob/661e1e77f445057312666a74d9f5002e82f81764/.agents/skills/writing-commit-messages/SKILL.md).

#### docs-style (continue)

The skill: principles, tone, and heading rules as a standalone style skill. The fit: the documentation rules are stricter (ASD-STE100, one paragraph per physical line, plain ASCII) and already enforced by lint gates. The value is structural: it shows how to package style guidance as a skill, the shape the documentation discipline takes under M8 (Skills / Templates). Pinned source: [`SKILL.md`](https://github.com/continuedev/continue/blob/5522c6f44ca0ac3528b37244818fbfa39b5af470/.claude/skills/docs-style/SKILL.md).

#### human-like-code-review (n8n)

The skill: PR review that writes findings to a markdown file, prioritizing architecture fit and missing tests over line-level nitpicks. The fit: overlaps the existing `thermo-nuclear-code-quality-review` skill. The recommendation is to compare, not adopt: a side-by-side read tests whether the local skill covers written-artifact output and explicit scope coverage. Pinned source: [`SKILL.md`](https://github.com/n8n-io/n8n/blob/8bff5da5a29abe99fb5b3ba1b90035bf3040e49e/.agents/skills/human-like-code-review/SKILL.md).

### Adopt whole-guide reference material (Omarchy)

The Omarchy instruction file and its `shell-dev` guide are the strongest structural reference for a shell-centric repository: task-guide routing, authoritative-source refusals, defensive-check noise rules with exceptions, and named test entry points. This option keeps them as reference material only; no content is copied.

## Decision

Draft recommendation, pending the scheduled review:

- Adopt the verification-matrix table, the extended router, the ratchet-direction sentences, and the prohibition-hygiene audit. The single-source pattern is already satisfied; the review confirms the pointers stay.
- Model local skills on `implementation-final-review` (adopt the tier ladder) and on `writing-commit-messages` and `docs-style` (adapt as templates). Compare `human-like-code-review` against the existing review skill.
- Keep Omarchy as reference material.
- File the skill work under M8 (Skills / Templates), not started.

No instruction file changes land in this iteration. The review task decides the adoption and records the decision.

## Consequences

What changes if adopted: `AGENTS.md` gains a verification table and task-kind router rows; the lint and documentation docs gain one ratchet-direction sentence each; the prohibition lists gain alternatives. No lint-gate or code changes are included; M3.1 gates stay as built.

What this enables: the skill work feeds M8 (Skills / Templates) and the prompt-eval story; the evaluation infrastructure gets testable skills that encode policy. What this forecloses: nothing in the current milestone; the adoption is review-gated and reversible.

## Sources

All material came from the ossrules.md API snapshots. The project detail, pattern detail, and skill detail endpoints were fetched for the shortlisted items; the rest of the corpus was seen at summary level only, so this draft claims coverage only for what it read. Pinned source links appear inline above; the pattern overviews live at [ossrules.md/agent-rules](https://ossrules.md/agent-rules).
