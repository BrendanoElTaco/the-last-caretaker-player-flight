# Update 6 compatibility record

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
