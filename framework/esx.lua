if Config.Framework ~= 'esx' then return end

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

Framework = {}

function Framework.getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

function Framework.getMoney(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end
    return xPlayer.getMoney()
end

function Framework.addMoney(src, amount)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then xPlayer.addMoney(amount) end
end

function Framework.removeMoney(src, amount)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then xPlayer.removeMoney(amount) end
end

function Framework.getJob(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 'civilian' end
    return xPlayer.job.name
end

function Framework.notify(src, msg, ntype)
    TriggerClientEvent('esx:showNotification', src, msg)
end
