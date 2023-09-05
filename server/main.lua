local Garages = {}

MySQL.ready(function()
    local result = MySQL.query.await('SELECT identifier FROM bryan_garage_owners')

    if result then
        for k, v in ipairs(result) do
            table.insert(Garages, CreateGarageInstance(k, v.identifier))
        end
    end
end)

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

    return true
end)

lib.callback.register('bryan_mazebank_garage:server:doesGarageHaveEmptySpots', function(source)
    return GetFreeSpotInGarage(source) ~= false
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

RegisterNetEvent('bryan_mazebank_garage:server:requestToEnter', function(id)
    if not DoesGrarageInstanceExist(id) then
        _Notification(source, _U('notification_invite_instance_does_not_exist'))
        return false
    end

    local xPlayer = _GetPlayerFromId(source)
    local xTarget = _GetPlayerFromId(id)

    if xPlayer and xTarget then
        if not requests[id] then requests[id] = {} end

        table.insert(requests[id], source)

        _Notification(source, _U('notification_invite_requested', id))
        _Notification(id, _U('notification_invite_request'))
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:enterVehicle', function(plate, props)
    local _source = source
    local freeSpot = GetFreeSpotInGarage(_source)
    
    if freeSpot then
        MySQL.insert.await('INSERT INTO bryan_garage_vehicles (identifier, plate, properties, slot) VALUES (?, ?, ?, ?)', {
            _GetPlayerIdentifier(_source), plate, json.encode(props), freeSpot
        })
        
        _UpdateOwnedVehicleTable(_source, plate, true)
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:exitVehicle', function(plate)
    MySQL.update.await('DELETE FROM bryan_garage_vehicles WHERE plate = ?', { plate })

    _UpdateOwnedVehicleTable(source, plate, false)
end)

RegisterNetEvent('bryan_mazebank_garage:server:enterGarage', function(visitId)
    local _source = source
    local identifier = _GetPlayerIdentifier(_source)
    local garage = visitId and GetGarageById(visitId) or GetGarageByOwner(identifier)

    if garage then
        garage.AddVisitor(identifier)

        SetPlayerRoutingBucket(_source, garage.id)
        ClearPlayerRequestsToGarages(identifier)

        if not garage.AreVehiclesSpawned() then
            garage.SpawnVehicles()
        end

        if garage.IsOwner(identifier) then
            TriggerClientEvent('bryan_mazebank_garage:client:ownerThreads', _source)
        end

        local vehicle = GetVehiclePedIsIn(GetPlayerPed(_source), false)
        local netId = NetworkGetNetworkIdFromEntity(vehicle)

        if vehicle then
            SetEntityRoutingBucket(vehicle, garage.id)
            
            for i = 0, 6 do
                local passanger = NetworkGetEntityOwner(GetPedInVehicleSeat(vehicle, i)))

                SetEntityRoutingBucket(passanger, garage.id)

                if passanger ~= 0 then
                    TriggerClientEvent('bryan_mazebank_garage:client:enterGaragePassanger', passanger, netId, i)
                end
            end
        end
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:exitGarage', function()
    local identifier = _GetPlayerIdentifier(source)
    local garage = GetGaragePlayerIsIn(identifier)

    if garage then
        garage.RemoveVisitor(identifier)
        if not self.DoesHaveVisitors() then
            garage.DeleteVehicles()
        end

        SetPlayerRoutingBucket(source, 0)
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:kickFromGarage', function(data)
    TriggerClientEvent('bryan_mazebank_garage:client:exitGarage', data.source)
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

RegisterNetEvent('bryan_mazebank_garage:server:forceExitVisitors', function()
    ForceKickVisitors(source)
end)

RegisterNetEvent('bryan_mazebank_garage:server:acceptRequest', function(data)
    local garage = GetGaragePlayerIsIn(source)

    TriggerClientEvent('bryan_mazebank_garage:client:visitGarage', data.source, garage.id)
end)

RegisterNetEvent('bryan_mazebank_garage:server:refreshVehicles', function()
    local _source = source
    local garage = GetGarageByOwner(_GetPlayerIdentifier(_source))

    if garage then
        garage.DeleteVehicles()
        garage.SpawnVehicles()
    end
end)

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
    local result = MySQL.query.await('SELECT floor, slot FROM bryan_garage_vehicles WHERE identifier = ?', { identifier })

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

IsSpotFree = function(floor, slot, table)
    for k, v in pairs(table) do
        if v.floor == floor and v.slot == slot then
            return false
        end
    end

    return true
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
            TriggerClientEvent('bryan_mazebank_garage:client:exitGarage', v)
        end
    end
end

-- TODO change "slot" to "spot"