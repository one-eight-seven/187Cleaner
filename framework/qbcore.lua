if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

Framework = {}

function Framework.getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

function Framework.getMoney(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return 0 end
    return player.PlayerData.money['cash']
end

function Framework.addMoney(src, amount)
    local player = QBCore.Functions.GetPlayer(src)
    if player then player.Functions.AddMoney('cash', amount) end
end

function Framework.removeMoney(src, amount)
    local player = QBCore.Functions.GetPlayer(src)
    if player then player.Functions.RemoveMoney('cash', amount) end
end

function Framework.getJob(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return 'civilian' end
    return player.PlayerData.job.name
end

function Framework.notify(src, msg, ntype)
    TriggerClientEvent('QBCore:Notify', src, msg, ntype or 'primary')
end
