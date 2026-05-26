# User Story — Website Dev Project Onboarding

**Status:** Investigation. Not yet on roadmap as a milestone.

---

## Context

A website dev project with a local backend API proxy and a frontend server, both run in a project-owned Dockerfile. Goal is to onboard the project into agent-sandbox so the agent can write code, with the operator reviewing and applying diffs in the normal workflow.

---

## Pain Points

- Need to expose additional ports from the container (frontend server, backend proxy) beyond the default serve mode port
- Live reload is part of the dev workflow — agent writes to sandbox, operator wants to preview changes in a browser before applying
- Unclear whether live reload against an agent-written sandbox creates a security risk

---

## Open Questions & Current Thinking

### Port exposure

Exposing ports to `127.0.0.1` on the host does not materially expand the network attack surface beyond what standard mode already allows (outbound AI provider access). The risk is not inbound exploitation from the network.

The practical requirement is: additional ports declared in the Dockerfile and published in the `docker run` invocation. This is per-project configuration — opt-in via project `.env` or Makefile, not hardcoded in the harness. Needs a mechanism for projects to declare extra ports without modifying core scripts.

### XSS / malicious write risk

**This is a real and credible threat vector.** The agent has write access to sandbox files. If it writes malicious JavaScript to a frontend file — intentionally, or via prompt injection from external content it fetched — and live reload is active, the browser executes it against the operator's session.

The current architecture provides a natural review gate: changes only reach the host after the operator applies the diff. The risk window is specifically if live reload is pointed at sandbox output directly, bypassing that gate.

**Mitigations under consideration:**

1. **Separate browser profile (near-term, no architecture change)** — treat the live preview browser as untrusted. Use a dedicated browser profile with no saved sessions, no auth cookies for sensitive services, and no access to password managers. Low friction, operator discipline required.

2. **Sandboxed browser in Docker → WSL → Windows** — technically possible via WSLg or X forwarding but adds display stack complexity and latency. Mouse interactivity through the full stack is not guaranteed to be smooth. Not recommended as a near-term solution; revisit if the separate profile approach proves insufficient.

3. **Content Security Policy on the dev server** — if the project's dev server can be configured with a strict CSP, this limits what injected scripts can do. Project-specific mitigation, not a harness concern.

**Decision needed:** formalise one of the above as the recommended protocol before enabling live port exposure. Option 1 is the pragmatic near-term answer. Needs a hardening note in the threat model (`threat_model_stride.md`) under External Network Threats or a new Human/Operational Misuse entry.

### Project Dockerfile interop

The project has its own Dockerfile for running the dev servers. The agent-sandbox harness has its own Dockerfile for the agent runtime. These are distinct concerns and should stay separate — the agent-sandbox container runs the agent; the project's dev servers run in their own container or on the host. The agent writes to sandbox; the dev server reads from a mounted or synced copy of those files if live reload is desired.

Mount strategy for live reload needs to be designed: either mount sandbox output into the dev server container, or use a file watcher that copies from sandbox to a host path the dev server watches. The former is cleaner but requires coordination between containers.

---

## Constraints

- Port exposure must be opt-in and per-project; no harness-wide changes
- The review gate (diff before apply) must not be bypassed for production-bound changes
- Browser sandboxing via Docker → WSL → Windows is not a near-term viable option

---

## Next Steps

1. Decide on safe browse protocol (option 1 recommended)
2. Add hardening note to threat model
3. Design per-project port declaration mechanism
4. Design live reload mount strategy
5. When ready to implement, pull into a milestone with full task list
