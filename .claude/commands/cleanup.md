# Elixir Project Cleanup

**IMPORTANT**: For Elixir projects, consult **elixir-expert** for proper cleanup
patterns and use **elixir-reviewer** for final validation.

## Cleanup Process

1. **Consult elixir-expert** for project-specific cleanup guidance
2. **Compile with warnings as errors**: `mix compile --warnings-as-errors`
   - Fix all compilation issues
3. **Run credo strict analysis**: `mix credo --strict`
   - Fix all issues including minor ones
4. **Run test suite**: `mix test`
   - Fix all test failures
   - Fix all warnings in test output
   - Address deprecated function warnings
   - Clean up any IO.inspect or debugging output
5. **Remove unnecessary comments**: Remove all unnecessary one-line comments
6. **Format code**: `mix format`
7. **Final validation**: Use **elixir-reviewer** agent to run comprehensive
   quality checks
8. **Commit changes**: Use conventional commits
