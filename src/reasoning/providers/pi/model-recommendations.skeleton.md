# Model recommendations

One line per role. The role names are fixed; the values are yours to set.

Format: `_ROLE: <provider>/<model> at <thinking level>[; <provider>/<model> at <level> ...]`

- A role line with no value is uninitialized.
- When several models are listed, the first wins unless a routing clause says otherwise.
- A role with no value resolves to the pi startup default in `$AGENT_HOME/agent/settings.json`.
- Run the `setup-model-recommendations` skill to populate the lines.

This file is operator-owned. It lives outside version control and is not part of the repository.

_IMPLEMENTER:

_REVIEWER:

_ADVISOR:

_ORCHESTRATOR:
