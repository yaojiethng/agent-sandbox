# Git commit history commons

**Current:** 2026-11-14

## 2026-11-14 -- The commit history is a commons

**Decision:** The `git-discipline` convention leads from the commit history as a commons: legible, honest, cheap to amend, with the working tree as its boundary. The subject is 72 at most, targeting 50 -- 50 is the scanning length, 72 leaves the short sha room on an 80-column line. The body stays 280. The type set, the fold and the no-instance rules hold; the working tree gains its rule from 2026-08-10.

**Evidence:** measured 2026-11-14 over 1,458 commits: 39% of the last 300 non-merge subjects exceed 50 and 3% exceed 72; 17% of those bodies exceed 280; 99% of those commits carry an active type. Two failures produced rules: a `git restore` over a dirty file destroyed uncommitted work, and the change prompts mirrored host verbs.

**Rejected alternatives:** keep 50 -- execution failure, ignored by 39%; drop the numeric budgets -- intent, an unchecked rule stops nothing; move the primitives to a prompt -- intent, a second surface; split the convention -- intent, one subject.

**Edge cases / drivers:** a 51-72 subject is legal; a `wip:` intermediate is legal; 280 is one paragraph; published history is never rewritten.
