Config = {}

Config.Locale               = 'en'

Config.Framework            = 'esx' -- esx / qbcore

Config.Price                = 15000 -- Price to buy the Garage
Config.CheckOwnership       = false -- Check if the vehicle that is being stored is owned by the player
Config.UseTarget            = true  -- Use target instead of markers

Config.Locations = {
    Enter            = vector4(-71.06, -800.99, 44.93, 181.40),
    EnterVh          = vector4(-84.11, -821.25, 35.63, 351.15),
    Exit             = vector4(-92.0, -821.12, 222.0, 250.0),
    
    VehicleElevator  = vector4(-76.89, -829.58, 221.11, 0.0),

    VehicleLocations = {
        [1] = vector4(-85.24082,      -818.235535,    220.23494,  -144.433289),
        [2] = vector4(-76.9321747,    -819.9362,      220.234451, 176.218323),
        [3] = vector4(-71.09352,      -822.318542,    220.234543, 140.8338),
        [4] = vector4(-67.9834747,    -828.685547,    220.234467, 94.56514),
        [5] = vector4(-70.25896,      -836.0581,      220.234222, 45.08332),
        [6] = vector4(-84.3974152,    -819.8488,      225.672928, -148.987808),
        [7] = vector4(-76.77495,      -819.621033,    225.672867, 171.160126),
        [8] = vector4(-71.1063461,    -823.0381,      225.672928, 136.971),
        [9] = vector4(-67.4827652,    -828.406433,    225.672943, 92.51076),
        [10] = vector4(-70.124855,     -835.7496,      225.673065, 49.92409),
        [11] = vector4(-85.98553,      -820.654846,    231.018417, -142.9082),
        [12] = vector4(-77.21592,      -820.092957,    231.018982, 178.564911),
        [13] = vector4(-71.42833,      -822.0914,      231.018478, 133.955643),
        [14] = vector4(-68.0297,       -828.6458,      231.018784, 88.1085358),
        [15] = vector4(-70.2125,       -835.0709,      231.0186,   48.27413),
    }
}

Config.Blips = {
    Enable = true,

    ['ForSale'] = {
        Sprite = 369,
        Colour = 47,
        Scale = 0.8,
        Text = 'Maze Bank Garage'
    },
    ['Owned'] = {
        Sprite = 50,
        Colour = 2,
        Scale = 0.8,
        Text = '~o~Maze Bank Garage'
    }
}

Config.Markers = {
    ['Enter'] = {
        Type = 1,
        Scale = { x = 1.0, y = 1.0, z = 1.0 },
        Colour = { r = 0, g = 255, b = 255, a = 255 },
        Rotate = true
    },
    ['EnterVh'] = {
        Type = 2,
        Scale = { x = 1.0, y = 1.0, z = 1.0 },
        Colour = { r = 0, g = 255, b = 255, a = 255 },
        Rotate = true
    },
    ['Exit'] = {
        Type = 1,
        Scale = { x = 1.0, y = 1.0, z = 1.0 },
        Colour = { r = 255, g = 0, b = 0, a = 255 },
        Rotate = true
    },
    ['SelectVehicle'] = {
        Type = 0,
        Scale = { x = 0.5, y = 0.5, z = 0.5 },
        Colour = { r = 50, g = 255, b = 50, a = 150 },
        Rotate = false,
    },
    ['SelectSlot'] = {
        Type = 0,
        Scale = { x = 0.5, y = 0.5, z = 0.5 },
        Colour = { r = 200, g = 150, b = 50, a = 150 },
        Rotate = false,
    },
}