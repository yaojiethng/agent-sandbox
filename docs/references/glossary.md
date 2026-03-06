# Glossary

This glossary defines core terminology used throughout the project documentation.

For architectural context see:

- [System Overview](../architecture/system_overview.md)
- [Agent Runtime](../architecture/agent_runtime.md)
- [Sandbox Model](../architecture/sandbox_model.md)

---

# Core System Concepts

## Sandbox
The containerized execution environment used to run coding agents safely.

See:  
[Sandbox Model](../architecture/sandbox_model.md)

The sandbox ensures:

- filesystem isolation
- controlled execution
- reproducible environments
- staged outputs before repository modification

---

## Orchestrator
The workflow responsible for dispatching tasks and managing agent execution.

See:  
[Orchestration Model](../concepts/orchestration.md)

The orchestrator:

- dispatches tasks
- collects outputs
- stages results
- approves repository modifications

In the current implementation, the orchestrator is the **human operator**.

---

## Agent Runtime
The execution environment used by coding agents.

See:  
[Agent Runtime](../architecture/agent_runtime.md)

The runtime includes:

- container configuration
- entrypoint scripts
- filesystem layout
- execution policies

---

# Agent Concepts

## Coding Agent
An automated system capable of performing software development tasks.

See:  
[Agents](../concepts/agents.md)

Typical capabilities include:

- reading code
- writing code
- modifying files
- executing tests
- producing diffs

---

## Agent Provider
An external system that supplies the intelligence used by a coding agent.

See:  
[Provider Integration](../architecture/provider_integration.md)

Examples of providers include LLM interfaces or agent frameworks.

Agent providers are **implementation details** of the runtime.

---

## Provider Adapter
The integration layer connecting an agent provider to the sandbox runtime.

See:  
[Provider Integration](../architecture/provider_integration.md)

Responsibilities include:

- translating tasks to provider requests
- managing provider execution
- normalizing outputs

---

# Workflow Concepts

## Task
A defined unit of work assigned to a coding agent.

See:  
[Tasks](../concepts/tasks.md)

Tasks usually contain:

- task description
- relevant files
- constraints
- expected outputs

---

## Diff
A set of file modifications produced by an agent.

See:  
[Diff Workflow](../concepts/diffs.md)

Diffs represent **proposed repository changes**.

They must be reviewed before being applied.

---

## Staged Output
Artifacts produced by agents but **not yet committed** to the repository.

See:  
[Sandbox Model](../architecture/sandbox_model.md)

Examples:

- diffs
- generated files
- logs
- test results

---

# Execution Modes

## Safe Mode
Execution mode where strict sandbox constraints apply.

See:  
[Sandbox Model](../architecture/sandbox_model.md)

Restrictions may include:

- limited filesystem access
- restricted command execution
- mandatory output staging

---

## Unsafe Mode
Execution mode where sandbox restrictions are relaxed.

This mode is intended only for controlled development environments.

---

# Architecture Concepts

## Parent Agent
An orchestration agent responsible for dispatching tasks.

See:  
[Orchestration Model](../concepts/orchestration.md)

Responsibilities may include:

- planning work
- dividing tasks
- coordinating child agents

---

## Child Agent
An execution agent responsible for implementing a specific task.

See:  
[Agents](../concepts/agents.md)

Child agents:

- operate inside the sandbox
- perform a single focused task
- return results to the orchestrator

---

## Workspace
A temporary filesystem environment where an agent performs work.

The workspace contains:

- a checkout of the repository
- task-specific files
- generated artifacts

Workspaces are typically destroyed after task completion.

---

## Artifact
A file produced by an agent as the result of a task.

Artifacts may include:

- generated code
- logs
- reports
- test results

Artifacts may or may not be committed to the repository.

---

## Action
A single executable step performed by an agent during task execution.

Examples include:

- editing a file
- executing a command
- running tests

Actions are usually part of a larger task plan.

---

## Observation
Information returned to the agent after performing an action.

Examples include:

- command output
- test failures
- file contents

Observations allow the agent to reason about the next action.

---

## Plan
A structured sequence of steps created by an agent to complete a task.

Plans may evolve dynamically as the agent observes new results.

---

## Execution Loop
The iterative cycle followed by an agent while performing a task.

Typical pattern:

Plan → Action → Observation → Reflection → Next Action

# Documentation Concepts

## Layered Documentation
A documentation model where documents are organized by abstraction level.

See:  
[Documentation Structure](../development/repository_structure.md)

Lower layers describe system architecture, while higher layers describe workflows.

---

## Documentation Drift
A condition where documentation no longer reflects system behavior.

See:  
[Contributing Guide](../development/contributing.md)

Mitigation strategies include:

- minimal edits
- architecture freezes
- documentation reviews