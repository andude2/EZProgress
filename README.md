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

Tiers 10, 11, 12, 12.5, Halloween - HoS, and Halloween - Thule Dream are tested.

Tiers 1 - 9 have data, but have not been tested yet.

Each tracked set currently checks all seven armor pieces and counts ownership from inventory plus bank.

Halloween - HoS tracks one Augment slot and displays the highest owned Foxy's augment rank, from Rusted through Ultimate.

Halloween - Thule Dream tracks one Familiar slot and counts completion if you own any one of Furious Sentinel Familiar, Thule's Nightmare Familiar, or Deranged Goblin Familiar.
