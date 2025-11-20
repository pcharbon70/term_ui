# Continue Work on Current Branch

## Process

1. **Analyze current branch** to determine work type:

   - Look at git branch name
   - Find planning document in:
     - notes/feature/<feature_name>.md
     - notes/fix/<fix_name>.md
     - notes/tasks/<task_name>.md

2. **Consult appropriate agents** based on work type:

   - **Features**: Use guidance from feature.md and **feature-planner** agent
   - **Fixes**: Use guidance from fix.md and **fix-planner** agent
   - **Tasks**: Use guidance from task.md and **task-planner** agent

3. **Research unfamiliar concepts**: Use **research-agent** when encountering
   unknown technologies or patterns

4. **Read and analyze planning document**:

   - Check current status and next steps
   - Understand what's been completed
   - Identify what needs to be done next

5. **Continue with the plan**:

   - Follow the implementation steps
   - Update planning document as you progress
   - Use **consistency-reviewer** to ensure alignment with existing patterns

6. **Commit practices**: Do not reference claude in git commit messages
