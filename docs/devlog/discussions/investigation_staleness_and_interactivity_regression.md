# Investigation — Image Staleness and Interactivity Regression

**Status:** Open Discussion
**Date:** 2026-04-12
**Context:** An operator encountered a regression of a previously solved bug (interactivity/TTY issues) when running the harness on a new repository. The cause was identified as the harness running a stale container image without warning the operator that the underlying scripts had changed.

---

## 1. Problem Statement

The harness currently lacks a mechanism to ensure that the container images it runs are up-to-date with the logic defined in the repository's `libs/` and `scripts/` directories. 

**Symptoms:**
- Changes to core harness scripts (e.g., [`libs/provider-entrypoint.sh`](../libs/provider-entrypoint.sh)) do not take effect unless the operator manually runs `make build`.
- Regressions to "solved" bugs occur when old images persist on a machine.
- No warning is issued when an image is out-of-sync with the current source.

---

## 2. Research & Documentation Audit

### Discrepancies
- **[`docs/devlog/changelog.md`](../devlog/changelog.md):** Claims Milestone 1.4 "Image Staleness Detection" is complete and provides a warning. **Reality:** This logic is missing from the current `start` flow.
- **[`docs/architecture/execution_model.md`](../architecture/execution_model.md):** States that *"Docker's layer cache is the primary staleness mechanism... no separate digest comparison is required."* **Reality:** This is only true during the build phase. At runtime, the harness does not check if the image matches the source.
- **[`libs/containers.sh`](../libs/containers.sh):** The `preflight` function only performs a existence check:
  ```bash
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    # build...
  fi
  ```

### The Interactivity Regression
The specific bug encountered (inability to interact with Pi) relates to how [`libs/provider-entrypoint.sh`](../libs/provider-entrypoint.sh) handles process backgrounding to allow for `EXIT` trap persistence. While the latest version of the script is designed to handle TTY correctly, an older version of the image "baked in" a broken version of this logic. Because the image name matched, the harness used it without question.

---

## 3. Considerations

- **Simplicity:** The solution must not require the operator to understand Docker internals or the hashing logic.
- **Onboarding Friction:** Any new check must be transparent. We should not require additional flags or manual versioning from the user.
- **Performance:** Avoid expensive file-system scans on every `make start`.
- **Changelog Integrity:** The changelog is currently causing confusion by listing "scrapped" or "regressed" features as complete.

---

## 4. Diagnosis

The system failed to detect the stale container because the **Pre-flight Gate** is too narrow. It only checks if an image *exists*. Because project-specific images (e.g., `pi-agent-my-repo`) often depend on shared base images (e.g., `pi-base`), changes to the shared harness libraries are "hidden" from the project's start-up logic.

---

## 5. Proposals

### A. Harness Signature Check (The "Simple Signature")
Instead of a complex file-by-file digest, implement a lightweight **Harness Signature** check:
1.  **Bake a Signature:** During `make build`, compute a SHA-1 of the core harness directory (`libs/`) and embed it as a Docker label: `agent-sandbox.harness-sig`.
2.  **Verify at Start:** In [`scripts/start_agent.sh`](../scripts/start_agent.sh), re-compute the local signature. Compare it against the label of the existing image using `docker inspect`.
3.  **Warning/Action:** If they mismatch, issue a clear warning: 
    > `WARNING: Harness scripts have been updated. Your image is stale. Run 'make build' to apply updates.`

### B. Documentation Cleanup
- **Archive the Changelog:** Move `docs/devlog/changelog.md` to `docs/archive/history.md`. It is a historical record of development, not a specification of current behavior.
- **Correct the Execution Model:** Update [`docs/architecture/execution_model.md`](../architecture/execution_model.md) to accurately describe the signature check and remove the false claim that the layer cache handles runtime staleness.

### C. Optional: `INTERACTIVE` Flag
Consider adding an `INTERACTIVE=true` environment variable to the provider configuration. This would allow [`libs/provider-entrypoint.sh`](../libs/provider-entrypoint.sh) to bypass backgrounding entirely for providers that require absolute TTY fidelity, at the cost of losing the "Copy-out" persistence on hard crashes (SIGKILL).

---

## 6. Next Steps
1.  Agree on the signature scope (e.g., the `libs/` folder).
2.  Implement the signature label in [`libs/containers.sh`](../libs/containers.sh).
3.  Add the comparison logic to the `preflight` gate.
4.  Relocate the changelog to prevent future confusion.
