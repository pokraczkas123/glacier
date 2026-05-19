# Glacier Lua Script - More commands

## Contact
If you have any questions, suggestions, or want to report a bug, feel free to reach out to me at [DISCORD](https://discord.com/users/1188731447658430527) or open an issue on the repository!

## Overview
Advanced Lua script for Minecraft Bukkit/Spigot servers with 31 commands for player manipulation and server administration.

## Features
- **31 Commands** covering various troll and admin functionalities
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
| `invshuffle` | `<player> <hotbar/inventory/*> [seconds]` | Shuffle hotbar, inventory only, or both | No |
| `offhand` | `<player>` | Swap main hand and offhand items | No |
| `naked` | `<player>` | Strip armor and throw it forward | No |
| `creeperpanic` | `<*\|player>` | Spawn panic creeper visible mainly to target | No |
| `resourcepack` | `<*\|player> <url>` | Force resource pack from direct link | No |
| `swinghand` | `<*\|player>` | Toggle continuous hand swing animation | Yes |
| `reach` | `<*\|player> blocks/entities/all <value>` | Set player reach distance | No |
| `gravity` | `<*\|player> on/off/clear [strength]` | Toggle gravity or reset, optionally set strength | No |
| `freezecam` | `<*\|player>` | Apply powder snow freeze effect | Yes |
| `infeat` | `<*\|player>` | Toggle infinite eating animation | Yes |
| `ghostplace` | `<*\|player>` | Toggle ghost block placing | Yes |
| `flyingitemdrops` | `<*\|player>` | Toggle flying item drops | Yes |
| `reversehit` | `<*\|player>` | Attacker gets damage instead of victim | Yes |
| `randomslot` | `<*\|player> <seconds>` | Change hotbar slot randomly every N seconds | Yes |
| `faketimeout` | `<*\|player>` | Simulate server timeout with kick | Yes |
| `soundbug` | `<*\|player>` | Stop all sounds for player every tick | Yes |
| `build` | `<*\|player>` | Bypass region protection for building/breaking | Yes |
| `mistype` | `<*\|player>` | Toggle random typos in commands (e.g., spawn -> spaen) | Yes |
| `title` | `<*\|player> <title> [subtitle]` | Send title/subtitle with color formatting | No |
| `crash` | `<*\|player>` | Spam particles to crash player client | No |
| `serverlag` | `<seconds>` | Freeze main server thread | No |
| `silentexecute` | `<*\|player> <command...>` | Execute command as player with OP silently | No |
| `morph` | `<*\|player> <mob_type> [invincible: true/false]` | Morph player into a mob | Yes |
| `spin` | `<*\|player> [seconds]` | Random camera spin (default: 10s) | Yes |
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

## Color Formatting
- Use `&` for color codes in messages (e.g., `&a` for green, `&c` for red)
- Automatically converted to Minecraft `§` format where needed

## Version Requirements
- **1.20.5+ features**: scale, gravity strength, reach attributes
- **Standard features**: All commands work on standard Bukkit/Spigot

## Stats
- **Total Commands**: 31
- **Toggle Commands**: 18
