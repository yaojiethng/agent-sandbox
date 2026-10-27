# Patterns -- image construction

The canonical forms a container review names in a finding. One entry is one form, its statement, and the wrong forms it replaces. The id rule and the entry format are the ones the bash pattern set states, once, in [`code-review-bash/patterns/README.md`](../../code-review-bash/patterns/README.md); this set continues the same numbering rather than starting its own, so a finding citing an id still resolves to one entry.

Finding an id:

```bash
grep -rn '^## p-' workflow/coding-agent/skills/code-review/code-review-container/patterns/
```

## What a linter settles

A Dockerfile linter reports the mechanical half of these. Measured against the seven build files in this repository, `hadolint 2.14.0` at its default rule set reports nothing on any of them, and it covers a pinning fault, an `ADD` where `COPY` does, and a shell-form entrypoint. So a review does not re-raise what the linter already blocks; the entries here that it does not cover are the reason the review exists: the order of privilege against the user switch, the id a non-root user is built from, which values are build-time and which run-time, and whether a copy names what the image needs.
