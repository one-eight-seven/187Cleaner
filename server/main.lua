-- ============================================================
-- 187Cleaner — server/main.lua
-- ============================================================

-- 1. Local state
local activeContracts    = {}   -- [src] = contractData
local cooldowns          = {}   -- [src] = ms timestamp of last contract end
local repBlacklist       = {}   -- [src][tier] = os.time() expiry
local betrayalTimestamps = {}   -- [src] = { unix_timestamps } — 24h rolling window
local activeBrokerIndex  = 1    -- daily rotating broker location (1-based)

-- 2. Helper functions

local function recordBetrayal(src, tier)
    local now    = os.time()
    local cutoff = now - 86400
    local fresh  = {}
    for _, t in pairs(betrayalTimestamps[src] or {}) do
        if t > cutoff then fresh[#fresh + 1] = t end
    end
    fresh[#fresh + 1]      = now
    betrayalTimestamps[src] = fresh

    if #fresh >= Config.BlacklistThreshold then
        betrayalTimestamps[src] = {}  -- reset window
        if not repBlacklist[src] then repBlacklist[src] = {} end
        repBlacklist[src][tier] = now + Config.BlacklistDuration
        return #fresh, true
    end
    return #fresh, false
end

local function try187Export(res, fn, ...)
    if GetResourceState(res) == 'started' then
        return exports[res][fn](...)
    end
end

local function log(msg)
    if Config.Debug then print('[187Cleaner] ' .. tostring(msg)) end
end

local function getIdentifier(src)
    return GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifier(src, 0)
end

local function isOnline(src)
    return GetPlayerPing(src) >= 0
end

local function randomOffset(radius)
    local angle = math.random() * 2 * math.pi
    local dist  = math.sqrt(math.random()) * radius
    return dist * math.cos(angle), dist * math.sin(angle)
end

-- 3. Database functions
local function fetchPlayer(identifier, cb)
    MySQL.query('SELECT * FROM `187cleaner_players` WHERE identifier = ?', { identifier }, cb)
end

local function createPlayer(identifier, cb)
    MySQL.query('INSERT INTO `187cleaner_players` (identifier) VALUES (?)', { identifier }, cb)
end

local function updatePlayerField(identifier, field, value)
    MySQL.query('UPDATE `187cleaner_players` SET `' .. field .. '` = ? WHERE identifier = ?', { value, identifier })
end

local function incrementStat(identifier, field, amount)
    MySQL.query('UPDATE `187cleaner_players` SET `' .. field .. '` = `' .. field .. '` + ? WHERE identifier = ?', { amount or 1, identifier })
end

local function addEvidenceDB(identifier, eType, value, tier)
    MySQL.query('INSERT INTO `187cleaner_evidence` (identifier, evidence_type, evidence_value, contract_tier) VALUES (?,?,?,?)',
        { identifier, eType, value, tier })
end

local function checkRepTierUnlock(src, identifier)
    MySQL.query('SELECT cleaner_rep FROM `187cleaner_players` WHERE identifier = ?', { identifier }, function(res)
        if not res or not res[1] then return end
        local rep = res[1].cleaner_rep
        -- Fire unlock notification when rep just crossed a tier threshold (within a 60-rep window to catch the contract that pushed them over)
        if rep >= Config.RepTier3 and rep < Config.RepTier3 + 60 then
            TriggerClientEvent('187cleaner:repTierUnlocked', src, 3)
        elseif rep >= Config.RepTier2 and rep < Config.RepTier2 + 60 then
            TriggerClientEvent('187cleaner:repTierUnlocked', src, 2)
        end
    end)
end

-- 4. Business logic functions
local function isBlacklisted(src, tier)
    if not repBlacklist[src] then return false end
    local exp = repBlacklist[src][tier]
    if not exp then return false end
    return os.time() < exp
end

local function generateContract(src, tier)
    local pool = Config.Scenes[tier]
    if not pool or #pool == 0 then return nil end

    local scene   = pool[math.random(#pool)]
    local center  = scene.coords

    local bodyCount     = math.random(scene.bodiesMin, scene.bodiesMax)
    local surfaceCount  = math.random(scene.surfacesMin, scene.surfacesMax)
    local evidenceCount = math.random(scene.evidenceMin, scene.evidenceMax)

    local bodies = {}
    for i = 1, bodyCount do
        local ox, oy = randomOffset(12.0)
        bodies[i] = { index = i, coords = vector3(center.x + ox, center.y + oy, center.z), completed = false }
    end

    local surfaces = {}
    for i = 1, surfaceCount do
        local ox, oy = randomOffset(18.0)
        local st = Config.SurfaceTypes[math.random(#Config.SurfaceTypes)]
        surfaces[i] = { index = i, coords = vector3(center.x + ox, center.y + oy, center.z), type = st.id, cleanTime = st.cleanTime, completed = false }
    end

    local evidence = {}
    for i = 1, evidenceCount do
        local ox, oy = randomOffset(10.0)
        local et = Config.EvidenceItems[math.random(#Config.EvidenceItems)]
        evidence[i] = { index = i, coords = vector3(center.x + ox, center.y + oy, center.z), type = et.id, label = et.label, pocketValue = et.pocketValue, completed = false, decision = nil }
    end

    local uvEvidence = {}
    local uvCount    = math.random(1, 2)
    for i = 1, uvCount do
        local ox, oy = randomOffset(8.0)
        local et     = Config.EvidenceItems[math.random(#Config.EvidenceItems)]
        uvEvidence[i] = { index = i, coords = vector3(center.x + ox, center.y + oy, center.z), type = 'uv_' .. et.id, label = 'UV Trace', pocketValue = math.floor(et.pocketValue * 0.5), completed = false, decision = nil }
    end

    local disposal    = Config.DisposalSites[math.random(#Config.DisposalSites)]
    local timeWindow  = Config.ContractTimeWindows[tier]
    local basePayout  = Config.PayoutTier[tier]
    local flavourPool = Config.SceneFlavour and Config.SceneFlavour[tier]
    local flavour     = flavourPool and flavourPool[math.random(#flavourPool)] or ''

    return {
        contractId   = tostring(os.time()) .. '_' .. tostring(src) .. '_' .. tostring(math.random(1000, 9999)),
        tier         = tier,
        timeWindow   = timeWindow,
        payoutMin    = math.floor(basePayout * 0.9),
        payoutMax    = math.floor(basePayout * 1.1),
        flavour      = flavour,
        sceneCoords  = center,
        disposalSite = { coords = disposal.coords, type = disposal.type, label = disposal.label },
        tasks        = { bodies = bodies, surfaces = surfaces, evidence = evidence, uvEvidence = uvEvidence },
        heat         = 0,
        heatMaxed    = false,
        startTime    = os.time(),
        witnessActive= false,
        accepted     = false,
    }
end

local function startHeatTimer(src, contractId)
    Citizen.CreateThread(function()
        while activeContracts[src] and activeContracts[src].contractId == contractId do
            Citizen.Wait(Config.HeatTickRate * 1000)

            if not activeContracts[src] or activeContracts[src].contractId ~= contractId then break end

            local c = activeContracts[src]
            c.heat = math.min(Config.MaxHeat, c.heat + Config.HeatPerTick)
            TriggerClientEvent('187cleaner:heatUpdate', src, c.heat)

            if c.heat >= Config.MaxHeat and not c.heatMaxed then
                c.heatMaxed = true
                TriggerClientEvent('187cleaner:policeSweep', src)

                Citizen.CreateThread(function()
                    Citizen.Wait(90000)
                    if activeContracts[src] and activeContracts[src].contractId == contractId then
                        local c2 = activeContracts[src]
                        c2.heat    = math.floor(c2.heat * 0.6)
                        c2.heatMaxed = false
                        TriggerClientEvent('187cleaner:heatDropped', src, c2.heat)
                    end
                end)
            end
        end
    end)
end

local function startContractTimer(src, contractId, timeWindow)
    Citizen.CreateThread(function()
        Citizen.Wait(timeWindow * 1000)

        if not activeContracts[src] or activeContracts[src].contractId ~= contractId then return end

        local c = activeContracts[src]
        local completedCount = 0
        local totalTasks = #c.tasks.bodies + #c.tasks.surfaces + #c.tasks.evidence

        for _, t in pairs(c.tasks.bodies)   do if t.completed then completedCount = completedCount + 1 end end
        for _, t in pairs(c.tasks.surfaces) do if t.completed then completedCount = completedCount + 1 end end
        for _, t in pairs(c.tasks.evidence) do if t.completed then completedCount = completedCount + 1 end end

        local ratio        = totalTasks > 0 and (completedCount / totalTasks) or 0
        local partialPayout = math.floor(Config.PayoutTier[c.tier] * 0.5 * ratio)

        if partialPayout > 0 then Framework.addMoney(src, partialPayout) end

        local identifier = getIdentifier(src)
        if identifier then
            MySQL.query('UPDATE `187cleaner_players` SET total_contracts = total_contracts + 1, total_earned = total_earned + ? WHERE identifier = ?',
                { partialPayout, identifier })
        end

        activeContracts[src] = nil
        cooldowns[src]       = GetGameTimer()
        TriggerClientEvent('187cleaner:contractExpired', src, partialPayout)
    end)
end

local function scheduleWitness(src, contractId, sceneCoords)
    if math.random() > Config.WitnessSpawnChance then return end

    Citizen.CreateThread(function()
        Citizen.Wait(math.random(60000, 180000))

        if not activeContracts[src] or activeContracts[src].contractId ~= contractId then return end

        local c = activeContracts[src]
        c.witnessActive = true
        TriggerClientEvent('187cleaner:witnessAppeared', src, sceneCoords)

        Citizen.Wait(30000)
        if activeContracts[src] and activeContracts[src].contractId == contractId then
            local c2 = activeContracts[src]
            if c2.witnessActive then
                c2.witnessActive = false
                c2.heat = math.min(Config.MaxHeat, c2.heat + Config.WitnessIgnoreHeat)
                TriggerClientEvent('187cleaner:heatUpdate', src, c2.heat)
                TriggerClientEvent('187cleaner:witnessIgnorePenalty', src)
            end
        end
    end)
end

-- 5. Net events
RegisterNetEvent('187cleaner:playerReady', function()
    local src = source
    if src <= 0 then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    fetchPlayer(identifier, function(result)
        if result and result[1] then
            TriggerClientEvent('187cleaner:alreadyRegistered', src, { kitTier = result[1].kit_tier or 0 })
        end
    end)
end)

RegisterNetEvent('187cleaner:register', function()
    local src = source
    if src <= 0 then return end
    if cooldowns[src] and (GetGameTimer() - cooldowns[src]) < 3000 then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    fetchPlayer(identifier, function(result)
        if result and result[1] then
            TriggerClientEvent('187cleaner:alreadyRegistered', src, { kitTier = result[1].kit_tier or 0 })
            Framework.notify(src, Locale['already_registered'], 'inform')
            return
        end
        createPlayer(identifier, function(res)
            if res then
                TriggerClientEvent('187cleaner:registered', src, { kitTier = 0 })
                log('Registered: ' .. identifier)
                -- Immediately offer a first contract without waiting for the dispatch loop
                Citizen.SetTimeout(5000, function()
                    if not isOnline(src) or activeContracts[src] then return end
                    local contract = generateContract(src, 1)
                    if contract then
                        activeContracts[src] = contract
                        TriggerClientEvent('187cleaner:receiveContract', src, {
                            contractId = contract.contractId,
                            tier       = contract.tier,
                            timeWindow = contract.timeWindow,
                            payoutMin  = contract.payoutMin,
                            payoutMax  = contract.payoutMax,
                            flavour    = contract.flavour,
                        })
                    end
                end)
            end
        end)
    end)
end)

RegisterNetEvent('187cleaner:unregister', function()
    local src = source
    if src <= 0 then return end
    if activeContracts[src] then
        Framework.notify(src, Locale['unregister_on_contract'], 'error')
        return
    end

    local identifier = getIdentifier(src)
    if not identifier then return end

    fetchPlayer(identifier, function(result)
        if not result or not result[1] then
            Framework.notify(src, Locale['not_registered'], 'error')
            return
        end
        MySQL.query('DELETE FROM `187cleaner_players` WHERE identifier = ?', { identifier })
        MySQL.query('DELETE FROM `187cleaner_evidence` WHERE identifier = ?', { identifier })
        cooldowns[src]          = nil
        repBlacklist[src]       = nil
        betrayalTimestamps[src] = nil
        TriggerClientEvent('187cleaner:unregistered', src)
        log('Unregistered: ' .. identifier)
    end)
end)

RegisterNetEvent('187cleaner:acceptContract', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if not activeContracts[src] or activeContracts[src].contractId ~= data.contractId then return end
    if activeContracts[src].accepted then return end

    activeContracts[src].accepted = true
    local c = activeContracts[src]

    if isBlacklisted(src, c.tier) then
        Framework.notify(src, string.format(Locale['rep_blacklisted'], c.tier), 'error')
        activeContracts[src] = nil
        return
    end

    TriggerClientEvent('187cleaner:contractStarted', src, c)
    startHeatTimer(src, c.contractId)
    startContractTimer(src, c.contractId, c.timeWindow)
    scheduleWitness(src, c.contractId, c.sceneCoords)
    log('Contract accepted — src:' .. src .. ' tier:' .. c.tier)
end)

RegisterNetEvent('187cleaner:declineContract', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if activeContracts[src] and activeContracts[src].contractId == data.contractId then
        activeContracts[src] = nil
    end
end)

RegisterNetEvent('187cleaner:uvEvidenceCollected', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if not activeContracts[src] or activeContracts[src].contractId ~= data.contractId then return end

    local c = activeContracts[src]
    local idx = tonumber(data.index)
    if not idx or not c.tasks.uvEvidence[idx] then return end
    if c.tasks.uvEvidence[idx].completed then return end

    c.tasks.uvEvidence[idx].completed = true

    local identifier = getIdentifier(src)
    if identifier then
        MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = cleaner_rep + 7 WHERE identifier = ?', { identifier })
    end
    TriggerClientEvent('187cleaner:uvEvidenceAck', src, { index = idx })
end)

RegisterNetEvent('187cleaner:taskComplete', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if not activeContracts[src] or activeContracts[src].contractId ~= data.contractId then return end

    local c   = activeContracts[src]
    local typ = data.taskType
    local idx = tonumber(data.taskIndex)
    if not idx then return end

    local identifier = getIdentifier(src)

    if typ == 'body' and c.tasks.bodies[idx] and not c.tasks.bodies[idx].completed then
        c.tasks.bodies[idx].completed = true
        c.heat = math.max(0, c.heat + Config.HeatOnBody)
        TriggerClientEvent('187cleaner:heatUpdate', src, c.heat)
        if identifier then
            MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = cleaner_rep + 2 WHERE identifier = ?', { identifier })
        end

    elseif typ == 'surface' and c.tasks.surfaces[idx] and not c.tasks.surfaces[idx].completed then
        c.tasks.surfaces[idx].completed = true
        c.heat = math.max(0, c.heat + Config.HeatOnSurface)
        TriggerClientEvent('187cleaner:heatUpdate', src, c.heat)
        if identifier then
            MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = cleaner_rep + 1 WHERE identifier = ?', { identifier })
        end
    end
end)

RegisterNetEvent('187cleaner:evidenceDecision', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if not activeContracts[src] or activeContracts[src].contractId ~= data.contractId then return end

    local c   = activeContracts[src]
    local idx = tonumber(data.taskIndex)
    if not idx or not c.tasks.evidence[idx] then return end

    local ev = c.tasks.evidence[idx]
    if ev.completed then return end

    ev.completed = true
    ev.decision  = data.decision

    c.heat = math.max(0, c.heat + Config.HeatOnEvidence)
    TriggerClientEvent('187cleaner:heatUpdate', src, c.heat)

    local identifier = getIdentifier(src)
    if not identifier then return end

    if data.decision == 'pocket' then
        addEvidenceDB(identifier, ev.type, ev.pocketValue, c.tier)

        -- Possible immediate betrayal discover (low probability)
        if math.random() < (Config.RepBetrayalChance * 0.25) then
            Citizen.SetTimeout(math.random(5000, 25000), function()
                if not isOnline(src) then return end
                TriggerClientEvent('187cleaner:betrayalDiscovered', src)
                MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = GREATEST(0, cleaner_rep - 10), current_streak = 0, betrayals = betrayals + 1 WHERE identifier = ?', { identifier })

                local _, blacklisted = recordBetrayal(src, c.tier)
                if blacklisted then
                    TriggerClientEvent('187cleaner:repBlacklisted', src, c.tier)
                end
            end)
        end
    else
        -- Destroy: +5 cleaner rep
        MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = cleaner_rep + 5, evidence_destroyed = evidence_destroyed + 1 WHERE identifier = ?', { identifier })
    end
end)

RegisterNetEvent('187cleaner:disposalComplete', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if not activeContracts[src] or activeContracts[src].contractId ~= data.contractId then return end

    local c = activeContracts[src]

    -- Validate all tasks done
    for _, t in pairs(c.tasks.bodies)   do if not t.completed then Framework.notify(src, Locale['not_all_done'], 'error'); return end end
    for _, t in pairs(c.tasks.surfaces) do if not t.completed then Framework.notify(src, Locale['not_all_done'], 'error'); return end end
    for _, t in pairs(c.tasks.evidence) do if not t.completed then Framework.notify(src, Locale['not_all_done'], 'error'); return end end

    local elapsed    = os.time() - c.startTime
    local multiplier = 1.0
    local bonusType  = 'none'

    if elapsed < c.timeWindow / 2 then
        multiplier = Config.GhostBonusMultiplier
        bonusType  = 'ghost'
    elseif elapsed < c.timeWindow then
        multiplier = Config.TimeBonusMultiplier
        bonusType  = 'time'
    end

    -- Streak: did player pocket any evidence this contract?
    local pocketedAny = false
    for _, ev in pairs(c.tasks.evidence) do
        if ev.decision == 'pocket' then pocketedAny = true; break end
    end

    local identifier = getIdentifier(src)
    -- Compute streak bonus before payout
    local streakBonus = 0
    if not pocketedAny and identifier then
        -- We'll read streak from DB and apply bonus; use cached if available
    end

    local basePayout  = math.random(c.payoutMin, c.payoutMax)
    local finalPayout = math.floor(basePayout * multiplier)

    if identifier then
        fetchPlayer(identifier, function(rows)
            local player      = rows and rows[1]
            local oldStreak   = (player and player.current_streak) or 0
            local newStreak   = pocketedAny and 0 or (oldStreak + 1)
            local bestStreak  = (player and player.best_streak) or 0
            local strBonus    = not pocketedAny and math.min(oldStreak, Config.MaxStreakBonus) * Config.StreakBonusPerContract or 0
            local finalWithStreak = math.floor(finalPayout * (1.0 + strBonus))

            Framework.addMoney(src, finalWithStreak)

            MySQL.query([[
                UPDATE `187cleaner_players` SET
                    total_contracts = total_contracts + 1,
                    total_earned    = total_earned + ?,
                    total_bodies    = total_bodies + ?,
                    broker_rep      = broker_rep + ?,
                    fastest_clean   = CASE WHEN fastest_clean = 0 OR ? < fastest_clean THEN ? ELSE fastest_clean END,
                    current_streak  = ?,
                    best_streak     = GREATEST(best_streak, ?)
                WHERE identifier = ?
            ]], { finalWithStreak, #c.tasks.bodies, math.random(2, 5), elapsed, elapsed, newStreak, newStreak, identifier }, function()
                checkRepTierUnlock(src, identifier)
            end)

            TriggerClientEvent('187cleaner:payoutScreen', src, {
                tier        = c.tier,
                base        = basePayout,
                multiplier  = multiplier,
                streakBonus = strBonus,
                streak      = newStreak,
                total       = finalWithStreak,
                bonusType   = bonusType,
                bodies      = #c.tasks.bodies,
                elapsed     = elapsed,
            })

            activeContracts[src] = nil
            cooldowns[src]       = GetGameTimer()
            log('Contract complete — src:' .. src .. ' payout:$' .. finalWithStreak .. ' bonus:' .. bonusType .. ' streak:' .. newStreak)
        end)
        return  -- return early; payout triggered in callback
    end

    -- Fallback if no identifier (shouldn't happen)
    Framework.addMoney(src, finalPayout)

    TriggerClientEvent('187cleaner:payoutScreen', src, {
        tier       = c.tier,
        base       = basePayout,
        multiplier = multiplier,
        total      = finalPayout,
        bonusType  = bonusType,
        bodies     = #c.tasks.bodies,
        elapsed    = elapsed,
    })

    activeContracts[src] = nil
    cooldowns[src]       = GetGameTimer()
    log('Contract complete — src:' .. src .. ' payout:$' .. finalPayout .. ' bonus:' .. bonusType)
end)

RegisterNetEvent('187cleaner:witnessDecision', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if not activeContracts[src] or activeContracts[src].contractId ~= data.contractId then return end

    local c = activeContracts[src]

    if data.decision == 'pay' then
        local money = Framework.getMoney(src)
        if money < Config.WitnessPayoffCost then
            Framework.notify(src, Locale['not_enough_money'], 'error')
            return  -- witness still active; player must choose again
        end
        Framework.removeMoney(src, Config.WitnessPayoffCost)
        c.witnessActive = false
    elseif data.decision == 'report' then
        local identifier = getIdentifier(src)
        if identifier then
            MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = GREATEST(0, cleaner_rep - 10) WHERE identifier = ?', { identifier })
        end
        c.witnessActive = false
    elseif data.decision == 'ignore' then
        c.witnessActive = false
    end
end)

RegisterNetEvent('187cleaner:purchaseUpgrade', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if cooldowns[src] and (GetGameTimer() - cooldowns[src]) < 2000 then return end

    local tier = tonumber(data.tier)
    if not tier or tier < 1 or tier > 3 then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    fetchPlayer(identifier, function(result)
        if not result or not result[1] then return end
        local player = result[1]

        if player.kit_tier >= tier then
            TriggerClientEvent('187cleaner:upgradeFailed', src, 'upgrade_already_owned')
            return
        end

        if player.kit_tier ~= tier - 1 then
            TriggerClientEvent('187cleaner:upgradeFailed', src, 'upgrade_wrong_tier')
            return
        end

        local price = Config.UpgradePrices[tier]
        if Framework.getMoney(src) < price then
            TriggerClientEvent('187cleaner:upgradeFailed', src, 'not_enough_money')
            return
        end

        Framework.removeMoney(src, price)
        updatePlayerField(identifier, 'kit_tier', tier)
        TriggerClientEvent('187cleaner:upgradeSuccess', src, tier)
    end)
end)

RegisterNetEvent('187cleaner:requestStats', function()
    local src = source
    if src <= 0 then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    fetchPlayer(identifier, function(result)
        if not result or not result[1] then
            Framework.notify(src, Locale['not_registered'], 'error')
            return
        end
        local p = result[1]

        MySQL.query('SELECT COUNT(*) as cnt, SUM(evidence_value) as total FROM `187cleaner_evidence` WHERE identifier = ?', { identifier }, function(evRes)
            local evCount = (evRes and evRes[1] and evRes[1].cnt)   or 0
            local evTotal = (evRes and evRes[1] and evRes[1].total) or 0

            TriggerClientEvent('187cleaner:statsData', src, {
                cleanerRep       = p.cleaner_rep       or 0,
                brokerRep        = p.broker_rep        or 0,
                kitTier          = p.kit_tier          or 0,
                totalContracts   = p.total_contracts   or 0,
                totalEarned      = p.total_earned      or 0,
                totalBodies      = p.total_bodies      or 0,
                evidenceDestroyed= p.evidence_destroyed or 0,
                evidenceSoldCount= evCount,
                evidenceSoldValue= evTotal or 0,
                betrayals        = p.betrayals         or 0,
                fastestClean     = p.fastest_clean     or 0,
                currentStreak    = p.current_streak    or 0,
                bestStreak       = p.best_streak       or 0,
            })
        end)

        -- Leaderboard: attach asynchronously
        MySQL.query('SELECT identifier, fastest_clean, total_contracts FROM `187cleaner_players` WHERE fastest_clean > 0 ORDER BY fastest_clean ASC LIMIT 5', {}, function(lb)
            -- Send leaderboard as a separate update to not delay the stats panel open
            TriggerClientEvent('187cleaner:leaderboardData', src, lb or {})
        end)
    end)
end)

RegisterNetEvent('187cleaner:requestShop', function()
    local src = source
    if src <= 0 then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    fetchPlayer(identifier, function(result)
        if not result or not result[1] then
            Framework.notify(src, Locale['not_registered'], 'error')
            return
        end
        local p = result[1]

        TriggerClientEvent('187cleaner:shopData', src, {
            kitTier    = p.kit_tier    or 0,
            cleanerRep = p.cleaner_rep or 0,
            upgrades   = Config.UpgradePrices,
            kitDefs    = Config.KitUpgrades,
            money      = Framework.getMoney(src),
        })
    end)
end)

RegisterNetEvent('187cleaner:requestBroker', function()
    local src = source
    if src <= 0 then return end

    local identifier = getIdentifier(src)
    if not identifier then return end

    MySQL.query('SELECT * FROM `187cleaner_evidence` WHERE identifier = ? ORDER BY created_at DESC LIMIT 20', { identifier }, function(result)
        TriggerClientEvent('187cleaner:brokerData', src, {
            evidence        = result or {},
            bonusMultiplier = Config.EvidenceBrokerBonus,
        })
    end)
end)

RegisterNetEvent('187cleaner:sellEvidence', function(data)
    local src = source
    if src <= 0 or type(data) ~= 'table' then return end
    if cooldowns[src] and (GetGameTimer() - cooldowns[src]) < 2000 then return end
    cooldowns[src] = GetGameTimer()

    local identifier = getIdentifier(src)
    if not identifier then return end

    local evId = tonumber(data.evidenceId)
    if not evId then return end

    MySQL.query('SELECT * FROM `187cleaner_evidence` WHERE id = ? AND identifier = ?', { evId, identifier }, function(result)
        if not result or not result[1] then return end

        local ev     = result[1]
        local amount = math.floor(ev.evidence_value * Config.EvidenceBrokerBonus)

        Framework.addMoney(src, amount)
        MySQL.query('DELETE FROM `187cleaner_evidence` WHERE id = ?', { evId })
        MySQL.query('UPDATE `187cleaner_players` SET broker_rep = broker_rep + 3 WHERE identifier = ?', { identifier })

        TriggerClientEvent('187cleaner:evidenceSold', src, { amount = amount, id = evId })

        -- Betrayal chance on broker sale
        if math.random() < Config.RepBetrayalChance then
            Citizen.SetTimeout(math.random(3000, 15000), function()
                if not isOnline(src) then return end
                TriggerClientEvent('187cleaner:betrayalDiscovered', src)
                MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = GREATEST(0, cleaner_rep - 15), betrayals = betrayals + 1, current_streak = 0 WHERE identifier = ?', { identifier })

                local _, blacklisted = recordBetrayal(src, ev.contract_tier)
                if blacklisted then
                    TriggerClientEvent('187cleaner:repBlacklisted', src, ev.contract_tier)
                end
            end)
        end
    end)
end)

-- 6. Callbacks
lib.callback.register('187cleaner:getStats', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return nil end
    local result    = MySQL.query.await('SELECT * FROM `187cleaner_players` WHERE identifier = ?', { identifier })
    local leaderboard = MySQL.query.await(
        'SELECT identifier, fastest_clean, total_contracts FROM `187cleaner_players` WHERE fastest_clean > 0 ORDER BY fastest_clean ASC LIMIT 5'
    )
    local stats = result and result[1] or nil
    if stats then stats.leaderboard = leaderboard or {} end
    return stats
end)

-- 7. Admin commands
RegisterCommand('cleaner:spawnscene', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, '187cleaner.admin') then
        Framework.notify(src, Locale['no_permission'], 'error')
        return
    end

    local tier = math.max(1, math.min(3, tonumber(args[1]) or 1))

    -- Place scene near player or at server console origin
    local centerCoords
    if src == 0 then
        centerCoords = vector3(459.3, -1003.5, 28.0)
    else
        local ped = GetPlayerPed(src)
        local pos = GetEntityCoords(ped)
        centerCoords = vector3(pos.x + 5.0, pos.y, pos.z)
    end

    local contract = generateContract(src, tier)
    if not contract then return end
    contract.sceneCoords = centerCoords

    activeContracts[src] = contract
    TriggerClientEvent('187cleaner:receiveContract', src, {
        contractId = contract.contractId,
        tier       = contract.tier,
        payoutMin  = contract.payoutMin,
        payoutMax  = contract.payoutMax,
        timeWindow = contract.timeWindow,
    })
    Framework.notify(src, '[Admin] Scene spawned — Tier ' .. tier, 'success')
end, false)

RegisterCommand('cleaner:resetrep', function(src, args)
    if src ~= 0 and not IsPlayerAceAllowed(src, '187cleaner.admin') then return end

    local targetId = tonumber(args[1])
    if not targetId then return end

    local identifier = getIdentifier(targetId)
    if not identifier then return end

    MySQL.query('UPDATE `187cleaner_players` SET cleaner_rep = 0, broker_rep = 0, kit_tier = 0, betrayals = 0 WHERE identifier = ?', { identifier })
    Framework.notify(src, '[Admin] Stats reset for player ' .. targetId, 'success')
end, false)

-- 8. Exports
exports('GetCleanerRep', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return 0 end
    local r = MySQL.query.await('SELECT cleaner_rep FROM `187cleaner_players` WHERE identifier = ?', { identifier })
    return r and r[1] and r[1].cleaner_rep or 0
end)

exports('GetBrokerRep', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return 0 end
    local r = MySQL.query.await('SELECT broker_rep FROM `187cleaner_players` WHERE identifier = ?', { identifier })
    return r and r[1] and r[1].broker_rep or 0
end)

exports('IsRegistered', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return false end
    local r = MySQL.query.await('SELECT identifier FROM `187cleaner_players` WHERE identifier = ?', { identifier })
    return r and #r > 0
end)

-- 9. Resource lifecycle
AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    log('187Cleaner started.')

    -- Contract dispatch loop — offer contracts every 2 minutes to eligible players
    Citizen.CreateThread(function()
        Citizen.Wait(30000)  -- warm-up
        while true do
            Citizen.Wait(120000)

            local players = GetPlayers()
            for _, srcStr in pairs(players) do
                local src = tonumber(srcStr)
                if not activeContracts[src] then
                    local cd = cooldowns[src] or 0
                    if (GetGameTimer() - cd) > Config.ContractCooldown * 1000 then
                        local identifier = getIdentifier(src)
                        if identifier then
                            fetchPlayer(identifier, function(result)
                                if not result or not result[1] then return end
                                local p = result[1]

                                local tier = 1
                                if (p.cleaner_rep or 0) >= Config.RepTier3 then tier = 3
                                elseif (p.cleaner_rep or 0) >= Config.RepTier2 then tier = 2 end

                                if isBlacklisted(src, tier) then return end

                                local contract = generateContract(src, tier)
                                if not contract then return end
                                activeContracts[src] = contract

                                TriggerClientEvent('187cleaner:receiveContract', src, {
                                    contractId = contract.contractId,
                                    tier       = contract.tier,
                                    payoutMin  = contract.payoutMin,
                                    payoutMax  = contract.payoutMax,
                                    timeWindow = contract.timeWindow,
                                })
                            end)
                        end
                    end
                end
            end
        end
    end)
end)

-- Broker daily rotation — compute once at start, refresh at midnight
local function computeBrokerIndex()
    return (os.time() // 86400) % #Config.BrokerLocations + 1
end
activeBrokerIndex = computeBrokerIndex()

Citizen.CreateThread(function()
    while true do
        local now         = os.time()
        local secondsToday = now % 86400
        local waitSecs    = 86400 - secondsToday + 1
        Citizen.Wait(waitSecs * 1000)
        activeBrokerIndex = computeBrokerIndex()
        TriggerAllClients('187cleaner:brokerLocationUpdated', activeBrokerIndex)
        log('Broker location rotated to index ' .. activeBrokerIndex)
    end
end)

RegisterNetEvent('187cleaner:requestBrokerIndex', function()
    local src = source
    if src <= 0 then return end
    TriggerClientEvent('187cleaner:brokerLocationUpdated', src, activeBrokerIndex)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    activeContracts    = {}
    cooldowns          = {}
    repBlacklist       = {}
    betrayalTimestamps = {}
end)

AddEventHandler('playerDropped', function()
    local src = source
    activeContracts[src] = nil
    cooldowns[src]       = GetGameTimer()
    betrayalTimestamps[src] = nil
end)
