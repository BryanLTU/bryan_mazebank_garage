CreateGarageInstance = function(id, owner)
    self = {}

    self.id                 = id
    self.owner              = owner
    self.vehicles           = {}
    self.visitors           = {}
    self.requests           = {}
    self.vehiclesSpawned    = false

    self.AddVisitor = function(identifier)
        if self.IsVisitor(identifier) then return end
        
        table.insert(self.visitors, identifier)
    end

    self.RemoveVisitor = function(identifier)
        for k, v in ipairs(self.visitors) do
            if v == identifier then
                table.remove(self.visitors, k)
                break
            end
        end
    end

    self.GetVisitorCount = function()
        return #self.visitors - 1
    end

    self.GetVisitors = function()
        local data = {}

        for k, v in ipairs(self.visitors) do
            if v ~= owner then
                local playerId = _GetPlayerId(v)

                table.insert(data, {
                    title = _GetPlayerName(playerId),
                    description = _U('kick'),
                    serverEvent = 'bryan_mazebank_garage:server:kickFromGarage',
                    args = { source = playerId },
                })
            end
        end

        return data
    end

    self.IsVisitor = function(identifier)
        for k, v in ipairs(self.visitors) do
            if v == identifier then
                return true
            end
        end

        return false
    end

    self.DoesHaveVisitors = function()
        return #self.visitors ~= 0
    end

    self.AddRequest = function(identifier)
        table.insert(self.requests, identifier)
    end

    self.RemoveRequest = function(identifier)
        for k, v in ipairs(self.requests) do
            if v == identifier then
                table.remove(self.requests, k)
                break
            end
        end
    end

    self.GetRequestCount = function()
        return #self.requests
    end

    self.GetRequests  = function()
        local data = {}

        for k, v in ipairs(self.requests) do
            local playerId = _GetPlayerId(v)

            if playerId then
                table.insert(data, {
                    title = _GetPlayerName(playerId),
                    description = _U('let_inside'),
                    serverEvent = 'bryan_mazebank_garage:server:acceptRequest',
                    args = { source = playerId }
                })
            end
        end
        
        return data
    end

    self.DoesRequestExist = function(identifier)
        for k, v in ipairs(self.requests) do
            if v == identifier then
                return true
            end
        end

        return false
    end

    self.AddVehicle = function(plate, props, spot)
        MySQL.insert.await('INSERT INTO bryan_garage_vehicles (identifier, plate, properties, slot) VALUES (?, ?, ?, ?)', {
            self.owner, plate, json.encode(props), spot
        })
    end

    self.RemoveVehicle = function(plate)
        MySQL.update.await('DELETE FROM bryan_garage_vehicles WHERE identifier = ? AND plate = ?', {
            self.owner, plate
        })
    end

    self.SpawnVehicles = function()
        local result = MySQL.query.await('SELECT plate, properties, slot FROM bryan_garage_vehicles WHERE identifier = ?', { self.owner })

        if result then
            for k, v in ipairs(result) do
                local plate, props, slot, coords = v.plate, json.decode(v.properties), v.slot, Config.Locations.VehicleLocations[v.slot]

                local vehicle = CreateVehicle(props.model, coords.x, coords.y, coords.z, coords.w, true, false)
                while not DoesEntityExist(vehicle) do Citizen.Wait(10) end

                SetVehicleDoorsLocked(vehicle, 2)
                SetEntityRoutingBucket(vehicle, self.id)
                TriggerClientEvent('bryan_mazebank_garage:client:applyVehicleProperties', _GetPlayerId(self.owner), NetworkGetNetworkIdFromEntity(vehicle), props)

                table.insert(self.vehicles, {
                    plate = v.plate,
                    props = props,
                    slot = slot,
                    entity = vehicle,
                })
            end
        end

        self.vehiclesSpawned = true
    end

    self.DeleteVehicles = function()
        for k, v in ipairs(self.vehicles) do
            if v.entity then
                DeleteEntity(v.entity)
            end
        end

        self.vehicles = {}
        self.vehiclesSpawned = false
    end

    self.AreVehiclesSpawned = function()
        return self.vehiclesSpawned
    end

    self.GetVehicles = function()
        local vehicles = {}
        local result = MySQL.query.await('SELECT plate, properties, slot FROM bryan_garage_vehicles WHERE identifier = ?', { self.owner })

        if result then
            for k, v in ipairs(result) do
                table.insert(vehicles, {
                    plate = v.plate,
                    props = json.decode(v.properties),
                    slot = v.slot
                })
            end
        end

        return vehicles
    end

    self.GetVehicle = function(plate)
        for k, v in ipairs(self.vehicles) do
            if v.plate == plate then
                return v
            end
        end

        return
    end

    self.GetVehicleEntities = function()
        local data = {}

        for k, v in ipairs(self.vehicles) do
            if v.entity then
                table.insert(data, NetworkGetNetworkIdFromEntity(v.entity))
            end
        end

        return data
    end

    self.UpdateVehicleSlot = function(plate, slot)
        for k, v in ipairs(self.vehicles) do
            if v.plate == plate then
                self.vehicles[k].slot = slot
                self.UpdateVehiclePosition(plate)
                break
            end
        end
    end

    self.UpdateVehiclePosition = function(plate)
        for k, v in ipairs(self.vehicles) do
            if v.plate == plate then
                local coords = Config.Locations.VehicleLocations[v.slot]

                SetEntityCoords(v.entity, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, false)
                SetEntityHeading(v.entity, coords.w)
                
                break
            end
        end
    end

    self.IsOwner = function(identifier)
        return self.owner == identifier
    end

    return self
end