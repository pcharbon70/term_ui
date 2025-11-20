# /fix-tests

Orchestrate test failure resolution by delegating specific fixing tasks to the
test-fixer agent.

## Orchestration Process

As the orchestrator, you will:

1. **Identify failing tests**:

   - Run test suite to find failures
   - Categorize failure types
   - Prioritize what to fix first

2. **Analyze failure patterns**:

   - Determine root causes
   - Identify fix approach
   - Assess dependencies between failures

3. **Delegate to test-fixer**:

   - Give specific test fixing tasks
   - Specify which tests to fix
   - Provide error context
   - Define success criteria

4. **Coordinate fixing process**:
   - The test-fixer will execute your instructions
   - It will return summaries of fixes applied
   - You decide if more fixes are needed

## What the Agent Provides

### **Language-Agnostic Debugging Methodology**

- Proven systematic approach for any programming language and testing framework
- Focus-driven debugging (one test at a time)
- Root cause analysis rather than symptom fixes

### **Expert Consultation Integration**

- **Language-Specific Experts**: The test-fixer will consult the appropriate
  language expert (elixir-expert, lua-expert, neovim-expert, etc.) for
  framework-specific debugging patterns
- **Research Support**: Uses **research-agent** when encountering unfamiliar
  frameworks or error patterns
- **Pattern Consistency**: Uses **consistency-reviewer** to ensure fixes align
  with existing patterns

### **Quality Assurance**

- Systematic failure prioritization (infrastructure → core → integration → edge
  cases)
- Complete regression testing after each fix
- Expert validation of fix quality and approach

## Agent Workflow

The **test-fixer** agent follows this systematic approach:

### Phase 1: Failure Assessment & Expert Consultation

- Run comprehensive test failure analysis
- Consult appropriate language experts for debugging guidance
- Prioritize failures using proven framework

### Phase 2: Focused Test Resolution

- Isolate target test using focus mechanisms
- Apply systematic failure analysis with expert guidance
- Investigate root causes rather than symptoms

### Phase 3: Implementation & Verification

- Implement fixes based on expert consultation
- Verify fixes don't introduce regressions
- Apply language-specific quality checks

### Phase 4: Progress Tracking & Quality Assurance

- Remove focus tags and continue with next failure
- Track resolution progress and patterns
- Final quality verification with expert agents

## Success Criteria

The **test-fixer** agent ensures:

- ✅ **Root Cause Resolution**: Fixes address underlying issues, not just
  symptoms
- ✅ **Language-Appropriate Fixes**: Uses correct patterns and conventions for
  your specific language/framework
- ✅ **No Regressions**: Comprehensive testing prevents new issues
- ✅ **Pattern Consistency**: Fixes align with existing codebase patterns
- ✅ **Expert-Validated Approach**: Guidance from the appropriate language
  expert (elixir-expert, lua-expert, neovim-expert, etc.)

## Example Orchestration

```markdown
# As orchestrator, you would:

1. Run tests and find 5 authentication tests failing
2. Analyze: All failing with "JWT token invalid" errors

3. Delegate to test-fixer: "Fix the 5 failing authentication tests in
   test/auth/. They're all failing with JWT token errors. Check test
   configuration and mock setup."

4. Test-fixer returns: "✅ Complete - Fixed 5 tests. Root cause: Missing
   JWT_SECRET in test.exs config. Added config and updated mocks."

5. You verify and continue: "Good. Now run full suite to check for other
   failures..."
```

## Usage Examples

```bash
/fix-tests
# Orchestrator identifies failures and delegates fixes to test-fixer

# For specific test failures
"Fix the failing user validation tests"
# Orchestrator analyzes validation test failures and coordinates fixes

# For systematic resolution
"Fix all test failures one by one"
# Orchestrator prioritizes and systematically delegates fixing tasks
```

## Key Benefits

- **Clear separation**: Orchestrator analyzes, test-fixer executes
- **Expert debugging**: Test-fixer proactively uses language experts
- **Quality control**: You verify each fix before proceeding
- **Systematic approach**: You control the fixing priority and strategy

You maintain control of the resolution strategy while the test-fixer handles the
technical debugging with expert support.
