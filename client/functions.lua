ESX = exports['es_extended']:getSharedObject()

_Notification = function(msg)
    ESX.ShowNotification(msg)
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