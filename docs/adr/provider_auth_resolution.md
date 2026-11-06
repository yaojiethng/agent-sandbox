# Provider Auth Resolution

**Current:** 2026-11-04

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One credential resolution owner | The provider resolves its credentials; the harness does not. |
| R2 | The harness passes, it does not inspect | Provider environment variables reach the container and the provider starts; the harness reads no auth map and resolves no key reference. |
| R3 | A missing credential is a provider state | The harness does not refuse startup; the provider offers its own repair path, such as `/login`. |

## 2026-11-04 -- The provider resolves its own credentials

**Decision:** The harness passes the configured provider environment variables into the container and starts the provider. It does not inspect `auth.json`, resolve key references, or refuse to start when no credential is present. The provider resolves its own credentials and offers its own login path, such as pi's `/login`.

**Rationale:** Credential resolution is provider-specific: the auth file shape, the key references and the login flow differ per provider. A harness resolver would be a second resolution path that must track each provider's rules. It would shadow the provider's own repair path, which the operator can already use after startup, and it would add no capability the harness lacks.

**Rejected alternatives:**

- *A preflight auth guard* -- rejected on intent: it duplicates each provider's resolution, including literal keys and environment references, and a naive check refuses a valid setup. It also cannot offer the provider's own login path.
- *An entrypoint resolver* -- rejected on intent: it is the same second resolution path, maintained per provider, with the same mismatch risk.
- *A startup warning only* -- rejected as insufficient: it reports a state the provider already reports, away from the repair path, and adds no capability.

**Edge cases / drivers:** A headless or dry run may not prompt, and the first request fails as it does today; the operator fixes the key and restarts. A provider with no login path owns its own error, and the [T12 `pi upstream` row](../../devlog/roadmap.md) holds that case.
