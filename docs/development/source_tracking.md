---
reader: [maintainer]
---

# Source Tracking

**Role:** Defines the tracking store for upstream-derived workflow artifacts, the shape of one source file, the gate that holds it valid, and the boundary between the maintainer and the merge agent.

The store answers one question: which upstream revision is this local artifact based on, and which revision will the next merge review? The local artifact stays in the tree and is authoritative. The store records the derivation edge; it does not build the artifact from the upstream.

## The store

The store is one JSON file per source at `.agents/registry/sources/<source-id>.json`. The filename is the source id. A source file is independent, so a fan-out can work one source without touching another.

The store is repository-only. It does not ship into the image; the image carries the artifacts and the `NOTICE`. The store is the maintainer's input for the next update, not runtime data.

The store is bump data, and it is opt-in. An edge exists because someone keeps that artifact current against an upstream; a path with no edge is a path nobody bumps, and nothing requires one. The artifact carries no record of its own and no provenance line, so the store is where a maintainer looks. The source catalog is retired.

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
| `artifacts` | yes | The artifact edges, sorted by address. |

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
| `kind` | `skill`, `runbook`, `prompt` or `instruction`. |
| `parent` | The owning skill path for a runbook; `null` for everything else. |
| `upstream_path` | The artifact path in the upstream repository. |
| `origin` | The revision the artifact was first taken from. It never changes. |
| `base` | The upstream revision the next merge reviews. It moves after every reviewed update. |
| `anchor` | A verbatim line of `local_path`, present only when the edge covers a passage rather than the whole file. |
| `record` | The adaptation note, whose fields are `name`, `source`, `kept`, `rewritten`, `added` and `dropped`, each optional. |

A skill and a runbook are directories with a `SKILL.md`; a prompt and an instruction are files. A runbook names its parent; nothing else names one. The gate checks the local path against the kind, so a prompt cannot claim a directory and a skill cannot claim a loose file, and it checks an `anchor` occurs exactly once in the file it names, so a passage edge that has drifted is a finding.

`origin` and `base` are full 40-character commits. The two are equal at the first fork. A merge moves `base` to the reviewed upstream revision and leaves `origin` alone, because a base left at the fork point would report the upstream changes as local edits at the next merge and replay or conflict them a second time. The adaptation note is what the merge review reads before it starts: the fields name what the fork kept, changed, added and left out, and why. The design doc still holds the intent the note does not carry.

One artifact may carry several edges, one per source: a skill built from three upstream skills has three contributions to describe, and each edge carries its own note. The address of an edge is the source, the `local_path` and the `anchor` together, and two edges in one source may not share it.

## The CLI

The store is edited by hand. The gate in [`check_skill_sources.sh`](../../scripts/check_skill_sources.sh) validates every file and holds its canonical form, and the CLI carries the merge instruments and the two commands that report or repair the store without inventing a field: `check` prints what the gate would, and `format` writes the canonical form.

| Command | Writes the store | Purpose |
|---|---|---|
| `source-bump check` | no | Print every finding the gate holds: the schema, the edges, the paths and the canonical form. |
| `source-bump format` | canonical form only | Rewrite each file in sorted, fixed-key-order, two-space form; a field value is never set. |
| `source-bump diff` | no | Print the stored `base -> local` change from a local clone. |
| `source-bump prepare` | no | Create a temporary `base`, `ours` and `theirs` workspace from a local clone. |

A source fact changes only by an operator decision, and review is what catches a change to `url`, `license` or `copyright`: nothing derives them, so no check can tell a deliberate edit from an accidental one.

The commands never fetch and `check` never reads the network. A source file whose upstream is unavailable still checks against the local paths and the recorded facts. `diff` and `prepare` take a local upstream clone; they do not update it. A bump runs only when the operator directs it, and the store stays pinned by default.

<!-- snippet: illustrative -->
```text
source-bump check --store .agents/registry/sources
source-bump format --store .agents/registry/sources
source-bump diff --source example-source --local src/reasoning/agent/skills/example --clone <clone>
source-bump prepare --source example-source --local src/reasoning/agent/skills/example --clone <clone> --revision <commit>
```

The merge workspace is temporary; the local artifact stays the editable copy. The merge agent owns the conflict resolution; these commands own the three inputs and the facts around them. The procedure that uses the commands is [`skill-fork/patterns/vendor-bump.md`](../../.agents/skills/skill-fork/patterns/vendor-bump.md).

## The agent and the store

| Owner | Writes |
|---|---|
| The agent | the source file: source facts, artifact edges, `origin`, `base` and the adaptation note |
| Merge agent | the local artifact and the design doc |
| Operator | the decision to take an upstream revision and the disposition of a conflict |

The gate is the store's validator, so an edit is judged by what it produced rather than by which command produced it. It runs on every commit, which is the coverage a write path cannot give: a merge, a rebase and a hand edit all arrive at the same check.

The tracking file and the design doc are separate artifacts. The tracking file holds machine state; the design doc holds prose: the intent, the essential changes, the rejected options and the conflict areas. Putting the design prose in the tracking file would repeat the mixed record the redesign removes.

A hand edit is the normal route, and `source-bump format` brings a file to canonical form. An edit that changed a field value is a review question, not a gate finding.

## What the store does not hold

The store does not hold a local or upstream hash. A hash is derived from the artifact and goes stale on every edit; the merge review is what decides whether the local file still matches the upstream intent.

It does not hold a patch. The diff is generated from `base` and the local artifact for the review, and applying it to a new upstream is a three-way merge, not a stored patch queue.

It does not hold the design rationale or a status. The adaptation note is bounded to six named fields, so it stays checkable; the reasoning behind the fork is the design doc's, and the artifact's own text is the tree's.

It does not hold the artifact itself. The local tree remains authoritative and editable while the maintenance work runs.

It does not hold an installed package. Upstream text that arrives as a pi package is loaded from a clone under the sandbox home, and the repository carries only the declaration; its bump is [`skill-fork/patterns/package-bump.md`](../../.agents/skills/skill-fork/patterns/package-bump.md), and `scripts/skill_packages.mjs` reports a package whose path is gone.

## Citations

A citation is a source this repository reads but does not carry: a standard, a paper, a specification. It is not a forked source, and it lives apart from the store because the two have different validity rules. A fork's edge must resolve against the tree and a forty-character pin. A citation resolves to a document somebody else publishes, and its pin is a version or a date.

One file per citation, at `.agents/registry/citations/<id>.json`:

| Field | Holds |
|---|---|
| `id` | the filename stem, and the name a citing document uses |
| `title`, `author`, `publisher` | what identifies the document to a reader who must find it |
| `url` | the canonical address, checked against the network when the citation is written |
| `version` | the revision read, because an address alone pins nothing |
| `record` | `source`, `kept`, `rewritten`, `added`, `dropped`, in the vocabulary the store's edges use |

Nothing validates these files. The store's gate exists to resolve a pin against a git tree, and a citation has no tree; a validator written over three examples would encode a guess. What keeps a citation honest is its `version` and its `record`, and what keeps it current is a reader who follows the address.

The citation file does not list the documents that cite it. The arrow runs one way, as it does for the store: the citing text names the source, so a second document can adopt the same citation without an edit here.

## Migration

The migration created the live source files, moved the forked edges and retired `source-catalog.json`. On 2026-11-01 the fourteen per-artifact `MAINTENANCE.md` records left the tree: eight became edges with their adaptation note, one passage edge was added for the ladder in the pi `AGENTS.md`, and six said nothing a bump could read, so they retired with the reasoning already in the handovers that wrote them. The gate now validates the store alone and asks for no record, and it checks no revision, so a bump still runs only when the operator directs it and the store stays pinned by default.
