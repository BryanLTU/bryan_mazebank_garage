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