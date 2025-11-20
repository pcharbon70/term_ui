Create a plan and implement a bug fix or issue resolution.

Follow these steps:

1. **Git Workflow**

   - Check if already on an appropriate fix branch (e.g., fix/\*)
   - If not on a fix branch, create a new one
   - Use conventional commits (fix: description)
   - Make small commits while working, so we can better analyze changes and
     revert if necessary
   - Do not reference claude in the commit messages

2. **Investigation Phase**

   - ultrathink
   - Always check the existing codebase, documentation, usage-rules
   - Reproduce the issue reliably
   - Analyze error messages, logs, and symptoms
   - Check existing codebase, documentation, and related issues
   - Create parallel sub-agents and analyse the problem from the following
     perspectives: factual, senior engineer, security expert, consistency
     reviewer, and let their feedback guide the fix
   - Create sub agent to check usage-rules and docs for the libraries we are
     going to use while fixing the issue
   - Save investigation docs in the notes/fixes folder in the project (unless
     otherwise specified)

3. **Implementation**
   - Follow the fix planning document structure below
   - After every step of implementation, update the planning document with a
     summary and wait for further instructions
   - add regression tests
   - Identify root cause through debugging
   - Update the plan frequently as you discover new information
   - Mark completed tasks clearly with ✅ and add detailed status summaries
   - Include current status section with "what's broken", "what's fixed", and
     "how to test"
   - Document discovered complications immediately when found

**CRITICAL**: Fixes are NOT complete without regression tests:

- Every bug fix must include tests that verify the fix
- Regression tests must fail before the fix and pass after
- All existing tests must continue to pass
- Use test-developer for comprehensive test creation
- Never claim fix completion without working tests

## Fix Planning Document Structure

### 1. Issue Description

- Clear description of the problem or bug
- Steps to reproduce the issue
- Expected vs actual behavior
- Impact and urgency level

### 2. Root Cause Analysis

- Investigation findings
- Where the issue originates
- Why it's happening (technical explanation)
- Related components or dependencies affected

### 3. Solution Overview

- High-level approach to fix the issue
- Key technical decisions
- Alternative approaches considered and why they were rejected

### 4. Technical Details

- File locations that need changes
- Configuration specifics
- Dependencies or prerequisites
- Backwards compatibility considerations

### 5. Testing Strategy

- How to verify the fix works
- Regression testing approach
- Edge cases to validate
- Performance impact assessment

### 6. Rollback Plan

- How to revert changes if issues arise
- Monitoring points to watch post-deployment
- Backup procedures if applicable

### 7. Implementation Plan

For simple fixes: single checklist with integrated testing For complex fixes:
break into logical steps, each with its own validation

#### Step Format (for complex fixes)

- [ ] Investigate and confirm root cause
- [ ] Implement the fix
- [ ] Test the fix thoroughly
- [ ] Validate no regressions introduced

## Example: Simple Bug Fix

```markdown
# Fix Login Timeout Issue

## Issue Description

Users are experiencing login timeouts after 30 seconds, but the expected timeout
should be 5 minutes.

**Steps to reproduce:**

1. Navigate to login page
2. Enter credentials but wait 35 seconds before submitting
3. Submit form
4. Observe timeout error

**Expected:** 5-minute timeout **Actual:** 30-second timeout **Impact:** High -
affects user experience

## Root Cause Analysis

- Investigated session configuration in `config/session.conf`
- Found timeout value set to 30000ms instead of 300000ms
- Likely a typo during initial configuration

## Solution Overview

Update session timeout configuration from 30 seconds to 5 minutes in the session
configuration file.

## Technical Details

- **File:** `config/session.conf`
- **Change:** `session_timeout = 300000` (was 30000)
- **No breaking changes expected**

## Testing Strategy

- Manual test: Login and wait 4 minutes, verify session active
- Manual test: Login and wait 6 minutes, verify session expired
- Automated test: Update session timeout test expectations

## Rollback Plan

- Revert `config/session.conf` to previous value
- Restart service to apply old configuration

## Implementation Plan

- [ ] Update session timeout value in config file
- [ ] Test timeout behavior manually
- [ ] Update automated tests
- [ ] Deploy and monitor for issues
```

## Example: Complex Bug Fix

```markdown
# Fix Memory Leak in Background Job Processor

## Issue Description

Background job processor is consuming increasing amounts of memory over time,
eventually causing out-of-memory crashes.

**Steps to reproduce:**

1. Start application with background job processor
2. Queue multiple jobs continuously
3. Monitor memory usage over 2+ hours
4. Observe memory continuously increasing

**Expected:** Stable memory usage **Actual:** Memory increases 10MB every hour
**Impact:** Critical - causes production crashes

## Root Cause Analysis

- Memory profiling revealed job objects not being garbage collected
- Jobs hold references to large data objects after completion
- `JobProcessor.cleanup()` method not properly releasing references
- Issue introduced in commit abc123 when adding job result caching

## Solution Overview

Implement proper cleanup of job references and cached data after job completion.
Add memory monitoring and periodic garbage collection.

## Technical Details

- **Files:**
  - `src/jobs/JobProcessor.js` - Main processor logic
  - `src/jobs/JobCache.js` - Result caching system
  - `tests/integration/memory-test.js` - Memory leak tests
- **Changes:**
  - Add explicit cleanup in job completion handler
  - Implement LRU cache with size limits
  - Add memory monitoring middleware

## Testing Strategy

- Memory profiling tests running jobs for 4+ hours
- Unit tests for cleanup methods
- Integration tests for cache size limits
- Performance benchmarks to ensure no regression

## Rollback Plan

- Revert to commit before caching feature (def456)
- Disable job result caching via feature flag
- Monitor memory usage returns to baseline

## Implementation Plan

### Step 1: Investigate and Reproduce

- [ ] Set up memory profiling environment
- [ ] Reproduce issue with test job queue
- [ ] Identify specific objects not being released
- [ ] Confirm root cause in job completion flow

### Step 2: Implement Core Fix

- [ ] Add explicit cleanup in JobProcessor completion handler
- [ ] Update JobCache to use LRU with size limits
- [ ] Add memory usage logging
- [ ] Test fix resolves memory leak

### Step 3: Add Monitoring and Tests

- [ ] Implement memory monitoring middleware
- [ ] Add automated memory leak detection tests
- [ ] Update existing job tests for cleanup verification
- [ ] Performance test to ensure no regression

### Step 4: Deployment and Validation

- [ ] Deploy to staging with monitoring
- [ ] Run 24-hour memory stability test
- [ ] Deploy to production with careful monitoring
- [ ] Validate memory usage remains stable
```

## Debugging Guidelines

### Investigation Techniques

- **Reproduce consistently** - Ensure you can trigger the issue reliably
- **Check logs and error messages** - Look for patterns and stack traces
- **Use debugging tools** - Profilers, debuggers, monitoring tools
- **Isolate the problem** - Narrow down to specific components or conditions
- **Review recent changes** - Check git history for related modifications

### Documentation Requirements

- **Record investigation steps** - What you tried and what you found
- **Document evidence** - Screenshots, log snippets, error messages
- **Note environment details** - OS, versions, configuration differences
- **Track time spent** - Helps with future similar issues

## Critical Success Factors

1. **Reproduce the issue first** - Never start fixing what you can't reproduce
2. **Understand root cause** - Don't just treat symptoms
3. **Test thoroughly** - Verify fix works and doesn't break anything else
4. **Document learnings** - Help prevent similar issues in the future
5. **Monitor post-fix** - Ensure the issue stays resolved

## Communication Patterns

### Issue Reporting

- **Be specific about symptoms** - Exact error messages, steps to reproduce
- **Include environment details** - What's different about failing cases
- **Assess impact and urgency** - Help prioritize the fix appropriately
- **Provide debugging context** - What you've already tried

### Fix Documentation

- **Explain the 'why'** - Not just what you changed, but why it fixes the issue
- **Document side effects** - Any other behavior that might change
- **Include testing evidence** - Proof that the fix works as intended
- **Plan for monitoring** - How to detect if the issue returns
