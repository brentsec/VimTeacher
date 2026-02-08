# VimTeacher

Interactive Vim tutorial plugin that teaches Vim concepts directly inside Neovim.

## Requirements

- Neovim >= 0.7 (tested on 0.11.6)

## Installation

### With lazy.nvim (LazyVim)

Add to `~/.config/nvim/lua/plugins/vimteacher.lua`:

```lua
return {
  dir = "/path/to/apps/vim-teacher",
  cmd = "VimTeacher",
}
```

### Manual

Symlink or copy to your Neovim pack path:

```bash
ln -s /path/to/apps/vim-teacher \
  ~/.local/share/nvim/site/pack/plugins/start/vim-teacher
```

## Usage

Open Neovim and run:

```
:VimTeacher
```

This opens the topic selection menu. Press a number to start a lesson.

To jump directly into a specific lesson:

```
:VimTeacher basic_movement
```

### During a Lesson

- Navigate with the keys being taught (e.g., h/j/k/l for basic movement)
- Move your cursor to the green highlighted target and stop on it
- Challenges auto-progress after each completion
- Complete 10 challenges to finish the lesson and view your session stats

### After Completing a Lesson

| Key | Action |
|-----|--------|
| `n` | Next topic |
| `p` | Previous topic |
| `r` | Restart current topic |
| `m` | Return to topic menu |
| `q` | Quit |

## Available Topics

1. **Basic Movement** (h, j, k, l) — Cursor movement using home row keys

## Design Principles

### Dwell-Time Validation

All movement-based challenges require the cursor to **dwell** on the target position for 50ms before the challenge completes. This prevents users from holding down a movement key and flying past the target without intentionally stopping.

The dwell check is enforced centrally in `init.lua`'s `on_cursor_moved()` handler, so it applies to **all lessons automatically**. No per-lesson opt-in is needed. If a future lesson type genuinely doesn't need dwell validation (e.g., a timed command execution lesson), it can set `dwell_ms = 0` in its lesson table to bypass it.

### Non-Opinionated

The tutorial teaches Vim concepts without prescribing how users should physically interact with their keyboard. No finger placement suggestions, hand position guidance, or ergonomic opinions.

## Adding New Lessons

1. Create `lua/vimteacher/lessons/your_lesson.lua` implementing the lesson interface:
   - `title` (string)
   - `description` (string[])
   - `hint_lines` (string[])
   - `generate_challenge(buf, ns_id)` (function returning `{snippet_lines, target, start_pos}`)
   - `compute_optimal(start_pos, target)` (optional, defaults to Manhattan distance)
   - `dwell_ms` (optional number, defaults to 50; set to 0 to disable dwell validation)
2. Add `"your_lesson"` to the `M.order` table in `lua/vimteacher/lessons/init.lua`
3. Dwell-time validation is applied automatically by the orchestrator — no lesson-level code needed

## Stats

Player stats are stored in `data/stats.json` (best times, averages, accuracy, speed).

## Testing

```bash
bash scripts/test.sh
```

Or with Docker:

```bash
docker build -t vimteacher . && docker run --rm vimteacher
```
