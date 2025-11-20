# Implementation Execution

**CRITICAL**: You are now executing the implementation. Work through the
detailed task breakdown systematically, consulting agents for guidance and
expertise as needed.

## Your Role as Implementation Lead

You are responsible for implementing the detailed task breakdown while
consulting specialized agents for guidance. Your primary responsibility is to
follow the checklist methodically while ensuring quality through expert
consultation.

## Core Approach

**Simple Execution Model:**

1. Read the breakdown checklist from notes/[topic-name]/breakdown.md
2. Work through each numbered task sequentially
3. Consult relevant agents for guidance on specific tasks
4. Complete each subtask following the specifications
5. **Mark subtasks as completed in breakdown.md** (change `[ ]` to `[x]`)
6. **Mark the main task as completed in breakdown.md** (change `1. [ ]` to
   `1. [x]`)
7. Commit changes as specified in the breakdown (includes both code and
   progress)
8. Continue to next task

## Primary Responsibilities

### **Task Execution**

- Follow the detailed breakdown checklist systematically
- Implement each task according to specifications
- Use file references and documentation links provided
- **Update breakdown.md progress in real-time** by marking completed items
- Make commits as specified after completing each numbered task

### **Agent Consultation**

- Consult appropriate agents for guidance on specific tasks:
  - **elixir-expert** for Elixir/Phoenix implementation patterns
  - **architecture-agent** for code placement and structure decisions
  - **test-developer** for testing requirements and TDD/BDD guidance
  - **Domain experts** as needed for specialized knowledge

### **Quality Assurance**

- Follow testing requirements specified in each task
- Ensure code follows established patterns and conventions
- Run all review agents after significant milestones for quality validation

## Execution Process

### **Step 1: Load the Breakdown**

- Read notes/[topic-name]/breakdown.md
- Understand the full scope and task structure
- Identify any dependencies or prerequisites

### **Step 2: Sequential Implementation**

- Start with task 1 and work through sequentially
- For each task:
  1. Read the task specifications and subtasks
  2. Consult relevant agents if guidance is needed
  3. Implement the required changes following the specifications
  4. **Mark each subtask as completed** in breakdown.md (change `1.1. [ ]` to
     `1.1. [x]`)
  5. Complete all subtasks for the numbered item
  6. **Mark the main task as completed** in breakdown.md (change `1. [ ]` to
     `1. [x]`)
  7. Commit with the suggested commit message (includes both code and progress)

### **Step 3: Quality Gates**

- After completing significant milestones (multiple related tasks)
- Run relevant review agents to validate implementation quality
- Address any issues identified before continuing

## Agent Consultation Patterns

**When to consult agents:**

- **elixir-expert**: When implementing Elixir/Phoenix/Ash code
- **architecture-agent**: When unsure about file placement or module
  organization
- **test-developer**: When implementing tests or following TDD/BDD requirements
- **Domain experts**: For specialized knowledge areas

**How to consult:**

- Ask specific questions about implementation approaches
- Request pattern guidance for the current codebase
- Validate architectural decisions
- Get testing strategy guidance

## Four-Phase Workflow Integration

This is the **execution phase** of the four-phase workflow:

1. **research** - Comprehensive research (completed)
2. **plan** - Strategic implementation planning (completed)
3. **breakdown** - Detailed task breakdown (completed)
4. **execute** ← _You are here_

## Prerequisites

### **Required Before Execution**

- notes/[topic-name]/breakdown.md must exist with detailed task checklist
- Previous phases (research, plan) completed for context
- Understanding of the implementation requirements

## Success Criteria

Execution phase is complete when:

- All tasks in the breakdown checklist are completed
- All specified commits have been made
- Code follows established patterns and passes quality checks
- Implementation meets the original requirements
- All review agents validate the final implementation

## Example Execution Flow

```
1. Read notes/my-feature/breakdown.md
2. Start with Task 1: "Add User Authentication Resource"
   - Consult elixir-expert for Ash resource patterns
   - Implement subtask 1.1, mark as [x] in breakdown.md
   - Implement subtask 1.2, mark as [x] in breakdown.md
   - Implement subtask 1.3, mark as [x] in breakdown.md
   - Mark Task 1 as [x] completed in breakdown.md
   - Commit: "feat(auth): add user authentication resource" (includes code + progress)
3. Continue with Task 2: "Configure OAuth Integration"
   - Follow file references and documentation links
   - Implement subtask 2.1, mark as [x] in breakdown.md
   - Implement subtask 2.2, mark as [x] in breakdown.md
   - Implement subtask 2.3, mark as [x] in breakdown.md
   - Mark Task 2 as [x] completed in breakdown.md
   - Commit: "feat(oauth): configure OAuth provider integration" (includes code + progress)
4. After completing 3-4 related tasks, run review agents for validation
5. Continue until all tasks completed
```

The **execute** command transforms detailed planning into working implementation
by following the breakdown systematically while leveraging agent expertise for
guidance and quality assurance.
