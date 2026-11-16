# Git commit history commons

**Current:** 2026-11-16

## 2026-11-14 -- The commit history is a commons

**Decision:** The `git-discipline` skill leads from the commit history as a commons: legible, honest, cheap to amend, with the working tree as its boundary. The subject is 72 at most, targeting 50 -- 50 is the scanning length, 72 leaves the short sha room on an 80-column line. The type set, the fold and the no-instance rules hold; the working tree gains its rule from 2026-08-10. The four properties the series section states -- atomic, bisectable, self-explanatory and blameable -- were derived from what the history's readers depend on it for: the operator at the accept (one ordered series), review (one unit and its reason per commit), a peer holding the series alone (it explains itself), archaeology (where a line came from), a bisect (which commit broke it), the next session (the branch's state), and the changelog (what shipped). The skill states the properties; this record keeps the reasoning that produced them.

**Evidence:** measured 2026-11-14 over 1,458 commits: 39% of the last 300 non-merge subjects exceed 50 and 3% exceed 72; 17% of those bodies exceed 280; 99% of those commits carry an active type. Two failures produced rules: a `git restore` over a dirty file destroyed uncommitted work, and the change prompts mirrored host verbs.

**Rejected alternatives:** keep 50 -- execution failure, ignored by 39%; drop the numeric budgets -- intent, an unchecked rule stops nothing; move the primitives to a prompt -- intent, a second surface; split the skill -- intent, one subject.

**Edge cases / drivers:** a 51-72 subject is legal; a `wip:` intermediate is legal; published history is never rewritten.

## 2026-11-14 -- The message budgets buy display and reading, not review cost

**Decision:** The three numbers keep, and each states what it buys. 50 is the subject's scan target: the corpus median, named to pull the distribution rather than to fence it. 72 is the subject's ceiling: an 80-column line minus the short sha and its space. 280 is the body's bound: four 72-column lines of prose. Their provenance is Pope's 2008 note for 50 and for 72 -- reused there from the body wrap, not given as a subject rule -- and this project for 280. Google's small-CL guidance and the SmartBear review rate bound the diff, not the message; no source maps a review rate to characters of prose, and no message-length number is derived from them. The body is bounded by characters alone; no paragraphing rule applies to it.

**Evidence:** the last 300 non-merge commits: subject median 48, p25 42, p75 58, p90 65, with 117 over 50 and 10 over 72; body paragraphs median 67, p90 263. The `--oneline` prefix is 8 characters in this repository, so a 72-character subject makes an 81-column line: the ceiling fits a seven-character sha, and the one-column overrun is accepted rather than tightening a number the world shares.

**Rejected alternatives:** tighten the subject to 50 -- execution failure, 39% miss it; raise it to 80 -- intent, the ceiling is the display line; derive the body's bound from the review rate -- intent, there is no mapping; drop the numbers -- intent, an unchecked budget stops nothing.

**Edge cases / drivers:** a 51-72 subject is legal; a body over 280 points at the handover; a wider sha overruns the line by one column.

## 2026-11-14 -- The working tree is where the session's work is not saved

**Decision:** The skill carries one working-tree section, and its mechanism is the record. Work that no ref holds is the session's alone, and the skill's five discarding verbs take it. The section states a four-step discard -- read, save, run, confirm -- so the save precedes the verb rather than following a warning. A mutation the session made itself is the case a copy aside serves, because those verbs restore HEAD rather than the state before the edit.

**Evidence:** two occurrences. `[A] 2026-08-10` -- `git restore scripts/stop.sh`, run to undo a test mutation, reverted a session's uncommitted refactor -- and its recurrence, `git checkout .markdownlint-cli2.mjs` run to recover a fixture, which dropped `doc-wrap` from the lint config and left a gate measuring nothing.

**Rejected alternatives:** a gate over `scripts/` -- intent, it catches a script that discards a tree and not the agent who types the verb, and both occurrences are the latter; a wrapper the agent must call -- intent, `git` stays one keystroke away and the forgetful path bypasses it; a blanket ban on git while work is uncommitted -- intent, it forbids the backup branch that is the save.

**Edge cases / drivers:** a stash is saved until `drop`; a fixture repository's own commits are its save; the outer tree is never a discard's target.

## 2026-11-16 -- The series is the cleanup's, not the commit's

**Decision:** `history-cleanup` is a change-pipeline workflow, not a branch-preparation primitive beside `prepare`. Its granularity is a feature branch and its consumer the PR or merge-request reviewer; its input is a commit range and its output a range conforming to six sequence properties: complete at every point, one unit per commit, a reviewable order, a bisectable path, records true at their commit, and origin surviving the rewrite. The skill keeps the four per-commit properties and declares the boundary: a commit is judged alone; the series is the cleanup's pass. `prepare` owns trunk alignment, and the host's one-commit delivery is the pipeline's squash, a different consumer. The two are independent: either can run on its own, and running both is two separate operator calls.

**Rationale:** a commit cannot know its successors. Making every commit read its neighbours spends O(n) agent turns and tokens per commit instead of once at the cleanup, and the full range exists only there. The skill's four properties are local at write time; the sequence properties are global and belong to the one pass that has the evidence. Self-explanatory means standalone, so a commit does not carry the sequence's readability. The earlier primitive frame hid the consumer and let the skill restate the commit rules and `prepare`.

**Evidence:** the skill measured 182 lines, restating the four properties, the rebase and gate of `prepare`, and the audit's eight checks. The audit's check 4 excluded only the handover root, so a roadmap, feedback or discussion delta at the tip read as non-record content; its `--addition` exclude began with an empty alternative, which disabled the content proof whenever an addition was named.

**Rejected alternatives:** declare the sequence properties in the skill -- intent failure, it makes them a per-commit obligation that is unknowable; make each commit read its neighbours -- intent failure, the successors do not exist yet and the cost is O(n) per commit; keep the primitive frame -- intent failure, the consumer is the reviewer and the overlap with the skill and `prepare` is duplication; prescribe the rewrite mechanism -- intent failure, the invariant is the output and the method is the agent's; serve the host's one-commit delivery -- intent failure, the cleanup serves the PR reviewer and the squash is the pipeline's.

**Edge cases / drivers:** a stack's contiguity is `branching.md`'s, not the series'. The cleanup folds corrections, not introductions, so `git blame` keeps the origin. A record that a later commit retires is record noise. The branch point, the export and the draft are the change pipeline's; the cleanup's base stays the base.
