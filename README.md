# NexusHub

A Roblox script hub built on [NexusUI](https://github.com/CryoStrike/NexusUI) (Translucid theme): loading screen, language picker, resizable window, 9 categories.

## Run it

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/CryoStrike/NexusHub/main/init.lua"))()
```

## Features (Murder Mystery 2)

| Category | What it has |
|----------|-------------|
| Combat | Aimbot (smart role mode) + range |
| Character | WalkSpeed, JumpPower, Invisible (GhostTrick) + opacity, Fly + speed, Noclip, Infinite Jump, Anti-AFK, Reset |
| Farm | Auto Farm coins (speed, body offset, stay delay) |
| TP | Auto Grab Gun, teleport to a player / the map / the lobby |
| Keys | Hotkeys for grab gun, infinite jump, fly, walk speed, noclip, jump power and the invisible "show gear" key |
| Troll | Fling a player, Kill All |
| Visuals | Role ESP with colour pickers, field of view |
| Settings / About | Accent colour, hide key, language, minimize, unload |

## Files

| Script | Job | Edit it to... |
|--------|-----|---------------|
| `init.lua` | launcher: loads NexusUI + the two scripts below, shows the loading screen and language picker, opens the hub | change the title, logo or loading screen |
| `languages.lua` | every text of the hub + the list of languages | translate, add a text, add a language |
| `hub.lua` | what the hub does (aimbot, fly, invisible, auto farm, ESP, teleport ...) and its UI: one function per category | add or edit categories, buttons, sliders, toggles, icons |

The UI library, the logo and the tab icons are not in this repo: they are loaded from NexusUI (`Library.lua`, `assets/`).

## Editing

- **Add a button / slider / toggle:** open that category's function in `hub.lua` (`buildCombat`, `buildFarm` ...) and add a `tab:AddButton({ ... })` line. Put its text in `languages.lua` and use `tr("key")` as the name.
- **Add a category:** write a `build...` function, add one line to the `CATEGORIES` list at the bottom of `hub.lua`, and add `tab_<name>` to every language.
- **Add a language:** add its name to `Language.List` in `languages.lua` and copy the English block. Missing texts fall back to English and are reported in the console.
- Full component reference (all options of every control): see the NexusUI guide.

## Unloading

The **Unload NEXUS** button, closing the window with ×, and running the script a second time all stop the hub cleanly: connections are disconnected, every feature is switched off, the ESP is removed, and the walk speed, jump, gravity, collisions and field of view are given back.

## Development

```lua
-- copy languages.lua and hub.lua to <workspace>/NexusHub/, then:
getgenv().NEXUSHUB_LOCAL = true
loadstring(readfile("NexusHub/init.lua"))()

-- or test another branch of this repo:
getgenv().NEXUSHUB_BASE = "https://raw.githubusercontent.com/CryoStrike/NexusHub/<branch>/"
loadstring(game:HttpGet(getgenv().NEXUSHUB_BASE .. "init.lua"))()
```

GitHub caches raw files for a few minutes, so a change you just pushed can take that long to show up.
