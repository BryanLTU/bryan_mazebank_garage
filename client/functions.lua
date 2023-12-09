FrameworkObj = nil

if Config.Framework == 'esx' then
    FrameworkObj = exports['es_extended']:getSharedObject()
    
    RegisterNetEvent('esx:playerLoaded', function()
        StartScript()
    end)
elseif Config.Framework == 'qbcore' then
    FrameworkObj = exports['qb-core']:GetCoreObject()
    
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        StartScript()
    end)
end

_Notification = function(msg)
    lib.notify({
        title = locale('mazebank_garage'),
        description = msg
    })
end

_SetVehicleProperties = function(vehicle, props)
    if Config.Framework == 'esx' then
        FrameworkObj.Game.SetVehicleProperties(vehicle, props)
    elseif Config.Framework == 'qbcore' then
        FrameworkObj.Functions.SetVehicleProperties(vehicle, props)
    end
end

_GetVehicleProperties = function(vehicle)
    if Config.Framework == 'esx' then
        return FrameworkObj.Game.GetVehicleProperties(vehicle)
    elseif Config.Framework == 'qbcore' then
        return FrameworkObj.Functions.GetVehicleProperties(vehicle)
    end
end

_GetVehicleModelName = function(model)
    return GetDisplayNameFromVehicleModel(model)
end