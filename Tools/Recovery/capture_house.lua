-- Read-only scene reflection for the user-authorized original game.
-- Invoked by the isolated harness; never installed in the original package.
local function q(s)
 return '"' .. tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','') .. '"'
end
local function v(t) return string.format('[%.9f,%.9f,%.9f]',t.X,t.Y,t.Z) end
local function capture()
 local rows,lights,errors={},{},{}
 local function add(c,name,t,materials)
  local r=t.Rotation
  rows[#rows+1]='{"name":'..q(name)..',"mesh":'..q(c.StaticMesh:GetFullName())..',"position":'..v(t.Translation)..',"quaternion":'..string.format('[%.9f,%.9f,%.9f,%.9f]',r.X,r.Y,r.Z,r.W)..',"scale":'..v(t.Scale3D)..',"materials":['..table.concat(materials,',')..']}'
 end
 for _,c in ipairs(FindAllOf('StaticMeshComponent') or {}) do
  local ok,err=pcall(function()
   local name=c:GetFullName()
   if name:find('/Game/Maps/Map_House.') and name:find('PersistentLevel') and c.StaticMesh:IsValid() then
    local materials={}
    for i=0,c:GetNumMaterials()-1 do
     local m=c:GetMaterial(i)
     materials[#materials+1]=q(m:IsValid() and m:GetFullName() or '')
    end
    if c:IsA('/Script/Engine.InstancedStaticMeshComponent') then
     for i=0,c:GetInstanceCount()-1 do
      local t={Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}}
      if c:GetInstanceTransform(i,t,true) then add(c,name..'_Instance_'..i,t,materials) end
     end
    else add(c,name,c:K2_GetComponentToWorld(),materials) end
   end
  end)
  if not ok then errors[#errors+1]=q(tostring(err)); print('Blackweb component error: '..tostring(err)..'\n') end
 end
 for _,c in ipairs(FindAllOf('PointLightComponent') or {}) do
  local ok,err=pcall(function()
   local name=c:GetFullName()
   if name:find('/Game/Maps/Map_House.') and name:find('PersistentLevel') then
    local p=c:K2_GetComponentLocation()
    local color=c.LightColor
    lights[#lights+1]='{"name":'..q(name)..',"position":'..v(p)..',"intensity":'..tostring(c.Intensity)..',"radius":'..tostring(c.AttenuationRadius)..',"color":'..string.format('[%d,%d,%d]',color.R,color.G,color.B)..'}'
   end
  end)
  if not ok then errors[#errors+1]=q(tostring(err)) end
 end
 local function save(name,items)
  local out=assert(io.open(name,'w')); out:write('['..table.concat(items,',\n')..']'); out:close()
 end
 save('Blackweb_components.json',rows)
 save('Blackweb_lights.json',lights)
 save('Blackweb_capture_errors.json',errors)
 print('Blackweb house capture: '..#rows..' mesh instances, '..#lights..' lights, '..#errors..' errors\n')
 DumpAllActors()
 DumpUSMAP()
end
ExecuteInGameThread(capture)
