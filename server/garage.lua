CreateGarageInstance = function(id, owner)
    self = {}

    self.id         = id
    self.owner      = owner
    self.vehicles   = nil
    self.visitors   = {}
    self.requests   = {}

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
    
    self.SetVehicles = function(vehicles)
        self.vehicles = vehicles
    end

    self.GetVehicles = function()
        return self.vehicles
    end

    self.UpdateVehicleSlot = function(plate, slot)
        for k, v in ipairs(self.vehicles) do
            if v.plate == plate then
                self.vehicles[k].slot = slot
                break
            end
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