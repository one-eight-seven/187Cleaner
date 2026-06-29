if Config.Framework ~= 'standalone' then return end

local playerMoney = {}

Framework = {}

function Framework.getPlayer(src)
    return { source = src }
end

function Framework.getMoney(src)
    return playerMoney[src] or 0
end

function Framework.addMoney(src, amount)
    playerMoney[src] = (playerMoney[src] or 0) + amount
end

function Framework.removeMoney(src, amount)
    local current = playerMoney[src] or 0
    playerMoney[src] = math.max(0, current - amount)
end

function Framework.getJob(src)
    return 'civilian'
end

function Framework.notify(src, msg, ntype)
    TriggerClientEvent('187:notify', src, msg, ntype)
end

AddEventHandler('playerDropped', function()
    playerMoney[source] = nil
end)
