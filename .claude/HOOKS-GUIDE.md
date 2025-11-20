# Claude Code Hooks - Complete Guide

> **Official Documentation**:
> https://docs.anthropic.com/en/docs/claude-code/hooks

## Table of Contents

- [Overview](#overview)
- [Hook Events](#hook-events)
- [Configuration](#configuration)
- [Input (What Hooks Receive)](#input-what-hooks-receive)
- [Output (How Hooks Communicate Back)](#output-how-hooks-communicate-back)
- [Practical Examples](#practical-examples)
- [Security Considerations](#security-considerations)
- [Best Practices](#best-practices)

## Overview

Claude Code hooks are shell commands that execute at specific points during your
interaction with Claude. They allow you to:

- ✅ Add project context automatically
- ✅ Validate or block dangerous operations
- ✅ Run formatters/linters after code changes
- ✅ Log interactions for audit purposes
- ✅ Customize Claude's behavior per project

**Key Characteristics:**

- Hooks run **synchronously** (blocking)
- Execute as **shell commands** with your user permissions
- Can **modify Claude's behavior** through exit codes and JSON output
- Are configured in `~/.claude/settings.json` or project-specific settings

## Hook Events

### Available Hook Events

| Event                | When It Fires                                | Common Use Cases                                                |
| -------------------- | -------------------------------------------- | --------------------------------------------------------------- |
| **UserPromptSubmit** | When you submit a prompt to Claude           | Add context, validate input, log requests                       |
| **PreToolUse**       | Before Claude uses a tool (Read, Edit, etc.) | Validate operations, check permissions, block dangerous actions |
| **PostToolUse**      | After a tool completes successfully          | Run formatters, linters, tests, update documentation            |
| **Notification**     | When Claude sends notifications              | Log events, send alerts                                         |
| **Stop**             | When Claude finishes responding              | Cleanup, final validation, summary generation                   |
| **SubagentStop**     | When a subagent finishes                     | Track subagent usage, aggregate results                         |

## Configuration

### Location

Hooks are configured in JSON settings files:

- **Global**: `~/.claude/settings.json`
- **Project**: `.claude/settings.json` in project root
- **Environment-specific**: Can use different configs per environment

### Basic Configuration Structure

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "regex-pattern", // Optional: filter by tool name
        "hooks": [
          {
            "type": "command",
            "command": "path/to/script.sh"
          }
        ]
      }
    ]
  }
}
```

### Real Configuration Example

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/add-context.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/validate-changes.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/format-code.sh"
          }
        ]
      }
    ]
  }
}
```

## Input (What Hooks Receive)

### 1. Environment Variables

| Variable                | Description                 | Example                 |
| ----------------------- | --------------------------- | ----------------------- |
| `CLAUDE_PROJECT_DIR`    | Current project directory   | `/home/user/my-project` |
| Standard shell env vars | All your normal environment | `$HOME`, `$PATH`, etc.  |

### 2. Standard Input (stdin) - PRIMARY INPUT METHOD

**Hooks receive a JSON object via stdin containing all event information.** This
is the primary way Claude passes data to hooks.

#### JSON Structure for PostToolUse Events:

```json
{
  "session_id": "uuid",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "hook_event_name": "PostToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "/path/to/edited/file.md",
    "old_string": "original content",
    "new_string": "new content"
  },
  "tool_response": {
    "filePath": "/path/to/edited/file.md"
    // Additional response data
  }
}
```

#### Reading stdin in your hook:

```bash
#!/bin/bash
# Read the complete JSON input
INPUT=$(cat)

# Parse specific fields (using jq if available)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path')

# Or use grep/sed for simple parsing
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)
```

### 3. Command Arguments

Hooks are called with **zero command-line arguments**. All data comes through
stdin and environment variables.

## Output (How Hooks Communicate Back)

### 1. Exit Codes

| Exit Code        | Effect                                      | Use Case                      |
| ---------------- | ------------------------------------------- | ----------------------------- |
| **0**            | Success, continue normally                  | Normal completion             |
| **2**            | **BLOCK the action**, show stderr to Claude | Prevent dangerous operations  |
| Other (1, 3-255) | Non-blocking error, show stderr             | Warnings, non-critical issues |

**Example - Blocking Dangerous Operations:**

```bash
#!/bin/bash
if [[ "$1" == *"rm -rf"* ]]; then
    echo "BLOCKED: Attempting to recursively delete files" >&2
    exit 2  # This STOPS Claude from proceeding
fi
exit 0
```

### 2. Standard Output (stdout)

Simple text output is shown to Claude (in transcript mode) or the user:

```bash
#!/bin/bash
echo "=== Project Context ==="
echo "Branch: $(git branch --show-current)"
echo "Last commit: $(git log -1 --oneline)"
echo "Uncommitted changes: $(git status -s | wc -l) files"
```

### 3. JSON Response (Most Powerful)

Return structured JSON for fine-grained control:

#### General JSON Structure

```json
{
  "continue": true|false,           // Whether to proceed
  "stopReason": "string",           // Message if stopping
  "suppressOutput": true|false,     // Hide stdout from user
  "additionalContext": "string"     // Add context for Claude
}
```

#### Event-Specific JSON Fields

**UserPromptSubmit:**

```json
{
  "additionalContext": "Working in production environment. Be extra careful with database operations."
}
```

**PreToolUse:**

```json
{
  "permissionDecision": "allow|deny",
  "stopReason": "Cannot modify files in /etc directory"
}
```

## Practical Examples

### Example 1: Smart Project Context Injection

```bash
#!/bin/bash
# ~/.claude/hooks/add-project-context.sh
# Adds relevant context based on project type

detect_and_add_context() {
    local context=""

    # Elixir/Phoenix project
    if [ -f "mix.exs" ]; then
        context+="Elixir/Phoenix project detected.\n"
        context+="Mix env: ${MIX_ENV:-dev}\n"
        context+="Remember: Use 'mix run' not 'elixir' for scripts.\n"

        if [ -f ".formatter.exs" ]; then
            context+="Formatter configured - will auto-format on save.\n"
        fi
    fi

    # Node.js project
    if [ -f "package.json" ]; then
        context+="Node.js project detected.\n"
        context+="Package manager: $([ -f "yarn.lock" ] && echo "yarn" || echo "npm")\n"

        if [ -f "tsconfig.json" ]; then
            context+="TypeScript enabled with strict: $(grep '"strict"' tsconfig.json | grep -q true && echo "yes" || echo "no")\n"
        fi
    fi

    # Python project
    if [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
        context+="Python project detected.\n"
        context+="Virtual env: ${VIRTUAL_ENV:-none active}\n"
    fi

    # Git information
    if [ -d ".git" ]; then
        context+="Git branch: $(git branch --show-current)\n"
        context+="Uncommitted changes: $(git status -s | wc -l) files\n"
    fi

    if [ -n "$context" ]; then
        cat <<EOF
{
  "additionalContext": "$context"
}
EOF
    fi
}

detect_and_add_context
```

### Example 2: Code Quality Gate

```bash
#!/bin/bash
# ~/.claude/hooks/validate-code-quality.sh
# Runs after Edit/Write operations

validate_code() {
    local file="$1"
    local exit_code=0
    local errors=""

    # Elixir validation
    if [[ "$file" == *.ex ]] || [[ "$file" == *.exs ]]; then
        # Check compilation
        if ! mix compile --warnings-as-errors >/dev/null 2>&1; then
            errors+="Compilation warnings detected. "
            exit_code=1
        fi

        # Check formatting
        if ! mix format --check-formatted "$file" >/dev/null 2>&1; then
            errors+="File is not formatted. Running formatter...\n"
            mix format "$file"
        fi

        # Check credo
        if command -v mix >/dev/null && mix credo --strict "$file" >/dev/null 2>&1; then
            errors+="Credo issues found. "
            exit_code=1
        fi
    fi

    # TypeScript/JavaScript validation
    if [[ "$file" == *.ts ]] || [[ "$file" == *.tsx ]]; then
        if command -v npx >/dev/null; then
            # Run ESLint
            if ! npx eslint "$file" >/dev/null 2>&1; then
                errors+="ESLint issues found. "
                exit_code=1
            fi
        fi
    fi

    if [ -n "$errors" ]; then
        echo "$errors" >&2
    fi

    return $exit_code
}

# Main execution
if [ -n "$1" ]; then
    validate_code "$1"
fi
```

### Example 3: Security Guardian

```bash
#!/bin/bash
# ~/.claude/hooks/security-check.sh
# Prevents dangerous operations in production

check_security() {
    local operation="$1"
    local current_branch=$(git branch --show-current 2>/dev/null)
    local is_production=false

    # Detect production environment
    if [[ "$MIX_ENV" == "prod" ]] || \
       [[ "$NODE_ENV" == "production" ]] || \
       [[ "$current_branch" == "main" ]] || \
       [[ "$current_branch" == "master" ]]; then
        is_production=true
    fi

    if [ "$is_production" = true ]; then
        # Block dangerous database operations
        if echo "$operation" | grep -iE "(drop|truncate|delete.*from)" >/dev/null; then
            cat <<EOF >&2
{
  "continue": false,
  "stopReason": "⛔ BLOCKED: Dangerous database operation detected in production environment. Switch to a feature branch or development environment."
}
EOF
            exit 2
        fi

        # Block secret exposure
        if echo "$operation" | grep -iE "(api_key|secret|password|token).*=" >/dev/null; then
            cat <<EOF >&2
{
  "continue": false,
  "stopReason": "⛔ BLOCKED: Potential secret exposure detected. Use environment variables or secret management tools."
}
EOF
            exit 2
        fi
    fi

    return 0
}

# Check if we received input to validate
if [ -n "$1" ]; then
    check_security "$1"
fi
```

### Example 4: Auto-Documentation

```bash
#!/bin/bash
# ~/.claude/hooks/update-docs.sh
# Automatically updates documentation after code changes

update_documentation() {
    local changed_file="$1"

    # Update API documentation for Elixir
    if [[ "$changed_file" == lib/*.ex ]]; then
        if command -v mix >/dev/null; then
            echo "Regenerating ExDoc documentation..."
            mix docs >/dev/null 2>&1
        fi
    fi

    # Update TypeScript documentation
    if [[ "$changed_file" == *.ts ]] || [[ "$changed_file" == *.tsx ]]; then
        if [ -f "typedoc.json" ]; then
            echo "Regenerating TypeDoc documentation..."
            npx typedoc >/dev/null 2>&1
        fi
    fi

    # Update README if specific files change
    if [[ "$changed_file" == "package.json" ]] || [[ "$changed_file" == "mix.exs" ]]; then
        echo "Project dependencies changed - consider updating README"
    fi
}

if [ -n "$1" ]; then
    update_documentation "$1"
fi
```

## Security Considerations

⚠️ **CRITICAL SECURITY NOTES:**

1. **Hooks execute with YOUR permissions** - They can do anything you can do
2. **Always validate and sanitize inputs** - Hooks receive external input
3. **Be careful with secrets** - Don't log sensitive information
4. **Review hook commands carefully** - Especially if sharing configurations
5. **Use absolute paths** - Avoid PATH manipulation attacks

### Security Best Practices

```bash
#!/bin/bash
# GOOD: Security-conscious hook

# Use set -euo pipefail for safety
set -euo pipefail

# Validate input
if [[ ! "$1" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
    echo "Invalid input detected" >&2
    exit 1
fi

# Use absolute paths
readonly SAFE_DIR="/home/user/project"
cd "$SAFE_DIR" || exit 1

# Don't expose secrets
export DATABASE_URL="***hidden***"

# Log safely
echo "Operation performed on $(date)" >> /tmp/claude-hooks.log
```

## Best Practices

### 1. Performance

- **Keep hooks fast** (<1 second ideally)
- **Use async operations** when possible (background jobs)
- **Cache expensive operations**

### 2. Reliability

- **Handle errors gracefully**
- **Use defensive programming**
- **Test hooks thoroughly**
- **Log for debugging** (but not sensitive data)

### 3. Maintainability

- **Version control your hooks** (use Chezmoi!)
- **Document hook behavior**
- **Use consistent naming**
- **Make hooks idempotent**

### 4. Organization

```
~/.claude/
├── settings.json           # Global configuration
└── hooks/
    ├── add-context.sh     # Context injection
    ├── validate.sh        # Validation hooks
    ├── format.sh          # Formatting hooks
    ├── security.sh        # Security checks
    └── lib/
        └── common.sh      # Shared functions
```

### 5. Testing Hooks

```bash
#!/bin/bash
# Test your hooks before deploying

# Test with mock environment
CLAUDE_PROJECT_DIR="/tmp/test-project" \
    ./hooks/add-context.sh

# Test blocking behavior
echo "DROP TABLE users;" | ./hooks/security.sh
echo "Exit code: $?"  # Should be 2 for blocking

# Test JSON output
./hooks/add-context.sh | jq .  # Validate JSON structure
```

## Common Patterns

### Language Detection Pattern

```bash
detect_language() {
    [ -f "mix.exs" ] && echo "elixir"
    [ -f "Cargo.toml" ] && echo "rust"
    [ -f "package.json" ] && echo "javascript"
    [ -f "pyproject.toml" ] && echo "python"
    [ -f "go.mod" ] && echo "go"
}
```

### Conditional Hook Execution

```bash
# Only run in certain environments
[ "$CI" = "true" ] && exit 0  # Skip in CI
[ -z "$CLAUDE_HOOKS_ENABLED" ] && exit 0  # Feature flag
```

### Logging Pattern

```bash
readonly LOG_FILE="$HOME/.claude/hooks.log"
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}
```

## Troubleshooting

1. **Hooks not firing**: Check settings.json syntax and file permissions
2. **Hooks blocking everything**: Ensure exit codes are correct (0 for success)
3. **Performance issues**: Profile hooks with `time` command
4. **JSON errors**: Validate with `jq` or online JSON validators

## Additional Resources

- **Official Docs**: https://docs.anthropic.com/en/docs/claude-code/hooks
- **Settings Reference**:
  https://docs.anthropic.com/en/docs/claude-code/settings
- **Example Configurations**: Check the Claude Code GitHub repository

---

_Remember: Hooks are powerful but execute with your permissions. Always review
and test hooks before use, especially when sharing configurations or using hooks
from others._
