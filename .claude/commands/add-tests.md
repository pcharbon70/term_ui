# /add-tests

Orchestrate test development by delegating specific test creation tasks to the
test-developer agent.

## Orchestration Process

As the orchestrator, you will:

1. **Analyze testing needs**:

   - Identify what code needs test coverage
   - Determine test scope (unit, integration, e2e)
   - Assess existing test patterns

2. **Plan test strategy**:

   - Decide what tests to create
   - Identify testing priorities
   - Determine coverage requirements

3. **Delegate to test-developer**:

   - Give specific test creation tasks
   - Specify what functionality to test
   - Define coverage expectations
   - Provide pattern references

4. **Coordinate test development**:
   - The test-developer will execute your instructions
   - It will proactively consult experts for patterns
   - It will return summaries of tests created
   - You decide if more tests are needed

## What the Agent Provides

### **Language-Agnostic Methodology**

- Proven systematic approach for any programming language
- Incremental development with focus-driven testing
- Comprehensive coverage planning (success paths, errors, edge cases)

### **Expert Consultation Integration**

- **For Elixir Projects**: Consults **elixir-expert** for ExUnit, Ash, and
  Phoenix patterns
- **For Other Languages**: Uses **research-agent** for framework-specific
  guidance
- **Pattern Consistency**: Always checks existing test patterns with
  **consistency-reviewer**

### **Quality Assurance**

- External boundary mocking strategies
- Test data generation following established patterns
- Integration testing approaches
- Coverage verification and quality metrics

## Agent Workflow

The **test-developer** agent follows this systematic approach:

### Phase 1: Analysis & Expert Consultation

- Analyze project context and testing framework
- Consult appropriate language experts for guidance
- Check existing test patterns for consistency

### Phase 2: Test Architecture Planning

- Map coverage requirements (success, error, edge cases)
- Design test data strategy using established patterns
- Plan mock strategy for external dependencies

### Phase 3: Incremental Implementation

- Start with core success paths
- Use focus-driven development (one test at a time)
- Build comprehensive coverage systematically

### Phase 4: Quality Verification

- Verify no placeholder tests remain
- Check coverage completeness with **qa-reviewer**
- Ensure pattern consistency throughout

## Success Criteria

The **test-developer** agent ensures:

- ✅ **100% Test Pass Rate**: All tests consistently pass
- ✅ **Language-Appropriate Patterns**: Uses correct frameworks and conventions
- ✅ **Comprehensive Coverage**: Success paths, error conditions, and edge cases
- ✅ **Maintainable Structure**: Clear organization following project
  conventions
- ✅ **Expert-Validated Approach**: Guidance from relevant language specialists

## Example Orchestration

```markdown
# As orchestrator, you would:

1. Analyze code needing tests (e.g., new User model)
2. Determine test requirements (CRUD, validations, edge cases)

3. Delegate to test-developer: "Create unit tests for the User model in
   test/users/user_test.exs. Test all CRUD operations, field validations, and
   error cases. Follow existing test patterns in the test/ directory."

4. Test-developer returns: "✅ Complete - Created 15 tests covering CRUD,
   validations, and error handling. All tests passing."

5. You assess coverage and decide next steps: "Now add integration tests for
   user registration flow..."
```

## Usage Examples

```bash
/add-tests
# Orchestrator analyzes code and delegates test creation to test-developer

# For specific functionality
"Add tests for the authentication module"
# Orchestrator breaks down auth testing needs and coordinates execution

# For comprehensive coverage
"Add missing tests to achieve 80% coverage"
# Orchestrator identifies gaps and systematically delegates test creation
```

## Key Benefits

- **Clear separation**: Orchestrator strategizes, test-developer executes
- **Expert consultation**: Test-developer proactively uses language experts
- **Quality control**: You verify coverage before moving on
- **Flexible coordination**: You adapt based on test results

You maintain control of the testing strategy while the test-developer handles
the technical execution with expert support.
