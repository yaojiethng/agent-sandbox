---
name: command-surface-matrix
description: Build the documented command surface matrix from the ADR taxonomy table and report each command's repository artifact, shipped status and naming roadmap row. Use when a document asserts a command exists, when a dispatch prompt is added, moved or retired, or at a milestone close.
---

# Command surface matrix

**Status:** draft. The operator has not reviewed this skill.

## What it answers

Three questions per documented command, in one table. Does the artifact exist where the ADR says it does. Does it ship to the runtime prompt root. Which roadmap task row names it.

The failure this catches is a documented command an operator cannot invoke, or a documented artifact path that no longer resolves. Both are invisible in the records, because a record describes the surface and no gate reads the description.

## Method

1. Read the taxonomy table in `docs/adr/coding_agent_loop_workflow.md`. Each row holds a command, a kind, and an artifact cell.
2. Take the backticked path from the artifact cell and resolve it against the repository root.
3. Read `src/build/container-interface.json`. Take the cell whose `sources` names `workflow/coding-agent/prompts/` and read its `runtime_path`. The gate's own declaration is the source of the shipped root, never a literal in the script.
4. Check the file's basename under that runtime path.
5. Scan `devlog/roadmap.md` and `devlog/roadmap_future.md` for a task bullet naming the command in a code span, and report its milestone and state. The join is a locating aid, not a claim of ownership, so the column is labelled as such.

## Run

```bash
node .agents/drafts/command-surface-matrix/matrix.mjs
node .agents/drafts/command-surface-matrix/matrix.mjs --strict
```

`--strict` exits 1 when a documented command has a repository artifact that neither ships nor carries a legitimate exemption. Use it as a gate once the skill is promoted. Without the flag it prints and exits 0, which is the reading mode.

## Reading a NO and a ?

A `shipped NO` row is not automatically a defect. It is legitimate in two cases.

- The ADR artifact cell declares the artifact a draft. A draft is structurally unreachable by design, which is the point of the draft gate. The draft must still exist in the tree; a declared draft with no file is a finding.
- The naming task row sits in `roadmap_future.md`. An unbuilt milestone owns an unbuilt command, and a documented path that does not resolve yet is legitimate for that row alone.

Anything else is a finding. A command with a live path in the ADR and no file in the runtime root is documented and unavailable.

A `?` means the runtime root named in the manifest does not exist on this machine. The tool then reports the shipped column as unchecked and raises no shipped-based finding. It does not report `NO`, because a host without the container cannot tell absence from a missing mount. The note under the table names the absent root.

## The exclusion question

To prove a tree is outside a gate rather than assume it from a comment, use the gate's own seam. Copy `src/build/container-interface.json` into a throwaway directory at `src/build/container-interface.json`, add the tree under test to a cell's `sources`, then run the gate with `FRONTMATTER_MANIFEST_ROOT` pointing at that directory. The file count rises by the number of Markdown files in the tree. The count with the real manifest is the baseline. Both numbers are observations. A `git grep` for the path is not, because a comment can name a tree the declaration excludes.

## What this does not answer

Whether a prompt's prose is true. A stub can be correctly unshipped and still claim that it fails closed, routes somewhere, or keeps a keyword safe. The matrix reports availability, and availability is not behavior. Pair it with a claims audit that lifts each normative claim into a row with the command that checks it. Record a claim of the form "this refuses an out-of-order list" as unverifiable until a runtime executes it, because no file's presence can make that sentence true.

## Neighbouring gates

`scripts/check_container_layout.sh` holds the manifest to the dockerfiles and the provider settings. `scripts/check_instruction_surfaces.sh` holds the two `AGENTS.md` layer tables and the loop inventory to their sources. `scripts/check_frontmatter.sh` parses every live prompt, skill and policy block. None of them reads the ADR taxonomy table, so a documented command with no artifact passes all three.

## Promotion

The draft gate's release is a move. After operator review, `git mv .agents/drafts/command-surface-matrix .agents/skills/command-surface-matrix`, then run `bash scripts/lint.sh`. The runtime path and repository root are derived, so the script needs no edit at its new home.
