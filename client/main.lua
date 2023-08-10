local hasGarage, currFloor = false, 0
local isMenuOpened, isSettingUp = false, false
local blip, garage, requests, requested = nil, {}, {}, {}
local currPlayers = {}

local garageVehicles = {}
local isInGarage, isInMagment = false, false

Citizen.CreateThread(function()
    if not Config.DebugMode then
        while ESX.GetPlayerData().job == nil do
            Citizen.Wait(100)
        end

        ESX.PlayerData = ESX.GetPlayerData()

        RegisterContextMenus()
        SetUpGarages()
        Citizen.CreateThread(StartMarkers)
        Citizen.CreateThread(SetupVisibility)
    end
end)

SetUpGarages = function()
    isSettingUp = true

    ESX.TriggerServerCallback('bryan_mazebank_garage:getGarage', function(gotGarage)
        if DoesBlipExist(blip) then RemoveBlip(blip); end

        if gotGarage then AddBlip('Owned');
        else AddBlip('ForSale'); end

        hasGarage = gotGarage

        isSettingUp = false
    end)
end

AddBlip = function(type)
    if Config.Blips.Enable then
        blip = AddBlipForCoord(Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z)

        SetBlipSprite(blip, Config.Blips[type].Sprite)
        SetBlipColour(blip, Config.Blips[type].Colour)
        SetBlipScale(blip, Config.Blips[type].Scale)
        SetBlipDisplay(blip, 4)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips[type].Text)
        EndTextCommandSetBlipName(blip)
    end
end

SetupVisibility = function()
    while true do
        local wait = 500

        if #currPlayers > 0 then
            wait = 5

            for k, v in pairs(currPlayers) do
                SetEntityLocallyVisible(GetPlayerPed(GetPlayerFromServerId(v)))
            end
        end

        Citizen.Wait(wait)
    end
end

StartMarkers = function()
    while true do
        local wait = 1000

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local type, isNear, pos = 'none', false
        
        if GetDistanceBetweenCoords(coords, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, true) <= 10.0 then
            isNear = true
            type, pos = 'Enter', vector3(Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z)
        elseif hasGarage and GetDistanceBetweenCoords(coords, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, true) <= 10.0 and IsPedInAnyVehicle(ped, false) then
            isNear = true
            type, pos = 'EnterVh', vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z)
        elseif GetDistanceBetweenCoords(coords, Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z, true) <= 10.0 then
            isNear = true
            type, pos = 'Exit', vector3(Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z)
        else
            type, isNear = 'none', false
        end

        if Config.Markers.Enable and isNear then
            wait = 1
            DrawMarker(Config.Markers[type].Type, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Markers[type].Scale.x, Config.Markers[type].Scale.y, Config.Markers[type].Scale.z, Config.Markers[type].Colour.r, Config.Markers[type].Colour.g, Config.Markers[type].Colour.b, Config.Markers[type].Colour.a, false, false, 2, Config.Markers[type].Rotate, nil, nil, false)
        end

        if isNear and not isMenuOpened and GetDistanceBetweenCoords(coords, pos, true) <= Config.Markers[type].Scale.x and not isSettingUp then
            wait = 1
            ESX.ShowHelpNotification(Config.Strings[type])

            if IsControlJustPressed(1, 51) then
                PressedControl(type)
            end
        elseif isMenuOpened and GetDistanceBetweenCoords(coords, pos, true) > Config.Markers[type].Scale.x then
            ESX.UI.Menu.CloseAll()
            isMenuOpened = false
        end

        Citizen.Wait(wait)
    end
end

RegisterContextMenus = function()
    lib.registerContext({
        id = 'bryan_mazebank_garage:enterVehicle',
        title = _U('menu_title'),
        options = {{
            title = _U('menu_enter_garage'),
            description = _U('menu_enter_vehicle'),
            onSelect = function()
                local doesOwnGarage = lib.callback.await('bryan_mazebank_garage:server:doesOwnGarage', false)
                local doesOwnVehicle = Config.CheckOwnership and lib.callback.await('bryan_mazebank_garage:server:doesOwnVehicle', false, _GetVehicleProperties(GetVehiclePedIsIn(PlayerPedId(), false)).plate) or true
                
                if not doesOwnGarage then
                    _Notification(_U('notification_enter_garage_not_owned'))
                    return
                end

                if not doesOwnVehicle then
                    _Notification(_U('notification_vehicle_not_owned'))
                    return
                end

                EnterGarage(ESX.GetPlayerData().identifier, GetVehiclePedIsIn(PlayerPedId(), false))
            end
        }}
    })

    lib.registerContext({
        id = 'bryan_mazebank_garage:exitOptions',
        title = _U('exit'),
        options = {
            {
                title = _U('front_door'),
                onSelect = ExitGarage,
                menu = 'bryan_mazebank_garage:managment',
                args = { door = 'front' },
            },
            {
                title =  _U('garage_elevator'),
                onSelect = ExitGarage,
                menu = 'bryan_mazebank_garage:managment',
                args = { door = 'elevator' },
            }
        }
    })
end

PressedControl = function(position)
    local options = {}

    if position == 'Enter' then
        local doesOwnGarage = lib.callback.await('bryan_mazebank_garage:server:doesOwnGarage', false)

        if doesOwnGarage then
            table.insert(options, {
                title = _U('menu_enter_garage'),
                onSelect = function()
                    EnterGarage(ESX.PlayerData.identifier)
                end
            })
        else
            table.insert(options, {
                title = _U('menu_enter_purchase'),
                description = _U('price', Config.Price),
                onSelect = function()
                    local isPurchaseSuccessful = lib.callback.await('bryan_mazebank_garage:server:purchaseGarage', false)

                    if isPurchaseSuccessful then
                        SetUpGarages()
                        lib.hideContext('bryan_garage_enter')
                    end
                end
            })
        end

        table.insert(options, {
            title = _U('menu_enter_visit'),
            description = _U('menu_enter_visit_desc'),
            onSelect = function()
                local input = lib.inputDialog(_U('menu_visit_title'), {
                    { label = _U('id'), type = 'number', min = 1, default = 1 }
                })

                if not tonumber(input[1]) then return end

                TriggerServerEvent('bryan_mazebank_garage:server:requestToEnter', tonumber(input[1]))
            end
        })
    elseif position == 'Exit' then
        GarageManagment()
    end

    lib.registerContext({
        id = 'bryan_garage_enter',
        title = _U('menu_enter_title'),
        options = options
    })
end

EnterGarage = function(id, vehicle)
    local coords = GetEntityCoords(PlayerPedId())

    if #(coords - vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z)) > 10.0 and
    #(coords - vector3(Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z)) > 10.0 and
    #(coords - vector3(Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z)) > 10.0 then
        _Notification(_U('notification_enter_too_far_away'))
        return
    end

    DoScreenFadeOut(200)
    Citizen.Wait(200)
    
    if vehicle ~= nil then
        local doesGarageHaveEmptySpots = lib.callback.await('bryan_mazebank_garage:server:doesGarageHaveEmptySpots', false)

        if not doesGarageHaveEmptySpots then
            _Notification(_U('notification_garage_full'))
            return
        end

        local props = _GetVehicleProperties(vehicle)
        TriggerServerEvent('bryan_mazebank_garage:server:enterVehicle', props.plate, props, _GetVehicleModelName(props.model))
        _DeleteVehicle(vehicle)
    end

    isInGarage = true
    SetEntityCoords(PlayerPedId(), Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z, 0.0, 0.0, 0.0, false)
    TriggerServerEvent('bryan_mazebank_garage:server:enterGarage', id)

    SpawnGarage(id)

    DoScreenFadeIn(200)
end

ExitGarage = function(data)
    local isGarageOwner = lib.callback.await('bryan_mazebank_garage:server:isGarageOwner', false)
    
    if isGarageOwner then
        local visitorCount = lib.callback.await('bryan_mazebank_garage:server:getVisitorCount', false)

        if visitorCount > 0 then
            local alert = lib.alertDialog({
                header = _U('warning'),
                content = _U('exit_with_visitors_warning'),
                centered = true,
                cancel = true,
            })

            if alert == 'cancel' then
                return
            else
                TriggerServerEvent('bryan_mazebank_garage:server:forceExitVisitors')
            end
        end
    end

    DoScreenFadeOut(200)
    Citizen.Wait(200)

    isInGarage = false

    if data.vehicle == nil then ClearGarage() end

    local ped = PlayerPedId()
    if data.door and data.door == 'elevator' then
        if data.vehicle then
            
            SetEntityCoords(ped, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, 0.0, 0.0, 0.0, false)
            
            local props = ESX.Game.GetVehicleProperties(data.vehicle)
            local localVehicle = _SpawnVehicle(props.model, vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z), Config.Locations.EnterVh.w)
            _SetVehicleProperties(localVehicle, props)
            TaskWarpPedIntoVehicle(ped, localVehicle, -1)
            
            if props then TriggerServerEvent('bryan_mazebank_garage:server:exitVehicle', props.plate) end
        else
            SetEntityCoords(ped, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, 0.0, 0.0, 0.0, false)
        end
    else
        SetEntityCoords(ped, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, 0.0, 0.0, 0.0, false)
    end

    ClearGarage()
    TriggerServerEvent('bryan_mazebank_garage:server:exitGarage')

    DoScreenFadeIn(200)
end

SpawnGarage = function(id)
    ClearGarage()
    
    local vehicles = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false, id)

    for k, v in ipairs(vehicles) do
        local localVehicle = _SpawnLocalVehicle(v.props.model, vector3(Config.Locations.VehicleLocations[v.slot].x, Config.Locations.VehicleLocations[v.slot].y, Config.Locations.VehicleLocations[v.slot].z), Config.Locations.VehicleLocations[v.slot].w)
            
        _SetVehicleProperties(localVehicle, v.props)
        SetVehicleDoorsLocked(localVehicle, 2)
        SetEntityInvincible(localVehicle, true)

        table.insert(garageVehicles, {
            entity = localVehicle,
            plate = v.plate,
            model = GetDisplayNameFromVehicleModel(v.props.model),
            slot = v.slot
        })

        Citizen.Wait(5)
    end

    if id == GetPlayerServerId(PlayerId()) then Citizen.CreateThread(DisplayUnlockText); end
    Citizen.CreateThread(OnDriveExit)
end

DisplayUnlockText = function()
    while isInGarage do
        local wait = 500
        local coords = GetEntityCoords(PlayerPedId())

        for k, v in pairs(garage) do
            if v.entity then
                local doorPos = GetWorldPositionOfEntityBone(v.entity, GetEntityBoneIndexByName(v.entity, 'door_dside_f'))

                if GetDistanceBetweenCoords(coords, doorPos, true) <= 1.0 then
                    wait = 5

                    if GetVehicleDoorLockStatus(v.entity) == 2 then
                        ESX.Game.Utils.DrawText3D(doorPos, Config.Strings['Text3D']['Unlock'], 1.0, 8)

                        if IsControlJustPressed(1, 51) then
                            Citizen.Wait(500)
                            SetVehicleDoorsLocked(v.entity, 1)
                        end
                    else
                        ESX.Game.Utils.DrawText3D(doorPos, Config.Strings['Text3D']['Lock'], 1.0, 8)

                        if IsControlJustPressed(1, 51) then
                            Citizen.Wait(500)
                            SetVehicleDoorsLocked(v.entity, 2)
                        end
                    end
                end
            end
        end

        Citizen.Wait(wait)
    end
end

OnDriveExit = function()
    while isInGarage do
        local wait = 500
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            wait = 5
            
            if GetEntitySpeed(vehicle) * 3.6 > 2.0 then
                ExitGarage('elevator', vehicle)
                return
            end
        end

        Citizen.Wait(wait)
    end
end

ClearGarage = function()
    for k, v in pairs(garageVehicles) do
        if v.entity then _DeleteVehicle(v.entity) end
    end

    garageVehicles = {}
end

RequestVehicle = function(model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Citizen.Wait(10)
    end
end

GarageManagment = function()
    local isGarageOwner = lib.callback.await('bryan_mazebank_garage:server:isGarageOwner', false)
    local options = isGarageOwner and {
        { title = _U('visitors'), description = _U('count', lib.callback.await('bryan_mazebank_garage:server:getVisitorCount', false)), menu = 'bryan_mazebank_garage:visitors' },
        { title = _U('enter_requests'), description = _U('count', lib.callback.await('bryan_mazebank_garage:server:getRequestCount', false)), menu = 'bryan_mazebank_garage:requests' },
        { title = _U('manage_vehicles'), disabled = #garageVehicles == 0, onSelect = StartVehicleManager }
        { title = _U('exit'), menu = 'bryan_mazebank_garage:exitOptions' }
    } or {
        { title = _U('exit'), menu = 'bryan_mazebank_garage:exitOptions' }
    }

    lib.registerContext({
        id = 'bryan_mazebank_garage:managment',
        title = _U('menu_title'),
        options = options
    })

    if isGarageOwner then
        lib.registerContext({
            id = 'bryan_mazebank_garage:visitors',
            title = _U('visitors'),
            menu = 'bryan_mazebank_garage:managment',
            options = lib.callback.await('bryan_mazebank_garage:server:getVisitors', false),
        })

        lib.registerContext({
            id = 'bryan_mazebank_garage:requests',
            title = _U('enter_requests'),
            menu = 'bryan_mazebank_garage:managment',
            options = lib.callback.await('bryan_mazebank_garage:server:getRequests', false),
        })
    end

    lib.showContext('bryan_mazebank_garage:managment')
end

StartVehicleManager = function()
    isInMagment = true

    local currentSlot, selectedVehicle = GetFirstVehicleSlotInGarage(), nil
    while isInGarage and isInMagment do
        local message = string.format('%s\n%s\n%s\n%s',
                                selectedVehicle == nil and _U('alert_vehicle_managment_select_vehicle') or _U('alert_vehicle_managment_select_spot'),
                                _U('alert_vehicle_managment_position'), _U('alert_vehicle_managment_confirm'), _U('alert_vehicle_managment_cancel'))
        
        _ShowHelpNotification(message)

        DrawMarker(0, Config.Locations.VehicleLocations[currentSlot].x, Config.Locations.VehicleLocations[currentSlot].y, Config.Locations.VehicleLocations[currentSlot].z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 255, 100, 0, 150, true, false, 2, false, nil, nil, false)

        if IsControlJustReleased(1, 174) then
            currentSlot = GetPreviousSlotInGarage(currentSlot, selectedVehicle == nil)
        end

        if IsControlJustReleased(1, 175) then
            currentSlot = GetNextSlotInGarage(currentSlot, selectedVehicle == nil)
        end

        if IsControlJustReleased(1, 176) then
            if selectedVehicle == nil then
                selectedVehicle = GetVehicleFromSlot(currentSlot)
                currentSlot = 1
            else
                isInMagment = false
                PlaceVehicleInNewSlot(selectedVehicle, currentSlot)
            end
        end
        
        if IsControlJustReleased(1, 177) then
            isInMagment = false
        end

        Citizen.Wait(1)
    end
end

PlaceVehicleInNewSlot = function(vehicle, slot)
    local slotVehicle = GetVehicleFromSlot(slot)

    if slotVehicle then
        TriggerServerEvent('bryan_mazebank_garage:updateVehiclePosition', vehicle.plate, slot)
        TriggerServerEvent('bryan_mazebank_garage:updateVehiclePosition', slotVehicle.plate, vehicle.slot, true)
    else
        TriggerServerEvent('bryan_mazebank_garage:server:updateVehiclePosition', vehicle.plate, slot, true)
    end
end

GetFirstVehicleSlotInGarage = function()
    return garageVehicles[1].slot
end

GetPreviousSlotInGarage = function(slot, checkIfVehicleExists)
    if checkIfVehicleExists and #garageVehicles <= 1 then return slot end

    slot = 1 == slot and #Config.Locations.VehicleLocations or slot - 1

    if checkIfVehicleExists and not IsVehicleInSlot(slot) then return GetPreviousSlotInGarage(slot, checkIfVehicleExists) end

    return slot
end

GetNextSlotInGarage = function(slot, checkIfVehicleExists)
    if checkIfVehicleExists and #garageVehicles <= 1 then return slot end

    slot = #Config.Locations.VehicleLocations == slot and 1 or slot + 1

    if checkIfVehicleExists and not IsVehicleInSlot(slot) then return GetNextSlotInGarage(slot, checkIfVehicleExists) end

    return slot
end

IsVehicleInSlot = function(slot)
    for k, v in ipairs(garageVehicles) do
        if v.slot == slot then
            return true
        end
    end

    return false
end

GetVehicleFromSlot = function(slot)
    for k, v in ipairs(garageVehicles) do
        if v.slot == slot then
            return v
        end
    end

    return nil
end

RegisterNetEvent('bryan_mazebank_garage:setVisibilityLocaly', function(players)
    currPlayers = players
end)

RegisterNetEvent('bryan_mazebank_garage:exitGarage', ExitGarage)

RegisterNetEvent('bryan_mazebank_garage:cancelSettingUp', function()
    isSettingUp = false
end)

RegisterNetEvent('bryan_mazebank_garage:forceUpdateVehicles', function(id)
    SpawnGarage(id)
end)

RegisterNetEvent('bryan_mazebank_garage:insertRequest', function(name, identifier)
    table.insert(requests, {
        label = name,
        value = identifier
    })
end)

RegisterNetEvent('bryan_mazebank_garage:removeRequest', function(identifier)
    for k, v in pairs(requests) do
        if v.identifier == identifier then
            table.remove(requests, k)
        end
    end
end)

RegisterNetEvent('bryan_mazebank_garage:clearRequested', function()
    requested = {}
end)

RegisterNetEvent('bryan_mazebank_garage:enterGarage', EnterGarage)

--[[AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and currFloor ~= 0 then
        ExitGarage()
    end
end)]]