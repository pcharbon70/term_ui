#!/bin/bash

# Claude Code Formatting Hook
# Automatically formats code files after Edit, Write, and MultiEdit operations
# Supports JavaScript/TypeScript (Prettier) and Elixir (mix format)
# Receives PostToolUse event data via stdin as JSON

set -euo pipefail

# Enable debug logging if CLAUDE_FORMAT_DEBUG is set
DEBUG="${CLAUDE_FORMAT_DEBUG:-false}"

# Log function for debugging
log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[FORMAT-HOOK DEBUG] $*" >&2
    fi
}

log_info() {
    echo "[FORMAT-HOOK] $*" >&2
}

log_error() {
    echo "[FORMAT-HOOK ERROR] $*" >&2
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect if we're in an Elixir project
is_elixir_project() {
    local dir="$1"
    # Look for mix.exs in current directory or parent directories
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/mix.exs" ]]; then
            log_debug "Found Elixir project at: $dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# Function to find project root (for Prettier configuration)
find_project_root() {
    local dir="$1"
    # Look for package.json, .prettierrc*, or git root
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/package.json" ]] || [[ -f "$dir/.prettierrc" ]] || [[ -f "$dir/.prettierrc.json" ]] || [[ -f "$dir/.prettierrc.js" ]] || [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    # Fallback to the directory itself
    echo "$1"
}

# Function to format JavaScript/TypeScript/Markdown files with Prettier
format_with_prettier() {
    local file_path="$1"
    local project_root
    
    if ! command_exists prettier; then
        log_debug "Prettier not found, skipping JavaScript/TypeScript/Markdown formatting for: $file_path"
        return 0
    fi
    
    project_root=$(find_project_root "$(dirname "$file_path")")
    log_debug "Using project root for Prettier: $project_root"
    
    log_info "Formatting with Prettier: $file_path"
    
    # Run prettier with error handling and timeout
    if timeout 30s prettier --write "$file_path" --log-level=warn 2>/dev/null; then
        log_debug "Successfully formatted with Prettier: $file_path"
        return 0
    else
        log_error "Failed to format with Prettier: $file_path"
        return 1
    fi
}

# Function to format Elixir files with mix format
format_with_mix() {
    local file_path="$1"
    local file_dir
    local mix_project_root
    
    if ! command_exists mix; then
        log_debug "Mix not found, skipping Elixir formatting for: $file_path"
        return 0
    fi
    
    file_dir=$(dirname "$file_path")
    
    # Find the mix project root
    local dir="$file_dir"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/mix.exs" ]]; then
            mix_project_root="$dir"
            break
        fi
        dir=$(dirname "$dir")
    done
    
    if [[ -z "${mix_project_root:-}" ]]; then
        log_debug "No mix.exs found, skipping mix format for: $file_path"
        return 0
    fi
    
    log_info "Formatting with mix format: $file_path (project: $mix_project_root)"
    
    # Change to project directory and run mix format with timeout
    if (cd "$mix_project_root" && timeout 30s mix format "$file_path" 2>/dev/null); then
        log_debug "Successfully formatted with mix format: $file_path"
        return 0
    else
        log_error "Failed to format with mix format: $file_path"
        return 1
    fi
}

# Main formatting function
format_file() {
    local file_path="$1"
    local file_extension
    local base_name
    
    # Validate file exists and is readable
    if [[ ! -f "$file_path" ]] || [[ ! -r "$file_path" ]]; then
        log_debug "File not found or not readable, skipping: $file_path"
        return 0
    fi
    
    # Get file extension
    base_name=$(basename "$file_path")
    file_extension="${base_name##*.}"
    
    # Skip if no extension
    if [[ "$base_name" == "$file_extension" ]]; then
        log_debug "No file extension found, skipping: $file_path"
        return 0
    fi
    
    log_debug "Processing file: $file_path (extension: $file_extension)"
    
    # Format based on file extension
    case "$file_extension" in
        js|jsx|ts|tsx|md|mdx|json|css|scss|less|html|yaml|yml)
            format_with_prettier "$file_path"
            ;;
        ex|exs)
            format_with_mix "$file_path"
            ;;
        *)
            log_debug "Unsupported file type for formatting: $file_extension"
            return 0
            ;;
    esac
}

# Main execution function
main() {
    # Read JSON input from stdin
    local input
    input=$(cat)
    
    log_debug "Received input: $input"
    
    # Parse file path from PostToolUse event JSON
    # The JSON structure includes tool_input.file_path for Edit/Write operations
    local file_path
    file_path=$(echo "$input" | grep -o '"file_path":"[^"]*"' | cut -d'"' -f4)
    
    # Exit if no file path found
    if [[ -z "$file_path" ]]; then
        log_debug "No file_path found in input"
        exit 0
    fi
    
    log_debug "Processing file: $file_path"
    
    # Convert to absolute path if relative
    if [[ "$file_path" != /* ]]; then
        file_path="${CLAUDE_PROJECT_DIR:-$(pwd)}/$file_path"
    fi
    
    log_debug "Absolute file path: $file_path"
    
    # Format the file (with error handling to prevent hook failure)
    if format_file "$file_path"; then
        log_debug "Formatting completed successfully for: $file_path"
    else
        log_debug "Formatting encountered errors for: $file_path (non-blocking)"
    fi
    
    # Always exit successfully to avoid disrupting Claude operations
    exit 0
}

# Run main function
main
