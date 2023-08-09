ESX = exports['es_extended']:getSharedObject()

_Notification = function(source, msg)
    TriggerClientEvent('esx:showNotification', source, msg)
end

_GetPlayerFromId = function(source)
    return ESX.GetPlayerFromId(source)
end

_GetPlayerIdentifier = function(source)
    return ESX.GetPlayerFromId(source).getIdentifier()
end

_GetPlayerName = function(source)
    return ESX.GetPlayerFromId(source).getName()
end

_GetPlayerMoney = function(source)
    return ESX.GetPlayerFromId(source).getMoney()
end

_RemovePlayerMoney = function(source, amount)
    ESX.GetPlayerFromId(source).removeMoney(amount)
end

-- TODO On Player exit if inside garage, set last coords to outside