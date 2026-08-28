# Design — UID Mapping Permission Strategy for Docker Bind Mounts

**Status:** Approved for implementation

**Linked artifacts:**
- Story: [`story_linux_filesystem_uid_mismatch.md`](story_linux_filesystem_uid_mismatch.md) — problem analysis and strategy catalog
- Plan handover: [`20260523-09-plan-settings_mount_permissions_resolution_3_scoping.md`](../handovers/20260523-09-plan-settings_mount_permissions_resolution_3_scoping.md) — session record

---

## 1. Problem

Docker bind mounts map host file permissions directly into the container. When the container process runs as a different UID than the host user who owns the files, writes to bind-mounted directories fail with `Permission Denied`. This affects:

- **Workspace directories** (`.workspace/session-diffs/`, `.workspace/input/`, `.workspace/output/`)
- **Provider config directories** (`.pi/agent/`, `.opencode/`, etc.)
- **Any file created or copied post-setup** — new inodes inherit default `umask`, not arbitrary ACLs

The current remedy (Resolution 1 in the story document) uses POSIX ACLs (`setfacl`) to grant the container UID write access. This approach is fragile: ACL masks can be silently downgraded by file operations, ACLs do not survive `cp` to new filesystems, and the solution fails entirely on `/mnt/c/` (Windows interoperability mounts) where ACLs are unsupported.

Additionally, the solution must work across all platforms developers use — WSL native, macOS Docker Desktop, Windows Docker Desktop — not just one.

---

## 2. Design Considerations

The following considerations were explored during the 2026-05-23 planning session.

### 2.1 Platform Portability

The solution must address three distinct platform behaviours:

| Platform | Docker Bind Mount Behaviour | Key Constraint |
|---|---|---|
| WSL (Native Docker Engine) | Enforces strict UID/GID matching | Group membership works; IDs are honest |
| macOS (Docker Desktop) | virtiofs bridge translates identities transparently | ACLs and group changes ignored; macOS grants write access to the Docker user anyway |
| Windows (Docker Desktop) | Hypervisor layer masks host UIDs | Group-based approaches fail; hypervisor is UID-aware but group-unaware |
| CI/CD (Linux) | Strict UID matching, always root-executed | Must handle arbitrary runner UID |

**Decision:** UID Mapping (the container runs as the host user's UID/GID) is the only approach that works across all four. Group-based approaches (Strategy 3) work on WSL but fail on macOS and Windows Docker Desktop.

### 2.2 Inheritance Model

File operations (`cp`, `mv`, `mkdir`) create new inodes with default permissions. Any permission fix applied to a parent directory is lost when new files arrive. Two mechanisms address this:

| Mechanism | Reliability | Platform Support |
|---|---|---|
| Default ACLs (`setfacl -d`) | Fragile — mask can be reset by intermediate operations | Linux only (fails on `/mnt/c/`) |
| Setgid bit (`chmod g+s`) | Reliable — kernel-enforced, survives operations | Linux only |
| Same UID (no fix needed) | **Native** — new files are owned by the process UID | **All platforms** |

**Decision:** Same UID is the only truly reliable inheritance mechanism. No post-copy permission fixes are needed when the container process and the file owner are the same numeric identity.

### 2.3 Build Pipeline Impact

Three approaches to achieving UID alignment were considered:

| Approach | Dockerfile Change | Compose Change | Build Pipeline Change | Host-Side Change |
|---|---|---|---|---|
| **A: Compose `user:` override only** | None | `user: "${HOST_UID}:${HOST_GID}"` | None | None |
| **B: Build args + compose `user:`** | `ARG HOST_UID`/`HOST_GID`, collision handling in `RUN` | Same as A | `build_agent`/`build_sandbox` must accept and thread `--build-arg` | None |
| **C: Host group bind** | Drop `-u 1001` only | `group_add: [${SHARED_GID}]` | None | `sudo groupadd`, `sudo usermod`, `chgrp`, `chmod` |

Approach A fails because the image has pre-baked files owned by UID 1001 — the process runs as a different UID and cannot write to its own `$HOME`. **Approach B is required** — the user must be created at the correct UID during image build.

Approach C (group bind) requires zero pipeline changes but fails on macOS/Windows DD.

**Decision:** Approach B. The pipeline change is mechanical — thread `HOST_UID` and `HOST_GID` through existing build function signatures.

### 2.4 UID Collision Handling

Base images often pre-create users. `node:22-slim` has a `node` user at UID 1000. If the host UID is 1000, `useradd -u 1000` fails.

Three collision strategies:

| Strategy | Outcome |
|---|---|
| `useradd -u ${UID} ... || true` (ignore error) | No agentuser user exists; `chown -R agentuser:agentuser` fails; `USER agentuser` errors |
| Remove existing user before `useradd` | Breaks Node package installs that depend on the `node` user's files |
| **Rename existing user to agentuser** | Preserves all files; `USER agentuser` works; home dir is correct |

**Decision:** Use `usermod`/`groupmod` to rename the colliding user/group, preserving all state. This is the pattern shown in the Dockerfile implementation (Strategy 4, Step A in the story document).

### 2.5 Agent ↔ Sandbox Seam

The agent and sandbox containers share volumes via `--volumes-from`. Both must run as the same identity for files to be readable/writable across them.

With UID Mapping, both containers receive the same `HOST_UID`/`HOST_GID` at build time and run as the same numeric identity via `user:` in compose. The seam is solved implicitly — no separate group mechanism needed.

### 2.6 Container-Sig / Image Determinism

M2.7's hash-based container identity captures the built image hash. The UID baked into the image is part of that hash. Since images are built per-machine (each host has its own Docker daemon), a different UID on a different machine produces a different hash — this is correct behaviour, not a conflict. Container-sig compares an image against itself on the same machine, so preflight validation remains valid regardless of UID.

---

## 3. Final Solution: UID Mapping (User Hijack)

**Selected strategy:** Strategy 4 from the story document.

The container's `agentuser` is created at the host user's UID/GID at build time. The process runs as that user. Bind mounts see the same numeric UID on both sides — no permission fixing needed.

### How It Works

```
Host (UID 1000, GID 1000)          Container (UID 1000, GID 1000)
         │                                     │
         │  HOST_UID=$(id -u) ──build-arg──►  │  useradd -u 1000 agentuser
         │  HOST_GID=$(id -g) ──build-arg──►  │  compose user: "1000:1000"
         │                                     │
         │  bind mount                          │
         ├── .workspace/session-diffs/ ──────►  ├── writes as UID 1000 ✓
         ├── .pi/agent/ ────────────────────►  ├── writes as UID 1000 ✓
         └── .snapshot/ ────────────────────►  └── reads as UID 1000 ✓
```

### What Changes

| # | File | Change | Dependency |
|---|---|---|---|
| **1** | `scripts/onboard.sh` | Remove all `setfacl` commands. Remove `chgrp`/`chmod`/`g+s` operations. Add `HOST_UID`/`HOST_GID` to `.env` export (already derived at runtime, but document as canonical). | Independent |
| **2** | `libs/docker-compose.yml` | Add `user: "${HOST_UID:-1000}:${HOST_GID:-1000}"` to both `sandbox` and `agent` services. Remove `group_add` (no longer needed). | Independent |
| **3** | `providers/pi/provider.Dockerfile` | Add `ARG HOST_UID=1000`, `ARG HOST_GID=1000`. Replace `useradd -m -u 1001 -s /bin/bash agentuser` with UID-aware user creation and collision handling. Replace `chown -R agentuser:agentuser` with `chown -R ${HOST_UID}:${HOST_GID}`. | Independent (can be done parallel across all providers) |
| **4** | `providers/hermes/provider.Dockerfile` | Same as #3 | Parallel with #3 |
| **5** | `providers/claude-code/provider.Dockerfile` | Same as #3 | Parallel with #3 |
| **6** | `providers/opencode/provider.Dockerfile` | Same as #3 | Parallel with #3 |
| **7** | `libs/sandbox.Dockerfile` | Same as #3 — add ARGs, UID-aware useradd, numeric chown | Independent |
| **8** | `providers/pi/onboard.sh` | Remove `chmod 775` additions (not needed with UID mapping). The `mkdir -p` remains; no permission fixing required. | After #1 |
| **9** | `libs/build.sh` (or `libs/containers.sh`) | `build_sandbox()` and `build_agent()` must accept `--uid`/`--gid` flags and pass them as `--build-arg HOST_UID=... --build-arg HOST_GID=...` to `docker build` | After #1, blocks #3–#7 |
| **10** | `scripts/start_agent.sh` | Export `HOST_UID=$(id -u)` and `HOST_GID=$(id -g)` before compose invocation | After #1 |
| **11** | `scripts/run_agent.sh` (if exists) | Ensure host IDs are propagated to compose generation | After #1 |
| **12** | `devlog/discussions/story_linux_filesystem_uid_mismatch.md` | Already updated with Strategy 4 | Done this session |
| **13** | All provider compose overlays | Verify `user:` override is not needed (base template handles it). If any provider overlay sets `user:`, remove or align. | After #2 |
| **14** | Tests | Update any tests that assert ACL presence or specific UID 1001. Tests that check bind mount writability should pass without change. | After #1–#7 |

### Dependency Ordering

```
#1 (onboard.sh) ────────────────────────────► #8 (pi/onboard.sh)
                                            ► #9 (build.sh: args)
                                                 │
                    #10 (start_agent.sh: export) ◄┘
                         │
                    #2 (compose: user:)
                         │
    ┌─────────┬─────────┼─────────┬─────────┐
    │         │         │         │         │
   #3 pi    #4 hermes #5 cd     #6 oc    #7 sandbox
    │         │         │         │         │
    └─────────┴─────────┼─────────┴─────────┘
                        │
                   #13 (provider overlays)
                   #14 (tests)
```

Items #3–#7 are parallelisable across the 5 Dockerfiles.

---

## 4. Documentation Changes — New User-Facing Contract

The following concepts become part of the system contract and must be documented for users/operators:

### 4.1 Host Identity as a Build Input

The user's UID/GID is now a build-time input, not just a runtime variable. This must be documented:

- **What:** `HOST_UID` and `HOST_GID` are exported from `id -u`/`id -g` and threaded into `docker build --build-arg`
- **Why:** The container must run as the same numeric user as the host to avoid bind mount permission conflicts
- **When it changes:** If a developer's UID changes (new machine, new OS install), images must be rebuilt. The `--rebuild` flag triggers this.
- **Default:** Defaults to 1000:1000 for CI environments where `id -u` may not match

### 4.2 Removal of ACL Requirement

The `setfacl` pre-requisite (ACL package installed, ACL commands run at onboard time) is **eliminated**. No user-facing ACL management needed. Onboarding is simpler — no `sudo apt install acl`, no `setfacl` commands.

### 4.3 Image Portability Constraint

Images built for one UID are not portable to a machine with a different host UID. Documented as a known limitation:

- Images are cached per-machine; rebuilding on `git pull` or `--rebuild` updates the UID
- CI/CD images must be built with the CI runner's UID (or use the 1000:1000 default)
- Multi-developer teams: each developer builds images locally with their own UID

### 4.4 Compose `user:` Override

The base compose template now explicitly sets `user:` on both services. Documented as the mechanism that ensures the container process runs as the correct identity. Operators should not override this unless they understand the permission implications.

### 4.5 Files to Update

| File | What to Add/Change |
|---|---|
| `scripts/onboard.sh` header | Update "What this script produces" — remove ACL references, add `HOST_UID`/`HOST_GID` export note |
| `docs/development/quickstart.md` | Add "First build" section explaining UID detection and image rebuild |
| `docs/architecture/security.md` | Document that container runs as host UID (not root, not a fixed internal UID) |
| `docs/concepts/execution_model.md` | Update container identity model to mention UID mapping |
| `providers/*/provider.Dockerfile` header comments | Document the ARG interface, collision handling behaviour |
| `libs/docker-compose.yml` header | Document `user:` field, why it's set, what the defaults mean |

---

---

## 6. Acceptance Criteria (for the implementation session)

| # | Criterion | Verifiable by |
|---|---|---|
| 1 | All 5 Dockerfiles accept `HOST_UID`/`HOST_GID` build args and create `agentuser` at the correct UID, handling collisions with pre-existing users | `docker build --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) .` succeeds for each |
| 2 | Compose template sets `user:` on both `sandbox` and `agent` services; container process runs as the correct UID | `docker compose exec sandbox id -u` matches `$(id -u)` on host |
| 3 | Bind-mounted `.workspace/session-diffs/` is writable by the container without any `setfacl` or `chmod` | `docker compose exec sandbox touch /home/agentuser/workspace/session-diffs/test` succeeds |
| 4 | Bind-mounted `.<provider>/agent/` directories are writable by the agent container without any `setfacl` or `chmod` | Agent preflight bind mount check passes |
| 5 | `onboard.sh` contains no `setfacl` references | `grep -c setfacl scripts/onboard.sh` is 0 |
| 6 | Onboarding works end-to-end with no ACL package installed | `apt remove acl && agent-sandbox onboard --refresh ...` completes without error |
| 7 | Documentation files listed in rule 4.5 are updated | `read` each file confirms coverage |

---

## 7. Open Questions

None. All design questions resolved during the 2026-05-23 planning session.

---

## 8. Supplementary Techniques (Reference Only)

These techniques are documented here for reference. They are not part of the selected UID Mapping strategy, but they may inform implementation of provisioning scripts or fallback approaches.

### 8.1 Group Bind with macOS Compatibility

The group bind approach (Strategy 3 in the story document) can be made cross-platform by using the host user's actual GID instead of a hardcoded shared group. On macOS, the commands execute but are effectively no-ops because the macOS filesystem bridge (virtiofs) overrides Linux permissions.

```bash
# Get Host GID (usually 1000 on WSL, 20 on Mac)
SAFE_GID=$(id -g)

# Apply to sandbox
sudo chgrp -R $SAFE_GID "$SANDBOX_DIR"
sudo chmod -R 775 "$SANDBOX_DIR"
sudo chmod -R g+s "$SANDBOX_DIR"
```

**Platform behaviour:**
- **WSL:** Group ownership and permissions are enforced. The GID must match the container's supplementary group for write access.
- **macOS:** `sudo` prompts for password. `chgrp`/`chmod` execute but the virtiofs bridge overrides the Linux permission bits — macOS Docker Desktop grants write access regardless, so the commands are redundant but harmless.
- **Windows DD:** Same as macOS — hypervisor masks the permissions.

**Limitation:** Unlike the UID Mapping approach (selected strategy), this does not solve the overshadoing problem during provisioning. The setgid bit (`g+s`) only triggers when the Linux kernel creates a **brand new inode** inside the setgid directory — it does not affect files brought in from elsewhere:

- **`cp -r`**: Creates subdirectories based on source metadata, overshadowing the destination's setgid bit. New subdirectories are owned by the host group (GID 1000) with restricted mask (755), not the shared group.
- **`mv`**: Preserves original attributes entirely — group does not change to the shared GID.
- **ACL Mask Trap**: Even if the group is correct, the copy process can reset the ACL Mask to `r-x`, blocking write access.

**Consequence:** The setgid bit reliably handles files the **container creates at runtime** (logs, session checkpoints). It does **not** handle provisioned files. A recursive permission fix after provisioning, or `rsync --chmod` (see rule 8.2), is required for deployment.

### 8.2 rsync for Permission-Aware Provisioning

During early provisioning, files are copied from template directories into the sandbox. Using `cp -r` creates new inodes that inherit default `umask` settings, potentially overshadowing any ACL or group permissions set on the parent directory. `rsync --chmod` solves this by setting permissions at write time.

```bash
rsync -rtv --chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r \
  --chown=1000:1001 ./src/ "$PROVIDER_SANDBOX_DIR/"
```

| Flag | Effect |
|---|---|
| `-rtv` | Recursive, preserve modification times, verbose |
| `--chmod=Du=rwx,Dg=rwx,Do=rx` | Force directories to mode 775 (owner+group+other readable, owner+group writable) |
| `--chmod=Fu=rw,Fg=rw,Fo=r` | Force files to mode 664 (owner+group writable, all readable) |
| `--chown=1000:1001` | Force owner to host user UID and group to container GID (WSL only; macOS ignores or requires `sudo`) |

**Why setgid does not solve this:** The `chmod g+s` setgid bit only fires for **new inodes created inside the directory** by the kernel. When `cp -r` copies a tree, it creates new inodes based on source `stat()` metadata (ownership, mode), bypassing the setgid mechanism entirely. This is not a bug in setgid — it is operating as designed. The kernel has no way to know that the inode it just created is a "copy" that should inherit differently. `rsync --chmod` works around this by forcing the permission bits at the point of write, before the kernel ever sees the source metadata.

**Comparison with `cp`:**

| Method | Inheritance | Reliability | Efficiency |
|---|---|---|---|
| `cp -r` | Fails (resets mask) | Low | Low (copies everything) |
| `cp -p` | Fails (preserves wrong bits) | Low | Low |
| `rsync --chmod` | Forced at write time | High | High (delta transfers) |

**Integration with the selected UID Mapping strategy:**

If UID Mapping is in effect, `--chown` is not needed — the container and host share the same UID, so native owner permissions apply. However, `rsync --chmod` remains useful as a belt-and-suspenders approach to ensure group/other permissions are correct regardless of source file modes.

If provisioning uses `rsync` instead of `cp -r`, the recommended command is:

```bash
rsync -rtv --chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r \
  "$SOURCE_DIR/" "$TARGET_DIR/"
# Safety catch: ensure setgid inheritance for future files
find "$TARGET_DIR" -type d -exec chmod g+s {} \;
```

The `find ... chmod g+s` is a cheap safety catch that ensures any directories created by the rsync inherit the setgid bit, so subsequent files written into them will use the correct group. This is necessary because `rsync --chmod` does not set the setgid bit — it only sets permissions.
