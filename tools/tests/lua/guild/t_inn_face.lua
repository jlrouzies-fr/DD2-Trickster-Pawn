local im = sdk.get_managed_singleton("app.InteractManager")
local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer")
local ptf = pl:call("get_Transform"); local pp = ptf:call("get_UniversalPosition")
-- all interactive objects whose owner is a character (ch*)
local hs = im:get_field("InteractiveObjects"); local en = hs:call("GetEnumerator")
while en:call("MoveNext") do
  local o = en:call("get_Current")
  pcall(function()
    local go = o:get_field("<Owner>k__BackingField"); local n = go:call("get_Name")
    if n:sub(1,2) == "ch" then
      local up = go:call("get_Transform"):call("get_UniversalPosition")
      local d = math.sqrt((up.x-pp.x)^2+(up.y-pp.y)^2+(up.z-pp.z)^2)
      out("chIO", n, string.format("d=%.1f", d), "enable", tostring(o:call("isInteractEnable(app.Character)", pl)), "can", tostring(o:call("canPlayerInteract", 0)), "pts", tostring(o:call("get_NumInteractPoints")))
    end
  end)
end
-- innkeeper
local nm = sdk.get_managed_singleton("app.NPCManager"); local fl = nm:call("get_NPCHolder_FullList")
for i = 0, fl:call("get_Count")-1 do
  local h = fl:call("get_Item", i)
  if h and h:get_field("CharaID") == 4052630797 then
    local up = h:call("get_UniversalPosition")
    local dx, dz = up.x - pp.x, up.z - pp.z
    local yaw = math.atan(dx, dz)
    local q = Quaternion.new(0, math.sin(yaw/2), 0, math.cos(yaw/2))
    ptf:call("set_Rotation", q)
    out("faced innkeeper", string.format("dx=%.2f dz=%.2f yaw=%.2f", dx, dz, yaw))
    local te = sdk.get_managed_singleton("app.TalkEventManager")
    local ch = h:call("get_chara")
    local ok, v = pcall(function() return te:call("canTalkEventInteract", ch) end); out("canTalkEventInteract", ok, tostring(v))
    break
  end
end
