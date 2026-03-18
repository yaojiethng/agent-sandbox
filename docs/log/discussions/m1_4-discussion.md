# M1.4 Discussion — Image Staleness Detection

**Status:** Pre-implementation discussion. Not yet on roadmap.

---

## Pain Point

Operators frequently encounter broken or outdated container behaviour after
updating agent-sandbox scripts or the Dockerfile, without realising the image
needs a rebuild. The failure mode is silent — the container starts from the
stale image, behaves incorrectly, and the operator has to diagnose why before
discovering a rebuild was all that was needed.

This is especially acute when agent-sandbox is being developed using itself —
changes to entrypoint scripts, snapshot functions, or the Dockerfile take no
effect until the image is explicitly rebuilt.

Currently the only remedies are `--rebuild` (manual, easy to forget) and
`make build` (requires knowing a rebuild is needed in the first place).

---

## Motivation

The image should declare itself stale automatically when the source files it
was built from have changed. The operator should never have to remember to
rebuild — the harness should detect the mismatch and rebuild before starting.

---

## Suggested Pattern

### Build-time digest

At build time, `build_agent.sh` computes a digest from all files that affect
the image — the Dockerfile and anything `COPY`ed into it:

```sh
DIGEST=$(cat providers/opencode/Dockerfile \
              libs/snapshot.sh \
              libs/diff.sh \
              providers/opencode/container-entrypoint.sh \
         | sha256sum | cut -d' ' -f1)

docker build --label "agent-sandbox.digest=$DIGEST" ...
```

The digest is stored as a Docker image label.

### Start-time staleness check

Before starting a container, the CLI wrapper computes the same digest from
current source files and compares it against the label on the existing image:

```sh
CURRENT_DIGEST=$(cat providers/opencode/Dockerfile \
                      libs/snapshot.sh \
                      libs/diff.sh \
                      providers/opencode/container-entrypoint.sh \
                 | sha256sum | cut -d' ' -f1)

IMAGE_DIGEST=$(docker inspect \
  --format '{{ index .Config.Labels "agent-sandbox.digest" }}' \
  "$IMAGE_NAME" 2>/dev/null)

if [[ "$CURRENT_DIGEST" != "$IMAGE_DIGEST" ]]; then
  echo "agent-sandbox: image is stale — rebuilding..."
  build_agent.sh --name="$NAME" --root="$ROOT"
fi
```

### Key constraints

- The digest file list must be **identical** in `build_agent.sh` and the
  staleness check. Centralise it — either a shared `libs/image.sh` helper or
  a variable defined once and reused in both scripts.
- The check belongs in the **CLI wrapper** (`agent-sandbox.sh`), which already
  owns build-if-missing logic. `start_agent.sh` hard-fails if the image is
  missing; the wrapper is the right place for pre-flight decisions.
- `--rebuild` stays as a manual escape hatch (e.g. to force a base image
  pull), but should no longer be needed for the common case.
- If no image exists at all, the existing build-if-missing path handles it —
  no digest comparison needed.

---

## Files Affected

| File | Change |
|---|---|
| `build_agent.sh` | Compute digest; pass as `--label agent-sandbox.digest=<sha>` |
| `agent-sandbox.sh` | Staleness check before `start`, `dry-run`; rebuild if stale |
| `libs/image.sh` (new, optional) | Centralise digest computation if shared logic grows |

---

## Design Decisions

1. **File list:** Hardcoded in `libs/image.sh`. Dynamic derivation from `COPY`
   instructions adds parsing complexity for little benefit given the file list
   is short and changes infrequently. `libs/image.sh` computes the digest from
   all files in `libs/` plus a provider-supplied `image-files.txt`.

2. **Stale image behaviour:** Warn-then-continue. The problem being solved is
   discovery — the operator not knowing a rebuild is needed. `--rebuild`
   remains the remedy. If the rebuild fails, the staleness warning must be the
   last visible line before exit to ensure it is not lost in build output.

3. **`dry-run` staleness check:** Yes. A dry-run against a stale image produces
   misleading output — the same class of problem as starting against one.
   The staleness check applies to both `start` and `dry-run`.

---

## Next Steps

1. ~~Add M1.4 to roadmap with objective and task list.~~ ✓
2. ~~Agree on file list centralisation approach (inline vs `libs/image.sh`).~~ ✓ — see Design Decisions above
3. Implement `build_agent.sh` digest label.
4. Implement staleness check in `agent-sandbox.sh`.
5. Update `execution_model.md` — document the digest label, staleness check,
   shared-lib assumption, and `image-files.txt` convention.
