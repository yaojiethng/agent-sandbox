---
name: setup-model-recommendations
description: Populate the project's role-to-model recommendations at $AGENT_HOME/model-recommendations.md. Detects the models this pi session can dispatch and writes one line per role. Use for /setup-model-recommendations, "initialize model recommendations", "set the role models", or when a dispatch reports an uninitialized role.
---

# Setup model recommendations

Write `$AGENT_HOME/model-recommendations.md`, the single home for the role-to-model recommendations this project dispatches by.

The file is operator-owned. It lives outside version control and outside pi's own `agent/` config root, and pi never rewrites it. A role line with no value is uninitialized and resolves to the pi startup default in `$AGENT_HOME/agent/settings.json`.

## Roles

| Role | Dispatched for |
|---|---|
| `_IMPLEMENTER` | Code and implementation work, worker tracks |
| `_REVIEWER` | Code review, adversarial review |
| `_ADVISOR` | Advisory review, with a routing clause for documentation and language versus code |
| `_ORCHESTRATOR` | The eval harness's driver run |

## Steps

### 1. Detect available models

Enumerate the models this session can dispatch: run `pi --list-models` and treat its output as the dependable source. If you cannot detect any, ask the operator to paste the slugs they have access to. Never write a real slug you have not confirmed is available.

### 2. Load current state

Read `$AGENT_HOME/model-recommendations.md`. Keep every value already present. A line for a role not in the table above is from a retired role: drop it. If a role line is missing, add it empty.

### 3. Choose a value per role

For each role, propose a value in the form `<provider>/<model> at <thinking level>` and confirm it with the operator, showing the current value and the detected models. Prefer a question with the detected models as options over free text. A role may list several values separated by `;`, and the first wins unless a routing clause says otherwise; keep the `_ADVISOR` routing clause when the operator wants one.

State the level explicitly, because a recommendation carries its thinking level.

### 4. Validate

Every real slug written must be in the detected set. If a chosen slug is not available, stop and ask again.

### 5. Write the file in place

Write `$AGENT_HOME/model-recommendations.md` with the same header, format and role lines, preserving the values. The file is a single-file bind mount: replace its content in place, never with `mv` or by deleting and recreating it, because that breaks the mount.

### 6. Confirm

Tell the operator the file was written and that the next dispatch reads it. Re-running this skill updates it.
