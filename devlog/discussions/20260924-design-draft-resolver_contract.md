# Resolver Contract

**Status:** draft - first write, not yet reviewed. Awaits the operator's decision.

**Scope:** how a setting's value is decided from its sources - the ladder (explicit, environment, file, record, default), the leaf that evaluates it, and the failure contract when no level supplies a value. Declaration and transport are outside this note: the flag spec, the Make translator, the `.env` key, and the record field are a sibling problem, recorded in the read-through's rows 44 through 48 as the larger half of the configuration surface.

## Context

The phase 2 read-through found the same resolution rule re-implemented at every layer that reads a setting. Nine readers over four record shapes (row 22), a host-side `eval` of branch-derived text (row 38), `_cli_parse`'s five documented spec forms with two of them dead or wrong (rows 41 through 46), sixteen Make `$(if)` translators for one boolean convention (row 45), and `env_load`'s silent mis-parses of two common `.env` shapes (row 47). The surface is large: 165 environment variables, 13 CLI call sites, 16 translators, 8 `SESSION_STATE` keys, and five input surfaces that spell the same setting differently (row 48).

One path is better than the rest, and it is the identity triple. `env_resolve_one EXPLICIT ENVVAR KEY ENV_FILE` in `src/libs/env_resolve.sh` is 17 lines and already generic over the key: explicit value, then `AGENT_SANDBOX_<KEY>`, then the key in the `.env` file, then a hard error. [`docs/adr/env_resolution.md`](../../docs/adr/env_resolution.md) fixes the requirements it serves: one resolution path (R1), explicit wins (R2), no silent default (R3), only `AGENT_SANDBOX_*` counts as the environment level so a leaked plain export cannot bypass `.env` (R4), and a deterministic `.env` location (R5). Four properties follow, and no other reader in the tree has any of them: a declared ladder per setting, the two-level environment guard, a loud failure with a remedy, and resolution separated from use.

The same layer also shows what to avoid. `env_resolve_one`'s explicit branch is unreachable, because all three of its call sites pass an empty value and `env_resolve_identity` re-implements explicit-wins inline twice (finding 78). Its failure text is identity-specific inside a generic function, so adopting it for a fourth setting would advise re-onboarding when an unrelated setting is absent. Its composite exports 14 names, five of which merely re-assert what the resolver already exported (finding 72's measurement), and the orchestrator around it reads two inputs from the environment that its own signature does not declare.

The deepest tension is that `.env` holds two roles at once. As a config source, its keys are candidates in a ladder, and the clean mechanism already exists in the leaf: `_env_value` loads the file in a subshell, reads one key, and leaves the caller's environment untouched. As a runtime environment, its values must reach child processes, so the prelude uses `env_load` into the running shell and then patches the damage by re-asserting the identity triple after the load. The re-assert is the tax on the bulk load, and the tax grows with every setting the file may carry.

Two constraints from the read-through bound any design here. A resolution that cannot distinguish "absent" from "the tool could not run" must not return an empty value as a verdict (rows 60 and 68: two demonstrated wrong artifacts from that alias). And a rule stated in documentation but not held by either parser layer is a defect, not a doc fix (row 45: "0 means off" holds in the docs only).

## Options Considered

### Option area 1 - the scope of the ladder

**Option A - the identity triple only.** The status quo. Cost: the settings that already have a ladder keep four ad-hoc readers.

**Option B - the laddered settings.** The identity triple, the 8 `SESSION_STATE` keys (read by four shape-based readers today, rows 22, 39, 40), and the record-recovered settings on the resume path (`DELIVERY`, `FLATTEN`, the provider), whose real ladder is flag over record over default. About eleven settings. Cost: their failure contracts differ, so each adoption must state its own levels and its own remedy.

**Option C - every setting.** About 165. Rejected on two counts. Most settings have no error level: they have an unset-only default (`DELIVERY=copy`), a tri-state, or a `0`/`1` convention, so a hard-error ladder would change behaviour. And a resolver cannot deduplicate a spelling, so this would leave the defect mass of rows 41 through 48 untouched.

### Option area 2 - the leaf contract

**Option A - keep the current shape.** The leaf prints the value, prints its own error, and the caller redirects (command substitution). Cost: the failure text is hardcoded, the caller reads the value through a subshell, and the exportedness of the result is the caller's business, which is how the four-hop round trip in the prelude arises.

**Option B - a pure leaf with declared inputs.** The leaf takes the levels, the environment variable name, the file key, an optional default, and the failure remedy, and prints the resolved value on standard output. One implementation of the precedence rule, one place for the failure text, and a unit per level. Evidence that this is small: the primitive is already generic over the key, so only the levels and the remedy become parameters.

### Option area 3 - the `.env` dual role

**Option A - keep the bulk load and the re-assert.** Smallest change, and it preserves the runtime values the file carries. Cost: the re-assert must be repeated for every setting the file may carry, and the discipline is invisible to a caller that loads the file itself.

**Option B - resolve without loading.** Every setting resolves through the leaf, which reads the file per key in a subshell, and the function exports only the declared set. The re-assert disappears because nothing is loaded unbidden. Cost: the runtime values that `.env` carries today (provider variables, `SERVE_PORT`, `WORKTREE_DIR`) must be declared and exported explicitly, which is the declaration work this note defers.

**Option C - split the file.** A config file for the ladder and a runtime environment file for the exports. The clearest expression of the two roles, and the largest blast radius: `ENV_FILE` is referenced in 7 files, onboarding writes one file, and the Makefile includes it as make variables.

### Option area 4 - the levels

**Option A - the three levels that exist.** Explicit, `AGENT_SANDBOX_*`, file, then a hard error.

**Option B - a declared level list per setting.** Explicit, environment, file, record, default, with an explicit statement of when a default applies (unset only, or always) and what an empty string means. The record level has evidence behind it: the resume path already recovers `DELIVERY`, `FLATTEN`, and the provider from the record with the flag as the override, which is a ladder the resolver cannot express today.

### Option area 5 - the failure contract

**Option A - one message for every setting.** The status quo, and identity-specific in a generic function (finding 78).

**Option B - the remedy travels with the declaration.** Each setting names its own remedy and its own severity, and a resolution that cannot tell "absent" from "unreadable" fails loudly instead of returning empty.

### Option area 6 - the output surface

**Option A - exports as a side effect.** The status quo: 14 export statements in the identity prelude, five of them re-asserts, and nothing in the file enumerates the set.

**Option B - a declared, returned set.** The resolution step declares which names it produces and returns them once; the caller assigns and exports. This is what makes the module's effect on the shell answerable from the file.

### Option area 7 - the adoption order

**Option A - the record keys first.** Eight keys, four readers, and the only group with a security consequence: a value that reaches a host-side `eval` (row 38).

**Option B - the identity triple's own cleanup first.** Fix the bypassed primitive and complete the phase 2 signature (findings 78 and 72), which proves the leaf contract on the path that already has units before widening it.

**Option C - declaration first.** One declaration per setting, emitting the flag spec, the environment variable name, the `.env` key, and the Make translator. The larger half of the problem, and out of scope here.

## Decision

Proposed, not settled. The recommendation is Option B in areas 2, 4, 5, and 6, Option B in area 1, Option B in area 7, and no decision in area 3.

1. Generalise the leaf. The ladder, the levels, the default semantics, and the failure remedy become declared inputs, and the leaf stays pure: it prints the resolved value and holds no side effects.
2. Fix the bypass before widening the use. Pass the explicit value into `env_resolve_one` and take the remedy as an argument, so the primitive has one implementation and one caller contract.
3. Adopt the leaf for the laddered settings one group at a time, starting with the record keys, because that group carries the host-eval consequence.
4. State the level list and the default semantics at each adoption. A setting that fails when absent and a setting that falls back to a default must not look the same at the call site.
5. Keep the orchestrator shape local to the identity bootstrap. The two-phase prelude stays, with the two named repairs: complete phase 2's signature and delete the recomputation in `start_agent.sh`.
6. Do not decide the `.env` dual role here. It is the deepest option, and it depends on the declaration work: option B in area 3 is only reachable once the runtime values are declared.
7. The ADR home is `docs/adr/env_resolution.md`, which adds a dated entry for a settled decision, per its own header.

## Consequences

One implementation of the precedence rule replaces the ladder duplicated across readers, and the failure text becomes a property of the setting rather than of the code path. The record level is expressed instead of improvised, which is what lets the 8 record keys' four readers retire. The leaf becomes unit-testable per level, and the identity prelude's output surface becomes enumerable, so "what does this do to my shell" is answerable from the file.

This note does not remove the declaration and transport fragmentation (rows 44 through 48). That is the larger half of the configuration surface, and the resolver cannot substitute for it: a resolver picks a winner after a value has arrived by one of five paths, and it cannot make five spellings of one setting into one spelling.

The `.env` dual role stays open, so the re-assert discipline stays in place until it is decided. Option C in area 3 would change the file's contract, and `ENV_FILE` is referenced in 7 files plus the onboarding writer and the Makefile include, so that decision needs its own iteration and its own handover.

The main risk is a generalisation that reads as a no-op refactor while changing behaviour. Whether a missing setting fails or falls back depends on whether its level list contains a default, so each adoption must state that list explicitly and must pin it with a unit, or a silent default returns through the new front door.

Evidence and disposition live in [`20260924-design-active-test_suite_readthrough.md`](20260924-design-active-test_suite_readthrough.md): rows 7 and 22 (the reader families), rows 38 through 48 (parsing and declaration), row 72 (the two-phase interface), and row 78 (the bypassed primitive).
