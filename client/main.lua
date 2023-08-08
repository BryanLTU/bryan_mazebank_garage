local hasGarage, currFloor = false, 0
local isMenuOpened, isSettingUp = false, false
local blip, garage, requests, requested = nil, {}, {}, {}
local currPlayers = {}

Citizen.CreateThread(function()
    if not Config.DebugMode then
        while ESX.GetPlayerData().job == nil do
            Citizen.Wait(100)
        end

        ESX.PlayerData = ESX.GetPlayerData()

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
            wait = 5
            DrawMarker(Config.Markers[type].Type, pos, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Markers[type].Scale.x, Config.Markers[type].Scale.y, Config.Markers[type].Scale.z, Config.Markers[type].Colour.r, Config.Markers[type].Colour.g, Config.Markers[type].Colour.b, Config.Markers[type].Colour.a, false, false, 2, Config.Markers[type].Rotate, nil, nil, false)
        end

        if isNear and not isMenuOpened and GetDistanceBetweenCoords(coords, pos, true) <= Config.Markers[type].Scale.x and not isSettingUp then
            wait = 5
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

PressedControl = function(type)
    isMenuOpened = true

    if type == 'Enter' then
        if hasGarage then
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_enter_menu', {
                title = 'Garage',
                align = Config.Menus.Align,
                elements = {
                    { label = Config.Strings['EnterMenu']['Enter'], value = 'enter' },
                    { label = Config.Strings['EnterMenu']['Visit'], value = 'visit' }
                }
            }, function(data, menu)
                if data.current.value == 'enter' then
                    menu.close()
                    isMenuOpened = false
                    EnterGarage(ESX.PlayerData.identifier, 1)
                elseif data.current.value == 'visit' then
                    ESX.TriggerServerCallback('bryan_mazebank_garage:getAllAvailableGarages', function(garages, count)
                        if count > 0 then
                            for k, v in pairs(garages) do
                                if requested[v.identifier] then
                                    v.label = v.label .. ' <b style="color:red;">(Requested)</b>'
                                    garages[k].requested = true
                                end
                            end

                            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_request', {
                                title = Config.Strings['EnterMenu']['Visit'],
                                align = Config.Menus.Align,
                                elements = garages
                            }, function(data2, menu2)
                                if not data2.current.requested then
                                    menu2.close()
                                    menu.close()
                                    isMenuOpened = false

                                    requested[data2.current.identifier] = true
                                    TriggerServerEvent('bryan_mazebank_garage:requestToEnter', data2.current.identifier)
                                end
                            end, function(data2, menu2)
                                menu2.close()
                            end)
                        else
                            ESX.ShowNotification(Config.Strings['Notifications']['NoActivateGarage'])
                        end
                    end)
                end
            end, function(data, menu)
                menu.close()
                isMenuOpened = false
            end)
        else
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_purchase_menu', {
                title = 'Purchase Garage',
                align = Config.Menus.Align,
                elements = {
                    { label = string.format(Config.Strings['EnterMenu']['Purchase'], ESX.Math.GroupDigits(Config.Price)), value = 'purchase'},
                    { label = Config.Strings['EnterMenu']['Visit'], value = 'visit' }
                }
            }, function(data, menu)
                local action = data.current.value

                if action == 'purchase' then
                    ESX.TriggerServerCallback('bryan_mazebank_garage:attemptToPurchase', function(hasEnough) 
                        if hasEnough then
                            menu.close()
                            isMenuOpened = false
                            ESX.ShowNotification(Config.Strings['Notifications']['Purchase_Success'])
                            SetUpGarages()
                        else
                            ESX.ShowNotification(Config.Strings['Notifications']['Purchase_Fail'])
                        end
                    end)
                elseif action == 'visit' then
                    ESX.TriggerServerCallback('bryan_mazebank_garage:getAllAvailableGarages', function(garages, count)
                        if count > 0 then
                            for k, v in pairs(garages) do
                                if requested[v.identifier] then
                                    v.label = v.label .. ' <b style="color:red;">(Requested)</b>'
                                    garages[k].requested = true
                                end
                            end

                            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_request', {
                                title = Config.Strings['EnterMenu']['Visit'],
                                align = Config.Menus.Align,
                                elements = garages
                            }, function(data2, menu2)
                                if not data2.current.requested then
                                    menu2.close()
                                    menu.close()
                                    isMenuOpened = false

                                    requested[data2.current.identifier] = true
                                    TriggerServerEvent('bryan_mazebank_garage:requestToEnter', data2.current.identifier)
                                end
                            end, function(data2, menu2)
                                menu2.close()
                            end)
                        else
                            ESX.ShowNotification(Config.Strings['Notifications']['NoActivateGarage'])
                        end
                    end)
                end
            end, function(data, menu)
                menu.close()
                isMenuOpened = false
            end)
        end
    elseif type == 'Exit' then
        GarageManagment()
    elseif type == 'EnterVh' then
        if hasGarage then
            local ownsVehicle = nil

            if Config.CheckOwnership then
                ESX.TriggerServerCallback('bryan_mazebank_garage:checkOwnerShip', function(doesOwn)
                    ownsVehicle = doesOwn 
                end, ESX.Game.GetVehicleProperties(GetVehiclePedIsIn(PlayerPedId(), false)).plate)
            else
                ownsVehicle = false
            end

            while ownsVehicle == nil do
                Citizen.Wait(10)
            end
            
            if not Config.CheckOwnership or ownsVehicle then
                EnterGarage(ESX.GetPlayerData().identifier, 1, GetVehiclePedIsIn(PlayerPedId(), false))
            else
                ESX.ShowNotification(Config.Strings['Notifications']['NoOwnVehicle'])
            end
        else
            ESX.ShowNotification(Config.Strings['Notifications']['NoOwn'])
        end
    end
end

EnterGarage = function(identifier, floor, vehicle)
    local coords = GetEntityCoords(PlayerPedId())
    local distance = GetDistanceBetweenCoords(coords, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, true) <= 10.0
    local distance2 = GetDistanceBetweenCoords(coords, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, true) <= 10.0
    local distance3 = GetDistanceBetweenCoords(coords, Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z, true) <= 10.0

    if not distance and not distance2 and not distance3 then
        return ESX.ShowNotification(Config.Strings['Notifications']['TooFarAway'])
    end

    DoScreenFadeOut(200)
    Citizen.Wait(200)
    
    if vehicle ~= nil then
        local props = ESX.Game.GetVehicleProperties(vehicle)
        isSettingUp = true
        TriggerServerEvent('bryan_mazebank_garage:placeNewVehicle', props.plate, props, GetDisplayNameFromVehicleModel(props.model))
        ESX.Game.DeleteVehicle(vehicle)
    end

    while isSettingUp == true do
        Citizen.Wait(10)
    end

    local ped = PlayerPedId()
    SetEntityCoords(ped, Config.Locations.Exit.x, Config.Locations.Exit.y, Config.Locations.Exit.z, 0.0, 0.0, 0.0, false)
    SetEntityVisible(ped, false, 0)
    TriggerServerEvent('bryan_mazebank_garage:updatePlayerVisibility', true, identifier, floor)

    currFloor = floor

    SpawnGarage(identifier)

    DoScreenFadeIn(200)
end

SpawnGarage = function(identifier)
    ClearGarage()
    local floor = currFloor

    ESX.TriggerServerCallback('bryan_mazebank_garage:getGarageVehicles', function(vehicles) 
        for k, v in pairs(vehicles) do
            local found = false

            if v.floor == currFloor then
                RequestVehicle(v.props.model)

                ESX.Game.SpawnLocalVehicle(v.props.model, vector3(Config.Locations.VehicleLocations[v.slot].x, Config.Locations.VehicleLocations[v.slot].y, Config.Locations.VehicleLocations[v.slot].z), Config.Locations.VehicleLocations[v.slot].w, function(callback_vehicle) 
                    ESX.Game.SetVehicleProperties(callback_vehicle, v.props)
                    SetVehicleDoorsLocked(callback_vehicle, 2)
                    SetEntityInvincible(callback_vehicle, true)

                    found = true
                    table.insert(garage, {
                        entity = callback_vehicle,
                        plate = v.plate,
                        model = GetDisplayNameFromVehicleModel(v.props.model),
                        floor = v.floor,
                        slot = v.slot
                    })
                end)

                Citizen.Wait(10)
            end

            if not found then
                table.insert(garage, {
                    plate = v.plate,
                    model = GetDisplayNameFromVehicleModel(v.props.model),
                    floor = v.floor,
                    slot = v.slot
                })
            end
        end
        currFloor = 0

        ESX.TriggerServerCallback('bryan_mazebank_garage:isGarageOwner', function(isOwner)
            currFloor = floor
            if isOwner then Citizen.CreateThread(DisplayUnlockText); end
            Citizen.CreateThread(OnDriveExit)
        end)
    end, identifier)
end

DisplayUnlockText = function()
    while currFloor ~= 0 do
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
    while currFloor ~= 0 do
        local wait = 500
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            wait = 5
            
            if GetEntitySpeed(vehicle) * 3.6 > 2.0 then
                ExitGarage('g', vehicle)
                return
            end
        end

        Citizen.Wait(wait)
    end
end

ClearGarage = function()
    for k, v in pairs(garage) do
        if v.entity then
            ESX.Game.DeleteVehicle(v.entity)
        end
    end

    garage = {}
end

RequestVehicle = function(model)
    RequestModel(model)

    while not HasModelLoaded(model) do
        Citizen.Wait(10)
    end
end

GarageManagment = function()
    local loadedVisitors = nil
    local elements = {
        { label = Config.Strings['ManagmentMenu']['Exit'], value = 'exit' } -- Exit Door | Exit Garage
    }

    ESX.TriggerServerCallback('bryan_mazebank_garage:isGarageOwner', function(isOwner)
        if isOwner then
            ESX.TriggerServerCallback('bryan_mazebank_garage:getVisitorCount', function(count)
                table.insert(elements, {
                    label = string.format(Config.Strings['ManagmentMenu']['Visitors'], count),
                    value = 'visitors'
                })
                loadedVisitors = count
            end, ESX.GetPlayerData().identifier)

            while loadedVisitors == nil do
                Citizen.Wait(10)
            end

            table.insert(elements, {
                label = Config.Strings['ManagmentMenu']['Requests'],
                value = 'requests'
            })
            table.insert(elements, {
                label = Config.Strings['ManagmentMenu']['Manage'],
                value = 'manage'
            })
        end

        for i = 1, Config.MaxFloors, 1 do
            if i ~= currFloor then
                table.insert(elements, {
                    label = string.format(Config.Strings['ManagmentMenu']['Floor'], i),
                    value = 'floor',
                    id = i
                })
            end
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_manage_menu', {
            title = 'Managment',
            align = Config.Menus.Align,
            elements = elements
        }, function(data, menu)
            local action = data.current.value

            if action == 'exit' then
                ExitComfirmation()
            elseif action == 'visitors' then
                VisitorManager(loadedVisitors)
            elseif action == 'requests' then
                RequestManager()
            elseif action == 'manage' then
                VehicleManager()
            elseif action == 'floor' then
                menu.close()
                isMenuOpened = false

                ESX.TriggerServerCallback('bryan_mazebank_garage:getOwner', function(identifier)
                    EnterGarage(identifier, data.current.id)
                end)
            end
        end, function(data, menu)
            menu.close()
            isMenuOpened = false
        end)
    end)
end

VisitorManager = function(count)
    if count > 0 then
        ESX.TriggerServerCallback('bryan_mazebank_garage:getVisitors', function(visitors)
            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_visitors', {
                title = 'Visitors',
                align = Config.Menus.Align,
                elements = visitors
            }, function(data, menu)
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_visitor_manager', {
                    title = 'Actions',
                    align = Config.Menus.Align,
                    elements = {
                        { label = 'Kick', value = 'kick' }
                    }
                }, function(data2, menu2)
                    if data2.current.value == 'kick' then
                        menu2.close()
                        menu.close()
                        TriggerServerEvent('bryan_mazebank_garage:forceExitSource', data.current.identifier)
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            end, function(data, menu)
                menu.close()
            end)
        end, ESX.GetPlayerData().identifier)
    else
        ESX.ShowNotification(Config.Strings['Notifications']['NoVisit'])
    end
end

RequestManager = function()
    local elements = {
        { label = Config.Strings['ManagmentMenu']['NoRequests'], value = 'none' }
    }

    if #requests > 0 then
        elements = requests
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_requests', {
        title = 'Requests',
        align = Config.Menus.Align,
        elements = elements
    }, function(data, menu)
        if data.current.value ~= 'none' then

            ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_requests_choice', {
                title = 'Accept?',
                align = Config.Menus.Align,
                elements = {
                    { label = 'Yes', value = true },
                    { label = 'No', value = false }
                }
            }, function(data2, menu2)
                if data2.current.value then
                    menu.close()
                    menu2.close()

                    TriggerServerEvent('bryan_mazebank_garage:acceptRequest', ESX.GetPlayerData().identifier, data.current.value)
                else
                    menu2.close()
                end
            end, function(data2, menu2)
                menu2.close()
            end)

        end
    end, function(data, menu)
        menu.close()
    end)
end

VehicleManager = function()
    local elements = {}

    for i = 1, Config.MaxFloors, 1 do
        table.insert(elements, {
            label = string.format(Config.Strings['ManagmentMenu']['Floor'], i),
            value = 'floor',
            id = i
        })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_vehicle_manager_floor', {
        title = 'Floors',
        align = Config.Menus.Align,
        elements = elements
    }, function(data, menu)
        local elements2 = {}

        for i = 1, 15, 1 do
            elements2[i] = {
                label = string.format(Config.Strings['ManagmentMenu']['Vehicle'], i, 'None'),
                plate = 'none',
                slot = i
            }
        end

        for k, v in pairs(garage) do
            if v.floor == data.current.id then
                elements2[v.slot] = {
                    label = string.format(Config.Strings['ManagmentMenu']['Vehicle'] .. '(<span style="color:orange;">%s</span>)', v.slot, v.model, v.plate),
                    plate = v.plate,
                    slot = v.slot,
                    model = v.model
                }
            end
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_vehicle_manager_slot', {
            title = 'Vehicles',
            align = Config.Menus.Align,
            elements = elements2
        }, function(data2, menu2)

            if data2.current.plate ~= 'none' then
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_vehicle', {
                    title = string.format('(%s)', data2.current.plate),
                    align = Config.Menus.Align,
                    elements = {
                        { label = Config.Strings['ManagmentMenu']['Replace'], value = 'replace' }
                    }
                }, function(data3, menu3)
                    
                    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_vehicle_choose_floor', {
                        title = 'Floors',
                        align = Config.Menus.Align,
                        elements = elements
                    }, function(data4, menu4)

                        elements3 = {}

                        for i = 1, 15, 1 do
                            elements3[i] = {
                                label = string.format(Config.Strings['ManagmentMenu']['Vehicle'], i, 'None'),
                                plate = 'none',
                                slot = i
                            }
                        end

                        for k, v in pairs(garage) do
                            if v.floor == data4.current.id then
                                elements3[v.slot] = {
                                    label = string.format(Config.Strings['ManagmentMenu']['Vehicle'] .. '(<span style="color:orange;">%s</span>)', v.slot, v.model, v.plate),
                                    plate = v.plate,
                                    slot = v.slot,
                                    model = v.model
                                }
                            end
                        end

                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_vehicle_choose_slot', {
                            title = 'Spots',
                            align = Config.Menus.Align,
                            elements = elements3
                        }, function(data5, menu5)
                            local currVehicle = data2.current

                            isSettingUp = true

                            if data5.current.plate ~= 'none' then
                                local futuVehicle = data5.current

                                TriggerServerEvent('bryan_mazebank_garage:updateVehiclePosition', currVehicle.model, currVehicle.plate, data4.current.id, data5.current.slot)
                                TriggerServerEvent('bryan_mazebank_garage:updateVehiclePosition', futuVehicle.model, futuVehicle.plate, data.current.id, data2.current.slot, true)
                            else
                                TriggerServerEvent('bryan_mazebank_garage:updateVehiclePosition', currVehicle.model, currVehicle.plate, data4.current.id, data5.current.slot, true)
                            end

                            while isSettingUp do
                                Citizen.Wait(10)
                            end

                            menu5.close()
                            menu4.close()
                            menu3.close()
                            menu2.close()
                            menu.close()
                        end, function(data5, menu5)
                            menu5.close()
                            menu4.close()
                            menu3.close()
                        end)

                    end, function(data4, menu4)
                        menu4.close()
                        menu3.close()
                    end)

                end, function(data3, menu3)
                    menu3.close()  
                end)
            end

        end, function(data2, menu2)
            menu2.close()
        end)

    end, function(data, menu)
        menu.close()
        isMenuOpened = false
    end)
end

ExitComfirmation = function()
    ESX.TriggerServerCallback('bryan_mazebank_garage:isGarageOwner', function(isOwner)
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_exit_door', {
            title = 'Door',
            align = Config.Menus.Align,
            elements = {
                { label = 'Front Door', value = 'f' },
                { label = 'Garage Exit', value = 'g' }
            }
        }, function(data2, menu2)
            if isOwner then
                ESX.TriggerServerCallback('bryan_mazebank_garage:getVisitorCount', function(count)
                    if count > 0 then
                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'bryan_exit_comfirmation', {
                            title = Config.Strings['ManagmentMenu']['ExitComfirm'],
                            align = Config.Menus.Align,
                            elements = {
                                { label = 'Yes', value = true },
                                { label = 'No', value = false }
                            }
                        }, function(data, menu)
                            if data.current.value then
                                ExitGarage(data2.current.value)
                                TriggerServerEvent('bryan_mazebank_garage:forceExit', ESX.GetPlayerData().identifier)
                            else
                                menu.close()
                                menu2.close()
                            end
                        end, function(data, menu)
                            menu.close()
                            menu2.close()
                        end)
                    else
                        ExitGarage(data2.current.value)
                        TriggerServerEvent('bryan_mazebank_garage:forceExit', ESX.GetPlayerData().identifier)
                    end
                end, ESX.GetPlayerData().identifier)
            else
                ExitGarage(data2.current.value)
            end
        end, function(data2, menu2)
            menu2.close()
        end)
    end)
end

ExitGarage = function(door, vehicle)
    DoScreenFadeOut(200)
    Citizen.Wait(200)

    ESX.UI.Menu.CloseAll()
    isMenuOpened = false

    currFloor = 0
    if vehicle == nil then
        ClearGarage()
    end

    local ped = PlayerPedId()
    if door then
        if door == 'f' then SetEntityCoords(ped, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, 0.0, 0.0, 0.0, false);
        elseif door == 'g' then
            if vehicle then
                local props = ESX.Game.GetVehicleProperties(vehicle)
                ClearGarage()

                SetEntityCoords(ped, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, 0.0, 0.0, 0.0, false)
                ESX.Game.SpawnVehicle(props.model, vector3(Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z), Config.Locations.EnterVh.w, function(callback_vehicle) 
                    ESX.Game.SetVehicleProperties(callback_vehicle, props)
                    TaskWarpPedIntoVehicle(ped, callback_vehicle, -1)
                end)
                if props then
                    TriggerServerEvent('bryan_mazebank_garage:removeVehicle', props.plate, GetDisplayNameFromVehicleModel(props.model))
                end
            else
                SetEntityCoords(ped, Config.Locations.EnterVh.x, Config.Locations.EnterVh.y, Config.Locations.EnterVh.z, 0.0, 0.0, 0.0, false)
            end
        end
    else
        SetEntityCoords(ped, Config.Locations.Enter.x, Config.Locations.Enter.y, Config.Locations.Enter.z, 0.0, 0.0, 0.0, false)
    end
    TriggerServerEvent('bryan_mazebank_garage:updatePlayerVisibility', false, nil, nil)
    SetEntityVisible(ped, true, 0)

    DoScreenFadeIn(200)
end

RegisterNetEvent('bryan_mazebank_garage:setVisibilityLocaly', function(players)
    currPlayers = players
end)

RegisterNetEvent('bryan_mazebank_garage:exitGarage', ExitGarage)

RegisterNetEvent('bryan_mazebank_garage:cancelSettingUp', function()
    isSettingUp = false
end)

RegisterNetEvent('bryan_mazebank_garage:forceUpdateVehicles', function(identifier)
    SpawnGarage(identifier)
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