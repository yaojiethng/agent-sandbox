# Skill Collision Delegation

**Current:** 2026-11-01

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | The loader owns the load set | A name held twice in the set a session loads is pi's to resolve and report, at startup, with both paths |
| R2 | The tree owns its four layers | Over the layers this repository declares, a collision is a defect we can fix, and the generated map reports it as a hard finding at review time |
| R3 | A reader can act on what pi prints | The output names both paths, which one loaded, and the lever that changes the outcome |
| R4 | The answer comes from the owner | A collision report, filter or reordering of installed bytes is not built here; a gap in pi's output is filed against pi |

## 2026-11-01 -- The loader owns the load set; the tree owns its four layers

**Decision:** A skill name held twice in the session's load set is pi's to resolve and report.

The load set is pi's: the user root, the project root, then each package in settings order, first path wins, as [`agent_workflow.md`](../reference/agent_workflow.md) states. The losers survive as `collision` diagnostics carrying `name`, `winnerPath` and `loserPath`, and the interactive interface prints them at startup as `[Skill conflicts]`, ticking the winner and marking each loser as skipped. That block is the surface pi's own skills page, `docs/skills.md` in the installed package, names when validating a skill. It prints whether or not a quiet startup hides the resource listing; that reading comes from the interactive mode source rather than the settings page, so a bump should re-read it.

What a resolver needs: the two paths from the diagnostic, the winner, which is the earlier of them, and two levers, the project's package list and the skill's name. Choosing between the levers is the operator's reading.

**Rationale:** A second resolver copies the owner's precedence, and this one had drifted before it was deleted: it compared the committed tree against the image copy of the same payload, so every pair it formed was a build input against a build output and none could collide. The loader already holds the precedence and both paths, and applies them before harness code runs. The map stays because it answers a different question over a set we author.

**Rejected alternatives:**

### A harness-side report at session start

Rejected on R4, on intent. Built twice, then deleted. It restated a block pi prints at every start, and to do that it invented a vocabulary the owner lacks: which copy is ours, which the project added. That classification produced the false pairs, and it exists only because the report existed.

### A preflight relay for headless runs

Rejected as the wrong addressee, on execution. Print, JSON and RPC modes carry no resource diagnostics, so a `--print` run or a dispatched worker sees no conflict. A relay would carry pi's formatting forever and go stale with it; the gap is one line of pi's output and is filed against pi.

### Delete the shipped names from an installed package

Rejected on R1, on intent. It rewrites bytes this repository did not author to defend a rank the loader already applied. The same shape was designed, reviewed and withdrawn on 2026-10-31.

**Edge cases / drivers:** A default session loads two copies of our own payload, the provisioned home and the image package, so every start prints conflict lines for them; that is the seeding, and its own row owns the fix. A worker in a task worktree loads that worktree's project layer, so a conflict there is invisible to the parent session, which is one gap the upstream row covers. A project that shadows a shipped skill on purpose still meets pi's warning, and changes its own package list.
