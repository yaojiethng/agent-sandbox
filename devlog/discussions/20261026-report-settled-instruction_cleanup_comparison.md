---
reader: [agent, operator]
status: settled
---

# Instruction-cleanup comparison: one file, two prompts

Does the landed 168-line pass raise faults the 18-line goal-only draft does not, over the same file? Both arms judge one calibration file, this record holds what each returned, and the operator rules per site on whether the fault is valid. Format is not compared; a raised fault is the whole unit of measure.

## The run

- `workflow/coding-agent/prompts/instruction-cleanup.md` (168 lines) against `.agents/drafts/instruction-cleanup-goal-only.md` (18 lines).
- Calibration file: `.agents/audits/kelsey-code-reviewer.skill.md`, 158 lines. It is in the cleanup pass's census, no arm had seen it, and it carries all four fault classes.
- Both arms ran the same preamble: read the file, run the procedure, return faults only, stop before the screen, edit nothing.
- Both arms ran role `_REVIEWER` at thinking level `high` on `deepseek/deepseek-flash`, arm A in 138s and arm B in 119s.
- Arm B's first run resolved to `opencode/deepseek-v4.1-flash-free` and was discarded: two runs of one role can land on different assignments, so the comparison pins the assignment. That run's fault list is not in this record.

## The count

| | Arm A, the landed pass | Arm B, the goal-only draft |
|---|---|---|
| Faults raised | 20 | 20 |
| Distinct sites | 20 | 20 |
| harmful | 6 | 8 |
| ambiguous wording | 5 | 4 |
| ambiguous procedure | 2 | 4 |
| redundant | 3 | 4 |
| other | 4 | 0 |

Nine sites were raised by both arms: 3, 4, 5, 37, 51, 74, 98, 121, 144. Eleven were raised by A alone: 31, 32, 35, 41, 54, 72, 90, 92, 93, 104, 118. Eleven by B alone: 9, 11, 17, 36, 45, 86, 94, 95, 96, 109, 156.

## Arm A -- the landed pass

| Site | Fault | Rule as the file states it | Recommendation |
|---|---|---|---|
| 4 | harmful | "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write" | removal - a review's tool boundary is the harness's, and this field states half of it in a vocabulary this runtime does not carry. |
| 5 | harmful | "model: opus" | removal - the assignment belongs to the role table, not to the reviewed surface. |
| 3 | ambiguous wording | "review them against Kelsey Hightower's exacting standards for production-grade shell and container code" / "against the same rigorous crite | my text: "You evaluate Bash scripts and Dockerfiles against the criteria below." (mine). |
| 90 | harmful | "'set -euo pipefail' is non-negotiable in every executable script. No exceptions." | my text: "'set -euo pipefail' at the top of every orchestrator entry point; no '-e' in observe-and-report scripts; never in a sourced library." (mine). ':30' and ':45' are the same rule stated twice more and are removal  |
| 35 | harmful | "'exit' or 'return 1' missing after error output" | my text: "'exit' in a script and 'return' in a function, with a status that names the failure." (mine). |
| 37 | harmful | "Use of '&&' chains where a mid-chain failure leaves state partially applied" | removal - the mechanism is a property of the side effects, not of '&&', so the row forbids a safe idiom for a risk it neither creates nor removes. |
| 41 | redundant | "Evaluate whether the code uses the language's own idioms correctly:" (with the rows that follow) | removal of ':41'-':65' as a second site, with ':52' and ':54' carried into ':88'-':112' as the only rows with no standard behind them; ':51' is raised at item 12. |
| 31 | other | "Unquoted variable expansions ('$VAR' instead of '"$VAR"')" / "The only safe unquoted expansions are arithmetic contexts and deliberate word | quote ':96''s exception into ':31', which already states it. |
| 32 | redundant | "Unquoted command substitutions" | removal - one rule with two rows in the same list. |
| 92 | other | "Every function in a library must declare all its variables 'local'." / "Are functions using 'local' for all variables?" / "Functions in sou | two options: (a) widen ':92' and ':33' to every function, my text: "Every function declares its variables 'local'; leaking into the caller's namespace is a bug." (mine); (b) narrow ':47' to library functions and delete ' |
| 93 | redundant | "All error output goes to stderr ('>&2'). All structured output (paths, SHAs, names the caller will use) goes to stdout." / "Error messages  | removal of ':34' and ':84'; ':93' is the home because it is the only site that states the stdout exception. |
| 51 | ambiguous procedure | "Are here-docs used where appropriate instead of multi-line echo chains?" | removal - the row states no condition a reviewer can apply, and no other site supplies one. |
| 54 | other | "Are arrays used for multi-value variables instead of space-delimited strings?" / "deliberate word splitting, which must be commented" | keep ':54'; my text for ':96': "Quote everything, except arithmetic contexts." (mine). |
| 72 | ambiguous wording | "Are library functions ('lib/') pure -- do they receive all inputs as arguments and produce all outputs via stdout or return values, with no | removal of the word 'pure' - the clauses after it state the requirement without it, and nothing in the file defines the stronger reading. |
| 74 | ambiguous wording | "Is the distinction between host-side and container-side logic clear and enforced?" | removal - the terms and the enforcement mechanism are stated nowhere in the file, so the check cannot be performed or failed. |
| 98 | ambiguous wording | "'git status --porcelain' to check for changes, not multiple 'git diff' calls with boolean flags accumulated into variables." | my text: "Use 'git status --porcelain' to detect changes; do not accumulate the results of several 'git diff' calls in variables." (mine). |
| 104 | ambiguous wording | "Pin base images. 'ubuntu:24.04' is acceptable; 'ubuntu:latest' is not." | my text: "Pin base images by version tag, and by digest where a rebuild must reproduce bit-for-bit." (mine). |
| 118 | other | "**Direct**: Name the problem without hedging. "This is incorrect" not "this might be worth considering."" / "If any answer is "no" or "mayb | my text: "A premise you could not settle is reported as unconfirmed, naming the check that would settle it." (mine). |
| 121 | ambiguous procedure | "**Prioritised**: Separate correctness issues (must fix) from style issues (should fix) from observations (worth knowing)." | my text: an '### Observations' section in the Output Format, between What Works Well and Refactored Version (mine); option, drop the third tier from ':121' instead, at the cost of the reviewer's low-confidence notes. |
| 144 | harmful | "If the code has pervasive issues, provide a complete rewrite. Partial patches on fundamentally broken code produce fundamentally broken cod | removal - a rewrite carries no attributable site, which ':119' and ':132' require; where a rewrite is wanted the operator asks for it after reading the findings. |

## Arm B -- the goal-only draft

| Site | Fault | Rule as the file states it | Recommendation |
|---|---|---|---|
| 4 | harmful | 'tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write' | removal - 'docs/reference/dispatch.md:80' states a reviewer run is read-only, 'docs/reference/dispatch.md:80' and the role table own what a reviewer may do, and no rule in the file depends on the list. |
| 5 | harmful | 'model: opus' | removal - the '_REVIEWER' line in '.agents/model-recommendations.md' derives the assignment, per the project rule that the role table wins. |
| 3 | ambiguous wording | 'description: Use this skill whenever new Bash scripts or Dockerfiles have been written or modified, to review them against Kelsey Hightower | my own text - 'description: Review Bash scripts, Dockerfiles and entrypoint scripts against the repository's bash coding conventions and the Dockerfile standards below. Use after writing or modifying any .sh file, Docker |
| 9 | harmful | 'You are an elite code reviewer channeling the exacting standards and operational philosophy of Kelsey Hightower -- SRE, Kubernetes contribu | removal - every criterion the persona is meant to supply is stated as a rule at lines 88-112, and an unfalsifiable standard can only add findings the operator cannot trace to a rule. |
| 86 | harmful | 'Is there a dry-run or diagnostic path that can be run safely to verify configuration before a live run?' | removal - no rule states which scripts require a diagnostic path, so the question can only produce noise. |
| 156 | harmful | 'If any answer is "no" or "maybe," that is a finding.' | my own text - 'An answer of "no" to a question above is a finding. An answer of "maybe" is a question the reviewer resolves before closing, not a finding.' |
| 144 | harmful | 'If the code has pervasive issues, provide a complete rewrite. Partial patches on fundamentally broken code produce fundamentally broken cod | removal - the reviewer reports findings and the corrected form per item; a rewrite is authoring, which is a different role. |
| 96 | harmful | 'Quote everything. The only safe unquoted expansions are arithmetic contexts and deliberate word splitting, which must be commented.' | replacement text quoted from 'docs/development/bash-coding-conventions.md:40' - 'Quote all variable expansions containing filenames' |
| 95 | harmful | 'Validate arguments at the top of every function and every script. State what was expected.' | my own text - 'Validate the arguments of every function and script that takes input, at its top, naming what was expected.' |
| 37 | ambiguous procedure | 'Use of '&&' chains where a mid-chain failure leaves state partially applied' | removal - line 90's mandatory flag already stops a mid-chain failure, and the rule names no state to check. |
| 94 | ambiguous wording | 'Error messages follow the pattern: 'FunctionName: what failed -- what the caller should do'. Including the function name makes errors attri | my own text - 'Every line written to stderr begins with the name of the function that produced it and ': '. An error message continues with what failed and what the caller should do; a log line continues with the event.' |
| 121 | ambiguous procedure | '**Prioritised**: Separate correctness issues (must fix) from style issues (should fix) from observations (worth knowing).' | removal of the 'from observations (worth knowing)' clause - reason: no output section carries that class, so the triage and the output format state different numbers of classes. |
| 109 | ambiguous procedure | 'Non-root user with a fixed UID. The UID matters for volume mount ownership -- document it.' | my own text - 'Non-root user with a fixed UID. State the UID and the ownership it implies in a comment above the 'USER' line, because volume mount ownership depends on it.' |
| 98 | ambiguous wording | '' 'git status --porcelain' to check for changes, not multiple 'git diff' calls with boolean flags accumulated into variables. '' | removal - the failure mode is unstated, and the rule is about one script's history rather than a standard a reviewer can apply. |
| 74 | ambiguous procedure | 'Is the distinction between host-side and container-side logic clear and enforced?' | removal - the distinction is a fact about this repository's layout, and the file states it nowhere; a rule that cannot be answered in the general case belongs to the surface that owns the layout. |
| 51 | ambiguous wording | 'Are here-docs used where appropriate instead of multi-line echo chains?' | replacement text quoted from 'docs/development/bash-coding-conventions.md:11' - 'Makefile content: 'printf', not heredocs' |
| 45 | redundant | 'Are safety flags ('set -euo pipefail') present at the top of every executable script?' | removal of the Bash question list at lines 45-54 - reason: lines 88-99 state each of the same rules once, in the imperative form a reviewer applies, and 'docs/development/bash-coding-conventions.md' owns the rules themse |
| 17 | redundant | '- **Correct before clever**: Safety flags, quoting, and error handling are not optional. A script that works 99% of the time is broken.' | removal of the Core Philosophy block at lines 17-22 - reason: every bullet is a second statement of a rule at lines 88-112, and only the later statement carries a test. |
| 11 | redundant | 'Your standard is not "does this work on my machine." It is: "would this hold up at 2am when something goes wrong and the person reading it  | removal - line 158 states the standard once, as a criterion. |
| 36 | redundant | 'Commands that can fail silently (piped commands where only the last exit code is checked)' | removal - the mandated 'pipefail' flag already covers the case, and line 90 is the site that owns it. |

## The site matrix

| Site | A | B | What the file states there |
|---|---|---|---|
| 3 | ambiguous wording | ambiguous wording | "review them against Kelsey Hightower's exacting standards for production-grade shell and  |
| 4 | harmful | harmful | "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write" |
| 5 | harmful | harmful | "model: opus" |
| 9 | -- | harmful | 'You are an elite code reviewer channeling the exacting standards and operational philosop |
| 11 | -- | redundant | 'Your standard is not "does this work on my machine." It is: "would this hold up at 2am wh |
| 17 | -- | redundant | '- **Correct before clever**: Safety flags, quoting, and error handling are not optional.  |
| 31 | other | -- | "Unquoted variable expansions ('$VAR' instead of '"$VAR"')" / "The only safe unquoted expa |
| 32 | redundant | -- | "Unquoted command substitutions" |
| 35 | harmful | -- | "'exit' or 'return 1' missing after error output" |
| 36 | -- | redundant | 'Commands that can fail silently (piped commands where only the last exit code is checked) |
| 37 | harmful | ambiguous procedure | "Use of '&&' chains where a mid-chain failure leaves state partially applied" |
| 41 | redundant | -- | "Evaluate whether the code uses the language's own idioms correctly:" (with the rows that  |
| 45 | -- | redundant | 'Are safety flags ('set -euo pipefail') present at the top of every executable script?' |
| 51 | ambiguous procedure | ambiguous wording | "Are here-docs used where appropriate instead of multi-line echo chains?" |
| 54 | other | -- | "Are arrays used for multi-value variables instead of space-delimited strings?" / "deliber |
| 72 | ambiguous wording | -- | "Are library functions ('lib/') pure  --  do they receive all inputs as arguments and prod |
| 74 | ambiguous wording | ambiguous procedure | "Is the distinction between host-side and container-side logic clear and enforced?" |
| 86 | -- | harmful | 'Is there a dry-run or diagnostic path that can be run safely to verify configuration befo |
| 90 | harmful | -- | "'set -euo pipefail' is non-negotiable in every executable script. No exceptions." |
| 92 | other | -- | "Every function in a library must declare all its variables 'local'." / "Are functions usi |
| 93 | redundant | -- | "All error output goes to stderr ('>&2'). All structured output (paths, SHAs, names the ca |
| 94 | -- | ambiguous wording | 'Error messages follow the pattern: 'FunctionName: what failed  --  what the caller should |
| 95 | -- | harmful | 'Validate arguments at the top of every function and every script. State what was expected |
| 96 | -- | harmful | 'Quote everything. The only safe unquoted expansions are arithmetic contexts and deliberat |
| 98 | ambiguous wording | ambiguous wording | "'git status --porcelain' to check for changes, not multiple 'git diff' calls with boolean |
| 104 | ambiguous wording | -- | "Pin base images. 'ubuntu:24.04' is acceptable; 'ubuntu:latest' is not." |
| 109 | -- | ambiguous procedure | 'Non-root user with a fixed UID. The UID matters for volume mount ownership  --  document  |
| 118 | other | -- | "**Direct**: Name the problem without hedging. "This is incorrect" not "this might be wort |
| 121 | ambiguous procedure | ambiguous procedure | "**Prioritised**: Separate correctness issues (must fix) from style issues (should fix) fr |
| 144 | harmful | harmful | "If the code has pervasive issues, provide a complete rewrite. Partial patches on fundamen |
| 156 | -- | harmful | 'If any answer is "no" or "maybe," that is a finding.' |

## What this record awaits

One ruling per site: valid fault, or not. A site both arms raised is not thereby valid; two runs of one model can share a misreading, and the agreement is a hint rather than a proof. The ruling is owned by the roadmap row **The corpus census over every review-instruction carrier**, which reads this record as its evidence and rules every carrier in one pass rather than this file alone; the prompt decision is owned by **The instruction-cleanup eval case set**, which grades against those rulings. Handover `20261026-04` carries the census.
