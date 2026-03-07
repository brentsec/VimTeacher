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
  "test_challenge_utils.lua"
  "test_lessons_pool.lua"
  "test_recent.lua"
  "test_snippets.lua"
  "test_keymaps.lua"
  "test_menu_ui.lua"
  "test_menu_input.lua"
  "test_plugin_command.lua"
  "test_line_numbers_integration.lua"
  "test_timing_smoke.lua"
  "test_getting_started_integration.lua"
  "test_validate.lua"
  "test_highlight.lua"
  "test_highlight_plan.lua"
  "test_stats.lua"
  "test_dwell_config.lua"
  "test_tooling_policy.lua"
  "test_docs_policy.lua"
  "test_intro_modes.lua"
  "test_basic_movement.lua"
  "test_word_movement.lua"
  "test_advanced_inserts_integration.lua"
  "test_essential_motions_integration.lua"
  "test_basic_operators_integration.lua"
  "test_advanced_vertical_movement_integration.lua"
  "test_search_integration.lua"
  "test_text_objects_integration.lua"
  "test_editing_efficiency_integration.lua"
  "test_visual_mode_integration.lua"
  "test_insert_mode.lua"
  "test_line_inserts.lua"
  "test_open_lines.lua"
  "test_small_edits.lua"
  "test_upper_word_movement.lua"
  "test_line_ends.lua"
  "test_find_char.lua"
  "test_till_char.lua"
  "test_intro_operators.lua"
  "test_delete_words.lua"
  "test_change_words.lua"
  "test_delete_lines.lua"
  "test_delete_multiple_lines.lua"
  "test_copy_paste_lines.lua"
  "test_relative_line_jumps.lua"
  "test_absolute_line_jumps.lua"
  "test_paragraph_jumps.lua"
  "test_window_scrolls.lua"
  "test_search.lua"
  "test_repeat_search.lua"
  "test_quick_word_search.lua"
  "test_search_review.lua"
  "test_search_replace.lua"
  "test_intro_text_objects.lua"
  "test_delete_inside_brackets.lua"
  "test_delete_around_brackets.lua"
  "test_change_inside_brackets.lua"
  "test_change_around_brackets.lua"
  "test_quote_text_objects.lua"
  "test_word_text_objects.lua"
  "test_paragraph_text_objects.lua"
  "test_text_objects_mega_review.lua"
  "test_repeat_power.lua"
  "test_macro_repetition.lua"
  "test_intro_visual_mode.lua"
  "test_visual_mode_operators.lua"
  "test_visual_line_mode.lua"
  "test_switch_selection_ends.lua"
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
