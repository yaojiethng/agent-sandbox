# Shell-option patterns

Open this when code decides which shell options a file declares, or whether a function takes a switch at all.

## p-18 Declare shell options by consumption class

| Class | Options | Why |
|---|---|---|
| Orchestrator entry point, exec'd, no source-consumer | `set -euo pipefail` at top | fail-fast beats continuing with partial state |
| Dual-use, exec'd in production and sourced by tests | flags inside `main()` or the `p-15` guard only | a top-level `set` mutates the sourcing consumer's shell |
| Pure library, sourced only | never set options | inherits whatever the sourcing file declares |
| Observe and report, test file, harness runner, diagnostic sweep | no `-e`; `set -uo pipefail` preferred | first-failure abort defeats reporting |

The class follows how the file is consumed, not where it lives. A class change declares the flags of the new class in the same change. Use a weaker set than `-uo pipefail` only with an inline comment saying why. `-u` in library code would fire on a consumer-controlled environment, so a library validates its inputs explicitly instead.

- Variant: a function invoked in a condition, as `if f`, `f && g` or `f || g`, runs with `set -e` suspended for its whole body, so a line inside it that counts on errexit does nothing there. The suspension belongs to the call site rather than the file, so the class alone cannot tell a reader whether `-e` is in force inside the function.
- Variant: a function signature, where a boolean or string mode parameter exists only when at least one production call site passes a value that changes behaviour. A flag for later has no consumer: every signature it passes through gains an untested branch, and removing it later touches every file in between. When a mode is needed, the parameter and the call-site change go in the same commit.

Replaces: `set -euo pipefail` at the top of a file that is also sourced, and a mode parameter no call site passes.
