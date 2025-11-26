#!/bin/bash
#
# Local CI script - runs the same checks as GitHub Actions
#
# Usage: ./scripts/ci.sh
#

set -e

echo "=========================================="
echo "TermUI Local CI"
echo "=========================================="
echo ""

# Check Elixir/OTP versions
echo "Environment:"
echo "  Elixir: $(elixir --version | head -1)"
echo "  OTP:    $(erl -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)"
echo ""

# Install dependencies
echo "=========================================="
echo "Installing dependencies..."
echo "=========================================="
mix deps.get
echo ""

# Check formatting
echo "=========================================="
echo "Checking formatting..."
echo "=========================================="
if mix format --check-formatted; then
    echo "✓ Formatting OK"
else
    echo "✗ Formatting errors found. Run 'mix format' to fix."
    exit 1
fi
echo ""

# Compile with warnings as errors
echo "=========================================="
echo "Compiling (warnings as errors)..."
echo "=========================================="
if MIX_ENV=test mix compile --warnings-as-errors; then
    echo "✓ Compilation OK"
else
    echo "✗ Compilation failed or has warnings"
    exit 1
fi
echo ""

# Run tests
echo "=========================================="
echo "Running tests..."
echo "=========================================="
if mix test; then
    echo ""
    echo "✓ Tests passed"
else
    echo ""
    echo "✗ Tests failed"
    exit 1
fi
echo ""

echo "=========================================="
echo "✓ All CI checks passed!"
echo "=========================================="
