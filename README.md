# The Last Caretaker Player Flight

A player-attached flight mod for **The Last Caretaker**. It keeps control of the normal player character instead of switching to the detached spectator/freecam pawn.

The mod uses UE4SS to change the character movement mode directly because Unreal's built-in `ghost` and `fly` cheat commands are compiled out of Shipping builds even though the console can still print their success messages.

## Compatibility

- The Last Caretaker `0.10.0.653173` (Update 6), Steam build `25982825`
- Unreal Engine `5.8.2`
- Tested with UE4SS experimental `v3.0.1-1181-g83330635`
- DML and Dev Menu are optional and can be used alongside this mod

Version 0.2.3-beta.1 was tested in game on the build above. Menu edits changed the speed cap during flight, and measured movement reached the selected cap at 300 and 500 cm/s. Flight requires the supported executable layout. See [VALIDATION.md](VALIDATION.md) for the test results.

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

Install a [UE4SS experimental build](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest) that supports Unreal Engine 5.8. The tested build is v3.0.1-1181-g83330635.

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

Supported numeric ranges:

- Flight base speed: **100-50000 cm/s** (default 1200). The game's weight,
  cold and sprint modifiers still affect the resulting movement speed.
- Rise/lower step: **10-10000 cm** (default 100).

Valid numeric edits save immediately and update the active flight speed without
toggling flight. Values above a maximum are capped and the field shows the
accepted value. Blank/incomplete or below-minimum edits are not applied.
Saved numeric settings use the same limits when loaded. Existing settings and
keybinds are retained during an update; the release never includes config.json.

Version 0.2.3 shows the accepted value when an input is capped. It updates the
base speed used by the game and restores the original value when flight ends.
Acceleration and game movement modifiers affect how quickly you reach the cap.
Very high speeds/steps may cause streaming or collision issues; start low.

## Automated settings tests

With Python and Lupa installed, run from the repository root:

~~~text
python tests/test_settings.py lupa.lua53
python tests/test_settings.py lupa.lua54
~~~

Tests execute the bundled numeric widget and JSON config store with mocked UE4SS
objects and in-memory files. Live gameplay results are recorded separately in
[VALIDATION.md](VALIDATION.md).

## Updating DML or Dev Menu

DML and Dev Menu install under `Voyage\Content\Paks`, while this mod installs under `Voyage\Binaries\Win64\ue4ss`. Updating them should not overwrite Player Flight.

## Troubleshooting

- Fully restart the game after installing or updating the mod.
- If `F7` does not open the panel, try `tlcflightmenu open` in the game console.
- Check `ue4ss\UE4SS.log` for lines containing `TLCPlayerFlight` or `ModMenu`.
- If the log says `Unsupported game movement layout`, the game build needs a
  compatibility update before this version can enable flight.
- For a speed report, compare 1200 and 6000 while flying forward. The mod logs
  three movement samples after enabling flight or changing its speed. The
  optional `tlcflightstatus` command captures another set in `UE4SS.log`.
- Launch the game with `--disable-ue4ss` to temporarily disable UE4SS for recovery.

Please include the game version and relevant `UE4SS.log` lines in bug reports.

## Credits

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) for Unreal Engine Lua scripting.
- [ue4ss-ModMenu](https://github.com/mattdavida/ue4ss-ModMenu) by Matthew Arvidson for the constructed UMG settings framework.

## License

The Player Flight Lua code is released under the [MIT License](LICENSE). Bundled third-party components retain their respective licenses; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
