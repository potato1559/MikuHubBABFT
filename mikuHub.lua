--[[ mikuHub  -  made by miku 
     Build / convert / auto-farm helper with a lightweight PC + mobile UI
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local R = { highlights = {}, hlContainer = nil }
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local bit = bit32

local LocalPlayer = Players.LocalPlayer or Players:WaitForChild("LocalPlayer", 30)
local function safeWaitChild(parent, childName, timeout)
    local started = tick()
    timeout = timeout or 30
    while parent and (tick() - started) < timeout do
        local ok, child = pcall(function()
            return parent:FindFirstChild(childName)
        end)
        if ok and child then return child end
        task.wait(0.05)
    end
    local ok, child = pcall(function()
        return parent and parent:FindFirstChild(childName)
    end)
    if ok then return child end
    return nil
end
local Character = LocalPlayer.Character
while not Character do
    Character = LocalPlayer.Character
    task.wait(0.05)
end
local function getHumanoid(model)
    if not model then return nil end
    local h = model:FindFirstChildOfClass("Humanoid") or model:FindFirstChild("Humanoid")
    if h then return h end
    return safeWaitChild(model, "Humanoid", 10)
end
local Humanoid = getHumanoid(Character)
local BlocksFolder = safeWaitChild(Workspace, "Blocks", 30) or safeWaitChild(Workspace, "Block", 30)
local BlockData = safeWaitChild(LocalPlayer, "Data", 30)
local BuildingParts = safeWaitChild(ReplicatedStorage, "BuildingParts", 30)

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local FOLDER_PATH = "mikuHub"
local FOLDER_PREFIX = FOLDER_PATH .. "/"
local SETTINGS_PATH = "mikuHub_Settings.json"
local CUSTOM_SCRIPTS_PATH = "mikuHub_CustomScripts.json"
local BUILD_SEARCH_PATHS = {
    FOLDER_PREFIX,
    "SOPERA_WORKSPACE/",
    "BABFT/",
    "BABFT/Build/",
    "Build/",
}

local PreviewFolder = Workspace:FindFirstChild("mikuHub_Preview") or Instance.new("Folder")
PreviewFolder.Name = "mikuHub_Preview"
PreviewFolder.Parent = Workspace

local Settings = {
    previewTransparency = 0.5,
    guiTransparency = 0.15,
    autoPreview = true,
    showBlockCounts = true,
    uiScale = isMobile and 0.72 or 1.0,
    mobileMode = isMobile,
    buildScale = 1.0,
    buildOffsetX = 0,
    buildOffsetY = 3,
    buildOffsetZ = 0,
    infBlockEnabled = false,
    infBlockSlot1 = 2,
    infBlockSlot2 = 3,
    skyHeight = 500,
    primaryColor = Color3.fromRGB(72, 205, 176),
    secondaryColor = Color3.fromRGB(150, 225, 220),
    uiMinimized = false,
    windowPosX = -1,
    windowPosY = -1,
    windowWidth = -1,
    windowHeight = -1,
    replacePosX = -1,
    replacePosY = -1,
    replaceW = -1,
    replaceH = -1,
    paintPosX = -1,
    paintPosY = -1,
    paintW = -1,
    paintH = -1,

    excludedBlocks = {},
    buildSpeed = 0,
    bgMode = "default",
    bgAnim = "grid",
    bgAnimEnabled = true,
    bgAnimAutoColor = true,
    bgAnimColor = Color3.fromRGB(90, 60, 200),
    bgAnimCount = 12,
    bgAnimSpeed = 1.0,
    bgAnimSize = 1.0,
    bgCustomColor = Color3.fromRGB(12, 8, 24),
    blockReplacements = {},
    lang = "en",
}

local Settings_DEFAULTS = {}
for _k, _v in pairs(Settings) do
    Settings_DEFAULTS[_k] = _v
end

local selectedPlayer = nil
local currentBuild = {}
local isBuilding = false
local stopBuild = false
local shareBlocksOriginal = false
local previewActive = false
local selectedObjectName = nil
local previewParts = {}
local selectionBoxes = {}

local updatePreviewButtonGlobal = nil
local updateBlocksDisplayGlobal = nil
local StatusLabelRef = nil
local MiscStatusLabelRef = nil
local InfProgressLabelRef = nil
local InfProgressFillRef = nil
local ProgressBarFillRef = nil
local DupeInfoLabelRef = nil
local DupePercentLabelRef = nil

local Colors = {
    BG = Color3.fromRGB(8, 8, 8),
    Panel = Color3.fromRGB(18, 18, 18),
    PanelSoft = Color3.fromRGB(14, 14, 14),
    PanelElevated = Color3.fromRGB(24, 24, 24),
    Border = Color3.fromRGB(255, 255, 255),
    Text = Color3.fromRGB(255, 255, 255),
    Muted = Color3.fromRGB(140, 140, 140),
    ActiveBG = Color3.fromRGB(255, 255, 255),
    ActiveText = Color3.fromRGB(0, 0, 0),
    Green = Color3.fromRGB(80, 200, 80),
    Red = Color3.fromRGB(200, 80, 80),
    AccentSoft = Color3.fromRGB(180, 180, 180),
    AccentGlow = Color3.fromRGB(235, 235, 235),
}

local UISoundConfig = {
    volume = 2,
    click = "rbxassetid://139719503904449",
    open = "rbxassetid://136108770017536",
    close = "rbxassetid://119354387183704",
    hover = "rbxassetid://7218169592",
    success = "rbxassetid://90420386076500",
    error = "rbxassetid://131661013076677",
    explode = "rbxassetid://139771888058836",
}

local function showFormatWarning() end
local function syncColors() end

local function playUISound(soundId)
    if not soundId or soundId == "" then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = soundId
        s.Volume = UISoundConfig.volume
        s.Parent = SoundService
        s.Ended:Connect(function()
            s:Destroy()
        end)
        pcall(function() s:Play() end)
        task.delay(2, function()
            if s and s.Parent then s:Destroy() end
        end)
    end)
end

local function ensureFolder()
    if isfolder(FOLDER_PATH) then
        return
    end

    makefolder(FOLDER_PATH)
end

local _cachedSearchPaths = nil

local function scanAllFolders(maxDepth)
    local paths, seen = {}, {}
    local function scanRecursive(basePath, depth)
        if depth <= 0 then return end
        local ok, items = pcall(listfiles, basePath)
        if not ok or type(items) ~= "table" then return end
        for _, fp in ipairs(items) do
            if type(fp) == "string" and isfolder(fp) and not seen[fp] then
                seen[fp] = true
                paths[#paths + 1] = fp
                scanRecursive(fp, depth - 1)
            end
        end
    end
    scanRecursive(".", maxDepth or 2)
    return paths
end

local function getBuildSearchPaths()
    if _cachedSearchPaths then return _cachedSearchPaths end
    local paths, seen = {}, {}
    for _, path in ipairs(BUILD_SEARCH_PATHS) do
        if not seen[path] then
            paths[#paths + 1] = path
            seen[path] = true
        end
    end
    if not seen[FOLDER_PREFIX] then
        paths[#paths + 1] = FOLDER_PREFIX
    end

    local allFolders = scanAllFolders(2)
    for _, fp in ipairs(allFolders) do
        if not seen[fp] then
            paths[#paths + 1] = fp
            seen[fp] = true
        end
    end
    _cachedSearchPaths = paths
    return paths
end

local function invalidateSearchCache()
    _cachedSearchPaths = nil
end

local function loadSettings()
    if not isfile(SETTINGS_PATH) then return end
    local raw = ""
    local ok1, err1 = pcall(function() raw = readfile(SETTINGS_PATH) end)
    if not ok1 or type(raw) ~= "string" or #raw == 0 then
        pcall(function() delfile(SETTINGS_PATH) end)
        return
    end
    local data
    local ok2, err2 = pcall(function() data = HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then
        pcall(function() delfile(SETTINGS_PATH) end)
        return
    end

    for k, v in pairs(data) do
        pcall(function()
            if Settings[k] == nil then return end
            if typeof(Settings[k]) == "Color3" then
                if type(v) == "table" then
                    local r = tonumber(v.R or v.r or v[1]) or 0
                    local g = tonumber(v.G or v.g or v[2]) or 0
                    local b = tonumber(v.B or v.b or v[3]) or 0
                    if r > 1 or g > 1 or b > 1 then
                        r = r / 255; g = g / 255; b = b / 255
                    end
                    r = math.clamp(r, 0, 1)
                    g = math.clamp(g, 0, 1)
                    b = math.clamp(b, 0, 1)
                    Settings[k] = Color3.new(r, g, b)
                end
            elseif type(v) ~= "table" then
                local tv = type(v)
                local sk = type(Settings[k])
                if (sk == "number" and tv == "number") or (sk == "string" and tv == "string") or (sk == "boolean" and tv == "boolean") then
                    Settings[k] = v
                end
            elseif type(Settings[k]) == "table" then
                Settings[k] = v
            end
        end)
    end
    Settings.blockReplacements = {}

    for k, v in pairs(Settings) do
        pcall(function()
            if typeof(Settings_DEFAULTS[k]) == "Color3" and typeof(v) ~= "Color3" then
                Settings[k] = Settings_DEFAULTS[k]
            end
        end)
    end

    if Settings.bgMode == "image" then Settings.bgMode = "default" end
    if type(Settings.guiTransparency) == "number" then
        Settings.guiTransparency = math.clamp(Settings.guiTransparency, 0, 0.95)
    end
    if type(Settings.uiScale) == "number" then
        Settings.uiScale = math.clamp(Settings.uiScale, 0.4, 2.0)
    end
    if type(Settings.buildScale) == "number" then
        Settings.buildScale = math.clamp(Settings.buildScale, 0.1, 10)
    end
end

local _saveQueued = false

local function saveSettings()

    if _saveQueued then return end
    _saveQueued = true
    task.delay(0.5, function()
        _saveQueued = false

        local d = {}
        for k, v in pairs(Settings) do
            if k == "blockReplacements" then continue end
            if typeof(v) == "Color3" then
                local r = math.clamp(v.R, 0, 1)
                local g = math.clamp(v.G, 0, 1)
                local b = math.clamp(v.B, 0, 1)
                d[k] = {r, g, b}
            elseif type(v) == "table" then
                local safe = true
                local clean = {}
                for tk, tv in pairs(v) do
                    local tvt = type(tv)
                    if tvt == "string" or tvt == "number" or tvt == "boolean" then
                        clean[tk] = tv
                    else
                        safe = false; break
                    end
                end
                if safe then d[k] = clean end
            elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
                d[k] = v
            end
        end
        local ok, json = pcall(function() return HttpService:JSONEncode(d) end)
        if ok and type(json) == "string" and #json > 0 then
            pcall(function() writefile(SETTINGS_PATH, json) end)
        else
        end
    end)
end

local function loadCustomScripts()
    if not isfile(CUSTOM_SCRIPTS_PATH) then return {windows={}} end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CUSTOM_SCRIPTS_PATH)) end)
    return (ok and data and data.windows) and data or {windows={}}
end

local function saveCustomScripts(data)
    writefile(CUSTOM_SCRIPTS_PATH, HttpService:JSONEncode(data or {windows={}}))
end

local function getBlockID(blockName)
    local c = BlockData:FindFirstChild(blockName)
    return c and c.Value or 0
end

local function getRealBlockCount(blockName)
    pcall(function()
        local bg = LocalPlayer.PlayerGui:FindFirstChild("BuildGui")
        if bg then
            local inv = bg:FindFirstChild("InventoryFrame")
            if inv then
                local sf = inv:FindFirstChild("ScrollingFrame")
                if sf then
                    local bf = sf:FindFirstChild(blockName)
                    if bf then
                        local at = bf:FindFirstChild("AmountText")
                        if at and at.Text then
                            return tonumber(at.Text) or 0
                        end
                    end
                end
            end
        end
    end)
    return getBlockID(blockName)
end

local function getPlayerZone(player)
    for _, zone in pairs(Workspace:GetChildren()) do
        if zone:FindFirstChild("TeamColor") and zone.TeamColor.Value == player.TeamColor then
            return zone
        end
    end
end

local function getPlayerList()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        local d = p.Name
        if p.DisplayName ~= p.Name then d = p.DisplayName .. " (" .. p.Name .. ")" end
        if p == LocalPlayer then d = d .. " [ME]" end
        table.insert(list, {name=p.Name, display=d})
    end
    return list
end

local function cfStr(cf)
    return string.format("%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f", cf:GetComponents())
end

local function parseNums(s)
    if type(s) ~= "string" then return {} end
    local r = {}
    for p in s:gmatch("[^,%s]+") do
        local n = tonumber(p)
        if n then table.insert(r, n) end
    end
    return r
end

local function strV3(s)
    if type(s) == "string" then
        local c = {}
        for v in s:gmatch("[^,]+") do table.insert(c, tonumber(v:match("^%s*(.-)%s*$")) or 0) end
        return #c >= 3 and Vector3.new(c[1],c[2],c[3]) or Vector3.new(0,0,0)
    elseif type(s) == "table" then

        local x = tonumber(s[1] or s.X) or 0
        local y = tonumber(s[2] or s.Y) or 0
        local z = tonumber(s[3] or s.Z) or 0
        return Vector3.new(x, y, z)
    end
    return Vector3.new(0,0,0)
end

local function v3Str(v) return string.format("%.4f,%.4f,%.4f", v.X, v.Y, v.Z) end

local function strCF(s)
    if type(s) ~= "string" then return nil end
    local c = {}
    for v in s:gmatch("[^,]+") do
        local n = tonumber(v:match("^%s*(.-)%s*$"))
        if n then table.insert(c, n) end
    end
    if #c >= 12 then return CFrame.new(table.unpack(c)) end
    return nil
end

local function colStr(c) return string.format("%.4f,%.4f,%.4f", c.R, c.G, c.B) end
local function strCol(s)
    if type(s) ~= "string" then return Color3.new(1,1,1) end
    local c = {}
    for v in s:gmatch("[^,]+") do table.insert(c, tonumber(v) or 1) end
    if #c >= 3 then
        local r,g,b = c[1],c[2],c[3]

        if r > 1 or g > 1 or b > 1 then
            r = r/255; g = g/255; b = b/255
        end
        return Color3.new(math.clamp(r,0,1), math.clamp(g,0,1), math.clamp(b,0,1))
    end
    return Color3.new(1,1,1)
end

local function getBlockCF(bi)

    if bi.CFrame then
        if type(bi.CFrame) == "string" then
            local cf = strCF(bi.CFrame)
            if cf then return cf end
        elseif type(bi.CFrame) == "table" and #bi.CFrame >= 12 then

            return CFrame.new(table.unpack(bi.CFrame))
        end
    end

    local posRaw = bi.Position or bi.position or bi.Pos or bi.pos
    local rotRaw = bi.Rotation or bi.rotation or bi.Rot or bi.rot
    if posRaw then
        local pos = strV3(posRaw)
        if rotRaw then
            local r = {}
            if type(rotRaw) == "string" then
                for v in rotRaw:gmatch("[^,]+") do
                    local n = tonumber(v:match("^%s*(.-)%s*$"))
                    if n then table.insert(r, math.rad(n)) end
                end
            elseif type(rotRaw) == "table" then
                for i = 1, 3 do
                    local v = rotRaw[i] or rotRaw[("XYZ"):sub(i,i)]
                    table.insert(r, math.rad(tonumber(v) or 0))
                end
            end
            if #r >= 3 then
                return CFrame.new(pos) * CFrame.Angles(r[1], r[2], r[3])
            end
        end
        return CFrame.new(pos)
    end

    return CFrame.new(0, 0, 0)
end

local function parseColorRGBA(rgba)
    if type(rgba) ~= "table" then return "1.000000, 1.000000, 1.000000" end
    local r = (tonumber(rgba[1]) or 255) / 255
    local g = (tonumber(rgba[2]) or 255) / 255
    local b = (tonumber(rgba[3]) or 255) / 255
    return string.format("%.6f, %.6f, %.6f", math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local function geomGetAABB(shape)
    if type(shape) ~= "table" then return nil end
    local t = tonumber(shape.type) or -1
    local d = shape.data
    if type(d) ~= "table" then return nil end
    local function min(a, b) return (a < b) and a or b end
    local function max(a, b) return (a > b) and a or b end
    if (t == 0 or t == 2) and #d >= 4 then
        local x0, y0, x1, y1 = d[1], d[2], d[3], d[4]
        return {min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)}
    elseif t == 1 and #d >= 5 then
        local x0, y0, x1, y1, ang = d[1], d[2], d[3], d[4], d[5]
        local cx = (x0 + x1) / 2
        local cy = (y0 + y1) / 2
        local rx = math.abs(x1 - x0) / 2
        local ry = math.abs(y1 - y0) / 2
        local rad = math.rad(ang)
        local hw = math.sqrt((rx * math.cos(rad)) ^ 2 + (ry * math.sin(rad)) ^ 2)
        local hh = math.sqrt((rx * math.sin(rad)) ^ 2 + (ry * math.cos(rad)) ^ 2)
        return {cx - hw, cy - hh, cx + hw, cy + hh}
    elseif t == 3 and #d >= 3 then
        local cx, cy, r = d[1], d[2], d[3]
        return {cx - r, cy - r, cx + r, cy + r}
    elseif t == 4 and #d >= 6 then
        local xs = {d[1], d[3], d[5]}
        local ys = {d[2], d[4], d[6]}
        local xMin, xMax = xs[1], xs[1]
        local yMin, yMax = ys[1], ys[1]
        for i = 2, 3 do
            xMin = min(xMin, xs[i]); xMax = max(xMax, xs[i])
            yMin = min(yMin, ys[i]); yMax = max(yMax, ys[i])
        end
        return {xMin, yMin, xMax, yMax}
    elseif t == 5 and #d >= 4 then
        local x0, y0, x1, y1 = d[1], d[2], d[3], d[4]
        local lw = tonumber(d[5]) or 1
        local half = lw / 2
        return {min(x0, x1) - half, min(y0, y1) - half, max(x0, x1) + half, max(y0, y1) + half}
    end
    return nil
end

local function geomAABBIntersects(a, b)
    return not (a[3] <= b[1] or b[3] <= a[1] or a[4] <= b[2] or b[4] <= a[2])
end

local function geomComputeZPositions(shapes, thickness)
    local step = thickness
    local placed = {}
    local results = {}
    for i, shape in ipairs(shapes) do
        local aabb = geomGetAABB(shape)
        if not aabb then
            results[i] = 0
        else
            local maxZ = -step
            for _, prev in ipairs(placed) do
                local prevAABB, prevZ = prev[1], prev[2]
                if geomAABBIntersects(aabb, prevAABB) then
                    if prevZ > maxZ then maxZ = prevZ end
                end
            end
            local z = maxZ + step
            results[i] = z
            placed[#placed + 1] = {aabb, z}
        end
    end
    return results
end

local function geomMakeBlock(cx, cy, zPos, w, h, thickness, rotZ, colorStr, transparency, blockId)




    return {
        ShowShadow = true,
        CanCollide = true,
        Color = colorStr,
        Anchored = true,
        BoolValues = {},
        Rotation = string.format("0.000, 0.000, %.3f", -rotZ),
        Transparency = transparency,
        Position = string.format("%.6f, %.6f, %.6f", cx, -cy, zPos + thickness / 2),
        ID = blockId,
        NumberValues = {},
        Size = string.format("%.6f, %.6f, %.6f", w, h, thickness),
    }
end

local function geomGetBounds(shapes)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local function addPoint(x, y)
        x, y = tonumber(x), tonumber(y)
        if not x or not y then return end
        minX = math.min(minX, x)
        minY = math.min(minY, y)
        maxX = math.max(maxX, x)
        maxY = math.max(maxY, y)
    end

    for _, shape in ipairs(shapes) do
        if type(shape) == "table" and type(shape.data) == "table" then
            local stype = tonumber(shape.type) or -1
            local data = shape.data
            if (stype == 0 or stype == 1 or stype == 2) and #data >= 4 then
                addPoint(data[1], data[2])
                addPoint(data[3], data[4])
            elseif stype == 3 and #data >= 3 then
                local x, y, r = tonumber(data[1]), tonumber(data[2]), tonumber(data[3]) or 0
                if x and y then
                    addPoint(x - r, y - r)
                    addPoint(x + r, y + r)
                end
            elseif stype == 4 and #data >= 6 then
                addPoint(data[1], data[2])
                addPoint(data[3], data[4])
                addPoint(data[5], data[6])
            elseif stype == 5 and #data >= 4 then
                addPoint(data[1], data[2])
                addPoint(data[3], data[4])
            end
        end
    end

    if minX == math.huge then return nil end
    return minX, minY, maxX, maxY
end


local compactBlockToJSON
local writeBuildJSON

local function convertGeometrizeJsonToBlocks(jsonText, scale, thickness, material, targetWidth, targetLength)
    local decodeOk, rawData = pcall(function()
        return HttpService:JSONDecode(jsonText)
    end)
    if not decodeOk or type(rawData) ~= "table" then
        return nil, nil, "Invalid JSON: " .. tostring(rawData)
    end

    local shapes = rawData.shapes or rawData
    if type(shapes) ~= "table" or #shapes == 0 then
        return nil, nil, "No shapes found in JSON"
    end
    scale = tonumber(scale) or 0.035
    thickness = tonumber(thickness) or 0.001
    if scale <= 0 or thickness <= 0 then return nil, nil, "Scale/thickness must be > 0" end
    material = tostring(material or "PlasticBlock")
    targetWidth = tonumber(targetWidth) or 0
    targetLength = tonumber(targetLength) or 0

    local scaleX, scaleY = scale, scale
    if targetWidth > 0 or targetLength > 0 then
        local minX, minY, maxX, maxY = geomGetBounds(shapes)
        if minX then
            local rawW = math.max(0.001, maxX - minX)
            local rawH = math.max(0.001, maxY - minY)
            if targetWidth > 0 then scaleX = targetWidth / rawW end
            if targetLength > 0 then scaleY = targetLength / rawH end
        end
    end

    local zPositions = geomComputeZPositions(shapes, thickness)
    local blocks = {}
    local currentId = 1

    for i, shape in ipairs(shapes) do
        if type(shape) ~= "table" then continue end
        local stype = tonumber(shape.type) or -1
        local data = shape.data
        local color = shape.color
        if type(data) ~= "table" then continue end

        local transparency = 0
        local colorStr = parseColorRGBA(color)
        local layerZ = zPositions[i] or 0

        if stype == 1 and #data >= 5 then
            local x0, y0, x1, y1, angle = data[1], data[2], data[3], data[4], data[5]
            local cx = (x0 + x1) / 2 * scaleX
            local cy = (y0 + y1) / 2 * scaleY
            local w = math.abs(x1 - x0) * scaleX
            local h = math.abs(y1 - y0) * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, w, h, thickness, tonumber(angle) or 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif (stype == 0 or stype == 2) and #data >= 4 then
            local x0, y0, x1, y1 = data[1], data[2], data[3], data[4]
            local cx = (x0 + x1) / 2 * scaleX
            local cy = (y0 + y1) / 2 * scaleY
            local w = math.abs(x1 - x0) * scaleX
            local h = math.abs(y1 - y0) * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, w, h, thickness, 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif stype == 3 and #data >= 3 then
            local cxRaw, cyRaw, r = data[1], data[2], data[3]
            local w = r * 2 * scaleX
            local h = r * 2 * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cxRaw * scaleX, cyRaw * scaleY, layerZ, w, h, thickness, 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif stype == 4 and #data >= 6 then
            local ptsX = {data[1], data[3], data[5]}
            local ptsY = {data[2], data[4], data[6]}
            local cx = (ptsX[1] + ptsX[2] + ptsX[3]) / 3 * scaleX
            local cy = (ptsY[1] + ptsY[2] + ptsY[3]) / 3 * scaleY
            local xMin, xMax = math.min(ptsX[1], ptsX[2], ptsX[3]), math.max(ptsX[1], ptsX[2], ptsX[3])
            local yMin, yMax = math.min(ptsY[1], ptsY[2], ptsY[3]), math.max(ptsY[1], ptsY[2], ptsY[3])
            local w = (xMax - xMin) * scaleX
            local h = (yMax - yMin) * scaleY
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, w, h, thickness, 0, colorStr, transparency, currentId)
            currentId = currentId + 1
        elseif stype == 5 and #data >= 4 then
            local x0, y0, x1, y1 = data[1], data[2], data[3], data[4]
            local lw = tonumber(data[5]) or 1
            local dx = (x1 - x0) * scaleX
            local dy = (y1 - y0) * scaleY
            local cx = (x0 + x1) / 2 * scaleX
            local cy = (y0 + y1) / 2 * scaleY
            local length = math.sqrt(dx ^ 2 + dy ^ 2)
            local angleZ = math.deg(math.atan2(-dy, dx))
            blocks[#blocks + 1] = geomMakeBlock(cx, cy, layerZ, length, lw * math.min(scaleX, scaleY), thickness, -angleZ, colorStr, transparency, currentId)
            currentId = currentId + 1
        end
    end

    if #blocks == 0 then
        return nil, nil, "Image produced no blocks"
    end


    local minY = math.huge
    for _, blk in ipairs(blocks) do
        if blk.Position then
            local nums = parseNums(blk.Position)
            if #nums >= 3 and nums[2] < minY then
                minY = nums[2]
            end
        end
    end
    if minY < 4 then
        local yShift = 4 - minY
        for _, blk in ipairs(blocks) do
            if blk.Position then
                local nums = parseNums(blk.Position)
                if #nums >= 3 then
                    nums[2] = nums[2] + yShift
                    blk.Position = string.format("%.6f, %.6f, %.6f", nums[1], nums[2], nums[3])
                end
            end
        end
    end

    return material, blocks, nil
end

local function convertGeometrizeJsonToBuild(jsonText, buildName, scale, thickness, material, targetWidth, targetLength)
    local outMaterial, blocks, err = convertGeometrizeJsonToBlocks(jsonText, scale, thickness, material, targetWidth, targetLength)
    if not outMaterial then
        return nil, err
    end
    local safeName = tostring(buildName or ""):gsub("^%s*(.-)%s*$", "%1")
    if safeName == "" then
        return nil, "Output name is empty"
    end
    ensureFolder()
    local outPath = FOLDER_PREFIX .. safeName .. ".Build"
    writeBuildJSON(outPath, outMaterial, blocks)
    return outPath, nil
end

local function trimStr(s)
    return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function startsWithDrivePath(s)
    return s:match("^%a:[/\\]") ~= nil or s:sub(1, 2) == "\\\\"
end

local function isAbsolutePath(s)
    s = trimStr(s)
    return s:sub(1, 1) == "/" or startsWithDrivePath(s)
end

local function getFileStem(path)
    local name = tostring(path or ""):match("([^/\\]+)$") or tostring(path or "")
    return (name:gsub("%.[^%.]+$", ""))
end

local function joinPath(dir, name)
    if dir == "" then return name end
    local sep = dir:match("[/\\]$") and "" or "/"
    return dir .. sep .. name
end

local function resolveConverterPath(rawPath)
    local candidate = trimStr(rawPath)
    if candidate == "" then
        return nil, "Select a converter file"
    end
    candidate = candidate:gsub('^"(.*)"$', "%1")
    if isfile(candidate) then
        return candidate
    end
    local probes = {}
    if isAbsolutePath(candidate) then
        probes[#probes + 1] = candidate
    else
        probes[#probes + 1] = FOLDER_PREFIX .. candidate
        probes[#probes + 1] = candidate
    end
    for _, probe in ipairs(probes) do
        if isfile(probe) then
            return probe
        end
    end
    return nil, "File not found: " .. candidate
end

local function getParentDir(path)
    local cleaned = trimStr(path)
    if cleaned == "" then
        return nil
    end
    if isfolder(cleaned) then
        return cleaned
    end
    return cleaned:match("^(.*)[/\\][^/\\]+$")
end

local function rgbStr(r, g, b)
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    return string.format("%.4f,%.4f,%.4f", math.clamp(r, 0, 1), math.clamp(g, 0, 1), math.clamp(b, 0, 1))
end

local function cfToAsuBlock(cf, sizeVec, colorStr, blockId, transparency)
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    local pos = cf.Position
    return {
        ShowShadow = true,
        CanCollide = true,
        Color = colorStr or rgbStr(1, 1, 1),
        Anchored = true,
        BoolValues = {},
        Rotation = string.format("%.6f, %.6f, %.6f", math.deg(rx), math.deg(ry), math.deg(rz)),
        Transparency = transparency or 0,
        Position = string.format("%.6f, %.6f, %.6f", pos.X, pos.Y, pos.Z),
        ID = blockId or 0,
        NumberValues = {},
        Size = string.format("%.6f, %.6f, %.6f", sizeVec.X, sizeVec.Y, sizeVec.Z),
    }
end

local function cloneJsonValue(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = cloneJsonValue(v)
    end
    return out
end

local ASU_MAPPED_KEYS = {

    Position = true, position = true, Pos = true, pos = true,
    Rotation = true, rotation = true, Rot = true, rot = true,
    CFrame = true, cframe = true,

    Size = true, size = true,
    Color = true, color = true, Col = true, col = true,
    Transparency = true, transparency = true,
    ShowShadow = true, showShadow = true,
    Material = true, material = true,
    Text = true, text = true,

    Anchored = true, anchored = true,
    CanCollide = true, canCollide = true,

    BoolValues = true, boolValues = true,
    NumberValues = true, numberValues = true,
    BindTable = true, bindTable = true,
    ID = true, id = true,

    SecondaryPartPosition = true, secondaryPartPosition = true,
    SecondaryPartRotation = true, secondaryPartRotation = true,
    SecCFrame = true, secCFrame = true,
    Stiffness = true, stiffness = true,
    Damping = true, damping = true,
    TargetLength = true, targetLength = true,
    MaxLength = true, maxLength = true,
    MinLength = true, minLength = true,
    Length = true, length = true,
    AngleLimit = true, angleLimit = true,
    MatchRotation = true, matchRotation = true,
    ShowConstraint = true, showConstraint = true,
    ServoTorque = true, servoTorque = true,
    ServoSpeed = true, servoSpeed = true,
    BarLength = true, barLength = true,
    WheelTorque = true, wheelTorque = true,
    MaxForce = true, maxForce = true,
    Speed = true, speed = true,
    WaitDuration = true, waitDuration = true,
    Health = true, health = true,
    ExtendLength = true, extendLength = true,
    LastDirrection = true, lastDirrection = true,
}

local function collectAsuExtras(block)
    local extras = {}
    for k, v in pairs(block) do
        if not ASU_MAPPED_KEYS[k] then
            extras[k] = cloneJsonValue(v)
        end
    end
    if next(extras) then
        return extras
    end
    return nil
end

local function mergePropertyMaps(boolValues, numberValues, extras)
    local outBool = {}
    local outNum = {}

    if type(boolValues) == "table" then
        for k, v in pairs(boolValues) do
            outBool[k] = v
        end
    end
    if type(numberValues) == "table" then
        for k, v in pairs(numberValues) do
            outNum[k] = v
        end
    end
    if type(extras) == "table" then
        for k, v in pairs(extras) do
            local vt = type(v)
            if vt == "boolean" then
                if outBool[k] == nil then
                    outBool[k] = v
                end
            elseif vt == "number" then
                if outNum[k] == nil then
                    outNum[k] = v
                end
            elseif vt == "string" then
                local lower = string.lower(v)
                if outBool[k] == nil and (lower == "true" or lower == "false") then
                    outBool[k] = lower == "true"
                elseif outNum[k] == nil then
                    local n = tonumber(v)
                    if n ~= nil then
                        outNum[k] = n
                    end
                end
            end
        end
    end

    return outBool, outNum
end

local function currentExecutorName()
    local ok, name = pcall(function()
        if identifyexecutor then
            return identifyexecutor()
        end
        if getexecutorname then
            return getexecutorname()
        end
        return ""
    end)
    if ok and name then
        return tostring(name)
    end
    return ""
end

local function pointInsideAnyButton(container, x, y)
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("ImageButton") then
            local pos = child.AbsolutePosition
            local size = child.AbsoluteSize
            if x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y then
                return true
            end
        end
    end
    return false
end

compactBlockToJSON = function(b)

    local parts = {}
    parts[#parts+1] = '{"ShowShadow":'
    parts[#parts+1] = b.ShowShadow and "true" or "false"
    parts[#parts+1] = ',"CanCollide":'
    parts[#parts+1] = b.CanCollide and "true" or "false"
    parts[#parts+1] = ',"Color":"'
    parts[#parts+1] = tostring(b.Color or "1,1,1")
    parts[#parts+1] = '","Anchored":'
    parts[#parts+1] = b.Anchored and "true" or "false"
    parts[#parts+1] = ',"BoolValues":{}'
    parts[#parts+1] = ',"Rotation":"'
    parts[#parts+1] = tostring(b.Rotation or "0,0,0")
    parts[#parts+1] = '","Transparency":'
    parts[#parts+1] = tostring(b.Transparency or 0)
    parts[#parts+1] = ',"Position":"'
    parts[#parts+1] = tostring(b.Position or "0,0,0")
    parts[#parts+1] = '","ID":'
    parts[#parts+1] = tostring(b.ID or 0)
    parts[#parts+1] = ',"NumberValues":{}'
    parts[#parts+1] = ',"Size":"'
    parts[#parts+1] = tostring(b.Size or "1,1,1")
    parts[#parts+1] = '"}'
    return table.concat(parts)
end

writeBuildJSON = function(outPath, materialName, cleanBlocks)

    local parts = {}
    parts[#parts+1] = '[["'
    parts[#parts+1] = materialName
    parts[#parts+1] = '"],{"'
    parts[#parts+1] = materialName
    parts[#parts+1] = '":['
    for i, block in ipairs(cleanBlocks) do
        if i > 1 then parts[#parts+1] = ',' end
        parts[#parts+1] = compactBlockToJSON(block)
    end
    parts[#parts+1] = ']}]'
    writefile(outPath, table.concat(parts))
end

local function writeConvertedBuild(buildName, material, blocks)
    local safeName = trimStr(buildName)
    if safeName == "" then
        return nil, "Output name is empty"
    end
    if type(blocks) ~= "table" or #blocks == 0 then
        return nil, "Nothing to convert"
    end
    local cleanBlocks = {}
    local seen = {}
    for _, block in ipairs(blocks) do
        if type(block) == "table" then
            local key = table.concat({
                tostring(block.Position or ""),
                tostring(block.Rotation or ""),
                tostring(block.Size or ""),
                tostring(block.Color or ""),
                tostring(block.Transparency or 0),
                tostring(block.Material or material or ""),
            }, "|")
            if not seen[key] then
                seen[key] = true
                cleanBlocks[#cleanBlocks + 1] = block
            end
        end
    end
    if #cleanBlocks == 0 then
        return nil, "Nothing to convert"
    end
    ensureFolder()
    local outPath = FOLDER_PREFIX .. safeName .. ".Build"
    local materialName = tostring(material or "PlasticBlock")
    if materialName == "Auto" then
        local materials = {}
        local groups = {}
        for _, block in ipairs(cleanBlocks) do
            local blockMaterial = tostring(block.Material or "PlasticBlock")
            if not groups[blockMaterial] then
                groups[blockMaterial] = {}
                materials[#materials + 1] = blockMaterial
            end
            block.Material = nil
            groups[blockMaterial][#groups[blockMaterial] + 1] = block
        end
        table.sort(materials, function(a, b) return a:lower() < b:lower() end)

        local mParts = {}
        mParts[#mParts+1] = '['

        mParts[#mParts+1] = '['
        for mi, m in ipairs(materials) do
            if mi > 1 then mParts[#mParts+1] = ',' end
            mParts[#mParts+1] = '"' .. m .. '"'
        end
        mParts[#mParts+1] = '],'

        mParts[#mParts+1] = '{'
        for gi, m in ipairs(materials) do
            if gi > 1 then mParts[#mParts+1] = ',' end
            mParts[#mParts+1] = '"' .. m .. '":['
            local gBlocks = groups[m]
            for bi, block in ipairs(gBlocks) do
                if bi > 1 then mParts[#mParts+1] = ',' end
                mParts[#mParts+1] = compactBlockToJSON(block)
            end
            mParts[#mParts+1] = ']'
        end
        mParts[#mParts+1] = '}]'
        writefile(outPath, table.concat(mParts))
    else
        for _, block in ipairs(cleanBlocks) do block.Material = nil end
        writeBuildJSON(outPath, materialName, cleanBlocks)
    end
    return outPath, nil
end

local convertMinecraftSchematicToBlocks
local convertMinecraftSchematicToBuild
local convertObjToBlocks
local convertObjToBuild
do
local function bytesToString(bytes)
    local chunks = {}
    for i = 1, #bytes, 4096 do
        local chars = {}
        for j = i, math.min(i + 4095, #bytes) do
            chars[#chars + 1] = string.char(bytes[j])
        end
        chunks[#chunks + 1] = table.concat(chars)
    end
    return table.concat(chunks)
end

local function gzNoEof(value)
    if value == nil then
        error("Unexpected end of gzip stream", 0)
    end
    return value
end

local function gzHasBit(bits, mask)
    return bits % (mask + mask) >= mask
end

local function gzMakeOutputState(writer)
    return {
        outbs = writer,
        window = {},
        windowPos = 1,
    }
end

local function gzOutput(outState, byte)
    outState.outbs(byte)
    outState.window[outState.windowPos] = byte
    outState.windowPos = outState.windowPos % 32768 + 1
end

local function gzBitstreamFromString(data)
    local index = 1
    local bufByte = 0
    local bufBits = 0
    local stream = {}

    function stream:nbitsLeftInByte()
        return bufBits
    end

    function stream:read(nbits)
        nbits = nbits or 1
        while bufBits < nbits do
            if index > #data then
                return nil
            end
            local byte = string.byte(data, index)
            index = index + 1
            bufByte = bufByte + bit.lshift(byte, bufBits)
            bufBits = bufBits + 8
        end
        local bitsOut
        if nbits == 0 then
            bitsOut = 0
        elseif nbits == 32 then
            bitsOut = bufByte
            bufByte = 0
        else
            bitsOut = bit.band(bufByte, bit.rshift(0xffffffff, 32 - nbits))
            bufByte = bit.rshift(bufByte, nbits)
        end
        bufBits = bufBits - nbits
        return bitsOut
    end

    return stream
end

local function gzHuffmanTable(init, isFull)
    local entries = {}
    if isFull then
        for value, nbits in pairs(init) do
            if nbits and nbits ~= 0 then
                entries[#entries + 1] = {value = value, nbits = nbits}
            end
        end
    else
        for i = 1, #init - 2, 2 do
            local firstVal, nbits, nextVal = init[i], init[i + 1], init[i + 2]
            if nbits and nbits ~= 0 then
                for value = firstVal, nextVal - 1 do
                    entries[#entries + 1] = {value = value, nbits = nbits}
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        return a.nbits == b.nbits and a.value < b.value or a.nbits < b.nbits
    end)

    local code = 1
    local currentBits = 0
    for _, entry in ipairs(entries) do
        if entry.nbits ~= currentBits then
            code = code * 2^(entry.nbits - currentBits)
            currentBits = entry.nbits
        end
        entry.code = code
        code = code + 1
    end

    local minBits = math.huge
    local lookup = {}
    for _, entry in ipairs(entries) do
        minBits = math.min(minBits, entry.nbits)
        lookup[entry.code] = entry.value
    end
    if minBits == math.huge then
        error("Invalid Huffman table", 0)
    end

    local firstCodeCache = {}
    local function msb(bitsValue, nbits)
        local result = 0
        for _ = 1, nbits do
            result = bit.lshift(result, 1) + bit.band(bitsValue, 1)
            bitsValue = bit.rshift(bitsValue, 1)
        end
        return result
    end

    local function firstCode(bitsValue)
        local cached = firstCodeCache[bitsValue]
        if cached == nil then
            cached = 2^minBits + msb(bitsValue, minBits)
            firstCodeCache[bitsValue] = cached
        end
        return cached
    end

    local tableObj = {}
    function tableObj:read(stream)
        local curCode = 1
        local nbits = 0
        while true do
            if nbits == 0 then
                curCode = firstCode(gzNoEof(stream:read(minBits)))
                nbits = minBits
            else
                local nextBit = gzNoEof(stream:read(1))
                nbits = nbits + 1
                curCode = curCode * 2 + nextBit
            end
            local value = lookup[curCode]
            if value ~= nil then
                return value
            end
        end
    end

    return tableObj
end

local function gzParseHeader(stream)
    local FLG_FHCRC = 2^1
    local FLG_FEXTRA = 2^2
    local FLG_FNAME = 2^3
    local FLG_FCOMMENT = 2^4

    local id1 = stream:read(8)
    local id2 = stream:read(8)
    if id1 ~= 31 or id2 ~= 139 then
        error("Not a gzip stream", 0)
    end
    local method = gzNoEof(stream:read(8))
    local flags = gzNoEof(stream:read(8))
    gzNoEof(stream:read(32))
    gzNoEof(stream:read(8))
    gzNoEof(stream:read(8))

    if method ~= 8 then
        error("Unsupported gzip method", 0)
    end

    if gzHasBit(flags, FLG_FEXTRA) then
        local xlen = gzNoEof(stream:read(16))
        for _ = 1, xlen do
            gzNoEof(stream:read(8))
        end
    end

    local function skipZString()
        repeat
            local byte = gzNoEof(stream:read(8))
        until byte == 0
    end

    if gzHasBit(flags, FLG_FNAME) then
        skipZString()
    end
    if gzHasBit(flags, FLG_FCOMMENT) then
        skipZString()
    end
    if gzHasBit(flags, FLG_FHCRC) then
        gzNoEof(stream:read(16))
    end
end

local function gzParseHuffmanTables(stream)
    local hlit = stream:read(5)
    local hdist = stream:read(5)
    local hclen = gzNoEof(stream:read(4))

    local codeLenInit = {}
    local codeLenOrder = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}
    for i = 1, hclen + 4 do
        codeLenInit[codeLenOrder[i]] = stream:read(3)
    end
    local codeLenTable = gzHuffmanTable(codeLenInit, true)

    local function decode(count)
        local init = {}
        local nbits = 0
        local value = 0
        while value < count do
            local codeLen = codeLenTable:read(stream)
            local repeatCount
            if codeLen <= 15 then
                repeatCount = 1
                nbits = codeLen
            elseif codeLen == 16 then
                repeatCount = 3 + gzNoEof(stream:read(2))
            elseif codeLen == 17 then
                repeatCount = 3 + gzNoEof(stream:read(3))
                nbits = 0
            elseif codeLen == 18 then
                repeatCount = 11 + gzNoEof(stream:read(7))
                nbits = 0
            else
                error("Broken dynamic Huffman table", 0)
            end
            for _ = 1, repeatCount do
                init[value] = nbits
                value = value + 1
            end
        end
        return gzHuffmanTable(init, true)
    end

    return decode(hlit + 257), decode(hdist + 1)
end

local gzLenBase, gzLenExtra, gzDistBase, gzDistExtra
local function gzParseCompressedItem(stream, outState, litTable, distTable)
    local value = litTable:read(stream)
    if value < 256 then
        gzOutput(outState, value)
        return false
    end
    if value == 256 then
        return true
    end

    if not gzLenBase then
        gzLenBase = {[257] = 3}
        local step = 1
        for i = 258, 285, 4 do
            for j = i, i + 3 do
                gzLenBase[j] = gzLenBase[j - 1] + step
            end
            if i ~= 258 then
                step = step * 2
            end
        end
        gzLenBase[285] = 258
    end
    if not gzLenExtra then
        gzLenExtra = {}
        for i = 257, 285 do
            local delta = math.max(i - 261, 0)
            gzLenExtra[i] = bit.rshift(delta, 2)
        end
        gzLenExtra[285] = 0
    end

    local runLength = gzLenBase[value] + (stream:read(gzLenExtra[value]) or 0)

    if not gzDistBase then
        gzDistBase = {[0] = 1}
        local step = 1
        for i = 1, 29, 2 do
            for j = i, i + 1 do
                gzDistBase[j] = gzDistBase[j - 1] + step
            end
            if i ~= 1 then
                step = step * 2
            end
        end
    end
    if not gzDistExtra then
        gzDistExtra = {}
        for i = 0, 29 do
            local delta = math.max(i - 2, 0)
            gzDistExtra[i] = bit.rshift(delta, 1)
        end
    end

    local distValue = distTable:read(stream)
    local distance = gzDistBase[distValue] + (stream:read(gzDistExtra[distValue]) or 0)
    for _ = 1, runLength do
        local pos = (outState.windowPos - 1 - distance) % 32768 + 1
        local prev = outState.window[pos]
        if prev == nil then
            error("Invalid distance in gzip stream", 0)
        end
        gzOutput(outState, prev)
    end
    return false
end

local function gzParseBlock(stream, outState)
    local isFinal = stream:read(1)
    local blockType = stream:read(2)
    if isFinal == nil or blockType == nil then
        error("Unexpected end of deflate stream", 0)
    end

    if blockType == 0 then
        stream:read(stream:nbitsLeftInByte())
        local length = gzNoEof(stream:read(16))
        local nlen = gzNoEof(stream:read(16))
        if bit.band(bit.bnot(length), 0xFFFF) ~= nlen then
            error("Stored block length mismatch", 0)
        end
        for _ = 1, length do
            gzOutput(outState, gzNoEof(stream:read(8)))
        end
    elseif blockType == 1 or blockType == 2 then
        local litTable, distTable
        if blockType == 2 then
            litTable, distTable = gzParseHuffmanTables(stream)
        else
            litTable = gzHuffmanTable({0, 8, 144, 9, 256, 7, 280, 8, 288, nil}, false)
            distTable = gzHuffmanTable({0, 5, 32, nil}, false)
        end
        repeat
        until gzParseCompressedItem(stream, outState, litTable, distTable)
    else
        error("Unsupported deflate block type", 0)
    end

    return isFinal ~= 0
end

local function gunzipString(data)
    if type(data) ~= "string" or #data < 18 then
        return nil, "Gzip file is too small"
    end
    if string.byte(data, 1) ~= 0x1F or string.byte(data, 2) ~= 0x8B then
        return nil, "Not a gzip stream"
    end
    local outputBytes = {}
    local ok, err = pcall(function()
        local stream = gzBitstreamFromString(data)
        gzParseHeader(stream)
        local outState = gzMakeOutputState(function(byte)
            outputBytes[#outputBytes + 1] = byte
        end)
        repeat
        until gzParseBlock(stream, outState)
    end)
    if not ok then
        return nil, tostring(err)
    end
    return bytesToString(outputBytes), nil
end

local function decodeMaybeGzip(data)
    if type(data) ~= "string" then
        return nil, "Expected binary string"
    end
    if #data >= 2 and string.byte(data, 1) == 0x1F and string.byte(data, 2) == 0x8B then
        return gunzipString(data)
    end
    return data, nil
end

local function makeNbtReader(data)
    local r = {data = data, pos = 1}

    function r:u8()
        local b = string.byte(self.data, self.pos)
        self.pos = self.pos + 1
        return b or 0
    end

    function r:s8()
        local v = self:u8()
        return v >= 128 and (v - 256) or v
    end

    function r:u16()
        local b1 = self:u8()
        local b2 = self:u8()
        return b1 * 256 + b2
    end

    function r:s16()
        local v = self:u16()
        return v >= 32768 and (v - 65536) or v
    end

    function r:u32()
        local b1 = self:u8()
        local b2 = self:u8()
        local b3 = self:u8()
        local b4 = self:u8()
        return (((b1 * 256) + b2) * 256 + b3) * 256 + b4
    end

    function r:s32()
        local v = self:u32()
        return v >= 2147483648 and (v - 4294967296) or v
    end

    function r:float32()
        local v = self:u32()
        if v == 0 then return 0 end
        local sign = bit.band(v, 0x80000000) ~= 0 and -1 or 1
        local exp = bit.band(bit.rshift(v, 23), 0xFF)
        local mant = bit.band(v, 0x7FFFFF)
        if exp == 0 then
            return sign * (mant / 8388608) * 2^-126
        end
        if exp == 255 then
            return sign * math.huge
        end
        return sign * (1 + mant / 8388608) * 2^(exp - 127)
    end

    function r:float64()
        local hi = self:u32()
        local lo = self:u32()
        local sign = bit.band(hi, 0x80000000) ~= 0 and -1 or 1
        local exp = bit.band(bit.rshift(hi, 20), 0x7FF)
        local mantHi = bit.band(hi, 0xFFFFF)
        local mant = mantHi * 4294967296 + lo
        if exp == 0 then
            return sign * (mant / 4503599627370496) * 2^-1022
        end
        if exp == 2047 then
            return sign * math.huge
        end
        return sign * (1 + mant / 4503599627370496) * 2^(exp - 1023)
    end

    function r:str()
        local len = self:u16()
        local s = self.data:sub(self.pos, self.pos + len - 1)
        self.pos = self.pos + len
        return s
    end

    return r
end

local function parseNbtPayload(reader, tagType)
    if tagType == 1 then
        return reader:s8()
    elseif tagType == 2 then
        return reader:s16()
    elseif tagType == 3 then
        return reader:s32()
    elseif tagType == 4 then
        local hi = reader:u32()
        local lo = reader:u32()
        return {hi = hi, lo = lo}
    elseif tagType == 5 then
        return reader:float32()
    elseif tagType == 6 then
        return reader:float64()
    elseif tagType == 7 then
        local len = reader:s32()
        local arr = {}
        for i = 1, len do
            arr[i] = reader:u8()
        end
        return arr
    elseif tagType == 8 then
        return reader:str()
    elseif tagType == 9 then
        local childType = reader:u8()
        local len = reader:s32()
        local arr = {}
        for i = 1, len do
            arr[i] = parseNbtPayload(reader, childType)
        end
        return arr
    elseif tagType == 10 then
        local out = {}
        while true do
            local childType = reader:u8()
            if childType == 0 then
                break
            end
            local name = reader:str()
            out[name] = parseNbtPayload(reader, childType)
        end
        return out
    elseif tagType == 11 then
        local len = reader:s32()
        local arr = {}
        for i = 1, len do
            arr[i] = reader:s32()
        end
        return arr
    elseif tagType == 12 then
        local len = reader:s32()
        local arr = {}
        for i = 1, len do
            arr[i] = {hi = reader:u32(), lo = reader:u32()}
        end
        return arr
    end
    return nil
end

local function parseNbt(data)
    local reader = makeNbtReader(data)
    local rootType = reader:u8()
    if rootType ~= 10 then
        return nil, "NBT root is not a compound"
    end
    local _ = reader:str()
    return parseNbtPayload(reader, 10), nil
end

local MC_DYE_COLORS = {
    white = rgbStr(249, 255, 254),
    orange = rgbStr(249, 128, 29),
    magenta = rgbStr(199, 78, 189),
    light_blue = rgbStr(58, 179, 218),
    yellow = rgbStr(254, 216, 61),
    lime = rgbStr(128, 199, 31),
    pink = rgbStr(243, 139, 170),
    gray = rgbStr(71, 79, 82),
    light_gray = rgbStr(157, 157, 151),
    cyan = rgbStr(22, 156, 156),
    purple = rgbStr(137, 50, 184),
    blue = rgbStr(60, 68, 170),
    brown = rgbStr(131, 84, 50),
    green = rgbStr(94, 124, 22),
    red = rgbStr(176, 46, 38),
    black = rgbStr(29, 29, 33),
}

local DYE_ORDER = {
    "light_blue", "light_gray", "magenta", "orange", "yellow", "purple", "brown",
    "white", "black", "gray", "lime", "cyan", "blue", "green", "pink", "red"
}

local function mcBlockStateToColor(blockState)
    local state = tostring(blockState or ""):lower()
    local base = state:match("^[^%[]+") or state
    if base == "" then return rgbStr(190, 190, 190) end
    if base == "minecraft:air" or base:find("cave_air", 1, true) or base:find("void_air", 1, true) then
        return nil
    end
    for _, dye in ipairs(DYE_ORDER) do
        if base:find(dye, 1, true) then
            return MC_DYE_COLORS[dye]
        end
    end
    if base:find("water", 1, true) or base:find("ice", 1, true) then return rgbStr(64, 120, 255) end
    if base:find("lava", 1, true) or base:find("magma", 1, true) then return rgbStr(255, 111, 0) end
    if base:find("grass", 1, true) or base:find("fern", 1, true) or base:find("leaf", 1, true) or base:find("vine", 1, true)
        or base:find("moss", 1, true) or base:find("bush", 1, true) or base:find("crop", 1, true)
        or base:find("beetroot", 1, true) or base:find("bamboo", 1, true) then
        return rgbStr(88, 148, 74)
    end
    if base:find("sand", 1, true) or base:find("end_stone", 1, true) then return rgbStr(219, 211, 160) end
    if base:find("dirt", 1, true) or base:find("mud", 1, true) or base:find("farmland", 1, true) or base:find("root", 1, true) then
        return rgbStr(134, 96, 67)
    end
    if base:find("log", 1, true) or base:find("plank", 1, true) or base:find("wood", 1, true) or base:find("slab", 1, true)
        or base:find("fence", 1, true) or base:find("trapdoor", 1, true) or base:find("ladder", 1, true)
        or base:find("campfire", 1, true) or base:find("barrel", 1, true) then
        return rgbStr(151, 109, 77)
    end
    if base:find("brick", 1, true) or base:find("nether", 1, true) or base:find("terracotta", 1, true) then
        return rgbStr(153, 84, 72)
    end
    if base:find("glass", 1, true) then return rgbStr(190, 220, 235) end
    if base:find("gold", 1, true) then return rgbStr(249, 236, 78) end
    if base:find("diamond", 1, true) or base:find("prismarine", 1, true) then return rgbStr(92, 219, 213) end
    if base:find("emerald", 1, true) then return rgbStr(72, 186, 88) end
    if base:find("copper", 1, true) then return rgbStr(193, 108, 74) end
    if base:find("quartz", 1, true) or base:find("snow", 1, true) then return rgbStr(238, 238, 238) end
    if base:find("obsidian", 1, true) or base:find("deepslate", 1, true) or base:find("blackstone", 1, true) then
        return rgbStr(55, 52, 66)
    end
    if base:find("stone", 1, true) or base:find("cobble", 1, true) or base:find("andesite", 1, true)
        or base:find("diorite", 1, true) or base:find("granite", 1, true) or base:find("ore", 1, true)
        or base:find("iron", 1, true) then
        return rgbStr(137, 137, 137)
    end
    return rgbStr(185, 185, 185)
end

local LEGACY_WOOL_BY_DATA = {
    [0] = "minecraft:white_wool", [1] = "minecraft:orange_wool", [2] = "minecraft:magenta_wool", [3] = "minecraft:light_blue_wool",
    [4] = "minecraft:yellow_wool", [5] = "minecraft:lime_wool", [6] = "minecraft:pink_wool", [7] = "minecraft:gray_wool",
    [8] = "minecraft:light_gray_wool", [9] = "minecraft:cyan_wool", [10] = "minecraft:purple_wool", [11] = "minecraft:blue_wool",
    [12] = "minecraft:brown_wool", [13] = "minecraft:green_wool", [14] = "minecraft:red_wool", [15] = "minecraft:black_wool",
}

local LEGACY_GLASS_BY_DATA = {
    [0] = "minecraft:white_stained_glass", [1] = "minecraft:orange_stained_glass", [2] = "minecraft:magenta_stained_glass", [3] = "minecraft:light_blue_stained_glass",
    [4] = "minecraft:yellow_stained_glass", [5] = "minecraft:lime_stained_glass", [6] = "minecraft:pink_stained_glass", [7] = "minecraft:gray_stained_glass",
    [8] = "minecraft:light_gray_stained_glass", [9] = "minecraft:cyan_stained_glass", [10] = "minecraft:purple_stained_glass", [11] = "minecraft:blue_stained_glass",
    [12] = "minecraft:brown_stained_glass", [13] = "minecraft:green_stained_glass", [14] = "minecraft:red_stained_glass", [15] = "minecraft:black_stained_glass",
}

local LEGACY_CONCRETE_BY_DATA = {
    [0] = "minecraft:white_concrete", [1] = "minecraft:orange_concrete", [2] = "minecraft:magenta_concrete", [3] = "minecraft:light_blue_concrete",
    [4] = "minecraft:yellow_concrete", [5] = "minecraft:lime_concrete", [6] = "minecraft:pink_concrete", [7] = "minecraft:gray_concrete",
    [8] = "minecraft:light_gray_concrete", [9] = "minecraft:cyan_concrete", [10] = "minecraft:purple_concrete", [11] = "minecraft:blue_concrete",
    [12] = "minecraft:brown_concrete", [13] = "minecraft:green_concrete", [14] = "minecraft:red_concrete", [15] = "minecraft:black_concrete",
}

local function legacyIdToState(blockId, dataValue)
    local dv = tonumber(dataValue) or 0
    local simple = {
        [0] = "minecraft:air",
        [1] = "minecraft:stone",
        [2] = "minecraft:grass_block",
        [3] = "minecraft:dirt",
        [4] = "minecraft:cobblestone",
        [12] = "minecraft:sand",
        [13] = "minecraft:gravel",
        [17] = "minecraft:oak_log",
        [18] = "minecraft:oak_leaves",
        [20] = "minecraft:glass",
        [24] = "minecraft:sandstone",
        [41] = "minecraft:gold_block",
        [42] = "minecraft:iron_block",
        [45] = "minecraft:bricks",
        [48] = "minecraft:mossy_cobblestone",
        [49] = "minecraft:obsidian",
        [57] = "minecraft:diamond_block",
        [79] = "minecraft:ice",
        [80] = "minecraft:snow_block",
        [82] = "minecraft:clay",
        [87] = "minecraft:netherrack",
        [89] = "minecraft:glowstone",
        [98] = "minecraft:stone_bricks",
        [112] = "minecraft:nether_bricks",
        [121] = "minecraft:end_stone",
        [133] = "minecraft:emerald_block",
        [155] = "minecraft:quartz_block",
        [159] = "minecraft:orange_terracotta",
        [168] = "minecraft:prismarine",
        [172] = "minecraft:terracotta",
        [173] = "minecraft:coal_block",
        [174] = "minecraft:packed_ice",
        [179] = "minecraft:red_sandstone",
    }
    if blockId == 5 then
        local kinds = {"oak_planks", "spruce_planks", "birch_planks", "jungle_planks", "acacia_planks", "dark_oak_planks"}
        return "minecraft:" .. (kinds[(dv % #kinds) + 1] or "oak_planks")
    end
    if blockId == 35 then return LEGACY_WOOL_BY_DATA[dv] or "minecraft:white_wool" end
    if blockId == 95 or blockId == 160 then return LEGACY_GLASS_BY_DATA[dv] or "minecraft:white_stained_glass" end
    if blockId == 251 or blockId == 252 then return LEGACY_CONCRETE_BY_DATA[dv] or "minecraft:white_concrete" end
    return simple[blockId] or "minecraft:stone"
end

local function greedyMergeVoxels(voxels)
    if #voxels == 0 then return {} end
    table.sort(voxels, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.z ~= b.z then return a.z < b.z end
        return a.x < b.x
    end)

    local cellMap = {}
    local used = {}
    for _, v in ipairs(voxels) do
        cellMap[v.x .. "," .. v.y .. "," .. v.z] = v
    end

    local function sameColor(x, y, z, color)
        local key = x .. "," .. y .. "," .. z
        local v = cellMap[key]
        return v and not used[key] and v.color == color
    end

    local boxes = {}
    for _, v in ipairs(voxels) do
        local key = v.x .. "," .. v.y .. "," .. v.z
        if not used[key] then
            local color = v.color
            local x2, y2, z2 = v.x, v.y, v.z
            while sameColor(x2 + 1, v.y, v.z, color) do
                x2 = x2 + 1
            end
            local canGrowY = true
            while canGrowY do
                for x = v.x, x2 do
                    if not sameColor(x, y2 + 1, v.z, color) then
                        canGrowY = false
                        break
                    end
                end
                if canGrowY then
                    y2 = y2 + 1
                end
            end
            local canGrowZ = true
            while canGrowZ do
                for y = v.y, y2 do
                    for x = v.x, x2 do
                        if not sameColor(x, y, z2 + 1, color) then
                            canGrowZ = false
                            break
                        end
                    end
                    if not canGrowZ then break end
                end
                if canGrowZ then
                    z2 = z2 + 1
                end
            end
            for z = v.z, z2 do
                for y = v.y, y2 do
                    for x = v.x, x2 do
                        used[x .. "," .. y .. "," .. z] = true
                    end
                end
            end
            boxes[#boxes + 1] = {x1 = v.x, y1 = v.y, z1 = v.z, x2 = x2, y2 = y2, z2 = z2, color = color}
        end
    end
    return boxes
end

local function decodePaletteVarInts(bytes, expectedCount)
    local values = {}
    local value = 0
    local shift = 0
    for _, b in ipairs(bytes or {}) do
        value = value + bit.lshift(bit.band(b, 0x7F), shift)
        if bit.band(b, 0x80) == 0 then
            values[#values + 1] = value
            value = 0
            shift = 0
            if expectedCount and #values >= expectedCount then
                break
            end
        else
            shift = shift + 7
        end
    end
    return values
end

local function buildSchemVoxels(root)
    local width = tonumber(root.Width) or 0
    local height = tonumber(root.Height) or 0
    local length = tonumber(root.Length) or 0
    local palette = root.Palette
    local rawData = root.BlockData or root.Blocks
    if width <= 0 or height <= 0 or length <= 0 then
        return nil, "Bad schematic size"
    end
    if type(palette) ~= "table" or type(rawData) ~= "table" then
        return nil, "Palette or block data missing"
    end
    local reversePalette = {}
    for state, id in pairs(palette) do
        reversePalette[tonumber(id) or 0] = state
    end
    local total = width * height * length
    local ids = decodePaletteVarInts(rawData, total)
    if #ids < total then
        return nil, "Schematic block data is truncated"
    end
    local voxels = {}
    local idx = 1
    for y = 0, height - 1 do
        for z = 0, length - 1 do
            for x = 0, width - 1 do
                local state = reversePalette[ids[idx] or 0] or "minecraft:air"
                idx = idx + 1
                local color = mcBlockStateToColor(state)
                if color then
                    voxels[#voxels + 1] = {x = x, y = y, z = z, color = color}
                end
            end
        end
    end
    return {width = width, height = height, length = length, voxels = voxels}
end

local function buildLegacySchematicVoxels(root)
    local width = tonumber(root.Width) or 0
    local height = tonumber(root.Height) or 0
    local length = tonumber(root.Length) or 0
    local blocks = root.Blocks
    local data = root.Data
    local addBlocks = root.AddBlocks
    if width <= 0 or height <= 0 or length <= 0 then
        return nil, "Bad legacy schematic size"
    end
    if type(blocks) ~= "table" or type(data) ~= "table" then
        return nil, "Legacy block arrays missing"
    end
    local total = width * height * length
    local voxels = {}
    for i = 0, total - 1 do
        local baseId = blocks[i + 1] or 0
        local blockId = baseId
        if type(addBlocks) == "table" then
            local packed = addBlocks[math.floor(i / 2) + 1] or 0
            local high = (i % 2 == 0) and bit.band(packed, 0x0F) or bit.rshift(packed, 4)
            blockId = baseId + high * 256
        end
        local dv = data[i + 1] or 0
        local state = legacyIdToState(blockId, dv)
        local color = mcBlockStateToColor(state)
        if color then
            local x = i % width
            local z = math.floor(i / width) % length
            local y = math.floor(i / (width * length))
            voxels[#voxels + 1] = {x = x, y = y, z = z, color = color}
        end
    end
    return {width = width, height = height, length = length, voxels = voxels}
end

convertMinecraftSchematicToBlocks = function(filePath, scale, material)
    local raw = readfile(filePath)
    local nbtRaw, zipErr = decodeMaybeGzip(raw)
    if not nbtRaw then
        return nil, nil, zipErr
    end
    local root, nbtErr = parseNbt(nbtRaw)
    if not root then
        return nil, nil, nbtErr
    end
    if type(root.Schematic) == "table" then
        root = root.Schematic
    end
    scale = tonumber(scale) or 1
    material = tostring(material or "PlasticBlock")
    if scale <= 0 then
        return nil, nil, "Scale must be > 0"
    end

    local data, err
    if type(root.Palette) == "table" then
        data, err = buildSchemVoxels(root)
    else
        data, err = buildLegacySchematicVoxels(root)
    end
    if not data then
        return nil, nil, err
    end

    local boxes = greedyMergeVoxels(data.voxels)
    local blocks = {}
    for i, box in ipairs(boxes) do
        local sizeVec = Vector3.new(
            (box.x2 - box.x1 + 1) * scale,
            (box.y2 - box.y1 + 1) * scale,
            (box.z2 - box.z1 + 1) * scale
        )
        local center = Vector3.new(
            ((box.x1 + box.x2 + 1) / 2 - data.width / 2) * scale,
            ((box.y1 + box.y2 + 1) / 2) * scale,
            ((box.z1 + box.z2 + 1) / 2 - data.length / 2) * scale
        )
        blocks[#blocks + 1] = cfToAsuBlock(CFrame.new(center), sizeVec, box.color, i, 0)
    end
    if #blocks == 0 then
        return nil, nil, "Schematic produced no blocks"
    end
    return material, blocks, nil
end

convertMinecraftSchematicToBuild = function(filePath, buildName, scale, material)
    local outMaterial, blocks, err = convertMinecraftSchematicToBlocks(filePath, scale, material)
    if not outMaterial then
        return nil, err
    end
    return writeConvertedBuild(buildName, outMaterial, blocks)
end

local function parseObjData(text, filePath)
    local materialColors = {}
    local vertices = {}
    local faces = {}
    for line in text:gmatch("[^\r\n]+") do
        local tag, rest = line:match("^%s*(%S+)%s*(.-)%s*$")
        if tag == "v" then
            local nums = parseNums(rest)
            if #nums >= 3 then
                local entry = {pos = Vector3.new(nums[1], nums[2], nums[3])}
                if #nums >= 6 then
                    entry.color = {nums[4], nums[5], nums[6]}
                end
                vertices[#vertices + 1] = entry
            end
        elseif tag == "f" then
            local face = {}
            for token in rest:gmatch("%S+") do
                local idxToken = token:match("([^/]+)")
                local idx = tonumber(idxToken)
                if idx then
                    if idx < 0 then
                        idx = #vertices + idx + 1
                    end
                    if vertices[idx] then
                        face[#face + 1] = idx
                    end
                end
            end
            if #face >= 3 then
                faces[#faces + 1] = {indices = face}
            end
        end
    end
    return {vertices = vertices, faces = faces, materialColors = materialColors}
end

local function chooseFaceColor(face, vertices, faceMaterial, materialColors)
    if faceMaterial and materialColors[faceMaterial] then
        return materialColors[faceMaterial]
    end
    local rs, gs, bs, count = 0, 0, 0, 0
    for _, idx in ipairs(face) do
        local v = vertices[idx]
        if v and v.color then
            rs = rs + v.color[1]
            gs = gs + v.color[2]
            bs = bs + v.color[3]
            count = count + 1
        end
    end
    if count > 0 then
        return rgbStr(rs / count, gs / count, bs / count)
    end
    return rgbStr(220, 220, 220)
end

local function centerPoints(points)
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, p in ipairs(points) do
        minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
        maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
    end
    local center = (minV + maxV) * 0.5
    local shifted = {}
    for i, p in ipairs(points) do
        shifted[i] = p - center
    end
    return shifted, center
end

local function makeFacePanel(points, scale, thickness, colorStr, blockId)
    if #points < 3 then
        return nil
    end
    local centered, baseCenter = centerPoints(points)
    local scaled = {}
    for i, p in ipairs(centered) do
        scaled[i] = Vector3.new(p.X * scale, p.Y * scale, p.Z * scale)
    end

    local normal = nil
    for i = 2, #scaled - 1 do
        local cross = (scaled[i] - scaled[1]):Cross(scaled[i + 1] - scaled[1])
        if cross.Magnitude > 1e-9 then
            normal = cross.Unit
            break
        end
    end
    if not normal then
        return nil
    end

    local longest = nil
    local bestDist = 0
    for i = 1, #scaled do
        for j = i + 1, #scaled do
            local d = (scaled[j] - scaled[i]).Magnitude
            if d > bestDist then
                bestDist = d
                longest = scaled[j] - scaled[i]
            end
        end
    end
    if not longest or longest.Magnitude < 1e-5 then
        return nil
    end

    local axisX = longest - normal * longest:Dot(normal)
    if axisX.Magnitude < 1e-5 then
        axisX = normal:Cross(Vector3.new(0, 1, 0))
        if axisX.Magnitude < 1e-5 then
            axisX = normal:Cross(Vector3.new(1, 0, 0))
        end
    end
    axisX = axisX.Unit
    local axisY = normal:Cross(axisX)
    if axisY.Magnitude < 1e-5 then
        return nil
    end
    axisY = axisY.Unit

    local minU, minV = math.huge, math.huge
    local maxU, maxV = -math.huge, -math.huge
    local center = Vector3.zero
    for _, p in ipairs(scaled) do
        center = center + p
    end
    center = center / #scaled
    for _, p in ipairs(scaled) do
        local rel = p - center
        local u = rel:Dot(axisX)
        local v = rel:Dot(axisY)
        minU = math.min(minU, u)
        maxU = math.max(maxU, u)
        minV = math.min(minV, v)
        maxV = math.max(maxV, v)
    end

    local width = math.max(0.02, maxU - minU)
    local height = math.max(0.02, maxV - minV)
    local faceCenter = (baseCenter * scale) + center + axisX * ((minU + maxU) * 0.5) + axisY * ((minV + maxV) * 0.5)
    local cf = CFrame.fromMatrix(faceCenter, axisX, axisY, normal)
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    rx = math.rad(snapAngle90(math.deg(rx)))
    ry = math.rad(snapAngle90(math.deg(ry)))
    rz = math.rad(snapAngle90(math.deg(rz)))
    cf = CFrame.new(faceCenter) * CFrame.Angles(rx, ry, rz)
    return cfToAsuBlock(cf, Vector3.new(width, height, thickness), colorStr, blockId, 0)
end

local function makeFacePanelCentered(points, thickness, colorStr, blockId)

    if #points < 3 then
        return nil
    end

    local normal = nil
    for i = 2, #points - 1 do
        local cross = (points[i] - points[1]):Cross(points[i + 1] - points[1])
        if cross.Magnitude > 1e-9 then
            normal = cross.Unit
            break
        end
    end
    if not normal then
        return nil
    end

    local longest = nil
    local bestDist = 0
    for i = 1, #points do
        for j = i + 1, #points do
            local d = (points[j] - points[i]).Magnitude
            if d > bestDist then
                bestDist = d
                longest = points[j] - points[i]
            end
        end
    end
    if not longest or longest.Magnitude < 1e-5 then
        return nil
    end

    local axisX = longest - normal * longest:Dot(normal)
    if axisX.Magnitude < 1e-5 then
        axisX = normal:Cross(Vector3.new(0, 1, 0))
        if axisX.Magnitude < 1e-5 then
            axisX = normal:Cross(Vector3.new(1, 0, 0))
        end
    end
    axisX = axisX.Unit
    local axisY = normal:Cross(axisX)
    if axisY.Magnitude < 1e-5 then
        return nil
    end
    axisY = axisY.Unit

    local minU, minV = math.huge, math.huge
    local maxU, maxV = -math.huge, -math.huge
    local centroid = Vector3.zero
    for _, p in ipairs(points) do
        centroid = centroid + p
    end
    centroid = centroid / #points
    for _, p in ipairs(points) do
        local rel = p - centroid
        local u = rel:Dot(axisX)
        local v = rel:Dot(axisY)
        minU = math.min(minU, u)
        maxU = math.max(maxU, u)
        minV = math.min(minV, v)
        maxV = math.max(maxV, v)
    end

    local width = math.max(0.02, maxU - minU)
    local height = math.max(0.02, maxV - minV)
    local faceCenter = centroid + axisX * ((minU + maxU) * 0.5) + axisY * ((minV + maxV) * 0.5)
    local cf = CFrame.fromMatrix(faceCenter, axisX, axisY, normal)
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    rx = math.rad(snapAngle90(math.deg(rx)))
    ry = math.rad(snapAngle90(math.deg(ry)))
    rz = math.rad(snapAngle90(math.deg(rz)))
    cf = CFrame.new(faceCenter) * CFrame.Angles(rx, ry, rz)
    return cfToAsuBlock(cf, Vector3.new(width, height, thickness), colorStr, blockId, 0)
end

local function makeEdgeBlock(p0, p1, scale, thickness, colorStr, blockId)
    local center = (p0 + p1) * 0.5 * scale
    local delta = (p1 - p0) * scale
    if delta.Magnitude < 1e-5 then
        return nil
    end
    local axisX = delta.Unit
    local up = math.abs(axisX:Dot(Vector3.new(0, 1, 0))) > 0.98 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
    local axisZ = axisX:Cross(up)
    if axisZ.Magnitude < 1e-5 then
        axisZ = axisX:Cross(Vector3.new(0, 0, 1))
    end
    axisZ = axisZ.Unit
    local axisY = axisZ:Cross(axisX).Unit
    local cf = CFrame.fromMatrix(center, axisX, axisY, axisZ)
    return cfToAsuBlock(cf, Vector3.new(delta.Magnitude, thickness, thickness), colorStr, blockId, 0)
end

local function snapAngle90(deg)
    return math.floor(deg / 90 + 0.5) * 90
end

local function makeEdgeBlockFromRef(pA, pB, thickness, color, blockId, faceNormal)
    local delta = pB - pA
    local dist = delta.Magnitude
    if dist < 0.01 then return nil end
    local dir = delta.Unit

    local maxEdgeLen = 50
    if dist > maxEdgeLen then dist = maxEdgeLen end

    local shrink = math.min(dist * 0.06, thickness * 0.5)
    local effectiveDist = dist - shrink
    if effectiveDist < 0.01 then effectiveDist = dist end
    local shrinkHalf = (dist - effectiveDist) / 2
    local eA = pA + dir * shrinkHalf
    local eB = pB - dir * shrinkHalf
    local mid = (eA + eB) / 2

    local maxPos = 300
    mid = Vector3.new(
        math.clamp(mid.X, -maxPos, maxPos),
        math.clamp(mid.Y, -maxPos, maxPos),
        math.clamp(mid.Z, -maxPos, maxPos)
    )

    local absDir = Vector3.new(math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z))
    local isDiagonal = not (absDir.X > 0.95 or absDir.Y > 0.95 or absDir.Z > 0.95)

    local upHint
    if faceNormal and faceNormal.Magnitude > 0.0001 then
        local projN = faceNormal - dir * faceNormal:Dot(dir)
        if projN.Magnitude > 0.0001 then
            upHint = projN.Unit
        else
            upHint = Vector3.new(0, 1, 0)
        end
    else
        local absX, absY, absZ = math.abs(dir.X), math.abs(dir.Y), math.abs(dir.Z)
        if absY <= absX and absY <= absZ then
            upHint = Vector3.new(0, 1, 0)
        elseif absX <= absY and absX <= absZ then
            upHint = Vector3.new(1, 0, 0)
        else
            upHint = Vector3.new(0, 0, 1)
        end
    end
    local right = dir:Cross(upHint)
    if right.Magnitude < 0.0001 then
        local alternatives = {Vector3.new(0, 1, 0), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)}
        for _, alt in ipairs(alternatives) do
            right = dir:Cross(alt)
            if right.Magnitude > 0.0001 then
                upHint = alt
                break
            end
        end
        if right.Magnitude < 0.0001 then return nil end
    end
    right = right.Unit
    local upFixed = right:Cross(dir).Unit

    local cf = CFrame.fromMatrix(mid, right, upFixed, dir)

    if not isDiagonal then
        local rx, ry, rz = cf:ToEulerAnglesXYZ()
        rx = math.rad(snapAngle90(math.deg(rx)))
        ry = math.rad(snapAngle90(math.deg(ry)))
        rz = math.rad(snapAngle90(math.deg(rz)))
        cf = CFrame.new(mid) * CFrame.Angles(rx, ry, rz)
    end

    local effThick = math.clamp(thickness, 0.05, 4)
    local effLen = math.clamp(effectiveDist, 0.01, maxEdgeLen)

    local colorStr = nil
    if type(color) == "string" and color ~= "" then
        colorStr = color
    elseif typeof(color) == "Color3" then
        colorStr = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B)
    end
    return cfToAsuBlock(cf, Vector3.new(effThick, effThick, effLen), colorStr, blockId, 0)
end

local function createTriangleStrips(p1, p2, p3, stripSize, color, detailMul, blockIdStart)
    local parts = {}
    local v1 = p2 - p1
    local normal = v1:Cross(p3 - p1)
    if normal.Magnitude < 0.0001 then return parts end
    normal = normal.Unit

    local e1Len = (p2 - p1).Magnitude
    local e2Len = (p3 - p2).Magnitude
    local e3Len = (p3 - p1).Magnitude
    local longestDir
    if e1Len >= e2Len and e1Len >= e3Len then
        longestDir = (p2 - p1).Unit
    elseif e2Len >= e1Len and e2Len >= e3Len then
        longestDir = (p3 - p2).Unit
    else
        longestDir = (p3 - p1).Unit
    end

    local projDir = longestDir - normal * (normal.X * longestDir.X + normal.Y * longestDir.Y + normal.Z * longestDir.Z)
    if projDir.Magnitude < 0.0001 then return {} end
    projDir = projDir.Unit

    local localY = projDir:Cross(normal)
    if localY.Magnitude < 0.0001 then return {} end
    localY = localY.Unit

    local localX = localY:Cross(normal)
    if localX.Magnitude < 0.0001 then return {} end
    localX = localX.Unit

    local h1 = p1:Dot(localY)
    local h2 = p2:Dot(localY)
    local h3 = p3:Dot(localY)
    local minH = math.min(h1, h2, h3)
    local maxH = math.max(h1, h2, h3)
    local span = maxH - minH
    if span < 0.0001 then return {} end

    local numStrips = math.max(1, math.ceil(span / stripSize * detailMul))

    local edgeData = {
        {p1, p2, h1, h2},
        {p2, p3, h2, h3},
        {p3, p1, h3, h1}
    }

    for stripIdx = 0, numStrips - 1 do
        local stripH = minH + (stripIdx + 0.5) * span / numStrips
        local intersections = {}

        for _, edge in ipairs(edgeData) do
            local eA, eB, eHA, eHB = edge[1], edge[2], edge[3], edge[4]
            if stripH >= math.min(eHA, eHB) - 1e-5 and stripH <= math.max(eHA, eHB) + 1e-5 then
                local spanH = eHB - eHA
                local t = 0.5
                if math.abs(spanH) > 1e-5 then
                    t = math.clamp((stripH - eHA) / spanH, 0, 1)
                end
                local pt = eA + (eB - eA) * t
                intersections[#intersections + 1] = pt
            end
        end

        if #intersections >= 2 then

            local bestDist = 0
            local iP1 = intersections[1]
            local iP2 = intersections[2]
            for i = 1, #intersections do
                for j = i + 1, #intersections do
                    local d = (intersections[j] - intersections[i]).Magnitude
                    if d > bestDist then
                        bestDist = d
                        iP1 = intersections[i]
                        iP2 = intersections[j]
                    end
                end
            end

            if bestDist > 0.0001 then
                local stripCenter = (iP1 + iP2) / 2
                local stripDir = (iP2 - iP1).Unit

                local orientNormal = normal - stripDir * (stripDir.X * normal.X + stripDir.Y * normal.Y + stripDir.Z * normal.Z)
                if orientNormal.Magnitude < 0.0001 then
                    orientNormal = Vector3.new(0, 1, 0)
                end
                orientNormal = -orientNormal

                local cf = CFrame.fromMatrix(stripCenter, stripDir:Cross(orientNormal).Unit, orientNormal, stripDir)
                local colorStr = nil
                if type(color) == "string" and color ~= "" then
                    colorStr = color
                elseif typeof(color) == "Color3" then
                    colorStr = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B)
                end
                parts[#parts + 1] = cfToAsuBlock(cf, Vector3.new(stripSize, stripSize, bestDist), colorStr, blockIdStart + #parts, 0)
            end
        end
    end

    return parts
end

local function triangulateFace(faceIndices)
    local tris = {}
    if #faceIndices < 3 then
        return tris
    end
    for i = 2, #faceIndices - 1 do
        tris[#tris + 1] = {faceIndices[1], faceIndices[i], faceIndices[i + 1]}
    end
    return tris
end

local function addVoxelCell(cellMap, x, y, z, color)
    local key = x .. "," .. y .. "," .. z
    if not cellMap[key] then
        cellMap[key] = {x = x, y = y, z = z, color = color}
    end
end

local function rasterizeTriangleToVoxels(cellMap, p1, p2, p3, voxelSize, color)
    local e1 = p2 - p1
    local e2 = p3 - p1
    local e3 = p3 - p2
    local longest = math.max(e1.Magnitude, e2.Magnitude, e3.Magnitude)
    local steps = math.max(1, math.ceil(longest / math.max(voxelSize * 0.7, 0.05)))
    for i = 0, steps do
        for j = 0, steps - i do
            local a = i / steps
            local b = j / steps
            local c = 1 - a - b
            local p = p1 * c + p2 * a + p3 * b
            addVoxelCell(
                cellMap,
                math.floor(p.X / voxelSize + 0.5),
                math.floor(p.Y / voxelSize + 0.5),
                math.floor(p.Z / voxelSize + 0.5),
                color
            )
        end
    end
end

local function voxelCellsToBlocks(cellMap, voxelSize, blockIdStart)
    local voxels = {}
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    for _, v in pairs(cellMap) do
        voxels[#voxels + 1] = v
        minX = math.min(minX, v.x)
        minY = math.min(minY, v.y)
        minZ = math.min(minZ, v.z)
        maxX = math.max(maxX, v.x)
        maxY = math.max(maxY, v.y)
        maxZ = math.max(maxZ, v.z)
    end
    local boxes = greedyMergeVoxels(voxels)
    local blocks = {}
    local cx = (minX + maxX + 1) * 0.5
    local cy = (minY + maxY + 1) * 0.5
    local cz = (minZ + maxZ + 1) * 0.5
    for i, box in ipairs(boxes) do
        local sizeVec = Vector3.new(
            (box.x2 - box.x1 + 1) * voxelSize,
            (box.y2 - box.y1 + 1) * voxelSize,
            (box.z2 - box.z1 + 1) * voxelSize
        )
        local center = Vector3.new(
            ((box.x1 + box.x2 + 1) * 0.5 - cx) * voxelSize,
            ((box.y1 + box.y2 + 1) * 0.5 - cy) * voxelSize,
            ((box.z1 + box.z2 + 1) * 0.5 - cz) * voxelSize
        )
        blocks[#blocks + 1] = cfToAsuBlock(CFrame.new(center), sizeVec, box.color, (blockIdStart or 1) + i - 1, 0)
    end
    return blocks
end

local function buildObjBlocks(parsedObj, scale, thickness, mode, colorOpts)
    mode = tostring(mode or "solid"):lower()
    local vertices = parsedObj.vertices or {}
    local faces = parsedObj.faces or {}
    local materialColors = parsedObj.materialColors or {}
    local blocks = {}
    local blockId = 1
    local stripSize = tonumber(thickness) or 0.5
    local opts = colorOpts or {}
    local colorMode = opts.colorMode or "mesh"
    local solidDetail = tonumber(opts.detail) or 1
    local totalFaces = #faces
    local faceIndex = 0
    local gradDir = opts.gradDir or "y_asc"

    local gradMin, gradMax

    local function resolveColor(meshColor, pos)
        if colorMode == "custom" then
            return string.format("%.3f,%.3f,%.3f", opts.customR or 0.4, opts.customG or 0.6, opts.customB or 1.0)
        elseif colorMode == "random" then
            return string.format("%.3f,%.3f,%.3f", math.random(), math.random(), math.random())
        elseif colorMode == "gradient" then
            local t = 0
            if gradDir == "index" then
                t = totalFaces > 1 and (faceIndex / (totalFaces - 1)) or 0
            elseif pos and gradMin and gradMax then
                if gradDir == "y_asc" then
                    t = (pos.Y - gradMin.Y) / math.max(0.0001, gradMax.Y - gradMin.Y)
                elseif gradDir == "y_desc" then
                    t = 1 - (pos.Y - gradMin.Y) / math.max(0.0001, gradMax.Y - gradMin.Y)
                elseif gradDir == "x_asc" then
                    t = (pos.X - gradMin.X) / math.max(0.0001, gradMax.X - gradMin.X)
                elseif gradDir == "x_desc" then
                    t = 1 - (pos.X - gradMin.X) / math.max(0.0001, gradMax.X - gradMin.X)
                elseif gradDir == "z_asc" then
                    t = (pos.Z - gradMin.Z) / math.max(0.0001, gradMax.Z - gradMin.Z)
                elseif gradDir == "z_desc" then
                    t = 1 - (pos.Z - gradMin.Z) / math.max(0.0001, gradMax.Z - gradMin.Z)
                elseif gradDir == "radial_out" then
                    local gc = (gradMin + gradMax) / 2
                    t = (pos - gc).Magnitude / math.max(0.0001, (gradMax - gradMin).Magnitude / 2)
                elseif gradDir == "radial_in" then
                    local gc = (gradMin + gradMax) / 2
                    t = 1 - (pos - gc).Magnitude / math.max(0.0001, (gradMax - gradMin).Magnitude / 2)
                else
                    t = totalFaces > 1 and (faceIndex / (totalFaces - 1)) or 0
                end
            else
                t = totalFaces > 1 and (faceIndex / (totalFaces - 1)) or 0
            end
            t = math.clamp(t, 0, 1)
            local g1R, g1G, g1B = opts.grad1R or 1, opts.grad1G or 0.3, opts.grad1B or 0.1
            local g2R, g2G, g2B = opts.grad2R or 0.1, opts.grad2G or 0.3, opts.grad2B or 1
            local cr = g1R + (g2R - g1R) * t
            local cg = g1G + (g2G - g1G) * t
            local cb = g1B + (g2B - g1B) * t
            return string.format("%.3f,%.3f,%.3f", cr, cg, cb)
        else
            return meshColor
        end
    end

    local verts = {}
    for _, v in ipairs(vertices) do
        verts[#verts + 1] = v.pos * scale
    end

    local faceIndices = {}
    for _, f in ipairs(faces) do
        faceIndices[#faceIndices + 1] = f.indices
    end

    if #faceIndices > 0 then
    end

    if #verts == 0 then return blocks end

    local bMin = verts[1]
    local bMax = verts[1]
    for _, v in ipairs(verts) do
        bMin = Vector3.new(math.min(bMin.X, v.X), math.min(bMin.Y, v.Y), math.min(bMin.Z, v.Z))
        bMax = Vector3.new(math.max(bMax.X, v.X), math.max(bMax.Y, v.Y), math.max(bMax.Z, v.Z))
    end
    local center = (bMin + bMax) / 2
    local localMin = bMin - center
    local localMax = bMax - center

    local yShift = -(localMin.Y) + 4
    center = center + Vector3.new(0, yShift, 0)
    localMin = bMin - center
    localMax = bMax - center

    gradMin = localMin
    gradMax = localMax

    local centeredVerts = {}
    for _, v in ipairs(verts) do
        centeredVerts[#centeredVerts + 1] = v - center
    end

    local edgeCount = {}
    local edgeOrder = {}
    local edgeMap = {}
    local edgeFaces = {}
    local allEdges = {}
    for _, face in ipairs(faceIndices) do
        local seenInFace = {}
        for i = 1, #face do
            local a = face[i]
            local b = face[(i % #face) + 1]
            if a >= 1 and a <= #centeredVerts and b >= 1 and b <= #centeredVerts and a ~= b then
                local k1, k2 = math.min(a, b), math.max(a, b)
                local key = k1 .. "_" .. k2
                if not seenInFace[key] then
                    seenInFace[key] = true
                    edgeCount[key] = (edgeCount[key] or 0) + 1
                    if not edgeMap[key] then
                        edgeMap[key] = {centeredVerts[a], centeredVerts[b], a, b}
                        edgeOrder[#edgeOrder + 1] = key
                        edgeFaces[key] = {}
                    end
                    edgeFaces[key][#edgeFaces[key] + 1] = face
                end
            end
        end
    end
    local edges = {}
    for _, key in ipairs(edgeOrder) do
        local count = edgeCount[key]
        local keep = true
        if count >= 2 then
            local fs = edgeFaces[key]
            local e = edgeMap[key]
            local va, vb = e[3], e[4]
            local pa, pb = centeredVerts[va], centeredVerts[vb]
            if pa and pb then
                local normals = {}
                for fi = 1, #fs do
                    local face = fs[fi]
                    local oppVerts = {}
                    for _, idx in ipairs(face) do
                        if idx ~= va and idx ~= vb then
                            oppVerts[#oppVerts + 1] = centeredVerts[idx]
                        end
                    end
                    if #oppVerts >= 1 then
                        local bestN = nil
                        local bestMag = 0
                        for _, ov in ipairs(oppVerts) do
                            if ov then
                                local n = (pb - pa):Cross(ov - pa)
                                if n.Magnitude > bestMag then
                                    bestN = n
                                    bestMag = n.Magnitude
                                end
                            end
                        end
                        if bestN and bestMag > 0.0001 then
                            normals[#normals + 1] = bestN.Unit
                        end
                    end
                end
                if #normals >= 2 then
                    local allCoplanar = true
                    for i = 2, #normals do
                        if math.abs(normals[1]:Dot(normals[i])) > 0.995 then
                        else
                            allCoplanar = false
                            break
                        end
                    end
                    if allCoplanar then
                        keep = false
                    end
                end
            end
        end
        if keep then
            local eNormal = nil
            local efs = edgeFaces[key]
            if efs and #efs >= 1 then
                local sumN = Vector3.zero
                local nCount = 0
                for _, face in ipairs(efs) do
                    if #face >= 3 then
                        local fp1 = centeredVerts[face[1]]
                        local fp2 = centeredVerts[face[2]]
                        local fp3 = centeredVerts[face[3]]
                        if fp1 and fp2 and fp3 then
                            local fn = (fp2 - fp1):Cross(fp3 - fp1)
                            if fn.Magnitude > 0.0001 then
                                sumN = sumN + fn.Unit
                                nCount = nCount + 1
                            end
                        end
                    end
                end
                if nCount > 0 and sumN.Magnitude > 0.0001 then
                    eNormal = sumN.Unit
                end
            end
            edges[#edges + 1] = {edgeMap[key][1], edgeMap[key][2], eNormal}
        end

        do
            local eNormal2 = nil
            local efs2 = edgeFaces[key]
            if efs2 and #efs2 >= 1 then
                local sumN2 = Vector3.zero
                local nC2 = 0
                for _, face in ipairs(efs2) do
                    if #face >= 3 then
                        local fp1 = centeredVerts[face[1]]
                        local fp2 = centeredVerts[face[2]]
                        local fp3 = centeredVerts[face[3]]
                        if fp1 and fp2 and fp3 then
                            local fn = (fp2 - fp1):Cross(fp3 - fp1)
                            if fn.Magnitude > 0.0001 then
                                sumN2 = sumN2 + fn.Unit
                                nC2 = nC2 + 1
                            end
                        end
                    end
                end
                if nC2 > 0 and sumN2.Magnitude > 0.0001 then
                    eNormal2 = sumN2.Unit
                end
            end
            allEdges[#allEdges + 1] = {edgeMap[key][1], edgeMap[key][2], eNormal2}
        end
    end

    local function getColor(pos)
        for _, f in ipairs(faces) do
            local color = chooseFaceColor(f, vertices, f.material, materialColors)
            if color then return color end
        end
        return nil
    end

    local function getColorForPos(pos)

        local bestDist = math.huge
        local bestColor = nil
        for _, f in ipairs(faces) do
            local indices = f.indices
            if #indices >= 3 then
                for i = 2, #indices - 1 do
                    local p1 = centeredVerts[indices[1]]
                    local p2 = centeredVerts[indices[i]]
                    local p3 = centeredVerts[indices[i+1]]
                    if p1 and p2 and p3 then
                        local centroid = (p1 + p2 + p3) / 3
                        local dist = (pos - centroid).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            bestColor = chooseFaceColor(indices, vertices, f.material, materialColors)
                        end
                    end
                end
            end
        end
        return bestColor
    end

    if mode == "face" then
        for fi, f in ipairs(faces) do
            faceIndex = fi
            local points = {}
            for _, idx in ipairs(f.indices) do
                points[#points + 1] = centeredVerts[idx] or vertices[idx].pos
            end
            local meshColor = chooseFaceColor(f.indices, vertices, f.material, materialColors)
            local cx, cy, cz = 0, 0, 0
            for _, p in ipairs(points) do cx = cx + p.x; cy = cy + p.y; cz = cz + p.z end
            local n = #points
            local faceCentroid = Vector3.new(cx/n, cy/n, cz/n)
            local color = resolveColor(meshColor, faceCentroid)
            local block = makeFacePanelCentered(points, thickness, color, blockId)
            if block then
                blocks[#blocks + 1] = block
                blockId = blockId + 1
            end
        end
    elseif mode == "wireframe" then
        for ei, edge in ipairs(allEdges) do
            faceIndex = math.ceil(ei / 3)
            local pA, pB, eNormal = edge[1], edge[2], edge[3]
            if not pA or not pB then continue end
            local mid = (pA + pB) / 2
            local meshColor = getColorForPos(mid)

            local color = resolveColor(meshColor, mid)
            if not color or color == "" then
                color = resolveColor(nil, mid)
            end
            if not color or color == "" then
                color = string.format("%.3f,%.3f,%.3f", opts.customR or 0.4, opts.customG or 0.6, opts.customB or 1.0)
            end

            local wfThick = math.max(stripSize, 0.25)
            local block = makeEdgeBlockFromRef(pA, pB, wfThick, color, blockId, eNormal)
            if block then
                blocks[#blocks + 1] = block
                blockId = blockId + 1
            end
        end
    elseif mode == "solid" then
        local function pointInTriangle2D(px, py, ax, ay, bx, by, cx, cy)
            local d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
            local d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
            local d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
            local hasNeg = (d1 < 0) or (d2 < 0) or (d3 < 0)
            local hasPos = (d1 > 0) or (d2 > 0) or (d3 > 0)
            return not (hasNeg and hasPos)
        end
        local function largestRectInGrid(grid, rows, cols)
            local heights = {}
            for c = 0, cols - 1 do heights[c] = 0 end
            local best = nil
            for r = 0, rows - 1 do
                for c = 0, cols - 1 do
                    heights[c] = grid[r][c] and (heights[c] + 1) or 0
                end
                local stack = {}
                for c = 0, cols do
                    local h = (c < cols) and heights[c] or 0
                    while #stack > 0 and heights[stack[#stack]] >= h do
                        local top = table.remove(stack)
                        local height = heights[top]
                        local left = (#stack > 0) and (stack[#stack] + 1) or 0
                        local width = c - left
                        local area = height * width
                        if height > 0 and (not best or area > best.area) then
                            best = {area = area, r0 = r + 1 - height, r1 = r, c0 = left, c1 = c - 1}
                        end
                    end
                    stack[#stack + 1] = c
                end
            end
            return best
        end
        local function decomposeFaceMosaic(p1, p2, p3, cellSize, color, blockIdStart)
            local minP = Vector3.new(math.min(p1.X, p2.X, p3.X), math.min(p1.Y, p2.Y, p3.Y), math.min(p1.Z, p2.Z, p3.Z))
            local maxP = Vector3.new(math.max(p1.X, p2.X, p3.X), math.max(p1.Y, p2.Y, p3.Y), math.max(p1.Z, p2.Z, p3.Z))
            local v1 = p2 - p1; local normal = v1:Cross(p3 - p1)
            if normal.Magnitude < 0.0001 then return {} end
            normal = normal.Unit
            local e1Len = (p2 - p1).Magnitude; local e2Len = (p3 - p2).Magnitude; local e3Len = (p3 - p1).Magnitude
            local longestDir
            if e1Len >= e2Len and e1Len >= e3Len then longestDir = (p2 - p1).Unit
            elseif e2Len >= e1Len and e2Len >= e3Len then longestDir = (p3 - p2).Unit
            else longestDir = (p3 - p1).Unit end
            local projDir = longestDir - normal * (normal:Dot(longestDir))
            if projDir.Magnitude < 0.0001 then return {} end
            projDir = projDir.Unit
            local localY = projDir:Cross(normal)
            if localY.Magnitude < 0.0001 then return {} end
            localY = localY.Unit
            local localX = localY:Cross(normal)
            if localX.Magnitude < 0.0001 then return {} end
            localX = localX.Unit
            local h1 = p1:Dot(localY); local h2 = p2:Dot(localY); local h3 = p3:Dot(localY)
            local w1 = p1:Dot(localX); local w2 = p2:Dot(localX); local w3 = p3:Dot(localX)
            local minH, maxH = math.min(h1, h2, h3), math.max(h1, h2, h3)
            local minW, maxW = math.min(w1, w2, w3), math.max(w1, w2, w3)
            local spanH = maxH - minH; local spanW = maxW - minW
            if spanH < 0.01 or spanW < 0.01 then return {} end
            local rows = math.max(1, math.ceil(spanH / cellSize))
            local cols = math.max(1, math.ceil(spanW / cellSize))
            local grid = {}
            local aW, aH = p1:Dot(localX), p1:Dot(localY)
            local bW, bH = p2:Dot(localX), p2:Dot(localY)
            local cW, cH = p3:Dot(localX), p3:Dot(localY)
            for r = 0, rows - 1 do
                grid[r] = {}
                local cy = minH + (r + 0.5) * (spanH / rows)
                for c = 0, cols - 1 do
                    local cx = minW + (c + 0.5) * (spanW / cols)
                    grid[r][c] = pointInTriangle2D(cx, cy, aW, aH, bW, bH, cW, cH)
                end
            end
            local result = {}
            local cellW = spanW / cols; local cellH = spanH / rows
            while true do
                local rect = largestRectInGrid(grid, rows, cols)
                if not rect then break end
                local cx0 = minW + rect.c0 * cellW
                local cx1 = minW + (rect.c1 + 1) * cellW
                local cy0 = minH + rect.r0 * cellH
                local cy1 = minH + (rect.r1 + 1) * cellH
                local ccx = (cx0 + cx1) / 2; local ccy = (cy0 + cy1) / 2
                local center3 = p1 + localX * (ccx - aW) + localY * (ccy - aH)
                local sizeW = cx1 - cx0; local sizeH = cy1 - cy0
                local cf = CFrame.fromMatrix(center3, localX, localY, normal)
                local colorStr = nil
                if type(color) == "string" and color ~= "" then colorStr = color
                elseif typeof(color) == "Color3" then colorStr = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B) end
                result[#result + 1] = cfToAsuBlock(cf, Vector3.new(sizeW, sizeH, thickness), colorStr, blockIdStart + #result, 0)
                for r = rect.r0, rect.r1 do
                    for c = rect.c0, rect.c1 do grid[r][c] = false end
                end
                if #result > 2000 then break end
            end
            return result
        end
        for fi, face in ipairs(faceIndices) do
            faceIndex = fi
            if not face or #face < 3 then
                continue
            end
            for i = 2, #face - 1 do
                local p1 = centeredVerts[face[1]]
                local p2 = centeredVerts[face[i]]
                local p3 = centeredVerts[face[i + 1]]
                if p1 and p2 and p3 then
                    local centroid = (p1 + p2 + p3) / 3
                    local meshColor = getColorForPos(centroid)
                    local color = resolveColor(meshColor, centroid)
                    local triBlocks = decomposeFaceMosaic(p1, p2, p3, stripSize * solidDetail, color, blockId)
                    if #triBlocks == 0 then
                        local dist = (p2 - p1).Magnitude
                        if dist < stripSize * solidDetail then
                            triBlocks = decomposeFaceMosaic(p1, p2, p3, dist * 0.5, color, blockId)
                        end
                    end
                    if #triBlocks == 0 then
                        local triN = (p2 - p1):Cross(p3 - p1)
                        if triN.Magnitude > 0.0001 then triN = triN.Unit else triN = nil end
                        local block = makeEdgeBlockFromRef(p1, p2, stripSize, color, blockId, triN)
                        if block then triBlocks = {block} end
                    end
                    for _, blk in ipairs(triBlocks) do
                        blocks[#blocks + 1] = blk
                        blockId = blockId + 1
                    end
                end
            end
        end
        local wfThickness = math.max(0.03, stripSize)
        for ei, edge in ipairs(edges) do
            faceIndex = math.ceil(ei / 3)
            local pA, pB, eNormal = edge[1], edge[2], edge[3]
            local mid = (pA + pB) / 2
            local meshColor = getColorForPos(mid)
            local color = resolveColor(meshColor, mid)
            local block = makeEdgeBlockFromRef(pA, pB, wfThickness, color, blockId, eNormal)
            if block then
                blocks[#blocks + 1] = block
                blockId = blockId + 1
            end
        end
    elseif mode == "voxel" then
        local cellMap = {}
        local voxelSize = math.max(0.05, stripSize)
        for fi, f in ipairs(faces) do
            faceIndex = fi
            local meshColor = chooseFaceColor(f.indices, vertices, f.material, materialColors)
            local fcx, fcy, fcz = 0, 0, 0
            for _, idx in ipairs(f.indices) do local p = centeredVerts[idx] or vertices[idx].pos; fcx = fcx + p.x; fcy = fcy + p.y; fcz = fcz + p.z end
            local fn = #f.indices
            local voxCentroid = Vector3.new(fcx/fn, fcy/fn, fcz/fn)
            local color = resolveColor(meshColor, voxCentroid)
            for _, tri in ipairs(triangulateFace(f.indices)) do
                local vp1 = centeredVerts[tri[1]] or vertices[tri[1]].pos
                local vp2 = centeredVerts[tri[2]] or vertices[tri[2]].pos
                local vp3 = centeredVerts[tri[3]] or vertices[tri[3]].pos
                rasterizeTriangleToVoxels(cellMap, vp1, vp2, vp3, voxelSize / math.max(scale, 0.001), color)
            end
        end
        blocks = voxelCellsToBlocks(cellMap, voxelSize, blockId)
    end
    return blocks
end

convertObjToBlocks = function(filePath, scale, thickness, mode, material, colorOpts)
    scale = tonumber(scale) or 1
    thickness = tonumber(thickness) or 0.2
    material = tostring(material or "PlasticBlock")
    if scale <= 0 or thickness <= 0 then
        return nil, nil, "Scale/thickness must be > 0"
    end
    local readFileOk, text = pcall(readfile, filePath)
    if not readFileOk then
        return nil, nil, "Failed to read file: " .. tostring(text)
    end
    local parsed = parseObjData(text, filePath)
    if #(parsed.vertices or {}) == 0 then
        return nil, nil, "No vertices found in OBJ file"
    end
    local blocks = buildObjBlocks(parsed, scale, thickness, mode, colorOpts)
    if #blocks == 0 then
        return nil, nil, "No blocks produced"
    end
    local minY = math.huge
    for _, blk in ipairs(blocks) do
        if blk.Position then
            local nums = parseNums(blk.Position)
            if #nums >= 3 and nums[2] < minY then
                minY = nums[2]
            end
        end
    end
    if minY < 4 then
        local yShift = 4 - minY
        for _, blk in ipairs(blocks) do
            if blk.Position then
                local nums = parseNums(blk.Position)
                if #nums >= 3 then
                    nums[2] = nums[2] + yShift
                    blk.Position = string.format("%.6f, %.6f, %.6f", nums[1], nums[2], nums[3])
                end
            end
        end
    end
    return material, blocks, nil
end

convertObjToBuild = function(filePath, buildName, scale, thickness, material, mode, colorOpts)
    local outMaterial, blocks, err = convertObjToBlocks(filePath, scale, thickness, mode, material, colorOpts)
    if not outMaterial then
        return nil, err
    end
    return writeConvertedBuild(buildName, outMaterial, blocks)
end
end

local function bytesToFloatLE(b1, b2, b3, b4)
    local v = (((b4 * 256) + b3) * 256 + b2) * 256 + b1
    if v == 0 then return 0 end
    local sign = bit.band(v, 0x80000000) ~= 0 and -1 or 1
    local exp = bit.band(bit.rshift(v, 23), 0xFF)
    local mant = bit.band(v, 0x7FFFFF)
    if exp == 0 then
        return sign * (mant / 8388608) * 2^-126
    end
    if exp == 255 then
        return sign * math.huge
    end
    return sign * (1 + mant / 8388608) * 2^(exp - 127)
end

local function asuToCF(pos, rot)
    local p = {0,0,0}
    if type(pos) == "string" then
        local v = parseNums(pos)
        if #v >= 3 then p = {v[1],v[2],v[3]} end
    elseif type(pos) == "table" then p = pos end
    local r = {0,0,0}
    if type(rot) == "string" then
        local v = parseNums(rot)
        if #v >= 3 then r = {math.rad(v[1]),math.rad(v[2]),math.rad(v[3])} end
    elseif type(rot) == "table" then
        for i,v in ipairs(rot) do r[i] = math.rad(tonumber(v) or 0) end
    end
    return CFrame.new(p[1] or 0, p[2] or 0, p[3] or 0) * CFrame.Angles(r[1] or 0, r[2] or 0, r[3] or 0)
end

local function convertAsuToPRS(asuData)
    if type(asuData) ~= "table" then return nil end
    local prs = {}
    local entriesById = {}
    local pendingBindTables = {}
    local globalIdCounter = 1
    for blockName, blocks in pairs(asuData) do
        if type(blocks) == "table" then
            prs[blockName] = prs[blockName] or {}
            for _, block in ipairs(blocks) do
                if type(block) == "table" then
                    local pos = block.Position or block.position or block.Pos or block.pos
                    local rot = block.Rotation or block.rotation or block.Rot or block.rot
                    if not pos then continue end
                    local cf
                    if type(pos) == "string" or type(rot) == "string" then
                        cf = asuToCF(tostring(pos), rot and tostring(rot) or "0,0,0")
                    else
                        cf = CFrame.new(
                            (type(pos)=="table") and (pos[1] or pos.X or 0) or 0,
                            (type(pos)=="table") and (pos[2] or pos.Y or 0) or 0,
                            (type(pos)=="table") and (pos[3] or pos.Z or 0) or 0
                        ) * CFrame.Angles(
                            math.rad((type(rot)=="table") and (rot[1] or rot.X or 0) or 0),
                            math.rad((type(rot)=="table") and (rot[2] or rot.Y or 0) or 0),
                            math.rad((type(rot)=="table") and (rot[3] or rot.Z or 0) or 0)
                        )
                    end
                    local sz = block.Size or block.size
                    local col = block.Color or block.color or block.Col or block.col
                    local sizeStr = nil
                    if sz then
                        local sizeVec = Vector3.new(1,1,1)
                        if type(sz) == "string" then
                            local v = parseNums(sz)
                            if #v >= 3 then sizeVec = Vector3.new(v[1],v[2],v[3]) end
                        elseif type(sz) == "table" then
                            sizeVec = Vector3.new(sz[1] or sz.X or 1, sz[2] or sz.Y or 1, sz[3] or sz.Z or 1)
                        elseif type(sz) == "number" then
                            sizeVec = Vector3.new(sz,sz,sz)
                        end
                        sizeStr = v3Str(sizeVec)
                    end
                    local colStr2 = nil
                    if col and type(col) == "string" then
                        local cv = parseNums(col)
                        if #cv >= 3 then
                            local r2,g2,b2 = cv[1],cv[2],cv[3]
                            if r2>1 or g2>1 or b2>1 then r2=r2/255; g2=g2/255; b2=b2/255 end
                            colStr2 = string.format("%.4f,%.4f,%.4f", math.clamp(r2,0,1), math.clamp(g2,0,1), math.clamp(b2,0,1))
                        end
                    end
                    local extras = collectAsuExtras(block)
                    local mergedBoolValues, mergedNumberValues = mergePropertyMaps(block.BoolValues, block.NumberValues, extras)
                    if mergedNumberValues then
                        if mergedNumberValues.LastDirrection ~= nil and mergedNumberValues.LastDirection == nil then
                            mergedNumberValues.LastDirection = mergedNumberValues.LastDirrection
                            mergedNumberValues.LastDirrection = nil
                        end
                    end
                    local assignedId = block.ID or globalIdCounter
                    globalIdCounter = globalIdCounter + 1
                    local entry = {
                        CFrame = cfStr(cf),
                        ID = assignedId,
                        Size = sizeStr,
                        Col = colStr2,
                        Transparency = block.Transparency,
                        Anchored = block.Anchored,
                        CanCollide = block.CanCollide,
                        ShowShadow = block.ShowShadow,
                        ASUExtra = extras,
                        BoolValues = mergedBoolValues,
                        NumberValues = mergedNumberValues,
                    }

                    if block.SecondaryPartPosition then entry.SecondaryPartPosition = tostring(block.SecondaryPartPosition) end
                    if block.SecondaryPartRotation then entry.SecondaryPartRotation = tostring(block.SecondaryPartRotation) end
                    if block.Stiffness ~= nil then entry.Stiffness = block.Stiffness end
                    if block.Damping ~= nil then entry.Damping = block.Damping end
                    if block.TargetLength ~= nil then entry.TargetLength = block.TargetLength end
                    if block.MaxLength ~= nil then entry.MaxLength = block.MaxLength end
                    if block.MinLength ~= nil then entry.MinLength = block.MinLength end
                    if block.Length ~= nil then entry.Length = block.Length end
                    if block.AngleLimit ~= nil then entry.AngleLimit = block.AngleLimit end
                    if block.MatchRotation ~= nil then entry.MatchRotation = block.MatchRotation end
                    if block.ShowConstraint ~= nil then entry.ShowConstraint = block.ShowConstraint end
                    if block.ServoTorque ~= nil then entry.ServoTorque = block.ServoTorque end
                    if block.ServoSpeed ~= nil then entry.ServoSpeed = block.ServoSpeed end
                    if block.BarLength ~= nil then entry.BarLength = block.BarLength end
                    if block.WheelTorque ~= nil then entry.WheelTorque = block.WheelTorque end
                    if block.Text then entry.Text = block.Text end
                    if type(block.BindTable) == "table" then
                        entry.BindTable = cloneJsonValue(block.BindTable)
                        pendingBindTables[#pendingBindTables + 1] = entry.BindTable
                    end
                    if entry.ID ~= nil then
                        entriesById[entry.ID] = entry
                        entriesById[tostring(entry.ID)] = entry
                    end
                    table.insert(prs[blockName], entry)
                end
            end
        end
    end
    for _, bindTable in ipairs(pendingBindTables) do
        for _, row in ipairs(bindTable) do
            if type(row) == "table" then
                local target = entriesById[row[1]] or entriesById[tostring(row[1])]
                local bindName = row[2]
                if target and bindName then
                    target.NumberValues = target.NumberValues or {}
                    target.NumberValues[bindName] = tonumber(row[3]) or row[3]
                end
            end
        end
    end
    return prs
end

local function convertedBlocksToPRS(material, blocks)
    if type(blocks) ~= "table" or #blocks == 0 then
        return nil
    end
    local materialName = tostring(material or "PlasticBlock")
    if materialName ~= "Auto" then
        return convertAsuToPRS({[materialName] = blocks})
    end
    local groups = {}
    for _, block in ipairs(blocks) do
        local blockMaterial = tostring(block.Material or "PlasticBlock")
        groups[blockMaterial] = groups[blockMaterial] or {}
        groups[blockMaterial][#groups[blockMaterial] + 1] = block
    end
    return convertAsuToPRS(groups)
end

local function convertRobloxAssetToBlocks(assetId, scale)
    local id = tostring(assetId or ""):match("%d+")
    if not id then return nil, "Enter a valid Roblox asset ID" end
    scale = math.clamp(tonumber(scale) or 1, 0.05, 10)
    local ok, loaded = pcall(function()
        return game:GetObjects("rbxassetid://" .. id)
    end)
    if not ok or type(loaded) ~= "table" or not loaded[1] then
        return nil, "Roblox could not load this asset ID"
    end
    local root = loaded[1]
    local parts = {}
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("BasePart") then parts[#parts + 1] = obj end
    end
    if root:IsA("BasePart") then parts[#parts + 1] = root end
    if #parts == 0 then return nil, "The asset has no BasePart or MeshPart" end
    local function mapRobloxMaterial(mat)
        local n = tostring(mat and mat.Name or ""):lower()
        if n:find("wood") then return "WoodBlock" end
        if n:find("metal") or n:find("diamond") or n:find("foil") then return "MetalBlock" end
        if n:find("glass") then return "GlassBlock" end
        if n:find("neon") then return "NeonBlock" end
        if n:find("fabric") then return "FabricBlock" end
        if n:find("granite") then return "GraniteBlock" end
        if n:find("marble") then return "MarbleBlock" end
        if n:find("slate") then return "SlateBlock" end
        if n:find("brick") then return "BrickBlock" end
        if n:find("cobble") then return "CobblestoneBlock" end
        if n:find("grass") then return "GrassBlock" end
        if n:find("ice") then return "IceBlock" end
        if n:find("sand") then return "SandBlock" end
        if n:find("concrete") then return "ConcreteBlock" end
        if n:find("corroded") then return "CorrodedMetalBlock" end
        if n:find("pebble") then return "PebbleBlock" end
        return "PlasticBlock"
    end
    local center = Vector3.zero
    for _, part in ipairs(parts) do center = center + part.Position end
    center = center / #parts
    local blocks = {}
    for index, part in ipairs(parts) do
        local rx, ry, rz = part.CFrame:ToOrientation()
        blocks[#blocks + 1] = {
            Position = {(part.Position.X - center.X) * scale, (part.Position.Y - center.Y) * scale, (part.Position.Z - center.Z) * scale},
            Rotation = {math.deg(rx), math.deg(ry), math.deg(rz)},
            Size = {math.max(0.05, part.Size.X * scale), math.max(0.05, part.Size.Y * scale), math.max(0.05, part.Size.Z * scale)},
            Color = colStr(part.Color),
            Transparency = part.Transparency,
            Anchored = true,
            CanCollide = part.CanCollide,
            Material = mapRobloxMaterial(part.Material),
            ID = index,
        }
    end
    pcall(function() root:Destroy() end)
    return blocks, nil
end

local function convertPRStoBH(prsData)
    if type(prsData) ~= "table" then return nil end
    local data = {}
    for blockName, blocks in pairs(prsData) do
        if type(blocks) == "table" and #blocks > 0 then
            local arr = {}
            for idx, bi in ipairs(blocks) do
                local entry = {}
                entry.ID = bi.ID or idx
                entry.Anchored = bi.Anchored ~= false
                entry.CanCollide = bi.CanCollide ~= false
                entry.Transparency = bi.Transparency or 0
                entry.CastShadow = bi.ShowShadow ~= false
                if bi.CFrame then
                    if type(bi.CFrame) == "string" then
                        local nums = {}
                        for v in bi.CFrame:gmatch("[^,]+") do
                            local n = tonumber(v:match("^%s*(.-)%s*$"))
                            if n then table.insert(nums, n) end
                        end
                        entry.CFrame = nums
                    elseif type(bi.CFrame) == "table" then
                        entry.CFrame = bi.CFrame
                    end
                end
                if bi.Size then
                    if type(bi.Size) == "string" then
                        local nums = {}
                        for v in bi.Size:gmatch("[^,]+") do
                            local n = tonumber(v:match("^%s*(.-)%s*$"))
                            if n then table.insert(nums, n) end
                        end
                        entry.Size = nums
                    elseif type(bi.Size) == "table" then
                        entry.Size = bi.Size
                    end
                end
                if bi.Col then
                    local cv = {}
                    for v in bi.Col:gmatch("[^,]+") do
                        local n = tonumber(v:match("^%s*(.-)%s*$"))
                        if n then table.insert(cv, n) end
                    end
                    if #cv >= 3 then
                        local r = math.floor((cv[1] or 1) * 255 + 0.5)
                        local g = math.floor((cv[2] or 1) * 255 + 0.5)
                        local b = math.floor((cv[3] or 1) * 255 + 0.5)
                        entry.Color = string.format("%02x%02x%02x", r, g, b)
                    end
                end
                local mVals = {}
                if bi.NumberValues and type(bi.NumberValues) == "table" then
                    for k, v in pairs(bi.NumberValues) do mVals[k] = v end
                end
                if bi.BoolValues and type(bi.BoolValues) == "table" then
                    for k, v in pairs(bi.BoolValues) do mVals[k] = v end
                end
                if next(mVals) then entry.MValues = mVals end
                if bi.SecCFrame then
                    if type(bi.SecCFrame) == "string" then
                        local nums = {}
                        for v in bi.SecCFrame:gmatch("[^,]+") do
                            local n = tonumber(v:match("^%s*(.-)%s*$"))
                            if n then table.insert(nums, n) end
                        end
                        entry.SecCFrame = nums
                    elseif type(bi.SecCFrame) == "table" then
                        entry.SecCFrame = bi.SecCFrame
                    end
                end
                if bi.BindTable and type(bi.BindTable) == "table" then
                    local idToBlock = {}
                    for bName, bList in pairs(prsData) do
                        if type(bList) == "table" then
                            for _, bEntry in ipairs(bList) do
                                if bEntry.ID then idToBlock[bEntry.ID] = bName end
                            end
                        end
                    end
                    for _, bindRow in ipairs(bi.BindTable) do
                        if type(bindRow) == "table" and bindRow[1] then
                            local targetID = bindRow[1]
                            local bindName = bindRow[2]
                            local bindValue = bindRow[3]
                            local targetName = idToBlock[targetID]
                            if not entry.Binds then entry.Binds = {} end
                            table.insert(entry.Binds, {targetID, bindName, bindValue})
                        end
                    end
                end
                table.insert(arr, entry)
            end
            data[blockName] = arr
        end
    end
    return {Data = data, AutoBuild_Version = "v1"}
end

local function saveBuildToFile(fileName, buildData)
    ensureFolder()
    local bhData = convertPRStoBH(buildData)
    if bhData then

        local function jsonEncode(val)
            if val == nil then return "null" end
            if type(val) == "boolean" then return val and "true" or "false" end
            if type(val) == "number" then return tostring(val) end
            if type(val) == "string" then return '"' .. val:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t') .. '"' end
            if type(val) ~= "table" then return "null" end

            local isArray = true
            local maxIdx = 0
            for k in pairs(val) do
                if type(k) == "number" and k == math.floor(k) and k >= 1 then
                    if k > maxIdx then maxIdx = k end
                else
                    isArray = false; break
                end
            end
            if isArray and maxIdx == #val then

                local parts = {}
                parts[#parts+1] = '['
                for i = 1, #val do
                    if i > 1 then parts[#parts+1] = ',' end
                    parts[#parts+1] = jsonEncode(val[i])
                end
                parts[#parts+1] = ']'
                return table.concat(parts)
            else

                local parts = {}
                parts[#parts+1] = '{'
                local sortedKeys = {}
                for k in pairs(val) do sortedKeys[#sortedKeys+1] = k end
                table.sort(sortedKeys, function(a, b) return tostring(a) < tostring(b) end)
                local first = true
                for _, k in ipairs(sortedKeys) do
                    if not first then parts[#parts+1] = ',' end
                    first = false
                    parts[#parts+1] = '"' .. tostring(k) .. '":'
                    parts[#parts+1] = jsonEncode(val[k])
                end
                parts[#parts+1] = '}'
                return table.concat(parts)
            end
        end
        local ok, result = pcall(function()
            return jsonEncode(bhData)
        end)
        if ok and result then
            writefile(FOLDER_PREFIX .. fileName .. ".Build", result)
            return true, "BH"
        end
    end
    return false
end

local function convertMcLaren(rawData)

    local converted = {}
    local invertedBinds = {}
    local idToKey = {}

    for blockName, blocks in pairs(rawData) do
        if type(blocks) == "table" and #blocks > 0 then
            local arr = {}
            for idx, bi in ipairs(blocks) do
                local entry = {}
                entry.ID = bi.ID
                entry.Transparency = bi.Transparency
                entry.Anchored = bi.Anchored
                entry.CanCollide = bi.CanCollide
                entry.CFrame = bi.CFrame
                entry.Size = bi.Size

                if bi.Color then
                    local hex = tostring(bi.Color):gsub("^#","")
                    local r = tonumber(hex:sub(1,2), 16) or 255
                    local g = tonumber(hex:sub(3,4), 16) or 255
                    local b = tonumber(hex:sub(5,6), 16) or 255
                    entry.Col = string.format("%.6f,%.6f,%.6f", r/255, g/255, b/255)
                end

                if bi.CastShadow ~= nil then
                    entry.ShowShadow = bi.CastShadow
                end

                if bi.MValues and type(bi.MValues) == "table" then
                    local numV, boolV = {}, {}
                    for k, v in pairs(bi.MValues) do
                        if type(v) == "number" then
                            numV[k] = v
                        elseif type(v) == "boolean" then
                            boolV[k] = v
                        else
                            numV[k] = v
                        end
                    end
                    if next(numV) then entry.NumberValues = numV end
                    if next(boolV) then entry.BoolValues = boolV end
                end

                if bi.SecCFrame then
                    entry.SecCFrame = bi.SecCFrame
                end

                local knownKeys = {ID=true, Transparency=true, Anchored=true, CanCollide=true,
                    CFrame=true, Size=true, Color=true, CastShadow=true, Binds=true, MValues=true, SecCFrame=true}
                local extra = {}
                for k, v in pairs(bi) do
                    if not knownKeys[k] then extra[k] = v end
                end
                if next(extra) then entry.ASUExtra = extra end
                arr[#arr+1] = entry

                if bi.ID then
                    idToKey[bi.ID] = {blockName = blockName, idx = idx}
                end

                if bi.Binds and type(bi.Binds) == "table" then
                    for _, bindRow in ipairs(bi.Binds) do
                        if type(bindRow) == "table" and bindRow[1] then
                            local sourceID = bindRow[1]
                            local bindName = bindRow[2]
                            local bindValue = bindRow[3]
                            if not invertedBinds[sourceID] then
                                invertedBinds[sourceID] = {}
                            end

                            local bindEntry = {bi.ID, bindName, bindValue}
                            table.insert(invertedBinds[sourceID], bindEntry)
                        end
                    end
                end
            end
            converted[blockName] = arr
        end
    end

    for sourceID, bindList in pairs(invertedBinds) do
        local key = idToKey[sourceID]
        if key then
            local arr = converted[key.blockName]
            if arr and arr[key.idx] then
                arr[key.idx].BindTable = bindList
            end
        end
    end

    return converted
end

local function loadBuildFromFile(fileName)
    ensureFolder()
    local json
    local searchPaths = {FOLDER_PREFIX, FOLDER_PATH .. "/", ""}
    for _, root in ipairs(searchPaths) do
        local paths = {
            root .. fileName .. ".Build",
            root .. fileName .. ".build",
            root .. fileName .. ".json",
            root .. fileName .. ".bh",
            root .. fileName .. ".BH",
            root .. fileName .. ".txt",
            root .. fileName,
        }
        for _, p in ipairs(paths) do
            if isfile(p) then json = readfile(p) ; break end
        end
        if json then break end
    end
    if not json then return nil, nil end

    json = json:match("^%s*(.-)%s*$") or json
    if json:byte(1) == 0xEF and json:byte(2) == 0xBB and json:byte(3) == 0xBF then
        json = json:sub(4)
    end

    if json:find("BuilderHub") or json:find("%[Build%]") then
        local buildLine = json:match("Build%s*=%s*(%b{})")
        if buildLine then
            local okB, decB = pcall(function() return HttpService:JSONDecode(buildLine) end)
            if okB and decB and decB.b and type(decB.b) == "table" then
                local dataObj = decB.b
                for bn, blist in pairs(dataObj) do
                    if type(blist) == "table" then
                        for _, b in ipairs(blist) do
                            if type(b) == "table" then
                                if b.p then b.Position = b.p end
                                if b.r then b.Rotation = b.r end
                                if b.cl then b.Color = b.cl end
                                if b.sz then b.Size = b.sz end
                                if b.a ~= nil then b.Anchored = b.a end
                                if b.cc ~= nil then b.CanCollide = b.cc end
                                if b.ss ~= nil then b.ShowShadow = b.ss end
                                if b.i then b.ID = b.i end
                                if b.nv then b.NumberValues = b.nv end
                                if b.bd then b.BindTable = b.bd end
                            end
                        end
                    end
                end
                return dataObj, "Asu"
            end
        end
    end

    local ok, dec = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or not dec then
        local compacted = json:gsub("\r\n", " "):gsub("\n", " "):gsub("\r", " "):gsub("%s+", " ")
        ok, dec = pcall(function() return HttpService:JSONDecode(compacted) end)
    end
    if not ok or not dec then return nil, nil end

    if type(dec) == "table" and dec.Data and type(dec.Data) == "table" and not dec.format then
        local inner = dec.Data
        for _, v in pairs(inner) do
            if type(v) == "table" and #v > 0 and type(v[1]) == "table" then
                local fb = v[1]
                if fb.CFrame and (type(fb.CFrame) == "table" or type(fb.CFrame) == "string") then
                    return convertMcLaren(inner), "BH"
                end
            end
        end
    end
    if type(dec) == "table" and #dec >= 2 then
        local cats, dataObj = dec[1], dec[2]
        if type(cats) == "table" and type(dataObj) == "table" then
            for _, blocks in pairs(dataObj) do
                if type(blocks) == "table" and #blocks > 0 then
                    local fb = blocks[1]
                    if type(fb) == "table" and (fb.Position or fb.position) then
                        return dataObj, "Asu"
                    end
                end
            end
        end
    end
    if dec.format and dec.data then
        if dec.format == "Asu" then
            return dec.data, "Asu"
        end
        return dec.data, dec.format
    end

    if type(dec) == "table" and dec.b and type(dec.b) == "table" and dec.t then
        local dataObj = dec.b
        for _, blocks in pairs(dataObj) do
            if type(blocks) == "table" and #blocks > 0 then
                local fb = blocks[1]
                if type(fb) == "table" and (fb.p or fb.cl or fb.i) then
                    for bn, blist in pairs(dataObj) do
                        if type(blist) == "table" then
                            for _, b in ipairs(blist) do
                                if type(b) == "table" then
                                    if b.p then b.Position = b.p end
                                    if b.r then b.Rotation = b.r end
                                    if b.cl then b.Color = b.cl end
                                    if b.sz then b.Size = b.sz end
                                    if b.a ~= nil then b.Anchored = b.a end
                                    if b.cc ~= nil then b.CanCollide = b.cc end
                                    if b.ss ~= nil then b.ShowShadow = b.ss end
                                    if b.i then b.ID = b.i end
                                    if b.nv then b.NumberValues = b.nv end
                                    if b.sv then
                                        b.StringValues = b.sv
                                        if b.sv.ActionName then
                                            b.NumberValues = b.NumberValues or {}
                                        end
                                    end
                                    if b.bd then b.BindTable = b.bd end
                                end
                            end
                        end
                    end
                    return dataObj, "Asu"
                end
            end
        end
    end
    if type(dec) == "table" and not dec.format and #dec == 0 then
        local hasBlockData = false
        for _, v in pairs(dec) do
            if type(v) == "table" and #v > 0 and type(v[1]) == "table" then
                hasBlockData = true
                local fb = v[1]

                if fb.CFrame and type(fb.CFrame) == "string" then
                    return dec, "PRS"
                end

                if fb.CFrame and type(fb.CFrame) == "table" then
                    for _, blocks in pairs(dec) do
                        if type(blocks) == "table" then
                            for _, b in ipairs(blocks) do
                                if type(b) == "table" then
                                    if type(b.Size) == "table" then
                                        b.Size = table.concat({b.Size[1], b.Size[2], b.Size[3]}, ", ")
                                    end
                                    if b.MValues and type(b.MValues) == "table" then
                                        local mv_num, mv_bool = {}, {}
                                        for mk, mv in pairs(b.MValues) do
                                            if type(mv) == "boolean" then
                                                mv_bool[mk] = mv
                                            else
                                                mv_num[mk] = mv
                                            end
                                        end
                                        if next(mv_num) then b.NumberValues = mv_num end
                                        if next(mv_bool) then b.BoolValues = mv_bool end
                                    end
                                    if b.Binds then b.BindTable = b.Binds end
                                    if b.CastShadow ~= nil then b.ShowShadow = b.CastShadow end
                                end
                            end
                        end
                    end
                    return dec, "PRS"
                end

                if fb.Position or fb.position or fb.Pos or fb.pos then
                    return dec, "Asu"
                end
            end
        end
        if hasBlockData then
            return dec, "Asu"
        end
    end
    return dec, "PRS"
end

local _buildFilesCache = nil
local _buildFilesCacheTime = 0
local function getSavedBuilds()
    if _buildFilesCache and (tick() - _buildFilesCacheTime) < 300 then
        return _buildFilesCache
    end
    ensureFolder()
    local builds, seen = {}, {}
    local function scanDir(dir, depth)
        if depth > 3 then return end
        local ok, items = pcall(listfiles, dir)
        if not ok or type(items) ~= "table" then return end
        for _, fp in ipairs(items) do
            if isfolder(fp) then
                scanDir(fp, depth + 1)
            else
                local n = fp:match("([^/\\]+)%.Build$") or fp:match("([^/\\]+)%.build$")
                if n and not seen[n:lower()] then
                    table.insert(builds, n)
                    seen[n:lower()] = true
                end
            end
        end
        task.wait()
    end
    scanDir(FOLDER_PATH, 0)
    if isfolder("SOPERA_WORKSPACE") then scanDir("SOPERA_WORKSPACE", 0) end
    table.sort(builds, function(a, b) return a:lower() < b:lower() end)
    _buildFilesCache = builds
    _buildFilesCacheTime = tick()
    return builds
end

local function teleportCharacterTo(pos)
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    hrp.CFrame = CFrame.new(pos)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function touchPart(part)
    local hrp = Character and Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not part then return false end
    if firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            task.wait()
            firetouchinterest(hrp, part, 1)
        end)
        return true
    end
    return false
end

local function equipAllTools()
    local ch = Character or LocalPlayer.Character
    if not ch or not LocalPlayer:FindFirstChild("Backpack") then return end
    local buildToolNames = {"BuildingTool", "PaintingTool", "PropertiesTool", "ScalingTool", "DeleteTool", "TrowelTool", "BindTool"}
    for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local isBuild = false
            for _, bn in ipairs(buildToolNames) do
                if tool.Name == bn then isBuild = true; break end
            end
            if isBuild then
                pcall(function() tool.Parent = ch end)
            end
        end
    end
    task.wait(0.03)
    for _, tool in pairs(ch:GetChildren()) do
        if tool:IsA("Tool") then
            pcall(function() tool:Activate() end)
        end
    end
end

local function setStatus(text)
    if StatusLabelRef then StatusLabelRef.Text = text end
    if MiscStatusLabelRef then MiscStatusLabelRef.Text = text end
end

local function placeBlock(blockName, cframe, relativeTo)
    equipAllTools()
    local ch = Character or LocalPlayer.Character
    local tool = ch and ch:FindFirstChild("BuildingTool")
    if not tool then return false end
    relativeTo = relativeTo or getPlayerZone(LocalPlayer)
    if not relativeTo then return false end
    tool.RF:InvokeServer(
        blockName,
        getBlockID(blockName),
        relativeTo,
        relativeTo.CFrame:ToObjectSpace(cframe),
        true
    )
    return true
end

local function rescaleBlock(block, cf, sz)
    if not block or not block:FindFirstChild("PPart") then return false end
    equipAllTools()
    local ch = Character or LocalPlayer.Character
    local tool = ch and ch:FindFirstChild("ScalingTool")
    if not tool then return false end
    local ok = pcall(function()
        tool.RF:InvokeServer(block, sz, cf)
    end)
    if not ok then
        pcall(function() block.PPart.CFrame = cf end)
        return false
    end
    return true
end

local function paintBlock(block, color)
    if not block or not block:FindFirstChild("PPart") then return false end
    if block.PPart.Color == color then return true end
    equipAllTools()
    local ch = Character or LocalPlayer.Character
    local tool = ch and ch:FindFirstChild("PaintingTool")
    if not tool then return false end
    local ok = pcall(function()
        tool.RF:InvokeServer({block, color})
    end)
    return ok
end

local function moveBlock(block, cf)
    if not block or not block:FindFirstChild("PPart") then return false end
    equipAllTools()
    local ch = Character or LocalPlayer.Character
    local tool = ch and ch:FindFirstChild("ScalingTool")
    if not tool then
        pcall(function() block.PPart.CFrame = cf end)
        return true
    end
    local ok = pcall(function()
        tool.RF:InvokeServer(block, block.PPart.Size, cf)
    end)
    if not ok then
        pcall(function() block.PPart.CFrame = cf end)
    end
    return true
end

local function copyBuild()
    if not selectedPlayer then return nil end
    local playerBlocks = BlocksFolder:FindFirstChild(selectedPlayer.Name)
    if not playerBlocks then return nil end
    local playerZone = getPlayerZone(selectedPlayer)
    if not playerZone then return nil end
    local buildData = {}
    local idCounter = 1
    local idToBlock = {}
    for _, block in pairs(playerBlocks:GetChildren()) do
        if block:FindFirstChild("PPart") then
            local ppart = block.PPart
            local relCF = playerZone.CFrame:ToObjectSpace(ppart.CFrame)
            local isBlock = block.Name:sub(-5) == "Block"
            local realTransp = ppart.Transparency
            if not isBlock then
                for _, desc in pairs(block:GetChildren()) do
                    if (desc:IsA("BasePart") or desc:IsA("UnionOperation")) and desc ~= ppart and desc.Transparency < 1 then
                        realTransp = desc.Transparency
                        break
                    end
                end
            end
            buildData[block.Name] = buildData[block.Name] or {}
            local entry = {
                CFrame = cfStr(relCF),
                Size = v3Str(ppart.Size),
                Col = colStr(ppart.Color),
                Transparency = realTransp,
                Anchored = ppart.Anchored,
                CanCollide = ppart.CanCollide,
                ShowShadow = ppart.CastShadow ~= false,
                ID = idCounter,
            }
            idCounter = idCounter + 1
            local boolVals = {}
            local numVals = {}
            for _, child in pairs(block:GetChildren()) do
                if child:IsA("BoolValue") then
                    boolVals[child.Name] = child.Value
                elseif (child:IsA("NumberValue") or child:IsA("IntValue")) and not child.Name:find("^Bind") then
                    numVals[child.Name] = child.Value
                end
            end
            for _, child in pairs(ppart:GetChildren()) do
                if child:IsA("BoolValue") then
                    boolVals[child.Name] = child.Value
                elseif (child:IsA("NumberValue") or child:IsA("IntValue")) and not child.Name:find("^Bind") then
                    numVals[child.Name] = child.Value
                end
            end
            if block.Name:find("Piston") then
                local fwd = block:GetAttribute("Forward")
                numVals.LastDirection = (fwd == true) and 1 or 0
            end
            if next(boolVals) then entry.BoolValues = boolVals end
            if next(numVals) then entry.NumberValues = numVals end
            table.insert(buildData[block.Name], entry)
            idToBlock[idCounter - 1] = block
        end
    end
    do
        local BKEYS = {"BindFire","BindActivate","BindUp","BindLeft","BindDown","BindRight"}
        local CONTROLLER_NAMES = {
            SwitchBig = true, Button = true, CarSeat = true, Switch = true,
            SensorBlock = true, RemoteController = true, PilotSeat = true,
            Lever = true, Gate = true, Delay = true,
        }
        local tBinds = {}
        for _, blk in pairs(playerBlocks:GetChildren()) do
            if blk:FindFirstChild("PPart") then
                for _, bk in ipairs(BKEYS) do
                    local bv = blk:FindFirstChild(bk)
                    if bv then
                        local keyCode = nil
                        local kc = bv:FindFirstChild("DefaultInputKeyCode")
                        if kc and (kc:IsA("IntValue") or kc:IsA("NumberValue")) then
                            keyCode = kc.Value
                        end
                        local tid = nil
                        if bv:IsA("ObjectValue") and bv.Value then
                            for id2, b2 in pairs(idToBlock) do
                                if b2 == bv.Value then tid = id2 break end
                            end
                        elseif bv:IsA("IntValue") or bv:IsA("NumberValue") then
                            for id2, b2 in pairs(idToBlock) do
                                if b2 == blk then tid = id2 break end
                            end
                        end
                        if tid then
                            tBinds[tid] = tBinds[tid] or {}
                            table.insert(tBinds[tid], {bk, keyCode or bv.Value or -1})
                        end
                    end
                end
            end
        end
        for _, blk in pairs(playerBlocks:GetChildren()) do
            if not blk:FindFirstChild("PPart") then continue end
            if not CONTROLLER_NAMES[blk.Name] then continue end
            local bid = nil
            for id2, b2 in pairs(idToBlock) do if b2 == blk then bid = id2 break end end
            if not bid then continue end
            local bEntry = nil
            for _, ent in ipairs(buildData[blk.Name] or {}) do
                if ent.ID == bid then bEntry = ent break end
            end
            if not bEntry then continue end
            local bSet = {}
            for _, ch in pairs(blk:GetChildren()) do
                if ch:IsA("ObjectValue") and ch.Value then
                    for id2, b2 in pairs(idToBlock) do if b2 == ch.Value then bSet[id2] = true break end end
                end
            end
            local pp2 = blk:FindFirstChild("PPart")
            if pp2 then
                for _, ch in pairs(pp2:GetChildren()) do
                    if ch:IsA("ObjectValue") and ch.Value then
                        for id2, b2 in pairs(idToBlock) do if b2 == ch.Value then bSet[id2] = true break end end
                    end
                end
            end
            local bt = {}
            for tid, bds in pairs(tBinds) do
                if bSet[tid] then
                    for _, bd in ipairs(bds) do table.insert(bt, {tid, bd[1], bd[2]}) end
                end
            end
            local hasT = false
            for _ in pairs(tBinds) do hasT = true break end
            if #bt == 0 and hasT then
                local asgn = {}
                for bn2, _ in pairs(buildData) do
                    for _, e2 in ipairs(buildData[bn2]) do
                        if e2.BindTable then
                            for _, r in ipairs(e2.BindTable) do if r[1] then asgn[r[1]] = true end end
                        end
                    end
                end
                for tid, bds in pairs(tBinds) do
                    if not asgn[tid] then
                        for _, bd in ipairs(bds) do table.insert(bt, {tid, bd[1], bd[2]}) end
                    end
                end
            end
            if #bt > 0 then bEntry.BindTable = bt end
        end
    end
    return buildData
end

local function getBlock(expected, list, used)
    local best, bestDist = nil, math.huge
    local tpos = expected.skyWorldCF.Position
    for _, b in ipairs(list) do
        if b and b.Parent and b:FindFirstChild("PPart") and b.Name == expected.Name and not used[b] then
            local d = (b.PPart.Position - tpos).Magnitude
            if d < bestDist then bestDist = d ; best = b end
        end
    end
    if best then used[best] = true end
    return best
end

local function calcSlots(sz)
    if not sz then return 1 end
    local vol = sz.X * sz.Y * sz.Z
    return math.max(1, math.ceil(vol / 8))
end

local function isRegularBlock(blockName)
    return blockName:sub(-5) == "Block"
end

local function buildDataToFlat(buildData, myZone)
    local regularFlat = {}
    local funcFlat = {}
    local sc = Settings.buildScale
    local off = Vector3.new(Settings.buildOffsetX, Settings.buildOffsetY, Settings.buildOffsetZ)
    local BASE_SKY = Settings.skyHeight or 500

    for blockName, blocks in pairs(buildData) do

        if Settings.excludedBlocks[blockName] then continue end

        local effectiveName = blockName
        if Settings.blockReplacements and Settings.blockReplacements[blockName] then
            effectiveName = Settings.blockReplacements[blockName]
        end
        local regular = isRegularBlock(effectiveName)
        for _, bi in pairs(blocks) do
            local relCF = getBlockCF(bi)
            local pos = (relCF.Position * sc) + off
            local scaledCF = CFrame.new(pos) * (relCF - relCF.Position)
            local worldCF = myZone.CFrame:ToWorldSpace(scaledCF)
            local hasSz = bi.Size ~= nil and bi.Size ~= ""
            local sz = hasSz and (strV3(bi.Size) * sc) or nil
            local hasCo = bi.Col ~= nil and bi.Col ~= ""
            local col = hasCo and strCol(bi.Col) or nil
            local mergedBoolValues, mergedNumberValues = mergePropertyMaps(bi.BoolValues, bi.NumberValues, bi.ASUExtra)
            local entry = {
                Name = effectiveName,
                ID = bi.ID,
                worldCF = worldCF,
                skyWorldCF = nil,
                Relative = myZone,
                Size = sz,
                Col = col,
                hasSz = hasSz,
                hasCo = hasCo,
                isRegular = regular,
                slotCount = regular and calcSlots(sz) or 1,
                Transparency = bi.Transparency,
                Anchored = bi.Anchored,
                CanCollide = bi.CanCollide,
                ShowShadow = bi.ShowShadow,
                BoolValues = mergedBoolValues,
                NumberValues = mergedNumberValues,
                BindTable = bi.BindTable,
                ASUExtra = bi.ASUExtra,
                IsTwoPart = (bi.SecondaryPartPosition ~= nil
                    or (bi.ASUExtra and bi.ASUExtra.SecondaryPartPosition ~= nil)
                    or (bi.SecCFrame ~= nil)
                    or (bi.ASUExtra and bi.ASUExtra.SecCFrame ~= nil)),
                SecondaryWorldCF = nil,
            }
            if entry.IsTwoPart then

                local rawSecCF = bi.SecCFrame or (bi.ASUExtra and bi.ASUExtra.SecCFrame)
                if rawSecCF and type(rawSecCF) == "table" and #rawSecCF >= 12 then

                    local secRelCF = CFrame.new(table.unpack(rawSecCF))
                    local secPos = secRelCF.Position
                    local scaledSecPos = Vector3.new(secPos.X * sc, secPos.Y * sc, secPos.Z * sc) + off
                    local secRotCF = secRelCF - secRelCF.Position
                    local secWorldCF = CFrame.new(scaledSecPos) * secRotCF
                    entry.SecondaryWorldCF = myZone.CFrame:ToWorldSpace(secWorldCF)
                else

                    local rawSecPos = bi.SecondaryPartPosition or (bi.ASUExtra and bi.ASUExtra.SecondaryPartPosition)
                    local secPos = parseNums(rawSecPos)
                    local secPosV = #secPos >= 3 and Vector3.new(secPos[1]*sc, secPos[2]*sc, secPos[3]*sc) + off or Vector3.zero
                    local ppRotCF = relCF - relCF.Position
                    local secCF = CFrame.new(secPosV) * ppRotCF
                    entry.SecondaryWorldCF = myZone.CFrame:ToWorldSpace(secCF)
                end
                entry.SpringProps = {}

                local extra = bi.ASUExtra or {}
                local numV = bi.NumberValues or {}
                local function getProp(k)
                    if bi[k] ~= nil then return bi[k] end
                    if numV[k] ~= nil then return numV[k] end
                    if extra[k] ~= nil then return extra[k] end
                    return nil
                end
                local stiff = getProp("Stiffness")
                if stiff then entry.SpringProps.Stiffness = tostring(stiff) end
                local damp = getProp("Damping")
                if damp then entry.SpringProps.Damping = tostring(damp) end
                local tl = getProp("TargetLength")
                if tl then entry.SpringProps.TargetLength = tostring(tl) end
                local mxl = getProp("MaxLength")
                if mxl then entry.SpringProps.MaxLength = tostring(mxl) end
                local mnl = getProp("MinLength")
                if mnl then entry.SpringProps.MinLength = tostring(mnl) end
                local ln = getProp("Length")
                if ln then entry.SpringProps.Length = tostring(ln) end
                local al = getProp("AngleLimit")
                if al then entry.SpringProps.AngleLimit = tostring(al) end
                local mr = getProp("MatchRotation")
                if mr ~= nil then entry.SpringProps.MatchRotation = mr end
                local sc2 = getProp("ShowConstraint")
                if sc2 ~= nil then entry.SpringProps.ShowConstraint = sc2 end
            end
            if regular then
                regularFlat[#regularFlat+1] = entry
            else
                entry.skyWorldCF = worldCF
                funcFlat[#funcFlat+1] = entry
            end
        end
    end

    local AREA = 25
    local HALF = AREA / 2
    local SPACING = 3
    local COLS = math.floor(AREA / SPACING)
    local PER_LAYER = COLS * COLS
    local cx = myZone.Position.X
    local cz = myZone.Position.Z
    local startY = myZone.Position.Y + 20
    for i, v in ipairs(regularFlat) do
        local idx = i - 1
        local layer = math.floor(idx / PER_LAYER)
        local inLayer = idx % PER_LAYER
        local col = inLayer % COLS
        local row = math.floor(inLayer / COLS)
        local x = cx - HALF + col * SPACING + math.random(0, 1)
        local z = cz - HALF + row * SPACING + math.random(0, 1)
        local y = startY + layer * SPACING
        v.skyWorldCF = CFrame.new(x, y, z) * (v.worldCF - v.worldCF.Position)
    end

    local flat = {}
    for _, v in ipairs(regularFlat) do flat[#flat+1] = v end
    for _, v in ipairs(funcFlat) do flat[#flat+1] = v end
    return flat
end

local function saveToSlot(slot)
    local Event = workspace:FindFirstChild("SaveBoatData")
    if not Event then setStatus("SaveBoatData not found!") ; return false end
    local ok = pcall(function()
        Event:InvokeServer(slot)
    end)
    task.wait(2)
    return ok
end

local function loadFromSlot(slot)
    local Event = workspace:FindFirstChild("LoadBoatData")
    if not Event then setStatus("LoadBoatData not found!") ; return false end
    pcall(function()
        Event:FireServer(slot, 0)
    end)
    task.wait(3)
    return true
end

local function tryInfMerge(slot1, slot2, expectedMinCount, statusCb)
    local folder = BlocksFolder:FindFirstChild(LocalPlayer.Name)
    local beforeCount = folder and #folder:GetChildren() or 0
    local function waitForMergeLoad(minCount, timeoutSec)
        local deadline = tick() + (timeoutSec or 8)
        local lastCount = beforeCount
        local stableFor = 0
        while tick() < deadline and not stopBuild do
            task.wait(0.15)
            local nowCount = folder and #folder:GetChildren() or 0
            if nowCount ~= lastCount then
                lastCount = nowCount
                stableFor = 0
            else
                stableFor = stableFor + 0.15
            end
            if nowCount >= minCount and stableFor >= 0.45 then
                return nowCount
            end
        end
        return folder and #folder:GetChildren() or 0
    end
    for attempt = 1, 5 do
        if stopBuild then return false, "stopped" end
        if statusCb then
            statusCb("INF merge try " .. attempt .. "/5")
        end
        pcall(function() workspace.LoadBoatData:FireServer(slot1, 0) end)
        local slot1Count = waitForMergeLoad(math.max(1, math.floor((expectedMinCount or beforeCount) * 0.35)), 5 + attempt)
        if statusCb then
            statusCb("INF base loaded " .. slot1Count)
        end
        task.wait(0.35 + attempt * 0.1)
        pcall(function() workspace.LoadBoatData:FireServer(slot2, 0) end)
        local loadedCount = waitForMergeLoad(math.max(beforeCount + 1, math.floor((expectedMinCount or 0) * 0.75)), 8 + attempt)
        if statusCb then
            statusCb("INF loaded " .. loadedCount .. " blocks, saving merge")
        end
        pcall(function()
            workspace.SaveBoatData:InvokeServer(slot1)
        end)
        task.wait(1)
        local nowCount = folder and #folder:GetChildren() or 0
        if nowCount >= math.max(beforeCount + 1, math.floor((expectedMinCount or 0) * 0.7)) then
            return true, attempt
        end
    end
    return false, "high ping or merge failed"
end

local BLOCKED_PROPS = {Health=true, LastGlobalTick=true, Anchored=true}

local function applyNumberValues(b, numVals, propRF)
    if not numVals or not b or type(numVals) ~= "table" then return end
    for propName, propVal in pairs(numVals) do
        if BLOCKED_PROPS[propName] then continue end
        local remotePropName = propName
        if b.Name == "Piston" and propName == "ExtendLength" then
            remotePropName = "Piston length"
        elseif b.Name == "Piston" and propName == "Speed" then
            remotePropName = "Piston speed"
        elseif b.Name == "Piston" and propName == "LastDirection" then
            remotePropName = "Piston direction"
        elseif b.Name == "Servo" and propName == "Angle" then
            remotePropName = "Servo angle"
        elseif b.Name == "Servo" and propName == "Speed" then
            remotePropName = "Servo speed"
        elseif b.Name == "JetTurbine" and propName == "Speed" then
            remotePropName = "Jet speed"
        elseif b.Name == "JetTurbine" and (propName == "Force" or propName == "JetForce" or propName == "MaxForce") then
            remotePropName = "Jet force"
        elseif b.Name == "Motor" and propName == "MaxSpeed" then
            remotePropName = "Max speed"
        elseif b.Name == "Motor" and propName == "WheelTorque" then
            remotePropName = "Wheel torque"
        elseif b.Name == "Motor" and propName == "ReverseSpin" then
            remotePropName = "Reverse spin"
        end
        local numericVal = tonumber(propVal)
        if numericVal == nil and type(propVal) == "boolean" then
            numericVal = propVal and 1 or 0
        end
        if numericVal == nil then numericVal = 0 end
        pcall(function()
            for _, target in ipairs({b, b.PPart}) do
                if target then
                    local pv = target:FindFirstChild(propName) or target:FindFirstChild(propName, true)
                    if not pv and remotePropName ~= propName then
                        pv = target:FindFirstChild(remotePropName) or target:FindFirstChild(remotePropName, true)
                    end
                    if pv then
                        if pv:IsA("NumberValue") or pv:IsA("IntValue") then
                            pv.Value = numericVal
                        elseif pv:IsA("BoolValue") then
                            pv.Value = numericVal ~= 0
                        end
                    end
                end
            end
        end)
        if propRF then
            task.spawn(function() pcall(function() propRF:InvokeServer(remotePropName, {b}, tostring(numericVal)) end) end)
        end
    end
end

local PROP_TIMEOUT = 0.5
local function invokeWithTimeout(rf, args, timeout)
    if not rf then return false end
    local done = false
    local ok = false
    task.spawn(function()
        ok = pcall(function() rf:InvokeServer(unpack(args)) end)
        done = true
    end)
    local t0 = tick()
    while not done and tick() - t0 < (timeout or PROP_TIMEOUT) do
        task.wait(0.05)
        if stopBuild then return false end
    end
    return ok
end

local function firePropertyRF(propRF, ...)
    if not propRF then return false end
    local args = {...}
    task.spawn(function() pcall(function() propRF:InvokeServer(unpack(args)) end) end)
    return true
end

local function activateButtonBlock(buttonBlock, pistonBlock)
    if not buttonBlock then return false end
    local inputLocalScript = ReplicatedStorage:FindFirstChild("InputLocalScript")
    if not inputLocalScript then return false end
    local queueRF = inputLocalScript:FindFirstChild("QueueBlocksRequest")
    if not queueRF then return false end
    local currentChar = LocalPlayer.Character or Character
    if not currentChar then return false end
    local args = {
        {
            pistonBlock or buttonBlock,
            true,
            false,
            buttonBlock,
            currentChar,
            true,
            false,
            true,
            true,
            false
        }
    }
    return pcall(function()
        queueRF:FireServer(args)
    end)
end

local function activatePistonViaQueue(pistonBlock, buttonBlock)
    if not pistonBlock then return false end
    local currentChar = LocalPlayer.Character or Character
    if not currentChar then return false end
    local inputLocalScript = ReplicatedStorage:FindFirstChild("InputLocalScript")
    if not inputLocalScript then return false end
    local queueRF = inputLocalScript:FindFirstChild("QueueBlocksRequest")
    if not queueRF then return false end
    local args = {
        {
            pistonBlock,
            true,
            false,
            buttonBlock or false,
            currentChar,
            true,
            false,
            true,
            true,
            false
        }
    }
    return pcall(function()
        queueRF:FireServer(args)
    end)
end

local function getPropertiesRF()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local propTool = (Character and Character:FindFirstChild("PropertiesTool")) or (backpack and backpack:FindFirstChild("PropertiesTool"))
    if not propTool then
        equipAllTools()
        propTool = (Character and Character:FindFirstChild("PropertiesTool")) or (backpack and backpack:FindFirstChild("PropertiesTool"))
    end
    return propTool and propTool:FindFirstChild("SetPropertieRF")
end

local function getEntrySizeVector(v)
    if not v then return nil end
    local raw = v.Size or v.size
    if typeof(raw) == "Vector3" then return raw end
    if type(raw) == "table" then
        return Vector3.new(tonumber(raw[1]) or 0, tonumber(raw[2]) or 0, tonumber(raw[3]) or 0)
    end
    if type(raw) == "string" then
        local nums = parseNums(raw)
        if #nums >= 3 then return Vector3.new(nums[1], nums[2], nums[3]) end
    end
    return nil
end

local function shouldLegacySwitch(entry)
    if not entry or not entry.block or not entry.v or entry.block.Name ~= "Switch" then return false end
    local bv = entry.v.BoolValues
    if bv and bv.Legacy == false then return false end
    return true
end

local function applyLegacySwitches(styledList, propRF)
    propRF = propRF or getPropertiesRF()
    if not propRF then return 0 end
    local targets = {}
    for _, entry in ipairs(styledList or {}) do
        if shouldLegacySwitch(entry) then
            targets[#targets + 1] = entry.block
        end
    end
    if #targets == 0 then return 0 end
    for i = 1, #targets, 40 do
        local chunk = {}
        for j = i, math.min(i + 39, #targets) do chunk[#chunk + 1] = targets[j] end
        pcall(function() propRF:InvokeServer("Legacy", chunk) end)
        task.wait(0.05)
    end
    return #targets
end

local function applyBoolValues(b, boolVals, propRF)
    if not boolVals or not b or type(boolVals) ~= "table" then return end
    for propName, propVal in pairs(boolVals) do
        if BLOCKED_PROPS[propName] then continue end
        local desired = propVal == true
        local currentValue = nil
        pcall(function()
            for _, target in ipairs({b, b.PPart}) do
                if target then
                    local pv = target:FindFirstChild(propName) or target:FindFirstChild(propName, true)
                    if pv and pv:IsA("BoolValue") then
                        if currentValue == nil then currentValue = pv.Value end
                    end
                end
            end
        end)
        local needToggle = false
        if currentValue == nil then
            needToggle = desired
        else
            needToggle = currentValue ~= desired
        end
        if propRF and needToggle then
            firePropertyRF(propRF, propName, {b})
        end
    end
end

local TRANSPARENCY_STEPS = {0, 0.25, 0.5, 0.75, 1}

local function getTransparencyStepIndex(value)
    local bestIndex = 1
    local bestDiff = math.huge
    for i, stepValue in ipairs(TRANSPARENCY_STEPS) do
        local diff = math.abs((tonumber(value) or 0) - stepValue)
        if diff < bestDiff then
            bestDiff = diff
            bestIndex = i
        end
    end
    return bestIndex
end

local function setBlockProperties(b, v, propRF, skipTransp)
    if not b or not b:FindFirstChild("PPart") then return end
    if not propRF then
        equipAllTools()
        local propTool = Character:FindFirstChild("PropertiesTool")
        propRF = propTool and propTool:FindFirstChild("SetPropertieRF")
        if not propRF then return end
    end
    if v.Transparency ~= nil and not skipTransp then
        local transparency = tonumber(v.Transparency)
        if transparency then
            transparency = math.clamp(transparency, 0, 1)
            if propRF then
                firePropertyRF(propRF, "Transparency", {b}, tostring(math.floor(transparency * 100 + 0.5)))
            end
        end
    end
    if v.CanCollide ~= nil and not isSpecialPropBlock(b.Name) then
        if propRF and b.PPart.CanCollide ~= (v.CanCollide == true) then firePropertyRF(propRF, "Collision", {b}) end
    end

    if v.ShowShadow ~= nil then
        if propRF and b.PPart.CastShadow ~= (v.ShowShadow == true) then firePropertyRF(propRF, "Cast shadow", {b}) end
    end
    applyBoolValues(b, v.BoolValues, propRF)
    applyNumberValues(b, v.NumberValues, propRF)
end


local function isSpecialPropBlock(name)
    return name == "Piston" or name == "Hinge" or name == "Bar" or name == "Rope" or name == "Spring"
end


local function isMoveWeldBlock(name)
    return name == "Piston" or name == "Hinge"
end


local function isRotateConstraintBlock(name)
    return name == "Bar" or name == "Rope" or name == "Spring"
end

local function pasteBuild(buildData, statusCb)
    if not buildData or isBuilding then return false end
    isBuilding = true
    stopBuild = false

    local teamLeaderName = nil
    local isTeamLeader = false
    pcall(function()
        local myTeam = LocalPlayer.Team
        if myTeam then
            local tlObj = myTeam:FindFirstChild("TeamLeader")
            if tlObj then
                teamLeaderName = tlObj.Value and tostring(tlObj.Value) or tostring(tlObj.Value)
                if not teamLeaderName or teamLeaderName == "" then
                    pcall(function()
                        teamLeaderName = tlObj.Value.Name
                    end)
                end
                isTeamLeader = (teamLeaderName == LocalPlayer.Name)
            end
        end
    end)
    shareBlocksOriginal = false
    pcall(function()
        local settingsFolder = LocalPlayer:FindFirstChild("Settings")
        if settingsFolder then
            local sbVal = settingsFolder:FindFirstChild("ShareBlocks")
            if sbVal then
                shareBlocksOriginal = (sbVal.Value == true)
            end
        end
    end)
    local shareBlocks = shareBlocksOriginal
    pcall(function()
        local settingsFolder = LocalPlayer:FindFirstChild("Settings")
        if settingsFolder then
            local sbVal = settingsFolder:FindFirstChild("ShareBlocks")
            if sbVal then
                shareBlocks = (sbVal.Value == true)
            end
        end
    end)
    if isTeamLeader and not shareBlocks then
        shareBlocks = true
        pcall(function()
            local settingsFolder = LocalPlayer:FindFirstChild("Settings")
            if not settingsFolder then
                settingsFolder = Instance.new("Folder")
                settingsFolder.Name = "Settings"
                settingsFolder.Parent = LocalPlayer
            end
            local sbVal = settingsFolder:FindFirstChild("ShareBlocks")
            if not sbVal then
                sbVal = Instance.new("BoolValue")
                sbVal.Name = "ShareBlocks"
                sbVal.Parent = settingsFolder
            end
            sbVal.Value = true
        end)
    end
    local buildTargetName = LocalPlayer.Name
    if not isTeamLeader and shareBlocks and teamLeaderName then
        buildTargetName = teamLeaderName
    end

    buildStartTime = tick()

    local myZone = getPlayerZone(LocalPlayer)
    if not myZone then isBuilding = false ; return false end

    local flat = buildDataToFlat(buildData, myZone)
    local total = #flat
    buildTotalBlocks = total
    if total == 0 then isBuilding = false ; return false end

    local folder = BlocksFolder:FindFirstChild(buildTargetName)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = buildTargetName
        folder.Parent = BlocksFolder
    end

    equipAllTools()
    local placeTool = Character:FindFirstChild("BuildingTool")
    local scaleTool = Character:FindFirstChild("ScalingTool")
    local paintTool = Character:FindFirstChild("PaintingTool")
    local deleteTool = Character:FindFirstChild("DeleteTool") or Character:FindFirstChild("DeletingTool")
    local bindTool = Character:FindFirstChild("BindTool")

    local function updProg(msg, pct)
        if statusCb then statusCb(msg, pct) end
        local safePct = math.clamp(tonumber(pct) or 0, 0, 100)
        local pctInt = math.floor(safePct + 0.5)
        if StatusLabelRef then
            StatusLabelRef.Text = "  " .. tostring(msg or "")
        end
        if ProgressBarFillRef then
            TweenService:Create(ProgressBarFillRef, TweenInfo.new(0.12), {Size = UDim2.new(safePct / 100, 0, 1, 0)}):Play()
        end
        if DupePercentLabelRef then
            DupePercentLabelRef.Text = pctInt .. "%"
        end
        if DupeInfoLabelRef then
            local remaining = math.max(0, math.floor(buildTotalBlocks * (100 - safePct) / 100))
            local elapsed = buildStartTime > 0 and (tick() - buildStartTime) or 0
            local etaStr = ""
            if safePct > 2 and elapsed > 1 then
                local totalEst = elapsed / (safePct / 100)
                local eta = math.max(0, totalEst - elapsed)
                if eta >= 60 then
                    etaStr = string.format(" | ETA %dm %ds", math.floor(eta/60), math.floor(eta % 60))
                else
                    etaStr = string.format(" | ETA %ds", math.floor(eta))
                end
            end
            DupeInfoLabelRef.Text = "  " .. tostring(msg or "") .. "  |  " .. remaining .. " left" .. etaStr
        end
        if InfProgressLabelRef and InfProgressFillRef then
            local isInf = tostring(msg or ""):sub(1, 3) == "INF"
            InfProgressLabelRef.Visible = isInf
            InfProgressFillRef.Parent.Visible = isInf
            if isInf then
                InfProgressLabelRef.Text = string.format("INF %d%%", pctInt)
                TweenService:Create(InfProgressFillRef, TweenInfo.new(0.08), {Size = UDim2.new(safePct / 100, 0, 1, 0)}):Play()
            end
        end
    end

    local function waitForN(minN, maxWait)
        local t0 = tick()
        local lastN, sameFor = 0, 0
        local stableNeed = minN > 200 and 0.4 or 0.6
        repeat
            task.wait(0.15)
            local n = #folder:GetChildren()
            if n == lastN then sameFor = sameFor + 0.15 else sameFor = 0 end
            lastN = n
        until (lastN >= minN and sameFor >= stableNeed) or tick()-t0 > maxWait or stopBuild
        return lastN
    end

    local function findNearest(name, skyPos, list, used)
        local best, bestD = nil, math.huge
        for _, b in ipairs(list) do
            if b and b.Parent and not used[b] and b.Name == name then
                local ppart = b:FindFirstChild("PPart")
                if ppart and ppart.Parent then
                    local d = (ppart.Position - skyPos).Magnitude
                    if d < bestD then bestD = d ; best = b end
                end
            end
        end
        if best then used[best] = true end
        return best
    end

    local placeRF = placeTool and placeTool:FindFirstChild("RF")
    local scaleRF = scaleTool and scaleTool:FindFirstChild("RF")

    local function forceAnchorBlocks(baseList)
        if not propertiesRF then return end
        local needAnchor = {}
        for _, b in ipairs(baseList) do
            if b and b:FindFirstChild("PPart") and not b.PPart.Anchored then
                needAnchor[#needAnchor+1] = b
            end
        end
        if #needAnchor > 0 then
            local batchSize = 50
            for i = 1, #needAnchor, batchSize do
                local batch = {}
                for j = i, math.min(i + batchSize - 1, #needAnchor) do
                    batch[#batch+1] = needAnchor[j]
                end
                pcall(function() propertiesRF:InvokeServer("Anchored", batch) end)
                if i + batchSize <= #needAnchor then task.wait(0.03) end
            end
        end
    end
    local paintRF = (paintTool and paintTool:FindFirstChild("RF"))
        or (LocalPlayer.Backpack:FindFirstChild("PaintingTool") and LocalPlayer.Backpack.PaintingTool:FindFirstChild("RF"))
    local deleteRF = deleteTool and deleteTool:FindFirstChild("RF")
    local propertiesTool = Character:FindFirstChild("PropertiesTool")
    local propertiesRF = propertiesTool and propertiesTool:FindFirstChild("SetPropertieRF")
    local bindRF = bindTool and bindTool:FindFirstChild("RF")
    local placedById = {}

    local function fireScale(b, sz, cf)
        if not scaleRF or not b then return end
        task.spawn(function()
            pcall(function() scaleRF:InvokeServer(b, sz, cf) end)
        end)
    end

    local function fastPlace(v)
        if not placeRF then return end
        task.spawn(function()
            pcall(function()
                if v.IsTwoPart and v.SecondaryWorldCF then
                    placeRF:InvokeServer(
                        v.Name, getBlockID(v.Name), v.Relative,
                        v.Relative.CFrame:ToObjectSpace(v.skyWorldCF),
                        true,
                        v.SecondaryWorldCF,
                        v.skyWorldCF
                    )
                else
                    placeRF:InvokeServer(
                        v.Name, getBlockID(v.Name), v.Relative,
                        v.Relative.CFrame:ToObjectSpace(v.skyWorldCF),
                        true
                    )
                end
            end)
        end)
    end

    local function fastRescale(b, cf, sz)
        if not b or not b:FindFirstChild("PPart") then return false end
        pcall(function()
            b.PPart.Size = sz
            b.PPart.CFrame = cf
        end)
        if scaleRF then
            fireScale(b, sz, cf)
            return true
        end
        return false
    end

    local function batchPaintSync(pairs_list)
        if not paintRF or #pairs_list == 0 then return end
        task.spawn(function()
            pcall(function() paintRF:InvokeServer(pairs_list) end)
            task.wait(0.5)
            for _, pair in ipairs(pairs_list) do
                local b = pair[1]
                local col = pair[2]
                if b and b.Parent and col then
                    local c3 = strCol(tostring(col))
                    pcall(function()
                        for _, desc in ipairs(b:GetDescendants()) do
                            if desc:IsA("Decal") then
                                desc.Color3 = c3
                            end
                        end
                    end)
                end
            end
        end)
    end

    local function fastMove(b, cf)
        if not b or not b:FindFirstChild("PPart") then return end
        pcall(function() b.PPart.CFrame = cf end)
        if scaleRF then
            fireScale(b, b.PPart.Size, cf)
        end
    end

        local PLACE_BATCH = 60
    local STYLE_BATCH = 90
    local MOVE_BATCH = 90

    local function runPlacePhase(subset, label, p0, p1)
            local BATCH = 60
            local delayTime = Settings.buildSpeed > 0 and Settings.buildSpeed * 0.01 or 0
            for i = 1, #subset do
                    if stopBuild then break end
                    fastPlace(subset[i])

                    if delayTime > 0 and i % BATCH == 0 then
                        task.wait(delayTime)
                    end
            end
            updProg(label .. #subset .. " placed", p1)
    end

    local function runStylePhase(subset, baseList, used, p0, p1)
                local regularStyled = {}
                local funcStyled = {}
                local paintQueue = {}
                local unmatched = {}

                local nameGroups = {}
                for _, blk in ipairs(baseList) do
                        if blk and blk.Parent and blk.Name then
                                nameGroups[blk.Name] = nameGroups[blk.Name] or {}
                                table.insert(nameGroups[blk.Name], blk)
                        end
                end
                local nameIdx = {}

                for i = 1, #subset do
                        if stopBuild then break end
                        local v = subset[i]
                        local b = nil

                        nameIdx[v.Name] = (nameIdx[v.Name] or 0) + 1
                        local group = nameGroups[v.Name]
                        if group then
                                for j = nameIdx[v.Name], #group do
                                        local candidate = group[j]
                                        if candidate and candidate.Parent and not used[candidate] and candidate:FindFirstChild("PPart") then
                                                b = candidate
                                                used[b] = true
                                                nameIdx[v.Name] = j
                                                break
                                        end
                                end
                        end

                        if not b then
                                b = findNearest(v.Name, v.skyWorldCF.Position, baseList, used)
                        end
                        if b and b:FindFirstChild("PPart") then
                                if v.ID ~= nil then
                                        placedById[v.ID] = b
                                        placedById[tostring(v.ID)] = b
                                end
                                if v.isRegular then
                                        if v.hasCo and v.Col then
                                                paintQueue[#paintQueue+1] = {b, v.Col}
                                        end
                                        if v.hasSz and v.Size then
                                                fastRescale(b, v.skyWorldCF, v.Size)
                                                regularStyled[#regularStyled+1] = {block=b, worldCF=v.worldCF, v=v}
                                        else
                                                pcall(function() b.PPart.CFrame = v.skyWorldCF end)
                                                regularStyled[#regularStyled+1] = {block=b, worldCF=v.worldCF, v=v}
                                        end
                                else
                                        funcStyled[#funcStyled+1] = {block=b, worldCF=v.worldCF, v=v}
                                end
                        else
                                unmatched[#unmatched+1] = v
                        end
                end

                if #unmatched > 0 then
                        updProg("Retrying " .. #unmatched .. " unmatched blocks...", p0 + 60)
                        task.wait(1.5)
                        local refreshedBase = folder:GetChildren()
                        local refreshedGroups = {}
                        for _, blk in ipairs(refreshedBase) do
                                if blk and blk.Parent and blk.Name and not used[blk] then
                                        refreshedGroups[blk.Name] = refreshedGroups[blk.Name] or {}
                                        table.insert(refreshedGroups[blk.Name], blk)
                                end
                        end
                        for _, v in ipairs(unmatched) do
                                if stopBuild then break end
                                local b = nil
                                local grp = refreshedGroups[v.Name]
                                if grp then
                                        for j = 1, #grp do
                                                local candidate = grp[j]
                                                if candidate and candidate.Parent and not used[candidate] and candidate:FindFirstChild("PPart") then
                                                        b = candidate
                                                        used[b] = true
                                                        break
                                                end
                                        end
                                end
                                if not b then
                                        b = findNearest(v.Name, v.skyWorldCF and v.skyWorldCF.Position or v.worldCF.Position, refreshedBase, used)
                                end
                                if b and b:FindFirstChild("PPart") then
                                        used[b] = true
                                        if v.ID ~= nil then
                                                placedById[v.ID] = b
                                                placedById[tostring(v.ID)] = b
                                        end
                                        if v.isRegular then
                                                if v.hasCo and v.Col then
                                                        paintQueue[#paintQueue+1] = {b, v.Col}
                                                end
                                                if v.hasSz and v.Size then
                                                        fastRescale(b, v.skyWorldCF, v.Size)
                                                        regularStyled[#regularStyled+1] = {block=b, worldCF=v.worldCF, v=v}
                                                else
                                                        pcall(function() b.PPart.CFrame = v.skyWorldCF end)
                                                        regularStyled[#regularStyled+1] = {block=b, worldCF=v.worldCF, v=v}
                                                end
                                        else
                                                funcStyled[#funcStyled+1] = {block=b, worldCF=v.worldCF, v=v}
                                        end
                                end
                        end
                end

                updProg("Painting " .. #paintQueue .. " blocks...", p0 + 70)
                if #paintQueue > 0 then
                        batchPaintSync(paintQueue)
                end

                local allStyled = {}
                for _, e in ipairs(regularStyled) do allStyled[#allStyled+1] = e end
                for _, e in ipairs(funcStyled) do allStyled[#allStyled+1] = e end

                return allStyled
        end

    local function applyBindTables(styledList, p0, p1)

        if not bindTool or not bindTool.Parent then
            bindTool = Character:FindFirstChild("BindTool") or LocalPlayer.Backpack:FindFirstChild("BindTool")
            if bindTool and bindTool.Parent ~= Character then bindTool.Parent = Character ; task.wait(0.05) end
            bindRF = bindTool and bindTool:FindFirstChild("RF")
        end
        if not bindRF then updProg("No BindTool RF, skipping binds", p0) return end
        local unbindRF = bindTool and bindTool:FindFirstChild("UnbindRF")
        local hasAnyBinds = false
        for _, e in ipairs(styledList) do
            if e.v and type(e.v.BindTable) == "table" then
                local bt = e.v.BindTable
                local cnt = 0
                for _ in pairs(bt) do cnt = cnt + 1 end
                if cnt > 0 then hasAnyBinds = true break end
            end
        end
        if not hasAnyBinds then return end
        do
            local unbound = {}
            for _, entry in ipairs(styledList) do
                if stopBuild then break end
                local bt = entry.v and entry.v.BindTable
                if type(bt) == "table" then
                    local sb = entry.block
                    if sb and unbindRF and not unbound[sb] then
                        unbound[sb] = true
                        invokeWithTimeout(unbindRF, {{sb}})
                    end
                end
            end
        end
        local done = 0
        local total = 0
        for _, entry in ipairs(styledList) do
            local bt = entry.v and entry.v.BindTable
            if type(bt) == "table" then
                for _ in pairs(bt) do total = total + 1 end
            end
        end
        for i, entry in ipairs(styledList) do
            if stopBuild then break end
            local bindTable = entry.v and entry.v.BindTable
            if type(bindTable) ~= "table" then continue end
            local seatBlock = entry.block
            if not seatBlock then continue end

            local isSwitchType = seatBlock.Name:find("Switch") ~= nil
                or seatBlock.Name:find("Delay") ~= nil
                or seatBlock.Name:find("Sensor") ~= nil
            local actionMap = {}
            for _, bindRow in pairs(bindTable) do
                if type(bindRow) ~= "table" then continue end
                local targetBlock = placedById[bindRow[1]] or placedById[tostring(bindRow[1])]
                local bindName = bindRow[2]
                local bindValue = tonumber(bindRow[3]) or bindRow[3]
                if not targetBlock or not bindName then continue end
                local bindObject = targetBlock:FindFirstChild(bindName) or targetBlock:FindFirstChild(bindName, true)
                if not bindObject then

                    pcall(function() bindObject = targetBlock:WaitForChild(bindName, 3) end)
                    if not bindObject then
                        pcall(function() bindObject = targetBlock:FindFirstChild(bindName, true) end)
                    end
                end
                if not bindObject then continue end

                local actionName
                if bindName == "BindUp" then
                    actionName = "Push"
                elseif bindName == "BindDown" then
                    actionName = "Pull"
                elseif bindName == "BindFire" or bindName == "BindActivate" then
                    actionName = "Activate"
                else
                    actionName = bindName:gsub("^Bind", "")
                end
                if not actionMap[actionName] then
                    actionMap[actionName] = {objs = {}, keys = {}}
                end
                table.insert(actionMap[actionName].objs, bindObject)
                table.insert(actionMap[actionName].keys, bindValue)
                done = done + 1
            end
            for actName, group in pairs(actionMap) do
                local firstArg = {[actName] = group.objs}
                local keyVal = #group.keys == 1 and group.keys[1] or group.keys

                local thirdArg = isSwitchType and {} or {[actName] = keyVal}
                if isSwitchType then

                    task.spawn(function()
                        pcall(function() bindRF:InvokeServer(firstArg, seatBlock, thirdArg, false) end)
                    end)
                else
                    invokeWithTimeout(bindRF, {firstArg, seatBlock, thirdArg, false})
                end
            end
            if i % 5 == 0 then task.wait() end
        end
        if done > 0 then updProg("Bound " .. done .. " controls", p1) end
    end

    local function applyPropertiesPhase(styledList, p0, p1, skipTransp)
        if not propertiesRF then updProg("No PropertiesTool RF, skipping props", p0) return end

        task.wait(0.05)

        local pbTotal = 0
        for _, entry in ipairs(styledList) do
            if not entry.block or not entry.v then continue end
            local v = entry.v
            local isSwitch = entry.block.Name == "Switch"
            if isSwitch or (v.NumberValues and next(v.NumberValues)) or (v.BoolValues and next(v.BoolValues)) or (v.SpringProps and next(v.SpringProps)) then
                pbTotal = pbTotal + 1
            end
        end
        local pbDone = 0
        local numValBatch = {}
        for _, entry in ipairs(styledList) do
            if stopBuild then break end
            if not entry.block or not entry.v then continue end
            local v = entry.v
            local b = entry.block
            if b.Name == "Switch" and shouldLegacySwitch(entry) then
                v.BoolValues = v.BoolValues or {}
                if v.BoolValues.Legacy == nil then
                    v.BoolValues.Legacy = true
                end
            end

            if not ((v.NumberValues and next(v.NumberValues)) or (v.BoolValues and next(v.BoolValues)) or (v.SpringProps and next(v.SpringProps))) then continue end
            applyBoolValues(b, v.BoolValues, propertiesRF)
            applyNumberValues(b, v.NumberValues, propertiesRF)
            if v.SpringProps and next(v.SpringProps) then
                local sp = v.SpringProps
                if sp.Stiffness then firePropertyRF(propertiesRF, "Stiffness", {b}, sp.Stiffness) end
                if sp.Damping then firePropertyRF(propertiesRF, "Damping", {b}, sp.Damping) end
                if sp.TargetLength then firePropertyRF(propertiesRF, "Target length", {b}, sp.TargetLength) end
                if sp.MaxLength then firePropertyRF(propertiesRF, "Max length", {b}, sp.MaxLength) end
                if sp.MinLength then firePropertyRF(propertiesRF, "Min length", {b}, sp.MinLength) end
                if sp.Length then firePropertyRF(propertiesRF, "Length", {b}, sp.Length) end
                if sp.AngleLimit then firePropertyRF(propertiesRF, "Angle limit", {b}, sp.AngleLimit) end
                if sp.MatchRotation then firePropertyRF(propertiesRF, "Match rotation", {b}) end
                if sp.ShowConstraint then firePropertyRF(propertiesRF, "Show constraint", {b}) end
            end
            pbDone = pbDone + 1
            if pbDone % 30 == 0 then task.wait() end
        end
        updProg("Properties done", p1)
    end

    local function runMovePhase(styledList, p0, p1)
            local moveOpRF = nil
            local trowelTool = Character:FindFirstChild("TrowelTool") or LocalPlayer.Backpack:FindFirstChild("TrowelTool")
            if trowelTool then
                    moveOpRF = trowelTool:FindFirstChild("OperationRF")
                    if trowelTool.Parent ~= Character then trowelTool.Parent = Character ; task.wait(0.05) end
            end
            for i, entry in ipairs(styledList) do
                    if stopBuild then break end
                    local b = entry.block
                    if b and b:FindFirstChild("PPart") then
                            local cf = entry.worldCF
                            local isBlock = b.Name:sub(-5) == "Block"
                            pcall(function() b.PPart.CFrame = cf end)
                            if isBlock and scaleRF then
                                    task.spawn(function()
                                            pcall(function() scaleRF:InvokeServer(b, b.PPart.Size, cf) end)
                                    end)
                            elseif not isBlock and moveOpRF then
                                    task.spawn(function()
                                            pcall(function() moveOpRF:InvokeServer({b}, cf, cf, "Move") end)
                                    end)
                            end
                    end
            end
            updProg("Moved " .. #styledList .. " blocks", p1)
    end

    local function deleteBlock(b)
        if not b or not b.Parent then return false end
        local ok = false
        if deleteRF then
            ok = pcall(function() deleteRF:InvokeServer(b) end) or ok
            ok = pcall(function() deleteRF:InvokeServer({b}) end) or ok
            ok = pcall(function() deleteRF:InvokeServer({{b}}) end) or ok
        end
        if not ok then
            pcall(function() b:Destroy() end)
        end
        return true
    end

    local function deletePlacedEntries(entries, p0, p1)
        local baseList = folder:GetChildren()
        local used = {}
        local deleted = 0
        for i, v in ipairs(entries) do
            if stopBuild then break end
            local b = findNearest(v.Name, v.skyWorldCF.Position, baseList, used)
            if b and deleteBlock(b) then
                deleted = deleted + 1
            end
            if i % PLACE_BATCH == 0 then
                task.wait()
                updProg("INF deleting saved blocks " .. i .. "/" .. #entries, p0 + math.floor(i / #entries * (p1 - p0)))
            end
        end
        task.wait(0.15)
        return deleted
    end

    if Settings.infBlockEnabled then
        equipAllTools()
        placeTool = Character:FindFirstChild("BuildingTool")
        scaleTool = Character:FindFirstChild("ScalingTool")
        placeRF = placeTool and placeTool:FindFirstChild("RF")
        scaleRF = scaleTool and scaleTool:FindFirstChild("RF")

        local needed = {}
        for _, v in ipairs(flat) do
            if v.isRegular and isRegularBlock(v.Name) then
                needed[v.Name] = (needed[v.Name] or 0) + (v.slotCount or 1)
            end
        end

        local missingList = {}
        for name, need in pairs(needed) do
            local have = getBlockID(name)
            if have < need then
                local missing = need - have
                missingList[#missingList+1] = {
                    Name = name,
                    Need = need,
                    Missing = missing,
                    ScaleCalls = math.max(1, math.ceil(missing / 4) + 1)
                }
            end
        end
        local totalInfCalls = 0
        for _, miss in ipairs(missingList) do
            totalInfCalls = totalInfCalls + (miss.ScaleCalls or 0)
        end
        local doneInfCalls = 0

        local function waitForBlockByName(name, beforeMap, maxWait)
            for _, b in ipairs(folder:GetChildren()) do
                if b.Name == name and not beforeMap[b] then
                    return b
                end
            end
            RunService.Heartbeat:Wait()
            for _, b in ipairs(folder:GetChildren()) do
                if b.Name == name and not beforeMap[b] then
                    return b
                end
            end
            return folder:FindFirstChild(name)
        end

        local myZone = getPlayerZone(LocalPlayer)
        local dupeSize = Vector3.new(251.79899597168, 1.1754999560161e-38, 298.99996948242)
        if myZone and math.abs(myZone.CFrame.LookVector.X) > 0.5 then
            dupeSize = Vector3.new(298.99996948242, 1.1754999560161e-38, 251.79899597168)
        end
        local dupeCFrame = myZone and CFrame.new(myZone.Position.X, -3.0000000054978e38, myZone.Position.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        for mi, miss in ipairs(missingList) do
            if stopBuild then break end
            if myZone and placeRF and scaleRF then
                local p0 = math.floor((mi - 1) / math.max(#missingList, 1) * 34)
                updProg("INF filling " .. miss.Name .. " +" .. miss.Missing, p0)

                local beforeMap = {}
                for _, b in ipairs(folder:GetChildren()) do beforeMap[b] = true end

                pcall(function()
                    placeRF:InvokeServer(
                        miss.Name,
                        getBlockID(miss.Name),
                        myZone,
                        CFrame.new(0, -3.0000000054978e38, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
                        true
                    )
                end)

                local dupBlock = waitForBlockByName(miss.Name, beforeMap, 4)
                if dupBlock then
                    local scaleCalls = miss.ScaleCalls or math.max(1, math.ceil(miss.Missing / 4) + 1)
                    for n = 1, scaleCalls do
                        if stopBuild then break end
                        task.spawn(function()
                            pcall(function()
                                scaleRF:InvokeServer(dupBlock, dupeSize, dupeCFrame)
                            end)
                        end)
                    end
                    doneInfCalls = doneInfCalls + scaleCalls
                    local infPct = totalInfCalls > 0 and math.floor(doneInfCalls / totalInfCalls * 35) or 35
                    updProg("INF filling " .. miss.Name .. " " .. doneInfCalls .. "/" .. totalInfCalls, infPct)
                end
            end
        end

        updProg("INF ready, building", 35)
    end

    equipAllTools()
    placeTool = Character:FindFirstChild("BuildingTool")
    scaleTool = Character:FindFirstChild("ScalingTool")
    paintTool = Character:FindFirstChild("PaintingTool")
    deleteTool = Character:FindFirstChild("DeleteTool") or Character:FindFirstChild("DeletingTool")
    propertiesTool = Character:FindFirstChild("PropertiesTool")
    bindTool = Character:FindFirstChild("BindTool")
    placeRF = placeTool and placeTool:FindFirstChild("RF")
    scaleRF = scaleTool and scaleTool:FindFirstChild("RF")
    paintRF = (paintTool and paintTool:FindFirstChild("RF"))
        or (LocalPlayer.Backpack:FindFirstChild("PaintingTool") and LocalPlayer.Backpack.PaintingTool:FindFirstChild("RF"))
    deleteRF = deleteTool and deleteTool:FindFirstChild("RF")
    propertiesRF = propertiesTool and propertiesTool:FindFirstChild("SetPropertieRF")
    bindRF = bindTool and bindTool:FindFirstChild("RF")
    local pistonFlat, restFlat = {}, {}
    for _, v in ipairs(flat) do
        if v.Name == "Piston" then
            pistonFlat[#pistonFlat + 1] = v
        else
            restFlat[#restFlat + 1] = v
        end
    end

    local allStyled, styledPistons = {}, {}
    if #pistonFlat > 0 and not stopBuild then
        updProg("Placing " .. #pistonFlat .. " pistons...", 0)
        runPlacePhase(pistonFlat, "Pistons ", 0, 15)
        if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end
        updProg("Waiting for pistons...", 16)
        waitForN(math.floor(#pistonFlat * 0.95), math.max(5, #pistonFlat * 0.08))
        styledPistons = runStylePhase(pistonFlat, folder:GetChildren(), {}, 18, 30)
        if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end
        updProg("Moving " .. #styledPistons .. " pistons...", 30)
        runMovePhase(styledPistons, 30, 40)
        if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end
        updProg("Piston properties (no transparency)...", 40)
        applyPropertiesPhase(styledPistons, 40, 50, true)

        local pistonsToActivate = {}
        for _, entry in ipairs(styledPistons) do
            local ld = entry.v and entry.v.NumberValues and entry.v.NumberValues.LastDirection
            if entry.block and entry.block:FindFirstChild("PPart") and ld == 1 then
                pistonsToActivate[#pistonsToActivate + 1] = {block = entry.block, worldCF = entry.worldCF}
            end
        end



        if #pistonsToActivate >= 2 and not stopBuild then
            updProg("Pre-positioning pistons (moving up 10k studs)...", 48)
            local trowelTool = Character:FindFirstChild("TrowelTool") or LocalPlayer.Backpack:FindFirstChild("TrowelTool")
            if trowelTool then
                if trowelTool.Parent ~= Character then trowelTool.Parent = Character ; task.wait(0.05) end
                local moveOpRF = trowelTool:FindFirstChild("OperationRF")
                if moveOpRF then

                    for _, pd in ipairs(pistonsToActivate) do
                        local b = pd.block
                        if b and b:FindFirstChild("PPart") then
                            local currentCF = b:GetPivot()
                            local highCF = currentCF * CFrame.new(0, 10000, 0)
                            pcall(function() b.PPart.CFrame = highCF end)
                            task.spawn(function()
                                pcall(function() moveOpRF:InvokeServer({b}, currentCF, highCF, "Move") end)
                            end)
                            task.wait(0.1)
                        end
                    end
                    task.wait(0.5)



                    local pistonSet = {}
                    for _, pd in ipairs(pistonsToActivate) do pistonSet[pd.block] = true end
                    local otherPositions = {}
                    for _, b in ipairs(folder:GetChildren()) do
                        if not pistonSet[b] and b:FindFirstChild("PPart") then
                            otherPositions[#otherPositions + 1] = b.PPart.Position
                        end
                    end


                    local baseX = pistonsToActivate[1].block:FindFirstChild("PPart") and pistonsToActivate[1].block.PPart.Position.X or 0
                    local baseZ = pistonsToActivate[1].block:FindFirstChild("PPart") and pistonsToActivate[1].block.PPart.Position.Z or 0
                    local highY = pistonsToActivate[1].block:FindFirstChild("PPart") and pistonsToActivate[1].block.PPart.Position.Y or 10000

                    for idx, pd in ipairs(pistonsToActivate) do
                        local b = pd.block
                        if b and b:FindFirstChild("PPart") then

                            local targetX = baseX + (idx - 1) * 5
                            local targetZ = baseZ
                            local targetY = highY


                            local needsAdjust = true
                            local adjustOffset = 0
                            while needsAdjust and adjustOffset < 50 do
                                needsAdjust = false
                                local testPos = Vector3.new(targetX + adjustOffset, targetY, targetZ)
                                for _, op in ipairs(otherPositions) do
                                    if (testPos - op).Magnitude < 5 then
                                        needsAdjust = true
                                        adjustOffset = adjustOffset + 5
                                        break
                                    end
                                end

                                for prevIdx = 1, idx - 1 do
                                    local prevB = pistonsToActivate[prevIdx].block
                                    if prevB and prevB:FindFirstChild("PPart") then
                                        if (testPos - prevB.PPart.Position).Magnitude < 5 then
                                            needsAdjust = true
                                            adjustOffset = adjustOffset + 5
                                            break
                                        end
                                    end
                                end
                            end

                            targetX = targetX + adjustOffset
                            local currentCF = b:GetPivot()

                            local worldCF = pd.worldCF
                            local spacedCF = CFrame.new(targetX, targetY, targetZ) * (worldCF - worldCF.Position)
                            pcall(function() b.PPart.CFrame = spacedCF end)
                            task.spawn(function()
                                pcall(function() moveOpRF:InvokeServer({b}, currentCF, spacedCF, "Move") end)
                            end)
                            task.wait(0.1)
                        end
                    end
                    task.wait(0.5)
                end
            end
        end
        if #pistonsToActivate > 0 and not stopBuild and placeRF and myZone then
            updProg("Activating " .. #pistonsToActivate .. " pistons via button...", 50)
            local inputLocalScript = ReplicatedStorage:FindFirstChild("InputLocalScript")
            local queueBlocksRF = inputLocalScript and inputLocalScript:FindFirstChild("QueueBlocksRequest")
            if queueBlocksRF then
                for _, pd in ipairs(pistonsToActivate) do
                    if stopBuild then break end
                    local pistonBlock = pd.block
                    if pistonBlock and pistonBlock.Parent and pistonBlock:FindFirstChild("PPart") then
                        local foundBtn = nil
                        local bt = pd.v and pd.v.BindTable
                        if type(bt) == "table" then
                            for _, bindRow in pairs(bt) do
                                if type(bindRow) == "table" then
                                    local targetBlock = placedById[bindRow[1]] or placedById[tostring(bindRow[1])]
                                    if targetBlock and (targetBlock.Name == "Button" or targetBlock.Name == "Switch" or targetBlock.Name == "Sensor" or targetBlock.Name == "Delay") then
                                        foundBtn = targetBlock
                                        break
                                    end
                                end
                            end
                        end
                        activatePistonViaQueue(pistonBlock, foundBtn)
                        task.wait(3)
                    end
                end
                updProg("Pistons activated via QueueBlocksRequest", 55)
            else
                local buttonBlockID = getBlockID("Button")
                local activationBindTool = Character:FindFirstChild("BindTool") or LocalPlayer.Backpack:FindFirstChild("BindTool")
                local activationBindRF = activationBindTool and activationBindTool:FindFirstChild("RF")
                local activationUnbindRF = activationBindTool and activationBindTool:FindFirstChild("UnbindRF")
                if buttonBlockID > 0 and activationBindRF then
                    local beforeSet = {}
                    for _, b in ipairs(folder:GetChildren()) do beforeSet[b] = true end
                    local hrp = Character:FindFirstChild("HumanoidRootPart") or myZone
                    pcall(function() placeRF:InvokeServer("Button", buttonBlockID, myZone, myZone.CFrame:ToObjectSpace(CFrame.new(hrp.Position + Vector3.new(0, 5, 0))), true) end)
                    task.wait(0.5)
                    local placedBtn
                    for _, b in ipairs(folder:GetChildren()) do
                        if not beforeSet[b] and b.Name == "Button" and b:FindFirstChild("PPart") then placedBtn = b ; break end
                    end
                    if placedBtn then
                        local pushParts, pullParts = {}, {}
                        for _, pd in ipairs(pistonsToActivate) do
                            local bUp = pd.block:FindFirstChild("BindUp") or pd.block:FindFirstChild("BindUp", true)
                            local bDn = pd.block:FindFirstChild("BindDown") or pd.block:FindFirstChild("BindDown", true)
                            if bUp then pullParts[#pullParts + 1] = bUp end
                            if bDn then pushParts[#pushParts + 1] = bDn end
                        end
                        local bindFirstArg = {}
                        if #pushParts > 0 then bindFirstArg.Push = pushParts end
                        if #pullParts > 0 then bindFirstArg.Pull = pullParts end
                        if next(bindFirstArg) then
                            invokeWithTimeout(activationBindRF, {bindFirstArg, placedBtn, {}, false})
                            task.wait(0.3)
                            for _, pd in ipairs(pistonsToActivate) do
                                if stopBuild then break end
                                activatePistonViaQueue(pd.block, placedBtn)
                                task.wait(3)
                            end
                        end
                        pcall(function() deleteBlock(placedBtn) end)
                        updProg("Pistons activated", 55)
                    else
                        updProg("Piston activation: button not found", 55)
                    end
                end
            end
        end
        for _, entry in ipairs(styledPistons) do allStyled[#allStyled + 1] = entry end
        task.wait(0.2)
    end

    local restP0 = #pistonFlat > 0 and 60 or 0
    if #restFlat > 0 and not stopBuild then
        updProg("Placing " .. #restFlat .. " blocks...", restP0)
        runPlacePhase(restFlat, "Placing ", restP0, restP0 + 20)
        if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end
        updProg("Waiting for blocks...", restP0 + 21)
        waitForN(math.floor((#pistonFlat + #restFlat) * 0.95), math.max(10, (#pistonFlat + #restFlat) * 0.04))
        local rUsed = {}
        for _, entry in ipairs(allStyled) do if entry.block then rUsed[entry.block] = true end end
        local styledRest = runStylePhase(restFlat, folder:GetChildren(), rUsed, restP0 + 23, restP0 + 50)
        if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end
        updProg("Moving " .. #styledRest .. " blocks...", restP0 + 50)
        runMovePhase(styledRest, restP0 + 50, restP0 + 55)
        if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end
        applyPropertiesPhase(styledRest, restP0 + 55, restP0 + 60)
        for _, entry in ipairs(styledRest) do allStyled[#allStyled + 1] = entry end
    end

    local legacyCount = applyLegacySwitches(allStyled, propertiesRF)
    if legacyCount > 0 then
        updProg("Legacy switches: " .. legacyCount, 94)
        task.wait(0.25)
    end

    applyBindTables(allStyled, 95, 99)
    if stopBuild then isBuilding = false ; setStatus("Stopped") ; return false end

    if #styledPistons > 0 and not stopBuild then
        updProg("Activating pistons via QueueBlocksRequest...", 99)
        for _, entry in ipairs(styledPistons) do
            if entry.block and entry.block.Parent and entry.block.Name == "Piston" and entry.block:FindFirstChild("PPart") then
                local ld = entry.v and entry.v.NumberValues and entry.v.NumberValues.LastDirection
                if ld == 1 then
                    local foundBtn = nil
                    local bt = entry.v and entry.v.BindTable
                    if type(bt) == "table" then
                        for _, bindRow in pairs(bt) do
                            if type(bindRow) == "table" then
                                local targetBlock = placedById[bindRow[1]] or placedById[tostring(bindRow[1])]
                                if targetBlock and (targetBlock.Name == "Button" or targetBlock.Name == "Switch" or targetBlock.Name == "Sensor" or targetBlock.Name == "Delay") then
                                    foundBtn = targetBlock
                                    break
                                end
                            end
                        end
                    end
                    if not foundBtn then
                        for _, otherEntry in ipairs(allStyled) do
                            if otherEntry.block and otherEntry.block.Name == "Button" and otherEntry.v and type(otherEntry.v.BindTable) == "table" then
                                local obBt = otherEntry.v.BindTable
                                for _, bindRow in pairs(obBt) do
                                    if type(bindRow) == "table" and (bindRow[1] == entry.v.ID or bindRow[1] == tostring(entry.v.ID)) then
                                        foundBtn = otherEntry.block
                                        break
                                    end
                                end
                                if foundBtn then break end
                            end
                        end
                    end
                    local ok, err = activatePistonViaQueue(entry.block, foundBtn)
                    if not ok then
                        pcall(function()
                            activatePistonViaQueue(entry.block, foundBtn)
                        end)
                    end
                    task.wait(3)
                end
            end
        end
    end

    if not stopBuild and #allStyled > 0 then
        updProg("Waiting for blocks to settle...", 97)
        local totalCount = #allStyled
        local maxWait = 12
        local startT = tick()
        local function countSettled()
            local settledCount = 0
            for _, entry in ipairs(allStyled) do
                local b = entry.block
                if b and b.Parent and b:FindFirstChild("PPart") then
                    local pp = b.PPart
                    local target = entry.worldCF
                    if target and (pp.Position - target.Position).Magnitude < 1.5 then
                        settledCount = settledCount + 1
                    end
                else
                    settledCount = settledCount + 1
                end
            end
            return settledCount
        end
        while countSettled() < totalCount * 0.9 and tick() - startT < maxWait do
            if stopBuild then break end
            task.wait(0.2)
        end
        updProg("Weld fix: ensuring collision ON on everything...", 97)
        if propertiesRF then
            local needCCOn = {}
            for _, entry in ipairs(allStyled) do
                if entry.block and entry.block.Parent and entry.block:FindFirstChild("PPart") and not isSpecialPropBlock(entry.block.Name) then
                    if not entry.block.PPart.CanCollide then
                        needCCOn[#needCCOn+1] = entry.block
                    end
                end
            end
            if #needCCOn > 0 then
                for i = 1, #needCCOn, 50 do
                    local chunk = {}
                    for j = i, math.min(i + 49, #needCCOn) do
                        chunk[#chunk+1] = needCCOn[j]
                    end
                    pcall(function() propertiesRF:InvokeServer("Collision", chunk) end)
                end
                task.wait(0.2)
            end
        end

        for _, entry in ipairs(allStyled) do
            if entry.v and entry.v.IsTwoPart and entry.block and entry.block.Parent and entry.block:FindFirstChild("PPart") and not isSpecialPropBlock(entry.block.Name) then
                pcall(function()
                    entry.block.PPart.CanCollide = true
                    for _, desc in ipairs(entry.block:GetDescendants()) do
                        if desc:IsA("BasePart") then
                            desc.CanCollide = true
                        end
                    end
                end)
            end
        end

        updProg("Weld fix (non-Block, batch Rotate)...", 98)
        local nonBlockList = {}
        local trowelTool = Character:FindFirstChild("TrowelTool") or LocalPlayer.Backpack:FindFirstChild("TrowelTool")
        if trowelTool and trowelTool.Parent ~= Character then trowelTool.Parent = Character ; task.wait(0.05) end
        local weldOpRF = trowelTool and trowelTool:FindFirstChild("OperationRF")

        for _, entry in ipairs(allStyled) do
            if stopBuild then break end
            if entry.block and entry.block.Parent and entry.block:FindFirstChild("PPart") then
                local isBlock = entry.block.Name:sub(-5) == "Block"
                if not isBlock then
                    nonBlockList[#nonBlockList+1] = entry
                end
            end
        end

        if #nonBlockList > 0 and weldOpRF then
            local identityCF = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
            local BATCH = 15

            local moveNonBlockList = {}
            local rotateConstraintList = {}
            local otherNonBlockList = {}
            for _, entry in ipairs(nonBlockList) do
                if entry.block and isMoveWeldBlock(entry.block.Name) then
                    moveNonBlockList[#moveNonBlockList + 1] = entry
                elseif entry.block and isRotateConstraintBlock(entry.block.Name) then
                    rotateConstraintList[#rotateConstraintList + 1] = entry
                else
                    otherNonBlockList[#otherNonBlockList + 1] = entry
                end
            end


            if #otherNonBlockList > 0 then
                for pass = 1, 3 do
                    if stopBuild then break end
                    updProg("Weld fix Rotate pass " .. pass .. "/3 (" .. #otherNonBlockList .. " parts)", 98)
                    local rotated = 0
                    for i = 1, #otherNonBlockList, BATCH do
                        if stopBuild then break end
                        local batch = {}
                        for j = i, math.min(i + BATCH - 1, #otherNonBlockList) do
                            local e = otherNonBlockList[j]
                            if e.block and e.block.Parent and e.block:FindFirstChild("PPart") then
                                batch[#batch+1] = e.block
                            end
                        end
                        if #batch > 0 then
                            pcall(function() weldOpRF:InvokeServer(batch, identityCF, identityCF, "Rotate") end)
                            rotated = rotated + #batch
                            task.wait(0.08)
                        end
                    end
                    task.wait(0.25)
                    if rotated == 0 then break end
                end
            end


            if #rotateConstraintList > 0 then
                updProg("Weld fix Bar/Rope/Spring (" .. #rotateConstraintList .. " parts)...", 98)
                for i = 1, #rotateConstraintList, BATCH do
                    if stopBuild then break end
                    local batch = {}
                    local batchCFs = {}
                    for j = i, math.min(i + BATCH - 1, #rotateConstraintList) do
                        local e = rotateConstraintList[j]
                        if e.block and e.block.Parent and e.block:FindFirstChild("PPart") and e.worldCF then
                            batch[#batch+1] = e.block
                            batchCFs[#batchCFs+1] = e.worldCF
                        end
                    end
                    if #batch > 0 then

                        for k, b in ipairs(batch) do
                            pcall(function()
                                local cf = batchCFs[k]
                                local rotCF = cf - cf.Position

                                b.PPart.CFrame = cf * CFrame.Angles(0, 0.01, 0)
                                weldOpRF:InvokeServer({b}, rotCF, rotCF * CFrame.Angles(0, 0.01, 0), "Rotate")
                            end)
                            task.wait(0.08)
                        end
                        task.wait(0.1)

                        for k, b in ipairs(batch) do
                            pcall(function()
                                local cf = batchCFs[k]
                                local rotCF = cf - cf.Position
                                b.PPart.CFrame = cf
                                weldOpRF:InvokeServer({b}, rotCF * CFrame.Angles(0, 0.01, 0), rotCF, "Rotate")
                            end)
                            task.wait(0.08)
                        end
                        task.wait(0.1)
                    end
                end
            end


            if #moveNonBlockList > 0 then
                updProg("Weld fix constraint blocks (" .. #moveNonBlockList .. " parts)...", 98)
                for i = 1, #moveNonBlockList, BATCH do
                    if stopBuild then break end
                    local batch = {}
                    local batchCFs = {}
                    for j = i, math.min(i + BATCH - 1, #moveNonBlockList) do
                        local e = moveNonBlockList[j]
                        if e.block and e.block.Parent and e.block:FindFirstChild("PPart") and e.worldCF then
                            batch[#batch+1] = e.block
                            batchCFs[#batchCFs+1] = e.worldCF
                        end
                    end
                    if #batch > 0 then

                        for k, b in ipairs(batch) do
                            pcall(function()
                                local cf = batchCFs[k]

                                b.PPart.CFrame = cf * CFrame.new(0, 0.1, 0)
                                weldOpRF:InvokeServer({b}, cf, cf * CFrame.new(0, 0.1, 0), "Move")
                            end)
                            task.wait(0.08)
                        end
                        task.wait(0.1)

                        for k, b in ipairs(batch) do
                            pcall(function()
                                local cf = batchCFs[k]
                                b.PPart.CFrame = cf
                                weldOpRF:InvokeServer({b}, cf * CFrame.new(0, 0.1, 0), cf, "Move")
                            end)
                            task.wait(0.08)
                        end
                        task.wait(0.1)
                    end
                end
            end


            updProg("Weld fix: restoring positions...", 98)
            for i = 1, #nonBlockList, BATCH do
                if stopBuild then break end
                local batch = {}
                local batchCFs = {}
                for j = i, math.min(i + BATCH - 1, #nonBlockList) do
                    local e = nonBlockList[j]


                    if e.block and e.block.Parent and e.block:FindFirstChild("PPart") and e.worldCF
                        and not isRotateConstraintBlock(e.block.Name) then
                        batch[#batch+1] = e.block
                        batchCFs[#batchCFs+1] = e.worldCF
                    end
                end
                if #batch > 0 then
                    for k, b in ipairs(batch) do
                        pcall(function()
                            local targetCF = batchCFs[k]
                            local currentCF = b:GetPivot()
                            b.PPart.CFrame = targetCF
                            weldOpRF:InvokeServer({b}, currentCF, targetCF, "Move")
                        end)
                        task.wait(0.05)
                    end
                    task.wait(0.05)
                end
            end
            task.wait(0.3)
        end

        if #nonBlockList > 0 and not stopBuild then
            local propTool = Character:FindFirstChild("PropertiesTool") or LocalPlayer.Backpack:FindFirstChild("PropertiesTool")
            if propTool and propTool.Parent ~= Character then propTool.Parent = Character ; task.wait(0.05) end
            propertiesRF = propTool and propTool:FindFirstChild("SetPropertieRF") or propertiesRF

            if propertiesRF then
                local ccToggleOn = {}
                for _, entry in ipairs(nonBlockList) do
                    local b = entry.block
                    local pp = b.PPart

                    local isConstraint = isSpecialPropBlock(b.Name)

                    if not isConstraint and not pp.CanCollide then
                        ccToggleOn[#ccToggleOn+1] = b
                    end
                end

                if #ccToggleOn > 0 then
                    pcall(function() propertiesRF:InvokeServer("Collision", ccToggleOn) end)
                    task.wait(0.1)
                end

                local twoPartCCToggle = {}
                for _, entry in ipairs(nonBlockList) do
                    if entry.v and entry.v.IsTwoPart and entry.block and entry.block.Parent and not isSpecialPropBlock(entry.block.Name) then
                        pcall(function()
                            entry.block.PPart.CanCollide = true
                            for _, desc in ipairs(entry.block:GetDescendants()) do
                                if desc:IsA("BasePart") then
                                    desc.CanCollide = true
                                end
                            end
                        end)
                        if not entry.block.PPart.CanCollide then
                            twoPartCCToggle[#twoPartCCToggle+1] = entry.block
                        end
                    end
                end
                if #twoPartCCToggle > 0 then
                    pcall(function() propertiesRF:InvokeServer("Collision", twoPartCCToggle) end)
                end
                task.wait(0.15)

                local nbTransp = 0
                for _, entry in ipairs(nonBlockList) do
                    if stopBuild then break end
                    local v = entry.v
                    if v and v.Transparency ~= nil and not isSpecialPropBlock(entry.block.Name) then
                        local t = tonumber(v.Transparency)
                        if t then
                            t = math.clamp(t, 0, 1)
                            pcall(function()
                                propertiesRF:InvokeServer("Transparency", {entry.block}, tostring(math.floor(t * 100 + 0.5)))
                            end)
                            pcall(function()
                                for _, desc in ipairs(entry.block:GetDescendants()) do
                                    if desc:IsA("BasePart") and desc.Name ~= "PPart" then
                                        desc.Transparency = t
                                    end
                                end
                            end)
                            nbTransp = nbTransp + 1
                        end
                    end
                    if nbTransp % 10 == 0 then task.wait(0.05) end
                end
                if nbTransp > 0 then task.wait(0.1) end
            end
            updProg("Weld fix done (" .. #nonBlockList .. " non-Block rotated)", 99)
        else
            updProg("Weld fix done", 99)
        end
    end

    if not stopBuild and propertiesRF then
        updProg("Applying all properties post-weld-fix...", 99)
        local postAnchorOn, postAnchorOff = {}, {}
        local postCcOn, postCcOff = {}, {}
        for _, entry in ipairs(allStyled) do
            if not entry.block or not entry.block.Parent or not entry.v or not entry.block:FindFirstChild("PPart") then continue end
            local v = entry.v
            local b = entry.block
            local pp = b.PPart
            local isBlock = b.Name:sub(-5) == "Block"

            local wantAnchor
            if v.Anchored ~= nil then
                wantAnchor = v.Anchored == true
            elseif not isBlock then
                wantAnchor = true
            end
            if wantAnchor ~= nil and pp.Anchored ~= wantAnchor then
                if wantAnchor then postAnchorOn[#postAnchorOn+1] = b else postAnchorOff[#postAnchorOff+1] = b end
            end

            if not isSpecialPropBlock(b.Name) then
                if v.CanCollide == false and pp.CanCollide then
                    postCcOff[#postCcOff+1] = b
                elseif v.CanCollide ~= false and not pp.CanCollide then
                    postCcOn[#postCcOn+1] = b
                end
            end
        end
        if #postAnchorOn > 0 then pcall(function() propertiesRF:InvokeServer("Anchored", postAnchorOn) end) end
        task.wait(0.05)
        if #postAnchorOff > 0 then pcall(function() propertiesRF:InvokeServer("Anchored", postAnchorOff) end) end
        task.wait(0.05)
        if #postCcOn > 0 then pcall(function() propertiesRF:InvokeServer("Collision", postCcOn) end) end
        task.wait(0.05)

        local postTranspGroups = {}
        local postShadowGroups = {}
        for _, entry in ipairs(allStyled) do
            if not entry.block or not entry.block.Parent or not entry.v or not entry.block:FindFirstChild("PPart") then continue end
            local v = entry.v
            local b = entry.block
            if v.Transparency ~= nil and not isSpecialPropBlock(b.Name) then
                local t = tonumber(v.Transparency)
                if t then
                    t = math.clamp(t, 0, 1)
                    local tStr = tostring(math.floor(t * 100 + 0.5))
                    postTranspGroups[tStr] = postTranspGroups[tStr] or {}
                    table.insert(postTranspGroups[tStr], b)
                end
            end
            if v.ShowShadow ~= nil then
                local val = v.ShowShadow == true
                local key = val and "1" or "0"
                postShadowGroups[key] = postShadowGroups[key] or {}
                table.insert(postShadowGroups[key], b)
            end
        end
        for valKey, blocks in pairs(postTranspGroups) do
            if #blocks > 0 then pcall(function() propertiesRF:InvokeServer("Transparency", blocks, valKey) end) end
            task.wait(0.05)
        end
        for valKey, blocks in pairs(postShadowGroups) do
            if #blocks > 0 then pcall(function() propertiesRF:InvokeServer("Cast shadow", blocks, valKey) end) end
            task.wait(0.05)
        end
        if #postCcOff > 0 then
            for i = 1, #postCcOff, 50 do
                local chunk = {}
                for j = i, math.min(i + 49, #postCcOff) do chunk[#chunk+1] = postCcOff[j] end
                pcall(function() propertiesRF:InvokeServer("Collision", chunk) end)
            end
            task.wait(0.1)
        end
        updProg("Properties applied", 99)
    end

    if #styledPistons > 0 and propertiesRF and not stopBuild then
        updProg("Piston transparency...", 99)
        local pDone = 0
        for _, entry in ipairs(styledPistons) do
            if stopBuild then break end
            if entry.block and entry.v and entry.v.Transparency ~= nil and entry.block.Name == "Piston" and entry.block:FindFirstChild("PPart") then
                local transparency = tonumber(entry.v.Transparency)
                if transparency then
                    transparency = math.clamp(transparency, 0, 1)
                    pcall(function()
                        firePropertyRF(propertiesRF, "Transparency", {entry.block}, tostring(math.floor(transparency * 100 + 0.5)))
                    end)
                    pDone = pDone + 1
                end
            end
            if pDone > 0 and pDone % 30 == 0 then task.wait() end
        end
        if pDone > 0 then
            task.wait(0.3)
            updProg("Piston transparency done (" .. pDone .. ")", 99)
        end
    end


    if not stopBuild and propertiesRF then
        local hingeTranspDone = 0
        for _, entry in ipairs(allStyled) do
            if stopBuild then break end
            if entry.block and entry.v and entry.v.Transparency ~= nil and entry.block.Name == "Hinge" and entry.block:FindFirstChild("PPart") then
                local transparency = tonumber(entry.v.Transparency)
                if transparency then
                    transparency = math.clamp(transparency, 0, 1)
                    pcall(function()
                        firePropertyRF(propertiesRF, "Transparency", {entry.block}, tostring(math.floor(transparency * 100 + 0.5)))
                    end)
                    hingeTranspDone = hingeTranspDone + 1
                end
            end
            if hingeTranspDone > 0 and hingeTranspDone % 30 == 0 then task.wait() end
        end
        if hingeTranspDone > 0 then
            task.wait(0.3)
            updProg("Hinge transparency done (" .. hingeTranspDone .. ")", 99)
        end
    end


    if not stopBuild and propertiesRF then
        local brsTranspDone = 0
        for _, entry in ipairs(allStyled) do
            if stopBuild then break end
            if entry.block and entry.v and entry.v.Transparency ~= nil and isRotateConstraintBlock(entry.block.Name) and entry.block:FindFirstChild("PPart") then
                local transparency = tonumber(entry.v.Transparency)
                if transparency then
                    transparency = math.clamp(transparency, 0, 1)
                    pcall(function()
                        firePropertyRF(propertiesRF, "Transparency", {entry.block}, tostring(math.floor(transparency * 100 + 0.5)))
                    end)
                    brsTranspDone = brsTranspDone + 1
                end
            end
            if brsTranspDone > 0 and brsTranspDone % 30 == 0 then task.wait() end
        end
        if brsTranspDone > 0 then
            task.wait(0.3)
            updProg("Bar/Rope/Spring transparency done (" .. brsTranspDone .. ")", 99)
        end
    end


    if not stopBuild and propertiesRF then
        local ccOffConstraint = {}
        for _, entry in ipairs(allStyled) do
            if entry.block and entry.block.Parent and entry.block:FindFirstChild("PPart") then
                local b = entry.block
                local v = entry.v
                if isSpecialPropBlock(b.Name) and v and v.CanCollide == false then
                    if b.PPart.CanCollide then
                        ccOffConstraint[#ccOffConstraint+1] = b
                    end
                end
            end
        end
        if #ccOffConstraint > 0 then
            updProg("Disabling collision on " .. #ccOffConstraint .. " constraint blocks...", 99)
            for i = 1, #ccOffConstraint, 50 do
                local chunk = {}
                for j = i, math.min(i + 49, #ccOffConstraint) do
                    chunk[#chunk+1] = ccOffConstraint[j]
                end
                pcall(function() propertiesRF:InvokeServer("Collision", chunk) end)
            end
            task.wait(0.1)
        end
    end

    updProg(stopBuild and "Stopped" or "Done! " .. total .. " blocks", 100)
    isBuilding = false
    pcall(function()
        local settingsFolder = LocalPlayer:FindFirstChild("Settings")
        if settingsFolder then
            local sbVal = settingsFolder:FindFirstChild("ShareBlocks")
            if sbVal then
                sbVal.Value = shareBlocksOriginal
            end
        end
    end)
    return true, placedById
end



local recentlyPlacedBlocks = {}

local function clearPreview()
    for _, o in pairs(PreviewFolder:GetChildren()) do o:Destroy() end
    for _, b in pairs(selectionBoxes) do if b then pcall(function() b:Destroy() end) end end
    previewParts = {}
    selectionBoxes = {}
    previewActive = false
    selectedObjectName = nil
    if updatePreviewButtonGlobal then updatePreviewButtonGlobal() end
end

local function createPreview(buildData, selBlock)
    clearPreview()
    local myZone = getPlayerZone(LocalPlayer)
    if not myZone then return false end
    local sc = Settings.buildScale
    local off = Vector3.new(Settings.buildOffsetX, Settings.buildOffsetY, Settings.buildOffsetZ)
    local targetT = Settings.previewTransparency
    local allFadeParts = {}
    local created = 0
    for blockName, blocks in pairs(buildData) do
        local tmpl = BuildingParts:FindFirstChild(blockName)
        if not tmpl then continue end
        for _, bi in pairs(blocks) do
            local relCF = getBlockCF(bi)
            local pos = (relCF.Position * sc) + off
            local scaledCF = CFrame.new(pos) * (relCF - relCF.Position)
            local worldCF = myZone.CFrame:ToWorldSpace(scaledCF)
            local pb = tmpl:Clone()
            if pb:FindFirstChild("PPart") then

                local partOffsets = {}
                for _, d in pairs(pb:GetDescendants()) do
                    if (d:IsA("BasePart") or d:IsA("UnionOperation")) and d ~= pb.PPart then
                        partOffsets[d] = pb.PPart.CFrame:ToObjectSpace(d.CFrame)
                    end
                end
                pb.PPart.CFrame = worldCF

                for d, offsetCF in pairs(partOffsets) do
                    pcall(function() d.CFrame = worldCF * offsetCF end)
                end
                local rawSize = bi.Size or bi.size
                if rawSize and rawSize ~= "" then
                    pcall(function() pb.PPart.Size = strV3(rawSize) * sc end)
                end
                local rawCol = bi.Col or bi.Color or bi.color or bi.col
                if rawCol and rawCol ~= "" then
                    pcall(function() pb.PPart.Color = strCol(tostring(rawCol)) end)
                end
                pb.PPart.Transparency = 1
                pb.PPart.CanCollide = false
                pb.PPart.Anchored = true
                allFadeParts[#allFadeParts + 1] = pb.PPart
                for _, d in pairs(pb:GetDescendants()) do
                    if d:IsA("BasePart") or d:IsA("UnionOperation") then
                        d.Transparency = 1
                        d.CanCollide = false
                        d.Anchored = true
                        allFadeParts[#allFadeParts + 1] = d
                    end
                end
                pb.Name = blockName
                pb.Parent = PreviewFolder
                if selBlock and blockName == selBlock then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = pb.PPart
                    hl.FillColor = Color3.fromRGB(255,255,255)
                    hl.OutlineColor = Color3.fromRGB(255,255,255)
                    hl.FillTransparency = 0.7
                    hl.OutlineTransparency = 0.3
                    hl.Parent = pb.PPart
                    selectionBoxes[blockName] = hl
                end
                table.insert(previewParts, pb)
                created = created + 1
                if created % 80 == 0 then task.wait() end
            end
        end
    end
    previewActive = true
    if updatePreviewButtonGlobal then updatePreviewButtonGlobal() end
    if updateBlocksDisplayGlobal then updateBlocksDisplayGlobal() end
    task.spawn(function()
        local startT = tick()
        local dur = 0.45
        while true do
            local el = tick() - startT
            local a = math.clamp(el / dur, 0, 1)
            local tVal = 1 + (targetT - 1) * a
            for _, p in ipairs(allFadeParts) do
                if p and p.Parent then p.Transparency = tVal end
            end
            if a >= 1 then break end
            if not previewActive then break end
            task.wait(0.03)
        end
    end)
    return true
end

local function updateSelectionHighlight(blockName)
    for _, b in pairs(selectionBoxes) do if b then pcall(function() b:Destroy() end) end end
    selectionBoxes = {}
    if blockName then
        for _, p in pairs(previewParts) do
            if p.Name == blockName and p:FindFirstChild("PPart") then
                local hl = Instance.new("Highlight")
                hl.Adornee = p.PPart
                hl.FillColor = Color3.fromRGB(255,255,255)
                hl.OutlineColor = Color3.fromRGB(255,255,255)
                hl.FillTransparency = 0.7
                hl.OutlineTransparency = 0.3
                hl.Parent = p.PPart
                selectionBoxes[blockName] = hl
                break
            end
        end
    end
end

local preTerminateCallbacks = {}

local farmState = {
    active = false, runs = 0, earned = 0, startTime = 0, totalTime = 0,
    positions = {
        Vector3.new(-61.26, 69.78, 1273.84),
        Vector3.new(-48.86, 85.36, 1441.15),
        Vector3.new(-46.04, 72.56, 2211.08),
        Vector3.new(-67.08, 72.74, 3726.19),
        Vector3.new(-55.31, 82.60, 4523.01),
        Vector3.new(-52.80, 116.90, 5937.94),
        Vector3.new(-62.71, 82.72, 6709.27),
        Vector3.new(-53.46, 94.83, 8241.62),
        Vector3.new(-56.53, -362.03, 9486.16),
    }
}
local function getGold()
    local dv = LocalPlayer:FindFirstChild("Data")
    if dv then local g = dv:FindFirstChild("Gold") if g then return g.Value end end
    return 0
end
local function fmtTime(s)
    s = math.floor(s)
    local h = math.floor(s / 3600) local m = math.floor((s % 3600) / 60)
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s % 60) end
    return string.format("%d:%02d", m, s % 60)
end
local function getFarmStats()
    local elapsed = farmState.active and (tick() - farmState.startTime + farmState.totalTime) or farmState.totalTime
    local hrs = elapsed / 3600
    return { active = farmState.active, runs = farmState.runs, earned = farmState.earned, time = fmtTime(elapsed), rate = hrs > 0.01 and math.floor(farmState.earned / hrs) or 0 }
end


local function mikuHubMain()
--====================================================================
-- mikuHub UI  (MiniUI library, TQQ / Miku theme)  -  made by miku
--====================================================================
local MiniUI = (function()
	local T = {
		Bg = Color3.fromRGB(15, 20, 34),
		Panel = Color3.fromRGB(21, 29, 48),
		Item = Color3.fromRGB(29, 40, 64),
		Hover = Color3.fromRGB(40, 56, 86),
		Accent = Color3.fromRGB(72, 205, 176),
		AccentDark = Color3.fromRGB(10, 30, 36),
		Text = Color3.fromRGB(234, 244, 250),
		Sub = Color3.fromRGB(140, 160, 190),
		Line = Color3.fromRGB(45, 62, 94),
		Bad = Color3.fromRGB(255, 107, 107),
	}
	-- five pastel keypoints = the quintuplet strip under the title bar
	local STRIP = {
		Color3.fromRGB(150, 190, 255), Color3.fromRGB(255, 143, 177), Color3.fromRGB(72, 205, 176),
		Color3.fromRGB(150, 225, 120), Color3.fromRGB(255, 176, 110),
	}

	local function tween(o, p, t)
		TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), p):Play()
	end
	local function new(class, props, kids)
		local o, parent = Instance.new(class), nil
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else o[k] = v end
		end
		for _, c in ipairs(kids or {}) do c.Parent = o end
		o.Parent = parent
		return o
	end
	local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
	local function stroke(c) return new("UIStroke", { Color = c, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
	local function pad(v, h)
		return new("UIPadding", {
			PaddingTop = UDim.new(0, v), PaddingBottom = UDim.new(0, v),
			PaddingLeft = UDim.new(0, h), PaddingRight = UDim.new(0, h),
		})
	end
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local function isMove(i)
		return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
	end

	local M = {}

	function M.Window(opts)
		opts = opts or {}
		local cam = Workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local mobile = opts.Mode == "Mobile"
			or (opts.Mode ~= "PC" and UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or vp.X < 800))

		local rowH, ts = mobile and 46 or 34, mobile and 16 or 14
		local topH = mobile and 46 or 40
		local statusH = mobile and 30 or 26
		local W = mobile and math.min(vp.X - 24, 500) or 580
		local H = mobile and math.min(vp.Y - 24, 320) or 400

		local win, conns = { Mobile = mobile }, {}
		local function bind(sig, fn)
			local c = sig:Connect(fn)
			conns[#conns + 1] = c
			return c
		end

		local gui = new("ScreenGui", {
			Name = "mikuHub", ResetOnSpawn = false, IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
		})
		local okp, hp = pcall(function() return gethui and gethui() end)
		pcall(function() gui.Parent = (okp and hp) or game:GetService("CoreGui") end)
		if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

		local main = new("Frame", {
			Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = T.Bg,
			ClipsDescendants = true, Parent = gui,
		}, { corner(12), stroke(T.Line) })

		-- title bar
		local top = new("Frame", { Size = UDim2.new(1, 0, 0, topH), BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = main })
		new("TextLabel", {
			Text = '🎧 ' .. (opts.Title or "mikuHub") .. '  <font size="' .. (ts - 2) .. '" color="#8CA0BE">' .. (opts.Subtitle or "") .. '</font>',
			RichText = true, Font = Enum.Font.GothamBold, TextSize = ts + 3, TextColor3 = T.Text,
			TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -60, 1, 0), Parent = top,
		})
		local close = new("TextButton", {
			Text = "×", Font = Enum.Font.GothamBold, TextSize = ts + 8, TextColor3 = T.Sub,
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(topH, topH), Parent = top,
		})
		new("Frame", {
			Position = UDim2.fromOffset(0, topH), Size = UDim2.new(1, 0, 0, 3), BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1), Parent = main,
		}, { new("UIGradient", { Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, STRIP[1]), ColorSequenceKeypoint.new(0.25, STRIP[2]),
			ColorSequenceKeypoint.new(0.5, STRIP[3]), ColorSequenceKeypoint.new(0.75, STRIP[4]),
			ColorSequenceKeypoint.new(1, STRIP[5]),
		}) }) })

		-- drag
		local dragging, dragStart, startPos
		bind(top.InputBegan, function(i)
			if isPress(i) then
				dragging, dragStart, startPos = true, i.Position, main.Position
			end
		end)
		bind(UserInputService.InputChanged, function(i)
			if dragging and isMove(i) then
				local d = i.Position - dragStart
				main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
		bind(UserInputService.InputEnded, function(i)
			if isPress(i) then dragging = false end
		end)

		-- body
		local body = new("Frame", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(0, topH + 3),
			Size = UDim2.new(1, 0, 1, -(topH + 3 + statusH)), Parent = main,
		})
		local tabs, pages
		if mobile then
			tabs = new("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X,
				ScrollingDirection = Enum.ScrollingDirection.X, Parent = body,
			}, {
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }),
				pad(5, 8),
			})
			pages = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = body })
		else
			tabs = new("ScrollingFrame", {
				Size = UDim2.new(0, 126, 1, 0), BackgroundColor3 = T.Panel, BorderSizePixel = 0,
				ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = body,
			}, { new("UIListLayout", { Padding = UDim.new(0, 4) }), pad(8, 8) })
			pages = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(126, 0), Size = UDim2.new(1, -126, 1, 0), Parent = body })
		end

		-- status bar
		local sbar = new("Frame", {
			Position = UDim2.new(0, 0, 1, -statusH), Size = UDim2.new(1, 0, 0, statusH),
			BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = main,
		})
		local sline = new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = T.Line, BorderSizePixel = 0, Parent = sbar })
		local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = sline })
		local stext = new("TextLabel", {
			Text = "Ready", Font = Enum.Font.Gotham, TextSize = ts - 2, TextColor3 = T.Sub,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
			BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 1, -2), Parent = sbar,
		})
		win.ProgressFill = fill
		function win:SetStatus(t) stext.Text = tostring(t) end
		function win:SetProgress(p) tween(fill, { Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0) }, 0.1) end

		-- show / hide
		local openBtn
		function win:Toggle(state)
			if state == nil then state = not main.Visible end
			main.Visible = state
			if openBtn then openBtn.Visible = not state end
		end
		function win:Destroy()
			for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
			gui:Destroy()
		end
		bind(close.MouseButton1Click, function() win:Toggle(false) end)
		if mobile then
			openBtn = new("TextButton", {
				Text = "🎧", Font = Enum.Font.GothamBold, TextSize = 22, TextColor3 = T.AccentDark,
				BackgroundColor3 = T.Accent, AnchorPoint = Vector2.new(0.5, 0), Visible = false,
				Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(44, 44), Parent = gui,
			}, { corner(22) })
			bind(openBtn.MouseButton1Click, function() win:Toggle(true) end)
		else
			bind(UserInputService.InputBegan, function(i, gp)
				if not gp and i.KeyCode == (opts.Key or Enum.KeyCode.RightShift) then win:Toggle() end
			end)
		end

		-- notifications
		local toasts = new("Frame", {
			BackgroundTransparency = 1, Parent = gui,
			AnchorPoint = mobile and Vector2.new(0.5, 0) or Vector2.new(1, 1),
			Position = mobile and UDim2.new(0.5, 0, 0, 60) or UDim2.new(1, -16, 1, -16),
			Size = UDim2.fromOffset(mobile and 300 or 290, 300),
		}, {
			new("UIListLayout", {
				Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = mobile and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom,
			}),
		})
		function win:Notify(title, text, dur)
			local t = new("CanvasGroup", {
				Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = T.Panel, GroupTransparency = 1, Parent = toasts,
			}, {
				corner(10), stroke(T.Line),
				new("Frame", { Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0 }),
				new("TextLabel", {
					Text = title, Font = Enum.Font.GothamBold, TextSize = ts, TextColor3 = T.Text,
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
					Position = UDim2.fromOffset(16, 7), Size = UDim2.new(1, -24, 0, 18),
				}),
				new("TextLabel", {
					Text = text or "", Font = Enum.Font.Gotham, TextSize = ts - 2, TextColor3 = T.Sub,
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
					Position = UDim2.fromOffset(16, 27), Size = UDim2.new(1, -24, 0, 20),
				}),
			})
			tween(t, { GroupTransparency = 0 }, 0.25)
			task.delay(dur or 3, function()
				tween(t, { GroupTransparency = 1 }, 0.3)
				task.wait(0.35)
				t:Destroy()
			end)
		end

		-- tabs
		local list, current = {}, nil
		local function select(tab)
			if current == tab then return end
			current = tab
			for _, o in ipairs(list) do
				local on = o == tab
				o.page.Visible = on
				tween(o.btn, { BackgroundTransparency = on and 0 or 1 })
				o.btn.TextColor3 = on and T.AccentDark or T.Sub
			end
		end
		function win:Select(tab) select(tab) end

		function win:Tab(name)
			local btn = new("TextButton", {
				Text = name, Font = Enum.Font.GothamMedium, TextSize = ts, TextColor3 = T.Sub,
				BackgroundColor3 = T.Accent, BackgroundTransparency = 1, AutoButtonColor = false,
				Size = UDim2.new(mobile and 0 or 1, 0, 0, 34),
				AutomaticSize = mobile and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
				Parent = tabs,
			}, { corner(8), pad(0, 14) })
			local page = new("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = mobile and 0 or 3, ScrollBarImageColor3 = T.Line,
				CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Visible = false, Parent = pages,
			}, { new("UIListLayout", { Padding = UDim.new(0, 8) }), pad(10, 10) })

			local tab = { btn = btn, page = page }
			list[#list + 1] = tab
			bind(btn.MouseButton1Click, function() select(tab) end)
			if #list == 1 then select(tab) end

			local function row(h)
				return new("Frame", { Size = UDim2.new(1, 0, 0, h or rowH), BackgroundColor3 = T.Item, Parent = page }, { corner(8) })
			end
			local function label(parent, text, x, w)
				return new("TextLabel", {
					Text = text, Font = Enum.Font.GothamMedium, TextSize = ts, TextColor3 = T.Text,
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
					Position = UDim2.fromOffset(x or 12, 0), Size = UDim2.new(w or 1, -(x or 12), 1, 0), Parent = parent,
				})
			end

			function tab:Section(text)
				new("TextLabel", {
					Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = ts - 2, TextColor3 = T.Accent,
					TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22), Parent = page,
				}, { pad(0, 2) })
			end

			function tab:Paragraph(text)
				local l = new("TextLabel", {
					Text = text, RichText = true, Font = Enum.Font.Gotham, TextSize = ts - 1, TextColor3 = T.Sub,
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = page,
				}, { pad(0, 2) })
				return { Set = function(_, s) l.Text = s end }
			end

			function tab:Collapsible(title, text, open)
				local holder = new("Frame", {
					Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Item, Parent = page,
				}, { corner(8), new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
				local head = new("TextButton", {
					Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, rowH), Parent = holder,
				})
				label(head, title, 12, 1)
				local arrow = new("TextLabel", {
					Text = open and "▾" or "▸", Font = Enum.Font.GothamBold, TextSize = ts, TextColor3 = T.Accent,
					BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0),
					Size = UDim2.fromOffset(16, rowH), Parent = head,
				})
				local bodyL = new("TextLabel", {
					Text = text, RichText = true, Font = Enum.Font.Gotham, TextSize = ts - 1, TextColor3 = T.Sub,
					TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
					BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
					Visible = open and true or false, LayoutOrder = 2, Parent = holder,
				}, { pad(6, 12) })
				bind(head.MouseButton1Click, function()
					bodyL.Visible = not bodyL.Visible
					arrow.Text = bodyL.Visible and "▾" or "▸"
				end)
				return { Set = function(_, s) bodyL.Text = s end }
			end

			function tab:Label(text)
				local l = new("TextLabel", {
					Text = text, RichText = true, Font = Enum.Font.GothamMedium, TextSize = ts - 1, TextColor3 = T.Text,
					TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundColor3 = T.Panel,
					Size = UDim2.new(1, 0, 0, 28), Parent = page,
				}, { corner(8), pad(0, 10) })
				return { Set = function(_, s) l.Text = s end }
			end

			function tab:Button(text, cb)
				local b = new("TextButton", {
					Text = text, Font = Enum.Font.GothamMedium, TextSize = ts, TextColor3 = T.Text,
					BackgroundColor3 = T.Item, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, rowH), Parent = page,
				}, { corner(8) })
				bind(b.MouseEnter, function() tween(b, { BackgroundColor3 = T.Hover }) end)
				bind(b.MouseLeave, function() tween(b, { BackgroundColor3 = T.Item }) end)
				bind(b.MouseButton1Click, function()
					b.BackgroundColor3 = T.Accent
					tween(b, { BackgroundColor3 = T.Item }, 0.35)
					if cb then task.spawn(cb) end
				end)
				return { SetText = function(_, s) b.Text = s end }
			end

			function tab:Toggle(text, default, cb)
				local r = row()
				label(r, text, 12, 1)
				local sw, kh = mobile and 50 or 42, mobile and 28 or 22
				local track = new("Frame", {
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(sw, kh), BackgroundColor3 = T.Line, Parent = r,
				}, { corner(kh) })
				local knob = new("Frame", {
					AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
					Size = UDim2.fromOffset(kh - 6, kh - 6), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
				}, { corner(kh) })
				local state = default and true or false
				local function render()
					tween(track, { BackgroundColor3 = state and T.Accent or T.Line })
					tween(knob, { Position = UDim2.new(0, state and (sw - kh + 3) or 3, 0.5, 0) })
				end
				render()
				local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = r })
				bind(hit.MouseButton1Click, function()
					state = not state
					render()
					if cb then task.spawn(cb, state) end
				end)
				return {
					Get = function() return state end,
					Set = function(_, v, silent)
						state = v and true or false
						render()
						if cb and not silent then task.spawn(cb, state) end
					end,
				}
			end

			function tab:Slider(text, min, max, default, cb, inc)
				inc = inc or 1
				local val = math.clamp(default or min, min, max)
				local r = row(rowH + 14)
				label(r, text, 12, 0.6).Position = UDim2.fromOffset(12, 6)
				local num = new("TextLabel", {
					Text = tostring(val), Font = Enum.Font.GothamBold, TextSize = ts, TextColor3 = T.Accent,
					TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1,
					Position = UDim2.new(0.6, 0, 0, 6), Size = UDim2.new(0.4, -12, 0, 20), Parent = r,
				})
				local bh = mobile and 8 or 6
				local bar = new("Frame", {
					Position = UDim2.new(0, 12, 1, -(bh + 12)), Size = UDim2.new(1, -24, 0, bh),
					BackgroundColor3 = T.Line, Parent = r,
				}, { corner(bh) })
				local fillF = new("Frame", { Size = UDim2.fromScale((val - min) / (max - min), 1), BackgroundColor3 = T.Accent, Parent = bar }, { corner(bh) })
				new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(bh + 8, bh + 8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = fillF,
				}, { corner(20) })

				local function apply(v, silent)
					val = v
					fillF.Size = UDim2.fromScale((val - min) / (max - min), 1)
					num.Text = tostring(val)
					if cb and not silent then task.spawn(cb, val) end
				end
				local function set(x)
					local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
					local v = math.clamp(math.floor((min + (max - min) * a) / inc + 0.5) * inc, min, max)
					if v ~= val then apply(v) end
				end
				local active = false
				bind(r.InputBegan, function(i)
					if isPress(i) then
						active = true
						page.ScrollingEnabled = false
						set(i.Position.X)
					end
				end)
				bind(UserInputService.InputChanged, function(i)
					if active and isMove(i) then set(i.Position.X) end
				end)
				bind(UserInputService.InputEnded, function(i)
					if active and isPress(i) then
						active = false
						page.ScrollingEnabled = true
					end
				end)
				return {
					Get = function() return val end,
					Set = function(_, v) apply(math.clamp(v, min, max), true) end,
				}
			end

			function tab:Input(text, placeholder, default, cb)
				local r = row()
				label(r, text, 12, 0.4)
				local box = new("TextBox", {
					Text = default or "", PlaceholderText = placeholder or "", PlaceholderColor3 = T.Sub,
					TextColor3 = T.Text, Font = Enum.Font.Gotham, TextSize = ts - 1, ClearTextOnFocus = false,
					TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = T.Panel,
					AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.new(0.6, -12, 1, -12), Parent = r,
				}, { corner(6), pad(0, 8) })
				bind(box.FocusLost, function(enter)
					if cb then task.spawn(cb, box.Text, enter) end
				end)
				return {
					Get = function() return box.Text end,
					Set = function(_, v) box.Text = tostring(v) end,
				}
			end

			function tab:Dropdown(text, getList, cb, default)
				local holder = new("Frame", {
					Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page,
				}, { new("UIListLayout", { Padding = UDim.new(0, 4) }) })
				local head = new("TextButton", {
					Text = "", AutoButtonColor = false, BackgroundColor3 = T.Item, Size = UDim2.new(1, 0, 0, rowH), Parent = holder,
				}, { corner(8) })
				label(head, text, 12, 0.4)
				local value = new("TextLabel", {
					Text = default or "Select...", Font = Enum.Font.Gotham, TextSize = ts - 1, TextColor3 = T.Accent,
					TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, BackgroundTransparency = 1,
					Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -30, 1, 0), Parent = head,
				})
				new("TextLabel", {
					Text = "▾", Font = Enum.Font.GothamBold, TextSize = ts, TextColor3 = T.Sub, BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(16, rowH), Parent = head,
				})
				local listF = new("ScrollingFrame", {
					Size = UDim2.new(1, 0, 0, 0), Visible = false, BackgroundColor3 = T.Panel, BorderSizePixel = 0,
					ScrollBarThickness = 3, ScrollBarImageColor3 = T.Line, CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = holder,
				}, { corner(8), new("UIListLayout", { Padding = UDim.new(0, 3) }), pad(4, 4) })

				local itemH = rowH - 8
				local function close() listF.Visible = false end
				local function refresh()
					for _, c in ipairs(listF:GetChildren()) do
						if c:IsA("GuiObject") then c:Destroy() end
					end
					local ok, items = pcall(getList)
					if not ok or type(items) ~= "table" then items = {} end
					if #items == 0 then items = { { display = "(nothing found)" } } end
					for _, it in ipairs(items) do
						local name = type(it) == "table" and (it.name or it.display) or it
						local disp = type(it) == "table" and (it.display or it.name) or it
						local b = new("TextButton", {
							Text = tostring(disp), Font = Enum.Font.Gotham, TextSize = ts - 1, TextColor3 = T.Text,
							TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
							BackgroundColor3 = T.Item, AutoButtonColor = false, Size = UDim2.new(1, -8, 0, itemH), Parent = listF,
						}, { corner(6), pad(0, 8) })
						bind(b.MouseButton1Click, function()
							if type(it) == "table" and not it.name then close() return end
							value.Text = tostring(disp)
							close()
							if cb then task.spawn(cb, name) end
						end)
					end
					local total = #items * (itemH + 3) + 8
					listF.Size = UDim2.new(1, 0, 0, math.min(total, mobile and 140 or 170))
				end
				bind(head.MouseButton1Click, function()
					if listF.Visible then close() else refresh() listF.Visible = true end
				end)
				return {
					Set = function(_, v) value.Text = tostring(v) end,
					Get = function() return value.Text end,
					Refresh = function() if listF.Visible then refresh() end end,
				}
			end

			return tab
		end

		return win
	end

	return M
end)()

--====================================================================
-- mikuHub app
--====================================================================
local ui = {}
local alive = true
local win = MiniUI.Window({ Title = "mikuHub", Subtitle = "made by miku", Mode = "Auto" })
ui.win = win

local function status(t) win:SetStatus((tostring(t):gsub("^%s+", ""))) end
StatusLabelRef = setmetatable({}, { __newindex = function(_, k, v) if k == "Text" then status(v) end end })
ProgressBarFillRef = win.ProgressFill

local function notify(a, b, c) win:Notify(a, b, c) end

--------------------------------------------------------------------
-- shared helpers
--------------------------------------------------------------------
local function neededFor(blockName, blocks)
	local needed, regular = 0, isRegularBlock(blockName)
	for _, bi in pairs(blocks) do
		local sz = nil
		if regular and bi and bi.Size and bi.Size ~= "" then
			sz = strV3(bi.Size) * (Settings.buildScale or 1)
		end
		needed = needed + (regular and calcSlots(sz) or 1)
	end
	return needed
end

local function currentBuildCount()
	local total = 0
	if currentBuild then
		for name, bs in pairs(currentBuild) do
			if type(bs) == "table" then total = total + neededFor(name, bs) end
		end
	end
	return total
end

local blocksText, counterLbl
local function refreshBlocks()
	if not blocksText then return end
	if not currentBuild or not next(currentBuild) then
		blocksText:Set("Load a build first (Build tab).")
		return
	end
	local names = {}
	for n, bs in pairs(currentBuild) do if type(bs) == "table" then names[#names + 1] = n end end
	table.sort(names)
	local lines, short = {}, 0
	for _, n in ipairs(names) do
		local need = neededFor(n, currentBuild[n])
		local have = getRealBlockCount(n)
		local bad = (not Settings.infBlockEnabled) and have < need
		if bad then short = short + 1 end
		lines[#lines + 1] = string.format('%s<b>%s</b>  %d / %d%s',
			bad and '<font color="#FF6B6B">' or '<font color="#48CDB0">', n, have, need, '</font>')
	end
	table.insert(lines, 1, string.format("<b>%d</b> block types, <b>%d</b> total slots. %s", #names, currentBuildCount(),
		short > 0 and ('<font color="#FF6B6B">' .. short .. ' type(s) short.</font>') or '<font color="#48CDB0">Looks good.</font>'))
	blocksText:Set(table.concat(lines, "\n"))
end
updateBlocksDisplayGlobal = refreshBlocks

local function loadByName(fName)
	task.spawn(function()
		local ok, err = pcall(function()
			local lb, lf = loadBuildFromFile(fName)
			if not lb then status("File not found: " .. fName) return end
			if lf == "Asu" then currentBuild = convertAsuToPRS(lb) else currentBuild = lb end
			if currentBuild and next(currentBuild) then
				if Settings.autoPreview then createPreview(currentBuild) end
				refreshBlocks()
				status("Loaded " .. fName .. "  (" .. currentBuildCount() .. " blocks)")
			else
				status("Build is empty")
			end
		end)
		if not ok then status("Load error: " .. tostring(err)) end
	end)
end

local function refreshPreviewIfActive()
	if previewActive and currentBuild and next(currentBuild) then
		pcall(createPreview, currentBuild, selectedObjectName)
	end
end

--------------------------------------------------------------------
-- GUIDE
--------------------------------------------------------------------
local guide = win:Tab("Guide")
local function G(title, text, open) guide:Collapsible(title, text, open) end
guide:Paragraph("Tap a title to open or close it.")

G("1. Quick start",
	"1. Put a <b>.Build</b> file in your executor's <b>workspace/mikuHub</b> folder.\n"
	.. "2. Open the <b>Build</b> tab, press <b>Refresh file list</b>, open <b>Build file</b> and tap your file.\n"
	.. "3. A see-through ghost of the build appears (Auto preview). Open the <b>Blocks</b> tab to see if you are missing any blocks.\n"
	.. "4. Resize or move it with the <b>Scale</b> and <b>Offset</b> boxes if needed.\n"
	.. "5. Press <b>Build</b> and keep your tools equipped until the bottom bar says <b>Build finished</b>.", true)

G("2. Controls and layout",
	(win.Mobile
		and "<b>Open / close:</b> tap the <b>x</b> in the title bar to hide the menu, then tap the <b>🎧</b> button at the top-center to bring it back.\n"
		or "<b>Open / close:</b> press <b>RightShift</b>, or click the <b>x</b> in the title bar.\n")
	.. "<b>Move:</b> drag the title bar.\n"
	.. "<b>Tabs:</b> " .. (win.Mobile and "the row under the title bar (swipe it sideways)." or "the list on the left.") .. "\n"
	.. "<b>Status bar:</b> the strip at the bottom shows what mikuHub is doing. The thin line above it is the progress bar while building.\n"
	.. "<b>Pop-ups:</b> short messages appear in the corner for things like 'Saved' or 'Build finished'.\n"
	.. "<b>Sliders:</b> tap or drag anywhere on the slider row.\n"
	.. "<b>Dropdowns:</b> tap the row to open the list, tap an item to choose it.")

G("3. Files and folders",
	"<b>Where:</b> your executor's <b>workspace</b> folder, inside <b>mikuHub</b>. mikuHub creates that folder the first time it runs.\n"
	.. "• Windows executors: executor folder, then workspace, then mikuHub\n"
	.. "• Mobile executors: the executor's app folder, then Workspace, then mikuHub\n\n"
	.. "<b>File types:</b>\n"
	.. "• <b>.Build / .build</b> - ready to build. These fill the Build file list.\n"
	.. "• <b>.json</b> - image data from Geometrize (see Image loader)\n"
	.. "• <b>.obj</b> - 3D mesh\n"
	.. "• <b>.schem / .schematic</b> - Minecraft build\n"
	.. "• Roblox models need no file, only an asset ID.\n\n"
	.. "<b>Good to know:</b> subfolders (3 levels deep) are scanned, an old <b>SOPERA_WORKSPACE</b> folder is still read, and the loader recognizes some other build formats automatically. New or copied files show up after you press <b>Refresh file list</b>. Your options are saved in <b>mikuHub_Settings.json</b> in the workspace.")

G("4. Building, step by step",
	"<b>Load:</b> Build tab, then <b>Build file</b>. You can also type a file name (without .Build) in <b>File name</b>.\n\n"
	.. "<b>Preview:</b> a ghost copy of the build shows where it will go. <b>Preview</b> toggles it, <b>Highlight part</b> lights up one block type so you can see where it is.\n\n"
	.. "<b>Blocks tab:</b> every block type with owned / needed. Green is fine, red means you are short. Press <b>Refresh</b> after buying or changing scale.\n\n"
	.. "<b>Build:</b> places everything. Keep all your tools equipped until it finishes. The counter shows total blocks and how many you have placed.\n\n"
	.. "<b>Stop Build:</b> stops after the current step. You can build again afterwards.")

G("5. Scale, offset and speed",
	"<b>Scale</b> (0.01 to 20, default 1) multiplies the whole build's size.\n"
	.. "<b>X / Y / Z offset</b> shift the whole build in studs. Y lifts it up (default 3 so it does not sink into the ground).\n"
	.. "<b>Build speed:</b> 0 builds as fast as possible, 1 to 10 adds a delay between blocks (higher is slower but gentler).\n\n"
	.. "Press Enter or tap outside the box to apply. The ghost preview and block counts update automatically.")

G("6. Not enough blocks / Inf Block",
	"If you own less than the build needs, <b>Build</b> warns you with the percentage you own and does nothing the first time.\n"
	.. "• Press <b>Build</b> again within 8 seconds to build anyway.\n"
	.. "• Or switch on <b>Inf Block</b> (Exploit tab) first. Switching it on also hides the red 'short' warnings in the Blocks tab.")

G("7. Copy a player's build",
	"1. Build tab, <b>Copy a player's build</b> section: choose the <b>Player</b>.\n"
	.. "2. Type a name in <b>File name</b> at the top of the tab.\n"
	.. "3. Press <b>Save player's build</b>. The status bar says how many blocks were saved.\n"
	.. "4. The new .Build appears in the Build file list (press Refresh if not).")

G("8. Image loader (picture to build)",
	"The script reads a <b>.json file</b> that you save from the Geometrize website. It does <b>not</b> take a link or an image URL.\n\n"
	.. "<b>Step 1 - make the JSON</b>\n"
	.. "Open https://www.samcodes.co.uk/project/geometrize-haxe-web/ in your browser and upload your image. Open its settings and set:\n"
	.. "• Turn off every shape type except <b>Rotated Rectangles</b>\n"
	.. "• Shape Opacity: <b>255</b>\n"
	.. "• Initial Background Opacity: <b>255</b>\n"
	.. "• Random Shapes Per Step: <b>100</b>\n"
	.. "• Shape Mutations Per Step: <b>100</b>\n"
	.. "Let it finish drawing, then <b>save as JSON</b>.\n\n"
	.. "<b>Step 2 - put it in place</b>\nMove the .json into <b>workspace/mikuHub</b>.\n\n"
	.. "<b>Step 3 - convert</b>\n"
	.. "Convert tab: <b>Pick file</b> (or type the name), set <b>Output name</b> and <b>Material</b>, then in the Image JSON section press <b>Convert image JSON</b>.\n"
	.. "• <b>Scale</b> (default 0.035) sets the size, or fill <b>Width / Length</b> in studs (0 means use scale)\n"
	.. "• <b>Thickness</b> 0.001 keeps it flat\n\n"
	.. "<b>Step 4 - build it</b>\nBuild tab, <b>Refresh file list</b>, pick your new build and build it like any other.")

G("9. 3D meshes (.obj)",
	"Put the .obj in the folder, pick it in the Convert tab, then fill the 3D mesh section:\n"
	.. "• <b>Scale</b> and <b>Thickness</b> of the panels/blocks\n"
	.. "• <b>Mode:</b> Face (thin panels from the mesh faces), Solid (fills the model), Wireframe (edges only), Voxel (blocky cubes)\n"
	.. "• <b>Detail</b> (0.2 to 3) - higher means more blocks and finer shape\n"
	.. "• <b>Colors:</b> Random, or Custom with the red / green / blue sliders\n"
	.. "Press <b>Convert mesh</b>. Big meshes make huge builds - start with a small scale.")

G("10. Minecraft schematics",
	"Put the .schem or .schematic file in the folder and pick it in the Convert tab. Set <b>Studs per block</b> (how big each Minecraft block is) and press <b>Convert schematic</b>. Neighbouring blocks of the same color are merged to keep the block count down.")

G("11. Roblox model by asset ID",
	"Convert tab, Roblox model section: type the numeric <b>Asset ID</b>, set <b>Scale</b> and the <b>Output name</b> at the top, then press <b>Import Roblox model</b>. The result is saved as a normal .Build. If the import fails, the status bar and a pop-up show the reason.")

G("12. Auto Farm",
	"<b>Farm</b> tab:\n"
	.. "• <b>Step delay</b> - seconds spent at each stage (default 2, minimum 0.5). If it skips stages, raise it.\n"
	.. "• Switch <b>Auto Farm</b> on. mikuHub teleports you through all the stages in order, claims the gold at the end, then repeats.\n"
	.. "• A see-through platform sits under you while it runs. It is rebuilt if you respawn.\n"
	.. "• The stats line shows runs, time, gold earned and gold per hour.\n"
	.. "• Switch it off to stop. If it says 'remote not found' you are probably in the wrong game.")

G("13. Exploit tab",
	"• <b>Inf Block</b> - build without owning the blocks\n"
	.. "• <b>Equip build tools</b> - puts all your build tools in hand\n"
	.. "• <b>NoClip</b> - walk through walls\n"
	.. "• <b>Fly</b> - moves where the camera points. " .. (win.Mobile and "Use the move stick." or "WASD to move, Space up, Left Ctrl down.") .. " Change the speed with the slider.\n"
	.. "• <b>WalkSpeed / JumpPower</b> - sliders, kept after you respawn")

G("14. Settings and unloading",
	"• <b>Auto preview on load</b> - show the ghost as soon as a file loads\n"
	.. "• <b>Save settings</b> - stores your options for next time\n"
	.. "• <b>Unload mikuHub</b> - stops building/farming, removes the preview and closes the menu completely. Run the script again to bring it back.")

G("15. Troubleshooting",
	"<b>File not in the list:</b> check it is in workspace/mikuHub, the extension is .Build, then press Refresh file list.\n"
	.. "<b>'File not found':</b> type the name without the extension, or pick it from the dropdown.\n"
	.. "<b>Convert error:</b> check Source path and the extension (.json, .obj, .schem), and that Output name is filled in.\n"
	.. "<b>Build stops or skips blocks:</b> keep all tools equipped, raise Build speed, and check the Blocks tab for missing blocks.\n"
	.. "<b>Menu vanished:</b> " .. (win.Mobile and "tap the 🎧 button at the top-center." or "press RightShift.") .. "\n"
	.. "<b>Script will not start:</b> the executor console prints a '[mikuHub] failed to start' message - that tells you why.")

--------------------------------------------------------------------
-- BUILD
--------------------------------------------------------------------
local build = win:Tab("Build")
local fileInput, fileDD, previewBtn

build:Section("Load a build")
fileInput = build:Input("File name", "name without .Build", "")
fileDD = build:Dropdown("Build file", getSavedBuilds, function(name)
	fileInput:Set(name)
	loadByName(name)
end)
build:Button("Refresh file list", function()
	invalidateSearchCache()
	_buildFilesCache = nil
	fileDD:Refresh()
	notify("Files", #getSavedBuilds() .. " build(s) found")
end)

build:Section("Build")
counterLbl = build:Label("Blocks: 0 | Placed: 0")

local confirmUntil = 0
local function runBuild()
	if isBuilding then status("Already building!") return end
	local fn = (fileInput:Get() or ""):match("^%s*(.-)%s*$")
	if fn ~= "" then
		status("Loading " .. fn .. "...")
		local lb, lf = loadBuildFromFile(fn)
		if not lb then status("File not found: " .. fn) return end
		if lf == "Asu" then currentBuild = convertAsuToPRS(lb) else currentBuild = lb end
	end
	if not currentBuild or not next(currentBuild) then status("Pick or type a build file first") return end
	if currentBuildCount() == 0 then status("No blocks found") return end

	if not Settings.infBlockEnabled then
		local needed, have = 0, 0
		for name, blocks in pairs(currentBuild) do
			if type(blocks) == "table" then
				local n = neededFor(name, blocks)
				needed = needed + n
				have = have + math.min(getRealBlockCount(name), n)
			end
		end
		if needed > have and have > 0 and tick() > confirmUntil then
			confirmUntil = tick() + 8
			notify("Not enough blocks", math.floor(have / needed * 100) .. "% owned. Press Build again to force.", 5)
			status("Short on blocks - press Build again within 8s to continue, or enable Inf Block")
			return
		end
	end
	confirmUntil = 0

	refreshBlocks()
	win:SetProgress(0)
	status("Keep all tools equipped until the build finishes")
	task.wait(0.8)
	local placedIds
	local ok, err = pcall(function()
		local good, ids = pasteBuild(currentBuild, function(msg, pct)
			status(msg)
			win:SetProgress((pct or 0) / 100)
		end)
		placedIds = ids
		return good
	end)
	if not ok then
		status("Build error: " .. tostring(err))
		playUISound(UISoundConfig.error)
	elseif stopBuild then
		status("Build stopped")
	else
		status("Build finished")
		notify("mikuHub", "Build finished!")
		playUISound(UISoundConfig.success)
		if placedIds then
			recentlyPlacedBlocks = {}
			for _, blk in pairs(placedIds) do
				if type(blk) == "userdata" and blk:FindFirstChild("PPart") then recentlyPlacedBlocks[blk] = true end
			end
		end
	end
	stopBuild = false
	isBuilding = false
	pcall(function()
		local sf = LocalPlayer:FindFirstChild("Settings")
		local sb = sf and sf:FindFirstChild("ShareBlocks")
		if sb then sb.Value = shareBlocksOriginal end
	end)
end

build:Button("Build", function() runBuild() end)
build:Button("Stop Build", function()
	if isBuilding then stopBuild = true status("Stopping...") else status("Not building") end
end)
previewBtn = build:Button("Preview", function()
	if not currentBuild or not next(currentBuild) then status("No build loaded") return end
	if previewActive then
		clearPreview()
		status("Preview cleared")
	else
		createPreview(currentBuild)
		status("Preview created")
	end
end)
updatePreviewButtonGlobal = function() previewBtn:SetText(previewActive and "Clear Preview" or "Preview") end
build:Dropdown("Highlight part", function()
	local t = {}
	if currentBuild then for n in pairs(currentBuild) do t[#t + 1] = n end end
	table.sort(t)
	return t
end, function(n)
	selectedObjectName = n
	pcall(updateSelectionHighlight, n)
end)

build:Section("Scale, offset, speed")
build:Input("Scale", "1.0", tostring(Settings.buildScale), function(txt)
	local v = tonumber(txt)
	if v and v >= 0.01 and v <= 20 then
		Settings.buildScale = v
		refreshPreviewIfActive()
		refreshBlocks()
	else
		notify("Scale", "Use a number from 0.01 to 20")
	end
end)
for _, ax in ipairs({ { "X", "buildOffsetX" }, { "Y", "buildOffsetY" }, { "Z", "buildOffsetZ" } }) do
	build:Input(ax[1] .. " offset", "0", tostring(Settings[ax[2]]), function(txt)
		local v = tonumber(txt)
		if v then Settings[ax[2]] = v refreshPreviewIfActive() end
	end)
end
build:Input("Build speed", "0 = instant, 1-10 = delay", tostring(Settings.buildSpeed or 0), function(txt)
	Settings.buildSpeed = math.clamp(tonumber(txt) or 0, 0, 10)
end)

build:Section("Copy a player's build")
build:Dropdown("Player", getPlayerList, function(n) selectedPlayer = Players:FindFirstChild(n) end)
build:Button("Save player's build", function()
	if not selectedPlayer then status("Select a player first!") return end
	local fn = (fileInput:Get() or ""):match("^%s*(.-)%s*$")
	if fn == "" then status("Type a file name first!") return end
	status("Copying build from " .. selectedPlayer.Name .. "...")
	task.spawn(function()
		local data = copyBuild()
		if not data or not next(data) then status("No blocks found for " .. selectedPlayer.Name) return end
		local ok, fmt = saveBuildToFile(fn, data)
		if ok then
			_buildFilesCache = nil
			fileDD:Refresh()
			local count = 0
			for _, bl in pairs(data) do if type(bl) == "table" then count = count + #bl end end
			status("Saved " .. count .. " blocks to " .. fn .. " (" .. tostring(fmt or "?") .. ")")
			notify("Saved", fn .. ".Build")
		else
			status("Save failed!")
		end
	end)
end)

task.spawn(function()
	while alive do
		pcall(function()
			local placed = 0
			local mine = BlocksFolder and BlocksFolder:FindFirstChild(LocalPlayer.Name)
			if mine then placed = #mine:GetChildren() end
			counterLbl:Set("Blocks: " .. currentBuildCount() .. "  |  Placed: " .. placed)
		end)
		task.wait(0.6)
	end
end)

--------------------------------------------------------------------
-- CONVERT
--------------------------------------------------------------------
local conv = win:Tab("Convert")
local convPath, convOut, convMat = nil, nil, "PlasticBlock"
local CONV_EXT = { json = true, obj = true, schem = true, schematic = true }

local function listConvFiles()
	local out, seen = {}, {}
	local function scan(dir, depth)
		if depth > 3 then return end
		local ok, items = pcall(listfiles, dir)
		if not ok or type(items) ~= "table" then return end
		for _, fp in ipairs(items) do
			if isfolder(fp) then
				scan(fp, depth + 1)
			else
				local nm = fp:match("([^/\\]+)$") or fp
				local ext = (nm:match("%.([%w]+)$") or ""):lower()
				if CONV_EXT[ext] and not seen[fp] then
					seen[fp] = true
					out[#out + 1] = { name = fp, display = nm }
				end
			end
		end
	end
	scan(FOLDER_PATH, 0)
	table.sort(out, function(a, b) return a.display:lower() < b.display:lower() end)
	return out
end

local function listMaterials()
	local opts = {}
	pcall(function()
		for _, bp in ipairs(BuildingParts:GetChildren()) do
			if bp.Name:sub(-5) == "Block" then opts[#opts + 1] = bp.Name end
		end
	end)
	if #opts == 0 then
		opts = { "PlasticBlock", "WoodBlock", "MetalBlock", "TitaniumBlock", "GlassBlock", "NeonBlock", "FabricBlock", "GraniteBlock",
			"MarbleBlock", "SlateBlock", "BrickBlock", "CobblestoneBlock", "ConcreteBlock", "IceBlock", "SandBlock", "GrassBlock" }
	end
	table.sort(opts, function(a, b) return a:lower() < b:lower() end)
	return opts
end

local function convDone(outPath, err)
	if err then
		status("Convert error: " .. tostring(err))
		notify("Convert failed", tostring(err), 5)
		playUISound(UISoundConfig.error)
		return
	end
	_buildFilesCache = nil
	fileDD:Refresh()
	status("Saved: " .. tostring(outPath))
	notify("Converted!", tostring(outPath), 4)
	playUISound(UISoundConfig.success)
end

local function resolveSource()
	local full, perr = resolveConverterPath(convPath:Get())
	if not full then status(tostring(perr)) end
	return full
end
local function outName()
	local n = trimStr(convOut:Get())
	if n == "" then status("Enter an output build name") return nil end
	return n
end

conv:Section("Source and output")
conv:Paragraph("Image JSON: make it on the Geometrize website, save the .json into the mikuHub folder, then pick it here. mikuHub reads the file, not a link. Full steps are in Guide, section 8.")
conv:Dropdown("Pick file", listConvFiles, function(fp) convPath:Set(fp) end)
convPath = conv:Input("Source path", "file name or full path", "")
convOut = conv:Input("Output name", "new build name", "converted")
conv:Dropdown("Material", listMaterials, function(m) convMat = m end, "PlasticBlock")

conv:Section("Image JSON (Geometrize) -> build")
local jScale = conv:Input("Scale", "0.035", "0.035")
local jW = conv:Input("Width studs", "0 = use scale", "0")
local jL = conv:Input("Length studs", "0 = use scale", "0")
local jT = conv:Input("Thickness", "0.001", "0.001")
conv:Button("Convert image JSON", function()
	local full, name = resolveSource(), outName()
	if not full or not name then return end
	if not full:lower():match("%.json$") then status("Source must be a .json file") return end
	local ok, res, err = pcall(function()
		return convertGeometrizeJsonToBuild(readfile(full), name, tonumber(jScale:Get()) or 0.035, tonumber(jT:Get()) or 0.001,
			convMat, tonumber(jW:Get()) or 0, tonumber(jL:Get()) or 0)
	end)
	if not ok then convDone(nil, res) else convDone(res, err) end
end)

conv:Section("3D mesh (.obj) -> build")
local oScale = conv:Input("Scale", "1", "1")
local oThick = conv:Input("Thickness", "0.2", "0.2")
local oDetail = conv:Input("Detail", "0.2 - 3", "1")
local objMode, objColor = "solid", "custom"
conv:Dropdown("Mode", function()
	return { { name = "face", display = "Face" }, { name = "solid", display = "Solid" },
		{ name = "wireframe", display = "Wireframe" }, { name = "voxel", display = "Voxel" } }
end, function(m) objMode = m end, "Solid")
conv:Dropdown("Colors", function()
	return { { name = "random", display = "Random" }, { name = "custom", display = "Custom" } }
end, function(m) objColor = m end, "Custom")
local cR = conv:Slider("Custom red", 0, 255, 102, nil, 1)
local cG = conv:Slider("Custom green", 0, 255, 153, nil, 1)
local cB = conv:Slider("Custom blue", 0, 255, 255, nil, 1)
conv:Button("Convert mesh", function()
	local full, name = resolveSource(), outName()
	if not full or not name then return end
	local colorOpts = {
		colorMode = objColor, detail = math.clamp(tonumber(oDetail:Get()) or 1, 0.2, 3),
		customR = cR:Get() / 255, customG = cG:Get() / 255, customB = cB:Get() / 255,
		grad1R = 1, grad1G = 0.3, grad1B = 0.1, grad2R = 0.1, grad2G = 0.3, grad2B = 1, gradDir = "y_asc",
	}
	status("Converting mesh...")
	task.spawn(function()
		local ok, res, err = pcall(function()
			return convertObjToBuild(full, name, tonumber(oScale:Get()) or 1, tonumber(oThick:Get()) or 0.2, convMat, objMode, colorOpts)
		end)
		if not ok then convDone(nil, res) else convDone(res, err) end
	end)
end)

conv:Section("Minecraft schematic -> build")
local sScale = conv:Input("Studs per block", "1", "1")
conv:Button("Convert schematic", function()
	local full, name = resolveSource(), outName()
	if not full or not name then return end
	status("Converting schematic...")
	task.spawn(function()
		local ok, res, err = pcall(function()
			return convertMinecraftSchematicToBuild(full, name, tonumber(sScale:Get()) or 1, convMat)
		end)
		if not ok then convDone(nil, res) else convDone(res, err) end
	end)
end)

conv:Section("Roblox model asset -> build")
local aId = conv:Input("Asset ID", "e.g. 123456789", "")
local aScale = conv:Input("Scale", "1", "1")
conv:Button("Import Roblox model", function()
	local name = outName()
	if not name then return end
	status("Importing asset...")
	task.spawn(function()
		local blocks, err = convertRobloxAssetToBlocks(aId:Get(), tonumber(aScale:Get()) or 1)
		if not blocks then convDone(nil, err or "import failed") return end
		local outPath, werr = writeConvertedBuild(name, convMat, blocks)
		convDone(outPath, (not outPath) and (werr or "save failed") or nil)
	end)
end)

--------------------------------------------------------------------
-- BLOCKS
--------------------------------------------------------------------
local blocks = win:Tab("Blocks")
blocks:Section("Required blocks")
blocks:Button("Refresh", function() refreshBlocks() end)
blocksText = blocks:Paragraph("Load a build first (Build tab).")

--------------------------------------------------------------------
-- FARM
--------------------------------------------------------------------
local farm = win:Tab("Farm")
local farmStats, farmToggle
local farmPlatform = nil
local farmStep = 2

local function farmPlatformMake()
	if farmPlatform and farmPlatform.Parent then farmPlatform:Destroy() end
	farmPlatform = Instance.new("Part")
	farmPlatform.Name = "mikuHub_FarmPlat"
	farmPlatform.Size = Vector3.new(12, 1, 12)
	farmPlatform.Anchored = true
	farmPlatform.CanCollide = true
	farmPlatform.Transparency = 0.8
	farmPlatform.Material = Enum.Material.ForceField
	farmPlatform.Color = Color3.fromRGB(72, 205, 176)
	farmPlatform.Parent = Workspace
end
local function farmPlatformRemove()
	if farmPlatform and farmPlatform.Parent then farmPlatform:Destroy() end
	farmPlatform = nil
end
local function updFarmStats()
	local s = getFarmStats()
	farmStats:Set(string.format("Runs: %d  |  Time: %s  |  Earned: %s  |  %s/hr", s.runs, s.time, tostring(s.earned), tostring(s.rate)))
end

farm:Section("Auto Farm")
farmStats = farm:Label("Runs: 0  |  Time: 0:00  |  Earned: 0")
farm:Input("Step delay (s)", "default 2", "2", function(txt)
	farmStep = math.max(0.5, tonumber(txt) or 2)
end)
farmToggle = farm:Toggle("Auto Farm", false, function(on)
	if on then
		if farmState.active then return end
		farmState.active = true
		farmState.startTime = tick()
		task.spawn(function() while farmState.active and alive do updFarmStats() task.wait(1) end end)
		task.spawn(function()
			local claimRF = safeWaitChild(workspace, "ClaimRiverResultsGold", 5)
			if not claimRF then
				status("Farm: remote not found")
				notify("Auto Farm", "Remote not found - are you in the right game?", 4)
				farmState.active = false
				farmToggle:Set(false, true)
				return
			end
			farmPlatformMake()
			while farmState.active and alive do
				local before = getGold()
				for i, pos in ipairs(farmState.positions) do
					if not farmState.active then break end
					local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
					if not hrp then status("Farm: no character") task.wait(2) break end
					if farmPlatform and farmPlatform.Parent then farmPlatform.CFrame = CFrame.new(pos.X, pos.Y - 3.5, pos.Z) end
					hrp.CFrame = CFrame.new(pos)
					status("Farm: stage " .. i .. "/" .. #farmState.positions)
					task.wait(farmStep)
				end
				if not farmState.active then break end
				pcall(function() claimRF:FireServer() end)
				task.wait(2)
				farmState.earned = farmState.earned + math.max(0, getGold() - before)
				farmState.runs = farmState.runs + 1
				status("Farm: run " .. farmState.runs .. " done")
				updFarmStats()
			end
			farmPlatformRemove()
			farmState.totalTime = farmState.totalTime + (tick() - farmState.startTime)
			farmState.active = false
			status("Farm stopped  |  " .. farmState.runs .. " runs")
			updFarmStats()
		end)
	else
		farmState.active = false
	end
end)
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(1)
	if farmState.active then farmPlatformMake() end
end)

--------------------------------------------------------------------
-- EXPLOIT
--------------------------------------------------------------------
local ex = win:Tab("Exploit")
ex:Section("Building")
ex:Toggle("Inf Block", Settings.infBlockEnabled, function(on)
	Settings.infBlockEnabled = on
	saveSettings()
	refreshBlocks()
end)
ex:Button("Equip build tools", function() pcall(equipAllTools) status("Tools equipped") end)

local function myHum() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") end
local function myHrp() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") end

ex:Section("Movement")
local noclipConn
ex:Toggle("NoClip", false, function(on)
	if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	if on then
		noclipConn = RunService.Stepped:Connect(function()
			local ch = LocalPlayer.Character
			if ch then
				for _, p in ipairs(ch:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
			end
		end)
	end
end)

local flySpeed, flyConn, flyBV, flyBG = 60, nil, nil, nil
local function stopFly()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
	local h = myHum()
	if h then h.PlatformStand = false end
end
local function startFly()
	local hrp, hum = myHrp(), myHum()
	if not hrp or not hum then return end
	hum.PlatformStand = true
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = hrp
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	flyBG.P = 9e4
	flyBG.Parent = hrp
	flyConn = RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		if not cam or not hrp.Parent then return end
		local md, look = hum.MoveDirection, cam.CFrame.LookVector
		local vel = Vector3.zero
		local flat = Vector3.new(look.X, 0, look.Z)
		if md.Magnitude > 0.05 and flat.Magnitude > 0.01 then
			flat = flat.Unit
			local right = Vector3.new(-flat.Z, 0, flat.X)
			vel = (look * md:Dot(flat) + cam.CFrame.RightVector * md:Dot(right)) * flySpeed
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, flySpeed, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, flySpeed, 0) end
		flyBV.Velocity = vel
		flyBG.CFrame = cam.CFrame
	end)
end
ex:Toggle("Fly", false, function(on)
	stopFly()
	if on then startFly() end
end)
ex:Slider("Fly speed", 10, 500, 60, function(v) flySpeed = v end, 5)

local wantWalk, wantJump = nil, nil
ex:Slider("WalkSpeed", 16, 200, 16, function(v)
	wantWalk = v
	local h = myHum()
	if h then h.WalkSpeed = v end
end)
ex:Slider("JumpPower", 50, 300, 50, function(v)
	wantJump = v
	local h = myHum()
	if h then h.UseJumpPower = true h.JumpPower = v end
end)
LocalPlayer.CharacterAdded:Connect(function(ch)
	local h = ch:WaitForChild("Humanoid", 10)
	if not h then return end
	if wantWalk then h.WalkSpeed = wantWalk end
	if wantJump then h.UseJumpPower = true h.JumpPower = wantJump end
end)

--------------------------------------------------------------------
-- SETTINGS / ABOUT
--------------------------------------------------------------------
local st = win:Tab("Settings")
st:Section("Options")
st:Toggle("Auto preview on load", Settings.autoPreview, function(on) Settings.autoPreview = on end)
st:Button("Save settings", function() saveSettings() notify("Settings", "Saved") end)
st:Button("Unload mikuHub", function()
	alive = false
	stopBuild = true
	farmState.active = false
	pcall(stopFly)
	if noclipConn then noclipConn:Disconnect() end
	pcall(clearPreview)
	pcall(farmPlatformRemove)
	pcall(saveSettings)
	task.wait(0.1)
	win:Destroy()
end)
st:Section("About")
st:Paragraph("<b>mikuHub</b>  -  made by miku 🎧\nTQQ theme. Build, convert and farm helper.\n\nBuild engine based on the AutoBuilder script by SoPeRa; interface rewritten for mikuHub.")

win:Select(build)
notify("mikuHub loaded", win.Mobile and "Tap 🎧 to reopen the menu" or "RightShift toggles the menu", 4)
status("Ready - open the Guide tab if you're new")
end

local okMain, errMain = xpcall(mikuHubMain, debug.traceback)
if not okMain then warn("[mikuHub] failed to start:\n" .. tostring(errMain)) end
