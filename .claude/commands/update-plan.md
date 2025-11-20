# Update Planning Document Command

## Purpose

Update existing planning documents (features, fixes, or tasks) with new
information, requirements, or changes while maintaining proper structure and
implementation guidance.

## When to Use

- **New requirements** discovered during implementation
- **Scope changes** or additional functionality needed
- **Technical constraints** or approach modifications
- **User feedback** requiring plan adjustments
- **Implementation blockers** requiring plan revision
- **Architecture changes** affecting the original plan

## Process

### Step 1: Identify Current Planning Document

1. **Locate active planning document**:

   - Check `notes/features/` for feature plans
   - Check `notes/fixes/` for fix plans
   - Check `notes/tasks/` for task plans
   - Identify the most relevant document for current work

2. **If no planning document exists**:
   - Use `/feature`, `/fix`, or `/task` commands first
   - Create proper planning foundation before updating

### Step 2: Analyze Current State vs New Requirements

1. **Review existing plan**:

   - Read current planning document thoroughly
   - Understand what has been implemented so far
   - Identify what remains to be done

2. **Assess new information**:
   - Gather all new requirements or changes
   - Understand impact on existing plan
   - Determine if changes are additive or modifications

### Step 3: Update Planning Document

1. **Use appropriate planning agent**:

   - **feature-planner**: For feature plan updates
   - **fix-planner**: For fix plan updates
   - **task-planner**: For task plan updates

2. **Planning agent responsibilities**:
   - Incorporate new information systematically
   - Update affected sections (requirements, implementation steps, success
     criteria)
   - Maintain plan structure and completeness
   - Add new implementation steps as needed
   - Update timelines and priorities
   - Document what has changed and why

### Step 4: Prepare Implementation Guidance

1. **Mark completed items**: Clearly indicate what has been finished
2. **Highlight changes**: Show what's new or modified
3. **Update next steps**: Provide clear guidance for implementation agents
4. **Update success criteria**: Ensure criteria reflect new requirements
5. **Add any new considerations**: Security, performance, testing implications

### Step 5: Signal Implementation Readiness

1. **Update plan status**: Mark as "updated and ready for implementation"
2. **Create implementation todos**: Clear action items for implementation agents
3. **Document change rationale**: Explain why updates were needed
4. **Highlight priority changes**: What needs immediate attention

## Example Usage Patterns

### New Feature Requirements

```markdown
## Plan Update: Additional Authentication Requirements

**New Requirements**:

- Multi-factor authentication support
- Social login integration (Google, GitHub)
- Session management improvements

**Updated Implementation Steps**:

- [Previous steps 1-5 remain unchanged]
- Step 6: Implement MFA flow with TOTP support
- Step 7: Add social OAuth providers
- Step 8: Enhanced session security measures

**Updated Success Criteria**:

- [Previous criteria plus]
- MFA can be enabled/disabled per user
- Social login works with existing user accounts
- Session security meets updated requirements
```

### Technical Constraint Changes

```markdown
## Plan Update: Database Migration Approach Change

**Context**: Performance testing revealed current approach won't scale

**Updated Approach**:

- Change from single migration to chunked migrations
- Add progress tracking and rollback capabilities
- Implement migration in background job

**Updated Implementation Steps**:

- [Steps 1-3 remain unchanged]
- Step 4: [MODIFIED] Create chunked migration strategy
- Step 5: [NEW] Implement background job processing
- Step 6: [NEW] Add migration progress monitoring
```

### Scope Expansion

```markdown
## Plan Update: Additional Platform Support

**Scope Expansion**:

- Original: Web application only
- Updated: Web + mobile API support
- New: Real-time notifications

**New Implementation Steps**:

- [All previous steps remain]
- Step 8: Design mobile-friendly API endpoints
- Step 9: Implement WebSocket notification system
- Step 10: Add mobile-specific error handling
```

## Planning Agent Integration

This command leverages the appropriate planning agent based on document type:

### Feature Plans

- **feature-planner**: Updates comprehensive feature documents
- Maintains full structure and research integration
- Handles complex scope changes and new requirements

### Fix Plans

- **fix-planner**: Updates focused fix documents
- Adjusts problem analysis and solution approach
- Handles new constraints or blockers

### Task Plans

- **task-planner**: Updates lightweight task documents
- Simple requirement changes and scope adjustments
- May escalate to feature-planner or fix-planner if complexity increases

## Success Indicators

- **Clear change documentation**: What changed and why
- **Updated implementation steps**: Actionable guidance for implementers
- **Maintained plan structure**: All required sections complete
- **Implementation readiness**: Clear next steps for implementation agents
- **Change impact assessment**: Understanding of how updates affect
  timeline/scope

**CRITICAL**: All plans must include test requirements:

- Test strategy updated for new/changed requirements
- Test completion criteria clearly defined
- Implementation agents understand testing is mandatory for completion

## Implementation Handoff

After plan update:

1. **implementation-agent**: Can execute updated plan systematically
2. **Clear change markers**: Implementation agents know what's new/changed
3. **Priority guidance**: What needs attention first
4. **Updated success criteria**: Clear completion definition

This command ensures planning documents stay current with evolving requirements
while providing clear guidance for implementation teams to execute the updated
plan effectively.
