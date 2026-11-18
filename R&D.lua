repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local C           = Color3.fromRGB

local hasDrawing = false
pcall(function() hasDrawing = type(Drawing) == "table" end)

local NextUI -- 前置声明：后面的模块会用到，UI 在文件后半段才创建

-- ============================================================================
-- [00] 配置 / 状态
-- ============================================================================

local CONFIG = {
  esp = {
    entityOn = true,
    eBox = true, eTracer = true, eName = true, eDist = true, eScale = 2500,
    playerOn = true,
    pBox = true, pTracer = true, pName = true, pDist = true, pHp = true, pScale = 2500,
    env = { shell = false, locker = false, table = false, door = false, objective = false },
    batteryOn = false,
    bBox = true, bTracer = true, bName = true, bDist = true,
    bScale = 700, bColor = C(255, 143, 74),
  },
  notify = {
    enabled = true, sound = true, volume = 1, duration = 3,
    onSpawn = true, onDespawn = true, onBattery = true,
    a666 = true, a666Range = 400, a400 = true,
  },
  move = {
    fly = false, flySpeed = 60,
    cframe = false, cframeSpeed = 26,
    qing = false, qingSpeed = 26,
    alwaysSprint = false, autoSlam = false, rewindGuard = true,
  },
  surv = { god = true, infStamina = true, infCharge = true, autoPick = false },
  anti = { a60 = true, a60prime = true, a50 = true, a1 = true, a90 = true, a90prime = true },
  light = { fullbright = false, fakeLight = false, brightness = 1.5, range = 60 },
}

local UNLOADED = false
local CONNS = {}

local function bind(signal, fn)
  local conn = signal:Connect(fn)
  table.insert(CONNS, conn)
  return conn
end

local function getChar()
  return LocalPlayer.Character
end

local function getHRP()
  local char = LocalPlayer.Character
  if not char then return nil end
  return char:FindFirstChild("HumanoidRootPart")
end

local function getHum()
  local char = LocalPlayer.Character
  if not char then return nil end
  return char:FindFirstChildOfClass("Humanoid")
end

local function getBasePart(obj)
  if not obj then return nil end
  if obj:IsA("BasePart") then return obj end
  local pp = obj.PrimaryPart
  if pp then return pp end
  return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function getPos(obj)
  if not obj then return nil end
  if obj:IsA("BasePart") then return obj.Position end
  local part = obj.PrimaryPart
            or obj:FindFirstChild("torso", true)
            or obj:FindFirstChild("Torso", true)
            or obj:FindFirstChildWhichIsA("BasePart", true)
  return part and part.Position or nil
end

local function getRoomsFolder()
  return Workspace:FindFirstChild("rooms") or Workspace:FindFirstChild("Rooms")
end

local function findRoomOf(obj)
  local rooms = getRoomsFolder()
  if not rooms or not obj then return nil end
  local node = obj
  while node and node ~= Workspace do
    if node.Parent == rooms then return node end
    node = node.Parent
  end
  return nil
end

local function isHidingAncestor(obj)
  local node = obj
  for _ = 1, 6 do
    if not node or node == Workspace then break end
    local norm = (node.Name:lower()):gsub("[^%w]", "")
    if norm:find("locker", 1, true) or norm:find("fridge", 1, true)
      or norm:find("closet", 1, true) or norm:find("wardrobe", 1, true)
      or norm:find("table", 1, true) or norm:find("desk", 1, true) then
      return true
    end
    node = node.Parent
  end
  return false
end

-- ============================================================================
-- [01] 实体识别（名称归一化 → 标签）
-- ============================================================================

local ENTITY_MAP = {
  monster = "A-60", multimonster = "A-60", a60 = "A-60", monster60 = "A-60",
  monsterprime = "A-60 Prime", multimonsterprime = "A-60 Prime",
  a60prime = "A-60 Prime", monster60prime = "A-60 Prime",
  monster2 = "A-120", a120 = "A-120", happyscribble = "A-120", scribbles = "A-120",
  a120prime = "A-120 Prime", scribblesprime = "A-120 Prime",
  a200 = "A-200", insidae = "A-200",
  a200prime = "A-200 Prime", insidaeprime = "A-200 Prime",
  handdebris = "A-250", kalypto = "A-250", a250 = "A-250", godhand = "A-250",
  a40 = "A-40", shell = "A-40", jack = "A-40",
  a50 = "A-50", darkness = "A-50",
  a90 = "A-90", a90face = "A-90",
  a90prime = "A-90 Prime",
  spirit = "A-100", a100 = "A-100",
  a400 = "A-400", monster400 = "A-400", ambientguardian = "A-400", guardian = "A-400",
  a400prime = "A-400 Prime", ambientguardianprime = "A-400 Prime",
  a666 = "A-666",
  evilbunger = "Evil Bunger",
}

local ENTITY_LABELS = {
  "A-60", "A-60 Prime", "A-120", "A-120 Prime", "A-200", "A-200 Prime",
  "A-250", "A-40", "A-50", "A-90", "A-90 Prime", "A-100",
  "A-400", "A-400 Prime", "A-666", "Evil Bunger",
}

local ENTITY_COLORS = {
  ["A-60"]        = C(255, 0, 0),
  ["A-60 Prime"]  = C(60, 140, 255),
  ["A-120"]       = C(255, 120, 0),
  ["A-120 Prime"] = C(60, 140, 255),
  ["A-200"]       = C(255, 170, 0),
  ["A-200 Prime"] = C(60, 140, 255),
  ["A-250"]       = C(200, 0, 60),
  ["A-40"]        = C(210, 210, 210),
  ["A-50"]        = C(140, 80, 255),
  ["A-90"]        = C(255, 255, 255),
  ["A-90 Prime"]  = C(60, 140, 255),
  ["A-100"]       = C(160, 0, 255),
  ["A-400"]       = C(120, 120, 120),
  ["A-400 Prime"] = C(60, 140, 255),
  ["A-666"]       = C(195, 126, 255),
  ["Evil Bunger"] = C(255, 165, 0),
}

local ENTITY_FILTER = {}
for _, label in ipairs(ENTITY_LABELS) do
  ENTITY_FILTER[label] = true
end

local function colorOf(label)
  return ENTITY_COLORS[label] or C(255, 80, 80)
end

local function isFiltered(label)
  local v = ENTITY_FILTER[label]
  if v == nil then return true end
  return v
end

local function classify(obj)
  if not obj then return nil end
  if not (obj:IsA("Model") or obj:IsA("BasePart")) then return nil end
  local cam = Workspace.CurrentCamera
  if cam and obj:IsDescendantOf(cam) then return nil end

  local rawName = obj.Name
  local lower = rawName:lower()
  local norm = lower:gsub("[^%w]", "")

  if lower == "???" then return "entity", "A-666" end

  local attrName = obj:GetAttribute("EntityName") or obj:GetAttribute("EntityType")
  local attrNorm = nil
  if type(attrName) == "string" then
    attrNorm = (attrName:lower()):gsub("[^%w]", "")
  end
  if attrNorm == "a10" or attrNorm == "a10prime" or attrNorm == "a10entity" then return nil end
  if attrNorm == "thevoid" or attrNorm == "thevoidprime" or attrNorm == "void" then return nil end

  local label = ENTITY_MAP[attrNorm or norm]
  if not label then
    if norm:match("^a666") then
      label = "A-666"
    elseif norm:match("^a120") then
      label = "A-120"
    elseif norm:match("^a200") then
      label = "A-200"
    elseif norm:match("^a250") then
      label = "A-250"
    elseif norm:match("^a400") or norm:find("ambientguardian", 1, true) then
      label = norm:find("prime", 1, true) and "A-400 Prime" or "A-400"
    end
  end

  if label then
    local isPrime = lower:find("prime", 1, true)
      or lower:find("'", 1, true)
      or lower:find("′", 1, true)
      or obj:GetAttribute("IsPrime") == true
      or (attrNorm and attrNorm:find("prime", 1, true))
    if isPrime and label:find("Prime") == nil then
      if label == "A-60" or label == "A-120" or label == "A-200"
        or label == "A-400" or label == "A-90" then
        label = label .. " Prime"
      end
    end
    return "entity", label
  end

  if norm:find("broken", 1, true) or norm:find("blue", 1, true)
    or norm:find("flipped", 1, true) or norm:find("upside", 1, true)
    or norm:find("overturned", 1, true) then
    return nil
  end

  if norm:find("locker", 1, true) or norm:find("fridge", 1, true)
    or norm:find("closet", 1, true) or norm:find("wardrobe", 1, true) then
    if norm:find("shell", 1, true) then return "shell", "Shell Locker" end
    return "locker", "Locker"
  end

  if norm:find("battery", 1, true) then
    if findRoomOf(obj) then return "battery", "Battery" end
    return nil
  end

  if norm:find("table", 1, true) or norm:find("desk", 1, true) then
    if norm:find("decor", 1, true) or norm:find("display", 1, true)
      or obj:GetAttribute("CanHide") == false or obj:GetAttribute("Hideable") == false then
      return nil
    end
    return "table", "Hiding Table"
  end

  if norm == "door" or norm:match("^door%d+$") or norm:find("exitdoor", 1, true) then
    return "door", "Door"
  end

  return nil
end

-- ============================================================================
-- [02] UI 帮助函数 / 通知（NextUI 内的提示，与"通知模块"无关）
-- ============================================================================

local function toast(title, content, kind, dur)
  if not NextUI then return end
  local map = { info = "Info", success = "Success", warn = "Warning", error = "Error" }
  local ok = pcall(function()
    NextUI:Notify({
      Type = map[kind] or "Info",
      Title = title,
      Content = content,
      Duration = dur or 3,
    })
  end)
  if ok then return end
  local fn = NextUI.Info
  if kind == "success" then fn = NextUI.Success
  elseif kind == "warn" then fn = NextUI.Warning
  elseif kind == "error" then fn = NextUI.Error
  end
  if type(fn) == "function" then pcall(fn, NextUI, title, content) end
end

-- ============================================================================
-- [03] 通知模块（完全独立：不读 ESP 状态，ESP 也不读它）
-- ============================================================================

local Notifier = {
  entities = {},
  batteries = {},
  lastA666 = 0,
  lastBatteryWarn = 0,
}

local function playSound(id)
  if not CONFIG.notify.enabled or not CONFIG.notify.sound then return end
  pcall(function()
    local s = Instance.new("Sound")
    s.SoundId = "rbxassetid://" .. tostring(id)
    s.Volume = CONFIG.notify.volume
    s.Parent = PlayerGui
    s:Play()
    Debris:AddItem(s, 4)
  end)
end

local function playAlert() playSound(6176997734) end
local function playNormal() playSound(4590662766) end

local function notifiedNear(tbl, obj)
  local node = obj
  for _ = 1, 4 do
    if not node or node == Workspace then break end
    if tbl[node] then return true end
    node = node.Parent
  end
  return false
end

local function notifierSpawn(obj, label)
  if Notifier.entities[obj] then return end
  if notifiedNear(Notifier.entities, obj) then return end
  Notifier.entities[obj] = label
  if not CONFIG.notify.enabled or not CONFIG.notify.onSpawn then return end
  playAlert()
  if label == "A-666" then
    toast("⚠ A-666", "距离 ≤ " .. tostring(CONFIG.notify.a666Range) .. " 时钻柜子，否则一路狂奔", "error", CONFIG.notify.duration + 1)
  else
    toast("⚠ 实体出现", label, "warn", CONFIG.notify.duration)
  end
end

local function notifierGone(obj)
  local label = Notifier.entities[obj]
  if not label then return end
  Notifier.entities[obj] = nil
  if not CONFIG.notify.enabled or not CONFIG.notify.onDespawn then return end
  playNormal()
  toast("✔ 实体消失", label, "success", CONFIG.notify.duration)
end

local function notifierBattery(obj)
  if Notifier.batteries[obj] then return end
  if notifiedNear(Notifier.batteries, obj) then return end
  Notifier.batteries[obj] = true
  if not CONFIG.notify.enabled or not CONFIG.notify.onBattery then return end
  playNormal()
  toast("🔋 电池", "房间里刷电池了", "info", CONFIG.notify.duration)
end

local notifierQueue = {}
local notifierBusy = false

-- 启动时把已经在场的实体静默登记，这样它们消失/靠近 A-666 也能触发通知
local function seedNotifier()
  local ok, list = pcall(function() return Workspace:GetDescendants() end)
  if not ok or type(list) ~= "table" then return end
  for _, obj in ipairs(list) do
    local kind, label = classify(obj)
    if kind == "entity" then
      if not notifiedNear(Notifier.entities, obj) then
        Notifier.entities[obj] = label
      end
    elseif kind == "battery" then
      if not notifiedNear(Notifier.batteries, obj) then
        Notifier.batteries[obj] = true
      end
    end
  end
end

local function pumpNotifier()
  if notifierBusy then return end
  notifierBusy = true
  task.spawn(function()
    while #notifierQueue > 0 do
      local obj = table.remove(notifierQueue, 1)
      if obj and obj.Parent then
        local kind, label = classify(obj)
        if kind == "entity" then
          notifierSpawn(obj, label)
        elseif kind == "battery" then
          notifierBattery(obj)
        end
      end
      if #notifierQueue > 12 then task.wait() end
    end
    notifierBusy = false
  end)
end

bind(Workspace.DescendantAdded, function(obj)
  if not CONFIG.notify.enabled then return end
  if #notifierQueue > 500 then return end
  table.insert(notifierQueue, obj)
  pumpNotifier()
end)

bind(Workspace.DescendantRemoving, function(obj)
  if Notifier.entities[obj] ~= nil then
    notifierGone(obj)
  end
  if Notifier.batteries[obj] ~= nil then
    Notifier.batteries[obj] = nil
  end
end)

-- A-666 距离预警（通知模块自己追踪，不看 ESP）
task.spawn(function()
  while not UNLOADED do
    task.wait(0.5)

    -- 实体已经不在世界里的，补一条"消失"通知，然后清出登记表
    for obj in pairs(Notifier.entities) do
      if not obj.Parent then
        notifierGone(obj)
      end
    end
    for obj in pairs(Notifier.batteries) do
      if not obj.Parent then
        Notifier.batteries[obj] = nil
      end
    end

    if CONFIG.notify.enabled and CONFIG.notify.a666 then
      local hrp = getHRP()
      if hrp then
        for obj, label in pairs(Notifier.entities) do
          if obj.Parent and label == "A-666" then
            local pos = getPos(obj)
            if pos then
              local dist = (pos - hrp.Position).Magnitude
              if dist <= CONFIG.notify.a666Range then
                if os.clock() - Notifier.lastA666 > 4 then
                  Notifier.lastA666 = os.clock()
                  playAlert()
                  toast("⚠ A-666 逼近", string.format("距离 %.0f · 立刻找柜子", dist), "error", 4)
                end
              end
            end
          end
        end
      end
    end
  end
end)

local function warnA400()
  if not CONFIG.notify.enabled or not CONFIG.notify.a400 then return end
  if os.clock() - Notifier.lastBatteryWarn < 6 then return end
  Notifier.lastBatteryWarn = os.clock()
  playAlert()
  toast("⚠ A-400 陷阱", "一个房间两块电池，两块都别捡", "warn", 5)
end

-- ============================================================================
-- [04] ESP 绘制对象
-- ============================================================================

-- 所有 Drawing 都在这里留一份强引用：弱表丢键时还能兜底清屏
local LIVE_DRAWINGS = {}

local function trackDrawing(d)
  if d then LIVE_DRAWINGS[d] = true end
  return d
end

-- 只隐藏，不销毁：最快、最不可能失败的一步
local function hideDrawing(d)
  if not d then return end
  pcall(function() d.Visible = false end)
end

-- 彻底销毁：Remove / Destroy 两种 API 都试，防止某个执行器没有 Remove 导致永久残影
-- 两种都失败的对象继续留在登记表里，下次 flush 再试一次
local function killDrawing(d)
  if not d then return end
  hideDrawing(d)
  local ok = pcall(function() d:Remove() end)
  if not ok then
    ok = pcall(function() d:Destroy() end)
  end
  if ok then
    LIVE_DRAWINGS[d] = nil
  end
end

local function newESP(label)
  if not hasDrawing then return nil end
  local esp = {}
  local ok = pcall(function()
    esp.Box = trackDrawing(Drawing.new("Square"))
    esp.Box.Filled = false
    esp.Box.Thickness = 1
    esp.Box.Visible = false

    esp.Name = trackDrawing(Drawing.new("Text"))
    esp.Name.Center = true
    esp.Name.Size = 16
    esp.Name.Font = 2
    esp.Name.Outline = true
    esp.Name.Visible = false

    esp.Distance = trackDrawing(Drawing.new("Text"))
    esp.Distance.Center = true
    esp.Distance.Size = 14
    esp.Distance.Font = 2
    esp.Distance.Outline = true
    esp.Distance.Visible = false

    esp.Tracer = trackDrawing(Drawing.new("Line"))
    esp.Tracer.Thickness = 1.5
    esp.Tracer.Visible = false

    esp.Health = trackDrawing(Drawing.new("Square"))
    esp.Health.Filled = true
    esp.Health.Visible = false
  end)
  if not ok then
    for _, v in pairs(esp) do killDrawing(v) end
    return nil
  end
  return esp
end

local function freeESP(esp)
  if not esp then return end
  for _, v in pairs(esp) do
    killDrawing(v)
  end
end

-- ============================================================================
-- 强引用登记表
-- 弱表（__mode = "k"）在 owner 被 Destroy 的瞬间会静默丢键，清理循环再也看不到它，
-- 于是那套 Drawing 就永久钉在屏幕上。静止物件（电池/柜子/门/桌子）被房间流式卸载
-- 或捡走时正好是这种情况，怪物和玩家通常只是走远、对象还在，所以看起来"只有不动的会印住"。
-- 这里改用强引用 + Destroying 事件 + 定时巡检，三条路都能收尸。
-- ============================================================================

local ACTIVE_ESP = {}
local OWNER_WATCH = setmetatable({}, { __mode = "k" })

local function releaseESP(esp)
  if not esp then return end
  local rec = ACTIVE_ESP[esp]
  if rec then
    local owner = rec.owner
    if owner then
      local conn = OWNER_WATCH[owner]
      if conn then
        pcall(function() conn:Disconnect() end)
        OWNER_WATCH[owner] = nil
      end
    end
    ACTIVE_ESP[esp] = nil
  end
  freeESP(esp)
end

local function registerESP(esp, owner)
  if not esp then return false end
  if not owner or not owner.Parent then
    freeESP(esp)
    return false
  end

  local old = OWNER_WATCH[owner]
  if old then
    pcall(function() old:Disconnect() end)
    OWNER_WATCH[owner] = nil
  end

  ACTIVE_ESP[esp] = { owner = owner }

  local conn
  conn = owner.Destroying:Connect(function()
    releaseESP(esp)
  end)
  OWNER_WATCH[owner] = conn
  return true
end

-- 每秒巡检：owner 已经没了就立刻收掉，不管它当初是从哪条路径漏的
task.spawn(function()
  while not UNLOADED do
    task.wait(1)
    if not UNLOADED then
      for esp, rec in pairs(ACTIVE_ESP) do
        local owner = rec.owner
        if not owner or not owner.Parent then
          releaseESP(esp)
        end
      end
    end
  end
end)

-- 兜底清屏：把所有登记过但已经没人管的绘制全部干掉
local function flushDrawings()
  for esp in pairs(ACTIVE_ESP) do
    releaseESP(esp)
  end
  local list = {}
  for d in pairs(LIVE_DRAWINGS) do
    table.insert(list, d)
  end
  for _, d in ipairs(list) do
    killDrawing(d)
  end
end

-- 逐项 pcall，任何一个对象失效都不会让后面的对象停在半路（这就是卡屏的根源）
local function hideESP(esp)
  if not esp then return end
  hideDrawing(esp.Box)
  hideDrawing(esp.Name)
  hideDrawing(esp.Distance)
  hideDrawing(esp.Tracer)
  hideDrawing(esp.Health)
end

local function drawESP(esp, pos, text, color, st, scale, hpRatio)
  if not esp or not pos then return end
  local cam = Workspace.CurrentCamera
  if not cam then hideESP(esp) return end

  local ok, screen, onScreen = pcall(function()
    return cam:WorldToViewportPoint(pos)
  end)
  if not ok or not onScreen then hideESP(esp) return end

  local size = scale / math.max(screen.Z, 2)
  if size > 320 then size = 320 end
  local boxPos = Vector2.new(screen.X - size / 4, screen.Y - size / 2)

  -- 每个元素单独 pcall：某个属性写失败只会让这一个元素停在原地，不会拖累其它元素
  pcall(function()
    esp.Box.Size = Vector2.new(size / 2, size)
    esp.Box.Position = boxPos
    esp.Box.Color = color
    esp.Box.Visible = st.box and true or false
  end)

  pcall(function()
    esp.Name.Text = tostring(text or "")
    esp.Name.Position = Vector2.new(screen.X, screen.Y + size / 2 + 10)
    esp.Name.Color = st.nameColor or color
    esp.Name.Visible = st.name and true or false
  end)

  pcall(function()
    local hrp = getHRP()
    if hrp and st.dist then
      esp.Distance.Text = string.format("[%.0f m]", (hrp.Position - pos).Magnitude)
      esp.Distance.Position = Vector2.new(screen.X, screen.Y + size / 2 + 25)
      esp.Distance.Color = st.distColor or C(180, 180, 180)
      esp.Distance.Visible = true
    else
      esp.Distance.Visible = false
    end
  end)

  pcall(function()
    esp.Tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y - 50)
    esp.Tracer.To = Vector2.new(screen.X, screen.Y)
    esp.Tracer.Color = st.tracerColor or color
    esp.Tracer.Visible = st.tracer and true or false
  end)

  pcall(function()
    if st.hp and hpRatio and hpRatio > 0 then
      local h = size * hpRatio
      esp.Health.Size = Vector2.new(4, math.max(h, 1))
      esp.Health.Position = Vector2.new(boxPos.X - 7, boxPos.Y + (size - h))
      esp.Health.Color = C(0, 255, 0)
      esp.Health.Visible = true
    else
      esp.Health.Visible = false
    end
  end)
end

-- ============================================================================
-- [05] ESP：实体（怪物）
-- ============================================================================

local EntityESP = {} -- 强引用：由 Parent/Destroying 判断失效，不靠 GC

local function removeEntityESP(obj)
  local esp = EntityESP[obj]
  if not esp then return end
  EntityESP[obj] = nil
  releaseESP(esp)
end

local function clearEntityESP()
  for obj in pairs(EntityESP) do
    removeEntityESP(obj)
  end
end

local function addEntityESP(obj, label)
  if EntityESP[obj] then return end
  local esp = newESP(label)
  if not esp then return end
  if not registerESP(esp, obj) then return end
  EntityESP[obj] = esp
end

local function scanEntities()
  if not CONFIG.esp.entityOn then return end
  if not hasDrawing then return end
  local count = 0
  for obj in pairs(EntityESP) do count = count + 1 end
  if count > 120 then return end
  for _, obj in ipairs(Workspace:GetDescendants()) do
    if obj:IsA("Model") or obj:IsA("BasePart") then
      local kind, label = classify(obj)
      if kind == "entity" and isFiltered(label) then
        addEntityESP(obj, label)
      end
    end
  end
end

bind(Workspace.DescendantAdded, function(obj)
  if not CONFIG.esp.entityOn or not hasDrawing then return end
  if not (obj:IsA("Model") or obj:IsA("BasePart")) then return end
  task.defer(function()
    local kind, label = classify(obj)
    if kind == "entity" and isFiltered(label) then
      addEntityESP(obj, label)
    end
  end)
end)

task.spawn(function()
  while not UNLOADED do
    task.wait(1.2)
    if CONFIG.esp.entityOn then
      scanEntities()
      for obj in pairs(EntityESP) do
        if not obj.Parent then removeEntityESP(obj) end
      end
    end
  end
end)

-- ============================================================================
-- [06] ESP：玩家
-- ============================================================================

local PlayerESP = {} -- 强引用：由 Parent/Destroying 判断失效，不靠 GC

local function removePlayerESP(char)
  local esp = PlayerESP[char]
  if not esp then return end
  PlayerESP[char] = nil
  releaseESP(esp)
end

local function addPlayerESP(char)
  if not CONFIG.esp.playerOn or not hasDrawing then return end
  if PlayerESP[char] then return end
  local esp = newESP("player")
  if not esp then return end
  if not registerESP(esp, char) then return end
  PlayerESP[char] = esp
end

local function refreshPlayers()
  for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
      if plr.Character then addPlayerESP(plr.Character) end
      bind(plr.CharacterAdded, function(char) addPlayerESP(char) end)
      bind(plr.CharacterRemoving, function(char) removePlayerESP(char) end)
    end
  end
end

bind(Players.PlayerAdded, function(plr)
  bind(plr.CharacterAdded, function(char) addPlayerESP(char) end)
  bind(plr.CharacterRemoving, function(char) removePlayerESP(char) end)
end)

bind(Players.PlayerRemoving, function(plr)
  if plr.Character then removePlayerESP(plr.Character) end
end)

-- ============================================================================
-- [07] ESP：环境（柜子 / 电池 / 桌子 / 门 / 目标点）—— Highlight + 名牌
-- ============================================================================

local ENV_COLORS = {
  shell = C(255, 58, 79),
  locker = C(66, 225, 179),
  battery = C(255, 212, 68),
  table = C(255, 151, 83),
  door = C(105, 166, 255),
  objective = C(255, 184, 64),
}

local EnvESP = {} -- 强引用：由 Parent/Destroying 判断失效，不靠 GC

local function removeEnvESP(obj)
  local data = EnvESP[obj]
  if not data then return end
  EnvESP[obj] = nil
  if data.conn then
    pcall(function() data.conn:Disconnect() end)
    data.conn = nil
  end
  pcall(function() data.hl:Destroy() end)
  pcall(function() data.bb:Destroy() end)
end

local function addEnvESP(obj, kind, text)
  if EnvESP[obj] then return end
  local part = getBasePart(obj)
  if not part then return end

  local color = ENV_COLORS[kind] or C(255, 255, 255)

  local hl = Instance.new("Highlight")
  hl.Name = "CMW_EnvHL"
  hl.Adornee = obj
  hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
  hl.FillColor = color
  hl.OutlineColor = color
  hl.FillTransparency = 0.72
  hl.OutlineTransparency = 0
  hl.Parent = PlayerGui

  local bb = Instance.new("BillboardGui")
  bb.Name = "CMW_EnvBB"
  bb.Adornee = part
  bb.Size = UDim2.fromOffset(180, 34)
  bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
  bb.AlwaysOnTop = true
  bb.MaxDistance = 420
  bb.Parent = PlayerGui

  local nameLabel = Instance.new("TextLabel")
  nameLabel.Size = UDim2.fromScale(1, 0.55)
  nameLabel.BackgroundTransparency = 1
  nameLabel.Text = text
  nameLabel.TextColor3 = color
  nameLabel.TextSize = 14
  nameLabel.Font = Enum.Font.GothamBold
  nameLabel.TextStrokeTransparency = 0.2
  nameLabel.Parent = bb

  local distLabel = Instance.new("TextLabel")
  distLabel.Name = "DistLabel"
  distLabel.Size = UDim2.fromScale(1, 0.4)
  distLabel.Position = UDim2.fromScale(0, 0.58)
  distLabel.BackgroundTransparency = 1
  distLabel.Text = "—"
  distLabel.TextColor3 = C(235, 235, 235)
  distLabel.TextSize = 12
  distLabel.Font = Enum.Font.Gotham
  distLabel.TextStrokeTransparency = 0.3
  distLabel.Parent = bb

  local conn = obj.Destroying:Connect(function()
    removeEnvESP(obj)
  end)

  EnvESP[obj] = {
    hl = hl, bb = bb, name = nameLabel, dist = distLabel,
    kind = kind, part = part, conn = conn,
  }
end

local function envAnyOn()
  for _, v in pairs(CONFIG.esp.env) do
    if v then return true end
  end
  return false
end

local function scanEnv()
  for obj, data in pairs(EnvESP) do
    if not obj.Parent or not CONFIG.esp.env[data.kind] then
      removeEnvESP(obj)
    end
  end

  if not envAnyOn() then return end

  local count = 0
  for _ in pairs(EnvESP) do count = count + 1 end
  if count > 1500 then return end

  for _, obj in ipairs(Workspace:GetDescendants()) do
    local kind, text = classify(obj)
    if kind and kind ~= "entity" and CONFIG.esp.env[kind] then
      addEnvESP(obj, kind, text)
    end
  end

  if CONFIG.esp.env.objective then
    local map = Workspace:FindFirstChild("Map")
    local objRoot = map and map:FindFirstChild("Objectives")
    if objRoot then
      for _, obj in ipairs(objRoot:GetChildren()) do
        local lower = obj.Name:lower()
        local text = nil
        if lower:find("token", 1, true) then
          text = "TOKEN"
        elseif lower:find("button", 1, true) then
          text = "BUTTON"
        elseif lower:find("relay", 1, true) then
          text = "RELAY"
        end
        if text then addEnvESP(obj, "objective", text) end
      end
    end
  end
end

-- 环境 ESP 距离数字刷新
task.spawn(function()
  while not UNLOADED do
    task.wait(0.2)
    if envAnyOn() then
      local hrp = getHRP()
      if hrp then
        for obj, data in pairs(EnvESP) do
          if obj.Parent and data.part and data.part.Parent then
            local mag = (data.part.Position - hrp.Position).Magnitude
            data.dist.Text = string.format("%d studs", math.floor(mag))
          end
        end
      end
    end
  end
end)

-- ============================================================================
-- [07b] ESP：电池（独立模块，配置、颜色、开关都和实体/环境分开）
-- ============================================================================

local BatteryESP = {} -- 强引用：由 Parent/Destroying 判断失效，不靠 GC

local function looksLikeBattery(name)
  local n = (name:lower()):gsub("[^%w]", "")
  return n == "battery" or n == "weakbattery" or n == "batteryitem"
    or n == "batterypickup" or n:match("^battery%d+$") ~= nil
end

-- 一块电池常常是「模型 + 若干同名子部件」。全部归到最顶层的那个节点上，
-- 否则同一块电池会画出好几套框和名字，叠在屏幕上像烙印。
local function batteryRoot(obj)
  local node = obj
  local root = obj
  for _ = 1, 6 do
    local parent = node.Parent
    if not parent or parent == Workspace then break end
    if looksLikeBattery(parent.Name) then
      root = parent
    end
    node = parent
  end
  return root
end

local function batteryInWorld(obj)
  local cam = Workspace.CurrentCamera
  if cam and obj:IsDescendantOf(cam) then return false end
  return findRoomOf(obj) ~= nil
end

local function removeBatteryESP(key)
  local esp = BatteryESP[key]
  if not esp then return end
  BatteryESP[key] = nil
  releaseESP(esp)
end

local function clearBatteryESP()
  for key in pairs(BatteryESP) do
    removeBatteryESP(key)
  end
end

local function addBatteryESP(obj)
  if BatteryESP[obj] then return end
  if not batteryInWorld(obj) then return end

  local root = batteryRoot(obj)
  if BatteryESP[root] then return end

  local esp = newESP("battery")
  if not esp then return end
  if not registerESP(esp, root) then return end
  BatteryESP[root] = esp
end

local function scanBatteries()
  if not CONFIG.esp.batteryOn or not hasDrawing then return end
  local rooms = getRoomsFolder()
  if not rooms then return end

  -- 先把已经不在世界里的清掉，避免越积越多
  for key in pairs(BatteryESP) do
    if not key.Parent or not batteryInWorld(key) then
      removeBatteryESP(key)
    end
  end

  local count = 0
  for _ in pairs(BatteryESP) do count = count + 1 end
  if count > 40 then return end

  for _, obj in ipairs(rooms:GetDescendants()) do
    if (obj:IsA("Model") or obj:IsA("BasePart")) and looksLikeBattery(obj.Name) then
      addBatteryESP(obj)
    end
  end
end

task.spawn(function()
  while not UNLOADED do
    task.wait(1.2)
    if CONFIG.esp.batteryOn then
      scanBatteries()
    end
  end
end)

bind(Workspace.DescendantAdded, function(obj)
  if not CONFIG.esp.batteryOn or not hasDrawing then return end
  if not (obj:IsA("Model") or obj:IsA("BasePart")) then return end
  if not looksLikeBattery(obj.Name) then return end
  task.defer(function()
    if not obj.Parent then return end
    addBatteryESP(obj)
  end)
end)

-- ============================================================================
-- [08] ESP 主渲染循环
-- ============================================================================

local function renderPlayers()
  for char, esp in pairs(PlayerESP) do
    local plr = Players:GetPlayerFromCharacter(char)
    -- 角色已经销毁：直接清掉，不留残影
    if not char.Parent or not plr then
      removePlayerESP(char)
    elseif not CONFIG.esp.playerOn then
      hideESP(esp)
    else
      local hrp = char:FindFirstChild("HumanoidRootPart")
      local hum = char:FindFirstChildOfClass("Humanoid")
      if not hrp or (hum and hum.Health <= 0) then
        hideESP(esp)
      else
        local ratio = 1
        if hum and hum.MaxHealth > 0 then
          ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
        end
        drawESP(esp, hrp.Position, plr.Name, C(50, 150, 255), {
          box = CONFIG.esp.pBox,
          tracer = CONFIG.esp.pTracer,
          name = CONFIG.esp.pName,
          dist = CONFIG.esp.pDist,
          hp = CONFIG.esp.pHp,
          nameColor = C(255, 255, 255),
          distColor = C(180, 180, 180),
          tracerColor = C(50, 150, 255),
        }, CONFIG.esp.pScale, ratio)
      end
    end
  end
end

local function renderEntities()
  if not CONFIG.esp.entityOn then
    for obj in pairs(EntityESP) do removeEntityESP(obj) end
    return
  end
  for obj, esp in pairs(EntityESP) do
    if not obj.Parent then
      removeEntityESP(obj)
    else
      local kind, label = classify(obj)
      if not kind then
        removeEntityESP(obj)
      else
        local pos = getPos(obj)
        if pos and isFiltered(label) then
          local color = colorOf(label)
          drawESP(esp, pos, label, color, {
            box = CONFIG.esp.eBox,
            tracer = CONFIG.esp.eTracer,
            name = CONFIG.esp.eName,
            dist = CONFIG.esp.eDist,
            nameColor = color,
            distColor = C(200, 200, 200),
            tracerColor = color,
          }, CONFIG.esp.eScale, nil)
        else
          hideESP(esp)
        end
      end
    end
  end
end

local function renderBatteries()
  if not CONFIG.esp.batteryOn then
    for key in pairs(BatteryESP) do removeBatteryESP(key) end
    return
  end

  local seen = {}
  for key, esp in pairs(BatteryESP) do
    if not key.Parent then
      removeBatteryESP(key)
    else
      local pos = getPos(key)
      if pos then
        -- 同一位置（2 stud 网格）只画一套：双电池陷阱、同点位多个部件都合并
        local grid = tostring(math.floor(pos.X / 2)) .. "|"
          .. tostring(math.floor(pos.Y / 2)) .. "|"
          .. tostring(math.floor(pos.Z / 2))
        if seen[grid] then
          hideESP(esp)
        else
          seen[grid] = true
          local color = CONFIG.esp.bColor
          drawESP(esp, pos, "Battery", color, {
            box = CONFIG.esp.bBox,
            tracer = CONFIG.esp.bTracer,
            name = CONFIG.esp.bName,
            dist = CONFIG.esp.bDist,
            nameColor = color,
            distColor = C(200, 200, 200),
            tracerColor = color,
          }, CONFIG.esp.bScale, nil)
        end
      else
        hideESP(esp)
      end
    end
  end
end

-- 每段单独 pcall：某一段出错不会让其它绘制停在最后一帧（"卡在屏幕上"就是这么来的）
bind(RunService.RenderStepped, function()
  if not hasDrawing then return end
  pcall(renderPlayers)
  pcall(renderEntities)
  pcall(renderBatteries)
end)

-- ============================================================================
-- [09] 移动：飞行 / 穿墙冲刺 / 速度
-- ============================================================================

local MOVE_STATE = {
  anchoredSaved = false,
  gravitySaved = Workspace.Gravity,
  paused = false,
  pausedUntil = 0,
  slamUntil = 0,
  sprintActive = false,
  sprintShift = false,
}

local function setFly(on)
  CONFIG.move.fly = on
  local hrp = getHRP()
  if on then
    if hrp then
      MOVE_STATE.anchoredSaved = hrp.Anchored
      hrp.Anchored = true
    end
    Workspace.Gravity = 0
  else
    if hrp then hrp.Anchored = MOVE_STATE.anchoredSaved end
    Workspace.Gravity = MOVE_STATE.gravitySaved
  end
end

bind(RunService.RenderStepped, function(dt)
  if not CONFIG.move.fly then return end
  local hrp = getHRP()
  if not hrp or not hrp.Parent then return end
  local cam = Workspace.CurrentCamera
  if not cam then return end

  local dir = Vector3.zero
  if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
  if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
  if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end

  if dir.Magnitude > 0 then
    hrp.CFrame = hrp.CFrame + dir.Unit * CONFIG.move.flySpeed * dt
  end
  hrp.Anchored = true
end)

local function wallclip()
  local hrp = getHRP()
  if not hrp or not hrp.Parent then return end
  local cam = Workspace.CurrentCamera
  if not cam then return end
  local look = cam.CFrame.LookVector
  task.spawn(function()
    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    for _ = 1, 33 do
      if not hrp or not hrp.Parent then break end
      hrp.CFrame = hrp.CFrame + look * 1.2
      task.wait(0.012)
    end
    if hrp and hrp.Parent and not CONFIG.move.fly then
      hrp.Anchored = wasAnchored
    end
  end)
end

bind(RunService.RenderStepped, function(dt)
  if not (CONFIG.move.cframe or CONFIG.move.qing) then return end
  if MOVE_STATE.paused then return end

  local char = LocalPlayer.Character
  local hrp = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not hrp or not hum then return end
  if hum.Health <= 0 or hum.Sit or hrp.Anchored then return end

  local md = hum.MoveDirection
  if md.Magnitude < 0.05 then return end

  local target = CONFIG.move.cframe and CONFIG.move.cframeSpeed or CONFIG.move.qingSpeed
  local extra = math.max(0, target - hum.WalkSpeed)
  if extra <= 0 then return end

  local step = md.Unit * extra * math.min(dt, 1 / 30)
  if CONFIG.move.cframe then
    hrp.CFrame = hrp.CFrame + step
  else
    pcall(function() char:TranslateBy(step) end)
  end
end)

-- ============================================================================
-- [10] 移动：冲刺 / 自动砸门 / rewind 保护 / panic
-- ============================================================================

local sprintCtl = nil
local sprintScanning = false
local sprintNextScan = 0

local function scanSprintController(force)
  if sprintCtl then return sprintCtl end
  if sprintScanning then return nil end
  if not force and os.clock() < sprintNextScan then return nil end
  if type(getgc) ~= "function" then return nil end
  sprintNextScan = os.clock() + 6
  sprintScanning = true
  task.spawn(function()
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
      sprintScanning = false
      return
    end
    local found = nil
    for i, v in ipairs(gc) do
      if type(v) == "table" then
        if type(rawget(v, "sprintinputdown")) == "function"
          and type(rawget(v, "sprintinputup")) == "function" then
          found = v
          break
        end
      end
      if i % 400 == 0 then task.wait() end
    end
    sprintCtl = found
    sprintScanning = false
  end)
  return nil
end

local function setSprint(on)
  if on then
    if type(keypress) == "function" then
      if not MOVE_STATE.sprintShift then
        MOVE_STATE.sprintShift = pcall(keypress, 16) and true or false
      end
    else
      local ctl = sprintCtl or scanSprintController()
      if ctl then
        local f = rawget(ctl, "sprintinputdown")
        if type(f) == "function" then
          if not pcall(f) then pcall(f, ctl) end
        end
        pcall(rawset, ctl, "playersprint", true)
      end
    end
    MOVE_STATE.sprintActive = true
  else
    if MOVE_STATE.sprintShift and type(keyrelease) == "function" then
      pcall(keyrelease, 16)
      MOVE_STATE.sprintShift = false
    end
    local ctl = sprintCtl
    if ctl then
      local f = rawget(ctl, "sprintinputup")
      if type(f) == "function" then
        if not pcall(f) then pcall(f, ctl) end
      end
      pcall(rawset, ctl, "playersprint", false)
    end
    MOVE_STATE.sprintActive = false
  end
end

local slamParams = OverlapParams.new()
slamParams.FilterType = Enum.RaycastFilterType.Exclude
slamParams.MaxParts = 90

local lastSlam = setmetatable({}, { __mode = "k" })

local function findFrontDoor()
  local char = LocalPlayer.Character
  local hrp = char and char:FindFirstChild("HumanoidRootPart")
  if not hrp then return nil end
  slamParams.FilterDescendantsInstances = { char }
  local ok, parts = pcall(function()
    return Workspace:GetPartBoundsInRadius(hrp.Position, 10, slamParams)
  end)
  if not ok or type(parts) ~= "table" then return nil end

  local best, bestDist = nil, nil
  for _, part in ipairs(parts) do
    local node = part
    for _ = 1, 5 do
      if not node or node == Workspace then break end
      if node:IsA("Model") or node:IsA("BasePart") then
        local kind = classify(node)
        if kind == "door" and not isHidingAncestor(node) then
          local delta = part.Position - hrp.Position
          local mag = delta.Magnitude
          if mag > 0.5 and mag < 10 then
            if hrp.CFrame.LookVector:Dot(delta.Unit) > 0.2 then
              if not bestDist or mag < bestDist then
                best = node
                bestDist = mag
              end
            end
          end
        end
      end
      node = node.Parent
    end
  end
  return best
end

local function slamDoor(door)
  if not door or not door.Parent then return end
  local prompt = door:FindFirstChildWhichIsA("ProximityPrompt", true)
  if prompt and prompt.Enabled and type(fireproximityprompt) == "function" then
    pcall(fireproximityprompt, prompt)
    return
  end
  local click = door:FindFirstChildWhichIsA("ClickDetector", true)
  if click and type(fireclickdetector) == "function" then
    pcall(fireclickdetector, click)
  end
end

local function isRewindRoom(room)
  if not room then return nil end
  local num = tonumber(room.Name:match("(%d+)$"))
  if not num then return nil end
  if num >= 101 and num <= 901 and num % 100 == 1 then return num end
  return nil
end

local function rewindCheck()
  if not CONFIG.move.rewindGuard then
    MOVE_STATE.paused = false
    return
  end
  local hrp = getHRP()
  local rooms = getRoomsFolder()
  if not hrp or not rooms then return end

  local speed = CONFIG.move.cframe and CONFIG.move.cframeSpeed
    or (CONFIG.move.qing and CONFIG.move.qingSpeed or 16)
  local radius = math.clamp(25 + (speed - 16) * 0.27, 25, 55)

  local found = false
  for _, room in ipairs(rooms:GetChildren()) do
    if isRewindRoom(room) then
      local part = getBasePart(room)
      if part and (part.Position - hrp.Position).Magnitude <= radius then
        found = true
        break
      end
    end
  end

  if found then
    MOVE_STATE.pausedUntil = os.clock() + 5
  end
  local paused = found or os.clock() < MOVE_STATE.pausedUntil
  if paused and not MOVE_STATE.paused then
    setSprint(false)
  end
  MOVE_STATE.paused = paused
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.22)
    rewindCheck()

    if not UNLOADED then
      local wantSprint = false
      if (CONFIG.move.alwaysSprint or CONFIG.move.autoSlam) and not MOVE_STATE.paused then
        local door = nil
        if CONFIG.move.autoSlam then
          door = findFrontDoor()
          if door then
            MOVE_STATE.slamUntil = os.clock() + 0.4
            if os.clock() - (lastSlam[door] or -100) > 2 then
              lastSlam[door] = os.clock()
              slamDoor(door)
            end
          end
        end
        wantSprint = CONFIG.move.alwaysSprint or door ~= nil or os.clock() < MOVE_STATE.slamUntil
      end

      if wantSprint and not MOVE_STATE.sprintActive then
        setSprint(true)
      elseif not wantSprint and MOVE_STATE.sprintActive then
        setSprint(false)
      end

      -- 没有 keypress 的执行器要靠控制器：扫到了就补一次冲刺
      if wantSprint and not sprintCtl and type(keypress) ~= "function" then
        scanSprintController()
        if sprintCtl then setSprint(true) end
      end
    end
  end
end)

local function panicStop()
  CONFIG.move.cframe = false
  CONFIG.move.qing = false
  CONFIG.move.alwaysSprint = false
  CONFIG.move.autoSlam = false
  CONFIG.surv.autoPick = false
  setSprint(false)
  MOVE_STATE.paused = false
  MOVE_STATE.pausedUntil = 0
end

-- ============================================================================
-- [11] 生存：godmode / 无限体力 / 无限手电 / 自动拾取
-- ============================================================================

local godField = nil

local function godTick()
  if not CONFIG.surv.god then
    if godField then
      pcall(function() godField:Destroy() end)
      godField = nil
    end
    return
  end

  local char = LocalPlayer.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not char or not hum then return end

  if not godField or godField.Parent ~= char then
    if godField then pcall(function() godField:Destroy() end) end
    godField = Instance.new("ForceField")
    godField.Name = "CMW_GodField"
    godField.Visible = false
    godField.Parent = char
  end

  if hum.Health > 0 and hum.Health < hum.MaxHealth then
    pcall(function() hum.Health = hum.MaxHealth end)
  end
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.18)
    godTick()
  end
end)

-- 无限体力 ------------------------------------------------------------------
local STAM_KEYS = {
  stamina = true, staminavalue = true, currentstamina = true, sprintstamina = true,
  runstamina = true, sprintenergy = true, runenergy = true,
}
local stamController = nil
local stamState = "off"
local stamScanId = 0

local function stamScan()
  stamScanId = stamScanId + 1
  local myId = stamScanId
  stamController = nil
  stamState = "scanning"
  if type(getgc) ~= "function" then
    stamState = "getgc 不可用"
    return
  end
  task.spawn(function()
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
      stamState = "扫描失败"
      return
    end
    local cand, candCount, best = nil, 0, nil
    for i, v in ipairs(gc) do
      if myId ~= stamScanId or not CONFIG.surv.infStamina then return end
      if type(v) == "table" and type(rawget(v, "stamina")) == "number" then
        candCount = candCount + 1
        cand = v
        if type(rawget(v, "playersprint")) == "boolean"
          or type(rawget(v, "sprintinputdown")) == "function" then
          best = v
        end
      end
      if i % 400 == 0 then task.wait() end
    end
    if myId ~= stamScanId or not CONFIG.surv.infStamina then return end
    stamController = best or (candCount == 1 and cand or nil)
    if stamController then
      stamState = "已连接"
    else
      stamState = candCount > 1 and "字段冲突" or "未找到"
    end
  end)
end

local function staminaBoostValues()
  local char = LocalPlayer.Character
  local targets = {}
  if char then table.insert(targets, char) end
  table.insert(targets, LocalPlayer)

  for _, root in ipairs(targets) do
    for _, v in ipairs(root:GetDescendants()) do
      if v:IsA("NumberValue") or v:IsA("IntValue") then
        local key = (v.Name:lower()):gsub("[^%w]", "")
        if STAM_KEYS[key] then
          local target = 100
          local maxVal = v.Parent and v.Parent:FindFirstChild("Max")
            or v.Parent and v.Parent:FindFirstChild("MaxStamina")
          if maxVal and (maxVal:IsA("NumberValue") or maxVal:IsA("IntValue")) and maxVal.Value > 0 then
            target = maxVal.Value
          end
          if v.Value < target then
            pcall(function() v.Value = target end)
          end
        end
      end
    end
  end
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.2)
    if CONFIG.surv.infStamina then
      if stamController then
        local v = rawget(stamController, "stamina")
        if type(v) == "number" then
          if v < 100 then
            if not pcall(rawset, stamController, "stamina", 100) then
              stamState = "写入被拦"
            end
          end
        else
          stamController = nil
          stamState = "控制器丢失"
        end
      end
      staminaBoostValues()
    end
  end
end)

-- 无限手电 ------------------------------------------------------------------
local chargeHolder = nil
local chargeState = "off"
local chargeScanId = 0

local function chargeScan()
  chargeScanId = chargeScanId + 1
  local myId = chargeScanId
  chargeHolder = nil
  chargeState = "scanning"
  if type(getgc) ~= "function" then
    chargeState = "getgc 不可用"
    return
  end
  task.spawn(function()
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then
      chargeState = "扫描失败"
      return
    end
    local best, bestScore, ties = nil, -1, 0
    for i, v in ipairs(gc) do
      if myId ~= chargeScanId or not CONFIG.surv.infCharge then return end
      if type(v) == "table" then
        local c = rawget(v, "flashlightcharge")
        if type(c) == "number" and c >= 0 and c <= 200 then
          local score = 0
          if type(rawget(v, "stamina")) == "number" then score = score + 2 end
          if type(rawget(v, "playersprint")) == "boolean" then score = score + 2 end
          if score > bestScore then
            bestScore = score
            best = v
            ties = 1
          elseif score == bestScore then
            ties = ties + 1
          end
        end
      end
      if i % 500 == 0 then task.wait() end
    end
    if myId ~= chargeScanId or not CONFIG.surv.infCharge then return end
    if best and ties == 1 and bestScore >= 4 then
      chargeHolder = best
      chargeState = "已连接"
    else
      chargeState = best and "控制器冲突" or "未找到"
    end
  end)
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.25)
    if CONFIG.surv.infCharge and chargeHolder then
      local c = rawget(chargeHolder, "flashlightcharge")
      if type(c) ~= "number" or c < -5 or c > 200 then
        chargeHolder = nil
        chargeState = "控制器丢失"
      elseif c < 100 then
        if not pcall(rawset, chargeHolder, "flashlightcharge", 100) then
          chargeState = "写入被拦"
        end
      end
    end
  end
end)

-- 自动拾取 ------------------------------------------------------------------
local pickupCooldown = setmetatable({}, { __mode = "k" })
local roomBatteryCache = setmetatable({}, { __mode = "k" })
local pickupParams = OverlapParams.new()
pickupParams.FilterType = Enum.RaycastFilterType.Exclude
pickupParams.MaxParts = 120

local function isBatteryName(name)
  local norm = (name:lower()):gsub("[^%w]", "")
  return norm == "battery" or norm == "weakbattery" or norm == "batteryitem"
    or norm == "batterypickup" or norm:match("^battery%d+$") ~= nil
end

local function isItemName(name)
  if isBatteryName(name) then return true end
  local norm = (name:lower()):gsub("[^%w]", "")
  if norm == "flashlight" or norm == "gummy" or norm == "bandage"
    or norm == "medkit" or norm == "keycard" or norm == "clock"
    or norm == "key" or norm == "keys" or norm:match("^key%d+$") then
    return true
  end
  return false
end

local function countRoomBatteries(room)
  local cached = roomBatteryCache[room]
  if cached and os.clock() - cached.time < 0.45 then return cached.count end
  local seen = {}
  local count = 0
  for _, v in ipairs(room:GetDescendants()) do
    if (v:IsA("Model") or v:IsA("BasePart")) and isBatteryName(v.Name) then
      local node = v
      while node and node ~= room do
        if isBatteryName(node.Name) then
          node = node.Parent
        else
          break
        end
      end
      local anchor = node or v
      if not seen[anchor] then
        seen[anchor] = true
        local p = anchor:FindFirstChildWhichIsA("ProximityPrompt", true)
        local c = anchor:FindFirstChildWhichIsA("ClickDetector", true)
        if p or c then count = count + 1 end
      end
    end
  end
  roomBatteryCache[room] = { time = os.clock(), count = count }
  return count
end

local function roomHasDoubleBattery(item)
  local room = findRoomOf(item)
  if not room then return false end
  if countRoomBatteries(room) >= 2 then
    warnA400()
    return true
  end
  return false
end

local function findItemAncestor(part)
  local room = findRoomOf(part)
  if not room then return nil end
  local node = part
  local best = nil
  while node and node ~= room do
    if isItemName(node.Name) then best = node end
    node = node.Parent
  end
  return best
end

local function tryPickup(item)
  if not CONFIG.surv.autoPick or MOVE_STATE.paused then return end
  if not item or not item.Parent then return end
  local hrp = getHRP()
  if not hrp then return end
  local part = getBasePart(item)
  if not part then return end
  if (part.Position - hrp.Position).Magnitude > 10 then return end
  if os.clock() - (pickupCooldown[item] or -100) < 2.5 then return end
  if isBatteryName(item.Name) and roomHasDoubleBattery(item) then return end

  local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
  if prompt and prompt.Enabled and type(fireproximityprompt) == "function" then
    pickupCooldown[item] = os.clock()
    pcall(fireproximityprompt, prompt)
    return
  end

  local click = item:FindFirstChildWhichIsA("ClickDetector", true)
  if click and type(fireclickdetector) == "function" then
    pickupCooldown[item] = os.clock()
    pcall(fireclickdetector, click)
    return
  end

  if type(firetouchinterest) == "function" and (part.Position - hrp.Position).Magnitude <= 3 then
    pickupCooldown[item] = os.clock()
    pcall(function()
      firetouchinterest(hrp, part, 0)
      firetouchinterest(hrp, part, 1)
    end)
  end
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.5)
    if CONFIG.surv.autoPick and not MOVE_STATE.paused then
      local char = LocalPlayer.Character
      local hrp = char and char:FindFirstChild("HumanoidRootPart")
      if hrp then
        pickupParams.FilterDescendantsInstances = { char }
        local ok, parts = pcall(function()
          return Workspace:GetPartBoundsInRadius(hrp.Position, 9, pickupParams)
        end)
        if ok and type(parts) == "table" then
          local seen = {}
          local tries = 0
          for _, part in ipairs(parts) do
            local item = findItemAncestor(part)
            if item and not seen[item] then
              seen[item] = true
              tryPickup(item)
              tries = tries + 1
              if tries >= 2 then break end
            end
          end
        end
      end
    end
  end
end)

-- ============================================================================
-- [12] 反实体（本地删除 + 模板改名）
-- ============================================================================

local ANTI_TEMPLATES = {
  { original = "darknesslocker", replacement = "A-50", group = "a50" },
  { original = "badskull", replacement = "A-1", group = "a1" },
  { original = "a90face", replacement = "A-90", group = "a90" },
  { original = "a90faceprime", replacement = "A-90 Prime", group = "a90prime" },
}

local renamedTemplates = setmetatable({}, { __mode = "k" })

local function antiActive(group)
  if group == "a90" then
    return CONFIG.anti.a90 or CONFIG.anti.a90prime
  end
  return CONFIG.anti[group] == true
end

local function anyAntiOn()
  for _, v in pairs(CONFIG.anti) do
    if v then return true end
  end
  return false
end

local function undoRenames()
  for obj, info in pairs(renamedTemplates) do
    if not antiActive(info.group) then
      if obj.Parent then
        pcall(function() obj.Name = info.original end)
      end
      renamedTemplates[obj] = nil
    end
  end
end

local function applyRenames()
  for _, entry in ipairs(ANTI_TEMPLATES) do
    if antiActive(entry.group) then
      local tmpl = ReplicatedStorage:FindFirstChild(entry.original, true)
      if tmpl and not renamedTemplates[tmpl] then
        if pcall(function() tmpl.Name = entry.replacement end) then
          renamedTemplates[tmpl] = { original = entry.original, group = entry.group }
        end
      end
    end
  end
end

local function isAntiTarget(obj)
  if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
  if obj.Parent ~= Workspace then return false end
  local norm = (obj.Name:lower()):gsub("[^%w]", "")
  local prime = norm:find("prime", 1, true) or obj:GetAttribute("IsPrime") == true
  if norm == "monster" or norm == "multimonster" then
    return CONFIG.anti.a60 or CONFIG.anti.a60prime
  end
  if norm == "a60" or norm == "monster60" then
    if prime then return CONFIG.anti.a60prime end
    return CONFIG.anti.a60
  end
  if norm == "a60prime" or norm == "monsterprime"
    or norm == "multimonsterprime" or norm == "monster60prime" then
    return CONFIG.anti.a60prime
  end
  return false
end

local function antiTick()
  applyRenames()
  if CONFIG.anti.a60 or CONFIG.anti.a60prime then
    for _, obj in ipairs(Workspace:GetChildren()) do
      if isAntiTarget(obj) then
        pcall(function() obj:Destroy() end)
      end
    end
  end
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.85)
    if anyAntiOn() then antiTick() end
    undoRenames() -- 关掉开关也要把模板名改回去
  end
end)

-- ============================================================================
-- [13] 光照：fullbright / 假光源
-- ============================================================================

local LIGHT_ORIG = {
  brightness = Lighting.Brightness,
  shadows = Lighting.GlobalShadows,
  ambient = Lighting.OutdoorAmbient,
  fogEnd = Lighting.FogEnd,
}

local function applyFullbright(on)
  CONFIG.light.fullbright = on
  if on then
    Lighting.Brightness = 2
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.FogEnd = 100000
  else
    Lighting.Brightness = LIGHT_ORIG.brightness
    Lighting.GlobalShadows = LIGHT_ORIG.shadows
    Lighting.OutdoorAmbient = LIGHT_ORIG.ambient
    Lighting.FogEnd = LIGHT_ORIG.fogEnd
  end
end

local fakeLight = nil

local function refreshFakeLight()
  local hrp = getHRP()
  if not CONFIG.light.fakeLight or not hrp then
    if fakeLight then
      pcall(function() fakeLight:Destroy() end)
      fakeLight = nil
    end
    return
  end

  if fakeLight and fakeLight.Parent ~= hrp then
    pcall(function() fakeLight:Destroy() end)
    fakeLight = nil
  end

  if not fakeLight then
    local existing = hrp:FindFirstChild("CMW_FakeLight")
    if existing and existing:IsA("PointLight") then
      fakeLight = existing
    else
      fakeLight = Instance.new("PointLight")
      fakeLight.Name = "CMW_FakeLight"
      fakeLight.Shadows = false
      fakeLight.Parent = hrp
    end
  end

  fakeLight.Brightness = CONFIG.light.brightness
  fakeLight.Range = CONFIG.light.range
  fakeLight.Enabled = true
end

task.spawn(function()
  while not UNLOADED do
    task.wait(0.3)
    if CONFIG.light.fakeLight then refreshFakeLight() end
  end
end)

-- ============================================================================
-- [14] NextUI
-- ============================================================================

NextUI = loadstring(game:HttpGet("https://diser.me/nextui/source.lua"))()

NextUI:AddThemes({
  Phoenix  = { Window = C(17, 18, 22), Side = C(10, 11, 13), Panel = C(21, 22, 27), Card = C(25, 27, 33), Element = C(34, 37, 45), Hover = C(45, 48, 60), Border = C(102, 105, 114), Accent = C(241, 137, 101), Text = C(228, 232, 247), Sub = C(149, 155, 180), Off = C(58, 61, 70) },
  Nocturne = { Window = C(16, 24, 33), Side = C(12, 17, 24), Panel = C(20, 30, 42), Card = C(25, 37, 51), Element = C(33, 48, 66), Hover = C(42, 62, 86), Border = C(106, 115, 126), Accent = C(230, 88, 162), Text = C(237, 242, 248), Sub = C(136, 155, 178), Off = C(50, 70, 93) },
  Sun      = { Window = C(245, 243, 245), Side = C(236, 232, 236), Panel = C(248, 247, 248), Card = C(252, 252, 252), Element = C(240, 236, 240), Hover = C(233, 228, 233), Border = C(176, 176, 176), Accent = C(214, 135, 0), Text = C(0, 0, 0), Sub = C(122, 104, 121), Off = C(206, 198, 206) },
  Gecko    = { Window = C(25, 27, 28), Side = C(19, 21, 21), Panel = C(30, 32, 33), Card = C(36, 39, 40), Element = C(48, 52, 53), Hover = C(62, 67, 68), Border = C(115, 118, 119), Accent = C(203, 244, 85), Text = C(245, 246, 247), Sub = C(139, 170, 179), Off = C(70, 72, 73), OnAccent = C(24, 29, 12) },
  Midnight = { Window = C(13, 11, 15), Side = C(6, 5, 7), Panel = C(18, 15, 20), Card = C(25, 21, 29), Element = C(36, 30, 41), Hover = C(49, 41, 56), Border = C(108, 103, 112), Accent = C(156, 100, 232), Text = C(243, 238, 248), Sub = C(158, 140, 172), Off = C(61, 54, 68) },
  Gold     = { Window = C(12, 12, 14), Side = C(8, 8, 10), Panel = C(15, 15, 18), Card = C(20, 20, 24), Element = C(28, 28, 33), Hover = C(47, 47, 47), Border = C(109, 109, 112), Accent = C(136, 110, 68), Text = C(255, 255, 255), Sub = C(130, 132, 144), Off = C(48, 48, 58) },
  Doir     = { Window = C(10, 8, 9), Side = C(5, 4, 5), Panel = C(8, 6, 7), Card = C(14, 10, 12), Element = C(23, 17, 20), Hover = C(36, 26, 31), Border = C(104, 97, 101), Accent = C(4, 0, 255), Text = C(250, 240, 245), Sub = C(150, 125, 136), Off = C(44, 32, 38) },
})

local Window = NextUI:CreateWindow({
  Title = "CatMeowWave",
  SubTitle = "由 Mjay 制作 Rooms & Doors · v1.5Promise",
  Size = Vector2.new(920, 600),
  TabWidth = 200,
  Collapsible = true,
  Theme = "Rose",
  Glass = true,
  ToggleKeys = { Enum.KeyCode.H, Enum.KeyCode.RightShift },
})

local function setFlag(flag, value)
  pcall(function()
    local opt = NextUI.Options and NextUI.Options[flag]
    if opt and type(opt.Set) == "function" then opt:Set(value) end
  end)
end

-- NextUI 各版本 AddTab 签名不一致，这里两种都试
local function addTab(title, icon)
  local ok, tab = pcall(function()
    return Window:AddTab({ Title = title, Icon = icon })
  end)
  if ok and tab then return tab end
  local ok2, tab2 = pcall(function()
    return Window:AddTab(title, icon)
  end)
  if ok2 and tab2 then return tab2 end
  return Window:AddTab(title, icon)
end

-- 官方键位总表：按 K 展开/收起，自动读取所有开关和按钮上的绑定
pcall(function()
  NextUI:CreateKeybindList({ Key = Enum.KeyCode.K, Visible = false })
end)

-- ---------------------------------- 透视 ----------------------------------
Window:AddCategory("透视")

local TabEntity = addTab("实体 ESP", "eye")
local TabEnv    = addTab("环境 ESP", "layers")
--local TabPlayer = addTab("玩家 ESP", "users")
--local TabBattery = addTab("电池 ESP", "battery-charging")

-- 实体 ESP
local SecEntity = TabEntity:AddSection({ Title = "实体 ESP", Icon = "skull" })

SecEntity:AddToggle({
  Title = "启用实体 ESP",
  Description = "只控制透视，不影响通知",
  Flag = "e_on",
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.esp.entityOn = v
    if not v then clearEntityESP() else scanEntities() end
  end,
})

SecEntity:AddToggle({
  Title = "方框",
  Flag = "e_box",
  Default = true,
  Callback = function(v) CONFIG.esp.eBox = v end,
})

SecEntity:AddToggle({
  Title = "射线",
  Flag = "e_tracer",
  Default = true,
  Callback = function(v) CONFIG.esp.eTracer = v end,
})

SecEntity:AddToggle({
  Title = "名字",
  Flag = "e_name",
  Default = true,
  Callback = function(v) CONFIG.esp.eName = v end,
})

SecEntity:AddToggle({
  Title = "距离",
  Flag = "e_dist",
  Default = true,
  Callback = function(v) CONFIG.esp.eDist = v end,
})

SecEntity:AddSlider({
  Title = "方框大小",
  Flag = "e_scale",
  Min = 1200, Max = 5000, Default = 2500, Increment = 100,
  Callback = function(v) CONFIG.esp.eScale = v end,
})

local SecEntityFilter = TabEntity:AddSection({ Title = "怪物筛选", Icon = "list-checks" })

for i, label in ipairs(ENTITY_LABELS) do
  SecEntityFilter:AddToggle({
    Title = label,
    Flag = "ef_" .. tostring(i),
    Default = true,
    Callback = function(v)
      ENTITY_FILTER[label] = v
    end,
  })
end

local SecEntityColor = TabEntity:AddSection({ Title = "怪物颜色", Icon = "palette" })

for i, label in ipairs(ENTITY_LABELS) do
  SecEntityColor:AddColorPicker({
    Title = label,
    Flag = "ec_" .. tostring(i),
    Default = ENTITY_COLORS[label],
    Callback = function(color)
      ENTITY_COLORS[label] = color
    end,
  })
end

-- 环境 ESP
local SecEnv = TabEnv:AddSection({ Title = "环境 ESP", Icon = "layers" })

SecEnv:AddParagraph({
  Title = "环境透视",
  Content = "柜子/桌子/门/目标点使用高亮 + 名牌。电池单独一页，配置互不影响。",
})

SecEnv:AddToggle({
  Title = "Shell 柜子",
  Flag = "env_shell",
  Default = false,
  Callback = function(v) CONFIG.esp.env.shell = v end,
})

SecEnv:AddToggle({
  Title = "普通柜子",
  Flag = "env_locker",
  Default = false,
  Callback = function(v) CONFIG.esp.env.locker = v end,
})

SecEnv:AddToggle({
  Title = "躲藏桌",
  Flag = "env_table",
  Default = false,
  Callback = function(v) CONFIG.esp.env.table = v end,
})

SecEnv:AddToggle({
  Title = "门",
  Flag = "env_door",
  Default = false,
  Callback = function(v) CONFIG.esp.env.door = v end,
})

SecEnv:AddToggle({
  Title = "目标点（Token / Button / Relay）",
  Flag = "env_objective",
  Default = false,
  Callback = function(v) CONFIG.esp.env.objective = v end,
})

local SecEnvColor = TabEnv:AddSection({ Title = "环境颜色", Icon = "palette" })
local envColorMap = {
  { key = "shell", title = "Shell 柜子" },
  { key = "locker", title = "普通柜子" },
  { key = "table", title = "躲藏桌" },
  { key = "door", title = "门" },
  { key = "objective", title = "目标点" },
}

for _, entry in ipairs(envColorMap) do
  SecEnvColor:AddColorPicker({
    Title = entry.title,
    Flag = "envc_" .. entry.key,
    Default = ENV_COLORS[entry.key],
    Callback = function(color)
      ENV_COLORS[entry.key] = color
      for _, data in pairs(EnvESP) do
        if data.kind == entry.key then
          data.hl.FillColor = color
          data.hl.OutlineColor = color
          data.name.TextColor3 = color
        end
      end
    end,
  })
end

task.spawn(function()
  while not UNLOADED do
    task.wait(1)
    -- 无条件跑：关掉开关时也要把已有高亮清干净
    pcall(scanEnv)
  end
end)

-- 电池 ESP（独立一页，不跟环境 ESP 共用配置）
local SecBattery = TabEnv:AddSection({ Title = "电池 ESP", Icon = "battery-charging" })

SecBattery:AddParagraph({
  Title = "独立模块",
  Content = "电池有自己的开关、颜色和元素设置，和环境 ESP 里的柜子/桌子/门互不影响。",
})

SecBattery:AddToggle({
  Title = "启用电池 ESP",
  Flag = "b_on",
  Style = "Switch",
  Default = false,
  Callback = function(v)
    CONFIG.esp.batteryOn = v
    if v then
      scanBatteries()
    else
      clearBatteryESP()
    end
  end,
})

SecBattery:AddToggle({
  Title = "方框",
  Flag = "b_box",
  Default = true,
  Callback = function(v) CONFIG.esp.bBox = v end,
})

SecBattery:AddToggle({
  Title = "射线",
  Flag = "b_tracer",
  Default = true,
  Callback = function(v) CONFIG.esp.bTracer = v end,
})

SecBattery:AddToggle({
  Title = "名字",
  Flag = "b_name",
  Default = true,
  Callback = function(v) CONFIG.esp.bName = v end,
})

SecBattery:AddToggle({
  Title = "距离",
  Flag = "b_dist",
  Default = true,
  Callback = function(v) CONFIG.esp.bDist = v end,
})

SecBattery:AddSlider({
  Title = "方框大小",
  Flag = "b_scale",
  Min = 300, Max = 1600, Default = 700, Increment = 50,
  Callback = function(v) CONFIG.esp.bScale = v end,
})

SecBattery:AddColorPicker({
  Title = "电池颜色",
  Flag = "b_color",
  Default = C(255, 143, 74),
  Callback = function(color) CONFIG.esp.bColor = color end,
})

-- 玩家 ESP
local SecPlayer = TabEnv:AddSection({ Title = "玩家 ESP", Icon = "users" })

SecPlayer:AddToggle({
  Title = "启用玩家 ESP",
  Flag = "p_on",
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.esp.playerOn = v
    if v then
      refreshPlayers()
    else
      for char in pairs(PlayerESP) do
        removePlayerESP(char)
      end
    end
  end,
})

SecPlayer:AddToggle({
  Title = "方框",
  Flag = "p_box",
  Default = true,
  Callback = function(v) CONFIG.esp.pBox = v end,
})

SecPlayer:AddToggle({
  Title = "射线",
  Flag = "p_tracer",
  Default = true,
  Callback = function(v) CONFIG.esp.pTracer = v end,
})

SecPlayer:AddToggle({
  Title = "名字",
  Flag = "p_name",
  Default = true,
  Callback = function(v) CONFIG.esp.pName = v end,
})

SecPlayer:AddToggle({
  Title = "距离",
  Flag = "p_dist",
  Default = true,
  Callback = function(v) CONFIG.esp.pDist = v end,
})

SecPlayer:AddToggle({
  Title = "血量条",
  Flag = "p_hp",
  Default = true,
  Callback = function(v) CONFIG.esp.pHp = v end,
})

SecPlayer:AddSlider({
  Title = "方框大小",
  Flag = "p_scale",
  Min = 1200, Max = 5000, Default = 2500, Increment = 100,
  Callback = function(v) CONFIG.esp.pScale = v end,
})

-- ---------------------------------- 通知 ----------------------------------
Window:AddCategory("通知")
local TabNotify = addTab("通知", "bell")

local SecNotify = TabNotify:AddSection({ Title = "通知（独立模块）", Icon = "bell" })

SecNotify:AddParagraph({
  Title = "和 ESP 没有绑定",
  Content = "这里的通知自己监听游戏事件：ESP 关掉照样弹，通知关掉 ESP 照样画。",
})

SecNotify:AddToggle({
  Title = "启用通知",
  Flag = "n_on",
  Keybind = Enum.KeyCode.F9,
  KeyMode = "Toggle",
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.notify.enabled = v
    if v then playNormal() end
  end,
})

SecNotify:AddToggle({
  Title = "实体出现",
  Description = "A-60 / A-120 / A-250 … 进场时提醒",
  Flag = "n_spawn",
  Default = true,
  Callback = function(v) CONFIG.notify.onSpawn = v end,
})

SecNotify:AddToggle({
  Title = "实体消失",
  Flag = "n_despawn",
  Default = true,
  Callback = function(v) CONFIG.notify.onDespawn = v end,
})

SecNotify:AddToggle({
  Title = "电池出现",
  Flag = "n_battery",
  Default = true,
  Callback = function(v) CONFIG.notify.onBattery = v end,
})

SecNotify:AddToggle({
  Title = "A-666 距离预警",
  Flag = "n_a666",
  Style = "Switch",
  Default = true,
  Callback = function(v) CONFIG.notify.a666 = v end,
})

SecNotify:AddSlider({
  Title = "A-666 预警距离",
  Flag = "n_a666_range",
  Min = 100, Max = 900, Default = 400, Increment = 25, Suffix = " studs",
  Callback = function(v) CONFIG.notify.a666Range = v end,
})

local SecNotifySound = TabNotify:AddSection({ Title = "音效", Icon = "volume-2" })

SecNotifySound:AddToggle({
  Title = "提示音",
  Flag = "n_sound",
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.notify.sound = v
    if v then playNormal() end
  end,
})

SecNotifySound:AddSlider({
  Title = "音量",
  Flag = "n_volume",
  Min = 0.05, Max = 1, Default = 1, Increment = 0.05,
  Callback = function(v)
    CONFIG.notify.volume = v
    playNormal()
  end,
})

SecNotifySound:AddSlider({
  Title = "停留时长",
  Flag = "n_duration",
  Min = 1, Max = 10, Default = 3, Increment = 0.5, Suffix = " s",
  Callback = function(v) CONFIG.notify.duration = v end,
})

SecNotifySound:AddToggle({
  Title = "A-400 双电池警告",
  Description = "自动拾取会跳过这种房间，两块都别拿",
  Flag = "n_a400",
  Default = true,
  Callback = function(v) CONFIG.notify.a400 = v end,
})

-- ---------------------------------- 功能 ----------------------------------
Window:AddCategory("功能")

local TabMove  = addTab("移动", "move")
local TabSurv  = addTab("生存", "shield")
local TabAnti  = addTab("反实体", "zap")
local TabLight = addTab("光照", "sun")

-- 移动
local SecFly = TabMove:AddSection({ Title = "飞行", Icon = "plane" })

SecFly:AddToggle({
  Title = "飞行",
  Description = "WASD 平移，空格上升，Ctrl 下降",
  Flag = "mv_fly",
  Keybind = Enum.KeyCode.V,
  KeyMode = "Toggle",
  Style = "Switch",
  Default = false,
  Callback = function(v) setFly(v) end,
})

SecFly:AddSlider({
  Title = "飞行速度",
  Flag = "mv_fly_speed",
  Min = 10, Max = 250, Default = 60, Increment = 5,
  Callback = function(v) CONFIG.move.flySpeed = v end,
})

local SecSpeed = TabMove:AddSection({ Title = "速度", Icon = "gauge" })

SecSpeed:AddToggle({
  Title = "CFrame 速度",
  Description = "直接改 RootPart 位移，和 Qing Yun 互斥",
  Flag = "mv_cframe",
  Keybind = Enum.KeyCode.F6,
  KeyMode = "Toggle",
  Style = "Switch",
  Default = false,
  Callback = function(v)
    CONFIG.move.cframe = v
    if v then
      CONFIG.move.qing = false
      setFlag("mv_qing", false)
    end
  end,
})

SecSpeed:AddSlider({
  Title = "CFrame 速度值",
  Flag = "mv_cframe_speed",
  Min = 16, Max = 80, Default = 26, Increment = 1,
  Callback = function(v) CONFIG.move.cframeSpeed = v end,
})

SecSpeed:AddToggle({
  Title = "Qing Yun 速度",
  Description = "用 TranslateBy 推人，模型更稳",
  Flag = "mv_qing",
  Bind = true,
  Style = "Switch",
  Default = false,
  Callback = function(v)
    CONFIG.move.qing = v
    if v then
      CONFIG.move.cframe = false
      setFlag("mv_cframe", false)
    end
  end,
})

SecSpeed:AddSlider({
  Title = "Qing Yun 速度值",
  Flag = "mv_qing_speed",
  Min = 16, Max = 120, Default = 26, Increment = 1,
  Callback = function(v) CONFIG.move.qingSpeed = v end,
})

local SecClip = TabMove:AddSection({ Title = "穿墙 / 保护", Icon = "corner-down-right" })

SecClip:AddButton({
  Title = "穿墙冲刺",
  Description = "朝视角方向冲 40 stud 左右，能直接穿门",
  Callback = function() wallclip() end,
})

SecClip:AddKeybind({
  Title = "穿墙冲刺键",
  Description = "按下即触发穿墙，点键位框可改",
  Flag = "key_clip",
  Default = Enum.KeyCode.Z,
  Mode = "Press",
  Callback = function() wallclip() end,
})

SecClip:AddToggle({
  Title = "Rewind 保护",
  Description = "靠近 A-101 / A-201 … 这类房间自动停速度、停冲刺",
  Flag = "mv_rewind",
  Bind = true,
  Style = "Switch",
  Default = true,
  Callback = function(v) CONFIG.move.rewindGuard = v end,
})

local SecSprint = TabMove:AddSection({ Title = "冲刺 / 砸门", Icon = "activity" })

SecSprint:AddToggle({
  Title = "永远冲刺",
  Flag = "mv_sprint",
  Bind = true,
  Style = "Switch",
  Default = false,
  Callback = function(v)
    CONFIG.move.alwaysSprint = v
    if v then scanSprintController(true) end
  end,
})

SecSprint:AddToggle({
  Title = "自动砸门",
  Description = "正面 10 stud 内的门，冲刺时自动触发",
  Flag = "mv_slam",
  Bind = true,
  Style = "Switch",
  Default = false,
  Callback = function(v)
    CONFIG.move.autoSlam = v
    if v then scanSprintController(true) end
  end,
})

local SecPanic = TabMove:AddSection({ Title = "紧急", Icon = "octagon-alert" })

local function doPanic()
  panicStop()
  setFlag("mv_cframe", false)
  setFlag("mv_qing", false)
  setFlag("mv_sprint", false)
  setFlag("mv_slam", false)
  setFlag("sv_pick", false)
  toast("PANIC", "所有移动与自动化已停止", "warn", 4)
end

SecPanic:AddButton({
  Title = "强制停止",
  Description = "一键停掉速度 / 冲刺 / 砸门 / 自动拾取",
  Badge = "STOP",
  Callback = doPanic,
})

SecPanic:AddKeybind({
  Title = "PANIC 快捷键",
  Description = "按下即紧急停止，点键位框可改",
  Flag = "key_panic",
  Default = Enum.KeyCode.F7,
  Mode = "Press",
  Callback = doPanic,
})

-- 生存
local SecGod = TabSurv:AddSection({ Title = "保命", Icon = "heart-pulse" })

SecGod:AddToggle({
  Title = "Godmode",
  Description = "本地 ForceField + 血量回满，只对自己生效",
  Flag = "sv_god",
  Keybind = Enum.KeyCode.G,
  KeyMode = "Toggle",
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.surv.god = v
    if v then godTick() end
  end,
})

SecGod:AddToggle({
  Title = "无限体力",
  Description = "扫描 sprint 控制器，把它按死在上限",
  Flag = "sv_stamina",
  Bind = true,
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.surv.infStamina = v
    if v then
      stamScan()
    else
      stamScanId = stamScanId + 1
      stamController = nil
      stamState = "off"
    end
  end,
})

SecGod:AddToggle({
  Title = "无限手电",
  Description = "把手电电量锁在 100%",
  Flag = "sv_charge",
  Bind = true,
  Style = "Switch",
  Default = true,
  Callback = function(v)
    CONFIG.surv.infCharge = v
    if v then
      chargeScan()
    else
      chargeScanId = chargeScanId + 1
      chargeHolder = nil
      chargeState = "off"
    end
  end,
})

local SecPick = TabSurv:AddSection({ Title = "自动拾取", Icon = "hand" })

SecPick:AddToggle({
  Title = "自动拾取",
  Description = "9 stud 内的电池 / 手电 / 药 / 钥匙，自动触发",
  Flag = "sv_pick",
  Bind = true,
  Style = "Switch",
  Default = false,
  Callback = function(v) CONFIG.surv.autoPick = v end,
})

SecPick:AddParagraph({
  Title = "A-400 保护",
  Content = "一个房间出现两块电池 = A-400 陷阱。自动拾取会整间跳过，并且弹警告。",
})

-- 反实体
local SecAnti = TabAnti:AddSection({ Title = "反实体", Icon = "zap" })

SecAnti:AddParagraph({
  Title = "注意",
  Content = "这是本地修改：删除本地 Workspace 里的实体，以及给 ReplicatedStorage 的模板改名。只对自己客户端有效。",
})

SecAnti:AddToggle({
  Title = "ANTI A-60",
  Flag = "an_a60",
  Bind = true,
  Default = true,
  Callback = function(v) CONFIG.anti.a60 = v end,
})

SecAnti:AddToggle({
  Title = "ANTI A-60 Prime",
  Flag = "an_a60p",
  Bind = true,
  Default = true,
  Callback = function(v) CONFIG.anti.a60prime = v end,
})

SecAnti:AddToggle({
  Title = "ANTI A-50",
  Flag = "an_a50",
  Bind = true,
  Default = true,
  Callback = function(v) CONFIG.anti.a50 = v end,
})

SecAnti:AddToggle({
  Title = "ANTI A-1（红骷髅）",
  Flag = "an_a1",
  Bind = true,
  Default = true,
  Callback = function(v) CONFIG.anti.a1 = v end,
})

SecAnti:AddToggle({
  Title = "ANTI A-90",
  Flag = "an_a90",
  Bind = true,
  Default = true,
  Callback = function(v) CONFIG.anti.a90 = v end,
})

SecAnti:AddToggle({
  Title = "ANTI A-90 Prime",
  Flag = "an_a90p",
  Bind = true,
  Default = true,
  Callback = function(v) CONFIG.anti.a90prime = v end,
})

-- 光照
local SecBright = TabLight:AddSection({ Title = "亮度", Icon = "sun" })

SecBright:AddToggle({
  Title = "Fullbright",
  Flag = "lt_full",
  Bind = true,
  Style = "Switch",
  Default = false,
  Callback = function(v) applyFullbright(v) end,
})

local SecLamp = TabLight:AddSection({ Title = "随身光源", Icon = "lightbulb" })

SecLamp:AddToggle({
  Title = "随身光源",
  Description = "在 HumanoidRootPart 挂一盏 PointLight",
  Flag = "lt_lamp",
  Keybind = Enum.KeyCode.F8,
  KeyMode = "Toggle",
  Style = "Switch",
  Default = false,
  Callback = function(v)
    CONFIG.light.fakeLight = v
    refreshFakeLight()
  end,
})

SecLamp:AddSlider({
  Title = "亮度",
  Flag = "lt_bright",
  Min = 0, Max = 10, Default = 1.5, Increment = 0.5,
  Callback = function(v)
    CONFIG.light.brightness = v
    refreshFakeLight()
  end,
})

SecLamp:AddSlider({
  Title = "范围",
  Flag = "lt_range",
  Min = 10, Max = 200, Default = 60, Increment = 5,
  Callback = function(v)
    CONFIG.light.range = v
    refreshFakeLight()
  end,
})

-- ---------------------------------- 设置 ----------------------------------
Window:AddCategory("其他")
local TabSet = addTab("设置", "settings")

local SecLook = TabSet:AddSection({ Title = "外观", Icon = "palette" })

SecLook:AddDropdown({
  Title = "主题",
  Flag = "ui_theme",
  Values = NextUI.ThemeOrder,
  Default = "Phoenix",
  Callback = function(name) NextUI:SetTheme(name) end,
})

SecLook:AddToggle({
  Title = "毛玻璃",
  Flag = "ui_glass",
  Style = "Switch",
  Default = true,
  Callback = function(v) NextUI:SetGlass(v) end,
})

local SecAbout = TabSet:AddSection({ Title = "关于", Icon = "info" })

local function nukeAllESP()
  CONFIG.esp.entityOn = false
  CONFIG.esp.playerOn = false
  CONFIG.esp.batteryOn = false
  for key in pairs(CONFIG.esp.env) do CONFIG.esp.env[key] = false end

  clearEntityESP()
  clearBatteryESP()
  for char in pairs(PlayerESP) do removePlayerESP(char) end
  for obj in pairs(EnvESP) do removeEnvESP(obj) end
  flushDrawings()

  setFlag("e_on", false)
  setFlag("p_on", false)
  setFlag("b_on", false)
  setFlag("env_shell", false)
  setFlag("env_locker", false)
  setFlag("env_table", false)
  setFlag("env_door", false)
  setFlag("env_objective", false)
end

SecAbout:AddButton({
  Title = "强制清屏",
  Description = "透视卡在屏幕上清不掉时按这个：销毁所有绘制并关掉全部透视",
  Badge = "修复",
  Callback = function()
    nukeAllESP()
    toast("已清屏", "所有透视绘制已销毁并关闭", "success", 3)
  end,
})

SecAbout:AddButton({
  Title = "卸载脚本",
  Description = "断开所有连接并清理绘制",
  Badge = "危险",
  Hold = 1.5,
  Callback = function()
    if UNLOADED then return end
    UNLOADED = true
    nukeAllESP()
    for _, conn in ipairs(CONNS) do
      pcall(function() conn:Disconnect() end)
    end
    CONNS = {}
    setFly(false)
    setSprint(false)
    applyFullbright(false)
    CONFIG.light.fakeLight = false
    refreshFakeLight()
    CONFIG.surv.god = false
    godTick()
    pcall(function() NextUI:Destroy() end)
  end,
})

-- ============================================================================
-- [15] 快捷键 / 角色重生
-- ============================================================================

bind(LocalPlayer.CharacterAdded, function(char)
  task.wait(0.5)
  local hrp = char:WaitForChild("HumanoidRootPart", 10)
  if CONFIG.move.fly and hrp then hrp.Anchored = true end
  if CONFIG.light.fakeLight then refreshFakeLight() end
  if CONFIG.esp.playerOn then
    for charObj in pairs(PlayerESP) do
      if charObj.Parent == nil then removePlayerESP(charObj) end
    end
  end
end)

-- 启动
refreshPlayers()
seedNotifier()
task.spawn(function()
  task.wait(2)
  if CONFIG.esp.entityOn then scanEntities() end
end)

if not hasDrawing then
  toast("ESP 不可用", "当前执行器没有 Drawing 库，透视不会显示（其他功能正常）", "error", 8)
else
  toast("CatMeowWave", "加载完成 · H / 右Shift 开关菜单", "success", 10)
end
print("[CatMeowWave] Rooms & Doors已载入")
