# Image construction patterns

Open this when a Dockerfile pins a base, installs packages, copies files, or sets the user, the work directory and the entrypoint.

## p-49 A base image is pinned to a tag

```dockerfile
FROM node:22.22.3-slim
```

A floating tag names whatever the registry holds that day, so two builds a month apart are different images under one name and a fault found in one cannot be reproduced from the other. Pin the tag, and pin the digest as well where a rebuild has to reproduce bit for bit.

- Variant: `ARG BASE_IMAGE=agent-base` with `FROM ${BASE_IMAGE}` keeps the base selectable without leaving it floating, because the default it carries is the pinned one.

Replaces: `FROM ubuntu:latest`, and a base named with no tag at all, which means `latest` without saying so.

## p-50 A package install is one layer, and it clears the lists in that layer

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      curl \
    && rm -rf /var/lib/apt/lists/*
```

Split across layers, the index a build fetched is cached in one layer and read in another, so a year later the install resolves packages against a list the registry no longer serves. The index is also a copy of every package name the install read, which the running image has no use for. Keep the update, the install and the removal in the one `RUN`, or the layer cache decides which of the three runs.

Replaces: `RUN apt-get update` and `RUN apt-get install` in two layers, and an install layer that leaves `/var/lib/apt/lists/*` behind.

## p-51 Privilege work happens before the user switch

```dockerfile
RUN mkdir -p /home/agentuser/workspace \
    && chown -R ${HOST_UID}:${HOST_GID} /home/agentuser
USER agentuser
```

A step that needs root belongs above the `USER` line, where the build is still root. After the switch the step either fails or the image carries a way to become root again, and a container that can elevate at runtime is a container whose non-root user is a claim rather than a boundary.

Replaces: `sudo` in a `RUN` or in the entrypoint script, which installs the elevation path into the image, and an install or a `chown` written below the `USER` line.

## p-52 Files arrive by `COPY`, not `ADD`

```dockerfile
COPY src/libs/     /opt/sandbox/lib/
COPY docs/reference/ /opt/sandbox/docs/reference/
```

`COPY` copies. `ADD` copies and then decides from the argument whether to do something else, so one instruction means two things and the reader cannot tell which from the line.

- Variant: `ADD` has two shapes `COPY` cannot express, extracting a local tar archive and fetching a URL. A URL fetch belongs in a `RUN` layer with `curl` or `wget`, so the layer records what arrived and can be pinned; tar extraction is a build step that unpacks a tarball the build already has, and then writes `ADD <file>.tar.gz /`. Neither shape is a reason to copy a directory with `ADD`.

Replaces: `ADD ./src /opt/src`, which is `COPY` carrying an extraction rule nobody asked for.

## p-53 The entrypoint is written in exec form

```dockerfile
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh"]
```

The shell form runs `/bin/sh -c <the string>`, so the process the container starts is a shell, and the script is its child. A stop signal then reaches the shell, which forwards it or does not, and the exit status the container reports is the shell's. Exec form starts the script as the process the container runs.

Replaces: `ENTRYPOINT /opt/sandbox/bin/provider-entrypoint.sh`, which is the shell form whether or not it reads like one.

## p-54 The image runs as a non-root user whose id is a build argument

```dockerfile
ARG HOST_UID=1000
ARG HOST_GID=1000
RUN useradd -l -m -u ${HOST_UID} -s /bin/bash agentuser
RUN chown -R ${HOST_UID}:${HOST_GID} /home/agentuser
USER agentuser
```

A container that runs as root writes root-owned files into anything mounted into it, and the next run on the host cannot read or replace them. The user's id is a build argument with a default rather than a literal, because the host mounting a volume has an id of its own and the two have to match; ownership is applied before the switch, since after it the process cannot.

Replaces: no `USER` line, which leaves the image running as root; a bare `USER agentuser` with the id invented inside the image, which is the same mismatch one layer down; and the literal `1000` repeated in the user creation and in every `chown` with no argument behind it.

## p-55 The work directory is set

```dockerfile
WORKDIR /home/agentuser/sandbox
```

`WORKDIR` sets the directory a `RUN`, a `COPY` destination and the started process all read relative paths against. Unset, it is `/`, so every relative path in the build and in the entrypoint depends on where the process happened to start, and the next instruction added to the file inherits the ambiguity.

Replaces: relying on the default, and `RUN cd /somewhere && ...`, whose directory does not outlive the line.

## p-56 A build-time value is `ARG`, a run-time value is `ENV`

```dockerfile
ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}
ENV AGENT_HOME=/home/agentuser/.pi
```

`ARG` exists during the build and is gone afterwards; `ENV` is in the image and reaches the started process. A value the entrypoint reads has to be `ENV`, or it is absent at the moment it is read, and a value only the build reads has no reason to travel into every process the image starts.

- Variant: a value both the build and the runtime need is written twice, `ARG` then `ENV`, because the second cannot see the first.

Replaces: `ENV` for something only a `RUN` reads, which ships a build detail to the runtime, and `ARG` for something the entrypoint reads, which is empty at run time.

## p-57 A copy names the directories the image needs

```dockerfile
COPY src/libs/                    /opt/sandbox/lib/
COPY src/reasoning/agent/skills/  /opt/workflow/agent/skills/
```

A copy of the build context takes the repository, its history, its ignored files and its secrets into the image, and it invalidates the cache on every change anywhere in the tree, so a one-line edit rebuilds every layer after it. Name the directories the image runs from.

Replaces: `COPY . .`, and `COPY ./ /opt/app`, which are the same instruction with the destination spelled out.
