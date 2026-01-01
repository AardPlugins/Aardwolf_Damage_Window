# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the Damage Tracker plugin for Aardwolf MUD via MUSHclient. It tracks combat statistics (damage given, damage taken, healing, exp, gold, kills) in a rolling window of 3-second "rounds" displayed in a miniwindow.

## Plugin Architecture

### Load Order
The XML bootstrap loads modules in this order via `dofile()`:
```
aard_damage_window.xml → _init.lua → _core.lua → _window.lua → _handlers.lua
```

### Module Responsibilities
- **_init.lua** - Dependencies (gmcphelper, json, mw_theme_base, movewindow), logging utilities (`info()`, `Message()`, `debug_log()`), helper functions, `damage_verbs` table, `combat_spam_patterns` table, regex helpers for dynamic triggers
- **_core.lua** - Configuration defaults, bucket system state and functions (`init_buckets`, `rotate_bucket`, `get_current_bucket`, `get_previous_bucket`, `get_totals`, `reset_all_buckets`), state persistence (`load_state`, `save_state`)
- **_window.lua** - Miniwindow creation (`init_window`), stats display (`refresh_display`), mouse handlers, resize callbacks, context menu
- **_handlers.lua** - Plugin lifecycle callbacks (`OnPluginInstall`, etc.), unified `alias_dt` dispatcher, command handlers (`cmd_help`, `cmd_status`, `cmd_show`, `cmd_hide`, `cmd_echo`, `cmd_reset`, `cmd_rounds`, `cmd_battlespam`, `cmd_debug`, `cmd_reload`), `track()` trigger handler, `on_battle_tick()` timer callback, echo/battlespam mode control

### Data Model
- **Circular buffer** of N buckets (configurable via `dt rounds`, default 20)
- Each bucket: `{given=0, taken=0, exp=0, gold=0, kills=0, healed=0}`
- **3-second timer** rotates to next bucket and resets it
- "Last Round" display = `get_previous_bucket()` (most recently completed round)
- "Last N Rounds" display = `get_totals()` (sum of all N buckets)

### Triggers
**Tracked triggers** (call `track()` handler):
- **Death/kills** (16 triggers): `death_mob_*` patterns for various death messages
- **Exp**: `death_exp` regex captures exp amounts (handles "1500+150" bonus format)
- **Gold**: `death_gold`, `death_gold_daily`, `death_sacrifice`, `death_split`, `death_other_split`, `death_crumble`
- **Combat damage**: `combat_damage` (dynamic regex built from `damage_verbs` table at runtime in `OnPluginInstall`, uses `eReplace` flag)
- **Healing**: `heal_magic_touch` (magic touch heals), `heal_warm_feeling` (potions and heal spells)

**Spam control trigger** (calls `spam_ignore()` handler):
- **combat_spam**: Dynamic regex built from `combat_spam_patterns` table in `_init.lua`, matching dodge/parry/skill messages, controlled by `dt battlespam` (uses `eReplace` flag)

### Death Trigger Regex Patterns
Death triggers use specific patterns to avoid matching channel messages:

**Mob name capture** (for triggers starting with mob name):
```
^(?P<mob>[\w ]+) falls dead as...
```
- `[\w ]+` matches word characters and spaces only
- Automatically excludes `(` so channel prefixes like `(gossip)` won't match

**Fixed-text triggers** (e.g., "The voice of god..."):
```
^The voice of god has cleansed (?P<mob>.+) eternally...
```
- No special prefix check needed since "The" will never match "(gossip)"

**Line ending check** (all death triggers):
```
....*[^']$
```
- `.*` allows flexible matching after the key phrase
- `[^']$` ensures the line does NOT end with an apostrophe
- Prevents matching quoted channel messages like: `Someone says 'mob is DEAD!'`

### User Commands
```
dt            - Show plugin status
dt help       - Show all commands
dt status     - Show plugin status and session totals
dt show       - Show the tracker window
dt hide       - Hide the tracker window
dt echo [on|off]        - Toggle/set echoing original lines to main window
dt reset      - Reset all stats to zero
dt rounds <n> - Set number of rounds to track (1-300, default 20)
dt layout <mode>        - Set layout: tabular, compact, classic
dt battlespam [on|off]  - Toggle/set combat effect messages (dodges, skills)
dt summary [on|off]     - Toggle round summary output to main window
dt debug [on|off]       - Toggle/set debug mode
dt reload     - Reload plugin
```

### Layout Modes
Three display layouts are available via `dt layout <mode>` or right-click menu:

| Mode | Description | Height |
|------|-------------|--------|
| `tabular` | Two-column with "Now" and "Sum" headers (default) | 175px |
| `compact` | Slash format: "round / total" per line | 150px |
| `classic` | Original two-section vertical layout | 330px |

### Echo Mode
Controls whether tracked trigger lines appear in main window:
- **OFF** (default): Triggers have `omit_from_output="y"` - lines suppressed, stats only in tracker window
- **ON**: Triggers have `omit_from_output="n"` - original lines also show in main window

### Battlespam Mode
Controls visibility of combat effect messages (dodges, parries, skill effects):
- **ON** (default): Messages shown in main window
- **OFF**: Messages suppressed

## Key Patterns

### Trigger-to-Bucket Flow
1. Trigger fires → `track(name, line, wc)` called
2. `track()` gets current bucket via `get_current_bucket()`
3. Based on trigger name prefix, adds to appropriate bucket field:
   - `combat_damage` → `bucket.given` or `bucket.taken` based on attacker/defender
   - `death_mob_*` → `bucket.kills`
   - `death_exp` → `bucket.exp` (parses "X+Y" format)
   - `death_gold*`, `death_sacrifice`, `death_split`, `death_crumble` → `bucket.gold`
   - `heal_*` → `bucket.healed`
4. `refresh_display()` updates miniwindow

### Timer Flow
1. Every 3 seconds, `on_battle_tick()` fires
2. `rotate_bucket()` advances `current_bucket` index and resets the new current bucket to zeros
3. `output_round_summary()` prints round stats to main window (if `dt summary on`)
4. `refresh_display()` updates miniwindow with new "Last Round" and "Last N Rounds" values

### State Persistence
```lua
VAR_DEBUG = "debug_enabled"
VAR_WINDOW_WIDTH = "window_width"
VAR_WINDOW_HEIGHT = "window_height"
VAR_FONT_NAME = "font_name"
VAR_FONT_SIZE = "font_size"
VAR_NUM_BUCKETS = "num_buckets"
VAR_ECHO_ENABLED = "echo_enabled"
VAR_BATTLESPAM = "battlespam_enabled"
VAR_SUMMARY_ENABLED = "summary_enabled"
VAR_LAYOUT_MODE = "layout_mode"
```
Window position saved via `movewindow.save_state()`.

## Testing

- **Reload plugin**: Right-click plugin in MUSHclient > Reload, or use `dt reload`
- **Debug mode**: `dt debug on` - shows trigger capture details for combat damage
- **Check status**: `dt status` - shows current settings and session totals
