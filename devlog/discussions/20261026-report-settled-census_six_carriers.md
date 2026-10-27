---
date: 2026-10-26
type: Discussion
status: settled
---

# The census run: both prompts over six carriers

## The run

Twelve runs, one carrier each, both arms of the cleanup comparison over the same set, so that the fault list a carrier draws is not a property of one reading alone. Arm A is the landed pass, [`instruction-cleanup.md`](../../workflow/coding-agent/prompts/instruction-cleanup.md) at 168 lines; arm B is the goal-only draft, [`instruction-cleanup-goal-only.md`](../../.agents/drafts/instruction-cleanup-goal-only.md) at 18 lines.

The assignment is pinned rather than resolved: `deepseek/deepseek-flash` at thinking level `high`, for every one of the twelve runs, verified from each session file as a single model id. A resolved role would have let the arms differ by model and made the comparison a measurement of resolution order.

The role line names `opencode/deepseek-v4.1-flash-free` first. That id answers only through the runtime its prefix names: `opencode run -m opencode/deepseek-v4.1-flash-free` answers in seconds, while the same id through `pi`'s provider path returns `429 FreeUsageLimitError` in about a second. The refusal is a misfire of the invocation rather than an unavailable model, and it is the reason an `opencode/` pair runs through `opencode run` and every other provider through `pi`. The pin is not about reachability: a different runtime is a different measurement, so the twelve cells here are comparable only because all twelve read the same model through the same backend.

Each run was told to return the faults it raised and to stop: no screen, no edit, no fold, no record. The logs are session-local under `.scratchpad/census/logs/`; the lists below are the record.

## The counts

| Carrier | Lines | Arm A | Arm B | Both | A only | B only |
|---|---|---|---|---|---|---|
| `kelsey-code-reviewer.skill.md` | 158 | 19 | 13 | 7 | 12 | 6 |
| `architecture-doc-reviewer.skill.md` | 166 | 17 | 13 | 8 | 9 | 5 |
| `dhh-code-audit.skill.md` | 99 | 19 | 21 | 11 | 8 | 10 |
| `bash-audit.skill.md` | 29 | 5 | 8 | 5 | 0 | 3 |
| `test-quality-campaign.md` | 106 | 10 | 17 | 7 | 3 | 10 |
| `test-assertion-sweep-brief.md` | 49 | 12 | 13 | 6 | 6 | 7 |
| **the set** | 607 | **82** | **85** | **44** | **38** | **41** |

Counts are distinct sites, not items: a carrier can carry two faults on one line, and both are listed below. The item totals are 92 for arm A and 100 for arm B, 192 across the set.

## The comparison this replaces

The earlier single-file run raised 20 faults on each arm, and that equality of count was read as the two prompts being equally effective, which would leave the 150 lines the pass holds over the draft buying nothing. The set does not support the reading. Volume is preserved, 82 sites against 85, and content is not shared: the union is 123 sites and the arms agree on 44, so each raises about a third of the union the other never touches. One asymmetry holds, and it runs against the long arm: on `bash-audit`, the draft raised all five of the pass's sites and three more.

What the set licenses is therefore narrower than either claim. The two prompts are equally productive and largely disjoint, neither subsumes the other, and an equality of count between two different prompts measured once cannot be told apart from the equality one prompt gives against itself. Which of the two sets is worth more is the census ruling's question and not this run's.

## The reproduction check

Arm A over `kelsey-code-reviewer.skill.md` ran once before, alone, on the same model, the same prompt and the same file, and raised 20 faults. Tonight it raised 20 items over 19 distinct sites, of which 5 repeat a site from that run (3, 4, 5, 98, 144) and 14 are sites it did not raise before (6, 9, 11, 17, 28, 30, 45, 47, 59, 96, 109, 122, 153, 156).

Arm B ran the same file before and raised 20 faults; tonight it raised 14 items over 13 distinct sites, 6 of them shared with that run.

A fault list is therefore a sample of a surface rather than an enumeration of it, and one run per carrier under-reports the set. That is a property of the method, recorded here as data: the ruling it bears on is the eval case set, which reads the same case twice.

## The fault lists

### kelsey-code-reviewer.skill.md -- 158 lines

#### Arm A -- 20 faults

**A1** `.agents/audits/kelsey-code-reviewer.skill.md:3`

- rule: description: Use this skill whenever new Bash scripts or Dockerfiles have been written or modified ... Invoke after writing or modifying any .sh file, Dockerfile, or entrypoint script

- fault: harmful instruction -- it states an automatic invocation that never fires. workflow/coding-agent/skills/code-review/SKILL.md:50 lists this file under "Not yet accepted" because "it names no scope, so there is nothing to dispatch", and .agents/audits/surface-area-report.md records .agents/audits/ as repo-side only, never deployed. A rule "invoke whenever X" that no dispatcher reads is obeyed by the reader and unsupported by the environment.

- recommendation: mine -- "Operator-invoked review of one Bash or Dockerfile change set, dispatched through the code-review shell; it runs when the operator invokes it, not on a file change."

**A2** `.agents/audits/kelsey-code-reviewer.skill.md:3`

- rule: the Examples:\n\n<example>\nContext: A new entrypoint script has been written for a container.\nuser: "Please write a container entrypoint that sets up the sandbox and runs the agent" ... block inside the same plain scalar.

- fault: a fault of my own naming -- inert harness payload in a plain YAML scalar: the literal \n escapes and <example> tags are read as one line of backslash text by any parser here, and the file is recorded as still carrying the unquoted-description parse defect at devlog/handovers/archive/20260929-08-workflow-prompt_frontmatter_fix_and_wrapup_reconcile.md:54.

- recommendation: removal - the examples demonstrate invocation for a harness that parses neither the escapes nor the tags; the sentence before the Examples: label is the whole description this repository reads.

**A3** `.agents/audits/kelsey-code-reviewer.skill.md:4`

- rule: tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write

- fault: harmful instruction -- conflict entry. docs/reference/review_runbook_template.md:21 states "A runbook names no model, role, provider, seat count, path or tool", and workflow/coding-agent/skills/code-review/SKILL.md:34 gives the seat "the read and inspection tools". Nine of these names bind no tool in this harness, and Write arms a reviewer against a caller who "applies" its suggestions.

- recommendation: removal - the environment is the shell's to state (review_runbook_template.md:21), and no name in this line resolves in this harness.

**A4** `.agents/audits/kelsey-code-reviewer.skill.md:5`

- rule: model: opus

- fault: harmful instruction -- conflict entry. workflow/coding-agent/skills/code-review/SKILL.md:32 states "A runbook never names a model, a role or a count", and docs/reference/review_runbook_template.md:21 names provider and model among what a runbook may not carry; the assignment is resolved per dispatch, so this field either overrides a route or names an id no route holds.

- recommendation: removal - replacement text is the site that already states it: "A runbook names no model, role, provider, seat count, path or tool".

**A5** `.agents/audits/kelsey-code-reviewer.skill.md:6`

- rule: color: orange

- fault: redundant instruction -- no reader in this repository consumes the field; it is the fourth environment attribute docs/reference/review_runbook_template.md:21 excludes, and nothing in this tree renders a colour.

- recommendation: removal - nothing reads it, and an environment attribute belongs to the shell that carries it.

**A6** `.agents/audits/kelsey-code-reviewer.skill.md:9`

- rule: You are an elite code reviewer channeling the exacting standards and operational philosophy of Kelsey Hightower -- SRE, Kubernetes contributor, and one of the most respected voices on production systems discipline.

- fault: harmful instruction -- it delegates the verdict to a body of doctrine the surface never states, so a finding justified by "the standards he applies" cannot be checked against any rule in the file, and the persona's judgement runs beside the rules below rather than through them.

- recommendation: removal - the operative standard is the rules this file states; the persona supplies a second, unstated one, and no site here can be cited to confirm a finding raised from it.

**A7** `.agents/audits/kelsey-code-reviewer.skill.md:11`

- rule: Your standard is not "does this work on my machine." It is: "would this hold up at 2am when something goes wrong and the person reading it has never seen it before?"

- fault: redundant instruction -- duplication entry. Line 158 states the same standard: The standard is not "it works in the happy path." The standard is "it fails loudly, fails safely, and leaves the system in a known state." Neither site states a check, so nothing distinguishes them but wording.

- recommendation: removal - line 158 carries the standard and the file acts on it there.

**A8** `.agents/audits/kelsey-code-reviewer.skill.md:17-22`

- rule: - **Correct before clever**: Safety flags, quoting, and error handling are not optional. A script that works 99% of the time is broken. and the five bullets after it under ## Core Philosophy.

- fault: redundant instruction -- duplication entry, six rules with two sites each: :17 restates :90 and :96, :19-:20 restate :82-:84, :21 restates :71-:72, :22 restates :100 and :153. No bullet states a rule the standards sections do not.

- recommendation: removal of the section - reason: the standards below state each of these as an item with a scope and a force, which is what a reviewer acts on.

**A9** `.agents/audits/kelsey-code-reviewer.skill.md:30,`

- rule: - Missing set -euo pipefail in any executable script / - Are safety flags (set -euo pipefail) present at the top of every executable script? / - set -euo pipefail is non-negotiable in every executable script. No exceptions.

- fault: redundant instruction -- duplication entry: one rule with three sites, and the three differ in force (a step-1 blocker, a step-2 question, a standing standard), so the blocker classification alone makes an edit to one site incomplete at the other two.

- recommendation: removal of :30 and :45 - line 90 states the rule with its scope and its force. Mine on which site keeps the blocker classification; the operator rules that word.

**A10** `.agents/audits/kelsey-code-reviewer.skill.md:47,`

- rule: - Are functions using local for all variables? / - Every function in a library must declare all its variables local. Leaking into the caller's namespace is a bug.

- fault: redundant instruction -- duplication entry with a scope drift: :47 binds every function, :92 binds every function in a library, :33 binds sourced libraries. A finding on a script's own function is graded by no rule, and the quantifier of one site cannot be changed without the others.

- recommendation: removal of :47 - :92 with :33 states the rule with the scope it has. Mine on the scope; the operator rules whether the rule is library-only or every function.

**A11** `.agents/audits/kelsey-code-reviewer.skill.md:28`

- rule: ### 1. Safety audit / Scan immediately for correctness violations -- these are blockers regardless of style: followed by an eight-item list, with no statement of what is being scanned.

- fault: ambiguous procedure -- the trace stops at step 1: it says what to look for and never says what input the look is over. docs/reference/review_runbook_template.md:13 requires a runbook to state its Scope accepted, this one states none, and workflow/coding-agent/skills/code-review/SKILL.md:50 records the consequence. The input nothing reads is the review's subject.

- recommendation: mine -- "Scope accepted: a delta (a diff or a named change set) or a set (named paths). Anything else is a refused dispatch." Then narrow :100 and :153 to that scope.

**A12** `.agents/audits/kelsey-code-reviewer.skill.md:153,`

- rule: - Does every script in the codebase follow the same conventions, or has each one invented its own? and - Image name construction must be consistent. If one script lowercases a name with ${VAR,,}, every script that constructs the same name must do the same.

- fault: ambiguous procedure -- both require facts about files the reviewer was not handed: the codebase, and every script that constructs an image name. With step 1 read as a change set, the answer is unknowable, and :156 turns the unknown into a finding.

- recommendation: mine -- "Does every script in the change set (or the named set) follow the same conventions...", and for :100 "If a script in scope lowercases a name with ${VAR,,}, every script in scope that constructs the same name does the same."

**A13** `.agents/audits/kelsey-code-reviewer.skill.md:45-54`

- rule: - Is -- used to terminate options when passing user-supplied paths to commands? against - Use -- before user-supplied paths in git, cp, and similar commands to prevent path injection.; - Are WORKDIR, USER, and ENTRYPOINT explicit? against :108-:110; and the eight further pairs the same two sections share.

- fault: redundant instruction -- duplication entry, ten rules each stated twice (:45/:90, :46/:91, :47/:92, :49/:97, :50/:97, :53/:99, :60/:107, :61/:105, :62/:109, :63/:108, :65/:108), once as a question and once as a standard, with unequal force and, at :47/:92 and :62/:109, unequal scope.

- recommendation: removal of the checklist copies, the standards list surviving as the single site per rule - reason: the checklist adds a question form and no rule. Mine on which form survives; the operator rules it.

**A14** `.agents/audits/kelsey-code-reviewer.skill.md:59`

- rule: - Are RUN instructions combined to minimise layers where it reduces image size?

- fault: ambiguous wording -- reading (a) every RUN is combined, since layers always cost size; reading (b) only the RUNs where a measured reduction follows, which needs a threshold the file never gives. :105 settles the single case it names and leaves the rest to the reader.

- recommendation: mine -- "RUN instructions are combined unless a split is needed for cache reuse or for a step that must stay separable; where they are split, a comment states why."

**A15** `.agents/audits/kelsey-code-reviewer.skill.md:96`

- rule: - Quote everything. The only safe unquoted expansions are arithmetic contexts and deliberate word splitting, which must be commented.

- fault: harmful instruction -- applied as written it quotes the right-hand expansion of [[ $var == $pattern ]], which makes the comparison literal and silently disables the glob match :49 asks the reviewer to keep working. The exceptions the line lists cover neither [[ ]] operands nor case patterns, so the rule's cost is a passing review of a broken match.

- recommendation: mine -- "Quote every expansion that can word-split or glob. Unquoted is correct in arithmetic contexts, in case patterns, and on the right side of a [[ ]] comparison; a deliberate unquoted expansion elsewhere is commented."

**A16** `.agents/audits/kelsey-code-reviewer.skill.md:98`

- rule: - git status --porcelain to check for changes, not multiple git diff calls with boolean flags accumulated into variables.

- fault: ambiguous wording -- reading (a) a rule about the reviewed script's own change detection, which is what the surrounding list governs; reading (b) an instruction about the reviewer's own commands, which is the only reading a reviewer can check. The line names no subject, and it is the one standard in the list carrying no reason, its rationale held only in a session that produced it.

- recommendation: mine -- "Scripts that detect working-tree changes use git status --porcelain, never git diff results accumulated into boolean flags." Subject named as the reviewed code; the operator rules which reading was meant.

**A17** `.agents/audits/kelsey-code-reviewer.skill.md:109`

- rule: - Non-root user with a fixed UID. The UID matters for volume mount ownership -- document it.

- fault: ambiguous wording -- "document it" names no site: reading (a) a comment in the Dockerfile beside the USER line, reading (b) a document outside the image. Both are actionable, and neither :36 nor :132 can tell a reviewer whether either happened.

- recommendation: mine -- "Non-root user with a fixed UID, stated in the USER line and in a comment beside it giving the UID and the volume-mount ownership it settles."

**A18** `.agents/audits/kelsey-code-reviewer.skill.md:122`

- rule: 5. **Concrete**: Every critique includes the corrected version. Don't describe the fix -- show it.

- fault: redundant instruction -- duplication entry. :132 states "Each item includes: the file and line, the failure mode, and the corrected code", and :136 states "Before/after examples for each"; the output sections are where the report is built, and the Feedback Style copy adds no scope while making an edit to either incomplete.

- recommendation: removal - the two output sections state the requirement for the sections that carry findings.

**A19** `.agents/audits/kelsey-code-reviewer.skill.md:144`

- rule: ### Refactored Version / If the code has pervasive issues, provide a complete rewrite. Partial patches on fundamentally broken code produce fundamentally broken code with patches.

- fault: harmful instruction -- "pervasive" carries no threshold, so the section is either always produced or silently skipped; and a complete rewrite is a proposal, not a finding, which the shell's contract at workflow/coding-agent/skills/code-review/SKILL.md:34 does not carry ("Suggestions go in the report and the caller applies them"). The census records the same instruction in the second carrier and calls the general statement a dedupe of two carriers.

- recommendation: mine -- "Where a finding's fix spans the whole file, say so inside that finding and give the rewritten file as a suggestion; the review rewrites nothing." Removal of the section is the alternative the operator may prefer.

**A20** `.agents/audits/kelsey-code-reviewer.skill.md:156`

- rule: If any answer is "no" or "maybe," that is a finding.

- fault: harmful instruction, as a harmful condition inside an otherwise good rule -- the five questions above it are unconditional and two of them cannot both be in scope: :150-151 ask about "this script" and :152 about "this Dockerfile". A Bash review must answer a Dockerfile question about a file it was not given, and this rule forbids "not applicable", so the review manufactures a finding from the absence of a subject.

- recommendation: mine -- "If any answer about a surface in scope is \"no\" or \"maybe,\" that is a finding; a question whose subject is not in scope is answered by naming it out of scope."

#### Arm B -- 14 faults

**B1** `.agents/audits/kelsey-code-reviewer.skill.md:3`

- rule: "description: Use this skill whenever new Bash scripts or Dockerfiles have been written or modified, ... Examples:\n\n<example>\nContext: A new entrypoint script has been written for a container."

- fault: harmful -- the frontmatter value is a YAML plain scalar carrying literal \n and repeated : , so the block does not parse: pi's own parseFrontmatter (the parser the lint gate at scripts/lint/pi-frontmatter.mjs calls) throws Nested mappings are not allowed in compact mappings at line 2, column 14, which I reproduced on this file. A skill whose frontmatter does not parse never loads, so every rule below is inert. Independently, line 3 is 1431 characters and pi's skill loader rejects a description over 1024.

- recommendation: mine -- restate as a single-line plain scalar with no : and no literal \n: description: Review a new or modified Bash script, Dockerfile, or entrypoint script against the standards in this skill. If the examples are kept, they must sit in a >- block scalar, not inline.

**B2** `.agents/audits/kelsey-code-reviewer.skill.md:4-5`

- rule: "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write" / "model: opus"

- fault: inert configuration, my naming -- pi's skill loader reads name, description and disable-model-invocation only (dist/core/skills.js), so tools, model and color constrain nothing, while model: opus restates an assignment .agents/model-recommendations.md owns ("A role with no line is refused by name, and no default model exists"). Four of the ten tool names (LS, TodoWrite, BashOutput, KillBash) name nothing this harness exposes, and search and fetch run through bash here, so the list also misdescribes the surface it sits on.

- recommendation: removal - delete model: so the role table owns the assignment, and delete tools: with it; the clause adds no constraint and four of its names address a toolset that is not here.

**B3** `.agents/audits/kelsey-code-reviewer.skill.md:22,`

- rule: "- **Self-consistent**: Patterns established in one script must be followed in all others." / "- Does every script in the codebase follow the same conventions, or has each one invented its own?"

- fault: harmful -- the skill is scoped to "new Bash scripts or Dockerfiles" (line 3), but these require a repository-wide audit the reviewer holding one file cannot perform; line 156 then makes any unanswerable check a finding, so the rule manufactures findings the reviewer cannot ground in the code in front of it.

- recommendation: mine -- "Compare the change against the conventions the scripts it sits beside already use. Report a change that breaks an established convention, and do not audit files the change does not touch."

**B4** `.agents/audits/kelsey-code-reviewer.skill.md:156`

- rule: "If any answer is "no" or "maybe," that is a finding."

- fault: ambiguous procedure -- one of the five questions it keys (line 153, "Does every script in the codebase follow the same conventions, or has each one invented its own?") is an either/or, so neither "no" nor "maybe" names its answer; and "maybe" turns the reviewer's own uncertainty into a reportable finding with no tier assigned, so it lands outside the three buckets line 121 requires.

- recommendation: mine -- "If any answer is "no," that is a finding. Where the code in front of you cannot answer a question, say which question it was and what you would need to see, and file no finding."

**B5** `.agents/audits/kelsey-code-reviewer.skill.md:30,`

- rule: "- set -euo pipefail is non-negotiable in every executable script. No exceptions." / "Sourced library files do not need set -euo pipefail themselves"

- fault: contradiction of scope, my naming -- an executable script that is sourced (lib/*.sh with a shebang and the execute bit) falls under both clauses: line 30 makes the missing flag a blocker and line 90 admits "No exceptions", while line 91 exempts the same file. The two readings return opposite verdicts on one file, and the file states no rule for which one wins.

- recommendation: mine -- at lines 30 and 45, "Missing set -euo pipefail in an executable script that is not sourced by another script"; at line 91, "A sourced library file must not set set -euo pipefail itself, and must be written to be safe when sourced by a script that does." This tightens "do not need" to a prohibition; the tightening is the point, and the operator judges it.

**B6** `.agents/audits/kelsey-code-reviewer.skill.md:47`

- rule: "- Are functions using local for all variables?"

- fault: ambiguous wording -- the checklist requires local in every function, the standard at line 92 requires it in "Every function in a library", and the blocker at line 33 names only "Functions in sourced libraries"; a helper defined in a script's own body is in scope under one site and out under the others.

- recommendation: replacement text quoted from .agents/audits/kelsey-code-reviewer.skill.md:92 -- "Every function in a library must declare all its variables local." Two of the three sites already scope the rule to libraries, and line 92 states the reason.

**B7** `.agents/audits/kelsey-code-reviewer.skill.md:97`

- rule: "Prefer [[ ]] over [ ]. Prefer $(...) over backticks. These are not style preferences -- they have different failure semantics."

- fault: ambiguous wording -- "Prefer" states a soft default and the next sentence denies the item is a preference at all; line 121 then files idiom under "style issues (should fix)", so one rule is simultaneously a preference, a non-preference and a should-fix, and the reviewer must pick a severity for a rule the file says has non-style failure semantics.

- recommendation: mine -- "Use [[ ]] instead of [ ], and $(...) instead of backticks; these have different failure semantics, so a violation is a correctness finding, not a style one."

**B8** `.agents/audits/kelsey-code-reviewer.skill.md:121,`

- rule: "Separate correctness issues (must fix) from style issues (should fix) from observations (worth knowing)."

- fault: ambiguous procedure -- the Output Format supplies a heading for the must-fix tier and the should-fix tier and none for the third: "What Works Well" (line 138) collects praise, not observations, so a reviewer holding an observation worth knowing has nowhere to put it.

- recommendation: mine -- "Put must-fix findings under ### Critical Issues, should-fix findings under ### Improvements Needed, and observations worth knowing under ### Observations, placed between those and ### What Works Well."

**B9** `.agents/audits/kelsey-code-reviewer.skill.md:30,`

- rule: "- Missing set -euo pipefail in any executable script"

- fault: redundant -- one requirement is stated as a blocker, again as a checklist question, and again as a standard with its own severity sentence; three carriers mean a later edit to one leaves two stating the retired position.

- recommendation: removal of the line 45 bullet - line 90 states the requirement and its severity ("non-negotiable ... No exceptions") and line 30 assigns it blocker status; the question at line 45 adds nothing either does not carry.

**B10** `.agents/audits/kelsey-code-reviewer.skill.md:39-66,`

- rule: "### 2. Idiomatic discipline" -- "For Bash:" / "### Review Standards -- Bash"

- fault: redundant -- the two sections own the same rules almost one-to-one (49/97 on [[ ]], 47/92 on local, 34/93 on stderr, 60/107 on COPY, 65/108 on exec form), and they have already diverged where it matters (fault 6 above); no reader can tell which section owns a rule, and no edit can be made to one without checking the other.

- recommendation: mine -- let ## Review Standards -- Bash and ## Review Standards -- Dockerfile own every rule, and reduce ## Review Process to the steps and the questions only inspection can answer, restating no rule.

**B11** `.agents/audits/kelsey-code-reviewer.skill.md:98`

- rule: "- git status --porcelain to check for changes, not multiple git diff calls with boolean flags accumulated into variables."

- fault: harmful -- it prescribes one command as a standard and gives no failure mode, and the commands are not interchangeable: a script asking whether a named path changed, or whether the index differs from HEAD, is correct with git diff --quiet and wrong with git status --porcelain, so a reviewer applying this rule files a false finding on correct code. It also breaks the file's own rule at line 120 ("Grounded: Explain the failure mode, not just the rule.") and states one repository's script convention as a universal one.

- recommendation: removal - no failure mode is stated, no failure mode follows from the rule, and the substitute it forbids is correct for the common case.

**B12** `.agents/audits/kelsey-code-reviewer.skill.md:36`

- rule: "- Commands that can fail silently (piped commands where only the last exit code is checked)"

- fault: redundant -- set -o pipefail is already mandated at line 90, so the case in the parenthetical cannot occur in a compliant script; what remains, "commands that can fail silently", is an open category with no test, listed among blockers a reviewer must scan for immediately.

- recommendation: removal - the only case it names is covered by line 90, and the general clause names no check a reviewer can run.

**B13** `.agents/audits/kelsey-code-reviewer.skill.md:46`

- rule: "- Are sourced library files structured so they are safe to source under set -euo pipefail?"

- fault: ambiguous procedure -- the question asks for a property the file never defines: which structures make a library safe to source (guarding its own option changes, not calling exit, tolerating unset variables under set -u) is left to the reviewer to invent; line 91 restates the obligation in the same words and still names no test, so two reviewers answer this differently on the same file.

- recommendation: mine -- "A sourced library must not depend on the caller's options: it must not call exit, must not change a shell option without restoring it, and must tolerate unset variables under set -u."

**B14** `.agents/audits/kelsey-code-reviewer.skill.md:59`

- rule: "- Are RUN instructions combined to minimise layers where it reduces image size?"

- fault: ambiguous procedure -- "where it reduces image size" cannot be decided without building the image, and the only cases with a determinate answer are already stated at line 61 (build dependencies cleaned in the installing layer) and line 105 (apt-get update, install and list removal in one layer); as written the question reads as a demand to merge layers generally, which defeats layer cache reuse.

- recommendation: removal - no test can be run from the source, and every case the rule decides is stated at lines 61 and 105.

### architecture-doc-reviewer.skill.md -- 166 lines

#### Arm A -- 18 faults

**A1** `.agents/audits/architecture-doc-reviewer.skill.md:15`

- rule: "These are not findings -- they are the standard you review against."

- fault: harmful -- the sentence removes the whole documentation system (folder model, ownership rules, reading-order conventions) from the reviewer's jurisdiction, and the same file then raises findings on exactly that system: "No duplicate content across documents" (line 33) is an ownership rule, and "A document that requires reading another document to understand its own core claim" (line 101) is a reading-order rule. A reviewer who reads line 15 first drops section 4's third group and section 5.

- recommendation: mine -- "These are not architecture findings -- they are the standard your architecture findings are judged against."

**A2** `.agents/audits/architecture-doc-reviewer.skill.md:25`

- rule: "- reference/ -- implementation design and decisions" and "- reference/ -- conceptual model and principles"

- fault: harmful -- "Each document belongs to exactly one category" is followed by an enumeration that gives one category name two definitions, so a concept document has no row of its own and a reviewer cannot place it. The project's own taxonomy files concept documents under docs/reference/ as a document type, not as a second folder, so the second row is not a folder distinction at all.

- recommendation: mine -- one row, "- docs/reference/ -- implementation design, decisions, and the conceptual model", replacing both.

**A3** `.agents/audits/architecture-doc-reviewer.skill.md:27`

- rule: "- operations/ -- how to run the system"

- fault: harmful -- no such folder exists in this project. The docs convention's tree is docs/reference/, docs/development/, docs/adr/ and devlog/, so a reviewer applying this row raises a finding against a folder nothing is filed in, or files a real violation under a category that cannot hold it.

- recommendation: removal -- the folder does not exist, and what the row means, "how to run the system", already sits in docs/reference/ as execution_model.md and tool_interface.md; the docs convention's ## Folder tree is the source of truth.

**A4** `.agents/audits/architecture-doc-reviewer.skill.md:21`

- rule: "The words will, plan, future, later, eventually, may support are prohibited in reference/ documents."

- fault: harmful -- a word-level prohibition fires on prose that forecasts nothing ("the teardown also prints the commands that continue the work" survives, "the plan commit type" does not), and line 41 states the same rule with the judgement attached, so two sites now disagree about what is a finding.

- recommendation: quoted from .agents/audits/architecture-doc-reviewer.skill.md:41 -- "**TODOs and speculative content are absent from reference/.** They belong in roadmap.md." The word list then has no site of its own.

**A5** `.agents/audits/architecture-doc-reviewer.skill.md:19`

- rule: "A finding is only a finding if it violates one of these, or if it reveals accidental complexity in the described architecture."

- fault: harmful -- the gate admits a violation of the standard list or accidental complexity and nothing else, while section 4 raises vagueness findings and section 5 raises cross-document consistency findings that violate neither. "A document that switches register mid-section (operator instructions inside a conceptual document)" is not in the standard list, so by line 19 it is not a finding, though section 4 and the Output Format both require it to be one.

- recommendation: mine -- "A finding is only a finding if it violates one of these, reveals accidental complexity in the described architecture, or is one of the vagueness or consistency faults sections 4 and 5 name."

**A6** `.agents/audits/architecture-doc-reviewer.skill.md:33`

- rule: "**No duplicate content across documents.** The agent-facing documents (readme.md, AGENTS.md, handover files) each answer a distinct question."

- fault: ambiguous wording -- two readings a reviewer can act on: the bold heading makes a duplicate between any two documents a violation, and the body restricts the violation to content repeated among readme.md, AGENTS.md and handover files. A sentence repeated between two docs/reference/ documents is a violation under the first reading and permitted under the second.

- recommendation: mine -- narrow the heading to its body: "**No duplicate content across the agent-facing documents.**"

**A7** `.agents/audits/architecture-doc-reviewer.skill.md:35`

- rule: "Stable documents do not reference volatile ones."

- fault: ambiguous wording -- "reference" reads as either a link or a mention, and the two readings give opposite verdicts on a case the linking convention requires: "A documentation or policy document links the ADR that records the fact, and the ADR links the handover that evidences it" is a durable document pointing at a transient one, which this line forbids.

- recommendation: quoted from .agents/skills/linking/SKILL.md ## What to link -- "Name transient evidence. A handover, a discussion page and a session export are named in a code span and never linked."

**A8** `.agents/audits/architecture-doc-reviewer.skill.md:35`

- rule: "Lower layers do not reference higher ones."

- fault: ambiguous wording -- in this project "layer" is the implementation stack (system_overview.md: Layer 0 Infrastructure, Layer 1 Execution Mechanics, Layer 2 Orchestration), and read that way the rule tells a reviewer to check a docs/reference/ document for naming a higher stack layer, which no document property supports. Read as document layers, the term is defined nowhere in the file.

- recommendation: removal -- the term is undefined in this surface, and what a document may point at is already the linking convention's (## What to link, ## Where the link is read); a finding the reviewer cannot evaluate is not a rule.

**A9** `.agents/audits/architecture-doc-reviewer.skill.md:41`

- rule: "The judgement is the communication-principle-dont-forecast-undone-work skill at $AGENT_HOME/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md."

- fault: ambiguous wording -- a repo-side file, in a directory the surface-area-report.md calls "repo-side only", points at a machine-local path, so a reader of the repository cannot open the skill the rule names, and the copy it points at is an installed copy of a file the repository holds.

- recommendation: quoted from /home/agentuser/sandbox/AGENTS.md ## Model Recommendations -- "src/reasoning/providers/pi/config/agent/skills/<name>/SKILL.md, the one root that carries them".

**A10** `.agents/audits/architecture-doc-reviewer.skill.md:60`

- rule: "- The layer freeze status in system_overview.md -- is this document marked as frozen but contains content that post-dates its freeze milestone?"

- fault: harmful -- it asks for a per-document freeze mark that cannot exist: system_overview.md states "The freeze status is layer-scoped (a whole layer freezes, never an individual file)", and line 39 of this file says architecture and concept documents carry no status header. The reviewer looks for a mark it will never find and the document passes by default, which is the failure the check exists to catch.

- recommendation: mine -- "is this document in a frozen layer, and does it describe work that post-dates that layer's freeze milestone?"

**A11** `.agents/audits/architecture-doc-reviewer.skill.md:61`

- rule: "- The active handover (YYYYMMDD-NN-*.md) -- for a closed iteration, does a document named in the Completed section show no sign of a recent update?"

- fault: ambiguous wording -- "the active handover" names no location, and the records sit under devlog/handovers/, which the line does not state; the glob also drops the shortform the work-log convention fixes (YYYYMMDD-NN-<shortform>-<slug>.md), so a reviewer cannot resolve the site to a file.

- recommendation: mine -- "The active handover under devlog/handovers/, the record with the highest date and index (YYYYMMDD-NN-*.md) -- for a closed iteration, does a document named in the Completed section show no sign of a recent update?"

**A12** `.agents/audits/architecture-doc-reviewer.skill.md:70`

- rule: "Document that explains it in a paragraph is evidence of simplicity."

- fault: ambiguous wording -- the sentence is missing its article and its predicate range, so every document satisfies it: any document that contains any one paragraph "explains it in a paragraph". The intended reading is that the explanation of the whole model fits in one paragraph, and nothing in the line says so.

- recommendation: mine -- "A document whose whole explanation of it fits in one paragraph is evidence of simplicity."

**A13** `.agents/audits/architecture-doc-reviewer.skill.md:116`

- rule: "The decision not to use git bundle is recorded with its reason, which is worth preserving."

- fault: my own naming -- a stale premise, on the model of a pointer whose target no longer states what the citing line claims. execution_model.md records the seed as the one-shot helper-container copy and carries no git bundle decision; the rejection survives only in devlog/discussions/archive/20260309-design-active-sandbox_file_isolation.md ### Rejected approach: git bundle. The calibration point therefore holds a reviewer to a claim about a named document that the document does not hold, and a reviewer who checks it reports the exemplar as failing the standard it exemplifies.

- recommendation: removal of that clause -- "describes the current container lifecycle, mount shape, and snapshot pipeline in terms of what the system does, with implementation decisions recorded alongside the design they produced. No future language. No aspirational components." carries the calibration on its own.

**A14** `.agents/audits/architecture-doc-reviewer.skill.md:120`

- rule: "An investigation marked In progress with no open questions recorded is stale."

- fault: harmful -- In progress is not a status in this project's vocabulary, which is draft, active, settled, superseded, rejected, archived, in the filename and in the **Status:** line alike. The check matches no record, so a stalled active investigation passes, which is the state the calibration point is there to catch.

- recommendation: mine -- "An investigation marked active with no open questions recorded is stale."

**A15** `.agents/audits/architecture-doc-reviewer.skill.md:130`

- rule: "5. **Do not recommend adding more documentation to fix a complexity problem.** More words on a hard concept is usually the wrong answer. The right answer is to ask whether the concept itself needs simplifying."

- fault: redundant -- third site of one rule. Section 3 states it where the reviewer applies it, at line 74: "Do not recommend adding more explanation -- recommend surfacing the underlying design question", and the Output Format states it where the reviewer writes the finding, at line 144: "Not documentation fixes -- these are questions for the operator". A change to the rule now has three sites to land in.

- recommendation: removal -- both other sites state it where the reviewer acts on it, and the four remaining feedback rules lose nothing.

**A16** `.agents/audits/architecture-doc-reviewer.skill.md:122`

- rule: "**The document that is hard to write is the signal.** If a document about a simple mechanism requires four paragraphs of context before the mechanism can be stated, the architecture may have complected something. Surface this as a design question, not a documentation failure."

- fault: redundant -- the rule is stated at line 13 ("Difficulty of explanation is a signal, not just a symptom") and again at line 74, and this third site puts a procedure inside ## What Good Documentation Looks Like Here, whose own opening says "Use these as your calibration points, not as a checklist to tick off": a reader there is matching a named document, not learning a step.

- recommendation: removal -- the rule holds at both earlier sites, and the section keeps its four named exemplars.

**A17** `.agents/audits/architecture-doc-reviewer.skill.md:148`

- rule: "Scope, vagueness, and consistency issues that should be fixed. Specific before/after examples where the fix is a documentation edit."

- fault: ambiguous procedure -- a cross-document inconsistency has two homes and the file assigns neither. Line 140 puts "cross-document inconsistencies that must be fixed" under Critical Findings; line 148 puts "consistency issues" under Improvements Needed. A reviewer walking the Output Format stops at the first ambiguity, and either writes the finding twice or drops it.

- recommendation: mine -- "Scope and vagueness issues that should be fixed. Specific before/after examples where the fix is a documentation edit." Consistency stays at line 140 with staleness and policy violations.

**A18** `.agents/audits/architecture-doc-reviewer.skill.md:4`

- rule: "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write" / "model: opus" / "color: purple"

- fault: harmful -- the list grants Write to a procedure whose job is to report and whose fifth feedback rule forbids adding documentation to fix a complexity problem, so the reviewer can repair the surface it is auditing instead of reporting on it; most of the other names (TodoWrite, KillBash, BashOutput, LS, WebFetch) are not tools this harness provides, so the grant describes a runtime the file does not run in; and model: opus pins an assignment for an audit the project dispatches through its role table, where AGENTS.md states "The role table wins."

- recommendation: mine -- drop tools, model and color, leaving name and description, since a read-only operator-invoked audit declares neither a tool grant nor a model pin and takes its assignment from .agents/model-recommendations.md.

#### Arm B -- 15 faults

**B1** `.agents/audits/architecture-doc-reviewer.skill.md:4-6`

- rule: "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write" / "model: opus" / "color: purple"

- fault: harmful -- these are Claude agent-definition fields, not pi skill frontmatter: the tool names do not exist in this runtime, and model: opus pins a model in the file, which pre-empts the role-table resolution every dispatch here goes through (.agents/model-recommendations.md). The file therefore cannot load as a pi skill, so none of its rules is reachable. The description line carries literal \n escapes rather than newlines, for the same reason.

- recommendation: removal - the same defect is already recorded by this repository: "But it is a Claude-format import: YAML frontmatter (tools:, model: opus), Claude tool names (Glob, WebFetch, TodoWrite), and <example> blocks. It cannot load as a pi skill." (.agents/audits/documentation-audit-comparison.md:46).

**B2** `.agents/audits/architecture-doc-reviewer.skill.md:4`

- rule: "tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write"

- fault: harmful -- Write (with BashOutput, KillBash) grants a review run the power to edit the very documents it is auditing, so a finding and the change that hides it can arrive in one pass with no attribution.

- recommendation: removal - this project's review rule is "A reviewer is a delegated read-only run. It edits nothing, commits nothing and runs no suite, so the caller applies what the report names." (provider-layer AGENTS.md, ## Running Review Subagents).

**B3** `.agents/audits/architecture-doc-reviewer.skill.md:15`

- rule: "**One critical calibration:** Hickey's complexity lens is applied to the *architecture being described*, not to the documentation system itself. This project has an explicit folder model, document ownership rules, and reading-order conventions. These are not findings -- they are the standard you review against."

- fault: contradiction -- "These are not findings" forbids reporting a violation of the folder model and the ownership rules, while the section it introduces makes exactly those violations reportable: "Folder ownership is strict" (:23), "No bridge documents" (:31), "Changes that cross layer boundaries without milestone justification are findings" (:37). A reviewer cannot tell whether a misplaced document is a finding or a calibration error.

- recommendation: (mine) "The folder model and the ownership rules are the standard, not the subject: a document that violates one of them is a finding, and the convention that states the rule is not itself open to review."

**B4** `.agents/audits/architecture-doc-reviewer.skill.md:15`

- rule: "This project has an explicit folder model, document ownership rules, and reading-order conventions."

- fault: ambiguous wording -- no document in the tree states a reading-order convention (grep -rn "reading-order\|reading order" docs/ .agents/skills/ returns nothing). The reviewer is told to enforce a standard it cannot look up, so the clause only supplies confidence.

- recommendation: removal - the two conventions that do exist, the folder tree and the header rules, are named by .agents/skills/docs/SKILL.md (## Folder tree, ## How a document opens), and the third has no source to point at.

**B5** `.agents/audits/architecture-doc-reviewer.skill.md:19`

- rule: "This project's documentation policy establishes the following rules."

- fault: ambiguous wording plus duplication -- the authority is named but not identified: there is no documentation_policy.md in docs/development/ or anywhere else in the tree, and the rules that follow are a restatement of .agents/skills/docs/SKILL.md and .agents/skills/linking/SKILL.md in different words. A reader who finds the copy stale has no original to check it against, and the copy silently wins on any divergence.

- recommendation: (mine) "The rules below are the docs and linking conventions', restated only to name what a finding violates; where this file and a convention differ, the convention wins."

**B6** `.agents/audits/architecture-doc-reviewer.skill.md:25-26`

- rule: "- reference/ -- implementation design and decisions" / "- reference/ -- conceptual model and principles"

- fault: ambiguous wording -- the rule directly above says "Each document belongs to exactly one category" (:23), and the list gives the same folder twice with two different holdings, so the category of a conceptual document is undecidable and one of the two intended folders is never named. The tree has no separate concepts folder; concepts live under docs/reference/.

- recommendation: replacement text quoted from the convention that owns the tree, .agents/skills/docs/SKILL.md ## Folder tree: "docs/reference/ | how the harness works: contracts, states and sequences, the glossary" and "docs/development/ | contributor workflow and the procedures for changing the harness".

**B7** `.agents/audits/architecture-doc-reviewer.skill.md:27,29`

- rule: "- operations/ -- how to run the system" / "- discussions/ -- investigation and story documents; reasoning records only, not current system description"

- fault: harmful -- neither folder exists. There is no docs/operations/; run instructions sit in docs/development/ and devlog/, and discussion records are devlog/discussions/. A reviewer following the list searches for two directories it will not find, and every document outside docs/{reference,development,adr} falls outside the category set, so its ownership cannot be checked at all.

- recommendation: replacement text quoted from .agents/skills/docs/SKILL.md ## Folder tree: "devlog/ | the roadmap, the changelog, the handovers and the discussion records" and "docs/adr/ | settled decisions, with superseded ones under adr/archive/".

**B8** `.agents/audits/architecture-doc-reviewer.skill.md:21`

- rule: "The words will, plan, future, later, eventually, may support are prohibited in reference/ documents."

- fault: harmful -- a token ban replaces the judgement it stands for. "Will" and "plan" occur in quoted policy, in a named artefact, and in a sentence that describes the present ("the plan is applied at start-up"), so a reviewer applying the rule literally reports clean text and, applying it as a judgement, has no rule left. The change being described is whether a document describes current reality, and no list of words decides that.

- recommendation: replacement text quoted from the same file, .agents/audits/architecture-doc-reviewer.skill.md:41: "The judgement is the communication-principle-dont-forecast-undone-work skill at $AGENT_HOME/agent/skills/communication-principle-dont-forecast-undone-work/SKILL.md."

**B9** `.agents/audits/architecture-doc-reviewer.skill.md:41`

- rule: "They belong in roadmap.md."

- fault: redundant -- the rule above it opens with the same requirement in the same words: "Future work belongs in roadmap.md." (:21). Two statements of one rule in one section, which is the class of defect this section's own "No duplicate content across documents" (:33) exists to catch.

- recommendation: removal - the requirement is stated at :21, and the pointer sentence that follows at :41 is the part that adds something.

**B10** `.agents/audits/architecture-doc-reviewer.skill.md:33`

- rule: "**No duplicate content across documents.** The agent-facing documents (readme.md, AGENTS.md, handover files) each answer a distinct question. Content that appears in more than one of them is a violation."

- fault: ambiguous wording -- the heading scopes the rule to all documents while the body scopes it to three named files, and those three sit in three different trees (root, root, devlog/handovers/). A reviewer cannot decide whether duplication between two docs/reference/ documents is a finding, which is the case the rule is presumably for.

- recommendation: (mine) "No rule is stated twice. Across the document set, each document answers a question no other document answers; readme.md, AGENTS.md and devlog/handovers/ are where a second copy most often appears."

**B11** `.agents/audits/architecture-doc-reviewer.skill.md:59`

- rule: "- The milestone history in changelog.md -- has a milestone completed that should have updated this document?"

- fault: ambiguous wording -- the file names five targets without a folder (changelog.md :59, system_overview.md :60, roadmap.md :21, execution_model.md and two_layer_model.md :116-118), and none of them resolves from the repository root: changelog.md is at devlog/changelog.md, system_overview.md at docs/reference/system_overview.md. A Read or Grep on the name as written fails, which reads as "the document is missing".

- recommendation: (mine) name each target by path: devlog/changelog.md, docs/reference/system_overview.md, devlog/roadmap.md, docs/reference/execution_model.md, docs/reference/two_layer_model.md.

**B12** `.agents/audits/architecture-doc-reviewer.skill.md:66`

- rule: "### 3. Complexity audit -- is this hard to explain because the design is hard, or because the design is wrong?"

- fault: ambiguous wording -- "wrong" is not the distinction the section makes. The body separates complexity the problem demands from complexity the design introduced (:70, :72) and asks for a design question to be surfaced, not for a verdict that the design is wrong. A reviewer reading the heading looks for a defect, and the honest answer to most findings is "the problem demands it".

- recommendation: replacement text quoted from the same file, .agents/audits/architecture-doc-reviewer.skill.md:13: "complexity in the documented architecture is either essential (the problem demands it) or accidental (the design introduced it)".

**B13** `.agents/audits/architecture-doc-reviewer.skill.md:74,130`

- rule: "Do not recommend adding more explanation -- recommend surfacing the underlying design question." (:74) and "**Do not recommend adding more documentation to fix a complexity problem.**" (:130)

- fault: redundant -- one prohibition stated in the method and again in the feedback style, with slightly different objects ("more explanation" / "more documentation"), so a reader must decide whether the two bind the same case.

- recommendation: removal of the sentence at :130 - :74 states it where the reviewer acts on it, and :130's remaining sentences name the consequence and the alternative.

**B14** `.agents/audits/architecture-doc-reviewer.skill.md:126`

- rule: "1. **Distinguish finding types explicitly.** Staleness, scope violation, policy violation, accidental complexity, and vagueness are different problems requiring different fixes. Do not group them."

- fault: contradiction -- "Do not group them" is contradicted by the output contract it feeds, where one section gathers three of those types: "Staleness, policy violations, and cross-document inconsistencies that must be fixed" (:140). A reviewer who separates the five types has nowhere to put a scope violation under the heading that takes it, and a reviewer who follows the output format has broken the feedback rule.

- recommendation: (mine) replace "Do not group them" with "Each finding names its type, in the parentheses after the quoted text." and let the output sections group types as they do.

**B15** `.agents/audits/architecture-doc-reviewer.skill.md:164`

- rule: "If any answer is "no" or "not sure," that is a finding."

- fault: harmful -- the answers are not uniformly polar. Four questions at :158-161 fail on "no", but "Is there any content here that belongs in roadmap.md but has not made it there?" (:162) fails on "yes", so the rule inverts: a clean document answers "no" and is scored as a finding, and a document carrying stray roadmap content answers "yes" and passes.

- recommendation: (mine) restate :162 with the polarity of the rest: "Does any content here belong in devlog/roadmap.md, and is it there?" and keep the uniform "no or not sure is a finding".

### dhh-code-audit.skill.md -- 99 lines

#### Arm A -- 20 faults

**A1** `.agents/audits/dhh-code-audit.skill.md:2`

- rule: name: dhh-code-reviewer

- fault: ambiguous wording -- one artifact carries two names, the frontmatter name dhh-code-reviewer and the path .agents/audits/dhh-code-audit.skill.md; a reader arriving through the shell's table (workflow/coding-agent/skills/code-review/SKILL.md:55) looks for dhh-code-audit and finds a file that answers to another name. Recorded as a contradiction at .agents/audits/surface-area-report.md:39.

- recommendation: replacement, marked mine: name: dhh-code-audit -- the file's own stem, which is the string the surface is cited by everywhere else.

**A2** `.agents/audits/dhh-code-audit.skill.md:3`

- rule: description: Use this agent whenever new code has been written by yourself or a sub-agent, ... Examples: followed by literal \n escapes and two <example> openers against one closer.

- fault: harmful -- the block does not parse. A run entry: pi's own frontmatter parser (dist/utils/frontmatter.js, the one scripts/lint/pi-frontmatter.mjs calls) throws YAMLParseError: Nested mappings are not allowed in compact mappings on this field, so pi reads no name and no description at all and the file loses its trigger. The same defect class as the failure recorded at devlog/AGENT_FEEDBACK.md:192, where a colon-space in a description made pi drop a skill.

- recommendation: replacement, quoted from the same line: Use this agent whenever new code has been written by yourself or a sub-agent, to review Ruby or JavaScript code against David Heinemeier Hansson's (DHH) exacting standards for code quality, as exemplified in the Rails and Hotwire codebases. -- the escaped example blocks are loader scaffolding, and one of the two <example> blocks is unclosed.

**A3** `.agents/audits/dhh-code-audit.skill.md:3`

- rule: This agent should always be invoked after writing or modifying Ruby/Rails and Javascript/Svelte code

- fault: harmful -- an unconditional invocation trigger with no scope accepted and no bounded subject. A conflict entry: the shell accepts a payload only once it names a scope, because "it names no scope, so there is nothing to dispatch" (workflow/coding-agent/skills/code-review/SKILL.md:50). The disposition record also reads "no Ruby or JavaScript in this repo" (.agents/audits/surface-area-report.md:29, devlog/roadmap.md:163), and no .rb, .svelte or .js file is tracked.

- recommendation: removal - a dispatcher routes on a named scope, and this trigger makes every code-writing turn claim a subject this repository does not have.

**A4** `.agents/audits/dhh-code-audit.skill.md:4`

- rule: tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write

- fault: harmful -- the field names tools that do not exist in this runtime (LS, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash), which the surface report records as the reason these files "were never deployable as pi skills" (.agents/audits/surface-area-report.md:35); it also names Write, which a review seat must not hold, since "Suggestions go in the report and the caller applies them" (workflow/coding-agent/skills/code-review/SKILL.md:34), and the template states "A runbook names no model, role, provider, seat count, path or tool" (docs/reference/review_runbook_template.md:21).

- recommendation: removal - the seat's toolset is the shell's to state, not the runbook's.

**A5** `.agents/audits/dhh-code-audit.skill.md:5`

- rule: model: opus

- fault: harmful -- a conflict entry: the template states "A runbook names no model, role, provider, seat count, path or tool" (docs/reference/review_runbook_template.md:21) and the shell states "A runbook never names a model, a role or a count" (workflow/coding-agent/skills/code-review/SKILL.md:32); the assignment comes from the role table, so a model named here is either ignored or overrides the resolver.

- recommendation: removal - the assignment is resolved per role at dispatch, and a literal model in the runbook defeats that single source.

**A6** `.agents/audits/dhh-code-audit.skill.md:6`

- rule: color: red

- fault: unread field, named by me -- no reader in this repository or in pi's skill loader consumes it; dist/core/skills.js reads only frontmatter.name and frontmatter.description, and no gate reads the others. The register is empty, which is itself the finding, and the census records it as the frontmatter field both arms missed (devlog/handovers/20261026-04-workflow-corpus_census.md, Findings).

- recommendation: removal - it is a Claude interface setting with no consumer here, and an unread field costs every later editor a decision about whether it matters.

**A7** `.agents/audits/dhh-code-audit.skill.md:9`

- rule: You are an elite code reviewer channeling the exacting standards and philosophy of David Heinemeier Hansson (DHH), creator of Ruby on Rails and the Hotwire framework.

- fault: harmful -- a persona, not an instruction: it supplies judgement the rules do not state, so a finding can come from the character rather than from a checkable rule. A ruling entry settles the handling: "A persona gets no eval arm and ships absent" (devlog/handovers/20261026-04-workflow-corpus_census.md:45), with the corpus finding that the persona carriers "failed as prose" (same file, Findings).

- recommendation: removal - the standard the reviewer judges against is the runbook's; a persona adds an unowned judge beside it.

**A8** `.agents/audits/dhh-code-audit.skill.md:20;`

- rule: **Self-documenting**: Comments are a code smell and should be avoided and Redundant comments

- fault: redundant instruction -- the two sites state different rules over one subject: line 20 bans comments outright, line 29 flags only the redundant ones, which permits the rest. A conflict entry with the project's own rule: "Comments must describe what the code does or why -- never that it was changed" (AGENTS.md:140), which line 20 forbids.

- recommendation: removal - line 20 is the site the project contradicts; the narrower check at line 29 is consistent with AGENTS.md:140 and survives.

**A9** `.agents/audits/dhh-code-audit.skill.md:24`

- rule: **Initial Assessment**: Scan the code for immediate red flags:

- fault: ambiguous procedure -- walk the steps in order: step 1 says to scan "the code", and no step, slot or definition says which code, which revision, or what a seat handed a diff should read; the first step stops there. A conflict entry: a payload that "names no scope" has "nothing to dispatch" (workflow/coding-agent/skills/code-review/SKILL.md:50), and the template's first slot is "Scope accepted" (docs/reference/review_runbook_template.md:13).

- recommendation: replacement, quoted from workflow/coding-agent/skills/code-review/SKILL.md:44: a delta: the branch's changes, read as a diff -- stated as the scope accepted, before step 1.

**A10** `.agents/audits/dhh-code-audit.skill.md:26;`

- rule: Violations of Rails conventions and Use Rails' built-in methods and conventions (scopes, callbacks, concerns)

- fault: redundant instruction -- one requirement at two sites: the scan flags violations of the conventions and the standard names the same conventions, so a change to which conventions count must land in both.

- recommendation: removal - line 26 repeats the scan entry line 49 already states with the conventions named; the scan list does not need its own copy.

**A11** `.agents/audits/dhh-code-audit.skill.md:32`

- rule: **Convention over Configuration**: Is the code fighting Rails/Inertia/Svelte or flowing with it?

- fault: ambiguous wording -- Inertia is named once in the surface, defined nowhere, and is the only framework in that sentence that no later rule addresses; one reading takes it as a subject to check alongside Rails and Svelte, the other as an incidental mention, and the two dispatch different scopes.

- recommendation: replacement, marked mine: **Convention over Configuration**: Is the code fighting Rails or Svelte, or flowing with it? -- the surface defines rules for those two and for neither Inertia nor Hotwire.

**A12** `.agents/audits/dhh-code-audit.skill.md:36;`

- rule: **No One Paradigm**: Is the solution appropriately object-oriented, functional, or procedural for the context? and Prefer declarative over imperative style

- fault: redundant instruction -- a conflict entry: one rule refuses any paradigm preference in favour of the context, the other installs a preference that survives no context test, so a reviewer follows one and violates the other.

- recommendation: replacement, marked mine, for the second site: Prefer declarative over imperative style, unless the context the first rule asks for is procedural. -- keeps the default and makes it yield to the general rule.

**A13** `.agents/audits/dhh-code-audit.skill.md:41;`

- rule: Is it the kind of code that would appear in a Rails guide as an exemplar? and If the code wouldn't make it into Rails core or wouldn't be used as an example in Rails documentation, it needs improvement.

- fault: harmful -- the bar admits no passing diff, so "it needs improvement" is asserted for every real change without evidence for that finding, which the honesty standard forbids: "A claim about an unobservable state is an inference and is marked as one" (provider-layer AGENTS.md, Communication Standards). The same bar is stated a third time at line 39. No failure entry records it; the harm is visible in the rule itself.

- recommendation: removal - a review whose verdict cannot be reached on a real diff reports a finding it cannot support.

**A14** `.agents/audits/dhh-code-audit.skill.md:42`

- rule: Would DHH himself write it this way?

- fault: ambiguous wording -- a counterfactual about code a named person has not written; the reading "would DHH accept this" collapses into the Rails-core question at line 39, and the reading "would his style produce this" has no observable. Code that doesn't "feel" like it belongs in Rails core (line 28) and Does this code spark joy or dread? (line 33) are the same test in other words, and the quotation marks at line 28 mark the author's own doubt about it.

- recommendation: removal - it adds no checkable distinction to the Rails-core question that precedes it, and its two nearest copies go with it.

**A15** `.agents/audits/dhh-code-audit.skill.md:48`

- rule: Leverage Ruby's expressiveness: prefer \unless\ over \if !\, use trailing conditionals appropriately

- fault: harmful condition inside a sound rule -- "prefer unless over if !" is unqualified, while unless with an else branch or a compound condition is harder to read than the negated if; a reviewer following the rule literally asks for worse code in exactly those cases. Empty register: no record on this surface states the qualification.

- recommendation: replacement, marked mine: Leverage Ruby's expressiveness: prefer \unless\ over \if !\; keep it to a single condition with no \else\. -- the qualification the literal rule is missing.

**A16** `.agents/audits/dhh-code-audit.skill.md:58`

- rule: Does the DOM seem to be fighting the code, or is the code driving the DOM?

- fault: ambiguous wording -- "seem to be fighting" names no observable, and the two readings (direct node manipulation in a lifecycle hook, versus state that Svelte fails to propagate) lead to different findings from the same code.

- recommendation: replacement, marked mine: Does the code change state and let Svelte update the DOM, or does it read and write DOM nodes directly? -- the observable the question is reaching for.

**A17** `.agents/audits/dhh-code-audit.skill.md:59`

- rule: Does the code follow known, best practices for Svelte 5?

- fault: ambiguous wording -- "known" by whom, and which set: the surface names no source and no list, the repository tracks no Svelte code, and the disposition record puts Svelte outside this codebase's subject (.agents/audits/surface-area-report.md:29). Two readings: the reviewer's recollection, or a documented set a reader could open; the file supplies neither.

- recommendation: removal - as written the question cannot be answered from the surface, and a pointer to a named set is the coverage gap to file rather than a rule to keep.

**A18** `.agents/audits/dhh-code-audit.skill.md:69;`

- rule: **Constructive**: Always show the path to improvement with specific examples. and **Actionable**: Provide concrete refactoring suggestions with code examples.

- fault: redundant instruction -- one requirement at two adjacent bullets: each demands that a finding carry the corrected code, so a change to what "specific examples" means must land in both.

- recommendation: removal of line 69 - line 71 names the deliverable ("concrete refactoring suggestions with code examples"), and the two bullets are otherwise one rule with a synonym for a title.

**A19** `.agents/audits/dhh-code-audit.skill.md:75`

- rule: Structure your review as: with ### Overall Assessment, ### Critical Issues, ### Improvements Needed, ### What Works Well, ### Refactored Version

- fault: redundant instruction -- a duplication entry: the same five sections, in the same order, stand at .agents/audits/kelsey-code-reviewer.skill.md:124-142, and the census records them as one statement carried twice and assigns the general plane one home (devlog/handovers/20261026-04-workflow-corpus_census.md:64 and the decision at line 47).

- recommendation: removal of the section set here - the shared body is the shell's and one copy is enough; the block's ### Refactored Version slot is raised separately below.

**A20** `.agents/audits/dhh-code-audit.skill.md:95`

- rule: [If the code needs significant work, provide a complete rewrite that would be Rails-worthy]

- fault: harmful -- a conflict entry: it instructs the seat to produce a rewritten tree, where the shell gives the seat "the read and inspection tools" and holds that "Suggestions go in the report and the caller applies them" (workflow/coding-agent/skills/code-review/SKILL.md:34). A review that rewrites is not attributable to one revision, which is the property the shell's dirty-tree refusal protects (...:33).

- recommendation: replacement, quoted from workflow/coding-agent/skills/code-review/SKILL.md:34: Suggestions go in the report and the caller applies them -- stated in that section's place.

#### Arm B -- 24 faults

**B1** `.agents/audits/dhh-code-audit.skill.md:2`

- rule: name: dhh-code-reviewer

- fault: identity mismatch (my own naming) -- the file is dhh-code-audit.skill.md, the description calls the thing an agent, and the body calls it a reviewer; the name a dispatcher resolves matches neither the filename nor the file's own vocabulary, so a caller cannot tell whether this is an audit or a reviewer.

- recommendation: my own text -- name: dhh-code-audit, and the description's "agent" replaced with the word the file's own name uses.

**B2** `.agents/audits/dhh-code-audit.skill.md:3`

- rule: Use this agent whenever new code has been written by yourself or a sub-agent

- fault: redundant -- the invocation trigger is stated three times in the description alone ("whenever new code has been written", "should always be invoked after writing or modifying"), then a fourth and fifth time in the two <example> blocks.

- recommendation: removal - keep one trigger sentence and delete the rest; a repetition of the trigger cannot strengthen it, only date it.

**B3** `.agents/audits/dhh-code-audit.skill.md:3`

- rule: whenever new code has been written by yourself or a sub-agent

- fault: harmful -- it instructs a reviewer to review its own writes, and this repository's _REVIEWER seat is a read-only delegated run that by construction did not write the code it reads; the clause invites a self-approving pass, which is the one review whose finding is worthless.

- recommendation: removal of "by yourself" - keep "by a sub-agent", or name the author as a separate party.

**B4** `.agents/audits/dhh-code-audit.skill.md:3`

- rule: Examples:\n\n<example>\n\n<example>

- fault: malformed structure (my own naming) -- </example> is written once while <example> is opened twice, so the second example is unterminated; a downstream parser that splits on the tag pair produces one example and a truncated remainder.

- recommendation: removal of the second, empty <example> opening tag.

**B5** `.agents/audits/dhh-code-audit.skill.md:4`

- rule: tools: Glob, Grep, LS, Read, WebFetch, TodoWrite, WebSearch, BashOutput, KillBash, Write

- fault: harmful -- a review seat is granted Write and KillBash, so the pass that judges the tree can also mutate or terminate the tree it judges; the evaluated artifact and the evidence about it stop being the same artifact.

- recommendation: removal - reduce to the read capabilities the procedure actually needs.

**B6** `.agents/audits/dhh-code-audit.skill.md:5`

- rule: model: opus

- fault: harmful -- pins an assignment inside the instruction surface, which contradicts this repository's rule that a dispatch resolves its model from the role table and that "the role table wins"; a pinned model here cannot be cooled, rotated or re-routed when its route cannot answer, and the operator loses the one place they edit to change it.

- recommendation: removal - the role table at .agents/model-recommendations.md owns the assignment.

**B7** `.agents/audits/dhh-code-audit.skill.md:9`

- rule: You evaluate Ruby and JavaScript code (whether Rails or Svelte) against the same rigorous criteria used for the Rails and Hotwire codebases themselves.

- fault: unspecified input (my own naming) -- this is the file's only scope-bearing sentence and it names a language, not an artifact; the procedure never says whether the reviewer reads the working tree, the uncommitted diff, or the iteration's commits, so two reviewers on the same change can legitimately review different code.

- recommendation: my own text -- state the artifact the review reads, at the top of ## Your Review Process.

**B8** `.agents/audits/dhh-code-audit.skill.md:9`

- rule: You are an elite code reviewer channeling the exacting standards and philosophy of David Heinemeier Hansson (DHH), creator of Ruby on Rails and the Hotwire framework.

- fault: redundant -- persona framing that restates the description and states no rule a reviewer can apply; "elite" and "channeling" change no decision the procedure makes.

- recommendation: removal - the standards sections that follow are the substance; the self-description adds no check.

**B9** `.agents/audits/dhh-code-audit.skill.md:15`

- rule: **DRY (Don't Repeat Yourself)**: Ruthlessly eliminate duplication

- fault: ambiguous wording -- "ruthlessly" and "eliminate" place no bound on the rule, so it fires against two similar lines anywhere and never against the cost of the abstraction introduced to remove them; it also states, unbounded, what line 62 states with a bound.

- recommendation: replace with the text at .agents/audits/dhh-code-audit.skill.md:62 -- Is there repeated boilerplate that could be extracted into a component, or a function?

**B10** `.agents/audits/dhh-code-audit.skill.md:20`

- rule: **Self-documenting**: Comments are a code smell and should be avoided

- fault: harmful -- forbids all comments, while the project layer requires them: Comments must describe what the code does or why (.agents/audits/../AGENTS.md:140); a reviewer applying line 20 deletes the why-comments this repository mandates, and does so as a "fix".

- recommendation: removal - line 29 Redundant comments already states the defensible, narrower version of the same check.

**B11** `.agents/audits/dhh-code-audit.skill.md:27`

- rule: Non-idiomatic Ruby or JavaScript patterns

- fault: redundant -- this red-flag line is restated twice below it, as Is there repeated boilerplate that could be extracted into a component, or a function? (:62) and as the third and fourth bullets of the JavaScript section (:60-61); without a cited source for "idiomatic" it also cannot be resolved where it stands.

- recommendation: removal, and let the section that names the library (:61) carry the ideomaticism check.

**B12** `.agents/audits/dhh-code-audit.skill.md:32`

- rule: **Convention over Configuration**: Is the code fighting Rails/Inertia/Svelte or flowing with it?

- fault: dangling reference (my own naming) -- Inertia is named here and nowhere else in the file: not in the description, not in the introduction, and in neither language standard; a reviewer is told to test whether code fights Inertia while the surface supplies no Inertia standard to test against.

- recommendation: removal of Inertia - the term a reviewer cannot resolve is a rule it cannot apply.

**B13** `.agents/audits/dhh-code-audit.skill.md:33`

- rule: **Programmer Happiness**: Does this code spark joy or dread?

- fault: cannot be acted on -- the criterion is a feeling about the code, not a property of it, and the file supplies no observable proxy; two reviewers on the same file reach opposite verdicts and neither is wrong by the rule.

- recommendation: removal - a criterion no reader can apply makes the review's verdict unattributable.

**B14** `.agents/audits/dhh-code-audit.skill.md:34`

- rule: **Conceptual Compression**: Are the right abstractions in place?

- fault: ambiguous wording -- the label is never defined and its gloss restates it ("right abstractions" is the term again); a reviewer holds a question with no test, and the check it seems to want is the extraction question already written at :62.

- recommendation: removal - it duplicates :62 while adding a term the file never defines.

**B15** `.agents/audits/dhh-code-audit.skill.md:35`

- rule: **The Menu is Omakase**: Does it follow Rails' opinionated path?

- fault: redundant -- this asks exactly what line 32 asks, "does the code follow Rails' opinionated path", under a second metaphor drawn from a restaurant menu; the metaphor also names nothing a reviewer can look up.

- recommendation: removal - one opinionated-path check is enough, and line 32 states it in the domain's own words.

**B16** `.agents/audits/dhh-code-audit.skill.md:39`

- rule: Would this code be accepted into Rails core?

- fault: harmful -- the file declares JavaScript/Svelte code in scope (:9) and then makes the Rails-core criterion, together with "would appear in a Rails guide as an exemplar" (:41) and "Would DHH himself write it this way?" (:42), the test for all of it; a Svelte component can only fail a question about Rails core, so the section's verdict is fixed before the code is read.

- recommendation: my own text -- restrict the Rails-Worthiness Test to ### For Ruby/Rails Code, and state separately what stands in for it in the Svelte section.

**B17** `.agents/audits/dhh-code-audit.skill.md:50`

- rule: Prefer declarative over imperative style

- fault: contradiction -- line 36 requires the solution be "appropriately object-oriented, functional, or procedural for the context", and procedural style *is* imperative style; a reviewer cannot satisfy both rules on code whose right form is procedural.

- recommendation: my own text -- state the preference and its exception in one rule, naming the case where imperative wins.

**B18** `.agents/audits/dhh-code-audit.skill.md:58`

- rule: - Does the DOM seem to be fighting the code, or is the code driving the DOM?

- fault: ambiguous procedure -- the whole ### For JavaScript/Svelte Code section is written as questions while its Ruby counterpart (:48-54) is written as imperatives; the section is then applied by the same procedure, which has no step that turns a question into a finding.

- recommendation: my own text -- restate all five bullets as the checks they ask for, in the imperative form :48-54 already uses.

**B19** `.agents/audits/dhh-code-audit.skill.md:59`

- rule: Does the code follow known, best practices for Svelte 5?

- fault: ambiguous wording -- "known, best practices" with the stray comma opens no document a reviewer can reach, and "Svelte 5" pins a major version the file never justifies; code on an earlier Svelte is reviewed against a standard it cannot meet.

- recommendation: my own text -- name the source the practices come from, or drop the version and the appeal to consensus.

**B20** `.agents/audits/dhh-code-audit.skill.md:60`

- rule: Does the code demonstrate mastery of JavaScript's paradigms?

- fault: redundant -- line 40 asks the same thing as its second clause, Does it demonstrate mastery of Ruby's expressiveness or JavaScript's paradigms?; "mastery" is in both, undefined in both.

- recommendation: removal - keep line 40's combined form, where the language pairing is stated.

**B21** `.agents/audits/dhh-code-audit.skill.md:69`

- rule: **Constructive**: Always show the path to improvement with specific examples.

- fault: redundant -- line 71 requires concrete refactoring suggestions with code examples, which is the same obligation; the two lines differ in adjective, not in requirement.

- recommendation: removal - one sentence carrying both the demonstration and the example, at :71 where it already carries the two.

**B22** `.agents/audits/dhh-code-audit.skill.md:95`

- rule: [If the code needs significant work, provide a complete rewrite that would be Rails-worthy]

- fault: harmful -- the seat is told to ship a complete rewrite under a trigger, "significant work", that is never defined; the fix leaves the author's hands, the diff the operator would review no longer exists, and with Write granted at :4 the rewrite can land in the tree under review.

- recommendation: removal, or my own text -- a review returns findings with the change described at its site; a rewrite is a separate unit of work with its own author.

**B23** `.agents/audits/dhh-code-audit.skill.md:97`

- rule: If the code wouldn't make it into Rails core or wouldn't be used as an example in Rails documentation, it needs improvement.

- fault: harmful -- the bar is Rails core, which no application code in this repository can reach, so the rule fires on every line of every review; with every finding mapped to "needs improvement", the output format at :81-87 has no way to separate a defect from a preference, and the reader cannot find the blocking one.

- recommendation: my own text -- state a severity threshold and what makes a finding blocking, and demote the exemplar bar to a comment on style.

**B24** `.agents/audits/dhh-code-audit.skill.md:99`

- rule: Channel DHH's uncompromising pursuit of beautiful, expressive code. Every line should be a joy to read and maintain.

- fault: redundant -- restates :97 in a second vocabulary ("beautiful, expressive", "joy to read") and adds no rule; "joy" is the same unactionable criterion already raised at :33.

- recommendation: removal - the closing sentence of a procedure should carry the last instruction, not a restatement of the first.

### bash-audit.skill.md -- 29 lines

#### Arm A -- 9 faults

**A1** `.agents/audits/bash-audit.skill.md:3`

- rule: "One-line findings, ranked by impact."

- fault: redundant instruction -- one rule at two sites, and "impact" appears in the repository only in this clause pair, so a change to the ranking key would have to land in both.

- recommendation: removal - the output rule at line 25 states the ranking where the reader acts on it, and the line-3 copy adds no constraint; "impact" is undefined at either site and no rule in docs/development/bash-coding-conventions.md assigns one.

**A2** `.agents/audits/bash-audit.skill.md:3`

- rule: "Read-only, one-shot."

- fault: redundant instruction -- the same read-only/one-shot rule is stated twice in a 29-line file, in different words, so the two sites can drift apart without either reading wrong.

- recommendation: removal - the Boundaries sentence states it together with the mechanism that makes it true ("applies nothing"), so it is the site to keep.

**A3** `.agents/audits/bash-audit.skill.md:15`

- rule: "| subshell-pitfall: | \|\| true on whole pipeline | subshell scope (cmd \|\| true) |"

- fault: ambiguous wording -- cmd is a placeholder with no stated scope, so a reader can act on two sentences: wrap the offending stage (docker compose up -d 2>&1 | (grep -v "^Container " || true)) or wrap the whole pipeline ((a | b) || true). The second is the harm the row exists to catch, since the subshell returns 0 and every stage's status is still swallowed.

- recommendation: "Scope to the individual command with a subshell" -- quoted from docs/development/bash-coding-conventions.md:207, which states this rule and carries the stage-scoped example.

**A4** `.agents/audits/bash-audit.skill.md:16-17`

- rule: "| shrink: | same logic, fewer lines | show shorter form |" and "| stdlib: | hand-rolled thing bash builtins cover | name the builtin |"

- fault: harmful instruction -- neither row names a rule the cited authority states; a grep of docs/development/bash-coding-conventions.md finds no economy rule and no builtin-preference rule, so a finding on either tag cites nothing the operator can check, while :29 admits "bash coding-conventions violations only". shrink: additionally carries no criterion: "fewer lines" is satisfied by merging two statements, which breaks rule 4.1's split assignment. Both rows are also unhunted -- the list at :21 names neither -- so they are dead as written.

- recommendation: removal - a tag with no owner rule and no hunt target is a finding generator the surface cannot adjudicate; if the operator wants either check, it belongs in docs/development/bash-coding-conventions.md first, then in this table.

**A5** `.agents/audits/bash-audit.skill.md:21`

- rule: "Bare exit in src/libs/ and src/build/, unquoted expansions, ..."

- fault: harmful instruction -- "bare exit" is narrower than the rule the audit says it enforces. Rule 3.1 states "Functions in sourced libraries (src/libs/, src/build/) must use return 1, not exit 1", and the file's own tag row at :9 says "exit in sourced library function". Read against the hunt list, a library function ending in exit 1 -- the exact form 3.1 forbids -- passes.

- recommendation: "Functions in sourced libraries (src/libs/, src/build/) must use return 1, not exit 1." -- quoted from docs/development/bash-coding-conventions.md:309.

**A6** `.agents/audits/bash-audit.skill.md:3,`

- rule: "Audit bash code against the rules in [bash-coding-conventions.md](...)"; "... circular source paths."; "Scope: bash coding-conventions violations only."

- fault: ambiguous procedure -- the audit's target set has three different extents. The trace stops at step 2: line 25 requires a <tag> per finding, the table at :9-17 supplies nine, and the Hunt list names seven; a violation of rule 1.2 (-- termination), 1.3 (while read over xargs), 1.8 (EXIT traps), 3.2 (exit code carries a verdict) or 4.1 (local FOO=$(cmd)) is in scope by :3 and :29, has no hunt target, and has no tag to report it under, so the finding cannot be written in the required shape and nothing in the file says what to do with it.

- recommendation: mine -- "Report a violation of any rule in bash-coding-conventions.md. Where the table has no row for the rule, tag the finding with the rule's own section id, as 1.8: <offending code>. <replacement>. [path:line]."

**A7** `.agents/audits/bash-audit.skill.md:25`

- rule: "End with net: -<N> issues found."

- fault: ambiguous wording -- "net" has no referent in the file, and the minus sign supports two readings a reader could act on: N is the number of findings, or N is a change against a prior count. The second cannot be produced, since the audit is one-shot and read-only with no prior count as input. The token also renames the unit the file otherwise calls a finding.

- recommendation: removal - the findings already above the line supply the count, and nothing in the format derives a net figure.

**A8** `.agents/audits/bash-audit.skill.md:25`

- rule: "<tag> <what to cut>. <replacement>. [path:line]"; "Nothing to cut: Clean. Ship."

- fault: ambiguous wording -- "cut" fits only deletions, while the table's own replacements are an edit (return 1), an addition ("name the builtin") and a re-scoping ("subshell scope ..."). Two readings both act: put the text to delete in that slot, or put the offending span there. Under the first, the null condition "Nothing to cut" is true while findings remain, so the reader cannot tell when to print Clean. Ship.

- recommendation: mine -- "One line per finding, ranked by impact: <tag> <offending code>. <replacement>. [path:line]. End with N findings. No findings: No findings." (the closing clause is item 9's site; the two recommendations are one edit).

**A9** `.agents/audits/bash-audit.skill.md:25`

- rule: "Nothing to cut: Clean. Ship."

- fault: harmful instruction -- the null output issues a shipping verdict for code the audit did not examine for the classes that decide whether shipping is safe, and the same file disclaims them at :29: "Correctness bugs, security holes, and performance are out of scope. Lists findings, applies nothing." A clean bash-conventions pass is compatible with a security hole, so the verdict asserts what the audit's own boundaries exclude.

- recommendation: mine -- "No findings."

#### Arm B -- 13 faults

**B1** `.agents/audits/bash-audit.skill.md:1`

- rule: # Skill -- Bash Audit

- fault: not-loadable skill -- the file is named .skill.md and titled "Skill", but carries no frontmatter name/description block, so nothing can load or describe it as a skill. The three sibling .skill.md files in the same directory (architecture-doc-reviewer, dhh-code-audit, kelsey-code-reviewer) each open with ---. My own naming, justified by that sibling convention in the same directory.

- recommendation: mine -- add a frontmatter block with name: bash-audit and a description: stating when to invoke it, above the current heading.

**B2** `.agents/audits/bash-audit.skill.md:3`

- rule: Audit bash code against the rules in [bash-coding-conventions.md](../../docs/development/bash-coding-conventions.md).

- fault: ambiguous procedure -- no file set to sweep is named anywhere; the only paths in the file are src/libs/ and src/build/ on line 21, and that scope is attached to the exit check alone. A reviewer cannot tell whether the sweep is the whole repository, src/, or those two directories.

- recommendation: mine -- state the swept set in this sentence, e.g. "Audit the bash under src/ against the rules in ...", and let line 21's two directories keep narrowing the one check they name.

**B3** `.agents/audits/bash-audit.skill.md:3`

- rule: One-line findings, ranked by impact. Read-only, one-shot.

- fault: redundant wording -- ranked by impact is restated at line 25 ("One line per finding, ranked by impact"), and Read-only, one-shot is restated at line 29 ("Lists findings, applies nothing. One-shot.").

- recommendation: removal -- both requirements are stated where they are acted on, in ## Output and ## Boundaries; this line is a summary of the two.

**B4** `.agents/audits/bash-audit.skill.md:15`

- rule: | subshell-pitfall: | \|\| true on whole pipeline | subshell scope (cmd \|\| true) |

- fault: harmful -- the prescribed replacement wraps the whole pipeline, (cmd1 | cmd2 || true), which still swallows every command's failure under pipefail. A reviewer following the Replacement column literally reports a fix that does not fix the violation it names.

- recommendation: quoted from docs/development/bash-coding-conventions.md:206 -- "Scope to the individual command with a subshell", with that section's example form ... | (grep -v "^Container " || true).

**B5** `.agents/audits/bash-audit.skill.md:16`

- rule: | shrink: | same logic, fewer lines | show shorter form |

- fault: harmful -- line count is made a violation, so the audit rewards compression over the readability the conventions doc requires; nothing in bash-coding-conventions.md states such a rule, yet the file audits "against the rules in" it (line 3) and claims "bash coding-conventions violations only" (line 29).

- recommendation: removal -- the rule has no source in the referenced conventions document, and as stated it can only produce findings the operator must reject.

**B6** `.agents/audits/bash-audit.skill.md:17`

- rule: | stdlib: | hand-rolled thing bash builtins cover | name the builtin |

- fault: ambiguous wording -- most replacements of hand-rolled shell are not builtins (sed, awk, find, stat), and "name the builtin" tells the reviewer nothing to do when the answer is external; like shrink:, it also has no rule in the referenced conventions document.

- recommendation: removal -- unsourced rule, and unactionable as worded; if it stays it needs the doc rule it enforces and a stated replacement form.

**B7** `.agents/audits/bash-audit.skill.md:21`

- rule: Bare exit in src/libs/ and src/build/, unquoted expansions, heredocs generating Makefile content, local at top level, export of behaviour flags, || true on pipelines, circular source paths.

- fault: ambiguous procedure -- the Hunt names seven checks for nine tags: shrink: and stdlib: appear in the table and are never looked for, and nothing says whether the Hunt is exhaustive or illustrative. A reviewer working from the Hunt cannot emit two of the nine tags.

- recommendation: mine -- pick one: treat the Hunt as exhaustive and delete the two tags it does not name (line 16, line 17), or say the Hunt is illustrative and add a search for each tag to it.

**B8** `.agents/audits/bash-audit.skill.md:21`

- rule: circular source paths

- fault: ambiguous wording -- the rule in the conventions doc (## 2.3 No circular sourcing) is about libraries sourcing each other; "source paths" reads as filesystem path cycles, i.e. symlinks, which are a different defect.

- recommendation: quoted from .agents/audits/bash-audit.skill.md:14 -- circular sourcing between libs.

**B9** `.agents/audits/bash-audit.skill.md:25`

- rule: One line per finding, ranked by impact: <tag> <what to cut>. <replacement>. [path:line].

- fault: ambiguous procedure -- "impact" is given no axis, and it is not orderable for the improvement tags: a stdlib: or shrink: finding has no severity to rank against an exit-in-lib: finding.

- recommendation: mine -- name the ordering the operator wants, e.g. "ranked by blast radius: exit-in-lib: and source-cycle: first, shrink: and stdlib: last", or drop the ranking requirement.

**B10** `.agents/audits/bash-audit.skill.md:25`

- rule: <what to cut>

- fault: ambiguous wording -- "cut" fits no tag whose fix is a rewrite: for unquoted: nothing is removed and the text added is a quote; the table's own column is "Replacement", so the reviewer must guess which of two names the slot holds.

- recommendation: quoted from .agents/audits/bash-audit.skill.md:7 -- Replacement, giving <tag> <rule violated>. <replacement>. [path:line].

**B11** `.agents/audits/bash-audit.skill.md:25`

- rule: End with net: -<N> issues found.

- fault: ambiguous wording -- a signed "net" over a count labelled "found": N is not defined as the finding count, the removed-line count, or a balance, and a negative sign on a "found" count reads backwards. The same file calls a finding a "finding" at lines 3 and 25 and an "issue" here.

- recommendation: mine -- End with <N> findings. and use "finding" throughout.

**B12** `.agents/audits/bash-audit.skill.md:25`

- rule: Nothing to cut: Clean. Ship.

- fault: harmful -- "Ship." is a release verdict. The same file states the audit "applies nothing" (line 29) and lists findings only, so a clean tag list licenses no approval: the audit never ran the code, and its own ## Boundaries puts correctness out of scope.

- recommendation: mine -- Nothing found: Clean.

**B13** `.agents/audits/bash-audit.skill.md:29`

- rule: Correctness bugs, security holes, and performance are out of scope.

- fault: redundant wording -- entailed by the preceding sentence, Scope: bash coding-conventions violations only.; the conventions doc covers none of the three.

- recommendation: removal -- the first sentence already excludes them, and a reader who holds "violations of that document only" derives the enumeration.

### test-quality-campaign.md -- 106 lines

#### Arm A -- 12 faults

**A1** `.agents/audits/test-quality-campaign.md:14`

- rule: "Autonomous, long-running, and token-aggressive."

- fault: ambiguous wording -- two readings a reader can act on, each supported by a different sentence of the same file: spend whatever tokens the judgment needs (the next sentence, "Prefer depth: read the file instead of guessing from a grep"), or keep the budget small and compress hard (:98, "If context grows, summarise older work into the state files and continue"). "Aggressive" carries the opposite direction in each, and no site decides it.

- recommendation: mine -- "Autonomous, long-running, and depth-first: read the file instead of guessing from a grep."

**A2** `.agents/audits/test-quality-campaign.md:14`

- rule: "Ignore the usual per-iteration permission gates for the duration."

- fault: ambiguous wording -- "the usual per-iteration permission gates" names no set. Reading A: every approval gate in docs/reference/iteration_protocol.md is suspended, including the operator release AGENTS.md requires ("Every gate requires explicit operator release"). Reading B: only in-session approval prompts are suspended, because the file keeps gates of its own -- "stop and ask the operator for a ruling" (:16) and "Do not commit" (:22). The two readings are contradictory over the same gates, and AGENTS.md:66-adjacent policy is the conflicting instruction.

- recommendation: mine -- "Ignore the in-session approval prompts for the duration; the operator ruling gate at line 16 and the no-commit rule stay in force."

**A3** `.agents/audits/test-quality-campaign.md:18`

- rule: "Outside the campaign, tests are opt-in and product-first."

- fault: harmful -- it authorises the omission the convention forbids. .agents/skills/testing/SKILL.md:20 states "**Tests arrive with the code.** Any function with meaningful branching, error handling, or external dependencies gets tests, produced alongside the implementation rather than deferred." The campaign names that same skill as the authority (:5) and says the convention wins (:10), so a reader must either break the campaign or break the convention, and the cost of picking the campaign is a session that ships untested code and believes it is authorised to.

- recommendation: removal - "The operator invoking this campaign is the opt-in moment. Writing and changing tests is authorised for the duration." already carries the authorisation the campaign needs; the deleted clause authorises the opposite of the convention this file names as authority.

**A4** `.agents/audits/test-quality-campaign.md:22,`

- rule: "Do not commit." (:22) / "Then leave the test changes uncommitted in the working tree, and stop. Do not commit." (:71) / "Do not continue past the report." (:22, :79)

- fault: redundant -- one rule with three to four sites (duplication entry, this file against itself): the no-commit rule at :22 and :71, the stop-at-report rule at :22, :79 and :106. A change to one must land in the others, and the copies are what left room for the contradicting heading at :59.

- recommendation: removal - keep :22 (Deliverable) as the single home and delete the copy at :71, the restatement at :79, and the stop clause at :106, leaving :71 the action "leave the test changes uncommitted in the working tree" and :106 "Start with Phase 0."

**A5** `.agents/audits/test-quality-campaign.md:39`

- rule: "Confirm the test command (make test) and that the suite starts green, so later failures are yours."

- fault: ambiguous procedure -- the baseline it establishes has no reader: Phase 1 re-runs the suite and records pass/fail (:43) without naming the Phase 0 result, so a reader cannot tell whether :43's record is the baseline or a second run, and no step covers a baseline that is not green while :98 forbids stopping. The command half is also already stated at .agents/skills/testing/SKILL.md:10 ("make test runs scripts/run_tests.sh").

- recommendation: removal - :43's "Run the full suite and record pass/fail" produces the same input before any change, and the command is stated in the convention; the clause asks for a result nothing later reads.

**A6** `.agents/audits/test-quality-campaign.md:45,`

- rule: "A test that pins a behaviour a future reader would be tempted to change must name the record (ADR, design record, or handover decision) that explains it." (:45) / "Pinned assertions name their rationale (ADR, design record, or handover decision)." (:89)

- fault: redundant -- one rule with two sites in one file (duplication entry; a change must land in both), and both restate .agents/skills/testing/patterns/assertions.md:27 in different words: the convention's trigger is "pins an exact string or byte class", not "a behaviour a future reader would be tempted to change", and its record list includes "a roadmap item", which both sites drop. A pin citing a roadmap item is conformant at the authority and unresolvable under the campaign -- a conflict entry against the source both sites name.

- recommendation: removal - :5 and :7 already point the reader at patterns/assertions.md "especially the change-mirror form", so the rule has one home and both campaign sites are copies that contradict it.

**A7** `.agents/audits/test-quality-campaign.md:46,`

- rule: "and dead tests (defined but never run_test-registered)" (:46) / "Zero dead tests - every test_*() registered and every run_test target resolving." (:86)

- fault: redundant -- the runner already holds this on every run: docs/development/test_harness_mechanism.md:19 "The registration liveness gate runs before dispatch ... on every run", :73 "scripts/check_test_liveness.sh owns the registration contract" with defects UNREGISTERED, DANGLING and DEAD-REGISTRATION, and .agents/skills/testing/SKILL.md:57 names make test-liveness as the check. A stop criterion a gate satisfies on every run cannot fail and carries no signal.

- recommendation: removal - both clauses; a named gate covers the whole requirement (make test-liveness over scripts/check_test_liveness.sh), and the gate's finding is fixed in the same change by the existing convention.

**A8** `.agents/audits/test-quality-campaign.md:49`

- rule: "seed TODO.md (P0 = High Noise + dead tests + missing invariant branches)"

- fault: ambiguous procedure -- the step is executed at the end of Phase 1 and reads an input Phase 2 produces: "missing invariant branches" are identified at :53 ("For every pure (or near-pure) bash function and important loop, document ... every branch"), so the trace stops at the seeding with nothing to seed. :53 then states the same seeding where the input exists ("Turn each missing contract into a TODO.md task").

- recommendation: removal - the clause "missing invariant branches" from :49; :53 states the same seeding against an input that exists at its site.

**A9** `.agents/audits/test-quality-campaign.md:49,`

- rule: "record one overall rating for the suite (same three values)" (:49) / "Every High Noise verdict from Phase 1 is resolved (kept with rationale, rewritten, or deleted)." (:92)

- fault: ambiguous procedure -- :92's action set is per file (keep, rewrite, delete), while :49 also produces a verdict about the suite as a whole, which is a "High Noise verdict from Phase 1" with no file to keep, rewrite or delete. The trace stops at :92 on a suite verdict, and :92 does not say whether the suite verdict is in scope.

- recommendation: mine -- "8. Every per-file High Noise verdict from Phase 1 is resolved (kept with rationale, rewritten, or deleted)."

**A10** `.agents/audits/test-quality-campaign.md:57`

- rule: "Every 4-6 tasks, re-run the broad suite and re-prioritise TODO.md."

- fault: ambiguous wording -- "broad suite" names no scope, and the file uses three names for the thing: "the full suite" (:43), "the broad suite" (:57), "the suite" (:91). Reading A: the full suite. Reading B: a wide subset, which scripts/run_tests.sh accepts as [FILE|DIR...]. Under reading B the grind can leave failures outside the subset for four to six tasks while criterion 7 measures the whole suite.

- recommendation: replacement text quoted from a site that already states it -- "Run the full suite" (:43), as "Every 4-6 tasks, re-run the full suite and re-prioritise TODO.md."

**A11** `.agents/audits/test-quality-campaign.md:59`

- rule: "## Phase 4 - Final Report, Commit, Submit"

- fault: harmful -- the heading orders a commit in a file whose deliverable is an uncommitted working-tree proposal (:22 "leave the test changes uncommitted in the working tree as a proposal. Do not commit."; :71), so a reader who follows the heading destroys the deliverable's only form; the collected summary block (:73-77) assumes an uncommitted tree. "Submit" names no action any step of the phase performs. Conflict entry: :22 and :71 state the opposite of the heading.

- recommendation: mine -- "## Phase 4 - Final Report"

**A12** `.agents/audits/test-quality-campaign.md:91`

- rule: "7. The suite is deterministic and green: failed 0, skipped 0."

- fault: harmful condition inside an otherwise good rule -- the authority's close gate is failed 0 alone (.agents/skills/testing/SKILL.md:56 "Run make test; the suite reports failed 0"), and a skip is a warning that never fails the run (docs/development/test_harness_mechanism.md:67; scripts/run_tests.sh:416 warns rather than fails). The suite does carry skip calls today (at least tests/test_model_failover.sh, tests/test_model_refresh.sh, tests/test_taskq.sh), so the clause converts a documented legitimate state into a stop gate, and :83 "Stop only when all hold" then blocks the close the deliverable requires, leaving the campaign the false exit of declaring a "hard external blocker" (:61) or a suite-layout move the convention places outside the campaign's criteria.

- recommendation: removal - the clause ", skipped 0"; the gate is failed 0, as .agents/skills/testing/SKILL.md:56 states it.

#### Arm B -- 20 faults

**B1** `.agents/audits/test-quality-campaign.md:5`

- rule: "This prompt links to it and does not restate it."

- fault: harmful -- the surface contradicts its own claim: it restates the convention at lines 18, 45, 47, 85-92, and one restatement (line 45) diverges from the source it claims not to copy.

- recommendation: removal - the precedence rule the sentence is meant to carry is already stated at line 10 ("Where this prompt and the convention disagree, the convention wins"), and the false part of the claim is what makes the divergent restatement look authoritative.

**B2** `.agents/audits/test-quality-campaign.md:14`

- rule: "Prefer depth: read the file instead of guessing from a grep."

- fault: harmful -- it instructs the reader to read files whole, against the root AGENTS.md ## Read Discipline ("Before opening any file in full, establish what you need from it first"), and the campaign later depends on a context that this rule spends ("If context grows, summarise older work into the state files").

- recommendation: removal - the project layer already governs how much of a file is opened, and a prompt under it may not lift that.

**B3** `.agents/audits/test-quality-campaign.md:14`

- rule: "Ignore the usual per-iteration permission gates for the duration."

- fault: ambiguous wording -- "the usual per-iteration permission gates" names no document and no gate, so the reader cannot tell which gates are lifted, and the grant cannot be checked by the operator who gave it.

- recommendation: replacement text quoted from line 18: "Writing and changing tests is authorised for the duration."

**B4** `.agents/audits/test-quality-campaign.md:18`

- rule: "The operator invoking this campaign is the opt-in moment. Writing and changing tests is authorised for the duration. Outside the campaign, tests are opt-in and product-first."

- fault: redundant -- one grant is stated three times in three vocabularies, and the third sentence describes a condition no reader of this surface acts in; "opt-in and product-first" appears in no cited authority.

- recommendation: removal of the first and third sentences - the second sentence is the grant the campaign needs, and the outside-campaign policy has no site here.

**B5** `.agents/audits/test-quality-campaign.md:22`

- rule: "The report lives in the output mount session directory."

- fault: ambiguous wording -- the location is named three ways across the file ("the output mount session directory", $OUTPUT_DIR at line 26, $SESSION_DIR at line 35), so the reader must decide whether the report sits in the mount root or in the session directory.

- recommendation: mine: "The report is FINAL_REVIEW.md in $SESSION_DIR."

**B6** `.agents/audits/test-quality-campaign.md:43`

- rule: "For each test file answer three questions:"

- fault: ambiguous procedure -- the announced count is three, but item 1 alone poses three questions of its own, and no item states what answer counts as passing the "reflection gate" it is asked to apply.

- recommendation: mine: "For each test file, decide three things, and record the evidence for each:" followed by a one-line pass rule per item.

**B7** `.agents/audits/test-quality-campaign.md:45`

- rule: "A test that pins a behaviour a future reader would be tempted to change must name the record (ADR, design record, or handover decision) that explains it."

- fault: harmful -- it restates .agents/skills/testing/patterns/assertions.md:27 with a different record list (it drops a roadmap item and adds a handover decision), so a reader obeying this line violates the authority the same file says wins.

- recommendation: replacement text quoted from .agents/skills/testing/patterns/assertions.md:27: "A test that pins an exact string or byte class cites the record that decides the pin (a roadmap item, an ADR, or a design record)".

**B8** `.agents/audits/test-quality-campaign.md:47`

- rule: "**Iteration friction** - find lock-step edits from output-contract changes that lacked a propagation checklist, and pins with no rationale."

- fault: redundant -- the pin-rationale requirement is stated at line 45 and again as success criterion 5 at line 89, in three wordings ("must name the record", "pins with no rationale", "name their rationale"), with no statement of which governs.

- recommendation: removal of the clause "and pins with no rationale" - the requirement is carried by line 45 and gated by line 89.

**B9** `.agents/audits/test-quality-campaign.md:49`

- rule: "Record the verdicts in FLAKY_AND_BAD_TESTS.md and seed TODO.md ..."

- fault: ambiguous wording of my own naming, "one file, two meanings" -- line 16 assigns that file to a product defect the campaign refuses to fix, and this line makes it also the home of every judged file's rating, so a reader cannot tell what an entry in it is.

- recommendation: mine: "Record the verdicts in FLAKY_AND_BAD_TESTS.md, whose entries carry either a product defect or a judged file's rating."

**B10** `.agents/audits/test-quality-campaign.md:53`

- rule: "For every pure (or near-pure) bash function and important loop, document preconditions, postconditions, invariants, edge cases, and every branch in INVARIANTS.md."

- fault: ambiguous wording -- "near-pure" names no boundary and "important loop" names no test, while the coverage note at line 94 measures "pure functions with documented invariants vs total pure functions", so neither the population nor the denominator can be counted.

- recommendation: mine: "For every pure function and every loop that carries a branch, document ...", with purity defined once before Phase 2.

**B11** `.agents/audits/test-quality-campaign.md:57`

- rule: "While TODO.md has open P0 or important P1 items: ..."

- fault: ambiguous procedure -- P1 is never defined (line 49 defines P0 only) and "important" adds an undefined qualifier to it, so the loop's exit condition is unreadable.

- recommendation: mine: "While TODO.md has open P0 or P1 items: ..." with line 49 extended to define P1 ("P1 = every other item Phase 1 and Phase 2 raise").

**B12** `.agents/audits/test-quality-campaign.md:57`

- rule: "Every 4-6 tasks, re-run the broad suite and re-prioritise TODO.md."

- fault: ambiguous wording -- "the broad suite" is a second name for the thing lines 39 and 43 call "the full suite", and no site says whether the two differ.

- recommendation: replacement text quoted from line 43: "Run the full suite".

**B13** `.agents/audits/test-quality-campaign.md:59`

- rule: "## Phase 4 - Final Report, Commit, Submit"

- fault: harmful -- the heading requires a commit, while line 22 ("Do not commit"), line 71 ("and stop. Do not commit.") and line 79 forbid one; a reader following the heading produces exactly the artifact the campaign exists to withhold.

- recommendation: mine: "## Phase 4 - Final Report".

**B14** `.agents/audits/test-quality-campaign.md:79`

- rule: "Do not continue past the report."

- fault: redundant -- the sentence is verbatim line 22, and line 71 states the stop again in the same section.

- recommendation: removal - the identical sentence is read first at line 22, in ## Deliverable.

**B15** `.agents/audits/test-quality-campaign.md:87`

- rule: "Prerequisites enforced - a broken stub or shim reports one named prerequisite error, not N unrelated test failures."

- fault: redundant -- it is a property the harness already holds and already documents: check_prerequisites in scripts/run_tests.sh:41, called at scripts/run_tests.sh:303, reports the missing docker stub once by name, and docs/development/test_harness_mechanism.md:101 states the rule; the campaign changes tests, so no campaign outcome makes this criterion true or false. "N" is also an unbound symbol.

- recommendation: removal - the guarantee belongs to the runner and its self-test, not to a campaign success criterion.

**B16** `.agents/audits/test-quality-campaign.md:88`

- rule: "Output-contract changes carry a propagation checklist per AGENTS.md."

- fault: redundant -- .agents/skills/testing/SKILL.md:54, which the Authority at line 7 names, already carries this rule and points at the propagation-check skill; this copy points at AGENTS.md instead, so one rule now has two pointers and the reader must pick.

- recommendation: removal - the convention holds the rule and a single pointer, and this file is not its owner.

**B17** `.agents/audits/test-quality-campaign.md:90`

- rule: "No handover or finding claims a code path that no test exercises."

- fault: harmful -- it makes a criterion out of an artifact class the scope excludes ("Scope: tests and the test runner"), and line 16's own conflict rule then obliges every run to stop and ask the operator for a ruling.

- recommendation: mine: "A handover or finding that claims a code path no test exercises is recorded in FLAKY_AND_BAD_TESTS.md and flagged, not repaired here."

**B18** `.agents/audits/test-quality-campaign.md:98`

- rule: "If you hit a non-blocking question, write it into CAMPAIGN_STATUS.md and keep working."

- fault: harmful -- it contradicts line 16, where a scope conflict "stop[s] and ask[s] the operator for a ruling; do not resolve the conflict silently", and gives the reader no way to tell a scope conflict from a non-blocking question.

- recommendation: mine: "If you hit a non-blocking question other than a scope conflict, write it into CAMPAIGN_STATUS.md and keep working."

**B19** `.agents/audits/test-quality-campaign.md:98`

- rule: "If a phase finishes early, deepen."

- fault: ambiguous wording -- "deepen" names no action and no bound, and the phase's work is already bounded by the TODO.md P0/P1 loop at line 57, so this sentence can only license work the success criteria do not ask for.

- recommendation: removal - the loop at line 57 already says what to do with remaining capacity.

**B20** `.agents/audits/test-quality-campaign.md:106`

- rule: "Start with Phase 0. Then enter the loop and do not stop until the final report is written and the summary block is returned."

- fault: redundant -- its second sentence restates line 98's last sentence almost word for word, and its first names a phase the file's own headings already order.

- recommendation: removal - the whole ## Kickoff section repeats the stop rule and the phase order stated above it.

### test-assertion-sweep-brief.md -- 49 lines

#### Arm A -- 13 faults

**A1** `.agents/audits/test-assertion-sweep-brief.md:23`

- rule: "# Test Suite Per-Assertion Sweep -- Review Brief (report-only)"

- fault: heading-nesting collapse -- my own fault name, justified: the file carries two H1s, the wrapper's at line 1 and the brief's own at line 23 ("# Task: final per-assertion authoring sweep (report only)"), so the brief's ## sections at 27, 35 and 45 are siblings of the wrapper's ## sections at 3, 7, 13 and 21. Nothing in the heading tree says which sections constitute the brief that line 10 feeds to a subagent, and the wrapper's run record reads as part of the brief.

- recommendation: my own text -- demote # Task: to ## and its three subsections to ###, or split the file so the brief is one document whose H1 is line 1.

**A2** `.agents/audits/test-assertion-sweep-brief.md:10`

- rule: "timeout 1800 pi --provider opencode-go --model deepseek-v4-flash --thinking xhigh -p \"$(cat <this file>)\" > /tmp/u7-review.log 2>&1"

- fault: ambiguous wording -- <this file> reads as a literal in a command that is otherwise copy-pasteable, and </> are shell redirections if pasted, so the reader cannot replay the recorded run.

- recommendation: my own text -- name the value: -p "$(cat .agents/audits/test-assertion-sweep-brief.md)".

**A3** `.agents/audits/test-assertion-sweep-brief.md:15`

- rule: "the harness contract (subshell-per-test, fail-fast, unit accounting, the allocator, benign-rc masks, the order gate) is stated before the checklist"

- fault: redundant instruction (conflict) -- line 33 states "no order gate is needed" and line 43 states "nothing to fix here", while this sentence names the order gate as a part of the contract. The gate was retired: devlog/handovers/archive/20260923-02-impl-test_harness_result_protocol_refactor.md:29 -- "The order gate is retired and REVERSE_RUN is gone".

- recommendation: removal - the order gate no longer exists, and lines 33 and 43 state that none is needed; the list is false at this member and the reader is sent looking for a gate to check.

**A4** `.agents/audits/test-assertion-sweep-brief.md:29`

- rule: "run_test NAME emits the unit markers PASS: NAME and FAIL: NAME (both indented two spaces; the runner counts them)."

- fault: harmful instruction -- the parenthetical is false, in the one section written "so you do not misread the code". scripts/run_tests.sh:164 reads UNIT="$(grep '^UNIT: pass=' "$TMPFILE" ...)" and scripts/run_tests.sh:141-142 states the counts "come from the test file's own UNIT: report ... not from re-parsing presentation" markers; tests/libs/test_common.sh:231-234 states the same. The markers only name failing units for display (scripts/run_tests.sh:197).

- recommendation: replacement quoted from tests/libs/test_common.sh:231-234: "Emits one machine-readable UNIT: line -- the authoritative counts the runner reads. scripts/run_tests.sh parses this line; it does not re-derive counts from the cosmetic markers, so the failure verdict rides the exit code and the counts ride this report."

**A5** `.agents/audits/test-assertion-sweep-brief.md:32`

- rule: "|| true masks are tolerated where the rc is a benign signal (git diff rc1 = differences found; grep -c rc1 = no matches; trailing cleanup commands under the strict rule that a non-zero test-subshell exit is a failure). A mask on a plain success-expected command is still a smell."

- fault: ambiguous wording -- the tolerated set is named again at line 41 as "(not the documented git-diff/grep-c/trailing-normalization cases)", where "trailing cleanup commands" has become "trailing-normalization": two readings, and a reader cannot tell whether a trailing normalization command is inside the exception this line grants. The same pair also disagrees on the disposition -- "still a smell" here, "flag" at line 41 -- so a reader cannot tell whether a smell is a finding.

- recommendation: my own text for line 41's parenthetical -- "(not the documented benign cases: git diff rc1, grep -c rc1, and trailing cleanup commands)", keeping line 32 as the source of the list.

**A6** `.agents/audits/test-assertion-sweep-brief.md:33`

- rule: "Each test runs in its own subshell with a fresh FIXTURE_DIR, so the suite is order-independent by construction; no order gate is needed."

- fault: redundant instruction (duplication) -- the same rule is stated again at line 43: "nothing to fix here; each test runs in its own subshell with a fresh fixture, so the suite is order-independent by construction." A change to one must land in the other; and inside line 43 the clause "nothing to fix here" contradicts the item's own instruction to flag a test that depends on a sibling's written file.

- recommendation: removal - of the duplicated clause at line 43 ("nothing to fix here; each test runs in its own subshell with a fresh fixture, so the suite is order-independent by construction."); line 33 is the contract for it, and item 7 must survive for the per-item zero statement the output format requires.

**A7** `.agents/audits/test-assertion-sweep-brief.md:35`

- rule: "## The authoring bar -- every assertion in tests/test_*.sh (58 files) against these"

- fault: harmful instruction, and redundant with line 49 -- the count is a derived value this document does not own and it has drifted: ls tests/test_*.sh | wc -l is 94 and wc -l tests/test_*.sh is 33,163. A reviewer told "58 files" sweeps 58 of 94.

- recommendation: removal - of the parenthetical "(58 files)" here and of "all 58" at line 49; the glob tests/test_*.sh in this heading already bounds the set, and the count drifts with the tree.

**A8** `.agents/audits/test-assertion-sweep-brief.md:37`

- rule: "a test that runs a command should keep its rc AND its output and assert both. Flag rc-only assertions that discard meaningful output (a failure message that would be blind)"

- fault: ambiguous wording -- two readings, each actionable, and the finding count depends on which. Reading one: assert_run captures into RUN_OUT (tests/libs/test_common.sh:353-366, "never discarded"), so an assert_run without a following output assertion satisfies "keep"; then only >/dev/null 2>&1 sites are findings. Reading two: "assert both" is a requirement, so every assert_run with no assert_contains/assert_eq on RUN_OUT is a finding.

- recommendation: my own text -- "Flag a test whose command output would diagnose a failure but is asserted nowhere: assert_run captures into RUN_OUT and asserts only the rc, so a finding is a capture whose RUN_OUT is never asserted on, or a command whose output is discarded with >/dev/null 2>&1."

**A9** `.agents/audits/test-assertion-sweep-brief.md:39`

- rule: "writes outside $FIXTURE_DIR/$FIXTURE_ROOT/get_fixture_dir"

- fault: category error in a path list -- my own fault name, justified: the list names three things a write can be outside, and the third, get_fixture_dir, is a function (tests/libs/test_common.sh:41), not a directory, so "writes outside get_fixture_dir" describes no observable act and the reviewer cannot run the check as written.

- recommendation: my own text -- "writes outside $FIXTURE_DIR or $FIXTURE_ROOT, or to any directory other than one the allocator returned".

**A10** `.agents/audits/test-assertion-sweep-brief.md:39`

- rule: "or hand-rolls its own temp-dir trap instead of the allocator"

- fault: redundant instruction (duplication) -- this rule has two other sites. Line 30: "Teardown is the allocator's; tests must not hand-roll rm -rf \"$FIXTURE_DIR\" traps or bare mktemp -d." Line 40 (item 4): "flag tests that clean up manually (rm -rf of their own dirs) where the allocator should own it". A hand-rolled trap is manual cleanup the allocator should own.

- recommendation: removal - line 30 states the prohibition and item 4 states the flag; item 3 keeps the allocation clause and loses the teardown clause.

**A11** `.agents/audits/test-assertion-sweep-brief.md:42`

- rule: "(The suite is documented as zero bare 2-arg calls -- verify and flag any found.)"

- fault: claim with no carrier -- my own fault name, justified: "documented as zero" names no document, so the reviewer cannot check the claim or the term "2-arg call", which this file never defines although its own signature (assert_run EXPECTED_RC CMD [LABEL], line 31) makes two arguments the normal call. An unlocated zero is the shape a reviewer confirms instead of testing.

- recommendation: removal - the item's first sentence already states the check (shared or near-duplicate labels within one test function), and the parenthetical adds a count with no site to read it at.

**A12** `.agents/audits/test-assertion-sweep-brief.md:43`

- rule: "Only flag a test that obviously depends on a sibling's written file."

- fault: ambiguous wording -- "obviously" supplies no criterion, so a reviewer cannot decide the edge and will either inflate the class or drop it; nothing in the file says what evidence makes a sibling dependency visible.

- recommendation: my own text -- "Only flag a test that reads a path a sibling test writes, or whose result changes when one file's tests are run alone."

**A13** `.agents/audits/test-assertion-sweep-brief.md:49`

- rule: "do not rely on grep alone -- read representative bodies to judge labels and discard patterns"

- fault: ambiguous procedure -- the trace stops here: nothing defines what "representative" selects or how many bodies satisfy it, so the reviewer cannot tell whether the sweep is complete. The file's own account of what worked contradicts sampling: line 11 records "The run read all 58 test files in full (16,859 lines)".

- recommendation: my own text -- "do not rely on grep alone: read the body of every file a finding names, and at least one body per file otherwise, so a label or discard pattern found by grep is judged against the code that emits it."

#### Arm B -- 14 faults

**B1** `.agents/audits/test-assertion-sweep-brief.md:49`

- rule: "Sweep all 58 files; do not rely on grep alone -- read representative bodies to judge labels and discard patterns."

- fault: harmful -- the count is a derived value the file does not own; measured at this reading, ls tests/test_*.sh | wc -l returns 94. A reviewer instructed to sweep 58 files stops at 58 and reports a clean item 1-6 for the 36 files it never opened.

- recommendation: removal of the literal, replaced by my own text: "Sweep every file matching tests/test_*.sh" at :49, and "every assertion in tests/test_*.sh" at :35.

**B2** `.agents/audits/test-assertion-sweep-brief.md:49`

- rule: "Sweep all 58 files; do not rely on grep alone -- read representative bodies to judge labels and discard patterns."

- fault: ambiguous procedure -- "Sweep all" and "read representative bodies" are two different scopes joined by a semicolon, and "representative" names no sample. The reviewer cannot tell whether a label rule found only in an unread body is a miss or is out of scope.

- recommendation: removal - "do not rely on grep alone" already forbids the sampled reading this clause licenses, so the clause can only narrow the sweep it sits in.

**B3** `.agents/audits/test-assertion-sweep-brief.md:11`

- rule: "It produced: six vacuous assertions that could not fail, one provable silent-green site, five silent-green or masked-rc classes, and a real production defect the masked suites had hidden (scripts/prune.sh committed without its exec bit, so stop --prune returned 126)."

- fault: harmful -- the record pre-answers the sweep the brief asks for, so a reviewer reads the expected classes before reading the code. This is the failure the file's own :19 bullet calls the dividend of fresh eyes, and a confirming report becomes indistinguishable from a seeded one.

- recommendation: removal - nothing under "## The brief" cites the record, and the outcome it states belongs to the iteration record that already holds it.

**B4** `.agents/audits/test-assertion-sweep-brief.md:37`

- rule: "a test that runs a command should keep its rc AND its output and assert both. Flag rc-only assertions that discard meaningful output"

- fault: ambiguous procedure -- the mandated helper is an rc-only assertion, and tests/libs/test_common.sh:361 confirms it asserts RC and prints RUN_OUT only on failure. Every assert_run call site therefore fails item 1 as written, and the reviewer cannot both apply the bar and use the contract's model.

- recommendation: mine, for the operator to accept or replace: add to :31 "assert_run asserts the rc only; a test using it must also assert on RUN_OUT where the output is what diagnoses a failure." -- the choice between item 1's "assert both" and the helper's shape is the operator's.

**B5** `.agents/audits/test-assertion-sweep-brief.md:43`

- rule: "7. **Order independence**: nothing to fix here; ... Only flag a test that obviously depends on a sibling's written file."

- fault: ambiguous procedure -- the item declares its class empty and then names a case to flag, so the reviewer does not know whether order dependence is on the checklist. It also restates :33 "the suite is order-independent by construction; no order gate is needed" in different words.

- recommendation: mine: replace item 7 with "**Order independence**: flag a test that depends on a sibling's written file." -- :33 already carries the construction claim, so the item keeps only the residual check.

**B6** `.agents/audits/test-assertion-sweep-brief.md:42`

- rule: "(The suite is documented as zero bare 2-arg calls -- verify and flag any found.)"

- fault: ambiguous wording -- "2-arg calls" names no helper and no arity; the only signature the file states is assert_run ... [LABEL]. The phrase occurs nowhere else in the repository, so the instruction cannot be acted on, and the property it names (an unlabelled assertion) is not the property item 6 tests (shared or duplicate labels).

- recommendation: removal - the parenthetical asks for a check no reader can run; if the check is wanted it must name the helper whose arity it counts.

**B7** `.agents/audits/test-assertion-sweep-brief.md:41`

- rule: "(not the documented git-diff/grep-c/trailing-normalization cases)"

- fault: ambiguous wording -- the third exemption is called "trailing-normalization" here and "trailing cleanup commands" at :32, and "trailing-normalization" appears nowhere else in the repository. A reviewer holding only the bar cannot identify the exempt case, so it either flags it or silently grants it.

- recommendation: replacement text quoted from :32: "trailing cleanup commands".

**B8** `.agents/audits/test-assertion-sweep-brief.md:30`

- rule: "Teardown is the allocator's; tests must not hand-roll rm -rf "$FIXTURE_DIR" traps or bare mktemp -d."

- fault: redundant -- items 3 and 4 state the same prohibition as the findable class ("a bare mktemp -d", "hand-rolls its own temp-dir trap", "rm -rf of their own dirs"), so one rule is stated twice in different words, and the report is grouped by the items, not by the contract.

- recommendation: removal of the sentence at :30 - the contract's job is the model the reviewer reads the code against; the prohibition is the authoring bar's, where it is already carried.

**B9** `.agents/audits/test-assertion-sweep-brief.md:40`

- rule: "or that leak dirs (create via other means)"

- fault: ambiguous procedure -- "other means" names none, and a leaked directory is a suite-end state that no assertion site shows. A per-assertion sweep cannot observe the evidence this clause asks for.

- recommendation: removal - the clause asks for evidence an assertion sweep does not have; a leak check belongs with whatever pass reads suite exit state.

**B10** `.agents/audits/test-assertion-sweep-brief.md:39`

- rule: "writes outside $FIXTURE_DIR/$FIXTURE_ROOT/get_fixture_dir"

- fault: ambiguous wording -- the list's third member is a function, not a location, so "writes outside get_fixture_dir" has no referent. The contract at :30 distinguishes the two kinds ("get_fixture_dir ... allocates extra fresh dirs"), so the fault is in this item's compression, not in the model.

- recommendation: mine: "writes outside $FIXTURE_DIR, $FIXTURE_ROOT, or a directory returned by get_fixture_dir".

**B11** `.agents/audits/test-assertion-sweep-brief.md:15`

- rule: "so the harness contract (subshell-per-test, fail-fast, unit accounting, the allocator, benign-rc masks, the order gate) is stated before the checklist."

- fault: ambiguous wording -- "the order gate" is undefined in the file and is asserted absent by :33 ("no order gate is needed"); no gate by that name remains in tests/ or scripts/. The term survives from the handovers that recorded it, so the list claims a contract item the surface does not hold.

- recommendation: removal of "the order gate" from the list - the other five members are each defined in the contract below it.

**B12** `.agents/audits/test-assertion-sweep-brief.md:17`

- rule: "Findings carry file:line, the offending code, the item violated, why it is a problem, and a concrete proposed fix."

- fault: redundant -- :47 states the same finding format, the same per-item summary and the same zero-violations rule; two copies of one instruction diverge as the format changes. :16 also quotes a rule the brief does not contain: "zero violations is an acceptable answer" appears nowhere in the brief, which says "If after a thorough sweep an item has zero violations, say so explicitly per item."

- recommendation: removal of the section's restatements -- :47 is the single site for the output format, and a quotation should be taken from the text it quotes.

**B13** `.agents/audits/test-assertion-sweep-brief.md:5`

- rule: "This is the U7 brief from M3.1, preserved as input for the future workflow review of the thermonuclear review prompt"

- fault: ambiguous procedure -- the purpose statement assigns the file a role in a later review instead of stating what a reader of this file does now, so the surface's own scope is undecidable. The forward-looking role is also a claim about work no task holds; the roadmap row it cites (devlog/roadmap.md:158) tracks the framing fixes, not this file's consumption.

- recommendation: mine: "Scope: a report-only review brief for one sweep of the assertions in tests/test_*.sh." plus the provenance kept as a single pointer line.

**B14** `.agents/audits/test-assertion-sweep-brief.md:47`

- rule: "Report findings grouped by checklist item."

- fault: ambiguous wording -- the list the report is grouped by is named "the authoring bar" at :35 and "these"; "the checklist" is used only in the preamble's commentary. One list, three names, so the reviewer has to infer that "checklist item" and "authoring-bar item" are one thing.

- recommendation: mine: "Report findings grouped by authoring-bar item." -- the name the section itself carries.

## What this record awaits

The ruling, one per site, by the operator. It is owned by the roadmap row **The corpus census over every review-instruction carrier**, which reads this record as its evidence and turns the rulings into the fate table; handover `20261026-04` carries that unit. The lists are evidence and not a verdict: no item here has been screened, and nothing in this record states which of two recommendations wins.
