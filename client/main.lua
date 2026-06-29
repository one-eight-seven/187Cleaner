-- ============================================================
-- 187Cleaner — client/main.lua
-- ============================================================

-- 1. Local state
local isRegistered     = false
local isOnContract     = false
local contractData     = nil
local contractPhase    = 'none'   -- 'none' | 'scene' | 'disposal'
local completedTasks   = { bodies = {}, surfaces = {}, evidence = {}, uvEvidence = {} }
local currentHeat      = 0
local contractStartTick= 0        -- GetGameTimer() value at contract start
local contractTimeWindow = 0      -- seconds
local activeBlips      = {}
local isInScene        = false
local witnessHandled   = false
local playerKitTier    = 0        -- 0 = no upgrade, 1/2/3
local contractAcceptKey  = false   -- waiting for Y/N input
local pendingContractId  = nil
local isDisposing        = false
local activeBrokerIndex  = 1      -- set from server on resource start + daily rotation
local contactNpcs        = {}

-- 2. Helper / utility functions

local function spawnContactNpcs()
    if #contactNpcs > 0 then return end  -- already spawned
    local MODEL_HASH = GetHashKey('s_m_y_garbage_01')
    RequestModel(MODEL_HASH)
    local t = 0
    repeat Citizen.Wait(100); t = t + 100 until HasModelLoaded(MODEL_HASH) or t > 5000
    for _, loc in pairs(Config.ContactLocations) do
        local ped = CreatePed(4, MODEL_HASH, loc.x, loc.y, loc.z - 1.0, 0.0, false, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, true)
        SetModelAsNoLongerNeeded(MODEL_HASH)
        contactNpcs[#contactNpcs + 1] = ped
    end
end

local function cleanupContactNpcs()
    for _, ped in pairs(contactNpcs) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    contactNpcs = {}
end

local function log(msg)
    if Config.Debug then print('[187Cleaner] ' .. tostring(msg)) end
end

local function showHint(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function addMapBlip(coords, sprite, color, label, shortRange)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, shortRange or false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function clearAllBlips()
    for k, blip in pairs(activeBlips) do
        removeBlip(blip)
        activeBlips[k] = nil
    end
end


local function timeLeftFormatted()
    if contractStartTick == 0 then return '--:--' end
    local elapsed = math.floor((GetGameTimer() - contractStartTick) / 1000)
    local left    = math.max(0, contractTimeWindow - elapsed)
    return string.format('%02d:%02d', math.floor(left / 60), left % 60)
end

local function allSceneTasksDone()
    if not contractData then return false end
    for i = 1, #contractData.tasks.bodies do
        if not completedTasks.bodies[i] then return false end
    end
    for i = 1, #contractData.tasks.surfaces do
        if not completedTasks.surfaces[i] then return false end
    end
    for i = 1, #contractData.tasks.evidence do
        if not completedTasks.evidence[i] then return false end
    end
    return true
end

local function pushSceneUpdate()
    if not isOnContract or contractPhase ~= 'scene' then return end
    SendNUIMessage({
        action = 'updateScene',
        heat   = currentHeat,
        timer  = timeLeftFormatted(),
        tasks  = { bodies = completedTasks.bodies, surfaces = completedTasks.surfaces, evidence = completedTasks.evidence },
    })
end

-- 3. Core logic functions
local function cleanupContract()
    isOnContract       = false
    contractData       = nil
    contractPhase      = 'none'
    completedTasks     = { bodies = {}, surfaces = {}, evidence = {}, uvEvidence = {} }
    currentHeat        = 0
    contractStartTick  = 0
    contractTimeWindow = 0
    isInScene          = false
    witnessHandled     = false
    contractAcceptKey  = false
    pendingContractId  = nil
    clearAllBlips()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideScene' })
end

local function startDisposalPhase()
    if contractPhase == 'disposal' then return end
    contractPhase = 'disposal'
    removeBlip(activeBlips.scene)
    activeBlips.scene = nil

    local site = contractData.disposalSite
    activeBlips.disposal = addMapBlip(site.coords, 446, 1, Locale['disposal_blip'], false)

    SendNUIMessage({ action = 'hideScene' })
    lib.notify({ title = '187 Cleaner', description = Locale['scene_clear'], type = 'inform' })
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)
end

local function bagBody(index)
    if completedTasks.bodies[index] then return end
    completedTasks.bodies[index] = true

    local dur = 7000
    local success = lib.progressBar({
        duration   = dur,
        label      = Locale['task_bag_body'],
        useWhileDead = false,
        canCancel  = true,
        disable    = { move = true, car = true, combat = true },
        anim       = { dict = 'random@arrests', clip = 'kneeling_arrest_ground', flag = 49 },
    })

    if not success then
        completedTasks.bodies[index] = false
        return
    end

    PlaySoundFrontend(-1, 'PLASTIC_WRAP', 'DLC_HEIST_FLEECA_SOUNDSET', true)
    TriggerServerEvent('187cleaner:taskComplete', {
        contractId = contractData.contractId,
        taskType   = 'body',
        taskIndex  = index,
    })
    lib.notify({ title = '187 Cleaner', description = Locale['body_bagged'], type = 'success' })
    pushSceneUpdate()

    if allSceneTasksDone() then startDisposalPhase() end
end

local function cleanSurface(index)
    if completedTasks.surfaces[index] then return end
    completedTasks.surfaces[index] = true

    local surface  = contractData.tasks.surfaces[index]
    local duration = surface.cleanTime or 5000
    if playerKitTier >= 1 then duration = math.floor(duration * 0.7) end

    local success = lib.progressBar({
        duration   = duration,
        label      = Locale['task_clean_surface'],
        useWhileDead = false,
        canCancel  = true,
        disable    = { move = true, car = true, combat = true },
        anim       = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
    })

    if not success then
        completedTasks.surfaces[index] = false
        return
    end

    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    TriggerServerEvent('187cleaner:taskComplete', {
        contractId = contractData.contractId,
        taskType   = 'surface',
        taskIndex  = index,
    })
    lib.notify({ title = '187 Cleaner', description = Locale['surface_cleaned'], type = 'success' })
    pushSceneUpdate()

    if allSceneTasksDone() then startDisposalPhase() end
end

local function collectEvidence(index)
    if completedTasks.evidence[index] then return end
    completedTasks.evidence[index] = true

    local ev = contractData.tasks.evidence[index]
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showEvidenceDecision',
        data   = {
            id            = index,
            label         = ev.label,
            pocketValue   = ev.pocketValue,
            repGain       = 5,
            betrayalChance = math.floor(Config.RepBetrayalChance * 100),
        },
    })
end

local function collectUvEvidence(index)
    if completedTasks.uvEvidence[index] then return end
    completedTasks.uvEvidence[index] = true

    local success = lib.progressBar({
        duration   = 3500,
        label      = Locale['task_collect_uv'],
        useWhileDead = false,
        canCancel  = true,
        disable    = { move = true, car = true, combat = true },
        anim       = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop', flag = 49 },
    })

    if not success then
        completedTasks.uvEvidence[index] = false
        return
    end

    PlaySoundFrontend(-1, 'SCAN_UP', 'SCANNING_SOUNDSET', true)
    TriggerServerEvent('187cleaner:uvEvidenceCollected', {
        contractId = contractData.contractId,
        index      = index,
    })
    lib.notify({ title = '187 Cleaner', description = Locale['uv_evidence_collected'], type = 'success' })
end

local function doDisposal()
    if isDisposing then return end
    isDisposing = true

    local site = contractData.disposalSite

    local animDict = site.type == 'ocean' and 'random@arrests' or 'mini@repair'
    local animClip = site.type == 'ocean' and 'kneeling_arrest_ground' or 'fixing_a_ped'

    local success = lib.progressBar({
        duration   = 8000,
        label      = Locale['disposal_label_' .. (site.type or 'container')],
        useWhileDead = false,
        canCancel  = false,
        disable    = { move = true, car = true, combat = true },
        anim       = { dict = animDict, clip = animClip, flag = 49 },
    })
    isDisposing = false
    if not success then return end

    -- Particle (incinerator only)
    if site.type == 'incinerator' then
        local s = site.coords
        if not HasNamedPtfxAssetLoaded('core') then
            RequestNamedPtfxAsset('core')
            local t = 0
            repeat Citizen.Wait(0); t = t + 1 until HasNamedPtfxAssetLoaded('core') or t > 60
        end
        UseParticleFxAssetNextCall('core')
        StartParticleFxLoopedAtCoord('exp_grd_flare', s.x, s.y, s.z, 0, 0, 0, 1.5, false, false, false, false)
    end

    -- Per-type disposal sound
    local sndMap = { incinerator = 'FIRE_CRACKLE', container = 'CARGO_THUD', ocean = 'WATER_SPLASH', junkyard = 'CARGO_THUD' }
    local snd    = sndMap[site.type] or 'CARGO_THUD'
    PlaySoundFromCoord(-1, snd, 'SCRIPTS/ATMS', site.coords.x, site.coords.y, site.coords.z, 0, true, 20.0, false)

    lib.notify({ title = '187 Cleaner', description = Locale['disposal_complete'], type = 'success' })

    removeBlip(activeBlips.disposal)
    activeBlips.disposal = nil

    TriggerServerEvent('187cleaner:disposalComplete', { contractId = contractData.contractId })
end

-- 4. NUI Callbacks
RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('evidenceDecision', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideEvidence' })

    TriggerServerEvent('187cleaner:evidenceDecision', {
        contractId = contractData and contractData.contractId,
        taskIndex  = data.id,
        decision   = data.decision,
    })

    if data.decision == 'destroy' then
        lib.notify({ title = '187 Cleaner', description = Locale['evidence_destroyed'], type = 'success' })
    else
        lib.notify({ title = '187 Cleaner', description = Locale['evidence_pocketed'], type = 'warning' })
    end

    pushSceneUpdate()
    if allSceneTasksDone() then startDisposalPhase() end
    cb('ok')
end)

RegisterNUICallback('witnessDecision', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideWitness' })
    witnessHandled = true

    TriggerServerEvent('187cleaner:witnessDecision', {
        contractId = contractData and contractData.contractId,
        decision   = data.decision,
    })

    if data.decision == 'pay' then
        lib.notify({ title = '187 Cleaner', description = Locale['witness_paid'], type = 'inform' })
    else
        lib.notify({ title = '187 Cleaner', description = Locale['witness_reported'], type = 'success' })
    end
    cb('ok')
end)

RegisterNUICallback('purchaseUpgrade', function(data, cb)
    TriggerServerEvent('187cleaner:purchaseUpgrade', { tier = data.tier })
    cb('ok')
end)

RegisterNUICallback('closeShop', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideShop' })
    cb('ok')
end)

RegisterNUICallback('closeStats', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideStats' })
    cb('ok')
end)

RegisterNUICallback('sellEvidence', function(data, cb)
    TriggerServerEvent('187cleaner:sellEvidence', { evidenceId = data.evidenceId })
    cb('ok')
end)

RegisterNUICallback('closeBroker', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideBroker' })
    cb('ok')
end)

-- 5. Net events
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    TriggerServerEvent('187cleaner:playerReady')
end)

RegisterNetEvent('187cleaner:alreadyRegistered', function(data)
    isRegistered  = true
    playerKitTier = data.kitTier or 0
    TriggerServerEvent('187cleaner:requestBrokerIndex')
    Citizen.CreateThread(spawnContactNpcs)
    log('Player already registered — kit tier: ' .. playerKitTier)
end)

RegisterNetEvent('187cleaner:registered', function(data)
    isRegistered  = true
    playerKitTier = data.kitTier or 0
    TriggerServerEvent('187cleaner:requestBrokerIndex')
    Citizen.CreateThread(spawnContactNpcs)
    lib.notify({ title = '187 Cleaner', description = Locale['register_success'], type = 'success' })
end)

RegisterNetEvent('187cleaner:brokerLocationUpdated', function(idx)
    activeBrokerIndex = idx
    lib.notify({ title = '187 Cleaner', description = Locale['broker_location_updated'], type = 'inform' })
end)

RegisterNetEvent('187cleaner:receiveContract', function(data)
    if isOnContract then
        lib.notify({ title = '187 Cleaner', description = Locale['already_on_contract'], type = 'error' })
        return
    end

    pendingContractId  = data.contractId
    contractAcceptKey  = true

    SendNUIMessage({ action = 'showContract', data = data })
    PlaySoundFrontend(-1, 'Notif_Generic_Slow', 'Phone_SoundSet_Trevor', true)

    -- 60-second key window
    Citizen.CreateThread(function()
        local deadline = GetGameTimer() + 60000
        while contractAcceptKey and GetGameTimer() < deadline do
            Citizen.Wait(100)
            if IsControlJustPressed(0, 246) then   -- Y key (INPUT_FRONTEND_Y)
                contractAcceptKey = false
                SendNUIMessage({ action = 'hideContract' })
                TriggerServerEvent('187cleaner:acceptContract', { contractId = pendingContractId })
                break
            end
            if IsControlJustPressed(0, 247) or IsControlJustPressed(0, 194) then  -- N / INPUT_CANCEL
                contractAcceptKey = false
                SendNUIMessage({ action = 'hideContract' })
                TriggerServerEvent('187cleaner:declineContract', { contractId = pendingContractId })
                lib.notify({ title = '187 Cleaner', description = Locale['contract_declined'], type = 'inform' })
                break
            end
        end
        if contractAcceptKey then
            contractAcceptKey = false
            SendNUIMessage({ action = 'hideContract' })
            TriggerServerEvent('187cleaner:declineContract', { contractId = pendingContractId })
        end
    end)
end)

RegisterNetEvent('187cleaner:contractStarted', function(data)
    isOnContract       = true
    contractData       = data
    contractPhase      = 'scene'
    completedTasks     = { bodies = {}, surfaces = {}, evidence = {} }
    witnessHandled     = false
    currentHeat        = 0
    contractStartTick  = GetGameTimer()
    contractTimeWindow = data.timeWindow

    activeBlips.scene  = addMapBlip(data.sceneCoords, 161, 1, Locale['scene_blip'], false)

    lib.notify({ title = '187 Cleaner', description = Locale['contract_accepted'], type = 'success' })
    PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)

RegisterNetEvent('187cleaner:heatUpdate', function(heat)
    currentHeat = heat
    pushSceneUpdate()

    if heat >= 90 and heat < Config.MaxHeat then
        lib.notify({ title = '187 Cleaner', description = Locale['heat_critical'], type = 'error' })
    elseif heat >= 80 and heat < 90 then
        lib.notify({ title = '187 Cleaner', description = Locale['heat_warning'], type = 'warning' })
    end
end)

RegisterNetEvent('187cleaner:policeSweep', function()
    lib.notify({ title = '187 Cleaner', description = Locale['heat_maxed'], type = 'error' })
    AnimpostfxPlay('Damage', 500, false)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)

    SetPlayerWantedLevel(PlayerId(), 1, false)
    SetPlayerWantedLevelNow(PlayerId(), false)

    Citizen.CreateThread(function()
        local deadline = GetGameTimer() + 45000
        while GetGameTimer() < deadline and isOnContract do
            Citizen.Wait(1000)
        end
        ClearPlayerWantedLevel(PlayerId())
    end)
end)

RegisterNetEvent('187cleaner:heatDropped', function(newHeat)
    currentHeat = newHeat
    pushSceneUpdate()
    lib.notify({ title = '187 Cleaner', description = Locale['heat_dropped'], type = 'inform' })
end)

RegisterNetEvent('187cleaner:witnessAppeared', function(sceneCoords)
    if witnessHandled then return end
    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showWitness',
        data   = { payoffCost = Config.WitnessPayoffCost },
    })
    lib.notify({ title = '187 Cleaner', description = Locale['witness_appeared'], type = 'warning' })
end)

RegisterNetEvent('187cleaner:witnessIgnorePenalty', function()
    lib.notify({ title = '187 Cleaner', description = Locale['witness_ignored_penalty'], type = 'error' })
    currentHeat = math.min(Config.MaxHeat, currentHeat + Config.WitnessIgnoreHeat)
    pushSceneUpdate()
end)

RegisterNetEvent('187cleaner:contractFailed', function()
    lib.notify({ title = '187 Cleaner', description = Locale['contract_failed'], type = 'error' })
    AnimpostfxPlay('DeathFailOut', 1000, false)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    cleanupContract()
end)

RegisterNetEvent('187cleaner:contractExpired', function(partialPayout)
    AnimpostfxPlay('Damage', 500, false)
    PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
    lib.notify({ title = '187 Cleaner', description = Locale['contract_expired'], type = 'warning' })
    if partialPayout and partialPayout > 0 then
        lib.notify({ title = '187 Cleaner', description = string.format(Locale['partial_payout'], partialPayout), type = 'inform' })
    end
    cleanupContract()
end)

RegisterNetEvent('187cleaner:payoutScreen', function(data)
    AnimpostfxPlay('HeistCelebPass', 0, false)
    PlaySoundFrontend(-1, 'CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET', true)

    cleanupContract()

    Citizen.CreateThread(function()
        Citizen.Wait(500)
        SendNUIMessage({ action = 'showPayout', data = data })
        Citizen.Wait(6000)
        SendNUIMessage({ action = 'hidePayout' })
        AnimpostfxStop('HeistCelebPass')
    end)
end)

RegisterNetEvent('187cleaner:upgradeSuccess', function(tier)
    playerKitTier = tier
    lib.notify({ title = '187 Cleaner', description = Locale['upgrade_purchased'], type = 'success' })
end)

RegisterNetEvent('187cleaner:upgradeFailed', function(reason)
    lib.notify({ title = '187 Cleaner', description = Locale[reason] or Locale['not_enough_money'], type = 'error' })
end)

RegisterNetEvent('187cleaner:repTierUnlocked', function(tier)
    lib.notify({ title = '187 Cleaner', description = string.format(Locale['rep_tier_unlocked'], tier), type = 'success' })
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
end)

RegisterNetEvent('187cleaner:uvEvidenceAck', function(data)
    if not data or not data.index then return end
    completedTasks.uvEvidence[data.index] = true
    lib.notify({ title = '187 Cleaner', description = Locale['uv_evidence_rewarded'], type = 'success' })
end)

RegisterNetEvent('187cleaner:betrayalDiscovered', function()
    lib.notify({ title = '187 Cleaner', description = Locale['betrayal_discovered'], type = 'error' })
    PlaySoundFrontend(-1, 'RACE_PLACED', 'HUD_AWARDS', true)
end)

RegisterNetEvent('187cleaner:repBlacklisted', function(tier)
    lib.notify({ title = '187 Cleaner', description = string.format(Locale['rep_blacklisted'], tier), type = 'error' })
end)

RegisterNetEvent('187cleaner:statsData', function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openStats', data = data })
end)

RegisterNetEvent('187cleaner:leaderboardData', function(lb)
    SendNUIMessage({ action = 'updateLeaderboard', data = lb })
end)

RegisterNetEvent('187cleaner:shopData', function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openShop', data = data })
end)

RegisterNetEvent('187cleaner:brokerData', function(data)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openBroker', data = data })
end)

RegisterNetEvent('187cleaner:evidenceSold', function(data)
    lib.notify({ title = '187 Cleaner', description = string.format(Locale['evidence_sold'], data.amount), type = 'success' })
    SendNUIMessage({ action = 'brokerItemSold', data = { id = data.id } })
end)

-- 6. Key mappings & commands
RegisterCommand('cleanerregister', function()
    TriggerServerEvent('187cleaner:register')
end, false)

RegisterCommand('cleanerstats', function()
    if not isRegistered then
        lib.notify({ title = '187 Cleaner', description = Locale['not_registered'], type = 'error' })
        return
    end
    TriggerServerEvent('187cleaner:requestStats')
end, false)

-- 7. Thread initialization

-- Scene zone detection + task interaction
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200)

        if not isOnContract or not contractData then
            Citizen.Wait(1000)
            goto skipScene
        end

        local ped    = cache.ped
        local pCoords = GetEntityCoords(ped)

        if contractPhase == 'scene' then
            isInScene = #(pCoords - contractData.sceneCoords) < 35.0

            for i, body in pairs(contractData.tasks.bodies) do
                if not completedTasks.bodies[i] and #(pCoords - body.coords) < 2.0 then
                    showHint(Locale['hint_bag_body'])
                    if IsControlJustPressed(0, 38) then bagBody(i) end
                end
            end

            for i, surface in pairs(contractData.tasks.surfaces) do
                if not completedTasks.surfaces[i] and #(pCoords - surface.coords) < 2.5 then
                    showHint(Locale['hint_clean_surface'])
                    if IsControlJustPressed(0, 38) then cleanSurface(i) end
                end
            end

            for i, ev in pairs(contractData.tasks.evidence) do
                if not completedTasks.evidence[i] and #(pCoords - ev.coords) < 2.0 then
                    showHint(Locale['hint_collect_evidence'])
                    if IsControlJustPressed(0, 38) then collectEvidence(i) end
                end
            end

            if playerKitTier >= 2 and contractData.tasks.uvEvidence then
                for i, uv in pairs(contractData.tasks.uvEvidence) do
                    if not completedTasks.uvEvidence[i] and #(pCoords - uv.coords) < 2.0 then
                        showHint(Locale['hint_collect_uv'])
                        if IsControlJustPressed(0, 38) then collectUvEvidence(i) end
                    end
                end
            end

        elseif contractPhase == 'disposal' then
            local site = contractData.disposalSite
            if #(pCoords - site.coords) < 3.0 then
                showHint(Locale['hint_dispose'])
                if IsControlJustPressed(0, 38) then doDisposal() end
            end
        end

        ::skipScene::
    end
end)

-- Contact + broker proximity
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(400)

        if not isRegistered or isOnContract then
            Citizen.Wait(1500)
            goto skipContact
        end

        local pCoords = GetEntityCoords(cache.ped)

        for _, loc in pairs(Config.ContactLocations) do
            if #(pCoords - loc) < 3.0 then
                showHint(Locale['hint_open_shop'])
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent('187cleaner:requestShop')
                end
            end
        end

        local brokerLoc = Config.BrokerLocations[activeBrokerIndex]
        if brokerLoc and #(pCoords - brokerLoc) < 3.0 then
            showHint(Locale['hint_sell_evidence'])
            if IsControlJustPressed(0, 38) then
                TriggerServerEvent('187cleaner:requestBroker')
            end
        end

        ::skipContact::
    end
end)

-- Scene panel open/close on zone entry
Citizen.CreateThread(function()
    local wasInScene = false
    while true do
        Citizen.Wait(600)

        if isOnContract and contractPhase == 'scene' and contractData then
            if isInScene and not wasInScene then
                wasInScene = true
                SendNUIMessage({
                    action = 'showScene',
                    data   = {
                        tier       = contractData.tier,
                        timeWindow = contractData.timeWindow,
                        tasks      = {
                            bodies   = contractData.tasks.bodies,
                            surfaces = contractData.tasks.surfaces,
                            evidence = contractData.tasks.evidence,
                        },
                    },
                })
            elseif not isInScene and wasInScene then
                wasInScene = false
                SendNUIMessage({ action = 'hideScene' })
            end
        else
            wasInScene = false
        end
    end
end)

-- Scene panel live update (timer + heat) every second
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if isOnContract and contractPhase == 'scene' then
            pushSceneUpdate()
        end
    end
end)

-- Marker drawing thread
Citizen.CreateThread(function()
    local DRAW_DIST = 60.0
    while true do
        Citizen.Wait(0)

        if not isOnContract or not contractData then
            Citizen.Wait(500)
            goto skipMarkers
        end

        local pCoords = GetEntityCoords(cache.ped)

        if contractPhase == 'scene' then
            for i, body in pairs(contractData.tasks.bodies) do
                if not completedTasks.bodies[i] and #(pCoords - body.coords) < DRAW_DIST then
                    DrawMarker(2, body.coords.x, body.coords.y, body.coords.z,
                        0.0,0.0,0.0, 0.0,0.0,0.0, 0.7,0.7,0.5,
                        200,30,30,160, false, false, 2, false, nil, nil, false)
                end
            end

            for i, surface in pairs(contractData.tasks.surfaces) do
                if not completedTasks.surfaces[i] and #(pCoords - surface.coords) < DRAW_DIST then
                    DrawMarker(1, surface.coords.x, surface.coords.y, surface.coords.z,
                        0.0,0.0,0.0, 0.0,0.0,0.0, 1.4,1.4,0.05,
                        180,0,0,130, false, false, 2, false, nil, nil, false)
                end
            end

            for i, ev in pairs(contractData.tasks.evidence) do
                if not completedTasks.evidence[i] and #(pCoords - ev.coords) < DRAW_DIST then
                    DrawMarker(2, ev.coords.x, ev.coords.y, ev.coords.z,
                        0.0,0.0,0.0, 0.0,0.0,0.0, 0.35,0.35,0.35,
                        255,210,0,190, false, false, 2, false, nil, nil, false)
                end
            end

            if playerKitTier >= 2 and contractData.tasks.uvEvidence then
                for i, uv in pairs(contractData.tasks.uvEvidence) do
                    if not completedTasks.uvEvidence[i] and #(pCoords - uv.coords) < DRAW_DIST then
                        DrawMarker(2, uv.coords.x, uv.coords.y, uv.coords.z,
                            0.0,0.0,0.0, 0.0,0.0,0.0, 0.25,0.25,0.25,
                            160,0,255,200, false, false, 2, false, nil, nil, false)
                    end
                end
            end

        elseif contractPhase == 'disposal' then
            local site = contractData.disposalSite
            if #(pCoords - site.coords) < DRAW_DIST then
                DrawMarker(2, site.coords.x, site.coords.y, site.coords.z,
                    0.0,0.0,0.0, 0.0,0.0,0.0, 1.2,1.2,1.0,
                    100,50,220,160, false, false, 2, false, nil, nil, false)
            end
        end

        -- Contact point markers (violet) and broker markers (amber)
        if isRegistered and not isOnContract then
            local pC = GetEntityCoords(cache.ped)
            for _, loc in pairs(Config.ContactLocations) do
                if #(pC - loc) < 40.0 then
                    DrawMarker(21, loc.x, loc.y, loc.z,
                        0.0,0.0,0.0, 0.0,0.0,0.0, 1.2,1.2,1.2,
                        139,92,246,110, false, false, 2, false, nil, nil, false)
                end
            end
            local bLoc = Config.BrokerLocations[activeBrokerIndex]
            if bLoc and #(pC - bLoc) < 40.0 then
                DrawMarker(21, bLoc.x, bLoc.y, bLoc.z,
                    0.0,0.0,0.0, 0.0,0.0,0.0, 1.2,1.2,1.2,
                    245,158,11,110, false, false, 2, false, nil, nil, false)
            end
        end

        ::skipMarkers::
    end
end)

-- 8. Resource lifecycle
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    isOnContract = false
    clearAllBlips()
    cleanupContactNpcs()
    SetNuiFocus(false, false)
    for _, action in pairs({ 'hideScene', 'hidePayout', 'hideBroker', 'hideShop', 'hideStats', 'hideContract', 'hideEvidence', 'hideWitness' }) do
        SendNUIMessage({ action = action })
    end
end)
