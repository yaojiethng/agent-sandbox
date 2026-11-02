---
reader: [maintainer]
---

# Source Tracking

**Role:** Defines the tracking store for upstream-derived workflow artifacts, the shape of one source file, the CLI that writes it, and the boundary between the CLI and the merge agent.

The store answers one question: which upstream revision is this local artifact based on, and which revision will the next merge review? The local artifact stays in the tree and is authoritative. The store records the derivation edge; it does not build the artifact from the upstream.

## The store

The store is one JSON file per source at `.agents/registry/sources/<source-id>.json`. The filename is the source id. A source file is independent, so a fan-out can work one source without touching another.

The store is repository-only. It does not ship into the image; the image carries the artifacts, the per-skill records and the `NOTICE`. The store is the maintainer's input for the next update, not runtime data.

The live store holds the three sources and eight edges. The source catalog is retired; the eight forked records name the store and the shipped `NOTICE`.

## The source file

A source file holds the source facts and the artifact edges. It holds no hashes, no patch and no adaptation prose.

| Field | Required | Meaning |
|---|---|---|
| `schema` | yes | The store schema, currently `1`. |
| `id` | yes | The source id; it matches the filename. |
| `url` | yes | The upstream repository URL, as an `https` URL. |
| `license` | yes | The upstream license name. |
| `copyright` | yes | The upstream copyright line. |
| `reason` | only when `artifacts` is empty | Why the source has no artifact in this repository. |
| `artifacts` | yes | The artifact edges, sorted by `local_path`. |

An empty source carries `artifacts: []` and a non-empty `reason`. It carries no `status` field: the source is a row a reader can find, and the reason is what makes the empty row meaningful. A non-empty source carries no `reason`.

The source file shape, with one edge:

<!-- snippet: illustrative -->
```json
{
  "schema": 1,
  "id": "example-source",
  "url": "https://github.com/example/skills",
  "license": "MIT",
  "copyright": "Copyright Example",
  "artifacts": [
    {
      "local_path": "src/reasoning/agent/skills/example",
      "kind": "skill",
      "parent": null,
      "upstream_path": "skills/example",
      "origin": "1111111111111111111111111111111111111111",
      "base": "2222222222222222222222222222222222222222"
    }
  ]
}
```

## The artifact edge

An artifact edge names one local artifact, the upstream path it came from, and the two commits that make the merge reproducible.

| Field | Meaning |
|---|---|
| `local_path` | The artifact path from the repository root. |
| `kind` | `skill`, `runbook` or `prompt`. |
| `parent` | The owning skill path for a runbook; `null` for a skill or a prompt. |
| `upstream_path` | The artifact path in the upstream repository. |
| `origin` | The revision the artifact was first taken from. It never changes. |
| `base` | The upstream revision the next merge reviews. It moves after every reviewed update. |

A skill and a runbook are directories with a `SKILL.md`; a prompt is a file. A runbook names its parent; a prompt names none. The CLI checks the local path against the kind, so a prompt cannot claim a directory and a skill cannot claim a loose file.

`origin` and `base` are full 40-character commits. The two are equal at the first fork. A merge moves `base` to the reviewed upstream revision and leaves `origin` alone. The design doc, not this store, records the adaptations and the reason a change was kept or rejected.

## The CLI

The `source-bump` command is the only writer of the tracking file. It validates before it writes, and it writes the file atomically, so a refused update leaves the previous file in place.

| Command | Writes the store | Purpose |
|---|---|---|
| `source-bump check` | no | Validate every source file, every edge and every local path. |
| `source-bump add` | yes | Create a source, create an empty source, or append one edge. |
| `source-bump diff` | no | Print the stored `base -> local` change from a local clone. |
| `source-bump prepare` | no | Create a temporary `base`, `ours` and `theirs` workspace from a local clone. |
| `source-bump record` | yes | Move one edge's `base`; `origin` is preserved. |

`add` takes the source facts only when it creates the source. An existing source refuses a changed `url`, `license` or `copyright`; changing source facts is a separate decision. `add --empty` creates an empty source and requires its reason. `record` requires an existing source and an existing edge; it does not create either.

The command never fetches and the `check` command never reads the network. A source file whose upstream is unavailable still checks against the local paths and the recorded facts. `diff` and `prepare` take a local upstream clone; they do not update it. `source-bump check` is a validation command, not a lint gate. A bump runs only when the operator directs it, and the store stays pinned by default.

<!-- snippet: illustrative -->
```text
source-bump check --store .agents/registry/sources
source-bump add --source example-source --url https://github.com/example/skills --license MIT --copyright "Copyright Example" --local src/reasoning/agent/skills/example --kind skill --upstream skills/example --origin <commit> --base <commit>
source-bump diff --source example-source --local src/reasoning/agent/skills/example --clone <clone>
source-bump prepare --source example-source --local src/reasoning/agent/skills/example --clone <clone> --revision <commit>
source-bump record --source example-source --local src/reasoning/agent/skills/example --base <commit>
```

The merge workspace is temporary; the local artifact stays the editable copy. The merge agent owns the conflict resolution; this CLI owns the three inputs and the facts around them. The procedure that uses the commands is the [`source-bump` skill](../../.agents/skills/source-bump/SKILL.md).

## The agent and the CLI

| Owner | Writes |
|---|---|
| `source-bump` CLI | the source file: source facts, artifact edges, `origin` and `base` |
| Merge agent | the local artifact and the design doc |
| Operator | the decision to take an upstream revision and the disposition of a conflict |

The tracking file and the design doc are separate artifacts. The tracking file holds machine state; the design doc holds prose: the intent, the essential changes, the rejected options and the conflict areas. Putting the design prose in the tracking file would repeat the mixed record the redesign removes.

A manual edit to the tracking file is a defect even when the result parses. The CLI canonicalizes the order and validates every write; an edit the CLI did not make has no such check.

## What the store does not hold

The store does not hold a local or upstream hash. A hash is derived from the artifact and goes stale on every edit; the merge review is what decides whether the local file still matches the upstream intent.

It does not hold a patch. The diff is generated from `base` and the local artifact for the review, and applying it to a new upstream is a three-way merge, not a stored patch queue.

It does not hold the adaptation prose, the design rationale or a status. Those belong to the design doc and the tree; a structured file that also carries prose cannot be validated by the CLI.

It does not hold the artifact itself. The local tree remains authoritative and editable while the maintenance work runs.

## Migration

The migration has created the live source files with `add` and `add --empty`, moved the five forked edges, retired `source-catalog.json`, and pointed the five records at the store and the shipped `NOTICE`. The record gate checks the records and the known source ids. `source-bump check` stays outside lint; a bump runs only when the operator directs it, and the store stays pinned by default.
