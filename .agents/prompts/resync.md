---
description: "Re-install the repository's staged config tree into $AGENT_HOME/agent after a reprovision reverted it. Copies only the files that differ, adds and overwrites but never deletes, and reports what moved."
argument-hint: "[optional: one skill name to narrow the sweep]"
---

> $ARGUMENTS

# /resync - Re-install the working copy

**Scope:** `$AGENT_HOME/agent/` is a projection of the image stage at `/opt/workflow/agent/config/agent/`, not of the repository. A repo change reaches the running session only after a rebuild, and a reprovision restores the stage over anything copied in during the session. This closes the gap for the current session and nothing longer. It does not rebuild the image.

`.agents/prompts/` is outside this sweep. It is read from the project tree itself: the pi settings record names it in its `prompts` key, so a file there needs no copy into `$AGENT_HOME/agent/`. An edit to one takes effect on `/reload`.

## 1. Compare, do not guess

Report the repository files under the staged tree that differ from their installed counterparts. Pass a skill name as the argument to narrow it to one directory.

```bash
cd <repo root>
git ls-files src/reasoning/providers/pi/config/agent/ | while read -r f; do
  rel="${f#src/reasoning/providers/pi/config/agent/}"
  case "$rel" in auth.json|models-store.json) continue;; esac
  case "$rel" in *"${1:-}"*) ;; *) continue;; esac
  diff -q "$f" "$AGENT_HOME/agent/$rel" >/dev/null 2>&1 || echo "differs: $rel"
done
```

## 2. Copy the differences

Overwrite the installed file. Never delete, and never run `rsync --delete`. The installed tree also holds skills and files the image does not stage, including `architect`, `arena`, `poteto-mode`, `principle-*`, `sessions/` and `models-store.json`, so a mirror destroys them.

Credentials are never synced. `auth.json` and `models-store.json` hold state the session owns.

## 3. Verify

Re-run step 1 and require it to report nothing. If the change carried an executable artifact, run it from its installed path and show the output.

## 4. Report

Name the files copied and the mtime of `/opt/workflow/agent/config/agent/`. If that date predates the change, say that the copy will not survive the next reprovision and that a rebuild is the durable fix.
