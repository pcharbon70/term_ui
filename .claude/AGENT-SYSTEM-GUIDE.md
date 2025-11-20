# Agent System Optimization Guide

## Overview

This guide documents the agent system model and tool optimization implemented to
achieve cost efficiency while maintaining quality through appropriate model
selection and tool permissions.

## Model Specifications

### YAML Frontmatter Schema

```yaml
---
name: agent-name
model: opus # or sonnet, or haiku
tools: Read, Grep, Glob, LS, NotebookRead, WebSearch, WebFetch
description: Agent description
color: agent-color
---
```

### Model Assignments

**Opus (Highest capability, highest cost)**:

- elixir-expert, research-agent, architecture-agent
- Complex analysis, expert knowledge, architectural decisions

**Sonnet (Balanced capability and cost)**:

- All reviewer agents, all planning agents, all implementation agents
- Analysis, planning, comprehensive review tasks, and complex implementation

**Haiku (Fast, cost-effective)**:

- Currently unused - all agents require reasoning capabilities
- Reserved for future simple automation tasks

## Tool Permission Categories

### No Permission Required

- Glob, Grep, LS, NotebookRead, Read, Task, TodoWrite

### Permission Required

- Bash, Edit, MultiEdit, NotebookEdit, WebFetch, WebSearch, Write

## Agent Tool Sets

### Expert Agents (opus model)

**Tools**: `Read, Grep, Glob, LS, NotebookRead, Task, WebSearch, WebFetch`

- Read-only access to files
- Can perform web research
- Can consult other agents via Task
- **Special case**: elixir-expert also has Bash for mix commands

### Reviewer Agents (sonnet model)

**Tools**: `Read, Grep, Glob, LS, NotebookRead, WebSearch, WebFetch`

- Read-only access to files and web research
- Analyze and return findings

### Planning Agents (sonnet model)

**Tools**: `Task, Read, Write, TodoWrite, Grep, Glob, LS, NotebookRead`

- Can create planning documents
- Can consult other agents
- Cannot modify existing code files

### Implementation Agents (sonnet model)

**Tools**: All tools including `Bash, Edit, MultiEdit, NotebookEdit, Write`

- Full access to implement changes
- Balanced reasoning capability for complex implementation decisions
- Coordinate effectively with expert agents

## Expert Guidance Workflow

### Standard Expert Response Format

````markdown
## Analysis Summary

Brief overview of findings

## Guidance

- Step-by-step implementation instructions
- Code patterns to follow
- Configuration requirements

## Code Examples

```language
// Concrete examples following best practices
```
````

## Important Considerations

- Performance, security, testing concerns
- Common pitfalls to avoid

## Next Steps

1. Specific action items
2. Files to create/modify
3. Commands to run

````

### Implementation Agent Request Pattern

```markdown
## Expert Consultation Request

**Context**: [current situation]
**Goal**: [what needs to be implemented]
**Specific Questions**:
1. [implementation approach]
2. [best practices]
3. [potential issues]

Please provide detailed implementation guidance.
````

## Cost Optimization Benefits

- **Balanced cost and capability** across all agents
- **Expert models** (opus) for specialized domain knowledge
- **Balanced models** (sonnet) for analysis, planning, and implementation
- **Clear role separation** between analysis and execution
- **Quality maintained** through appropriate model selection for task complexity

## Tool Limitations by Agent Type

### Read-Only Agents (Experts/Reviewers)

```
## Tool Limitations

You have read-only access to files and can perform web research. You cannot modify files or execute commands.
Your role is to analyze and return detailed findings and recommendations.
The calling agent will implement any necessary changes based on your guidance.
```

### Planning Agents

```
## Tool Limitations

You can create planning documents and consult other agents but cannot modify existing code files.
Your role is to create comprehensive plans that implementation agents will execute.
```

### Implementation Agents

```
## Working with Expert Guidance

Before making significant changes, consult appropriate expert agents for guidance:
- Request detailed implementation instructions
- Follow expert recommendations precisely
- Report back on implementation results
```

## Agent Selection Guide

**elixir-expert**: Elixir/Phoenix/Ecto questions, OTP patterns, testing
strategies **architecture-agent**: Project structure, module design, component
boundaries **research-agent**: Unknown libraries, API integration, technology
evaluation **documentation-expert**: Creating documentation with industry
methodologies **documentation-reviewer**: Documentation quality assurance and
standards compliance **security-reviewer**: Authentication, data validation,
vulnerability assessment **implementation-agent**: Execute planning documents,
implement expert guidance **test-developer**: Systematic test development with
expert consultation **test-fixer**: Test failure diagnosis and resolution

This system optimizes costs while maintaining quality through appropriate model
selection and clear role separation between analysis and implementation.
