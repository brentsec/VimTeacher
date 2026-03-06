---
summary: High-level structure and boundaries of this project.
read_when:
  - Starting work in this repo
status: active
---

# ARCHITECTURE

## Purpose

Describe major components, boundaries, and data flow.

## Current Adapter

- `lua-nvim-plugin`

## Notes

- Update this file when major architecture boundaries change.
- Keep this high-level and put procedures into runbooks.

## Runtime Structure

- `lua/vimteacher/init.lua`: entrypoint, setup, commands, and top-level wiring
- `lua/vimteacher/gameplay.lua`: active-lesson render loop, validation, and autocmd handlers
- `lua/vimteacher/state.lua`: shared session state and mode transitions
- `lua/vimteacher/session.lua`: lesson/session lifecycle, challenge loading, completion flow
- `lua/vimteacher/input.lua`: menu input buffering and menu rerender behavior
- `lua/vimteacher/mode_keymaps.lua`: mode-specific buffer-local keymaps outside menu input handling
- `lua/vimteacher/key_display.lua`: adaptive key text rewriting and lesson-view construction
- `lua/vimteacher/key_blocking.lua`: buffer-local lesson key blocking and resolved-key helpers
- `lua/vimteacher/goal.lua`: goal-bar metadata derived from lesson command keys
- `lua/vimteacher/recent.lua`: shared recency-window selection helper for snippets and challenge pools
- `lua/vimteacher/optimal.lua`: shared motion-cost utilities for lesson scoring
- `lua/vimteacher/buffer.lua`: thin facade over UI renderers
- `lua/vimteacher/ui/menu.lua`: topic menu layout and rendering
- `lua/vimteacher/ui/lesson.lua`: active lesson/challenge rendering
- `lua/vimteacher/ui/stats.lua`: between-challenge stats overlay
- `lua/vimteacher/ui/completion.lua`: end-of-lesson summary screen
- `lua/vimteacher/lessons/base.lua`: template-driven adaptive lesson text helpers
- `lua/vimteacher/stats.lua`: stats calculations and persistence in `stdpath("data") .. "/vimteacher/stats.json"`
