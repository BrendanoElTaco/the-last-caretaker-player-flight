local UEHelpers = require("UEHelpers")
local ModMenu = require("ModMenu.ModMenu")
local Config = ModMenu.ConfigManager

local MOD_NAME = "TLCPlayerFlight"
local MOD_VERSION = "0.2.3-beta.1"
local TARGET_BUILD = "25982825"
local MOVE_WALKING = 1
local MOVE_FLYING = 5

local DEFAULTS = {
    flySpeed = 1200,
    verticalStep = 100,
    toggleKey = "F6",
    riseKey = "PAGE_UP",
    lowerKey = "PAGE_DOWN",
    dock = "right",
}

local LIMITS = {
    flySpeed = { min = 100, max = 50000 },
    verticalStep = { min = 10, max = 10000 },
}

local function normalizeNumber(value, fallback, limits)
    local number = tonumber(value)
    if number == nil or number ~= number or number == math.huge or number == -math.huge then
        number = fallback
    end
    return math.max(limits.min, math.min(limits.max, math.floor(number)))
end

local TOGGLE_KEYS = {
    { label = "F5", value = "F5", key = Key.F5 },
    { label = "F6", value = "F6", key = Key.F6 },
    { label = "F8", value = "F8", key = Key.F8 },
    { label = "F9", value = "F9", key = Key.F9 },
    { label = "F10", value = "F10", key = Key.F10 },
    { label = "Numpad 0", value = "NUM_ZERO", key = Key.NUM_ZERO },
    { label = "Unbound", value = "NONE" },
}

local RISE_KEYS = {
    { label = "Page Up", value = "PAGE_UP", key = Key.PAGE_UP },
    { label = "Home", value = "HOME", key = Key.HOME },
    { label = "Numpad +", value = "ADD", key = Key.ADD },
    { label = "Numpad 8", value = "NUM_EIGHT", key = Key.NUM_EIGHT },
    { label = "Numpad 9", value = "NUM_NINE", key = Key.NUM_NINE },
    { label = "Unbound", value = "NONE" },
}

local LOWER_KEYS = {
    { label = "Page Down", value = "PAGE_DOWN", key = Key.PAGE_DOWN },
    { label = "End", value = "END", key = Key.END },
    { label = "Numpad -", value = "SUBTRACT", key = Key.SUBTRACT },
    { label = "Numpad 2", value = "NUM_TWO", key = Key.NUM_TWO },
    { label = "Numpad 3", value = "NUM_THREE", key = Key.NUM_THREE },
    { label = "Unbound", value = "NONE" },
}

Config.Init({
    id = MOD_NAME,
    defaults = DEFAULTS,
})

local function loadNumber(key)
    local saved = Config.Get(key)
    local value = normalizeNumber(saved, DEFAULTS[key], LIMITS[key])
    if saved ~= value then Config.Set(key, value) end
    return value
end

local flySpeed = loadNumber("flySpeed")
local verticalStep = loadNumber("verticalStep")
local toggleKey = tostring(Config.Get("toggleKey") or DEFAULTS.toggleKey)
local riseKey = tostring(Config.Get("riseKey") or DEFAULTS.riseKey)
local lowerKey = tostring(Config.Get("lowerKey") or DEFAULTS.lowerKey)

local flightEnabled = false
local activePawn = nil
local activeMovement = nil
local savedMovementMode = MOVE_WALKING
local savedCustomMovementMode = 0
local savedMaxFlySpeed = nil
local savedBaseClimbSpeed = nil
local speedPropertyReady = false

-- Update 6 caches MaxClimbSpeed at BeginPlay and uses that cache to recalculate
-- MaxFlySpeed, including the game's weight/cold/sprint modifiers. Verify the
-- actual executable layout before exposing this non-reflected float. Other
-- builds must be checked again; never apply an unchecked memory offset.
local SPEED_LAYOUT = {
    { offset = 0x5574621, hex = "8b860c100000898670110000" },
    { offset = 0x559eccb, hex = "440f2948b8f3440f108970110000" },
    { offset = 0x559ee75, hex = "f3440f118b94020000" },
}

local function prepareSpeedProperty()
    if speedPropertyReady then return end
    local source = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
    local root = source:match("^(.*)/ue4ss/Mods/TLCPlayerFlight/[Ss]cripts/main%.lua$")
    local path = (root and (root .. "/") or "") .. "VoyageSteam-Win64-Shipping.exe"
    local file, problem = io.open(path, "rb")
    if not file then error("Cannot verify game movement layout: " .. tostring(problem)) end
    local ok, err = pcall(function()
        for _, check in ipairs(SPEED_LAYOUT) do
            local expected = check.hex:gsub("..", function(byte)
                return string.char(tonumber(byte, 16))
            end)
            assert(file:seek("set", check.offset), "Cannot read game movement layout")
            assert(file:read(#expected) == expected,
                "Unsupported game movement layout; Player Flight needs an update")
        end
    end)
    file:close()
    if not ok then error(err) end
    RegisterCustomProperty({
        Name = "TLCFlightBaseClimbSpeed",
        Type = PropertyTypes.FloatProperty,
        BelongsToClass = "/Script/Voyage.VoyageCharacterMovementComponent",
        OffsetInternal = 0x1170,
    })
    speedPropertyReady = true
end

local function applyFlightSpeed(movement)
    movement.TLCFlightBaseClimbSpeed = flySpeed
    movement.MaxFlySpeed = flySpeed
end

local function log(message)
    print(string.format("[%s] %s\n", MOD_NAME, message))
end

local function updateMenuStatus()
    pcall(function()
        if flightEnabled then
            ModMenu.SetLabel("Flight", "status", "Status: FLIGHT ON")
            ModMenu.SetButtonLabel("Flight", "toggle", "Disable Flight")
            ModMenu.SetButtonActive("Flight", "toggle", true)
        else
            ModMenu.SetLabel("Flight", "status", "Status: flight off")
            ModMenu.SetButtonLabel("Flight", "toggle", "Enable Flight")
            ModMenu.SetButtonActive("Flight", "toggle", false)
        end
    end)
end

local function getPlayerAndMovement()
    local controller = UEHelpers.GetPlayerController()
    if not controller or not controller:IsValid() then
        return nil, nil, "player controller is not ready"
    end

    local pawn = controller.Pawn
    if not pawn or not pawn:IsValid() then
        return nil, nil, "player character is not ready"
    end

    local movement = nil
    local ok = pcall(function()
        movement = pawn.CharacterMovement
    end)

    if not ok or not movement or not movement:IsValid() then
        ok = pcall(function()
            movement = pawn.CharMoveComp
        end)
    end

    if not ok or not movement or not movement:IsValid() then
        ok = pcall(function()
            movement = pawn:GetMovementComponent()
        end)
    end

    if not ok or not movement or not movement:IsValid() then
        return pawn, nil, "character movement component was not found"
    end

    return pawn, movement, nil
end

local function getActivePlayerAndMovement()
    local pawn, movement, problem = getPlayerAndMovement()
    if problem then return nil, nil, problem end
    if not activePawn or not activePawn:IsValid()
        or not activeMovement or not activeMovement:IsValid()
        or pawn:GetAddress() ~= activePawn:GetAddress()
        or movement:GetAddress() ~= activeMovement:GetAddress() then
        return nil, nil, "player character changed; toggle flight off and on again"
    end
    return pawn, movement, nil
end

local probeSamplesRemaining = 0
local probeReason = ""

local function diagnosticValue(read)
    local ok, value = pcall(read)
    return ok and tostring(value) or ("ERROR: " .. tostring(value))
end

local function vectorLength(vector)
    local x, y, z = tonumber(vector.X), tonumber(vector.Y), tonumber(vector.Z)
    if not x or not y or not z then error("vector fields are not numeric") end
    return math.sqrt(x * x + y * y + z * z)
end

local function logFlightSnapshot(reason)
    local pawn, movement, problem = getPlayerAndMovement()
    if problem then
        log("PROBE " .. reason .. ": " .. problem)
        return
    end
    local values = {
        "requested=" .. tostring(flySpeed),
        "mode=" .. diagnosticValue(function() return movement.MovementMode end),
        "MaxFlySpeed=" .. diagnosticValue(function() return movement.MaxFlySpeed end),
        "baseSpeed=" .. diagnosticValue(function() return movement.TLCFlightBaseClimbSpeed end),
        "GetMaxSpeed=" .. diagnosticValue(function() return movement:GetMaxSpeed() end),
        "MaxAcceleration=" .. diagnosticValue(function() return movement.MaxAcceleration end),
        "acceleration=" .. diagnosticValue(function() return vectorLength(movement.Acceleration) end),
        "velocity=" .. diagnosticValue(function() return vectorLength(pawn:GetVelocity()) end),
        "FluidFriction=" .. diagnosticValue(function()
            local volume = movement:GetPhysicsVolume()
            if not volume or not volume:IsValid() then return "no volume" end
            return volume.FluidFriction
        end),
        "component=" .. diagnosticValue(function() return movement:GetFullName() end),
    }
    log("PROBE " .. reason .. ": " .. table.concat(values, " | "))
end

local function armFlightProbe(reason)
    probeReason = reason
    probeSamplesRemaining = 3
    logFlightSnapshot(reason .. " (immediate)")
end

-- Read-only samples on the game thread. Keep one callback pinned for UE4SS.
local probeTick = require("ModMenu.core.util").PinFn(function()
    if not flightEnabled or probeSamplesRemaining <= 0 then return end
    logFlightSnapshot(probeReason .. " (sample " .. tostring(4 - probeSamplesRemaining) .. ")")
    probeSamplesRemaining = probeSamplesRemaining - 1
end)
LoopInGameThreadWithDelay(1000, probeTick)

local function enableFlight()
    local pawn, movement, problem = getPlayerAndMovement()
    if problem then
        log("Cannot enable flight: " .. problem)
        return false, problem
    end

    local ready, speedProblem = pcall(function()
        prepareSpeedProperty()
        local base = movement.TLCFlightBaseClimbSpeed
        assert(type(base) == "number" and base > 0 and base < 10000000,
            "Game's cached movement speed is not valid")
        savedMovementMode = movement.MovementMode
        savedCustomMovementMode = movement.CustomMovementMode
        savedMaxFlySpeed = movement.MaxFlySpeed
        savedBaseClimbSpeed = base
    end)
    if not ready then
        log("Cannot enable flight: " .. tostring(speedProblem))
        return false, tostring(speedProblem)
    end

    activePawn = pawn
    activeMovement = movement

    local ok, err = pcall(function()
        applyFlightSpeed(movement)
        movement:SetMovementMode(MOVE_FLYING, 0)
    end)

    if not ok then
        pcall(function()
            movement.TLCFlightBaseClimbSpeed = savedBaseClimbSpeed
            movement.MaxFlySpeed = savedMaxFlySpeed
            movement:SetMovementMode(savedMovementMode, savedCustomMovementMode)
        end)
        activePawn = nil
        activeMovement = nil
        log("Could not switch movement mode: " .. tostring(err))
        return false, tostring(err)
    end

    flightEnabled = true
    updateMenuStatus()
    log(string.format("Flight ON - speed %d, rise %s, lower %s", flySpeed, riseKey, lowerKey))
    armFlightProbe("flight enabled")
    return true, "Flight ON"
end

local function disableFlight()
    -- Restore only the component whose original values we captured. A new save,
    -- respawn or possession must not receive another character's saved values.
    local movement = activeMovement

    if movement and movement:IsValid() then
        if savedBaseClimbSpeed ~= nil then
            pcall(function()
                movement.TLCFlightBaseClimbSpeed = savedBaseClimbSpeed
            end)
        end
        pcall(function()
            movement:SetMovementMode(savedMovementMode or MOVE_WALKING, savedCustomMovementMode or 0)
        end)
        if savedMaxFlySpeed ~= nil then
            pcall(function()
                movement.MaxFlySpeed = savedMaxFlySpeed
            end)
        end
    end

    flightEnabled = false
    probeSamplesRemaining = 0
    activePawn = nil
    activeMovement = nil
    savedBaseClimbSpeed = nil
    updateMenuStatus()
    log("Flight OFF")
    return true, "Flight OFF"
end

local function toggleFlight()
    if flightEnabled then
        return disableFlight()
    end
    return enableFlight()
end

local function moveVertical(amount)
    if not flightEnabled then
        log("Flight is off; enable it first")
        return false, "Flight is off"
    end

    local pawn, movement, problem = getActivePlayerAndMovement()
    if problem then
        log("Cannot move vertically: " .. problem)
        return false, problem
    end

    pcall(function()
        movement:SetMovementMode(MOVE_FLYING, 0)
        applyFlightSpeed(movement)
    end)

    local ok, err = pcall(function()
        local location = pawn:K2_GetActorLocation()
        location.Z = location.Z + amount
        pawn:K2_SetActorLocation(location, true, {}, false)
    end)

    if not ok then
        log("Vertical movement failed: " .. tostring(err))
        return false, tostring(err)
    end

    return true, amount > 0 and "Rising" or "Lowering"
end

local function runOnGameThread(action)
    ExecuteInGameThread(function()
        local ok, err = pcall(action)
        if not ok then
            log("Unexpected error: " .. tostring(err))
        end
    end)
end

local function routeBoundKey(keyName)
    if keyName == toggleKey then
        runOnGameThread(toggleFlight)
    elseif keyName == riseKey then
        runOnGameThread(function()
            moveVertical(verticalStep)
        end)
    elseif keyName == lowerKey then
        runOnGameThread(function()
            moveVertical(-verticalStep)
        end)
    end
end

local function bindOption(option)
    if option.key == nil then return end
    local keyName = option.value
    RegisterKeyBind(option.key, function()
        routeBoundKey(keyName)
    end)
end

for _, option in ipairs(TOGGLE_KEYS) do bindOption(option) end
for _, option in ipairs(RISE_KEYS) do bindOption(option) end
for _, option in ipairs(LOWER_KEYS) do bindOption(option) end

local function setFlySpeed(value)
    flySpeed = normalizeNumber(value, DEFAULTS.flySpeed, LIMITS.flySpeed)
    Config.Set("flySpeed", flySpeed)
    -- The numeric widget can clamp a value without changing its visible text.
    -- Set synchronizes that text without recursively invoking onChange.
    ModMenu.Set("Flight", "speed", flySpeed)
    if flightEnabled then
        runOnGameThread(function()
            if not flightEnabled then return end
            local _, movement, problem = getActivePlayerAndMovement()
            if problem then log("Cannot apply speed: " .. problem); return end
            applyFlightSpeed(movement)
            armFlightProbe("speed edit")
        end)
    end
end

local function setVerticalStep(value)
    verticalStep = normalizeNumber(value, DEFAULTS.verticalStep, LIMITS.verticalStep)
    Config.Set("verticalStep", verticalStep)
    ModMenu.Set("Flight", "verticalStep", verticalStep)
end

local function restoreDefaults()
    flySpeed = DEFAULTS.flySpeed
    verticalStep = DEFAULTS.verticalStep
    toggleKey = DEFAULTS.toggleKey
    riseKey = DEFAULTS.riseKey
    lowerKey = DEFAULTS.lowerKey

    Config.Set("flySpeed", flySpeed)
    Config.Set("verticalStep", verticalStep)
    Config.Set("toggleKey", toggleKey)
    Config.Set("riseKey", riseKey)
    Config.Set("lowerKey", lowerKey)

    ModMenu.Set("Flight", "speed", flySpeed)
    ModMenu.Set("Flight", "verticalStep", verticalStep)
    ModMenu.Set("Keybinds", "toggleKey", toggleKey)
    ModMenu.Set("Keybinds", "riseKey", riseKey)
    ModMenu.Set("Keybinds", "lowerKey", lowerKey)

    if flightEnabled then
        runOnGameThread(function()
            if not flightEnabled then return end
            local _, movement, problem = getActivePlayerAndMovement()
            if problem then log("Cannot apply speed: " .. problem); return end
            applyFlightSpeed(movement)
        end)
    end
    log("Settings restored to defaults")
end

ModMenu.Init({
    title = "TLC Player Flight",
    instanceId = "TLCPlayerFlight",
    key = Key.F7,
    keyHint = "F7",
    inputBackend = "ue4ss",
    consoleCommand = "tlcflightmenu",
    dock = tostring(Config.Get("dock") or DEFAULTS.dock),
    widthFrac = 0.30,
    fontScale = 1.0,
    theme = "dark",
    ignoreLook = true,
    showClose = true,
    tabs = { "Flight", "Keybinds" },
})

ModMenu.OnDockChange(function(side)
    Config.Set("dock", side)
end)

ModMenu.Register({
    id = "Flight",
    title = "Player Flight",
    tab = "Flight",
    items = {
        { type = "label", id = "status", label = "Status: flight off" },
        {
            type = "button",
            id = "toggle",
            label = "Enable Flight",
            variant = "success",
            onClick = function()
                runOnGameThread(toggleFlight)
            end,
        },
        { type = "separator" },
        {
            type = "number",
            id = "speed",
            label = "Flight base speed (cm/s)",
            default = flySpeed,
            min = LIMITS.flySpeed.min,
            max = LIMITS.flySpeed.max,
            integer = true,
            fieldWidth = 100,
            labelWidth = 190,
            -- No pending edit to lose when the panel closes or rebuilds.
            debounceMs = 0,
            onChange = setFlySpeed,
        },
        { type = "label", label = "Speed range: 100-50000 cm/s." },
        { type = "label", label = "Game weight, cold and sprint modifiers still apply." },
        {
            type = "number",
            id = "verticalStep",
            label = "Rise/lower step (cm)",
            default = verticalStep,
            min = LIMITS.verticalStep.min,
            max = LIMITS.verticalStep.max,
            integer = true,
            fieldWidth = 100,
            labelWidth = 190,
            debounceMs = 0,
            onChange = setVerticalStep,
        },
        { type = "label", label = "Rise/lower range: 10-10000 cm." },
        { type = "label", label = "Collision stays enabled. Settings save automatically." },
        {
            type = "button",
            id = "reset",
            label = "Restore Defaults",
            variant = "secondary",
            onClick = restoreDefaults,
        },
    },
})

ModMenu.Register({
    id = "Keybinds",
    title = "Flight Keybinds",
    tab = "Keybinds",
    items = {
        { type = "label", label = "F7 always opens/closes this menu." },
        {
            type = "dropdown",
            id = "toggleKey",
            label = "Toggle flight",
            options = TOGGLE_KEYS,
            default = toggleKey,
            onChange = function(value)
                toggleKey = value
                Config.Set("toggleKey", value)
            end,
        },
        {
            type = "dropdown",
            id = "riseKey",
            label = "Rise",
            options = RISE_KEYS,
            default = riseKey,
            onChange = function(value)
                riseKey = value
                Config.Set("riseKey", value)
            end,
        },
        {
            type = "dropdown",
            id = "lowerKey",
            label = "Lower",
            options = LOWER_KEYS,
            default = lowerKey,
            onChange = function(value)
                lowerKey = value
                Config.Set("lowerKey", value)
            end,
        },
        { type = "label", label = "Changes apply immediately and persist after restart." },
    },
})

RegisterConsoleCommandHandler("tlcflightstatus", function(_, _, outputDevice)
    if outputDevice then outputDevice:Log("Flight probe queued; fly forward for 3 seconds, then check UE4SS.log") end
    runOnGameThread(function() armFlightProbe("console request") end)
    return true
end)

RegisterConsoleCommandHandler("tlcfly", function(_, _, outputDevice)
    if outputDevice then outputDevice:Log("TLC flight toggle queued") end
    runOnGameThread(toggleFlight)
    return true
end)

RegisterConsoleCommandHandler("tlcup", function(_, parameters, outputDevice)
    local amount = tonumber(parameters[1]) or verticalStep
    if outputDevice then outputDevice:Log("TLC rise queued") end
    runOnGameThread(function()
        moveVertical(math.abs(amount))
    end)
    return true
end)

RegisterConsoleCommandHandler("tlcdown", function(_, parameters, outputDevice)
    local amount = tonumber(parameters[1]) or verticalStep
    if outputDevice then outputDevice:Log("TLC lower queued") end
    runOnGameThread(function()
        moveVertical(-math.abs(amount))
    end)
    return true
end)

updateMenuStatus()
log(string.format("Loaded v%s for game build %s - F7 opens settings; configured flight keys are active", MOD_VERSION, TARGET_BUILD))
