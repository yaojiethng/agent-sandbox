# Agents

An agent is an autonomous system capable of analyzing code,
generating modifications, and executing tasks toward a defined goal.

Agents in this system are responsible for performing coding-related work
such as implementing features, fixing bugs, or improving documentation.

Agents typically perform the following loop:

1. Observe the current repository state.
2. Plan a sequence of actions.
3. Generate code or configuration changes.
4. Execute tests or validation steps.
5. Iterate until the task is complete.

Agents may operate in a hierarchical structure where a parent agent
delegates subtasks to child agents.

This model allows complex work to be decomposed while maintaining
clear boundaries and limited execution depth.

Related documents:

- orchestration.md
- architecture/agent_runtime.md