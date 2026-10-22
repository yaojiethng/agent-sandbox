# Model recommendations

One line per role. The role names are fixed; the operator sets the values.

Format: `_ROLE: <provider>/<model> at <thinking level>`

- A role line with no value is uninitialized, and the dispatch stops.
- Every role names `deepseek/deepseek-flash`, the only model we dispatch.
- The level is one of `low`, `medium`, `high`.

_IMPLEMENTER: deepseek/deepseek-flash at high

_REVIEWER: deepseek/deepseek-flash at high

_ADVISOR: deepseek/deepseek-flash at high

_ORCHESTRATOR: deepseek/deepseek-flash at low
