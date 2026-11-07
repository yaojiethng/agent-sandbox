# Build Input Pinning

**Current:** 2026-11-07

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | A pin fixes the resolved artifact, not the requested name | an exact version still lets the registry serve different bytes; where the registry serves no digest, the artifact's hash is recorded and compared (2026-11-07) |
| R2 | One pin form per input class | a base image, a registry package, a URL artifact, a git source and an apt package are five different guarantees |
| R3 | Every pin is paired with a way to move it | a pin with no bump path freezes its own vulnerabilities; `scripts/check_pins.sh --remote` reports what moved and `--write` records it |
| R4 | A working-tree input is excluded by name | its identity is the commit, not a version |
| R5 | A missing or failing pin fails the build | the check is blocking, and it runs on the pin, not on the build's output |

## 2026-11-07 -- The apt class takes exact versions and a recorded hash, and the strict form is deferred

**Decision:** A pin fixes the resolved artifact where its registry serves one. Two input classes cannot reach that form on this base, and each carries the strongest form that exists:

- **an apt package.** The Dockerfile carries the exact version, and `src/build/pins.json` records the resolved `.deb` SHA256 from the suite's `Packages` index. apt enforces the version; the gate compares the recorded hash, and `--remote` reports a republished `.deb` or a newer version as drift.
- **the Python build.** uv resolves the standalone build from its own recorded table, so the pin fixes the 3.11 patch and the build records the artifact uv chose.

The relaxation is temporary and it has an end: [`roadmap_future.md`](../../devlog/roadmap_future.md) `M7 -- Dependency Security` carries `The base image is digest-capable and the apt set takes the strict pin form`, which moves the base to one whose package set is content-addressed and removes this entry's exception.

R3's movement pair is `scripts/check_pins.sh`: `--remote` re-resolves every input and reports what moved, and `--write` records it. R5 is the gate on the form, which reads the tree and blocks, and the preflight warning in `scripts/build.sh`, which is the build's cheap local nudge.

**Rationale:** The strict form is the right target and it is unreachable here today, and the two ways to handle an unreachable target are to pretend it is reachable or to name the gap. Debian's archive publishes a SHA256 per `.deb` and apt has no syntax that requires it, so a Dockerfile cannot express the guarantee no matter how it is written; a policy that stated it anyway would produce a check that cannot pass, which is the failure the 2026-10-16 entry already rejected for the digest-per-package alternative. Recording the hash and comparing it moves the class one step closer: a republished `.deb` at the same version is caught, which the version alone does not catch, and the remaining gap is the guarantee that the bytes fetched are the bytes recorded, which apt's own index check covers for a tampered mirror but not for a compromised archive.

**Rejected alternatives:**

- *A dated Debian snapshot* -- execution: it fixes the whole archive for the sake of eight packages, slows every build, makes `snapshot.debian.org` a single point of failure for tier 1, and is a larger change than the base migration it would postpone.
- *A digest per `.deb` enforced by the Dockerfile* -- intent: apt has no such syntax, so the line could not be written, which is the alternative the 2026-10-16 entry rejected on the same grounds.
- *Leave apt unpinned until the base migration* -- intent: a strict form that is impossible today, therefore nothing. Execution: the version pin is achievable now and catches most of the class, so waiting for the perfect form would ship the weaker state for longer.
- *A lockfile for the Python build* -- intent: it would fix the interpreter's bytes the way the npm lockfiles fix the packages'. Execution: uv already resolves from a recorded table and verifies the download, so a second record would restate a guarantee the tool already holds.

**Edge cases / drivers:** The apt row is what a `--remote` run reports on: bookworm receives security updates without a suite bump, so an unchanged Dockerfile line can drift under the pins file, and drift is a warning because a newer patch is usually the thing to take. The base image takes a digest with the tag kept, so the line stays readable. Every registry package installs with `npm ci` from a committed lockfile under `src/reasoning/registry/`, which the manifest declares in its `build` layer: the context gate owns every included path, and an input no image copies belongs to no `image` row.

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
