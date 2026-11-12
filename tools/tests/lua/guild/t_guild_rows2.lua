local gm = sdk.get_managed_singleton("app.GuiManager"); local l = gm:get_field("_GUIList"); local g
for i = 0, l:call("get_Count")-1 do local x = l:call("get_Item", i); if x and x:get_type_definition():get_full_name() == "app.ui040101_00" then g = x end end
local lc = g:get_field("_Main_ContentsListCtrl"); local il = lc:get_field("InfoList"); local n = il:call("get_Count"); out("InfoList", n)
for i = 0, n-1 do local info = il:call("get_Item", i); local is = {}
  for _, ff in ipairs(info:get_type_definition():get_fields()) do local vv; pcall(function() vv = info:get_field(ff:get_name()) end); local s = tostring(vv)
    if type(vv) == "userdata" then local sub = {}; pcall(function() for _, sf in ipairs(vv:get_type_definition():get_fields()) do local sv; pcall(function() sv = vv:get_field(sf:get_name()) end); if type(sv) ~= "userdata" then sub[#sub+1] = sf:get_name() .. "=" .. tostring(sv) end end end); s = "{" .. table.concat(sub, ",") .. "}" end
    is[#is+1] = ff:get_name() .. "=" .. s end
  out("row", i, table.concat(is, " "))
end
local pm = sdk.get_managed_singleton("app.PawnManager"); local mp = pm:get_field("_MainPawn")
out("mainpawn", tostring(mp ~= nil), mp and mp:get_type_definition():get_full_name() or "")
local ok, err = pcall(function()
  local ch = mp
  if mp:get_type_definition():get_full_name() ~= "app.Character" then ch = mp:call("get_Character") or mp:get_field("<Character>k__BackingField") or mp:get_field("Chara") end
  local hu = ch:call("get_GameObject"):call("getComponent(System.Type)", sdk.typeof("app.Human")); local jc = hu:call("get_JobContext")
  out("pawn job", tostring(jc:call("get_CurrentJob")), "qualifiedBits", tostring(jc:get_field("QualifiedJobBits")), "exp9", tostring(jc:call("getJobExp", 9)), "rank9", tostring(jc:call("calcJobRank", 9)), "exp3", tostring(jc:call("getJobExp", 3)))
end); out("pawn job read", ok, err or "")
