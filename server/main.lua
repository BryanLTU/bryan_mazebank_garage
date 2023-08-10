local garageInstances, playerInstances, requests = {}, {}, {}

RegisterNetEvent('bryan_mazebank_garage:updatePlayerVisibility', function(value, identifier, floor)
    local _source = source

    if value then

        if not playerInstances[identifier] then SetUpPlayerInstance(identifier) end
        RemovePlayerInstance(_source, identifier)
        table.insert(playerInstances[identifier][floor], _source)

        local xPlayers = ESX.GetPlayers()

        for k, v in pairs(playerInstances[identifier]) do
            for j, c in pairs(v) do
                TriggerClientEvent('bryan_mazebank_garage:setVisibilityLocaly', c, playerInstances[identifier][k])
            end
        end

        TriggerClientEvent('bryan_mazebank_garage:clearRequested', _source)
        TriggerClientEvent('bryan_mazebank_garage:removeRequest', -1, ESX.GetPlayerFromId(_source).getIdentifier())

    else

        identifier = GetInWhatGarage(_source)
        if identifier then
            RemovePlayerInstance(_source, identifier)

            if GetVisitorCount(identifier) < 0 then
                DeleteGarage(identifier)
            end

            TriggerClientEvent('bryan_mazebank_garage:setVisibilityLocaly', _source, {})
        end

    end
end)

RegisterNetEvent('bryan_mazebank_garage:forceExit', function(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)

    for k, v in pairs(playerInstances[identifier]) do
        for j, c in pairs(v) do
            if c ~= xPlayer.source then
                TriggerClientEvent('bryan_mazebank_garage:exitGarage', c)
            end
        end
    end
end)

RegisterNetEvent('bryan_mazebank_garage:forceExitSource', function(identifier)
    local xTarget = ESX.GetPlayerFromIdentifier(identifier)
    TriggerClientEvent('bryan_mazebank_garage:exitGarage', xTarget.source)
end)

RegisterNetEvent('bryan_mazebank_garage:placeNewVehicle', function(plate, props, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    local result = MySQL.Sync.fetchAll('SELECT * FROM bryan_garage_vehicles WHERE identifier = @identifier', { ['@identifier'] = xPlayer.getIdentifier() })
    local found, hSlot, hFloor = false, 0, 0

    if result and result[1] then
        for i = 1, 4 do
            for j = 1, 16 do
                if IsSpotFree(i, j, result) then
                    found, hFloor, hSlot = true, i, j
                    break
                end
            end

            if found then break; end
        end
    else
        found, hFloor, hSlot = true, 1, 1
    end

    if found then
        if garageInstances[xPlayer.getIdentifier()] then garageInstances[xPlayer.getIdentifier()] = nil end

        MySQL.Async.execute('INSERT INTO bryan_garage_vehicles (identifier, name, plate, properties, floor, slot) VALUES (@identifier, @name, @plate, @props, @floor, @slot)', {
            ['@identifier'] = xPlayer.getIdentifier(),
            ['@name'] = name,
            ['@plate'] = plate,
            ['@props'] = json.encode(props),
            ['@floor'] = hFloor,
            ['@slot'] = hSlot
        })

        if Config.CheckOwnership then
            MySQL.Async.execute('UPDATE owned_vehicles SET stored = @stored, garage_name = @garage WHERE owner = @identifier AND plate = @plate', {
                ['@stored'] = true,
                ['@garage'] = 'Maze Bank',
                ['@identifier'] = xPlayer.getIdentifier(),
                ['@plate'] = plate
            })
        end
    else
        xPlayer.showNotification(Config.Strings['Notifications']['NoFreeSpot'])
    end

    TriggerClientEvent('bryan_mazebank_garage:cancelSettingUp', xPlayer.source)
end)

RegisterNetEvent('bryan_mazebank_garage:removeVehicle', function(plate, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.execute('DELETE FROM bryan_garage_vehicles WHERE name = @name AND plate = @plate', {
        ['@name'] = name,
        ['@plate'] = plate
    })

    if Config.CheckOwnership then
        MySQL.Async.execute('UPDATE owned_vehicles SET stored = @stored WHERE owner = @owner AND plate = @plate', {
            ['@stored'] = false,
            ['@owner'] = xPlayer.getIdentifier(),
            ['@plate'] = plate
        })
    end
end)

RegisterNetEvent('bryan_mazebank_garage:requestToEnter', function(rIdentifier)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local xTarget = ESX.GetPlayerFromIdentifier(rIdentifier)

    if xPlayer and xTarget then
        TriggerClientEvent('bryan_mazebank_garage:insertRequest', xTarget.source, xPlayer.getName(), xPlayer.getIdentifier())
        xPlayer.showNotification(string.format(Config.Strings['Notifications']['Requested'], xTarget.getName()))
        xTarget.showNotification(Config.Strings['Notifications']['NewRequest'])
    end
end)

RegisterNetEvent('bryan_mazebank_garage:updateVehiclePosition', function(model, plate, floor, slot, update)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if xPlayer then
        MySQL.Async.execute('UPDATE bryan_garage_vehicles SET floor = @floor, slot = @slot WHERE name = @name AND plate = @plate', {
            ['@floor'] = floor,
            ['@slot'] = slot,
            ['@name'] = model,
            ['@plate'] = plate
        }, function(rowsChanged)
            if update then
                if garageInstances[xPlayer.getIdentifier()] then garageInstances[xPlayer.getIdentifier()] = nil end
                for k, v in pairs(playerInstances[xPlayer.getIdentifier()]) do 
                    for j, c in pairs(v) do
                        TriggerClientEvent('bryan_mazebank_garage:forceUpdateVehicles', c, xPlayer.getIdentifier())
                    end
                end
                TriggerClientEvent('bryan_mazebank_garage:cancelSettingUp', xPlayer.source)
            end
        end)
    end
end)

RegisterNetEvent('bryan_mazebank_garage:acceptRequest', function(sIdentifier, rIdentifier)
    local xTarget = ESX.GetPlayerFromIdentifier(rIdentifier)

    TriggerClientEvent('bryan_mazebank_garage:removeRequest', -1, sIdentifier)
    TriggerClientEvent('bryan_mazebank_garage:enterGarage', xTarget.source, sIdentifier, 1, nil)
end)



ESX.RegisterServerCallback('bryan_mazebank_garage:getGarage', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    local result = MySQL.Sync.fetchAll('SELECT identifier FROM bryan_garage_owners WHERE identifier = @identifier', { ['@identifier'] =  xPlayer.getIdentifier() })
    local gotGarage = (result ~= nil and result[1] ~= nil)

    cb(gotGarage)
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:getGarageVehicles', function(source, cb, identifier)
    if garageInstances[identifier] then
        cb(garageInstances[identifier])
    else
        local result = MySQL.Sync.fetchAll('SELECT * FROM bryan_garage_vehicles WHERE identifier = @identifier', { ['@identifier'] = identifier })

        garageInstances[identifier] = {}

        if result ~= nil then            
            for k, v in pairs(result) do
                table.insert(garageInstances[identifier], {
                    model = v.name,
                    plate = v.plate,
                    props = json.decode(v.properties),
                    floor = v.floor,
                    slot  = v.slot
                })
            end
        end

        cb(garageInstances[identifier])
    end
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:attemptToPurchase', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local hasEnough = false

    if xPlayer and xPlayer.getMoney() >= Config.Price then
        hasEnough = nil
        xPlayer.removeMoney(Config.Price)

        MySQL.Async.execute('INSERT INTO bryan_garage_owners (identifier) VALUES (@identifier)', { ['@identifier'] = xPlayer.getIdentifier() }, function(rowsChanged)
            hasEnough = true
        end)
    end

    while hasEnough == nil do
        Citizen.Wait(10)
    end

    cb(hasEnough)
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:isGarageOwner', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    local garage = GetInWhatGarage(source)
    cb(garage == xPlayer.getIdentifier())
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:getOwner', function(source, cb)
    cb(GetInWhatGarage(source))
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:getVisitorCount', function(source, cb, identifier)
    cb(GetVisitorCount(identifier))
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:getVisitors', function(source, cb, identifier)
    cb(GetVisitors(identifier))
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:getAllAvailableGarages', function(source, cb)
    local garages, count = {}, 0

    for k, v in pairs(garageInstances) do
        count = count + 1
        table.insert(garages, {
            label = string.format(Config.Strings['EnterMenu']['Player'], ESX.GetPlayerFromIdentifier(k).getName()),
            identifier = k,
            requested = false
        })
    end

    cb(garages, count)
end)

ESX.RegisterServerCallback('bryan_mazebank_garage:checkOwnerShip', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    local doesOwn = false

    local result = MySQL.Sync.fetchAll('SELECT owner FROM owned_vehicles WHERE plate = @plate', { ['@plate'] = plate })
    if result and result[1] and result[1].owner == xPlayer.getIdentifier() then doesOwn = true end

    cb(doesOwn)
end)

-- New Code

lib.callback.register('bryan_mazebank_garage:server:doesOwnGarage', function(source)
    local result = MySQL.Scalar.await('SELECT identifier FROM bryan_garage_owners WHERE identifier = ?', { _GetPlayerIdentifier(source) })

    return result ~= nil
end)

lib.callback.register('bryan_mazebank_garage:server:doesOwnVehicle', function(source, plate)
    local result = MySQL.Scalar.await('SELECT owner FROM owned_vehicles WHERE plate = ? AND owner = ?', { plate, _GetPlayerIdentifier(source) })

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

lib.callback.register('bryan_mazebank_garage:server:getGarageVehicles', function(source, id)
    if garageInstances[id] then return garageInstances[id] end
    
    local identifier = _GetPlayerIdentifier(id)
    if not identifier then return {} end

    local result = MySQL.query.await('SELECT * FROM bryan_garage_vehicles WHERE identifier = ?', { identifier })
    garageInstances[id] = {}

    if result then
        for k, v in ipairs(result) do
            table.insert(garageInstances[id], {
                model = v.name,
                plate = v.plate,
                props = json.encode(v.properties),
                slot = v.slot,
            })
        end
    end

    return garageInstances[id]
end)

lib.callback.register('bryan_mazebank_garage:server:isGarageOwner', function(source)
    local id = GetInWhatGarage(source)

    return source == id
end)

lib.callback.register('bryan_mazebank_garage:server:getVisitorCount', function(source)
    return GetVisitorCount(source)
end)

lib.callback.register('bryan_mazebank_garage:server:getVisitors', function(source)
    return GetVisitors(source)
end)

lib.callback.register('bryan_mazebank_garage:server:getRequestCount', function(source)
    return #requests[source]
end)

lib.callback.register('bryan_mazebank_garage:server:getRequests', function(source)
    return GetRequests(source)
end)

-- TODO Replace garage instances from identifiers to sources
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

RegisterNetEvent('bryan_mazebank_garage:server:enterVehicle', function(plate, props, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    local freeSpot = GetFreeSpotInGarage(source)

    if freeSpot then
        if garageInstances[source] then garageInstances[source] = nil end

        MySQL.insert.await('INSERT INTO bryan_garage_vehicles (identifier, name, plate, properties, slot) VALUES (?, ?, ?, ?, ?)', {
            _GetPlayerIdentifier(source), name, plate, json.encode(props), freeSpot
        })

        _UpdateOwnedVehicleTable(source, plate, true)
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:exitVehicle', function(plate)
    MySQL.update.await('DELETE FROM bryan_garage_vehicles WHERE plate = ?', { plate })

    _UpdateOwnedVehicleTable(source, plate, false)
end)

RegisterNetEvent('bryan_mazebank_garage:server:enterGarage', function(id)
    if not playerInstances[id] then playerInstances[id] = {} end
    table.insert(playerInstances[id], source)

    SetPlayerRoutingBucket(source, id)

    TriggerClientEvent('bryan_mazebank_garage:clearRequested', source)
    TriggerClientEvent('bryan_mazebank_garage:removeRequest', -1, _GetPlayerIdentifier(source))
end)

RegisterNetEvent('bryan_mazebank_garage:server:exitGarage', function()
    local id = GetInWhatGarage(source)

    if id then
        RemovePlayerInstance(source, id)

        if GetVisitorCount(id) < 0 then DeleteGarage(id) end

        SetPlayerRoutingBucket(source, 0)
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:kickFromGarage', function(data)
    TriggerClientEvent('bryan_mazebank_garage:exitGarage', data.source)
end)

RegisterNetEvent('bryan_mazebank_garage:server:updateVehiclePosition', function(plate, slot, update)
    MySQL.update.await('UPDATE bryan_garage_vehicles SET slot = ? WHERE plate = ?', { slot, plate })

    if update then
        if garageInstances[source] then garageInstances[source] = nil end

        for k, v in ipairs(playerInstances[source]) do
            TriggerClientEvent('bryan_mazebank_garage:forceUpdateVehicles', v, source)
        end
    end
end)

RegisterNetEvent('bryan_mazebank_garage:server:forceExitVisitors', function()
    for k, v in pairs(playerInstances[source]) do
        if v ~= source then
            TriggerClientEvent('bryan_mazebank_garage:exitGarage', v)
        end
    end
end)

GetFreeSpotInGarage = function(id)
    local result = MySQL.query.await('SELECT floor, slot FROM bryan_garage_vehicles WHERE identifier = ?', { _GetPlayerIdentifier(id) })

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

DoesGrarageInstanceExist = function(id)
    for k, v in ipairs(garageInstances) do
        if v.id == id then
            return true
        end
    end

    return false
end

GetInWhatGarage = function(source)
    for k, v in pairs(playerInstances) do
        if v == source then
            return k
        end
    end

    return nil
end

DeleteGarage = function(identifier)
    for i = 1, 3 do
        playerInstances[identifier][i] = {}
    end
    garageInstances[identifier] = nil
end

IsSpotFree = function(floor, slot, table)
    for k, v in pairs(table) do
        if v.floor == floor and v.slot == slot then
            return false
        end
    end

    return true
end

SetUpPlayerInstance = function(identifier)
    playerInstances[identifier] = {}

    for i = 1, 3, 1 do
        playerInstances[identifier][i] = {}
    end
end

RemovePlayerInstance = function(source, identifier)
    for k, v in pairs(playerInstances[identifier]) do
        if v == source then
            table.remove(playerInstances[identifier], k)
            return true
        end
    end
    
    return false
end

GetVisitors = function(id)
    local data = {}

    for k, v in ipairs(playerInstances[id]) do
        if v ~= id then
            table.insert(data, {
                title = _GetPlayerName(v),
                description = _U('kick'),
                serverEvent = 'bryan_mazebank_garage:server:kickFromGarage',
                args = { source = v },
            })
        end
    end

    if #data == 0 then
        table.insert(data, {
            title = _U('no_visitors'),
            disabled = true
        })
    end

    return data
end

GetRequests = function(id)
    local data = {}

    for k, v in ipairs(requests[id]) do
        table.insert(data, {
            title = _GetPlayerName(v),
            description = _U('let_inside'),
            source = v
        })
    end

    if #data == 0 then
        table.insert(data, {
            title = _U('no_requests'),
            disabled = true
        })
    end
    
    return data
end

GetVisitorCount = function(id)
    local count = -1

    for k, v in pairs(playerInstances[id]) do
        count = count + 1
    end

    return count
end

-- ON PLAYER LEAVE!