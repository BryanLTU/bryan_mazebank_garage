local hasGarage, currFloor = false, 0
local isMenuOpened, isSettingUp = false, false
local blip, garage, requests, requested = nil, {}, {}, {}
local currPlayers = {}
local disableControlsInElevator = false

local garageVehicles = {}
local isInGarage, isInMagment = false, false

lib.locale()

StartScript = function()
    TriggerServerEvent('bryan_mazebank_garage:server:registerGarage')
    RegisterContextMenus()
    RefreshGarageBlip()
    Citizen.CreateThread(StartMarkers)

    if Config.UseTarget then RegisterTarget() end
end

RefreshGarageBlip = function()
    local doesOwnGarage = lib.callback.await('bryan_mazebank_garage:server:doesOwnGarage', false)
    
    if DoesBlipExist(blip) then RemoveBlip(blip); end

    if doesOwnGarage then AddBlip('Owned');
    else AddBlip('ForSale'); end
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

RegisterTarget = function()
    exports.ox_target:addSphereZone({
        coords = Config.Locations.Enter,
        radius = 1.5,
        drawSprite = true,
        options = {
            {
                label = locale('mazebank_garage'),
                name = 'enter',
                distance = 1.5,
                onSelect = function(data)
                    PressedControl('Enter')
                end
            },
        }
    })
    exports.ox_target:addBoxZone({
        coords = Config.Locations.Exit,
        size = vector3(1.5, 0.5, 3.0),
        rotation = 250.0,
        drawSprite = true,
        options = {
            {
                label = locale('manage_garage'),
                name = 'exit',
                distance = 1.5,
                onSelect = function(data)
                    PressedControl('Exit')
                end
            },
        }
    })
end

StartMarkers = function()
    local isUIOpen = false

    while true do
        local sleep = true
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local positionType

        if not Config.UseTarget and GetDistanceBetweenCoords(coords, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, true) <= 10.0 then
            positionType = 'Enter'
        elseif IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped and GetDistanceBetweenCoords(coords, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, true) <= 10.0 then
            positionType = 'EnterVh'
        elseif not Config.UseTarget and GetDistanceBetweenCoords(coords, Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z, true) <= 10.0 then
            positionType = 'Exit'
        end

        if positionType then
            sleep = false
            DrawMarker(Config.Markers[positionType].Type, Config.Locations[positionType].x, Config.Locations[positionType].y, Config.Locations[positionType].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Markers[positionType].Scale.x, Config.Markers[positionType].Scale.y, Config.Markers[positionType].Scale.z, Config.Markers[positionType].Colour.r, Config.Markers[positionType].Colour.g, Config.Markers[positionType].Colour.b, Config.Markers[positionType].Colour.a, false, false, 2, Config.Markers[positionType].Rotate, nil, nil, false)
        end

        if positionType and #(coords - vector3(Config.Locations[positionType].x, Config.Locations[positionType].y, Config.Locations[positionType].z)) <= Config.Markers[positionType].Scale.x then
            if not isUIOpen then
                isUIOpen = true
                local text, pos = locale('alert_' .. string.lower(positionType))
                lib.showTextUI(text)
            end

            if IsControlJustPressed(1, 51) then
                PressedControl(positionType)
            end
        elseif isUIOpen then
            isUIOpen = false
            lib.hideTextUI()
        end

        if sleep then Citizen.Wait(500) end
        Citizen.Wait(1)
    end
end

RegisterContextMenus = function()
    lib.registerContext({
        id = 'bryan_mazebank_garage:enterVehicle',
        title = locale('mazebank_garage'),
        options = {{
            title = locale('menu_enter_garage'),
            description = locale('menu_enter_vehicle'),
            onSelect = function()
                local doesOwnGarage = lib.callback.await('bryan_mazebank_garage:server:doesOwnGarage', false)
                local doesOwnVehicle = Config.CheckOwnership and lib.callback.await('bryan_mazebank_garage:server:doesOwnVehicle', false, _GetVehicleProperties(GetVehiclePedIsIn(PlayerPedId(), false)).plate) or true
                
                if not doesOwnGarage then
                    _Notification(locale('notification_enter_garage_not_owned'))
                    return
                end

                if not doesOwnVehicle then
                    _Notification(locale('notification_vehicle_not_owned'))
                    return
                end

                TriggerServerEvent('bryan_mazebank_garage:server:enterGarage')
            end
        }}
    })

    lib.registerContext({
        id = 'bryan_mazebank_garage:exitOptions',
        title = locale('exit'),
        menu = 'bryan_mazebank_garage:managment',
        options = {
            {
                title = locale('front_door'),
                serverEvent = 'bryan_mazebank_garage:server:exitGarage',
                args = 'front',
            },
            {
                title =  locale('garage_elevator'),
                serverEvent = 'bryan_mazebank_garage:server:exitGarage',
                args = 'elevator',
            }
        }
    })
end

PressedControl = function(position)
    if position == 'Enter' then
        local options = {}
        local doesOwnGarage = lib.callback.await('bryan_mazebank_garage:server:doesOwnGarage', false)

        if doesOwnGarage then
            table.insert(options, {
                title = locale('menu_enter_garage'),
                onSelect = function()
                    TriggerServerEvent('bryan_mazebank_garage:server:enterGarage')
                end
            })
        else
            table.insert(options, {
                title = locale('menu_enter_purchase'),
                description = locale('price', Config.Price),
                onSelect = function()
                    local isPurchaseSuccessful = lib.callback.await('bryan_mazebank_garage:server:purchaseGarage', false)

                    if isPurchaseSuccessful then
                        RefreshGarageBlip()
                        lib.hideContext('bryan_garage_enter')
                    end
                end
            })
        end

        table.insert(options, {
            title = locale('menu_enter_visit'),
            description = locale('menu_enter_visit_desc'),
            onSelect = function()
                local input = lib.inputDialog(locale('menu_visit_title'), {
                    { label = locale('id'), type = 'number', min = 1, default = 1 }
                })

                if not input then return end
                if not tonumber(input[1]) then return end

                TriggerServerEvent('bryan_mazebank_garage:server:requestToEnter', tonumber(input[1]))
            end
        })

        lib.registerContext({
            id = 'bryan_garage_enter',
            title = locale('mazebank_garage'),
            options = options
        })
    
        lib.showContext('bryan_garage_enter')
    elseif position == 'Exit' then
        GarageManagment()
    elseif position == 'EnterVh' then
        lib.showContext('bryan_mazebank_garage:enterVehicle')
    end
end

lib.callback.register('bryan_mazebank_garage:client:kickVisitorsOnExitDialog', function()
    local alert = lib.alertDialog({
        header = locale('warning'),
        content = locale('exit_with_visitors_warning'),
        centered = true,
        cancel = true,
    })

    return alert ~= 'cancel'
end)

DisplayUnlockText = function()
    local closeVehicle
    local isUIOpen = false
    local vehicles = {}
    local serverId = GetPlayerServerId(PlayerId())

    local data = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicleEntities', false)
    for k, v in ipairs(data) do table.insert(vehicles, NetworkGetEntityFromNetworkId(v)) end

    while isInGarage do
        local sleep = true
        local coords = GetEntityCoords(PlayerPedId())

        for k, v in ipairs(vehicles) do
            local doorCoords = GetWorldPositionOfEntityBone(v, GetEntityBoneIndexByName(v, 'door_dside_f'))

            if not closeVehicle and v and #(coords - doorCoords) < 1.5 then
                closeVehicle = v
                break
            elseif closeVehicle and closeVehicle == v and #(coords - doorCoords) > 1.5 then
                closeVehicle = nil
            end
        end

        if closeVehicle and not IsPedInAnyVehicle(PlayerPedId(), false) then
            local isLocked = GetVehicleDoorLockStatus(closeVehicle) == 2
            local text = isLocked and locale('alert_unlock') or locale('alert_lock')
            sleep = false

            if not isUIOpen then
                isUIOpen = true
                lib.showTextUI(text)
            end

            if IsControlJustReleased(1, 51) then
                SetVehicleDoorsLocked(closeVehicle, isLocked and 1 or 2)
                VehicleLockAnimation(closeVehicle)
                isUIOpen = false
            end

        elseif isUIOpen then
            isUIOpen = false
            lib.hideTextUI()
        end

        if sleep then Citizen.Wait(100) end
        Citizen.Wait(1)
    end
end

OnDriveExit = function()
    local serverId = GetPlayerServerId(PlayerId())

    while isInGarage do
        local sleep = true
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local throttle = GetVehicleThrottleOffset(vehicle)
            sleep = false
            
            if throttle >= 0.5 or throttle <= -0.5  then
                TriggerServerEvent('bryan_mazebank_garage:server:exitGarage', 'elevator')
                return
            end
        end

        if sleep then Citizen.Wait(500) end
        Citizen.Wait(1)
    end
end

RequestVehicle = function(model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Citizen.Wait(10)
    end
end

GarageManagment = function()
    local isGarageOwner = lib.callback.await('bryan_mazebank_garage:server:isGarageOwner', false)
    local garageId = lib.callback.await('bryan_mazebank_garage:server:getGarageId', false)
    local visitorCount, requestCount, vehicleCount = 0, 0, 0

    if isGarageOwner then
        visitorCount = lib.callback.await('bryan_mazebank_garage:server:getVisitorCount', false)
        requestCount = lib.callback.await('bryan_mazebank_garage:server:getRequestCount', false)
        vehicleCount = #lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)
    end

    local options = isGarageOwner and {
        { title = locale('visitors'), description = locale('count', visitorCount), menu = 'bryan_mazebank_garage:visitors', disabled = visitorCount == 0 },
        { title = locale('enter_requests'), description = locale('count', requestCount), menu = 'bryan_mazebank_garage:requests', disabled = requestCount == 0 },
        { title = locale('manage_vehicles'), description = locale('count', vehicleCount), disabled = vehicleCount == 0, onSelect = StartVehicleManager },
        { title = locale('exit'), menu = 'bryan_mazebank_garage:exitOptions' },
    } or {
        { title = locale('exit'), menu = 'bryan_mazebank_garage:exitOptions' },
    }

    lib.registerContext({
        id = 'bryan_mazebank_garage:managment',
        title = isGarageOwner and locale('menu_title_id', garageId) or locale('mazebank_garage'),
        options = options
    })

    if isGarageOwner then
        lib.registerContext({
            id = 'bryan_mazebank_garage:visitors',
            title = locale('visitors'),
            menu = 'bryan_mazebank_garage:managment',
            options = lib.callback.await('bryan_mazebank_garage:server:getVisitors', false),
        })

        lib.registerContext({
            id = 'bryan_mazebank_garage:requests',
            title = locale('enter_requests'),
            menu = 'bryan_mazebank_garage:managment',
            options = lib.callback.await('bryan_mazebank_garage:server:getRequests', false),
        })
    end

    lib.showContext('bryan_mazebank_garage:managment')
end

StartVehicleManager = function()
    local spotsWithVehicle, availableSpots = {labels = {}, args = {}}, {labels = {}, args = {}}
    local currentSpot, currentVehicle

    for k, v in ipairs(lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)) do
        if currentSpot == nil then currentSpot = v.slot end

        table.insert(spotsWithVehicle.labels, string.format('#%s', v.slot))
        table.insert(spotsWithVehicle.args, v.slot)
    end

    for k, v in ipairs(Config.Locations.VehicleLocations) do

        table.insert(availableSpots.labels, string.format('#%s', k))
        table.insert(availableSpots.args, k)
    end

    lib.registerMenu({
        id = 'bryan_mazebank_garage:selectVehicle',
        title = locale('alert_vehicle_managment_select_vehicle'),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
            currentSpot = args[scrollIndex]
        end,
        onClose = function()
            isInMagment = false
        end,
        options = {
            {label = locale('vehicle'), values = spotsWithVehicle.labels, args = spotsWithVehicle.args}
        },
    }, function(selected, scrollIndex, args)
        currentVehicle = GetVehicleFromSlot(currentSpot)
        currentSpot = 1

        lib.hideMenu()
        lib.showMenu('bryan_mazebank_garage:selectSpot')
    end)

    lib.registerMenu({
        id = 'bryan_mazebank_garage:selectSpot',
        title = locale('alert_vehicle_managment_select_spot'),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
            currentSpot = args[scrollIndex]
        end,
        onClose = function()
            isInMagment = false
        end,
        options = {
            {label = locale('spot'), values = availableSpots.labels, args = availableSpots.args}
        }
    }, function(selected, scrollIndex, args)
        isInMagment = false
        lib.hideMenu()

        PlaceVehicleInNewSlot(currentVehicle, currentSpot)
    end)

    lib.showMenu('bryan_mazebank_garage:selectVehicle')

    isInMagment = true

    while isInGarage and isInMagment do
        local markerOptions = currentVehicle == nil and Config.Markers['SelectVehicle'] or Config.Markers['SelectSlot']

        DrawMarker(0, Config.Locations.VehicleLocations[currentSpot].x, Config.Locations.VehicleLocations[currentSpot].y, Config.Locations.VehicleLocations[currentSpot].z + 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, markerOptions.Scale.x, markerOptions.Scale.y, markerOptions.Scale.z, markerOptions.Colour.r, markerOptions.Colour.g, markerOptions.Colour.b, 150, false, false, 2, markerOptions.Rotate, nil, nil, false)

        Citizen.Wait(1)
    end
end

PlaceVehicleInNewSlot = function(vehicle, slot)
    local slotVehicle = GetVehicleFromSlot(slot)

    if slotVehicle then
        TriggerServerEvent('bryan_mazebank_garage:server:updateVehiclePosition', { plate = vehicle.plate, slot = slot, previousSlot = vehicle.slot }, { plate = slotVehicle.plate, slot = vehicle.slot, previousSlot = slot })
    else
        TriggerServerEvent('bryan_mazebank_garage:server:updateVehiclePosition', { plate = vehicle.plate, slot = slot, previousSlot = vehicle.slot })
    end
end

GetFirstVehicleSlotInGarage = function()
    local vehicles = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)
    local minSlot = vehicles[1].slot

    for k, v in ipairs(vehicles) do
        if v.slot < minSlot then minSlot = v.slot end
    end

    return minSlot
end

GetPreviousSlotInGarage = function(slot, checkIfVehicleExists)
    if checkIfVehicleExists then
        local vehicles = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)
        
        if #vehicles <= 1 then return slot end
    end

    slot = 1 == slot and #Config.Locations.VehicleLocations or slot - 1

    if checkIfVehicleExists and not IsVehicleInSlot(slot) then return GetPreviousSlotInGarage(slot, checkIfVehicleExists) end

    return slot
end

GetNextSlotInGarage = function(slot, checkIfVehicleExists)
    if checkIfVehicleExists then
        local vehicles = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)
        
        if #vehicles <= 1 then return slot end
    end

    slot = #Config.Locations.VehicleLocations == slot and 1 or slot + 1

    if checkIfVehicleExists and not IsVehicleInSlot(slot) then return GetNextSlotInGarage(slot, checkIfVehicleExists) end

    return slot
end

IsVehicleInSlot = function(slot)
    local vehicles = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)

    for k, v in ipairs(vehicles) do
        if v.slot == slot then
            return true
        end
    end

    return false
end

GetVehicleFromSlot = function(slot)
    local vehicles = lib.callback.await('bryan_mazebank_garage:server:getGarageVehicles', false)

    for k, v in ipairs(vehicles) do
        if v.slot == slot then
            return v
        end
    end

    return nil
end

VehicleLockAnimation = function(vehicle)
    local dict = "anim@mp_player_intmenu@key_fob@"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Citizen.Wait(0)
    end

    PlaySoundFrontend(-1, "BUTTON", "MP_PROPERTIES_ELEVATOR_DOORS", 1)
    TaskPlayAnim(PlayerPedId(), dict, "fob_click_fp", 8.0, 8.0, -1, 48, 1, false, false, false)
    SetVehicleLights(vehicle, 2); Citizen.Wait(200)
    SetVehicleLights(vehicle, 0); Citizen.Wait(200)
    SetVehicleLights(vehicle, 2); Citizen.Wait(200)
    SetVehicleLights(vehicle, 0); Citizen.Wait(200)
end

ActivateElevatorCamera = function()
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, -87.08, -821.06, 225.31)
    SetCamRot(cam, -20.0, 0.0, 230.0)
    RenderScriptCams(true, false, 0, true, true)
    SetCamActive(cam, true)
end

DisableElevatorCamera = function()
    RenderScriptCams(false, false, 0, 0, 0)
    DestroyCam(cam, true)
end

DisableControlsInElevator = function()
    Citizen.CreateThread(function()
        while disableControlsInElevator do
            DisableAllControlActions(0)

            Citizen.Wait(1)
        end
    end)
end

lib.callback.register('bryan_mazebank_garage:client:requestModel', function()
    RequestModel(`imp_prop_int_garage_mirror01`)
    while not HasModelLoaded(`imp_prop_int_garage_mirror01`) do
        Wait(10)
    end

    return
end)

lib.callback.register('bryan_mazebank_garage:client:attachVehicleToElevator', function(vehicleNetId, elevatorNetId)
    AttachEntityToEntity(NetToVeh(vehicleNetId), NetToObj(elevatorNetId), 0, 0.0, 0.0, 0.6, 0.0, 0.0, 0.0, 0, false, false, false, GetEntityRotation(NetToObj(elevatorNetId)), false)

    return
end)

lib.callback.register('bryan_mazebank_garage:client:getVehicleProps', function(vehicleNetId)
    return _GetVehicleProperties(NetToVeh(vehicleNetId))
end)

RegisterNetEvent('bryan_mazebank_garage:client:ActivateElevatorCamera', function()
    ActivateElevatorCamera()

    disableControlsInElevator = true
    DisableControlsInElevator()
end)

RegisterNetEvent('bryan_mazebank_garage:client:DisableElevatorCamera', function()
    DisableElevatorCamera()

    disableControlsInElevator = false
end)

RegisterNetEvent('bryan_mazebank_garage:client:fadeout', function(value, length)
    length = length or 1000

    if value then DoScreenFadeOut(length)
    else DoScreenFadeIn(length) end
end)

RegisterNetEvent('bryan_mazebank_garage:client:applyVehicleProperties', function(netId, props)
    _SetVehicleProperties(NetworkGetEntityFromNetworkId(netId), props)
end)

RegisterNetEvent('bryan_mazebank_garage:client:ownerThreads', function()
    Citizen.CreateThread(OnDriveExit)
    Citizen.CreateThread(DisplayUnlockText)
end)

RegisterNetEvent('bryan_mazebank_garage:client:toggleIsInGarage', function(value)
    isInGarage = true
end)