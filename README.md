# EZProgress

Tracks armor set completion across your team using MacroQuest actors.

## Usage

- `/lua run ezprogress` - Launch with HUD and auto-start peers in `nohud`
- `/lua run ezprogress nohud` - Background mode for alts
- `/ezp show` - Show HUD
- `/ezp hide` - Hide HUD
- `/ezp refresh` - Request fresh peer status
- `/ezp debug` - Toggle debug logging
- `/ezp exit` - Stop the script

## Current Coverage

Armor type follows the same class mapping used in `EZInventory`:

- `Plate`: `WAR`, `CLR`, `PAL`, `SHD`, `BRD`
- `Chain`: `RNG`, `ROG`, `SHM`, `BER`
- `Leather`: `DRU`, `MNK`, `BST`
- `Cloth`: `NEC`, `WIZ`, `MAG`, `ENC`

Tracked sets:

- `Plate` / Blightforged Warlord
- `Chain` / Rotfang Hunter
- `Leather` / Blightclaw Stalker
- `Cloth` / Moorshade Magus

Each tracked set currently checks all seven armor pieces and counts ownership from inventory plus bank.
