local pl = sdk.get_managed_singleton("app.CharacterManager"):call("get_ManualPlayer"); local human = pl:call("get_Human")
local jc = human:get_field("<JobContext>k__BackingField")
local am = pl:call("get_ActionManager"); local items = am:get_field("CurrentActionList"):get_field("_items")
local j9 = human:get_field("<Job09ActionCtrl>k__BackingField"); local dh = j9 and j9:call("get_DecoyHandler")
local rows = {}; pcall(function() for _, r in ipairs(PawnTrickster.censer_rows()) do rows[#rows + 1] = r.name .. " (" .. r.id .. "): " .. r.where end end)
out("Arisen job", tostring(jc:get_field("CurrentJob")), "weapon job", tostring(pl:call("getWeaponJob")), "action", items[0] and tostring(items[0]:get_field("Name")) or "?", "hp", tostring(pl:call("get_Hp")),
  "own decoy handler", tostring(dh ~= nil), "decoy out", tostring(dh and dh:call("get_HasInstance")), "| censers: " .. table.concat(rows, "; "))
