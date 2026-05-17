# Glacier Lua Script - More commands

## Overview
Advanced Lua script for Minecraft Bukkit/Spigot servers with 28 commands for player manipulation and server administration.

## Features
- **28 Commands** covering various troll and admin functionalities
- **Multi-player targeting** with wildcard `*`, comma-separated lists, and exclusions `*!nick1,nick2`
- **Toggle-based commands** for easy enable/disable
- **Event-driven system** with efficient event listeners
- **Version-aware** with compatibility checks for 1.20.5+ features

## Command List

### Player Manipulation Commands
| Command | Syntax | Description | Toggle |
|---------|--------|-------------|--------|
| `hitpush` | `<player> <upward_blocks>` | Push victim in attacker direction | Yes |
| `nohit` | `<player>` | Visual hits but no HP loss | Yes |
| `dmgmult` | `<player> <multiplier> incoming/outgoing` | Damage multiplier (0 = off) | No |
| `noitempickup` | `<player>` | Items flee from player | Yes |
| `ride` | `<vehicle> <rider>` | Make rider sit on vehicle player | Yes |
| `drop` | `<player> one/all` | Drop item from player's main hand | No |
| `scale` | `<player> <size>` | Change player size (0.01-17) | No |
| `invshuffle` | `<player> [seconds]` | Shuffle hotbar, optionally for X seconds | No |
| `offhand` | `<player>` | Swap main hand and offhand items | No |
| `naked` | `<player>` | Strip armor and throw it forward | No |
| `creeperpanic` | `<player>` | Spawn panic creeper visible mainly to target | No |
| `resourcepack` | `<player> <url>` | Force resource pack from direct link | No |
| `swinghand` | `<player>` | Toggle continuous hand swing animation | Yes |
| `reach` | `<player> blocks/entities/all <value>` | Set player reach distance | No |
| `gravity` | `<player> on/off/clear [strength]` | Toggle gravity or reset, optionally set strength | No |
| `freezecam` | `<player>` | Apply powder snow freeze effect | Yes |
| `infeat` | `<player>` | Toggle infinite eating animation | Yes |
| `ghostplace` | `<player>` | Toggle ghost block placing | Yes |
| `flyingitemdrops` | `<player>` | Toggle flying item drops | Yes |
| `reversehit` | `<player>` | Attacker gets damage instead of victim | Yes |
| `randomslot` | `<player> <seconds>` | Change hotbar slot randomly every N seconds | Yes |
| `faketimeout` | `<player>` | Simulate server timeout with kick | Yes |
| `soundbug` | `<player>` | Stop all sounds for player every tick | Yes |
| `build` | `<player>` | Bypass region protection for building/breaking | Yes |
| `title` | `<player> <title> [subtitle]` | Send title/subtitle with color formatting | No |
| `crash` | `<player>` | Spam particles to crash player client | No |
| `serverlag` | `<seconds>` | Freeze main server thread | No |
| `scripthelp` | | Show all available commands | No |

## Targeting System

### Single Player
```
command NickName
```

### Multiple Players (comma-separated)
```
command Nick1,Nick2,Nick3
```

### All Players (wildcard)
```
command *
```

### All Except Specific Players (exclusion)
```
command *!Nick1,Nick2
```

## Event Listeners
- **EntityDamageByEntityEvent** - Handles hitpush, nohit, dmgmult, reversehit
- **PlayerAttemptPickupItemEvent** - Handles noitempickup
- **PlayerItemConsumeEvent** - Handles infeat
- **BlockPlaceEvent** - Handles ghostplace, build
- **BlockBreakEvent** - Handles build
- **PlayerDropItemEvent** - Handles flyingitemdrops

## Global State Tables
- `hitpushPlayers` - Hitpush toggle state
- `nohitPlayers` - Nohit toggle state
- `dmgmultPlayers` - Damage multiplier settings
- `ridePairs` - Ride pairings
- `rideTasks` - Ride task IDs
- `noPickupPlayers` - No item pickup toggle state
- `swingPlayers` - Swing hand toggle state
- `swingTasks` - Swing hand task IDs
- `infeatPlayers` - Infinite eating toggle state
- `freezecamPlayers` - Freeze cam toggle state
- `freezecamTasks` - Freeze cam task IDs
- `ghostPlacePlayers` - Ghost place toggle state
- `flyingDropPlayers` - Flying item drops toggle state
- `reversehitPlayers` - Reverse hit toggle state
- `randomslotTasks` - Random slot task IDs
- `faketimeoutTasks` - Fake timeout task IDs
- `faketimeoutItems` - Fake timeout saved items
- `soundbugTasks` - Sound bug task IDs
- `buildPlayers` - Build mode toggle state

## Color Formatting
- Use `&` for color codes in messages (e.g., `&a` for green, `&c` for red)
- Automatically converted to Minecraft `§` format where needed

## Version Requirements
- **1.20.5+ features**: scale, gravity strength, reach attributes
- **Standard features**: All commands work on standard Bukkit/Spigot

## Logging
- All actions logged to dashboard via `log_info()`
- Optional in-game broadcast for authorized players

## Stats
- **Total Commands**: 28
- **Toggle Commands**: 15
- **Event Listeners**: 6
- **Global State Tables**: 18
- **Helper Functions**: 3
