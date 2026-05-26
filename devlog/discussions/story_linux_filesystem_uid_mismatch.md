# Document — WSL/Docker Volume Permission Architectural Matrix and Remediation Strategies

**Status:** Evaluated — resolved via Strategy 4

> **Resolved.** Structural comparison and implementation specifications for host-container volume permission anomalies across WSL2 runtimes. **Strategy 4 (UID Mapping)** selected as the implementation target — see design document at `docs/devlog/discussions/design_settings_permissions_group_bind.md`.

---

## Context

When utilizing Docker bind mounts within a Windows Subsystem for Linux (WSL) environment, a structural conflict occurs across the host-container boundary due to a Linux UID Mismatch. Linux manages file permissions strictly via numeric identifiers rather than usernames.

In this environment, the standard WSL host user operates as `UID 1000`, while the containerized application process executes as `UID 1001` (an application-specific agent user). When a host folder is bind-mounted into the container, Docker maps the host's physical file permissions directly into the container's namespace.

---

## Pain Points

* **Host-Container Write Blocks:** The container application (`UID 1001`) must perform preflight write checks and maintain persistent write access to host-mounted directories (such as `CHANGES_DIR` or `SANDBOX_DIR`) owned by the host user (`UID 1000`). Because default directory modes (`0755`) restrict write access exclusively to the owner, standard Linux permissions treat `UID 1001` as "Other," resulting in immediate `Permission Denied` errors at container runtime.


* **ACL Mask Throttling:** Standard POSIX Access Control Lists (ACLs) are frequently superseded or capped by the effective ACL mask. If the directory's runtime mask is inadvertently set or altered to `r-x`, any granular `rwx` permissions explicitly assigned to `UID 1001` are automatically downgraded to read-only, breaking container write capabilities.


* **Metadata Reset during Provisioning:** File operations executed during early setup phases (such as `cp` or `mkdir`) generate entirely new inodes. These newly created files and folders inherit default system `umask` settings rather than the advanced ACLs of their parent directory, effectively "overshadowing" and nullifying prior permission fixes.


* **Container Boot Latency:** Remediation strategies that rely on recursive ownership changes (`chown -R`) at container startup introduce an operational bottleneck. If the target bind mount contains large nested directories, startup times scale linearly with inode counts.


* **Host-Side Ownership Pollution:** Modifying file ownership directly inside the container alters physical metadata on the host. This causes files within the WSL host filesystem to become owned by `UID 1001`, forcing the developer to use `sudo` on the host to manage local files.



---

## Architectural Comparison Matrix

| Feature / Criteria | Solution 1: Host-Side ACLs | Solution 2: Runtime Entrypoint | Solution 3: Shared Group Bind | Solution 4: UID Mapping (User Hijack) |
| --- | --- | --- | --- | --- |
| **Execution Point** | Host-Side Setup Script

 | Container Runtime Boot

 | One-Time Host Setup + Compose | Build Time (Dockerfile + Compose) |
| **Privilege Escalation** | Host `sudo` during setup

 | Passwordless `sudo` in container

 | Host `sudo` during configuration | Build-time root (standard in Dockerfiles) |
| **Boot Time Impact** | None (Zero latency) | High (Linear with inode count)

 | None (Zero latency) | None (Zero latency) |
| **Host File Ownership** | Retained by Host User (`1000`)

 | Hijacked by Container User (`1001`)

 | Shared (Owner: `1000`, Group: `1001`) | **Natively shared** (Container runs as Host UID) |
| **Docker Driver Support** | Requires WSL Native / Ext4 FS

 | Driver Dependent (Fails on gRPC FUSE)

 | WSL Native Linux only (fails on macOS/Windows DD) | **Universal** (macOS, Windows DD, WSL, Linux, CI) |
| **Inheritance (cp/mkdir)** | Fragile (ACL mask can be reset)

 | N/A (runtime fix) | Reliable via setgid bit | **Native** (same UID = same owner) |
| **Host-Side Changes** | ACL package + `setfacl` | None | `sudo groupadd`, `sudo usermod`, log-out/in | **None** (`id -u`/`id -g` are free) |
| **Build Pipeline Impact** | None | None | None | Requires `--build-arg` threading for host UID/GID |
| **Image Portability** | Portable | Portable | Portable | **Tied to host UID** (rebuild per machine) |

---

## Implementation Specifications

### Strategy 1: Host-Side ACL Stabilization (The "One-Two Punch")

This method locks down permissions via POSIX Access Control Lists, maintaining the host user as the exclusive owner while whitelisting the container user and stabilizing the effective mask.

#### Constraints & Prerequisites

* **File System Location:** This functions exclusively if the project files reside natively within the WSL Linux file system (e.g., `/home/...`). It fails on Windows interoperability mounts (e.g., `/mnt/c/...`).


* **Tooling Prerequisites:** The host system must have the ACL management package installed (`sudo apt install acl`).



#### Required Commands

Run these commands sequentially within the target WSL directory *after* file provisioning has finished:

```bash
# 1. Fix Existing: Apply explicit rwx permissions and mask to all current assets recursively
sudo setfacl -R -m u:1001:rwx,m:rwx [TARGET_DIRECTORY]

# 2. Fix Future: Establish default inheritance so new sub-items preserve shared rwx access
sudo setfacl -R -d -m u:1001:rwx,m:rwx [TARGET_DIRECTORY]

```

---

### Strategy 2: Container Runtime Permission Hijacking via Entrypoint

This approach shifts remediation responsibility into the container lifecycle. A custom entrypoint script checks ownership at boot and dynamically uses `chown` to correct access blocks.

#### Constraints & Prerequisites

* **Security Exposure:** Requires granting passwordless `sudo` privileges to the containerized application user, adding security risks.


* **Driver Requirements:** Must be coupled with either the VirtioFS file-sharing driver in Docker Desktop settings or a native Docker Engine configuration running inside the WSL Ubuntu instance.



#### Technical Implementation

Create an `entrypoint.sh` script:

```bash
#!/bin/bash
set -e

TARGET_DIR="/home/agentuser/workspace"

# Evaluate ownership and remediate if host user (1000) maintains control
if [ "$(stat -c %u "$TARGET_DIR")" != "1001" ]; then
    echo "Permissions mismatch detected. Adjusting ownership..."
    sudo chown -R agentuser:agentuser "$TARGET_DIR"
fi

exec "$@"

```

Integrate into the `Dockerfile` infrastructure:

```dockerfile
RUN apt-get update && apt-get install -y sudo
RUN echo "agentuser ALL=(ALL) NOPASSWD: /usr/bin/chown" >> /etc/sudoers

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER agentuser
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["npm", "start"]

```

---

### Strategy 3: Shared Group Bind and Setgid Mapping

This strategy resolves boundaries by aligning group memberships rather than individual user IDs. By matching GIDs and leveraging the Linux `Setgid` bit, files remain accessible to both execution spaces without modifying primary owners or altering masks.

#### Constraints & Prerequisites

* **Session Lifecycle:** Requires a one-time host user group assignment modification and a subsequent WSL session restart to apply active group tokens.
* **Compose Mapping:** Demands explicit runtime configuration within the container engine specification layer to bind Supplementary GIDs.

#### Technical Implementation

**Step A: Host Group Registration (One-time)**
Expose GID `1001` on the WSL host machine and link the primary user to it:

```bash
sudo groupadd -g 1001 agentgroup || true
sudo usermod -aG agentgroup $USER

```

**Step B: Host Folder Permission Mapping**
Configure the project directory to use group ownership and enable group propagation:

```bash
# 1. Alter group assignment to match the container target GID
sudo chgrp -R 1001 "$SANDBOX_DIR"

# 2. Open Group write access permissions (chmod 775)
sudo chmod -R 775 "$SANDBOX_DIR"

# 3. Apply the Setgid bit so new files inherit GID 1001 automatically
#    NOTE: setgid only covers files CREATED inside the directory
#          (by the container at runtime). It does NOT cover files
#          PROVISIONED via cp -r or mv — those preserve source
#          metadata and must be fixed explicitly.
sudo chmod -R g+s "$SANDBOX_DIR"

```

**Step C: Container Engine Configuration**
Update `docker-compose.yml` to run processes under the shared scope:

```yaml
services:
  agent:
    image: agent-workspace:latest
    user: "1001:1001"
    group_add:
      - 1001

```

---

### Strategy 4: UID Mapping (User Hijack) — Universal Solution

This strategy synchronizes the container's identity with the host's identity at build time. Instead of making the host open permissions to a foreign user, the container "becomes" the host user. The container process runs as the same UID/GID as the developer who launches it, making file ownership a non-issue across all platforms.

#### Why This Is the Universal Solution

| Platform | UID Mapping Outcome |
|---|---|
| **WSL (Native Docker Engine)** | The container runs as the host UID — every file `cp`/`mkdir`/`touch` is natively owned by the right user. |
| **Docker Desktop (macOS)** | macOS's virtiofs bridge performs identity translation. UID Mapping is technically redundant on Mac (Docker Desktop grants access regardless), but it does not break anything and provides environment parity. |
| **Docker Desktop (Windows)** | The hypervisor layer masks host UIDs. UID Mapping ensures the container requests the right identity, avoiding permission denials. |
| **CI/CD (GitHub Actions, etc.)** | Runners have a known UID — UID Mapping ensures the workspace is always writable. |

Unlike Strategy 3 (Shared Group Bind), which fails on macOS and Windows Docker Desktop because the hypervisor does not recognise host-side group assignments, UID Mapping works at the process identity level — a concept every OS and hypervisor respects.

#### Constraints & Prerequisites

* **Build-time Dependency:** The image must be rebuilt for each machine where the developer has a different UID/GID. This is a one-time cost per machine; subsequent builds use cached layers.
* **UID Collision Handling:** Official Docker images (e.g., `node`) often pre-create a user at UID 1000. The Dockerfile must handle this case gracefully — if the host UID conflicts with an existing user, rename the existing user rather than failing.
* **Pipeline Impact:** The build system (`build_agent`, `build_sandbox`) must accept `HOST_UID` and `HOST_GID` as build arguments and thread them into `docker build --build-arg`.

#### Technical Implementation

**Step A: Dockerfile — Handle UID/GID Arguments and Collisions**

```dockerfile
# Accept Host IDs as Build Arguments
ARG HOST_UID=1000
ARG HOST_GID=1000

# 1. If the host UID matches an existing user (e.g. node at UID 1000),
#    rename that user to agentuser. Otherwise create a new user.
# 2. Same for the group.
RUN if getent passwd ${HOST_UID}; then \
        EXISTING_USER=$(getent passwd ${HOST_UID} | cut -d: -f1); \
        usermod -l agentuser -m -d /home/agentuser $EXISTING_USER; \
        groupmod -n agentgroup $(getent group ${HOST_GID} | cut -d: -f1); \
    else \
        groupadd -g ${HOST_GID} agentgroup && \
        useradd -u ${HOST_UID} -g agentgroup -m agentuser; \
    fi

# All baked file ownership must use numeric IDs, not usernames,
# because the username may not exist (if useradd was skipped).
RUN chown -R ${HOST_UID}:${HOST_GID} /home/agentuser

USER agentuser
```

**Step B: Compose — Run as Host UID/GID**

```yaml
services:
  agent:
    build:
      context: .
      args:
        HOST_UID: ${HOST_UID:-1000}
        HOST_GID: ${HOST_GID:-1000}
    user: "${HOST_UID:-1000}:${HOST_GID:-1000}"
    volumes:
      - .:/home/agentuser/workspace
```

**Step C: Build Pipeline — Export and Thread Host IDs**

The startup script (`start_agent.sh`) exports the host identity before invoking compose:

```bash
export HOST_UID=$(id -u)
export HOST_GID=$(id -g)
```

Build functions (`build_sandbox`, `build_agent`) pass them through to Docker:

```bash
docker build \
  --build-arg HOST_UID=${HOST_UID} \
  --build-arg HOST_GID=${HOST_GID} \
  ...
```

#### Failure Cases Avoided

| Failure | How UID Mapping Avoids It |
|---|---|
| **The Mask Trap** — ACL mask downgrades `rwx` to `r-x` | Not applicable — no ACLs involved. Container runs as the file Owner, not Other. |
| **The Sudo Loop** — recurring `sudo setfacl` after every file sync | Never needed — same UID means every new file is natively owned by the container process. |
| **The Preflight Fail** — application writability checks fail | Passes natively — the process owns the bind mount directory. |
| **Platform Lock-In** — solution only works on one OS | Works on macOS, Windows DD, WSL native, Linux, and CI. |

#### Pros and Cons

**Pros:**
- Total inheritance: `cp`, `mv`, `mkdir` work natively — no post-copy scripts needed.
- No ACL complexity: eliminates the mask-throttling problem entirely.
- Zero runtime overhead: no `chown -R` in entrypoint, no `setfacl` at startup.
- Environment parity: WSL/Linux development feels as seamless as macOS.

**Cons:**
- Build-time dependency: developers with non-standard UIDs must rebuild images locally.
- Dockerfile complexity: requires conditional user-rename logic for UID collisions.
- Image tied to host UID: images are not portable across machines with different host UIDs (rebuild required).

---

