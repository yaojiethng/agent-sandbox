#!/usr/bin/env bash
# tests/stubs/libs/snapshot.sh
# No-op stub for src/capability/snapshot.sh (container-side copy: unpack,
# worktree materialization). The capability entrypoint lists it CRITICAL and
# sources it unconditionally, so the stub lib dir must carry one for tests
# that run the entrypoint. Consumers here never invoke it:
#   - copy delivery: seeder-side unpack runs in the seeder, not the entrypoint
#   - mount delivery: the host materializes the worktree (start_agent.sh)
# If a test needs real unpack behavior, source src/capability/snapshot.sh
# directly in the fixture.
