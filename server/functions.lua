ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('esx:playerDropped', function(playerId, reason)
    OnPlayerLeave(_GetPlayerIdentifier(playerId), playerId)
end)

_Notification = function(source, msg)
    TriggerClientEvent('ox_lib:notify', source, {
        title = locale('mazebank_garage'),
        description = msg
    })
end

_IsPlayerOnline = function(source)
    return GetPlayerName(source) ~= nil
end

_GetPlayerIdentifier = function(source)
    return ESX.GetPlayerFromId(source).getIdentifier()
end

_GetPlayerId = function(identifier)
    return ESX.GetPlayerFromIdentifier(identifier).source
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

_UpdateOwnedVehicleTable = function(source, plate, stored)
    if Config.CheckOwnership then
        MySQL.update.await('UPDATE owned_vehicles SET stored = ?, garage_name = "Maze Bank" WHERE owner = ? AND plate = ?', {
            stored, _GetPlayerIdentifier(source), plate
        })
    end
end