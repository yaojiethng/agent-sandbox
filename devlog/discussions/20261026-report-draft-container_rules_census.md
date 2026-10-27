---
reader: [agent, operator]
status: draft
---

# The container half of the carrier: one seat, and the second seat blocked

Two seats over `.agents/audits/kelsey-code-reviewer.skill.md`, both on the goal-only prompt at thinking level `high`, both returning faults only. Seat 1 ran on `deepseek/deepseek-flash`. Seat 2 did not run: `openrouter/z-ai/glm-5.3-flash` answered `401 API key expired` before the model was reached, so there is no second reading and nothing is merged yet.

## The control this was meant to be, and why it is not one

B over this carrier already ran in the six-carrier census, where it raised 14 faults over 13 sites. A matching seat 1 would have shown the pinned-model invocation yields what the ablation harness yielded. It cannot: the carrier has moved since. `tests/eval/instruction-cleanup/room/kelsey-code-reviewer.skill.md.orig` froze it at 158 lines, and it is 160 now, because the absorb step rewrote each rule in the bash block to cite its entry id and inserted the paragraph that says so. Every line number from 90 down therefore names different text than the census named, which also means a record citing this carrier by line now points at shifted text.

Seat 1 raised 17 entries where the census recorded 14, and its sites before the shift correspond to the census sites. The delta is in judgements, not in yield.

## What this seat says about the container block

Nothing. All nine bullets under `## Review Standards -- Dockerfile` (`:105` to `:118`) came back unflagged, and no entry names a site inside that block. The nearest entries are `:100` and `:102`, which are shell rules that name a repository convention, and `:123` onward, which is the feedback style.

So the ten container rules are not faulted by this reading. What happens to them is a ruling about which of them this repository holds, taken against the tree, and a fault census cannot supply it.

## Seat 1, verbatim

## Faults

**1. `.agents/audits/kelsey-code-reviewer.skill.md:4`**
Rule: "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write"
Fault: **harmful** -- a review grants `Write`, `KillBash` and `BashOutput`, so the reviewer can edit and kill what it reviews; a review that writes cannot be attributed to a revision. Every listed tool name except `Read` is from a different agent runtime and does not exist here (`Glob`, `LS`, `WebFetch`, `TodoWrite`, `BashOutput`, `KillBash`), so the line names grants the agent does not have and omits `Bash`, which a shell review needs.
Recommendation: replacement -- `tools: Read, Grep, Glob, Bash` (read-only); do not grant `Write`.

**2. `.agents/audits/kelsey-code-reviewer.skill.md:5`** and **:6**
Rule: "model: opus" / "color: orange"
Fault: **harmful** -- `model` and `color` are not keys of this harness's skill front matter, so both are inert; the reviewer's model therefore comes from nowhere rather than from the project's role table, and the pin reads as a decision that was made. `opus` is not a `pi` model id.
Recommendation: removal.

**3. `.agents/audits/kelsey-code-reviewer.skill.md:37`**
Rule: "- Use of `&&` chains where a mid-chain failure leaves state partially applied"
Fault: **harmful** -- the stated failure mode does not occur. `a && b` short-circuits: a failing left operand halts the chain, and under `set -e` the shell exits. A reviewer applying this line files a blocker against correct code, and the rule as written is indistinguishable from a ban on `&&`.
Recommendation: replacement -- "`AND` chains are fine; a sequence that must be all-or-nothing is the thing to flag -- `a; b; c` under `set -e` leaves `a` applied when `c` fails, so state the ordering or make the step idempotent."

**4. `.agents/audits/kelsey-code-reviewer.skill.md:98`**
Rule: "- Quote everything. The only safe unquoted expansions are arithmetic contexts and deliberate word splitting, which must be commented."
Fault: **harmful** -- the exception list omits pattern and match contexts, where quoting is the defect: `[[ $s == foo* ]]`, `case $x in *.sh)`, `[[ $p =~ ^a+$ ]]`. A reviewer applying "quote everything" flags the idiomatic form as a blocker, and the safety audit at line 31 inherits the same over-reach.
Recommendation: replacement -- "Quote every expansion that is passed as a word. Leave unquoted, and expect them unquoted: arithmetic contexts, the right-hand side of `[[ ... == ... ]]` and `=~`, and `case` patterns. Comment any deliberate word splitting."

**5. `.agents/audits/kelsey-code-reviewer.skill.md:144-146`**
Rule: "If the code has pervasive issues, provide a complete rewrite. Partial patches on fundamentally broken code produce fundamentally broken code with patches."
Fault: **harmful** -- it converts a reviewer into an author. A rewrite is unreviewable against the diff it came from, carries none of the original's constraints, and cannot be attributed to a commit. The claim in the second sentence is also unfalsifiable.
Recommendation: removal of the section.

**6. `.agents/audits/kelsey-code-reviewer.skill.md:124`**
Rule: "5. **Concrete**: Every critique includes the corrected version. Don't describe the fix  --  show it."
Fault: **harmful** -- "every critique" forced to carry code makes the reviewer emit patches for style observations it should only name, and collides with the read-only grant a review needs (entry 1) and with `.agents/audits/` being an audit, not an implementation.
Recommendation: replacement -- "Show the corrected line where the correction is one line or one ordering; name the change where it is structural, so the operator can judge the direction before code exists."

**7. `.agents/audits/kelsey-code-reviewer.skill.md:155`** with **:158**
Rule: "- Does every script in the codebase follow the same conventions, or has each one invented its own?" / "If any answer is \"no\" or \"maybe,\" that is a finding."
Fault: **harmful** -- the question is unanswerable from the file under review, so the honest answer is "maybe" and line 158 then mandates a finding that rests on no evidence. The same applies to line 152 ("someone who did not write it") and line 154 ("six months from now"): both are counterfactuals, so "maybe" is the only available answer.
Recommendation: replacement -- "Where a closing question cannot be answered from the file under review, record it as a question for the operator and not as a finding. A finding states the site, the failure mode, and the evidence in the file."

**8. `.agents/audits/kelsey-code-reviewer.skill.md:90`**
Rule: "Each rule in this block is held as an entry in the `code-review-bash` pattern set, which is the better version of it: where a line here states one differently, the entry wins and a finding cites its id."
Fault: **harmful** -- the block declares itself superseded and leaves its own text in place, so a reader gets one rule in two versions with a precedence note as the only signal. The precedence covers only the Bash block: the Dockerfile block at 104-114 restates section 2's Dockerfile list (58-65) with no such note, so the two Dockerfile versions have no resolution. `p-15` (92) and `p-18` (30, 45, 92, 93) are cited as if defined; the file defines neither.
Recommendation: deletion of the Bash and Dockerfile Standard blocks (88-114), leaving the pattern set as the single site, and deletion of the restating lists at 58-65 and 30-37 that they duplicate; if any rule here is unique, move it to the pattern set entry and cite the id.

**9. `.agents/audits/kelsey-code-reviewer.skill.md:26-86`** against **:88-114**
Rule: sections "Safety audit", "Idiomatic discipline", "Architecture and design", "Operability test" as one statement of the rules, then "Review Standards -- Bash" and "Review Standards -- Dockerfile" as another.
Fault: **redundant** -- the same rules are stated twice in different words. Enumerated: quoting (31-32, 98); stderr/stdout split (34, 84, 95); `local` (33, 47, 94); error-message content (20, 83, 96); `--` before paths (53, 101); `[[ ]]` and `$(...)` (49-50, 99); `local`-free sourced library (33, 46, 93); pinned base (58, 106); `COPY` not `ADD` (60, 109); non-root (62, 111); explicit `WORKDIR` (63, 112); exec-form `ENTRYPOINT` (65, 110); minimal image (64, 114); self-consistency (22, 102, 155). Two copies drift, and neither copy says which tier a violation lands in.
Recommendation: replacement -- one list per use case, each line a rule with its tier; delete the second statement.

**10. `.agents/audits/kelsey-code-reviewer.skill.md:30`**
Rule: "- Missing `set -euo pipefail` in a script that is only executed, or a top-level `set` in one the tests also source (`p-18`)"
Fault: **ambiguous wording** -- one bullet carries two unrelated conditions joined by "or", so a reviewer cannot cite which half failed; and "a script that is only executed" is defined by a property the reviewer cannot see in the script itself (a pure library also has no sourcing site). Line 45 repeats the same question in interrogative form under the same id.
Recommendation: replacement -- split into the three consumption classes already used at line 92 and delete the duplicate at 45: "Executed and never sourced: `set -euo pipefail` at the top. Executed and sourced (for example by tests): flags inside `main()` or the guard, never at the top. Pure library: no options set."

**11. `.agents/audits/kelsey-code-reviewer.skill.md:46`**
Rule: "- Are sourced library files structured so they are safe to source under `set -euo pipefail`?"
Fault: **ambiguous wording** -- "safe to source under" does not say whether the library sets the flags or merely tolerates them, and it sits in tension with line 93 ("A sourced library sets no options"), so the reviewer must guess which reading is the rule.
Recommendation: removal; the requirement is stated once, at 92-93.

**12. `.agents/audits/kelsey-code-reviewer.skill.md:100`** and **:102**
Rule: "- `git status --porcelain` to check for changes, not multiple `git diff` calls with boolean flags accumulated into variables." / "- Image name construction must be consistent. If one script lowercases a name with `${VAR,,}`, every script that constructs the same name must do the same."
Fault: **redundant** -- both are requirements of one repository's own shell code, filed under a block that claims to state general production Bash standards, so they fire as blockers against unrelated code. Line 100 also names a mechanism without a failure mode, and `git status --porcelain` includes untracked files by default, which is a different answer from `git diff` -- the substitution changes the check.
Recommendation: replacement -- move both to the repository's own code convention; here state the general rule only: "A rule this repository's scripts must all follow is a convention: one site, named, and a finding cites it by name."

**13. `.agents/audits/kelsey-code-reviewer.skill.md:123`** against **:128-142**
Rule: "4. **Prioritised**: Separate correctness issues (must fix) from style issues (should fix) from observations (worth knowing)." / "### Critical Issues" / "### Improvements Needed" / "### What Works Well"
Fault: **ambiguous procedure** -- three tiers are promised and two are emitted; the "observations (worth knowing)" tier has no section, and "What Works Well" is a fourth section the tier list does not mention. A reviewer cannot tell where an observation goes, so it either drops it or promotes it to a finding.
Recommendation: replacement -- fix the tiers in the output format and have the feedback style cite them by name, e.g. sections `Critical` (must fix), `Improvements` (should fix), `Observations` (worth knowing), `What Works Well`.

**14. `.agents/audits/kelsey-code-reviewer.skill.md:9`**
Rule: "You are an elite code reviewer channeling the exacting standards and operational philosophy of Kelsey Hightower  --  SRE, Kubernetes contributor, and one of the most respected voices on production systems discipline."
Fault: **harmful** -- the file's rules are presented as a named living person's standards, which no reviewer can check and no operator can revise; where the file's own rules are wrong (entries 3, 4) the attribution argues against correcting them. "Elite" adds no test a finding can meet.
Recommendation: replacement -- "You review shell and container code against the rules below. Where a rule is missing or wrong, the finding names the site and the failure mode; the rules are the standard, not the reviewer's taste."

**15. `.agents/audits/kelsey-code-reviewer.skill.md:86`**
Rule: "- Is there a dry-run or diagnostic path that can be run safely to verify configuration before a live run?"
Fault: **ambiguous wording** -- it demands new functionality from any script under review, but states no tier and no failure mode, so it reads as a blocker against every script that has no `--dry-run`.
Recommendation: replacement -- "A script whose first live run can destroy state has a dry-run or a documented pre-flight check. Name the destructive step when it does not."

**16. `.agents/audits/kelsey-code-reviewer.skill.md:72`** and **:74**
Rule: "- Are library functions (`lib/`) pure  --  do they receive all inputs as arguments and produce all outputs via stdout or return values, with no side effects outside their documented scope?" / "- Is the distinction between host-side and container-side logic clear and enforced?"
Fault: **ambiguous wording** -- both assume this repository's layout: a `lib/` directory, a host/container split. A reviewer holding any other tree cannot evaluate them, and "documented scope" is never defined, so a violation cannot be stated as a site.
Recommendation: replacement -- "A function's side effects are the ones its header comment declares; an undeclared write to a path, a global or the environment is a finding at that line." Delete the host/container line; it is a property of this repository, not of shell code.

**17. `.agents/audits/kelsey-code-reviewer.skill.md:1-7`**
Rule: the file is a `SKILL.md`-bodied document living at `.agents/audits/kelsey-code-reviewer.skill.md` with subagent front matter (`name`, `description`, `tools`, `model`, `color`).
Fault: I do not have one of your four categories for this: **wrong artifact form** -- a skill here is `<dir>/SKILL.md`, so this file is loaded by nothing, while its body is written as a live instruction set ("Scan immediately", "Before closing the review"). The `description` also embeds worked examples with a truncated function call, which is skill-listing pad, not instruction.
Recommendation: replacement -- land the rules that survive as a runbook under the `code-review` base skill; the file's own layer then disappears rather than being maintained beside it.
