# Agent Runtime

The agent runtime describes how coding agents execute tasks inside the system.

Agents operate within containerized environments and interact with the
repository through controlled interfaces.

The runtime typically performs the following operations:

1. Receive a task or milestone.
2. Analyze repository state.
3. Generate code modifications.
4. Run tests or validation commands.
5. Stage outputs for review.

Agents may operate in a parent/child hierarchy to decompose complex tasks
while limiting recursion depth.

The runtime is responsible for enforcing boundaries such as:

- filesystem isolation
- container limits
- execution modes (safe vs unsafe)
- staged output validation

Operational details for running the system are described in:

- operations/quickstart.md
- operations/setup_barebones.md
- operations/setup_complete.md