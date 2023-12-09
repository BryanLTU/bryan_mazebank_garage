local Garages = {}

lib.callback.register('bryan_mazebank_garage:server:doesOwnGarage', function(source)
    return IsPlayerGarageOwner(source)
end)

lib.callback.register('bryan_mazebank_garage:server:doesOwnVehicle', function(source, plate)
    local result = MySQL.scalar.await('SELECT owner FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, _GetPlayerIdentifier(source) })

    return result ~= nil
end)

lib.callback.register('bryan_mazebank_garage:server:purchaseGarage', function(source)
    if _GetPlayerMoney(source) < Config.Price then
        _Notification(source, _U('notification_buy_not_enough_money'))
        return false
    end

    local result = MySQL.insert.await('INSERT INTO bryan_garage_owners (identifier) VALUES (?)', { _GetPlayerIdentifier(source) })
    _RemovePlayerMoney(source, Config.Price)

    table.insert(Garages, CreateGarageInstance(source, _GetPlayerIdentifier(source)))

    return true
end)

lib.callback.register('bryan_mazebank_garage:server:getGarageVehicles', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    if not garage then return {} end

    return garage.vehicles
end)

lib.callback.register('bryan_mazebank_garage:server:getGarageVehicle', function(source, plate)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))
    
    return garage.GetVehicle(plate) 
end)

lib.callback.register('bryan_mazebank_garage:server:getGarageVehicleEntities', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    if not garage then return {} end

    return garage.GetVehicleEntities()
end)

lib.callback.register('bryan_mazebank_garage:server:isGarageOwner', function(source)
    local identifier = _GetPlayerIdentifier(source)
    local garage = GetGaragePlayerIsIn(identifier)

    if not garage then return false end

    return garage.owner == identifier
end)

lib.callback.register('bryan_mazebank_garage:server:getVisitorCount', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    return garage.GetVisitorCount()
end)

lib.callback.register('bryan_mazebank_garage:server:getVisitors', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    return garage.GetVisitors()
end)

lib.callback.register('bryan_mazebank_garage:server:getRequestCount', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    return garage.GetRequestCount()
end)

lib.callback.register('bryan_mazebank_garage:server:getRequests', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    return garage.GetRequests()
end)

lib.callback.register('bryan_mazebank_garage:server:getGarageId', function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    if garage then return garage.id end
    
    return nil
end)

RegisterNetEvent('bryan_mazebank_garage:server:registerGarage', function()
    local _source = source
    local identifier = _GetPlayerIdentifier(_source)
    
    local result = MySQL.query.await('SELECT identifier FROM bryan_garage_owners WHERE identifier = ?', { identifier })

    if result and result[1] then
        table.insert(Garages, CreateGarageInstance(_source, identifier))
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:requestToEnter', function(id)
    local garage = GetGarageById(id)

    if not garage then
        _Notification(source, _U('notification_invite_instance_does_not_exist'))
        return
    end

    if _IsPlayerOnline(source) and _IsPlayerOnline(id) then
        if garage.DoesRequestExist(_GetPlayerIdentifier(id)) then
            _Notification(source, _U('notification_request_already_exists'))
            return
        end

        garage.AddRequest(_GetPlayerIdentifier(id))

        _Notification(source, _U('notification_invite_requested', id))
        _Notification(id, _U('notification_invite_request'))
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:enterGarage', function(visitId)
    local _source = source

    EnterGarage(_source, visitId)
end)

RegisterNetEvent('bryan_mazebank_garage:server:exitGarage', function(door)
    ExitGarage(source, door)
end)

RegisterNetEvent('bryan_mazebank_garage:server:updateVehiclePosition', function(data1, data2)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    garage.UpdateVehicleSlot(data1.plate, data1.slot)
    MySQL.update.await('UPDATE bryan_garage_vehicles SET slot = ? WHERE plate = ?', { data1.slot, data1.plate })

    if data2 then
        garage.UpdateVehicleSlot(data2.plate, data2.slot)
        MySQL.update.await('UPDATE bryan_garage_vehicles SET slot = ? WHERE plate = ?', { data2.slot, data2.plate })
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:acceptRequest', function(data)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))
    
    garage.RemoveRequest(_GetPlayerIdentifier(data.source))
    EnterGarage(data.source, garage.id)
end)

RegisterNetEvent('bryan_mazebank_garage:server:refreshVehicles', function()
    local _source = source
    local garage = GetGarageByOwner(_GetPlayerIdentifier(_source))

    if garage then
        garage.DeleteVehicles()
        garage.SpawnVehicles()
    end
end)

EnterGarage = function(source, visitId)
    local identifier = _GetPlayerIdentifier(source)
    local garage = visitId and GetGarageById(visitId) or GetGarageByOwner(identifier)

    local ped = GetPlayerPed(source)
    if #(GetEntityCoords(ped) - vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z)) > 10.0 and
        #(GetEntityCoords(ped) - vector3(Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z)) > 10.0 then
        _Notification(source, _U('notification_enter_too_far_away'))
        return
    end

    if not garage then
        _Notification(source, _('notification_fault'))
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not visitId and vehicle and vehicle ~= 0 and not EnterVehicle(source, vehicle, garage) then
        return
    else
        garage.AddVisitor(identifier)
        SetEntityCoords(ped, Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z)

        SetPlayerRoutingBucket(source, garage.id)
        ClearPlayerRequestsToGarages(identifier)
    end

    TriggerClientEvent('bryan_mazebank_garage:client:toggleIsInGarage', source, true)

    if not garage.AreVehiclesSpawned() then
        garage.SpawnVehicles()
    end

    if garage.IsOwner(identifier) then
        TriggerClientEvent('bryan_mazebank_garage:client:ownerThreads', source)
    end
end

EnterVehicle = function(source, vehicle, garage)
    local ped = GetPlayerPed(source)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if GetFreeSpotInGarage(source) == false then
        _Notification(source, _U('notification_garage_full'))
        return false
    end

    if vehicle and #(GetEntityCoords(ped) - vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z)) > 10.0 then
        _Notification(source, _U('notification_enter_with_vehicle_only_garage'))
        return false
    end

    local passangers = { {id = source, seat = -1} }
    for i = 0, 6 do
        local passanger = NetworkGetEntityOwner(GetPedInVehicleSeat(vehicle, i))

        if passanger ~= 0 then
            TriggerClientEvent('bryan_mazebank_garage:client:fadeout', passanger, true)
            table.insert(passangers, { id = passanger, seat = i })
        end

        Citizen.Wait(10)
    end

    SetEntityRoutingBucket(vehicle, garage.id)

    for k, v in ipairs(passangers) do
        garage.AddVisitor(_GetPlayerIdentifier(v.id))

        SetPlayerRoutingBucket(v.id, garage.id)
        TaskWarpPedIntoVehicle(GetPlayerPed(v.id), vehicle, v.seat)
        ClearPlayerRequestsToGarages(_GetPlayerIdentifier(v.id))

        lib.callback.await('bryan_mazebank_garage:client:requestModel', v.id)
        TriggerClientEvent('bryan_mazebank_garage:client:ActivateElevatorCamera', v.id)

        Citizen.Wait(10)
    end

    SpawnElevator(source, vehicle, passangers, garage.id)

    local props = lib.callback.await('bryan_mazebank_garage:client:getVehicleProps', source, NetworkGetNetworkIdFromEntity(vehicle))
    garage.AddVehicle(props.plate, props, GetFreeSpotInGarage(source))
    _UpdateOwnedVehicleTable(source, props.plate, true)

    DeleteEntity(vehicle)

    -- TODO Add exiting vehicle animation
    for k, v in ipairs(passangers) do
        SetEntityCoords(GetPlayerPed(v.id), Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z)
        TriggerClientEvent('bryan_mazebank_garage:client:fadeout', v.id, false)
    end

    return true
end

SpawnElevator = function(source, vehicle, passangers, id)
    local pos = vector3(Config.Locations.VehicleElevator.x, Config.Locations.VehicleElevator.y, Config.Locations.VehicleElevator.z)
    local object = CreateObject(`imp_prop_int_garage_mirror01`, pos.x, pos.y, pos.z - 3.0, true, false, false)
    
    while not DoesEntityExist(object) do Wait(10) end
    
    SetEntityCoords(vehicle, pos.x, pos.y, pos.z - 2.8, 0.0, 0.0, 0.0, false)
    FreezeEntityPosition(vehicle, true)
    lib.callback.await('bryan_mazebank_garage:client:attachVehicleToElevator', source, NetworkGetNetworkIdFromEntity(vehicle), NetworkGetNetworkIdFromEntity(object))

    for k, v in ipairs(passangers) do TriggerClientEvent('bryan_mazebank_garage:client:fadeout', v.id, false, 300) end

    while #(GetEntityCoords(object) - pos) > 0.5 do
        SetEntityCoords(object, GetEntityCoords(object) + vector3(0.0, 0.0, 0.01))
        SetEntityHeading(object, GetEntityHeading(object) + 0.3)
        Wait(10)
    end

    for k, v in ipairs(passangers) do
        TriggerClientEvent('bryan_mazebank_garage:client:fadeout', v.id, true, 100)
        Wait(100)
        TriggerClientEvent('bryan_mazebank_garage:client:DisableElevatorCamera', v.id)
    end

    DeleteEntity(object)
end

ExitGarage = function(source, door)
    local identifier = _GetPlayerIdentifier(source)
    local garage = GetGaragePlayerIsIn(identifier)

    if not garage then
        if #(GetEntityCoords(GetPlayerPed(source)) - vector3(Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z)) <= 5.0 then
            local exitLocation = door == 'elevator' and vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z) or vector3(Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z)
            
            SetPlayerRoutingBucket(source, 0)
            SetEntityCoords(GetPlayerPed(source), exitLocation.x, exitLocation.y, exitLocation.z, 0.0, 0.0, 0.0, false)
        else
            _Notification(source, _('notification_fault'))
        end

        return
    end

    if garage.IsOwner(identifier) and garage.GetVisitorCount() > 0 then
        local kickVisitors = lib.callback.await('bryan_mazebank_garage:client:kickVisitorsOnExitDialog', source)

        if not kickVisitors then
            return
        end

        ForceKickVisitors(source)
    end

    TriggerClientEvent('bryan_mazebank_garage:client:fadeout', source, true, 100)

    garage.RemoveVisitor(identifier)

    SetPlayerRoutingBucket(source, 0)

    local ped = GetPlayerPed(source)

    if door and door == 'elevator' then
        SetEntityCoords(ped, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, 0.0, 0.0, 0.0, false)

        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 then
            local plate = GetVehicleNumberPlateText(vehicle)
            local vehicleData = garage.GetVehicle(plate)
            local localVehicle = CreateVehicle(vehicleData.props.model, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, Config.Locations.EnterVh.w, true, false)

            while not DoesEntityExist(localVehicle) do Citizen.Wait(10) end

            TriggerClientEvent('bryan_mazebank_garage:client:applyVehicleProperties', source, NetworkGetNetworkIdFromEntity(localVehicle), vehicleData.props)

            TaskWarpPedIntoVehicle(ped, localVehicle, -1)
        end
    else
        -- TODO Add garage Exit animation
        SetEntityCoords(ped, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, 0.0, 0.0, 0.0, false)
    end

    if not garage.DoesHaveVisitors() then garage.DeleteVehicles() end

    TriggerClientEvent('bryan_mazebank_garage:client:toggleIsInGarage', source, false)
    TriggerClientEvent('bryan_mazebank_garage:client:fadeout', source, false)
end

IsPlayerGarageOwner = function(source)
    local identifier = _GetPlayerIdentifier(source)

    for k, v in ipairs(Garages) do
        if v.IsOwner(identifier) then
            return true
        end
    end

    return false
end

GetGaragePlayerIsIn = function(identifier)
    for k, v in ipairs(Garages) do
        if v.IsVisitor(identifier) then
            return v
        end
    end

    return nil
end

ClearPlayerRequestsToGarages = function(identifier)
    for k, v in ipairs(Garages) do
        v.RemoveRequest(identifier)
    end
end

GetGarageById = function(id)
    for k, v in ipairs(Garages) do
        if v.id == id then
            return v
        end
    end

    return nil
end

GetGarageByOwner = function(identifier)
    for k, v in ipairs(Garages) do
        if v.IsOwner(identifier) then
            return v
        end
    end

    return nil
end

GetFreeSpotInGarage = function(id)
    local identifier = _GetPlayerIdentifier(id)
    local result = MySQL.query.await('SELECT slot FROM bryan_garage_vehicles WHERE identifier = ?', { identifier })

    if result then
        for i = 1, 15 do
            if not IsGarageSpotOccupied(result, i) then
                return i
            end
        end
    end

    return false
end

IsGarageSpotOccupied = function(occupiedSlots, slot)
    for k, v in ipairs(occupiedSlots) do
        if v.slot == slot then
            return true
        end
    end

    return false
end

OnPlayerLeave = function(identifier, playerId)
    local garage = GetGaragePlayerIsIn(identifier)

    if garage then
        ForceKickVisitors(playerId)
        garage.RemoveVisitor(identifier)
        SetEntityCoords(GetPlayerPed(playerId), Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, false, false, false, false)
    end
end

ForceKickVisitors = function(source)
    local garage = GetGaragePlayerIsIn(_GetPlayerIdentifier(source))

    if garage then
        for k, v in ipairs(garage.GetVisitors()) do
            ExitGarage(v.args.source)
        end
    end
end

-- TODO change "slot" to "spot"