ESX = exports['es_extended']:getSharedObject()

_Notification = function(msg)
    lib.notify({
        title = _U('menu_title'),
        description = msg
    })
end

_SetVehicleProperties = function(vehicle, props)
    ESX.Game.SetVehicleProperties(vehicle, props)
end

_GetVehicleProperties = function(vehicle)
    return ESX.Game.GetVehicleProperties(vehicle)
end

_GetVehicleModelName = function(model)
    return GetDisplayNameFromVehicleModel(model)
end

_DeleteVehicle = function(vehicle)
    ESX.Game.DeleteVehicle(vehicle)
end

_SpawnLocalVehicle = function(model, coords, heading)
    local vehicle = nil

    ESX.Game.SpawnLocalVehicle(model, coords, heading, function(callback_vehicle) vehicle = callback end)
    while vehicle == nil do Citizen.Wait(10) end

    return vehicle
end

_SpawnVehicle = function(model, coords, heading)
    local vehicle = nil

    ESX.Game.SpawnVehicle(model, coords, heading, function(callback_vehicle) vehicle = callback end)
    while vehicle == nil do Citizen.Wait(10) end

    return vehicle
end

_ShowHelpNotification = function(msg)
    ESX.ShowHelpNotification(msg)
end