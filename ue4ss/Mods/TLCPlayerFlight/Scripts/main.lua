local UEHelpers = require("UEHelpers")
local ModMenu = require("ModMenu.ModMenu")
local Config = ModMenu.ConfigManager

local MOD_NAME = "TLCPlayerFlight"
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

local flySpeed = tonumber(Config.Get("flySpeed")) or DEFAULTS.flySpeed
local verticalStep = tonumber(Config.Get("verticalStep")) or DEFAULTS.verticalStep
local toggleKey = tostring(Config.Get("toggleKey") or DEFAULTS.toggleKey)
local riseKey = tostring(Config.Get("riseKey") or DEFAULTS.riseKey)
local lowerKey = tostring(Config.Get("lowerKey") or DEFAULTS.lowerKey)

local flightEnabled = false
local activePawn = nil
local activeMovement = nil
local savedMovementMode = MOVE_WALKING
local savedCustomMovementMode = 0
local savedMaxFlySpeed = nil

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

local function enableFlight()
    local pawn, movement, problem = getPlayerAndMovement()
    if problem then
        log("Cannot enable flight: " .. problem)
        return false, problem
    end

    activePawn = pawn
    activeMovement = movement

    pcall(function()
        savedMovementMode = movement.MovementMode
        savedCustomMovementMode = movement.CustomMovementMode
        savedMaxFlySpeed = movement.MaxFlySpeed
        movement.MaxFlySpeed = flySpeed
    end)

    local ok, err = pcall(function()
        movement:SetMovementMode(MOVE_FLYING, 0)
    end)

    if not ok then
        activePawn = nil
        activeMovement = nil
        log("Could not switch movement mode: " .. tostring(err))
        return false, tostring(err)
    end

    flightEnabled = true
    updateMenuStatus()
    log(string.format("Flight ON - speed %d, rise %s, lower %s", flySpeed, riseKey, lowerKey))
    return true, "Flight ON"
end

local function disableFlight()
    local pawn, movement = getPlayerAndMovement()
    if activePawn and activePawn:IsValid() then
        pawn = activePawn
    end
    if activeMovement and activeMovement:IsValid() then
        movement = activeMovement
    end

    if movement and movement:IsValid() then
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
    activePawn = nil
    activeMovement = nil
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

    local pawn, movement, problem = getPlayerAndMovement()
    if problem then
        log("Cannot move vertically: " .. problem)
        return false, problem
    end

    pcall(function()
        movement:SetMovementMode(MOVE_FLYING, 0)
        movement.MaxFlySpeed = flySpeed
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
    flySpeed = math.max(100, math.min(5000, math.floor(tonumber(value) or DEFAULTS.flySpeed)))
    Config.Set("flySpeed", flySpeed)
    if flightEnabled then
        runOnGameThread(function()
            local _, movement = getPlayerAndMovement()
            if movement and movement:IsValid() then movement.MaxFlySpeed = flySpeed end
        end)
    end
end

local function setVerticalStep(value)
    verticalStep = math.max(10, math.min(1000, math.floor(tonumber(value) or DEFAULTS.verticalStep)))
    Config.Set("verticalStep", verticalStep)
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
            local _, movement = getPlayerAndMovement()
            if movement and movement:IsValid() then movement.MaxFlySpeed = flySpeed end
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
            label = "Flight speed (cm/s)",
            default = flySpeed,
            min = 100,
            max = 5000,
            integer = true,
            fieldWidth = 100,
            labelWidth = 190,
            debounceMs = 250,
            onChange = setFlySpeed,
        },
        {
            type = "number",
            id = "verticalStep",
            label = "Rise/lower step (cm)",
            default = verticalStep,
            min = 10,
            max = 1000,
            integer = true,
            fieldWidth = 100,
            labelWidth = 190,
            debounceMs = 250,
            onChange = setVerticalStep,
        },
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
log("Loaded - F7 opens settings; configured flight keys are active")
