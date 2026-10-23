---
description: "Draft - define the seat contract once: the table schema and validator, the pure resolver, the two runtime adapters, and the dispatch record. States the six places the complexity actually lives, with the measurement that re-derives them, so a reader with no access to the session that wrote this can re-check it against the current tree."
argument-hint: "[scope - contract, migration, or both - optional]"
---

> $@

# The Seat Contract

## The problem

A dispatch is one operation in the operator's model. Nothing in the repository defines a seat, so each caller derives it differently, and the callers disagree. A seat is one process invocation.

Measured on 2026-10-20 by the census described under `## The measurement`.

- The reviewer dispatch pins two pairs in its own script, `glm|openrouter|z-ai/glm-5.3-flash|high` and `step5|opencode-go|step-5-preview-free|high`, beside the skill. Both are off-list. It is called a special case, and it is the only multi-seat dispatch in the tree.
- The seam accepts a bare model override and uses it verbatim, with no check against the role and no record. `src/libs/dispatch.sh:163`.
- The advisor prompt tells the reader to follow a routing clause on the `_ADVISOR` line. The operator's line carries three ordered candidates and no routing clause. The reader finds nothing to follow.
- Eight instruction lines pair a role with a concrete pair in one line. Six of the pairs are off-list.

## Why the rule looks simple and is not

1. Two runtimes with different contracts. `pi` matches `--model` as a substring and takes the last hit. `opencode run` keeps an event subscription open after a refusal unless it is given `--print-logs --log-level ERROR`.
2. The operator's rule projects three axes onto one. Provider namespace, serving runtime and entitlement are separate, and today the free tier and the CLI coincide.
3. The highest-leverage input has no validator. The role table is gitignored, mounted, and editable between sessions. Its header line matches a role regex, the seam honours only the first `;` entry while a skill splits on all of them, and a stale line reports `refusing: every candidate failed` with no remedy.
4. Nobody has counted the seats. A census of instruction lines found 47, which is a proxy. The population of dispatch sites is unknown.
5. Availability is runtime state and the table states preference. `403 FreeTierError`, `429 GoUsageLimitError`, `401 API key expired` and quota exhaustion arrive through one error channel, so each caller improvises a ladder.
6. The operator override is the normal path and the seam treats it as the exception.

## The three axes

| Axis | Values in this tree | Decided by |
|---|---|---|
| provider namespace | `deepseek`, `opencode`, `opencode-go`, `openrouter`, `failover` | the id's prefix |
| serving runtime | `pi`, `opencode` CLI | `DISPATCH_OPENCODE_PROVIDERS`, which is `opencode` only |
| entitlement | app-session free tier, go tier, paid key, expired key | runtime state |

The operating rule, correct for every case met so far, is that an `opencode/` pair runs through `opencode run` and every other provider runs through `pi`, strictly, with no `settings.json` fallback for a seat.

## The work

```text
Define the seat contract once, prove it against this tree, and leave the
migration of old call sites as a separate unit. No edit to the operator's
recommendation file. Strict: no settings.json fallback for a seat.

1. Count the seats. Write one rerunnable inventory over every dispatch site,
   including $AGENT_HOME/agent/skills, that reports each site with the form it
   uses (role, pair, neither) and whether it resolves through the seam. The unit
   is the seat, not the line. Report the count and the unlisted sites.

2. Name the three axes as data before writing logic. Provider namespace, serving
   runtime and entitlement. State which values exist today, evidence for each,
   and where the operator's rule ("opencode-free only through opencode,
   otherwise prefer pi") is a projection that would break. Keep the projection
   for the first slice, and record the cases it does not cover.

3. Write the table schema and its validator first. The validator refuses a
   header line, a duplicate role, an empty entry, an unknown role, a malformed
   pair, and a trailing space before the colon. Run it against the operator's
   real file and report the result. It is a gate, not a script.

4. Write the resolver as a pure function: table, role, seat, override in, a seat
   record or a named refusal out. Five refusal codes. Property tests asserting
   no third outcome.

5. Write the two adapters as the only place that knows a runtime's quirks, each
   with golden argv tests and one captured live failure: pi's substring model
   match, opencode's event-subscription hang and its stderr level.

6. Emit the dispatch record at spawn and join it against the session files. Show
   effective equal to resolved for a set of real runs.

7. Prove it. Validator on the real file plus every fixture. Inventory with zero
   unlisted sites. Resolver property tests. Golden argv and the two live
   failures. The join over real runs. A red-team attempt refused. A fresh
   reviewer's verdict against these criteria, with attribution.

Out of scope: migrating the 47 instruction lines, deleting the reviewer's pinned
pair, and the advisor prompt's routing clause. Those are the next unit, and they
wait for this contract to hold.
```

## The seat contract, as logic

```text
resolve(role, seat, brief, operator) -> Seat | Refusal

  if role = "" or brief = "" or seat < 1:
      refuse("missing-argument", the.first_empty_one)

  if operator.pair is given:
      entry, source = operator.pair_at_level, "operator"
      if operator.quote = "":  refuse("operator-unquoted", role)
  else:
      if not exists(TABLE):    refuse("unresolvable", role, "table")
      entry, source = candidate(role, seat), "role"

  if entry = null:             refuse("unresolvable", role, seat)
  pair, level = parse(entry)
  if pair = null:              refuse("malformed", entry)

  record = { role, seat, pair, level, source, quote: operator.quote,
             backend: BACKEND(pair.provider), session, effective: null }

  spawn(record)
  record.effective = read_session_model(record.session)
  if record.effective != pair:  record.refusal = "effective-mismatch"
  return record


candidate(role, seat) -> entry | null
  line = first line matching /^role:/        # anchored, case-sensitive
  if line = null:            return null     # no line, unknown role, mistyped role
  entries = split(rest(line), ";")
  if seat > len(entries):    return null     # seat out of range, empty entry
  return entries[seat]
```

Four no-entry causes collapse into one null producer and one refusal. The closed role set leaves the seam and becomes a table check, because a typo has no line anyway.

## The measurement

47 instruction lines carry a model-selection decision. 21 name a role alone, 10 pair a role with a concrete pair, 16 name a dispatch command with no value, and none is a bare literal. Six of the 15 concrete pairs are off-list, and every off-list pair sits on a role-and-pair line.

The census lives in the session that wrote this draft and is not committed. To re-derive it, scan `workflow/`, `.agents/drafts/`, `.agents/prompts/`, `src/**/skills/`, `docs/` and `AGENTS.md` for `--model`, `--provider`, `dispatch_role_model`, a role tag, and a `provider/model` id, then compare each id against the operator's table.

## The quick win

Before the contract lands, one sentence in the provider-layer `AGENTS.md` "Which model" block removes the ambiguity that produced the incident: a dispatched seat resolves only from `$AGENT_HOME/model-recommendations.md`, an agent composes no pair, and the brief records the role, the pair and the level. Two mechanical deletions go with it, both landed ahead of this unit: the reviewer script's pinned pairs (Handover `20261023-02`) and the advisor prompt's dead routing clause (Handover `20261023-01`). The eight draft lines can wait for the migration unit.

The `_REVIEWER` line carries three candidates from one family, so the reviewer's two-family constraint has no source in the table. The runner carries no pair at all now, so the constraint is a table gap for the migration unit.

## Records this depends on

- [`single_source_model_recommendations.md`](../../docs/adr/single_source_model_recommendations.md), which owns the role file and its requirements.
- [`dispatch.sh`](../../src/libs/dispatch.sh), the seam the resolver replaces.
- [`review-dispatch.sh`](../../src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh), the one multi-seat dispatch.
- [`close-the-model-bypass-run.md`](close-the-model-bypass-run.md), which states the incident class this contract removes.
