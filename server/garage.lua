CreateGarageInstance = function(id, owner)
    self = {}

    self.id                 = id
    self.owner              = owner
    self.vehicles           = {}
    self.visitors           = {}
    self.requests           = {}
    self.vehiclesSpawned    = false

    self.AddVisitor = function(identifier)
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

            table.insert(data, {
                title = _GetPlayerName(playerId),
                description = _U('let_inside'),
                serverEvent = 'bryan_mazebank_garage:server:acceptRequest',
                args = { source = playerId }
            })
        end
        
        return data
    end

    self.GetRequests = function()
        return self.requests
    end

    self.SpawnVehicles = function()
        local result = MySQL.query.await('SELECT plate, properties, slot FROM bryan_garage_vehicles WHERE identifier = ?', { self.owner })

        if result then
            for k, v in ipairs(result) do
                local plate, props, slot, coords = v.plate, json.decode(v.properties), v.slot, Config.Locations.VehicleLocations[v.slot]

                local vehicle = CreateVehicle(props.model, coords.x, coords.y, coords.z, coords.w, true, false)
                while not DoesEntityExist(vehicle) do Citizen.Wait(10) end

                SetEntityRoutingBucket(vehicle, self.id)

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

    self.UpdateVehicleSlot = function(plate, slot)
        for k, v in ipairs(self.vehicles) do
            if v.plate == plate then
                self.vehicles[k].slot = slot
                break
            end
        end
    end

    self.UpdateVehicleEntity = function(plate)
        for k, v in ipairs(self.vehicles) do

        end
    end

    self.UpdateVisitorsVehicles = function()
        for k, v in ipairs(self.visitors) do
            local playerId = _GetPlayerId(v)

            TriggerClientEvent('bryan_mazebank_garage:client:forceUpdateVehicles', playerId)
        end
    end

    self.IsOwner = function(identifier)
        return self.owner == identifier
    end

    return self
end