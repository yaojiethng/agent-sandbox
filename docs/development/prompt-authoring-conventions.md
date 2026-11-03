# Prompt and Skill Authoring Conventions

The rules for writing a prompt or a skill are the `instruction-authoring` skill at `.agents/skills/instruction-authoring/SKILL.md`, where a writer starts and where each rule has one home.

This page holds the one instruction the skill leaves here: the draft gate.

A prompt or a skill under review goes to the skill's `runbook/review.md`; text that has grown by accretion goes to `prose-review`'s `instruction-cleanup` runbook. Neither runs without the operator's word.

## Draft status and the switch-over gate

A prompt or skill not yet operator-reviewed is a draft. The durable gate is the location: drafts live in `.agents/drafts/`, a root the frontmatter gate does not scan, the dispatch conventions do not read, and live dispatch never references, so an unreviewed prompt is structurally unreachable by the run paths that would trust it. The file carries `**Status:** draft` as its human-readable marker.

A draft is released only on explicit operator direction, in one commit that moves the file into its live root and runs a documentation pass over it at the same time; the move is the promotion, so there is no separate step to forget. A prompt written by an autonomous worker unit is a draft by default, whatever its author claimed: the `maintenance` dispatch prompt's premature switch-over is the recorded incident.
