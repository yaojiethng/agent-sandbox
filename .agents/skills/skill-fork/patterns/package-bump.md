# Bump an installed package to a new upstream revision

Open this when the operator directs a bump of an installed package. The move is to move the checkout a package is loaded from to a reviewed upstream revision, keep the exclusion that protects a vendored name, and report what the new revision brings.

## The boundary

This pattern is the other carrier. [`vendor-bump.md`](vendor-bump.md) bumps an artifact this repository carries; here the repository carries a declaration and a session loads the text from the sandbox. Nothing in the tree changes when a package bumps, so there is no merge, no local copy and no base revision in the store.

A bump runs only when the operator directs it. An upstream commit is not a reason to bump.

**One name, one route.** A name an installed package provides cannot also be vendored until the package's entry excludes it and [`../../registry/sources/`](../../../registry/sources) holds its edge. So a bump that would land a name the store already holds an edge for is a conflict: extend the exclusion, do not let two copies compete.

## Where the declaration and the payload live

| What | Where | Committed |
|---|---|---|
| the declaration | `$AGENT_HOME/agent/settings.json`, in `packages`, object form | no, sandbox state |
| the payload | the clone at `$AGENT_HOME/agent/packages/<name>`, bind-mounted so it outlives a container | no, sandbox state |
| the revision | the clone's checkout | no; git holds it and this repository records nothing |

The repository records no revision, deliberately. A committed revision would make one sandbox's history a claim about every other sandbox, and each sandbox holds whatever was last checked out in it.

## Declare it

One entry, filtered. The paths in `skills` are relative to the **package root**, which is the directory the entry names:

```json
{
  "packages": [
    {
      "source": "./packages/pstack/pstack",
      "skills": ["-skills/<the name the store holds an edge for>"]
    }
  ]
}
```

| Filter form | Effect |
|---|---|
| `-skills/<name>` | excludes exactly that skill directory |
| `!skills/<name>/*` | excludes the same by glob |
| `-<name>` or `!<name>/*` | **matches nothing and reports nothing**: the path is relative to the package root, so `skills/` is part of it |

`pi list` prints the entry with `(filtered)` beside it, which confirms the entry is read as an object rather than a bare source. It does not confirm the pattern matches; only the count of loaded skills does.

## Procedure

1. **Find the declaration.** Read `$AGENT_HOME/agent/settings.json`, then run `pi list`. Done when the entry is present, is marked `(filtered)`, and you can state its source and its exclusions.

2. **Locate the payload.** Resolve the source against the settings file's directory, which is `$AGENT_HOME/agent`. Done when the path exists and `git -C <clone> rev-parse HEAD` prints a commit.

3. **Record what is installed now.** Note the current commit and the package's own version, for example `pstack/plugin.json`'s `version`, because the handover names the range. Done when both are written down.

4. **Move the checkout.** Run `git -C <clone> fetch origin` and `git -C <clone> checkout <new revision>`. Done when `rev-parse HEAD` is the new revision and the working tree is clean.

5. **Check the exclusion still lands.** Confirm each excluded name still exists at the new revision. A name upstream removed makes the filter a harmless no-op, which is acceptable; a name that is now the same as a newly vendored one is not, and it needs a new exclusion before the session loads. Done when every exclusion names a skill that exists, or is recorded as a no-op.

6. **Report what the revision changes.** List the skill names the new revision adds and removes against the ones installed before. Done when the handover names them, so the operator sees the capability the bump brings rather than a commit hash.

7. **Verify.** Run `node scripts/skill_packages.mjs` and confirm no package is absent and no local entry is reported, then `bash scripts/lint.sh` and `bash scripts/run_tests.sh`. Done when the report is clean and the gates are green.

8. **Record the run.** The handover names the package, the revision range, and the skills added and removed. Nothing is committed for the install itself; the clone and the settings entry are sandbox state.

If the clone is absent, clone it at the revision the operator names and continue from step 3. A fresh sandbox starts with an empty `packages/` folder, so this is the ordinary case on a new host rather than a repair.

## Failure stops

- The operator did not direct the bump.
- The declaration is absent, or its source does not resolve.
- The clone cannot be fetched, and the operator has not supplied a revision to clone.
- An exclusion no longer matches a name that now collides with the store's edges.
- The report names a package as absent after the bump.

Stop on any of these and report the condition. Do not edit the store, and do not vendor a name to make a collision go away.

## The test

Name the package, the revision range, and the skills the revision added. If any is missing, nothing was installed: the checkout moved and no one can say what arrived.
