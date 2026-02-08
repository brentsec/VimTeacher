#!/bin/bash
# Run VimTeacher tests in headless Neovim
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
NVIM="${NVIM:-nvim}"

echo "=== VimTeacher Test Suite ==="
echo "Plugin root: $PLUGIN_ROOT"
echo "Neovim: $($NVIM --version 2>&1 | head -1)"
echo ""

TESTS=(
  "test_snippets.lua"
  "test_validate.lua"
  "test_stats.lua"
  "test_basic_movement.lua"
  "test_word_movement.lua"
)

FAILED=0

for test in "${TESTS[@]}"; do
  echo "--- Running $test ---"
  if $NVIM --headless -u "$PLUGIN_ROOT/tests/minimal_init.lua" \
    -c "luafile $PLUGIN_ROOT/tests/$test" \
    -c "qa!" 2>&1; then
    echo ""
  else
    echo "  $test FAILED (exit code $?)"
    FAILED=$((FAILED + 1))
    echo ""
  fi
done

echo "=== Results ==="
if [ $FAILED -eq 0 ]; then
  echo "All ${#TESTS[@]} test files passed!"
  exit 0
else
  echo "$FAILED of ${#TESTS[@]} test files failed."
  exit 1
fi
