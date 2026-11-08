# GamepadMacros

Ready-made macros for controller and Steam Deck players. One addon, one repository: `bizzal70/GamepadMacros`. Split out of MacroKit on 2026-11-08 at the user's request ("rename the tab to Gamepad macros and make sure it is a separate addon"): MacroKit 0.6.0-0.6.2 had these as a Controller tab; MacroKit 0.7.0 removed them.

## Workflow

- **No local `.git`.** GitHub holds all history; work in a throwaway clone.
- **Never write Lua through a shell heredoc**: it collapsed `\\` to `\` once (ZoomPad's invisible minimap button). Use the Write/Edit tools. `tests/run.py` fails on single-backslash texture paths.
- **Tests:** `python tests/run.py` runs `tests/test_gamepadmacros.lua` in Lua 5.1 (lupa) against `tests/wow_stub.lua` (a copy of MacroKit's). They prove the addon's own logic only.
- **Releases:** a `v*` tag runs the BigWigs packager; the CurseForge token secret may be `CF_API_KEY` or `CF_KEY`.
- **Client install:** `C:\Program Files (x86)\World of Warcraft\_forever_\`.

## How it works

- `Pack.lua`: `ns.List()` builds the macros for the character's class; `ns.ControllerInUse()` is true once `GAME_PAD_ACTIVE_CHANGED` has fired with true this session (connected devices are not enough: the user's PC reports two with none in use). Without `C_GamePad`, true.
- `Core.lua`: add (only on request), add all, remove (only what it made: `GamepadMacrosDB.generalMade` for account-wide General macros, `GamepadMacrosCharDB.made` for Heal Me), the Quest Item updater (`EditMacro`, out of combat, only if this addon made it), and taking over `MacroKitDB.generalMade` entries on `PLAYER_LOGIN`.
- `Window.lua`: the "Gamepad macros" window. `MinimapButton.lua`: shown only once a controller is used.
- None of the macros' game commands (`C_EquipmentSet`, `/equipset`, `C_PartyInfo.LeaveParty`, the emotes, `item:ID` in `/use`) have been checked in Forever yet.

## Client facts

See MacroKit's CLAUDE.md: Forever is Retail-based (Midnight 12.x API), TOC interface 16001, secret values active in combat, wrap first-time API use in `pcall`.
