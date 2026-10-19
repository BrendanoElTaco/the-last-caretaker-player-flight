# The Last Caretaker Player Flight

A player-attached flight mod for **The Last Caretaker**. It keeps control of the normal player character instead of switching to the detached spectator/freecam pawn.

The mod uses UE4SS to change the character movement mode directly because Unreal's built-in `ghost` and `fly` cheat commands are compiled out of Shipping builds even though the console can still print their success messages.

## Compatibility

- The Last Caretaker `0.10.0.653173` (Update 6), Steam build `25982825`
- Unreal Engine `5.8.2`
- UE4SS experimental `v3.0.1-1181-g83330635` is the current compatibility-check runtime
- DML and Dev Menu are optional and can be used alongside this mod

The maintainer confirmed loading an existing save, F6 flight, and the F7 menu on Update 6 with the updated UE4SS. Verification details are recorded in [VALIDATION.md](VALIDATION.md). This release remains a beta.

## Features

- Real flight while controlling the normal player character
- Normal world collision remains enabled
- In-game settings panel
- Adjustable flight speed
- Adjustable rise/lower distance
- Remappable flight toggle, rise, and lower controls
- Automatically saved settings and keybinds
- Selectable left, right, top, or bottom menu docking

## Default controls

| Control | Action |
| --- | --- |
| `F7` | Open or close the flight settings panel |
| `F6` | Toggle flight |
| `WASD` | Move while flying |
| `Page Up` | Rise |
| `Page Down` | Lower |

The flight controls can be changed from the **Keybinds** tab. `F7` remains the menu key.

## Requirements

Install a current [UE4SS experimental build](https://github.com/UE4SS-RE/RE-UE4SS/releases) that supports Unreal Engine 5.8.

## Installation

1. Install UE4SS beside `VoyageSteam-Win64-Shipping.exe` in:

   ```text
   ...\Voyage\Voyage\Binaries\Win64\
   ```

2. Download the latest `TLCPlayerFlight` release archive.
3. Extract its `ue4ss` folder into that same `Win64` directory and allow folders to merge.
4. Start the game and load a save.
5. Press `F7` to open the flight panel.

The important installed paths are:

```text
ue4ss\Mods\TLCPlayerFlight\enabled.txt
ue4ss\Mods\TLCPlayerFlight\Scripts\main.lua
ue4ss\Mods\shared\ModMenu\ModMenu.lua
```

## Console alternatives

If DML or another console unlocker is installed:

```text
tlcfly
tlcup [centimetres]
tlcdown [centimetres]
tlcflightmenu [toggle|open|close]
```

## Configuration

Settings save automatically to:

```text
ue4ss\Mods\TLCPlayerFlight\config.json
```

Delete that file to restore defaults, or use **Restore Defaults** in the menu.

## Updating DML or Dev Menu

DML and Dev Menu install under `Voyage\Content\Paks`, while this mod installs under `Voyage\Binaries\Win64\ue4ss`. Updating them should not overwrite Player Flight.

## Troubleshooting

- Fully restart the game after installing or updating the mod.
- If `F7` does not open the panel, try `tlcflightmenu open` in the game console.
- Check `ue4ss\UE4SS.log` for lines containing `TLCPlayerFlight` or `ModMenu`.
- Launch the game with `--disable-ue4ss` to temporarily disable UE4SS for recovery.

Please include the game version and relevant `UE4SS.log` lines in bug reports.

## Credits

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) for Unreal Engine Lua scripting.
- [ue4ss-ModMenu](https://github.com/mattdavida/ue4ss-ModMenu) by Matthew Arvidson for the constructed UMG settings framework.

## License

The Player Flight Lua code is released under the [MIT License](LICENSE). Bundled third-party components retain their respective licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
