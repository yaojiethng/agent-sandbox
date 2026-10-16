# Build Input Pinning

**Current:** 2026-10-16

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | A pin fixes the resolved artifact, not the requested name | an exact version still lets the registry serve different bytes |
| R2 | One pin form per input class | a base image, a registry package, a URL artifact, a git source and an apt package are five different guarantees |
| R3 | Every pin is paired with a way to move it | a pin with no bump path freezes its own vulnerabilities |
| R4 | A working-tree input is excluded by name | its identity is the commit, not a version |
| R5 | A missing or failing pin fails the build | the check is blocking, and it runs on the pin, not on the build's output |

## 2026-10-16 -- A pin names its form, and every pin moves

**Decision:** A build input is pinned to its resolved artifact. The form follows the input's class.

| Input class | Form | Check |
|---|---|---|
| a Docker base image | a digest, with the tag kept for readability | the Dockerfile carries `@sha256:` |
| a package a registry resolves | an exact version plus a committed lockfile with integrity hashes, installed frozen | the lockfile is present and the install passes its frozen flag |
| an archive or an installer fetched by URL | the version in the URL plus the publisher's checksum | the checksum is verified in the same `RUN` |
| a git source | a commit SHA | the clone checks out the SHA, never a branch |
| an apt package | a dated snapshot | the source list names the snapshot date |
| an output of the repository working tree | the git revision, recorded by the build | not an external pin, excluded from this policy by name |

Every pin is paired with a way to move it: one automated bump path across the repository, and a scan that reports what each pin currently carries. A pin without those is a decision to stop patching.

**Rationale:** An exact version is the right instinct and an incomplete guarantee. It fixes the name, and the registry may still serve different bytes under that name through a republish or a compromise, which is why the lockfile's integrity hash and the digest are the forms that actually fix the artifact. And a pin that never moves freezes whatever vulnerability the version carried, which is the cost the operator asked about and the reason the policy pairs every pin with a bump path rather than choosing a looser form.

The unpinned list is measured rather than assumed. The census reads 41 install and copy steps and names the tier-1 apt set, the uv installer, the hermes apt sets, the hermes clone and its pip and npm resolution, and the unpinned `opencode-ai` in the opencode base.

**Rejected alternatives:**

- *A version range or a caret range* -- it trades reproducibility for freshness, and the freshness it buys is not the kind that patches a vulnerability: a range moving under you is an unreviewed change.
- *Pin only the agent packages and leave the runtime set unpinned* -- the runtime set is the larger attack surface and the less visible one, and the census shows the pins are already concentrated in the agent packages.
- *Pin the repository working-tree inputs to the harness version* -- it names a number that does not identify the content. The commit does, and the build already stands at one.
- *A digest for every input, including the apt set* -- Debian's archive does not serve per-package digests, so the snapshot date is the form that exists, and pretending otherwise would produce a check that cannot pass.

**Edge cases / drivers:** A digest and a tag together are deliberate: the tag keeps a human able to read the line, and the digest is what the build resolves. A lockfile only helps if the install is frozen, so the frozen flag is part of the check rather than a separate habit. The bump path and the scan are one row in their own right, and the policy is applied input by input by the row that carries the census's worklist.
