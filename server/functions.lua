ESX = exports['es_extended']:getSharedObject()

_Notification = function(source, msg)
    TriggerClientEvent('ox_lib:notify', source, {
        title = _U('menu_title'),
        description = msg
    })
end

_GetPlayerFromId = function(source)
    return ESX.GetPlayerFromId(source)
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

-- TODO On Player exit if inside garage, set last coords to outside