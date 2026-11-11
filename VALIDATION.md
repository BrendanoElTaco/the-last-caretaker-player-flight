# Validation records

## Flight settings fix: 0.2.3-beta.1 - 2026-11-11

- The maintainer tested the installed build on Update 6 (Steam build 25982825)
  and reported that the settings worked. The UE4SS log recorded 42 samples
  with the requested value matching both the cached base and GetMaxSpeed.
  Actual movement reached 300 and 500 cm/s at those two settings. Edits to
  1200 and 5000 also took effect during the session. The saved rise/lower step
  reached 10000 cm.
- The game session ended normally with no Player Flight errors or new crash
  dumps. The release uses the same script as the installed build.

- The logging-only 0.2.3-diagnostic.1 ran in the installed game. At requested
  speeds 1200, 6000 and 50000, subsequent samples showed MaxFlySpeed, GetMaxSpeed
  and actual movement velocity near 110-120 cm/s. MovementMode remained 5.
- Read-only analysis of the current executable and its matching JMAP located
  the reset: BeginPlay copies MaxClimbSpeed at component offset 0x100c into a
  private base at 0x1170. The update at RVA 0x559f690..0x559f888 reads that base,
  applies the game's movement modifiers, and writes MaxFlySpeed at 0x294.
- Executable SHA256:
  `08228b72d4590f9b00e2171f252d618464c2e04b785237fe728dddbf27d3b734`.
- The candidate exposes only that float through UE4SS RegisterCustomProperty,
  after three exact executable byte checks. It sets the base while flying and
  restores its captured value on disable; no weight/cold multipliers are changed.
- Twenty isolated regression tests pass under each of Lua 5.3 and Lua 5.4.
  These include repeated simulated resets, changing modifiers, disable/default
  restoration, unsupported layouts, partial enable failure, character changes
  and queued edits after disabling flight, as well as the numeric widget tests.
- The actual Lua executable-layout verifier also passed against the installed
  game file using the installed script-path shape and mocked movement objects.
  This verifies file access/layout detection, not live UE4SS property access.
- The shared ModMenu library, configuration format and keybind defaults remain
  unchanged. Release archives exclude user configuration.
## Earlier numeric settings test: 0.2.2-beta.1 - 2026-10-26

- Reproduced the reported speed 6000 case using the actual bundled numeric widget:
  v0.2.1-beta.1 instead stored/applied 5000. Rise/lower had the same issue at 1000.
- Existing local game logs show earlier callbacks reaching the flight runtime
  (configured speeds 3000 and 5000). This is not evidence of a game-side override.
- Regression harness uses the real bundled number widget and ConfigManager JSON
  store, mock movement/pawn/keybind/game-thread objects, and in-memory I/O.
- Checks cover live changes, immediate callbacks, cap/display agreement, restart
  persistence, invalid saved values, restore-defaults, keybinds, and stock-speed
  restoration on disabling flight.
- No installed files or user configuration were changed by these tests.
- Lua 5.3: all 10 tests passed; Lua 5.4: all 10 tests passed (Lupa 2.8).
  The pre-fix Lua 5.4 run had 9 expected failures and 1 pass.
- Git whitespace/diff checks passed. The shared ModMenu library is unchanged.
- These are automated/mocked results, not a claim of live in-game verification.
- In the subsequent live test, the maintainer reported no movement-speed difference
  between 1200 and 6000. That led to the diagnostic and speed-reset fix above.

## Historical Update 6 compatibility record

- Mod: `0.2.1-beta.1`
- Date: 2026-10-19
- Game: `0.10.0.653173` / Update 6
- Steam app/build: `1783560` / `25982825`
- Engine: `5.8.2`
- Runtime: official UE4SS experimental `v3.0.1-1181-g83330635`

## Checks completed

- Maintainer confirmed loading an existing save, toggling flight with F6, and opening/using the F7 settings menu on Update 6 with the updated UE4SS.
- After installing this maintenance source together with the refreshed enhancer, proximity, DML and Dev Menu packages, the maintainer reported "Everything works" in the final all-mods check.
- The UE4SS runtime log records successful Player Flight initialization, flight ON at the configured speed, and flight OFF without a Lua error.
- Maintenance source passes the Lua 5.3 syntax parser.
- The executable flight/menu behavior is unchanged from that tested source; this maintenance version adds version/build information to the startup message.
- Existing configuration is retained during installation and excluded from the release archive.
- Release includes Player Flight and the existing MIT-licensed ModMenu component. UE4SS and game assets are not bundled.

The reconstructed enhancer and proximity packages are separate mods, maintained privately. They are not part of this public package. Compatibility with future game/UE4SS updates is not established by these checks.
