Config = {}

-- Framework: 'esx', 'qbcore', 'standalone'
Config.Framework  = 'esx'
Config.Debug      = false
Config.Locale     = 'en'

-- Economy
Config.ContractCooldown      = 600    -- seconds between contracts per player
Config.PayoutTier            = { 5000, 12000, 25000 }  -- base payout per tier
Config.TimeBonusMultiplier   = 1.25   -- finish under time window
Config.GhostBonusMultiplier  = 1.50   -- finish under half the time window
Config.UpgradePrices         = { 10000, 28000, 55000 }  -- Tier 1/2/3

-- Heat system
Config.HeatTickRate  = 10    -- seconds between heat increments
Config.MaxHeat       = 100   -- heat at which police sweep triggers
Config.HeatPerTick   = 10    -- heat added per tick
Config.HeatOnBody    = -12   -- heat reduction per body bagged
Config.HeatOnSurface = -8    -- heat reduction per surface cleaned
Config.HeatOnEvidence= -5    -- heat reduction per evidence collected

-- Contract time windows (seconds per tier)
Config.ContractTimeWindows = { 480, 720, 1080 }

-- Evidence broker
Config.EvidenceBrokerBonus = 1.5   -- multiplier on pocket value when sold to broker
Config.RepBetrayalChance   = 0.20  -- probability a sold item is traced back to client

-- Witness
Config.WitnessSpawnChance  = 0.35  -- probability a witness appears (0.0–1.0)
Config.WitnessPayoffCost   = 500   -- cash deducted to silence witness
Config.WitnessIgnoreHeat   = 30    -- heat added if witness is ignored

-- Reputation thresholds for tier access
Config.RepTier2 = 150   -- cleaner_rep needed for tier-2 contracts
Config.RepTier3 = 500   -- cleaner_rep needed for tier-3 contracts

-- Blacklist: betrayals within 24h before blacklist triggers
Config.BlacklistThreshold = 3
Config.BlacklistDuration  = 86400  -- seconds

-- Disposal sites (type: 'incinerator' | 'container' | 'ocean')
Config.DisposalSites = {
    { coords = vector3(459.3,  -2023.5, 25.5),   type = 'incinerator', label = 'Elysian Island Incinerator' },
    { coords = vector3(568.7,  -2793.5, 5.4),    type = 'container',   label = 'Terminal Container Yard'    },
    { coords = vector3(1415.3, -2032.4, 75.0),   type = 'ocean',       label = 'Palomino Cliffs Dump'       },
    { coords = vector3(-176.5, -2098.3, 5.3),    type = 'container',   label = 'La Mesa Junkyard'           },
}

-- Rotating contact points (cleaner registration & kit shop)
Config.ContactLocations = {
    vector3(459.3, -1003.5, 28.0),   -- Cypress Flats alley
    vector3(819.4, -1299.0, 28.3),   -- La Mesa industrial bay
    vector3(-116.2, -1427.8, 31.1),  -- Elysian back road
}

-- Rotating broker locations (sell pocketed evidence)
Config.BrokerLocations = {
    vector3(-1094.5, -1072.5, 2.0),  -- Vespucci
    vector3(155.0,   -1285.0, 29.3), -- Del Perro parking
    vector3(1094.3,  -819.4,  57.8), -- Vinewood Hills edge
}

-- Scene definitions per tier
-- Each entry: scene center coord + task count ranges
-- Task positions are randomised around the center at runtime
Config.Scenes = {
    -- Tier 1 — light
    {
        { coords = vector3(459.3,   -1003.5, 28.0), bodiesMin = 1, bodiesMax = 1, surfacesMin = 2, surfacesMax = 3, evidenceMin = 1, evidenceMax = 1 },
        { coords = vector3(573.2,   -1028.5, 28.3), bodiesMin = 1, bodiesMax = 1, surfacesMin = 2, surfacesMax = 2, evidenceMin = 1, evidenceMax = 1 },
        { coords = vector3(-116.2,  -1427.8, 31.1), bodiesMin = 1, bodiesMax = 1, surfacesMin = 2, surfacesMax = 3, evidenceMin = 1, evidenceMax = 2 },
        { coords = vector3(1076.5,  -719.4,  57.8), bodiesMin = 1, bodiesMax = 1, surfacesMin = 1, surfacesMax = 2, evidenceMin = 1, evidenceMax = 1 },
    },
    -- Tier 2 — moderate
    {
        { coords = vector3(1001.8,  -1001.5, 43.9), bodiesMin = 2, bodiesMax = 3, surfacesMin = 3, surfacesMax = 4, evidenceMin = 2, evidenceMax = 3 },
        { coords = vector3(-520.3,  -1195.6, 18.2), bodiesMin = 2, bodiesMax = 3, surfacesMin = 3, surfacesMax = 4, evidenceMin = 2, evidenceMax = 3 },
        { coords = vector3(156.7,   -1289.4, 29.3), bodiesMin = 2, bodiesMax = 2, surfacesMin = 3, surfacesMax = 4, evidenceMin = 2, evidenceMax = 3 },
        { coords = vector3(-299.4,  -793.2,  31.6), bodiesMin = 2, bodiesMax = 3, surfacesMin = 3, surfacesMax = 5, evidenceMin = 2, evidenceMax = 3 },
    },
    -- Tier 3 — heavy
    {
        { coords = vector3(573.2,   -2802.4, 5.4),  bodiesMin = 3, bodiesMax = 5, surfacesMin = 4, surfacesMax = 6, evidenceMin = 3, evidenceMax = 4 },
        { coords = vector3(460.3,   -2019.8, 25.5), bodiesMin = 3, bodiesMax = 4, surfacesMin = 4, surfacesMax = 5, evidenceMin = 3, evidenceMax = 4 },
        { coords = vector3(819.4,   -1298.7, 28.0), bodiesMin = 3, bodiesMax = 5, surfacesMin = 5, surfacesMax = 6, evidenceMin = 3, evidenceMax = 4 },
        { coords = vector3(-1094.5, -1072.5, 2.0),  bodiesMin = 4, bodiesMax = 5, surfacesMin = 5, surfacesMax = 6, evidenceMin = 3, evidenceMax = 4 },
    },
}

-- Evidence items (pocketValue = cash from broker before bonus multiplier)
Config.EvidenceItems = {
    { id = 'shell_casing',  label = 'Shell Casing',             pocketValue = 800  },
    { id = 'burner_phone',  label = 'Burner Phone',             pocketValue = 2200 },
    { id = 'document',      label = 'Incriminating Document',   pocketValue = 3500 },
    { id = 'blood_sample',  label = 'Blood Sample',             pocketValue = 1500 },
    { id = 'knife',         label = 'Murder Weapon',            pocketValue = 4500 },
    { id = 'zip_tie',       label = 'Restraint Fragment',       pocketValue = 600  },
}

-- Surface types and their clean durations (ms)
Config.SurfaceTypes = {
    { id = 'blood_pool',     label = 'Blood Pool',       cleanTime = 5000 },
    { id = 'glass_shards',   label = 'Glass Shards',     cleanTime = 3000 },
    { id = 'chemical_spill', label = 'Chemical Spill',   cleanTime = 7000 },
}

-- Kit upgrade definitions (effects are enforced client-side; server sets tier)
Config.KitUpgrades = {
    [1] = { name = 'Field Kit',       desc = 'Faster clean animations (–30%) · Extended bag radius', effect = 'speed' },
    [2] = { name = 'UV Scanner Kit',  desc = 'Reveals hidden bonus evidence worth 3× · Double bag capacity', effect = 'uv' },
    [3] = { name = 'Chemical Kit',    desc = 'Heat gain rate –40% · Leaves no surface trace', effect = 'heat' },
}
