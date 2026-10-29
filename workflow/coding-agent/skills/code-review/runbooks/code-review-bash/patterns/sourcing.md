# Sourcing patterns

Open this when one file sources another, or when two files need each other's functions.

## p-26 Source only in the allowed direction

```text
scripts/    ---> src/libs/, src/build/     host scripts source shared libraries
scripts/    ---> scripts/                  only when the target is logically a
                                           library, e.g. checkpoint.sh
src/libs/   ---> src/libs/ only            a library never sources a script
src/build/  ---> src/build/, src/libs/     build libraries source shared ones only
tests/*     ---> anything                  tests may source everything
nothing     ---> tests/                    nothing sources a test
```

A dependency points toward the more general module, never the more specific one, because a module that knows its caller can serve only that caller. In bash an edge is `source`, which runs the target inside the caller's process, or `exec`, which replaces the caller with it. A library that sources a script therefore depends on whatever called the script, and anything that sources a test file runs that file's cases.

Replaces: `src/libs/checkpoint.sh` sourcing `scripts/run.sh`, and a test file sourced by anything.

## p-27 Keep the source graph a tree

Shared functions live in leaf libraries, never in orchestrators. When `A.sh` sources `B.sh` and `B.sh` needs a function from `A.sh`, extract the shared function to a third library `C.sh` that both source, so one direction remains and the cycle never forms.

Replaces: two libraries sourcing each other, which resolves at load time or not at all depending on the order.
