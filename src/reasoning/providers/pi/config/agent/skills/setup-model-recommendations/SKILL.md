---
name: setup-model-recommendations
description: Read and write the project's role-to-model recommendations at /home/agentuser/sandbox/.agents/model-recommendations.md, exactly as the operator states them. Writes only when the operator asks. Never detects, probes, or invokes a model. Use for /setup-model-recommendations, "initialize model recommendations", "set the role models", or when a dispatch reports an uninitialized role.
---

# Setup model recommendations

Write `model-recommendations.md`, the single source of truth for the role-to-model recommendations this project dispatches by.

The operator owns the values. The agent is an interface to them: it reads the file and writes what the operator says, and nothing else. The file is committed at `.agents/model-recommendations.md`, so an edit there is a reviewable change and pi never rewrites it on its own.

Nothing here validates a model. A model id is a fact about the operator's accounts, and this skill has no way to check one that does not spend a request or read a catalogue that drifts. An id that does not exist is discovered at dispatch, where the failure is attributed to the route, and the run reports it.

## Roles

| Role | Dispatched for |
|---|---|
| `_IMPLEMENTER` | Code and implementation work, worker tracks |
| `_REVIEWER` | Code review, adversarial review |
| `_ADVISOR_CODE` | Advisory review of a change whose deliverable is code |
| `_ADVISOR_DOCS` | Advisory review of a change whose deliverable is prose |
| `_ORCHESTRATOR` | The eval harness's driver run |

A role tag not in this table is from a retired role: drop the line, and do not invent values for it.

## Steps

### 1. Read the file

Read `model-recommendations.md` as it stands. Keep every value already present, in its written order, character for character. Report to the operator what each role resolves to before changing anything.

### 2. Ask for the change

Ask which role and which value, and accept the operator's answer as given. Do not propose a model from memory, do not run `pi --list-models`, and do not read a runtime's catalogue. The operator names the assignment; the model may not exist, and that is the operator's call to make and to correct.

A value is `<provider>/<model> at <thinking level>`. A role line may carry several values separated by `;`, tried in the order written, so the cheapest route that can answer goes first. A condition on which models a role uses becomes a role of its own, never a clause inside one line.

### 3. Write the file in place

Edit only the lines the operator named. Keep the header, the format line and every other role line untouched. The repository copy is the one to edit: the container's `~/.pi/model-recommendations.md` is derived from it at every start.

### 4. Report what the file now says

Print the resulting lines for the roles that changed, and say that the next dispatch reads them. Do not report a model as available. The only thing this skill knows is what the file says.

## What this skill never does

- It never runs a model, or any command that would list models.
- It never asserts that an id exists, is served, or is reachable by a runtime.
- It never substitutes a default for a role with no value. That dispatch stops and names the role.
- It never rewrites values the operator did not name.
