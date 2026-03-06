---
summary: Adaptive keymapping behavior, support matrix, and current limitations.
read_when:
  - Configuring keymap behavior
  - Using LazyVim or custom Neovim mappings
status: active
---

# Adaptive Keymapping

## Purpose

Explain how VimTeacher resolves and displays custom keymaps in lessons, what works today, and what does not.

## How It Works

VimTeacher does not parse your config files directly.

It reads active Neovim mappings at runtime via the Neovim API and resolves display keys from the live keymap state.

Resolution flow:

1. Start with canonical lesson key (example: `h`).
2. Apply explicit override if configured.
3. Check if canonical key is still available.
4. Look for reverse mappings that clearly map another key to the canonical action (example: `a -> h`).
5. Pick the best candidate and display it in lesson UI.
6. Fall back to canonical key if no safe candidate is found.

## Configuration

```lua
require("vimteacher").setup({
  keymaps = {
    mode = "adaptive_display", -- strict | adaptive_display | adaptive_runtime
    distro = "auto", -- auto | neovim | lazyvim
    overrides = {
      -- optional hard overrides
      -- h = "a",
    },
  },
})
```

`mode` behavior:

- `strict`: disable adaptive resolution; always show canonical lesson keys.
- `adaptive_display`: enable adaptive resolution for lesson display and helper UI.
- `adaptive_runtime`: currently behaves the same as `adaptive_display` (reserved for deeper runtime behavior).

## Distro Coverage

Currently supported:

- Neovim (global normal-mode mappings)
- LazyVim (same runtime scan, plus refresh on `User LazyVimStarted`)

Not supported:

- Classic Vim (plugin requires Neovim APIs)
- Direct parsing of distro config files

## Current UI Coverage

Guaranteed adaptive surfaces today:

- Challenge helper bar ("press X" style instructions)
- Hint lines using bracket key tokens (example: `[x]`)
- Getting Started lesson prose:
  - `intro_modes`
  - `basic_movement`
  - `word_movement`
  - `insert_mode`

Fallback behavior:

- If a key/action is not in the adaptive key catalog yet, UI stays canonical for that key.
- Some advanced lesson prose may still intentionally remain canonical even when helper/hints adapt.

## Important Limitations

Adaptive resolution is intentionally conservative. It does not reliably reverse:

- `expr` maps
- callback/function maps
- complex recursive chains
- mappings with non-trivial command RHS that are not clear equivalents

Additional boundaries:

- Resolution uses global normal-mode mappings (`n`), not buffer-local mappings.
- Leader-based and `<Plug>` candidates are filtered from replacement display candidates.
- If a canonical key is blocked and no safe replacement can be proven, VimTeacher keeps canonical display and reports unresolved internally.

## Lazy Loading Timing

VimTeacher captures keymaps on start and performs a deferred refresh.

For LazyVim, it also refreshes when `User LazyVimStarted` fires. This covers common late-registered mappings, but mappings created after lesson start may require restarting VimTeacher.

## Practical Check

If you are unsure whether your setup will adapt:

1. Start a Getting Started lesson (for example `basic_movement`).
2. Confirm title/hints/helper show your remapped keys.
3. If UI stays canonical, your mapping likely falls into a limitation above.

