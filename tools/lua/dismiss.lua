-- dismiss the hired pawns through the game's own PawnManager.dismissPawn(app.Character)
local pm = sdk.get_managed_singleton("app.PawnManager"); local main = pm:get_field("_MainPawn"); local mc = main and main:call("get_CachedCharacter")
local l = pm:call("get_PawnCharacterList"); local hired = {}
for i = 0, l:call("get_Count") - 1 do local ch = l:call("get_Item", i); if ch and (not mc or ch:get_address() ~= mc:get_address()) then hired[#hired + 1] = ch end end
local n = 0
for _, ch in ipairs(hired) do local ok, e = pcall(function() pm:call("dismissPawn(app.Character)", ch) end); if ok then n = n + 1 else out("dismiss error", tostring(e)) end end
out("dismissed", n, "partyNum", tostring(pm:call("getPartyPawnNum")))
