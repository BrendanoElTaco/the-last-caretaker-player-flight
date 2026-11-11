"""Run with Python + lupa. Uses the real bundled numeric widget/config store.
UE4SS objects, game-thread scheduling, and file I/O are isolated in memory.
No game is launched and no installed config/save is touched.
"""
import importlib
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / "ue4ss/Mods/TLCPlayerFlight/Scripts/main.lua"
BUNDLE = ROOT / "ue4ss/Mods/shared/ModMenu/ModMenu.lua"

HARNESS = r'''
local h = {now=0, values={}, fields={}, controls={}, binds={}, commands={},
           queue={}, files={}, sections={}, z=0, logs={}}
-- Three small slices from the verified Update 6 executable. No game is run.
local layoutBytes = {
    [0x5574621]="8b860c100000898670110000",
    [0x559eccb]="440f2948b8f3440f108970110000",
    [0x559ee75]="f3440f118b94020000",
}
function h.invalidateLayout() layoutBytes[0x559ee75]="000000000000000000" end
PropertyTypes={FloatProperty={}}
RegisterCustomProperty=function(info) h.registeredProperty=info end
if INITIAL_CONFIG ~= nil then h.files["test/config.json"] = INITIAL_CONFIG end
print = function(message) h.logs[#h.logs+1] = tostring(message) end
os.clock = function() return h.now end
os.remove = function(path) h.files[path]=nil; return true end
os.rename = function(a,b) h.files[b]=h.files[a]; h.files[a]=nil; return true end
io.open = function(path, mode)
    mode = mode or "r"
    if mode == "rb" and path:match("VoyageSteam%-Win64%-Shipping%.exe$") then
        local offset=0
        return {
            seek=function(_,whence,position) assert(whence=="set"); offset=position; return offset end,
            read=function(_,size)
                local hex=assert(layoutBytes[offset],"unexpected executable read")
                local bytes=hex:gsub("..",function(pair) return string.char(tonumber(pair,16)) end)
                assert(#bytes==size)
                return bytes
            end,
            close=function() end,
        }
    end
    if mode == "r" then
        if h.files[path] == nil then return nil, "not found (virtual filesystem)" end
        return {read=function() return h.files[path] end, close=function() end}
    end
    if mode ~= "w" then error("unsupported virtual I/O mode: "..mode) end
    local parts = {}
    return {
        write=function(_,s) parts[#parts+1]=s end,
        close=function() h.files[path]=table.concat(parts) end,
    }
end
assert(load(BUNDLE_MODULES, "@ModMenu.bundle.modules"))()
local Util = require("ModMenu.core.util")
local Number = require("ModMenu.widgets.number")
local Config = require("ModMenu.core.store")
local initConfig = Config.Init
Config.Init = function(opts) opts.file="test/config.json"; return initConfig(opts) end
h.Config = Config
local movement = {MovementMode=1, CustomMovementMode=0, MaxFlySpeed=900,
                  TLCFlightBaseClimbSpeed=200,
                  MaxAcceleration=2048, Acceleration={X=0,Y=0,Z=0}}
function movement:IsValid() return true end
function movement:SetMovementMode(mode,custom)
    self.MovementMode=mode; self.CustomMovementMode=custom
end
function h.failMovementMode() error("simulated movement-mode failure") end
function movement:GetAddress() return 100 end
h.movement=movement
function movement:GetMaxSpeed() return h.speedOverride or self.MaxFlySpeed end
function movement:GetPhysicsVolume()
    return {IsValid=function() return true end, FluidFriction=0.3}
end
function movement:GetFullName() return "MockCharacterMovement" end
-- Reproduce the observed game behavior: every update overwrites MaxFlySpeed
-- from the cached climbing base, with weight/cold modifiers applied.
function h.gameUpdate(multiplier)
    movement.MaxFlySpeed=movement.TLCFlightBaseClimbSpeed*(multiplier or 0.55)
end
local pawn = {CharacterMovement=movement}
function pawn:GetAddress() return 200 end
function pawn:IsValid() return true end
function pawn:GetVelocity() return {X=0,Y=0,Z=0} end
function pawn:K2_GetActorLocation() return {X=0,Y=0,Z=h.z} end
function pawn:K2_SetActorLocation(location) h.z=location.Z end
local controller={Pawn=pawn, IsValid=function() return true end}
function h.replaceCharacter()
    local otherMovement={MovementMode=1, MaxFlySpeed=777, TLCFlightBaseClimbSpeed=333}
    function otherMovement:IsValid() return true end
    function otherMovement:GetAddress() return 101 end
    local otherPawn={CharacterMovement=otherMovement}
    function otherPawn:IsValid() return true end
    function otherPawn:GetAddress() return 201 end
    controller.Pawn=otherPawn
    h.otherMovement=otherMovement
end
package.loaded["UEHelpers"]={GetPlayerController=function() return controller end}
Key=setmetatable({}, {__index=function(_,name) return name end})
RegisterKeyBind=function(key,fn) h.binds[key]=fn end
RegisterConsoleCommandHandler=function(name,fn) h.commands[name]=fn end
ExecuteInGameThread=function(fn) h.queue[#h.queue+1]=fn end
LoopInGameThreadWithDelay=function(_,fn) h.sample=fn; return 1 end
FText=function(text) return text end
function h.flush()
    while #h.queue>0 do local fn=table.remove(h.queue,1); fn() end
end
local Menu={ConfigManager=Config}
local function buildNumber(section,item)
    local ctx={
        section=section,item=item,values=h.values,ValueKey=Util.ValueKey,
        config={fontItem=14},liveControls={},namePrefix="test",
        umg={
            CreateLabeledEditable=function(_,_,_,text)
                local edit={text=text}
                function edit:GetText() return self.text end
                function edit:SetText(value) self.text=value end
                return {},edit,{}
            end,
            AddToContent=function() end,AddItemPad=function() end,
        },
    }
    Number.build(ctx)
    h.controls[section.id.."."..item.id]=ctx.liveControls[1]
end
function Menu.Init(opts) h.menuOptions=opts end
function Menu.OnDockChange(fn) h.onDockChange=fn end
function Menu.Register(section)
    h.sections[section.id]=section
    for _,item in ipairs(section.items) do
        if item.id then
            local key=section.id.."."..item.id
            h.fields[key]=item
            if item.type=="number" then
                Number.validate(item,section.id,1)
                Number.seed(section.id,item,h.values)
                buildNumber(section,item)
            elseif item.default~=nil then h.values[key]=item.default end
        end
    end
end
function Menu.Set(section,id,value)
    local key=section.."."..id
    if h.controls[key] then Number.apply(h.controls[key],value,{values=h.values})
    else h.values[key]=value end
end
Menu.SetLabel=function() end
Menu.SetButtonLabel=function() end
Menu.SetButtonActive=function() end
package.loaded["ModMenu.ModMenu"]=Menu
assert(load(MAIN_SOURCE,"@TLCPlayerFlight/Scripts/main.lua"))()
function h.type(id,text,wait)
    local ctrl=assert(h.controls["Flight."..id])
    ctrl.edit.text=tostring(text)
    Number.poll(ctrl,{values=h.values})
    h.now=h.now+(wait or 0.3)
    Number.poll(ctrl,{values=h.values})
    h.flush()
end
function h.get(key) return Config.Get(key) end
function h.text(id) return h.controls["Flight."..id].edit.text end
function h.press(key) assert(h.binds[key],"unbound test key")(); h.flush() end
function h.reset() h.fields["Flight.reset"].onClick(); h.flush() end
function h.dropdown(id,key) h.fields["Keybinds."..id].onChange(key) end
function h.saved() return h.files["test/config.json"] end
function h.probe() h.commands.tlcflightstatus(nil,{},nil); h.flush() end
return h
'''

class SettingsTests(unittest.TestCase):
    runtime_module = "lupa.lua54"

    def harness(self, initial=None):
        runtime = importlib.import_module(self.runtime_module).LuaRuntime(
            unpack_returned_tuples=True
        )
        runtime.globals().BUNDLE_MODULES = BUNDLE.read_text(
            encoding="utf-8"
        ).split("-- ModMenu.lua (entry)", 1)[0]
        runtime.globals().MAIN_SOURCE = MAIN.read_text(encoding="utf-8")
        runtime.globals().INITIAL_CONFIG = initial
        return runtime.execute(HARNESS)

    def test_reported_6000_speed_reaches_live_movement(self):
        h = self.harness()
        h.press("F6")
        h.type("speed", "6000")
        self.assertEqual(h.get("flySpeed"), 6000)
        self.assertEqual(h.movement.MaxFlySpeed, 6000)
        self.assertEqual(h.text("speed"), "6000")

    def test_game_reset_preserves_selected_speed_ratio(self):
        h = self.harness()
        h.press("F6")
        h.gameUpdate(0.55)
        self.assertAlmostEqual(h.movement.MaxFlySpeed, 660)
        h.type("speed", "6000")
        for _ in range(120):
            h.gameUpdate(0.55)
        self.assertAlmostEqual(h.movement.MaxFlySpeed, 3300)
        h.gameUpdate(0.25)
        self.assertEqual(h.movement.MaxFlySpeed, 1500)

    def test_stock_cached_base_restored_when_flight_disabled(self):
        h = self.harness()
        h.type("speed", "6000")
        self.assertEqual(h.movement.TLCFlightBaseClimbSpeed, 200)
        h.press("F6")
        h.gameUpdate(0.55)
        h.press("F6")
        self.assertEqual(h.movement.TLCFlightBaseClimbSpeed, 200)
        h.gameUpdate(0.55)
        self.assertAlmostEqual(h.movement.MaxFlySpeed, 110)

    def test_restore_defaults_updates_cached_base(self):
        h = self.harness()
        h.press("F6")
        h.type("speed", "6000")
        h.reset()
        h.gameUpdate(0.55)
        self.assertAlmostEqual(h.movement.MaxFlySpeed, 660)

    def test_unsupported_executable_layout_fails_without_movement_writes(self):
        h = self.harness()
        h.invalidateLayout()
        h.press("F6")
        self.assertIsNone(h.registeredProperty)
        self.assertEqual(h.movement.MaxFlySpeed, 900)
        self.assertEqual(h.movement.TLCFlightBaseClimbSpeed, 200)
        self.assertEqual(h.movement.MovementMode, 1)
        self.assertIn("Unsupported game movement layout", h.logs[len(h.logs)])

    def test_partial_enable_failure_restores_both_speed_fields(self):
        h = self.harness()
        h.movement.SetMovementMode = h.failMovementMode
        h.press("F6")
        self.assertEqual(h.movement.MaxFlySpeed, 900)
        self.assertEqual(h.movement.TLCFlightBaseClimbSpeed, 200)
        self.assertEqual(h.movement.MovementMode, 1)
        self.assertIn("Could not switch movement mode", h.logs[len(h.logs)])

    def test_character_change_never_writes_uncaptured_movement(self):
        h = self.harness()
        h.press("F6")
        h.replaceCharacter()
        h.type("speed", "6000")
        h.press("PAGE_UP")
        h.press("F6")
        self.assertEqual(h.otherMovement.MaxFlySpeed, 777)
        self.assertEqual(h.otherMovement.TLCFlightBaseClimbSpeed, 333)
        self.assertEqual(h.otherMovement.MovementMode, 1)
        self.assertEqual(h.movement.TLCFlightBaseClimbSpeed, 200)
        self.assertEqual(h.z, 0)

    def test_queued_edit_does_not_reapply_after_disable(self):
        h = self.harness()
        h.press("F6")
        h.binds["F6"]()
        h.fields["Flight.speed"].onChange(6000)
        h.flush()
        self.assertEqual(h.get("flySpeed"), 6000)
        self.assertEqual(h.movement.MaxFlySpeed, 900)
        self.assertEqual(h.movement.TLCFlightBaseClimbSpeed, 200)
        self.assertEqual(h.movement.MovementMode, 1)

    def test_step_above_old_cap_controls_rise_and_lower(self):
        h = self.harness()
        h.press("F6")
        h.type("verticalStep", "6000")
        self.assertEqual(h.get("verticalStep"), 6000)
        h.press("PAGE_UP")
        self.assertEqual(h.z, 6000)
        h.press("PAGE_DOWN")
        self.assertEqual(h.z, 0)

    def test_numeric_edits_apply_without_debounce_wait(self):
        h = self.harness()
        h.press("F6")
        h.type("speed", "3500", 0)
        h.type("verticalStep", "750", 0)
        self.assertEqual(h.get("flySpeed"), 3500)
        self.assertEqual(h.movement.MaxFlySpeed, 3500)
        self.assertEqual(h.get("verticalStep"), 750)

    def test_above_limit_text_matches_saved_and_applied_value(self):
        h = self.harness()
        h.press("F6")
        h.type("speed", "999999")
        h.type("verticalStep", "999999")
        self.assertEqual(h.get("flySpeed"), 50000)
        self.assertEqual(h.movement.MaxFlySpeed, 50000)
        self.assertEqual(h.text("speed"), "50000")
        self.assertEqual(h.get("verticalStep"), 10000)
        self.assertEqual(h.text("verticalStep"), "10000")

    def test_saved_custom_values_survive_restart(self):
        h = self.harness()
        h.type("speed", "6000")
        h.type("verticalStep", "2500")
        saved = h.saved()
        self.assertEqual(json.loads(saved)["flySpeed"], 6000)
        restarted = self.harness(saved)
        restarted.press("F6")
        self.assertEqual(restarted.movement.MaxFlySpeed, 6000)
        restarted.press("PAGE_UP")
        self.assertEqual(restarted.z, 2500)

    def test_disabled_flight_does_not_change_stock_speed(self):
        h = self.harness()
        h.type("speed", "6000")
        self.assertEqual(h.movement.MaxFlySpeed, 900)
        h.press("F6")
        self.assertEqual(h.movement.MaxFlySpeed, 6000)
        h.press("F6")
        self.assertEqual(h.movement.MaxFlySpeed, 900)
        self.assertEqual(h.movement.MovementMode, 1)

    def test_restore_defaults_applies_and_preserves_stock_restore(self):
        h = self.harness()
        h.press("F6")
        h.type("speed", "6000")
        h.type("verticalStep", "2500")
        h.reset()
        self.assertEqual(h.get("flySpeed"), 1200)
        self.assertEqual(h.movement.MaxFlySpeed, 1200)
        self.assertEqual(h.get("verticalStep"), 100)
        self.assertEqual(h.text("speed"), "1200")
        h.press("F6")
        self.assertEqual(h.movement.MaxFlySpeed, 900)

    def test_keybinds_still_use_custom_step(self):
        h = self.harness()
        h.type("verticalStep", "2500")
        h.dropdown("toggleKey", "F8")
        h.dropdown("riseKey", "HOME")
        h.dropdown("lowerKey", "END")
        h.press("F6")
        self.assertEqual(h.movement.MovementMode, 1)
        h.press("F8")
        h.press("HOME")
        self.assertEqual(h.z, 2500)
        h.press("END")
        self.assertEqual(h.z, 0)

    def test_loaded_values_are_normalized_without_losing_other_keys(self):
        h = self.harness(json.dumps({
            "flySpeed": 999999, "verticalStep": -20, "extra": "preserve",
        }))
        self.assertEqual(h.get("flySpeed"), 50000)
        self.assertEqual(h.get("verticalStep"), 10)
        h.press("F6")
        self.assertEqual(h.movement.MaxFlySpeed, 50000)
        self.assertEqual(json.loads(h.saved())["extra"], "preserve")

    def test_nonfinite_loaded_values_use_safe_defaults(self):
        h = self.harness('{"flySpeed":"nan","verticalStep":"1e999"}')
        h.press("F6")
        self.assertEqual(h.movement.MaxFlySpeed, 1200)
        self.assertEqual(h.get("verticalStep"), 100)

    def test_diagnostics_distinguish_requested_and_effective_speed(self):
        h = self.harness()
        h.speedOverride = 300
        h.press("F6")
        h.type("speed", "6000")
        self.assertIn("requested=6000", h.logs[len(h.logs)])
        self.assertIn("MaxFlySpeed=6000", h.logs[len(h.logs)])
        self.assertIn("GetMaxSpeed=300", h.logs[len(h.logs)])
        self.assertEqual(h.movement.MaxFlySpeed, 6000)

    def test_diagnostics_take_three_samples_then_stop(self):
        h = self.harness()
        h.press("F6")
        before = len(h.logs)
        for _ in range(5):
            h.sample()
        self.assertEqual(len(h.logs), before + 3)
        h.press("F6")
        before = len(h.logs)
        h.sample()
        self.assertEqual(len(h.logs), before)

    def test_status_probe_does_not_enable_flight(self):
        h = self.harness()
        h.probe()
        self.assertIn("PROBE console request", h.logs[len(h.logs)])
        self.assertEqual(h.movement.MovementMode, 1)
        self.assertEqual(h.movement.MaxFlySpeed, 900)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1].startswith("lupa."):
        SettingsTests.runtime_module = sys.argv.pop(1)
    unittest.main(verbosity=2)
