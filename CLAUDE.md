# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is the Damage Window plugin for Aardwolf MUD via MUSHclient. It reduces spam by combining multiple lines of MUD output (combat damage, mob deaths, equipment changes, etc.) into condensed summaries displayed in a dedicated miniwindow.

## Plugin Architecture

### Load Order
The XML bootstrap loads modules in this order via `dofile()`:
```
aard_damage_window.xml → _init.lua → _core.lua → _output.lua → _window.lua → _death.lua → _combat.lua → _misc.lua → _handlers.lua
```

### Module Responsibilities
- **_init.lua** - Dependencies (`gmcphelper`, `json`, `mw_theme_base`), shared utilities (`gmcp()`, `debug_log()`, string helpers), module loading
- **_core.lua** - Configuration defaults, state variables, options table, `load_state()`/`save_state()`, trigger group management
- **_output.lua** - Output abstraction layer routing to miniwindow and optionally main window (`output_tell()`, `output_note()`, `duplicate_color_output()`)
- **_window.lua** - Miniwindow creation, resize handling, mouse callbacks, context menu builder
- **_death.lua** - Death message combining logic with verbose and simple output modes
- **_combat.lua** - Combat damage combining, damage type mappings (`damage_nouns`, `damage_verbs`), dynamic regex generation
- **_misc.lua** - Lotus, equip, spellup, and where combining handlers
- **_handlers.lua** - All alias/trigger callbacks (MUST be global), plugin lifecycle hooks, tag suppression system

### Combine Groups
Each group has triggers in the XML and a handler in the Lua code:
- `death` - Mob death, exp, gold, loot, sacrifice
- `combat` - Damage dealt/received with type tracking
- `lotus` - Lotus potion consumption
- `equip` - Equipment swap/wear/remove
- `spellup` - Spell queue messages
- `where` - Area/creator/level range header

Groups toggle via `spamreduce combine <group>`. Each group has a `_conditional` trigger subgroup enabled only during active combining.

## Key Patterns

### Trigger-to-Handler Flow
1. Trigger fires with `script="combine"` and `group="<group_name>"`
2. `combine()` in _handlers.lua routes to group-specific handler
3. Handler accumulates data in `options[group].data` table
4. `DeleteLines()` removes accumulated MUD output
5. Handler outputs condensed summary via `output_tell()`/`output_note()`

### State Management
```lua
-- Core state variables (global for cross-file access)
options = { death = {desc="..."}, combat = {desc="..."}, ... }
trigger_overrides = {}  -- Individual trigger disable overrides
output_to_main = true   -- Echo to main window

-- Persistence via GetVariable/SetVariable
VAR_DEBUG, VAR_OUTPUT_TO_MAIN, VAR_COMBAT_OTHERS, VAR_PRESERVE, etc.
```

### Output Routing
All output goes through the abstraction in _output.lua:
```lua
output_tell("color", "text")  -- Buffers styled text
output_note()                 -- Flushes to miniwindow + main (if enabled)
duplicate_color_output(sr)    -- Outputs MUSHclient style runs
```

### Tag Suppression
`suppress_triggers_between_tags(header, footer)` prevents triggers firing inside tagged blocks like `{score}...{/score}`, `<MAPSTART>...<MAPEND>`.

## User Commands

```
spamwin show/hide/clear     - Window visibility control
spamwin echo                - Toggle main window echo
spamreduce combine          - List all combine options
spamreduce combine <group>  - Toggle a specific group
spamreduce combine combat others <hide|list|full>
spamreduce combine combat preserve
spamreduce combine death simple
spamreduce combine trigger <name>  - Toggle individual trigger
spamreduce combine triggers [search]
```

## Testing & Debug

Reload plugin: Right-click plugin in MUSHclient > Reload
Debug mode: Set `debug_enabled = true` in _init.lua or modify saved state
