# Update Documentation Command

## Purpose

Systematically update all project documentation to reflect the current state of
the code using specialized documentation agents.

## Process

### Step 1: Context Analysis

1. **Identify current work**:

   - Check git branch to understand feature/fix context
   - Review recent commits for changes
   - Identify affected components and systems

2. **Locate existing documentation**:
   - Feature/fix documentation in `notes/**/**.md`
   - Project documentation in `docs/**/**.md`
   - Special files: `PROJECT.md`, `CLAUDE.md`, `README.md`
   - API documentation and architecture diagrams

### Step 2: Documentation Expert Consultation

Use **documentation-expert** to:

- Apply appropriate documentation methodology
- Update documentation following industry standards
- Ensure consistency with style guides
- Implement accessibility best practices
- Create missing documentation sections

### Step 3: Documentation Updates

The documentation-expert will:

1. **Analyze code changes** against existing documentation
2. **Identify gaps** in documentation coverage
3. **Update existing docs** to reflect current implementation
4. **Create new sections** for undocumented features
5. **Ensure consistency** across all documentation

### Step 4: Quality Review

Use **documentation-reviewer** to:

- Verify technical accuracy
- Check completeness and coverage
- Validate style guide compliance
- Assess readability and accessibility
- Identify improvement opportunities

### Step 5: Commit Changes

- Stage all documentation updates
- Create descriptive commit message
- Include what documentation was updated and why

## Documentation Types to Update

### **Project Documentation**

- README.md - Project overview and quick start
- PROJECT.md - Detailed project information
- CLAUDE.md - AI assistant instructions
- CONTRIBUTING.md - Development guidelines
- CHANGELOG.md - Version history

### **Feature Documentation**

- Feature planning documents in `notes/features/`
- Implementation status and progress
- API documentation for new endpoints
- User guides for new functionality

### **Technical Documentation**

- Architecture diagrams and decisions
- API reference documentation
- Configuration guides
- Troubleshooting documentation
- Performance documentation

### **Developer Documentation**

- Code comments and docstrings
- Setup and installation guides
- Development workflow documentation
- Testing documentation

## Quality Standards

Documentation must meet these criteria:

- **Accurate**: Reflects current code state
- **Complete**: All features documented
- **Consistent**: Follows style guides
- **Accessible**: WCAG compliant
- **Maintainable**: Easy to update

## Example Workflow

```bash
# On feature branch
git checkout feature/user-authentication

# Run update-docs command
/update-docs

# Process:
# 1. documentation-expert analyzes changes
# 2. Updates all affected documentation
# 3. documentation-reviewer validates quality
# 4. Commits documentation updates
```

## Integration with Other Commands

- Run after `/feature` completion
- Run after `/fix` implementation
- Run before creating pull requests
- Include in release preparation

This command ensures documentation stays synchronized with code changes through
systematic updates using specialized documentation agents.
