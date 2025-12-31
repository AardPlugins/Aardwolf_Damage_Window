# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the Damage Tracker plugin for Aardwolf MUD via MUSHclient. It tracks combat statistics (damage given, damage taken, exp, gold, kills) in a rolling window of 3-second "battle ticks".

## Plugin Architecture

### Load Order
The XML bootstrap loads modules in this order via `dofile()`:
```
aard_damage_window.xml → _init.lua → _core.lua → _window.lua → _handlers.lua
```

### Module Responsibilities
- **_init.lua** - Dependencies (gmcphelper, json, mw_theme_base, movewindow), shared utilities, damage_verbs table, regex helpers for dynamic combat trigger
- **_core.lua** - Configuration defaults, bucket system state and functions (init, rotate, get_current, get_totals, reset), persistence
- **_window.lua** - Miniwindow creation, fixed stats display with refresh_display(), context menu
- **_handlers.lua** - Plugin lifecycle, track() trigger handler, timer callback, alias handlers (dt_show, dt_hide, dt_echo, dt_reset, dt_ticks), echo mode control

### Data Model
- **Circular buffer** of N buckets (configurable, default 10)
- Each bucket: `{given=0, taken=0, exp=0, gold=0, kills=0}`
- **3-second timer** rotates to next bucket and resets it
- "Last Tick" = current bucket being filled
- "Last N Ticks" = sum of all N buckets

### Triggers
All triggers call the unified `track()` handler:
- **Death/kills** (16 triggers): `death_mob_*` patterns for various death messages
- **Exp**: `death_exp` regex captures exp amounts (handles "1500+150" format)
- **Gold**: `death_gold`, `death_gold_daily`, `death_sacrifice`, `death_split`, `death_other_split`, `death_crumble`
- **Combat damage**: `combat_damage` (dynamic regex created at runtime)

### User Commands
```
dt show       - Show the tracker window
dt hide       - Hide the tracker window
dt echo       - Toggle echoing original lines to main window
dt reset      - Reset all stats to zero
dt ticks <n>  - Set number of ticks to track (1-100)
```

### Echo Mode
- OFF (default): Triggers have `omit_from_output="y"` - lines suppressed, stats only
- ON: Triggers have `omit_from_output="n"` - original lines show in main window

## Key Patterns

### Trigger-to-Bucket Flow
1. Trigger fires → `track(name, line, wc)` called
2. `track()` gets current bucket via `get_current_bucket()`
3. Based on trigger name, adds to appropriate bucket field
4. `refresh_display()` updates window

### Timer Flow
1. Every 3 seconds, `on_battle_tick()` fires
2. `rotate_bucket()` advances index and resets new bucket
3. `refresh_display()` updates window

### State Persistence
```lua
VAR_NUM_BUCKETS = "num_buckets"
VAR_ECHO_ENABLED = "echo_enabled"
VAR_WINDOW_WIDTH/HEIGHT/FONT_NAME/FONT_SIZE
```

## Testing

Reload plugin: Right-click plugin in MUSHclient > Reload
Debug mode: Set `debug_enabled = true` in _core.lua
