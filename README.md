# [187] Cleaner

> You are the only neutral party in Los Santos who has stood inside every crime scene — and the fact that you are still alive means you have learned exactly which truth to tell to which person.

A clandestine crime scene disposal script with a heat system, dual reputation tracks, and evidence decision mechanics. Players are anonymous contractors hired to clean up crime scenes before the police arrive.

---

## Preview

| Scene Assessment Panel | Evidence Decision | Payout Screen |
|------------------------|-------------------|---------------|
| Live heat gauge, task checklist, countdown timer shown on-screen during each contract | Choose to destroy evidence for Cleaner Rep or pocket it for broker cash at the risk of betrayal | Scaleform-style overlay with base payout, time/ghost bonus, and total |

---

## Dependencies

| Dependency | Required |
|------------|----------|
| `ox_lib` | Yes |
| `oxmysql` | Yes |
| ESX / QBCore / Standalone | One of the three |

---

## Installation

1. Place `187Cleaner` in `resources/[187]/`
2. Add `ensure 187Cleaner` to your `server.cfg`
3. Import `database.sql` into your MySQL database
4. Set `Config.Framework` in `config.lua` to `'esx'`, `'qbcore'`, or `'standalone'`
5. Edit the framework bridge file that matches your server (`framework/esx.lua` etc.) if needed

---

## Features

- **Anonymous contract system** — Contracts arrive as phone-style notifications every 2 minutes for eligible players; Accept (Y) or Decline (N) without freezing the game
- **Scene assessment UI** — Non-blocking panel shows task checklist, live heat gauge, and countdown timer while working the scene
- **Body disposal chain** — Bag bodies at the scene with a progress bar animation, then drive bags to one of four disposal sites (incinerator, container yard, cliff dump, junkyard)
- **Surface cleaning** — Blood pools, glass shards, and chemical spills are marked; scrub each with a timed animation
- **Evidence decision system** — Every evidence item triggers a 15-second modal: Destroy for Cleaner Rep or Pocket for broker cash with a configurable betrayal risk
- **Heat system** — Heat ticks up every 10 seconds while at the scene; completing tasks reduces it; hitting max heat triggers an NPC police sweep; leaving for 90 seconds drops heat by 40%
- **Witness complication** — Random chance per contract; a witness appears near the scene; Pay them off (deducted from payout), Report to client (no cost, rep risk), or Ignore (heat +30, police arrive faster)
- **Evidence broker** — A rotating contact buys pocketed evidence at 1.5× base value; broker location changes daily; each sale carries a betrayal chance
- **Dual reputation tracks** — Cleaner Rep (loyalty to clients) and Broker Rep (informant network) are in tension; high Cleaner Rep unlocks tier-3 contracts; high Broker Rep unlocks better prices
- **Kit upgrade shop** — Three upgrade tiers at the rotating contact point: Tier 1 (faster animations), Tier 2 (UV scanner reveals hidden evidence), Tier 3 (heat gain –40%)
- **Timed bonus system** — Time Bonus (+25%) for finishing under the window; Ghost Bonus (+50%) for finishing under half the window; shown on the payout screen
- **Lifetime statistics** — `/cleanerstats` shows contracts, earnings, bodies, evidence ratios, fastest clean time, titles, and both rep tracks
- **Admin commands** — `/cleaner:spawnscene [tier]` spawns a scene at the admin's location; `/cleaner:resetrep [id]` resets a player's stats
- **Betrayal & blacklist system** — Three betrayals in 24 hours blacklists the player from that contract tier for 24 hours
- **Fully standalone** — Works without any other 187Scripts resource; exposes exports for cross-script integration

---

## How it works

### Contract lifecycle

```
Player receives contract notification (Y/N, 60s window)
  ↓ Accept
Scene blip appears → player drives to location
  ↓ Enter scene zone (~35m radius)
Scene assessment panel opens (non-blocking)
  Tasks:
    ├── Bag each body (press E, 7s progress bar)
    ├── Clean each surface (press E, 3–7s progress bar)
    └── Collect each evidence item (press E → 15s modal: Destroy or Pocket)
  Heat ticks up every 10s while in zone
  Completing tasks reduces heat
  ↓ All tasks done
Disposal phase → blip for disposal site
  Player drives to site
  Press E → 8s disposal animation + particle effect
  ↓ Disposal complete
Payout screen → base + bonus multiplier → money awarded
Cooldown: Config.ContractCooldown (default 600s)
```

### Heat system

- Heat starts at 0 when the contract begins
- +10 heat every `HeatTickRate` seconds (default 10s)
- –12 per body bagged, –8 per surface cleaned, –5 per evidence collected
- At 80%: warning notification
- At 100%: NPC police sweep, player must leave scene zone
- 90 seconds after leaving: heat drops to 60% of current value

### Reputation

- **Cleaner Rep**: earned by destroying evidence (+5 each). At 150 → Tier 2 contracts. At 500 → Tier 3.
- **Broker Rep**: earned by selling evidence to broker (+3 each) and completing contracts (+2–5).
- Three betrayals within 24 hours = 24h blacklist from that tier's contracts.

---

## Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `Config.Framework` | `'esx'` | Framework bridge to use |
| `Config.ContractCooldown` | `600` | Seconds between contracts per player |
| `Config.PayoutTier` | `{5000, 12000, 25000}` | Base payout per tier before bonuses |
| `Config.TimeBonusMultiplier` | `1.25` | Payout multiplier for finishing under window |
| `Config.GhostBonusMultiplier` | `1.50` | Payout multiplier for finishing under half window |
| `Config.UpgradePrices` | `{10000, 28000, 55000}` | Price per kit upgrade tier |
| `Config.HeatTickRate` | `10` | Seconds per heat increment |
| `Config.MaxHeat` | `100` | Heat threshold for police sweep |
| `Config.ContractTimeWindows` | `{480, 720, 1080}` | Seconds per tier |
| `Config.EvidenceBrokerBonus` | `1.5` | Multiplier on evidence pocket value at broker |
| `Config.RepBetrayalChance` | `0.20` | Probability a sold item is traced to the client |
| `Config.WitnessSpawnChance` | `0.35` | Probability a witness appears per contract |
| `Config.WitnessPayoffCost` | `500` | Cash deducted to silence witness |
| `Config.BlacklistThreshold` | `3` | Betrayals before tier blacklist |
| `Config.BlacklistDuration` | `86400` | Seconds of blacklist duration |
| `Config.DisposalSites` | See config | Table of coords + type |
| `Config.ContactLocations` | See config | Rotating contact point coords |
| `Config.BrokerLocations` | See config | Rotating broker coords |
| `Config.Scenes` | See config | Scene centers + task count ranges per tier |

---

## Commands & Keybinds

| Command | Permission | Description |
|---------|------------|-------------|
| `/cleanerregister` | Public | Register as a cleaner |
| `/cleanerstats` | Public | Open the statistics panel |
| `/cleaner:spawnscene [tier]` | `187cleaner.admin` | Spawn a scene at your location |
| `/cleaner:resetrep [id]` | `187cleaner.admin` | Reset a player's rep and stats |

**In-game interactions:**
- `E` — Bag body / Clean surface / Collect evidence / Dispose bags / Open shop / Contact broker
- `Y` — Accept incoming contract
- `N` — Decline incoming contract

---

## Exports

```lua
-- Returns the player's Cleaner Rep (integer)
exports['187Cleaner']:GetCleanerRep(src)

-- Returns the player's Broker Rep (integer)
exports['187Cleaner']:GetBrokerRep(src)

-- Returns true if the player is registered as a cleaner
exports['187Cleaner']:IsRegistered(src)
```

---

## Framework compatibility

| Framework | Status |
|-----------|--------|
| ESX | Supported |
| QBCore | Supported |
| Standalone | Supported (in-memory wallet) |

---

**187Scripts** — Quality FiveM Scripts
