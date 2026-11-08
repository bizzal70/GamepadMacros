# GamepadMacros

Ready-made macros for playing World of Warcraft: Forever (client 1.60.x) with a controller or on a Steam Deck: things a controller makes awkward, each turned into one button for your gamepad's action bar.

## The macros

| Macro | What it does |
|---|---|
| Heal Me | Heals yourself, whatever you have targeted (Holy Light, Lesser Heal or Heal, Healing Touch, Healing Wave; paladins, priests, druids and shamans) |
| Quest Item | Uses the quest item in your bags: one that starts a quest first, else a quest item you can use. GamepadMacros keeps it pointing at the right item as your bags change |
| Save Gear | Saves what you are wearing as the gear set "GamepadMacros" |
| Wear Gear | Puts that gear set back on (not in combat) |
| Leave Group | Leaves your party or raid |
| Hello, Thanks, Follow Me, Need Help | The /wave, /thank, /followme and /helpme emotes, for when there is no keyboard to type on |

All but Heal Me are account-wide General macros, so they use none of a character's 18 macro slots and every character shares them.

## Using it

Type `/gpm` (or `/gamepadmacros`), or use the minimap button, which shows once you use a controller (press a button or move a stick), so it stays out of the way when you play with mouse and keyboard.

1. In the **Gamepad macros** window, click **Add** on a macro, or **Add all**.
2. Drag the macro from the window onto a slot on your gamepad's action bar (or click it once to pick it up, then click the slot).

Nothing is added until you ask. A macro you made yourself with the same name is never overwritten. If the game cannot do something (gear sets, for example), that macro says what it needs instead of being added.

| Command | What it does |
|---|---|
| `/gpm` | Open the window |
| `/gpm add` | Add every macro you are missing |
| `/gpm remove` | Delete the macros GamepadMacros added (your own stay) |
| `/gpm button` | Minimap button on or off |

These macros were part of MacroKit 0.6; they moved here in their own addon. Ones MacroKit added are taken over.

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherLog](https://github.com/bizzal70/GatherLog)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[RangeShade](https://www.curseforge.com/wow/addons/rangeshade)** shades action buttons red when your target is out of range.
- **[JunkMate](https://github.com/bizzal70/JunkMate)** sells junk and repairs at vendors, and warns when your gear is wearing out.
- **[AltGlance](https://github.com/bizzal70/AltGlance)** shows all your characters at a glance: level, gold, rested and where you left them.
- **[SwiftQuest](https://github.com/bizzal70/SwiftQuest)** accepts quests and hands them in as soon as you talk to the quest giver, without ever choosing a reward for you.
- **[SessionRecap](https://github.com/bizzal70/SessionRecap)** keeps a running tally of your play session: gold, experience per hour, quests, gathering and loot.
- **[MacroKit](https://github.com/bizzal70/MacroKit)** adds ready-made macros for your class and spec, for all nine classes, and never overwrites your own.
- **[ZoomPad](https://github.com/bizzal70/ZoomPad)** puts big + and - buttons on screen that zoom the camera, made for the Steam Deck touchscreen.

## Installing

Install it from [CurseForge](https://www.curseforge.com/wow/addons/gamepadmacros) (once approved) with the CurseForge app, or by hand: copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `GamepadMacros`, restart the game, and enable GamepadMacros on the character select screen.

## Developing

- `tools\Link-Addon.ps1` links this folder into the game's AddOns folder, so edits are live after `/reload`.
- `python tests/run.py` runs the tests (`pip install lupa` once). They run the addon in real Lua 5.1 against a fake of the game's API.
- `tools\Publish.ps1 -Message "..."` runs the tests and pushes to GitHub.

## Releasing

`tools\Publish.ps1 -Message "Release x.y.z" -Tag vx.y.z` publishes and tags. The tag makes GitHub package the addon, attach the zip to a GitHub release and, once the CurseForge project ID is in `GamepadMacros.toc` and a `CF_API_KEY` or `CF_KEY` secret is in this repository, upload it to CurseForge.

Before each release: raise `## Version:` in `GamepadMacros.toc` and add the version to `CHANGELOG.md`.

## Licence

MIT. See `LICENSE`.
