# System Overview

This document describes the high-level architecture of the project.

The system is a sandbox and execution harness for autonomous coding agents.
It provides a controlled environment where agents can read, modify, and test
code while maintaining safety boundaries.

The system consists of several major components:

- Agent orchestration
- Containerized execution environments
- Staged output validation
- Security controls and operational safeguards

The goal of the system is to allow autonomous coding agents to operate
productively while preventing unsafe or uncontrolled modifications
to the host environment.

Detailed architecture components are described in:

- agent_runtime.md
- security_model.md
- threat_model_stride.md