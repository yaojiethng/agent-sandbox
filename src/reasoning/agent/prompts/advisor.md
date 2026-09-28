---
description: Run a fresh external model as an advisory reviewer over a single file or artifact, and work to consensus. Use when a fresh perspective is needed on agent-context authoring, code, or a design, and the current agent's blind spots risk missing defects. The advisor is consulted for a second perspective on one concrete artifact.
argument-hint: "<target file or artifact path> -- <focus concern>"
---

Advisor review over: $@

## Role split

The advisor reviews one concrete artifact. You are the leader with decision authority: you triage the advisor's findings, decide which to accept, and apply the accepted fixes. The advisor does not edit; it only reports. Never let the advisor's wording override your own decision authority, and do not re-open a settled decision without a concrete reason.

## Invocation

Run a fresh subagent with its own context. It does not inherit this session's conversation, loaded files, or tool state, so pass the whole assignment in the argument.

State the model and thinking level in the brief, because the subagent cannot see the invocation flags. Use the review-advisor pair already working in this repo (`glm-5.3-flash` at `high` thinking for language-shaped reviews). Capture the run to a log file, never through a pipe, with a generous timeout. Write both the brief and the log in `/tmp`, never in the repo tree:

```bash
timeout 1800 pi --provider opencode-go --model glm-5.3-flash --thinking high -p "$(cat /tmp/advisor-brief.md)" > /tmp/advisor.log 2>&1
```

If the run fails or the log is empty, fix the invocation and rerun before triaging.

## Construct the brief

Write the brief to a throwaway file in `/tmp`. It must contain:

1. **What to review:** the full path of the target file, and the instruction to read it in full.
2. **The review concerns, in priority order.** Name the in-scope targets explicitly. Do not ask the advisor to judge things you know are out of scope.
3. **A limited deliverable format:** numbered defects, each with location, defect, and suggested fix; then an overall verdict. Give the advisor a way to say "no remaining defects" plainly so the loop can terminate.
4. **The advisor framing:** it is an advisor, not the decision-maker.
5. Enough surrounding context (the artifact's purpose, how it will be used) that the advisor does not need any other file to review it.
6. **The model and thinking level**, matching the invocation, so the report carries the attribution the subagent cannot see.
7. **Adjacent-file scope (optional).** The advisor may read the sibling prompts and the governing policies that the reviewed artifact names, for coherence and term-consistency against the project. Bound this to obvious adjacency: the reviewed prompt's siblings and the policies it cites. Do not let it read unrelated documents.
8. **Direct answers (optional).** The brief may pose concrete yes/no questions about the artifact ("does the shaping role end in a bundle?", "is the delegation removed?"). The advisor must answer each head-on after the defect list.

Require the brief to ask for one closing line: a single literal sentence the advisor ends its reply with, naming either the clean bill ("Consensus reached -- no remaining defects") or the remaining-blocker verdict ("Needs major rework -- <reason>"). This line makes the loop's termination test unambiguous.

## Triaging the advisor's findings

Read the advisor's report and route each finding as leader:

- **Accept** -- the defect is real. Apply the fix.
- **Partially accept** -- the defect has merit but the suggested fix breaks an intent you want to keep. Apply a fix that keeps that intent while correcting the defect.
- **Reject** -- the defect is not valid, the advisor is wrong about a fact of this system, or the current wording is the settled result of a known trade-off. Keep your reading and record the rejection with the reason.

Apply the accepted fixes. If the advisor's reasoning changes the shape of the work, say so plainly rather than folding it in silently.

## Work to consensus

Re-invoke the advisor on the revised artifact. The follow-up brief lists which earlier findings were addressed and asks for the remaining objections, carrying forward the same review concerns and deliverable format as the first brief. Keep the loop going until the advisor reports a clean bill of health.

A clean bill is a positive statement; it can be a statement that is not a finding, but it must be present ("no remaining defects", "consensus reached") rather than the absence of a reply. Do not treat the artifact as done until that statement lands.

An advisor that has nothing substantive left to say should be encouraged to say so directly rather than manufacture findings. When no substantive finding remains, the advisor says so in the required closing line; it does not manufacture a trivial finding to fill the list. If the advisor keeps raising the same point after it is already handled, record the point as settled in the next brief and, if it is raised again, close the loop with that finding rejected on record.
