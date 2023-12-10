FrameworkObj = nil

if Config.Framework == 'esx' then
    FrameworkObj = exports['es_extended']:getSharedObject()
    
    RegisterNetEvent('esx:playerDropped', function(playerId)
        OnPlayerLeave(_GetPlayerIdentifier(playerId), playerId)
    end)
elseif Config.Framework == 'qbcore' then
    FrameworkObj = exports['qb-core']:GetCoreObject()

    RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(playerId)
        OnPlayerLeave(_GetPlayerIdentifier(playerId), playerId)
    end)
end


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
    if Config.Framework == 'esx' then
        return FrameworkObj.GetPlayerFromId(source).getIdentifier()
    elseif Config.Framework == 'qbcore' then
        return FrameworkObj.Functions.GetIdentifier(source, 'license')
    end
end

_GetPlayerId = function(identifier)
    if Config.Framework == 'esx' then
        return FrameworkObj.GetPlayerFromIdentifier(identifier).source
    elseif Config.Framework == 'qbcore' then
        return FrameworkObj.Player.GetPlayerByLicense(identifier).source
    end
end

_GetPlayerName = function(source)
    return GetPlayerName(source)
end

_GetPlayerMoney = function(source)
    if Config.Framework == 'esx' then
        return FrameworkObj.GetPlayerFromId(source).getMoney()
    elseif Config.Framework == 'qbcore' then
        return FrameworkObj.Functions.GetPlayer(source).Functions.GetMoney('cash')
    end
end

_RemovePlayerMoney = function(source, amount)
    if Config.Framework == 'esx' then
        FrameworkObj.GetPlayerFromId(source).removeMoney(amount)
    elseif Config.Framework == 'qbcore' then
        FrameworkObj.Functions.GetPlayer(source).Functions.RemoveMoney('cash', amount)
    end
end

_UpdateOwnedVehicleTable = function(plate, stored)
    if Config.CheckOwnership then
        if Config.Framework == 'esx' then
            MySQL.update.await('UPDATE owned_vehicles SET stored = ?, garage_name = ? WHERE AND plate = ?', {
                stored, locale(mazebank_garage), plate
            })
        elseif Config.Framework == 'qbcore' then
            MySQL.update.await('UPDATE player_vehicles SET state = ?, garage = ? WHERE plate = ?', {
                stored, locale(mazebank_garage), plate
            })
        end
    end
end

_IsVehiclePlayerOwned = function(source, plate)
    if Config.Framework == 'esx' then
        local result = MySQL.query.await('SELECT identifier FROM owned_vehicles WHERE identifier = ?', {
            _GetPlayerIdentifier(source)
        })

        return #result > 0
    elseif Config.Framework == 'qbcore' then
        local result = MySQL.query.await('SELECT citizenid FROM player_vehicles WHERE citizenid = ?', {
            _GetPlayerIdentifier(source)
        })

        return #result > 0
    end
end