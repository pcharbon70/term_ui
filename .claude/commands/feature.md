# Create Feature Planning Document and Implementation

**IMPORTANT**: Use the **feature-planner** agent to create comprehensive feature
planning documents with proper research and agent consultation.

## Command Overview

This command guides you through feature development using the
**feature-planner** agent for systematic planning, followed by implementation
with continuous plan updates.

## Workflow

### 1. **Feature Planning Phase**

- **Use feature-planner agent** to create comprehensive planning document
- The agent will:
  - Consult **research-agent** for unfamiliar technologies
  - Consult **elixir-expert** for Elixir/Phoenix/Ash features
  - Consult **senior-engineer-reviewer** for architectural decisions
  - Create structured implementation plans with clear steps
  - Save planning docs in the notes/features folder

### 2. **Git Workflow**

- Check if already on an appropriate feature branch (e.g., feature/\*)
- If not on a feature branch, create a new one
- Use conventional commits
- Make small commits while working, so we can better analyze changes and revert
  if necessary
- Do not reference claude in the commit messages

### 3. **Implementation with Plan Updates**

- Follow the planning document created by **feature-planner**
- After every step of implementation, update the planning document
- Output a summary and wait for further instructions
- Update the plan frequently as you complete tasks and discover new requirements
- Mark completed tasks clearly with ✅ and add detailed status summaries
- Include current status section with "what works", "what's next", and "how to
  run"
- Document discovered limitations immediately when found, plan next steps

**CRITICAL**: Features are NOT complete without working tests:

- Every feature must have comprehensive test coverage
- Tests must pass before considering any step complete
- Use test-developer for systematic test creation
- Never claim feature completion without working tests

## What the Feature-Planner Agent Provides

The **feature-planner** agent creates comprehensive planning documents with:

### **Expert Research Integration**

- **research-agent**: For unfamiliar technologies, APIs, frameworks
- **elixir-expert**: For Elixir, Phoenix, Ash, Ecto work
- **senior-engineer-reviewer**: For architectural decisions
- Documents all agent consultations performed

### **Structured Planning**

- Problem Statement with impact analysis
- Solution Overview with design decisions
- Technical Details with file locations and dependencies
- Success Criteria with measurable outcomes
- Implementation Plan broken into logical steps

### **Quality Assurance**

- Ensures proper research before planning
- Breaks complex features into manageable steps
- Defines clear success criteria and testing approaches
- Plans for integration and architectural considerations

## Planning Document Structure

The **feature-planner** agent will create a planning document with the following
structure:

1. **Problem Statement** - Clear description and impact analysis
2. **Solution Overview** - High-level approach and key decisions
3. **Agent Consultations Performed** - Documents all expert consultations
4. **Technical Details** - File locations, dependencies, configuration
5. **Success Criteria** - Measurable outcomes and verification
6. **Implementation Plan** - Logical steps with testing integration
7. **Notes/Considerations** - Edge cases, future improvements, risks

## Example Usage

1. **Start Planning**: Invoke the **feature-planner** agent with your feature
   description
2. **Review Plan**: The agent will create a comprehensive planning document
3. **Begin Implementation**: Follow the implementation steps in the plan
4. **Update Progress**: Mark completed tasks and update status as you work
5. **Review and Iterate**: Use review agents for quality assurance

The **feature-planner** agent handles the complexity of research integration and
structured planning, ensuring you have a solid foundation before implementation
begins.
