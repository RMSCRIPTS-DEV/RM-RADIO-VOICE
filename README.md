<p align="center">
  <a href="https://rm-scripts.dev/">
    <img src="https://r2.fivemanage.com/aKdhnWQAzohu8VO3pwbkC/thumbnail-1787238766215.png" alt="rm-radios — RM-SCRIPTS" width="720" />
  </a>
</p>

<h1 align="center">rm-radios</h1>

<p align="center">
  <strong>RM-SCRIPTS</strong> · Voice radio for Qbox — channels, favorites, member lists, and item-gated shadow/anonymous mode from a clean NUI.
</p>

<p align="center">
  <a href="https://rm-scripts.dev/">Store</a>
  &nbsp;·&nbsp;
  <a href="https://rm-scripts.dev/docs">Documentation</a>
  &nbsp;·&nbsp;
  <a href="https://discord.gg/5F2ecFqmVA">Discord</a>
</p>

---

**rm-radios** is a **Qbox** voice radio resource: HTML/CSS/JS NUI, **pma-voice** channels, and **ox_inventory** item-backed radios with per-radio frequency storage. Includes favorites/categories, live channel chat, mic clicks, mute/deafen, restricted police/EMS channels, and a shadow module that hides you from channel member lists.

## Requirements

- **[ox_lib](https://github.com/communityox/ox_lib)** — shared `@ox_lib/init.lua` provides `lib` and `cache`.
- **[qbx_core](https://github.com/Qbox-project/qbx_core)** — player/job data via `@qbx_core/modules/lib.lua` / `playerdata.lua`.
- **[pma-voice](https://github.com/AvarianKnight/pma-voice)** — radio channel voice routing and volume.
- **[ox_inventory](https://github.com/communityox/ox_inventory)** — radio items, per-radio storage stash, shadow module item.

## Installation

1. Place `rm-radios` in your resources folder.
2. Ensure **ox_lib**, **qbx_core**, **pma-voice**, and **ox_inventory** are installed and started.
3. Add to `server.cfg` (order matters):

   ```cfg
   ensure ox_lib
   ensure qbx_core
   ensure pma-voice
   ensure ox_inventory
   ensure rm-radios
   ```

4. Add the `ox_inventory` items — see [`install/README.md`](./install/README.md) for the copy-paste snippet and item images.
5. Edit channel restrictions in `config/shared.lua`, and voice/UX defaults in `config/client.lua`.

## Configuration

### `config/shared.lua`

| Option | Description |
|--------|-------------|
| `earpieceItem` | Inventory item that makes radio private (no speaker leak to nearby players) |
| `shadowItem` | Item placed inside a radio's storage that hides that radio's holder from channel member lists |
| `shadowAutoJobs` | Jobs that are radio-invisible by default without needing `shadowItem` (e.g. `police`, `ambulance`). Set to `false` so everyone, including these jobs, must carry the item |
| `radioStash` | Per-radio storage stash: `slots`, `weight` |
| `whitelistSubChannels` | `false` restricts all decimals of a restricted channel; `true` requires listing each subchannel individually |
| `restrictedChannels` | `table<channel, table<jobName, true>>` — channels only the listed jobs may join |

### `config/client.lua`

| Option | Description |
|--------|-------------|
| `maxFrequency` | Highest selectable channel frequency |
| `leaveOnDeath` | Turn the radio off when the player dies |
| `decimalPlaces` | Subchannel decimal precision |
| `defaultMicClicks` | Mic click sound on by default |
| `overhearRange` | Distance nearby players can overhear radio traffic leaking from a speaker (no earpiece) |
| `overhearVolume` | Volume (0.0–1.0) of overheard radio, lower than normal so it reads as a speaker |

## Radio storage

Every radio item carries its own small stash (`radioStash` in `config/shared.lua` — 5 slots by default), used to hold the `shadowItem`. Two ways to open it, both go through the same server-side check that you actually own that radio:

1. **From the inventory** — right-click the radio item and use its "Open storage" context button.
2. **From the radio app itself** — the Package icon next to Power/Close in the radio panel header opens the currently-active radio's storage directly, no need to back out to the inventory.

## Shadow / anonymous mode

Drop `shadowItem` (default `shadow_module`, see [Configuration](#configuration)) into a radio's storage (see [Radio storage](#radio-storage) above) to make that radio's holder eligible for shadow mode. Players eligible for shadow mode (`shadowAutoJobs` job, or `shadowItem` in their radio's storage) get an **Anonymous** toggle in the radio Settings tab, letting them opt in or out of being hidden from other members' channel lists. Ineligible players see the toggle disabled with a hint pointing at the required item.

## Client exports

| Export | Returns | Description |
|--------|---------|-------------|
| `IsRadioOn` | `boolean` | Whether the local player currently has a radio powered on |

### Example

```lua
local onRadio = exports['rm-radios']:IsRadioOn()
```

## ox_lib

- **`lib.callback`** — joining/leaving channels, favorites, and shadow-eligibility sync between client and server
- **`cache`** — player job/ped/vehicle lookups gating radio use and overhear range checks

---

© RM-SCRIPTS
