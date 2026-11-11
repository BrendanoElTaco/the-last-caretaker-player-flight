# Changelog

## 0.2.3-beta.1 - 2026-11-11

- Fixed the game resetting the selected flight speed during flight. Speed edits in the F7 menu now apply immediately.
- Expanded flight base speed to 100–50,000 cm/s and rise/lower distance to 10–10,000 cm. The menu displays the accepted value when an entry is capped.
- Restore the original movement settings when flight ends and validate the game's executable layout before enabling flight.
- Tested in game on Update 6 (0.10.0.653173, Steam build 25982825) with UE4SS experimental v3.0.1-1181-g83330635.

## 0.2.1-beta.1 - 2026-10-19

- Maintenance package targeting Update 6, game 0.10.0.653173 / Steam build 25982825 / Unreal Engine 5.8.2.
- Added the mod version and target build to the startup log for easier troubleshooting.
- Retained the flight behavior, menu, controls, and existing configuration format.
- Updated installation and compatibility records for the current game and UE4SS.

## 0.2.0-beta.1 - 2026-09-06

- Added an in-game UMG settings panel on `F7`.
- Added persistent flight speed and rise/lower step settings.
- Added persistent remapping for toggle, rise, and lower controls.
- Added menu docking and restore-defaults controls.
- Preserved player-attached flight and normal collision.

## 0.1.0 - 2026-09-06

- Initial player-attached flight implementation.
- Added `F6`, `Page Up`, and `Page Down` controls.
- Added `tlcfly`, `tlcup`, and `tlcdown` console commands.
