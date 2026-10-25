# Model recommendations

One line per role. The role names are fixed; the operator sets the values.

Format: `_ROLE: <provider>/<model> at <thinking level>; <provider>/<model> at <level>`

- Entries are tried in the order written, and the next one runs only when the previous route cannot answer.
- The free pool comes first, then the subscription route, then the metered one, so a session spends the cheapest route that can answer.
- The free pool is a shared daily quota that replenishes at UTC midnight. An exhausted route cools, the walk takes the next entry, and the free entry is tried again the next day.
- A role with no line is refused by name, and no default model exists.

_IMPLEMENTER: opencode/deepseek-v4.1-flash-free at high; opencode-go/deepseek-v4.1-flash at high; deepseek/deepseek-flash at high

_REVIEWER: opencode/deepseek-v4.1-flash-free at high; deepseek/deepseek-flash at high

_ADVISOR_CODE: opencode/deepseek-v4.1-flash-free at high; opencode-go/deepseek-v4.1-flash at high; deepseek/deepseek-flash at high

_ADVISOR_DOCS: opencode/glm-5.3-flash-free at high; deepseek/deepseek-flash at high

_ORCHESTRATOR: deepseek/deepseek-flash at high
