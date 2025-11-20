# Task Planning and Execution

**IMPORTANT**: Use the **task-planner** agent for lightweight task planning and
the appropriate specialized agents for complex work.

## Command Overview

This command helps determine the right approach for your work item and delegates
to the appropriate planning agent.

## Decision Framework

### 1. **Determine Work Type**

- **Complex New Functionality** → Use **feature-planner** agent (follow
  feature.md)
- **Bug Fixes or Issues** → Use **fix-planner** agent (follow fix.md)
- **Simple Tasks** → Use **task-planner** agent (this command)

### 2. **Task Planning Process**

For simple tasks, use the **task-planner** agent which will:

- Create lightweight planning document in ./notes/tasks/<task_name>.md
- Include essential task description and todo list
- Consult **research-agent** when working with unfamiliar tools
- Consult **elixir-expert** for Elixir-related tasks
- Use **consistency-reviewer** for pattern-related work

### 3. **Git Workflow**

- Check if already on an appropriate task branch (e.g., task/\*)
- If not on a task branch, create a new one
- Use conventional commits
- Make small commits while working
- Do not reference claude in the commit messages

### 4. **Agent Integration**

The **task-planner** agent knows when to consult other agents:

- **research-agent**: For unfamiliar technologies or approaches
- **elixir-expert**: For any Elixir/Phoenix/Ash/Ecto work
- **consistency-reviewer**: When maintaining existing patterns
- Escalates to **feature-planner** or **fix-planner** if complexity exceeds
  scope

## What the Task-Planner Provides

### **Right-Sized Planning**

- Minimal overhead for straightforward tasks
- Essential structure without over-engineering
- Quick execution while maintaining planning discipline

### **Smart Escalation**

- Recommends **feature-planner** for complex functionality
- Recommends **fix-planner** for issues requiring investigation
- Ensures appropriate level of planning for work complexity

### **Expert Consultation**

- Includes necessary agent consultations without over-engineering
- Consults **research-agent** for unfamiliar concepts
- Uses language experts when appropriate

## Example Task Types

**Good for task-planner:**

- Configuration changes
- Simple refactoring
- Documentation updates
- Tool setup or installation
- Small improvements

**Should use feature-planner:**

- New complex functionality
- Multi-component integrations
- Architectural changes

**Should use fix-planner:**

- Bug investigations
- Security issues
- System stability problems

## Implementation Notes

- Do not reference claude in commit messages
- Follow established git workflow practices
- Update planning document as work progresses
- Mark tasks complete as you finish them
