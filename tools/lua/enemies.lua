-- loaded enemies: character id (species), distance to the Arisen, hp
local em = sdk.get_managed_singleton("app.EnemyManager"); local l = em:get_field("_EnemyList"); local n = l:call("get_Count")
local cm = sdk.get_managed_singleton("app.CharacterManager"); local pl = cm:call("get_ManualPlayer"); local pp = pl:call("get_Transform"):call("get_Position")
local t = {}
for i = 0, n - 1 do
  local ok, s = pcall(function()
    local ec = l:call("get_Item", i); local ch = ec:call("get_Chara"); local p = ch:call("get_Transform"):call("get_Position")
    local d = math.sqrt((p.x-pp.x)^2 + (p.y-pp.y)^2 + (p.z-pp.z)^2)
    return string.format("%s d=%.0f dy=%.0f hp=%.0f", tostring(ch:call("get_GameObject"):call("get_Name")), d, p.y - pp.y, ch:call("get_Hp"))
  end)
  if ok then t[#t+1] = s end
end
out("enemies " .. n, table.concat(t, " | "))
