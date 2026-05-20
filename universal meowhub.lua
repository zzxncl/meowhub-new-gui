getgenv().MeowHubSource = [====[

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Player = Players.LocalPlayer

if game.CoreGui:FindFirstChild("MeowHub") then
    game.CoreGui:FindFirstChild("MeowHub"):Destroy()
end

local presenceEnabled = true
local showPresenceTags = true
local guiToggleKey = Enum.KeyCode.RightShift
local guiVisible = true
local autoTeleport = true
local serverHopMode = "Lowest Players"
local currentThemeName = "Obsidian"
local customBg = "#1e1e1e"
local customAccent = "#7551cc"
local currentConfigName = "default"
local savedConfigsList = {"default"}

local presenceBucket = "meowhub_presence_v2"
local gameJobId = (game.JobId ~= "" and game.JobId) or "studio_testing"
local playerUserId = tostring(Player.UserId)
local lastPresenceKey = nil

local Colors = {
    BgTitlebar   = Color3.fromRGB(22, 22, 22),
    BgRibbon     = Color3.fromRGB(26, 26, 26),
    BgSidebar    = Color3.fromRGB(28, 28, 28),
    BgEditor     = Color3.fromRGB(30, 30, 30),
    BgRowHover   = Color3.fromRGB(37, 37, 37),
    Border       = Color3.fromRGB(45, 45, 45),
    BorderLight  = Color3.fromRGB(55, 55, 55),

    Accent       = Color3.fromRGB(117, 81, 204),
    AccentHover  = Color3.fromRGB(135, 100, 224),
    AccentFaint  = Color3.fromRGB(60, 48, 90),

    TextNormal   = Color3.fromRGB(226, 226, 227),
    TextMuted    = Color3.fromRGB(154, 154, 156),
    TextFaint    = Color3.fromRGB(104, 104, 106),

    Success      = Color3.fromRGB(72, 191, 132),
    Error        = Color3.fromRGB(235, 87, 87),
}

local ThemeRegistry = {}
local selectCategory, Categories -- Forward declarations
local activeCategoryIdx = 1

local function pruneRegistry()
    local active = {}
    for _, item in ipairs(ThemeRegistry) do
        if item.Element and item.Element.Parent then
            table.insert(active, item)
        end
    end
    ThemeRegistry = active
end

local function reg(element, role, prop)
    table.insert(ThemeRegistry, {
        Element = element,
        Role = role,
        Property = prop or "BackgroundColor3"
    })
    if Colors[role] then
        element[prop or "BackgroundColor3"] = Colors[role]
    end
end

local function hexToColor3(hex)
    hex = hex:gsub("#", "")
    if #hex == 3 then
        return Color3.fromRGB(
            tonumber(hex:sub(1,1):rep(2), 16),
            tonumber(hex:sub(2,2):rep(2), 16),
            tonumber(hex:sub(3,3):rep(2), 16)
        )
    elseif #hex == 6 then
        return Color3.fromRGB(
            tonumber(hex:sub(1,2), 16),
            tonumber(hex:sub(3,4), 16),
            tonumber(hex:sub(5,6), 16)
        )
    end
    return nil
end

local function color3ToHex(color)
    local r = math.round(color.R * 255)
    local g = math.round(color.G * 255)
    local b = math.round(color.B * 255)
    return string.format("#%02x%02x%02x", r, g, b)
end

local function generateThemePalette(bgCol, accentCol)
    local function darken(col, factor)
        return Color3.new(
            math.clamp(col.R * factor, 0, 1),
            math.clamp(col.G * factor, 0, 1),
            math.clamp(col.B * factor, 0, 1)
        )
    end
    
    local function lighten(col, factor)
        return Color3.new(
            math.clamp(col.R * factor, 0, 1),
            math.clamp(col.G * factor, 0, 1),
            math.clamp(col.B * factor, 0, 1)
        )
    end

    return {
        BgEditor    = bgCol,
        BgSidebar   = darken(bgCol, 0.93),
        BgRibbon    = darken(bgCol, 0.87),
        BgTitlebar  = darken(bgCol, 0.75),
        BgRowHover  = lighten(bgCol, 1.23),
        Border      = lighten(bgCol, 1.50),
        BorderLight = lighten(bgCol, 1.83),
        
        Accent      = accentCol,
        AccentHover = lighten(accentCol, 1.15),
        AccentFaint = darken(accentCol, 0.50),
        
        TextNormal  = Color3.fromRGB(226, 226, 227),
        TextMuted   = Color3.fromRGB(154, 154, 156),
        TextFaint  = Color3.fromRGB(104, 104, 106),
        
        Success     = Color3.fromRGB(72, 191, 132),
        Error       = Color3.fromRGB(235, 87, 87)
    }
end

local PredefinedThemes = {
    Obsidian = {
        Bg = Color3.fromRGB(30, 30, 30),
        Accent = Color3.fromRGB(117, 81, 204)
    },
    Nord = {
        Bg = Color3.fromRGB(46, 52, 64),
        Accent = Color3.fromRGB(136, 192, 208)
    },
    Monokai = {
        Bg = Color3.fromRGB(39, 40, 34),
        Accent = Color3.fromRGB(249, 38, 114)
    },
    Crimson = {
        Bg = Color3.fromRGB(26, 15, 15),
        Accent = Color3.fromRGB(224, 62, 62)
    },
    Sakura = {
        Bg = Color3.fromRGB(45, 31, 39),
        Accent = Color3.fromRGB(255, 121, 198)
    },
    Custom = {
        Bg = Color3.fromRGB(30, 30, 30),
        Accent = Color3.fromRGB(117, 81, 204)
    }
}

local function applyTheme(themeColors)
    pruneRegistry()
    for role, color in pairs(themeColors) do
        Colors[role] = color
    end
    for _, item in ipairs(ThemeRegistry) do
        pcall(function()
            local targetVal = Colors[item.Role]
            if targetVal then
                local t = TweenService:Create(item.Element, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [item.Property] = targetVal })
                t:Play()
            end
        end)
    end
end

local function applyThemeByName(name)
    currentThemeName = name
    local theme = PredefinedThemes[name]
    if name == "Custom" then
        local customBgCol = hexToColor3(customBg) or Color3.fromRGB(30, 30, 30)
        local customAccentCol = hexToColor3(customAccent) or Color3.fromRGB(117, 81, 204)
        local palette = generateThemePalette(customBgCol, customAccentCol)
        applyTheme(palette)
    elseif theme then
        local palette = generateThemePalette(theme.Bg, theme.Accent)
        applyTheme(palette)
    end
    if selectCategory and Categories[activeCategoryIdx] and Categories[activeCategoryIdx].IsSettingsPage then
        selectCategory(activeCategoryIdx)
    end
end

local function tween(obj, duration, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function getExecutorName()
    if identifyexecutor then
        local name, version = identifyexecutor()
        return name or "Unknown Executor"
    elseif syn then
        return "Synapse X"
    elseif krnl then
        return "Krnl"
    elseif fluxus then
        return "Fluxus"
    elseif exploit then
        return exploit
    elseif SCRIPT_ENGINE then
        return SCRIPT_ENGINE
    end
    return "Unknown Executor"
end

Categories = {
    {
        Name = "Info",
        Icon = "ℹ️",
        IsInfoPage = true,
        Scripts = {}
    },
    {
        Name = "Main",
        Icon = "📂",
        Scripts = {
            { Name = "Example Toggle", Desc = "An example toggle switch", Enabled = false }
        }
    },
    {
        Name = "Aimbot",
        Icon = "🎯",
        Scripts = {
            { Name = "Silent Aim", Desc = "Silently redirect displacement vectors", Enabled = false },
            { Name = "Trigger Bot", Desc = "Instantly discharge when crosshair intersects player", Enabled = false },
            { Name = "ESP Tracers", Desc = "Draw visual vectors to all active nodes", Enabled = false },
        }
    },
    {
        Name = "Utility",
        Icon = "👥",
        Scripts = {
            { Name = "Share Presence", Desc = "Let other script users see you are active", Enabled = true },
            { Name = "Render Tags", Desc = "Show overhead MeowHub badges on active users", Enabled = true },
            { Name = "Anti-AFK", Desc = "Bypass idle timeout disconnect protocols", Enabled = false },
            { Name = "Rejoin", Desc = "Rejoin the current server instance", Enabled = false, IsAction = true },
            { Name = "FPS Boost", Desc = "Toggles graphics settings to boost client FPS", Enabled = false }
        }
    },
    {
        Name = "Settings",
        Icon = "⚙️",
        IsSettingsPage = true,
        Scripts = {}
    }
}

local function httpRequest(options)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        local success, result = pcall(req, options)
        if success then return result end
    end
    return nil
end

local function cleanPresence()
    if lastPresenceKey then
        pcall(function()
            httpRequest({
                Url = "https://kvdb.io/" .. presenceBucket .. "/" .. lastPresenceKey,
                Method = "DELETE"
            })
        end)
        lastPresenceKey = nil
    end
end

local function updatePresenceState(isActive)
    if not presenceEnabled then
        cleanPresence()
        return
    end

    if lastPresenceKey then
        pcall(function()
            httpRequest({
                Url = "https://kvdb.io/" .. presenceBucket .. "/" .. lastPresenceKey,
                Method = "DELETE"
            })
        end)
        lastPresenceKey = nil
    end

    if isActive then
        local timestamp = os.time()
        local newKey = gameJobId .. "_" .. playerUserId .. "_" .. tostring(timestamp)
        local success = pcall(function()
            httpRequest({
                Url = "https://kvdb.io/" .. presenceBucket .. "/" .. newKey,
                Method = "POST",
                Body = "1"
            })
        end)
        if success then
            lastPresenceKey = newKey
        end
    end
end

local function getActivePeers()
    if not presenceEnabled then return {} end

    local url = "https://kvdb.io/" .. presenceBucket .. "/?prefix=" .. gameJobId .. "_"
    local res = httpRequest({
        Url = url,
        Method = "GET"
    })

    local active = {}
    if res and res.StatusCode == 200 then
        local success, keys = pcall(function()
            return HttpService:JSONDecode(res.Body)
        end)
        if success and type(keys) == "table" then
            local now = os.time()
            for _, k in ipairs(keys) do
                local uIdStr, tsStr = string.match(k, "^[^_]+_(%d+)_(%d+)$")
                if uIdStr and tsStr then
                    local uId = tonumber(uIdStr)
                    local ts = tonumber(tsStr)
                    if now - ts < 30 then
                        active[uId] = true
                    else
                        task.spawn(function()
                            httpRequest({
                                Url = "https://kvdb.io/" .. presenceBucket .. "/" .. k,
                                Method = "DELETE"
                            })
                        end)
                    end
                end
            end
        end
    end
    return active
end

local function clearHeadTag(character)
    if character then
        local tag = character:FindFirstChild("MeowTag")
        if tag then tag:Destroy() end
    end
end

local function applyHeadTag(player)
    local char = player.Character
    if not char then return end
    local head = char:WaitForChild("Head", 5)
    if not head then return end

    clearHeadTag(char)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "MeowTag"
    billboard.Adornee = head
    billboard.Size = UDim2.new(2.4, 0, 2.4, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 150
    billboard.Parent = char

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0.85, 0, 0.85, 0)
    bg.Position = UDim2.new(0.075, 0, 0.075, 0)
    bg.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    bg.BackgroundTransparency = 0.15
    bg.Parent = billboard

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 6)
    bgCorner.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color = Colors.Accent
    stroke.Thickness = 1.5
    stroke.Parent = bg

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.new(0.8, 0, 0.8, 0)
    img.Position = UDim2.new(0.1, 0, 0.1, 0)
    img.BackgroundTransparency = 1
    img.Image = "rbxassetid://110721752576238"
    img.ScaleType = Enum.ScaleType.Fit
    img.Parent = bg

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1.8, 0, 0.3, 0)
    lbl.Position = UDim2.new(-0.4, 0, 1.05, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = player.DisplayName or player.Name
    lbl.TextColor3 = Colors.TextNormal
    lbl.TextSize = 10
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = bg
end

local function cleanAllTags()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then clearHeadTag(p.Character) end
    end
end

local function rebuildPresenceTags(peerSet)
    for _, p in ipairs(Players:GetPlayers()) do
        if peerSet[p.UserId] and showPresenceTags then
            applyHeadTag(p)
        else
            if p.Character then clearHeadTag(p.Character) end
        end
    end
end

task.spawn(function()
    while true do
        pcall(function()
            if presenceEnabled then
                updatePresenceState(true)
                local peers = getActivePeers()
                peers[Player.UserId] = true
                rebuildPresenceTags(peers)
            else
                cleanPresence()
                cleanAllTags()
            end
        end)
        task.wait(12)
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if p.Character then clearHeadTag(p.Character) end
end)

local GUI = Instance.new("ScreenGui")
GUI.Name = "MeowHub"
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = game.CoreGui

local ToastHolder = Instance.new("Frame")
ToastHolder.Size = UDim2.new(0, 260, 1, 0)
ToastHolder.Position = UDim2.new(1, -280, 0, 0)
ToastHolder.BackgroundTransparency = 1
ToastHolder.ZIndex = 99
ToastHolder.Parent = GUI

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = ToastHolder

local function toast(title, desc, duration, statusColor)
    local item = Instance.new("Frame")
    item.Size = UDim2.new(1, 0, 0, 0)
    item.BackgroundColor3 = Colors.BgRibbon
    item.BorderSizePixel = 0
    item.ClipsDescendants = true
    item.Parent = ToastHolder

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = item

    local border = Instance.new("UIStroke")
    border.Color = statusColor or Colors.Border
    border.Thickness = 1
    border.Parent = item

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -12)
    bar.Position = UDim2.new(0, 6, 0, 6)
    bar.BackgroundColor3 = statusColor or Colors.Accent
    bar.BorderSizePixel = 0
    bar.Parent = item

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 2)
    uiCorner.Parent = bar

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -24, 0, 18)
    label.Position = UDim2.new(0, 16, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = title
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = item

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -24, 0, 16)
    sub.Position = UDim2.new(0, 16, 0, 24)
    sub.BackgroundTransparency = 1
    sub.Text = desc
    sub.TextColor3 = Colors.TextMuted
    sub.TextSize = 11
    sub.Font = Enum.Font.Gotham
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = item

    tween(item, 0.25, { Size = UDim2.new(1, 0, 0, 48) })

    task.delay(duration or 3, function()
        tween(item, 0.25, { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1 })
        task.wait(0.3)
        item:Destroy()
    end)
end

local Win = Instance.new("Frame")
Win.Size = UDim2.new(0, 760, 0, 480)
Win.Position = UDim2.new(0.5, -380, 0.5, -240)
Win.BackgroundColor3 = Colors.BgEditor
Win.BorderSizePixel = 0
Win.ClipsDescendants = true
Win.Parent = GUI
reg(Win, "BgEditor")

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 8)
winCorner.Parent = Win

local winStroke = Instance.new("UIStroke")
winStroke.Color = Colors.Border
winStroke.Thickness = 1
winStroke.Parent = Win
reg(winStroke, "Border", "Color")

local Shadow = Instance.new("ImageLabel")
Shadow.Size = UDim2.new(1, 40, 1, 40)
Shadow.Position = UDim2.new(0, -20, 0, -20)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = -1
Shadow.Parent = Win

local MobileButton = Instance.new("ImageButton")
MobileButton.Name = "MobileToggle"
MobileButton.Size = UDim2.new(0, 42, 0, 42)
MobileButton.Position = UDim2.new(0, 15, 0.15, 0)
MobileButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MobileButton.Image = "rbxassetid://110721752576238"
MobileButton.ScaleType = Enum.ScaleType.Fit
MobileButton.ZIndex = 98
MobileButton.Parent = GUI
reg(MobileButton, "BgEditor")

local mbCorner = Instance.new("UICorner")
mbCorner.CornerRadius = UDim.new(0.5, 0)
mbCorner.Parent = MobileButton

local mbStroke = Instance.new("UIStroke")
mbStroke.Color = Colors.Accent
mbStroke.Thickness = 1.5
mbStroke.Parent = MobileButton
reg(mbStroke, "Accent", "Color")

local mbDragging, mbDragStart, mbStartPos
MobileButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        mbDragging = true
        mbDragStart = input.Position
        mbStartPos = MobileButton.Position

        tween(MobileButton, 0.1, { Size = UDim2.new(0, 36, 0, 36) })

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                mbDragging = false
                tween(MobileButton, 0.1, { Size = UDim2.new(0, 42, 0, 42) })
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if mbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - mbDragStart
        MobileButton.Position = UDim2.new(mbStartPos.X.Scale, mbStartPos.X.Offset + delta.X, mbStartPos.Y.Scale, mbStartPos.Y.Offset + delta.Y)
    end
end)

local Titlebar = Instance.new("Frame")
Titlebar.Size = UDim2.new(1, 0, 0, 36)
Titlebar.BackgroundColor3 = Colors.BgTitlebar
Titlebar.BorderSizePixel = 0
Titlebar.Parent = Win
reg(Titlebar, "BgTitlebar")

local tbBorder = Instance.new("Frame")
tbBorder.Size = UDim2.new(1, 0, 0, 1)
tbBorder.Position = UDim2.new(0, 0, 1, 0)
tbBorder.BackgroundColor3 = Colors.Border
tbBorder.BorderSizePixel = 0
tbBorder.Parent = Titlebar
reg(tbBorder, "Border")

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 1, 0)
titleLabel.Position = UDim2.new(0.5, -100, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MeowHub"
titleLabel.TextColor3 = Colors.TextMuted
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamSemibold
titleLabel.Parent = Titlebar
reg(titleLabel, "TextMuted", "TextColor3")

local function toggleMenu()
    guiVisible = not guiVisible
    if guiVisible then
        Win.Visible = true
        Win.Size = UDim2.new(0, 760, 0, 480)
        Win.Position = UDim2.new(0.5, -380, 0.5, 0)
        tween(Win, 0.35, {
            Size = UDim2.new(0, 760, 0, 480),
            Position = UDim2.new(0.5, -380, 0.5, -240),
        }, Enum.EasingStyle.Back)
    else
        tween(Win, 0.25, {
            Size = UDim2.new(0, 760, 0, 0),
            Position = UDim2.new(0.5, -380, 0.5, 0)
        })
        task.wait(0.26)
        Win.Visible = false
    end
end

MobileButton.MouseButton1Click:Connect(toggleMenu)

local function createMacDot(color, position, callback)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 11, 0, 11)
    dot.Position = UDim2.new(0, position, 0.5, -5)
    dot.BackgroundColor3 = color
    dot.BorderSizePixel = 0
    dot.Parent = Titlebar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = dot

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = dot

    btn.MouseButton1Click:Connect(callback)
    return dot
end

createMacDot(Color3.fromRGB(235, 87, 87), 16, function()
    presenceEnabled = false
    cleanPresence()
    cleanAllTags()

    tween(Win, 0.25, { Size = UDim2.new(0, 760, 0, 0), Position = UDim2.new(0.5, -380, 0.5, 0) })
    task.wait(0.26)
    GUI:Destroy()
end)

createMacDot(Color3.fromRGB(242, 201, 76), 33, function()
    toggleMenu()
    toast("MeowHub", "GUI Hidden. Use Keybind or Shortcut button to open.", 3, Colors.Accent)
end)

createMacDot(Color3.fromRGB(39, 174, 96), 50, function()
    tween(Win, 0.3, { Position = UDim2.new(0.5, -380, 0.5, -240) })
end)

local dragging, dragInput, dragStart, startPos
Titlebar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Win.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

Titlebar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, 0, 1, -36)
Container.Position = UDim2.new(0, 0, 0, 36)
Container.BackgroundTransparency = 1
Container.Parent = Win

local Ribbon = Instance.new("Frame")
Ribbon.Size = UDim2.new(0, 42, 1, 0)
Ribbon.BackgroundColor3 = Colors.BgRibbon
Ribbon.BorderSizePixel = 0
Ribbon.Parent = Container
reg(Ribbon, "BgRibbon")

local ribbonBorder = Instance.new("Frame")
ribbonBorder.Size = UDim2.new(0, 1, 1, 0)
ribbonBorder.Position = UDim2.new(1, -1, 0, 0)
ribbonBorder.BackgroundColor3 = Colors.Border
ribbonBorder.BorderSizePixel = 0
ribbonBorder.Parent = Ribbon
reg(ribbonBorder, "Border")

local ribbonLayout = Instance.new("UIListLayout")
ribbonLayout.SortOrder = Enum.SortOrder.LayoutOrder
ribbonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ribbonLayout.Padding = UDim.new(0, 4)
ribbonLayout.Parent = Ribbon

local function createRibbonIcon(symbol, order, tooltipText, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 32, 0, 32)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order
    frame.Parent = Ribbon
    reg(frame, "BgRowHover")

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = symbol
    btn.TextColor3 = Colors.TextFaint
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = frame
    reg(btn, "TextFaint", "TextColor3")

    local tooltip = Instance.new("Frame")
    tooltip.Size = UDim2.new(0, 0, 0, 22)
    tooltip.Position = UDim2.new(1, 8, 0.5, -11)
    tooltip.BackgroundColor3 = Colors.BgTitlebar
    tooltip.BorderSizePixel = 0
    tooltip.ClipsDescendants = true
    tooltip.ZIndex = 50
    tooltip.Parent = frame
    reg(tooltip, "BgTitlebar")

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 4)
    tooltipCorner.Parent = tooltip

    local tooltipStroke = Instance.new("UIStroke")
    tooltipStroke.Color = Colors.Border
    tooltipStroke.Thickness = 1
    tooltipStroke.Parent = tooltip
    reg(tooltipStroke, "Border", "Color")

    local tooltipLabel = Instance.new("TextLabel")
    tooltipLabel.Size = UDim2.new(0, 80, 1, 0)
    tooltipLabel.Position = UDim2.new(0, 6, 0, 0)
    tooltipLabel.BackgroundTransparency = 1
    tooltipLabel.Text = tooltipText
    tooltipLabel.TextColor3 = Colors.TextNormal
    tooltipLabel.TextSize = 10
    tooltipLabel.Font = Enum.Font.Gotham
    tooltipLabel.TextXAlignment = Enum.TextXAlignment.Left
    tooltipLabel.Parent = tooltip
    reg(tooltipLabel, "TextNormal", "TextColor3")

    btn.MouseEnter:Connect(function()
        tween(btn, 0.15, { TextColor3 = Colors.TextNormal })
        tween(frame, 0.15, { BackgroundColor3 = Colors.BgRowHover, BackgroundTransparency = 0 })
        tween(tooltip, 0.15, { Size = UDim2.new(0, 90, 0, 22) })
    end)

    btn.MouseLeave:Connect(function()
        tween(btn, 0.15, { TextColor3 = Colors.TextFaint })
        tween(frame, 0.15, { BackgroundTransparency = 1 })
        tween(tooltip, 0.15, { Size = UDim2.new(0, 0, 0, 22) })
    end)

    btn.MouseButton1Click:Connect(callback)

    return frame, btn
end

local filesIconFrame, filesIcon = createRibbonIcon("📂", 1, "Files", function() end)
filesIcon.TextColor3 = Colors.TextNormal

createRibbonIcon("🔍", 2, "Search Vault", function() end)
createRibbonIcon("⚙️", 3, "Settings", function() end)

local ribbonPad = Instance.new("UIPadding")
ribbonPad.PaddingTop = UDim.new(0, 6)
ribbonPad.Parent = Ribbon

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 178, 1, 0)
Sidebar.Position = UDim2.new(0, 42, 0, 0)
Sidebar.BackgroundColor3 = Colors.BgSidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Container
reg(Sidebar, "BgSidebar")

local sidebarBorder = Instance.new("Frame")
sidebarBorder.Size = UDim2.new(0, 1, 1, 0)
sidebarBorder.Position = UDim2.new(1, -1, 0, 0)
sidebarBorder.BackgroundColor3 = Colors.Border
sidebarBorder.BorderSizePixel = 0
sidebarBorder.Parent = Sidebar
reg(sidebarBorder, "Border")

local vaultLabel = Instance.new("TextLabel")
vaultLabel.Size = UDim2.new(1, -24, 0, 28)
vaultLabel.Position = UDim2.new(0, 12, 0, 6)
vaultLabel.BackgroundTransparency = 1
vaultLabel.Text = "MEOW VAULT"
vaultLabel.TextColor3 = Colors.TextFaint
vaultLabel.TextSize = 10
vaultLabel.Font = Enum.Font.GothamBold
vaultLabel.TextXAlignment = Enum.TextXAlignment.Left
vaultLabel.Parent = Sidebar
reg(vaultLabel, "TextFaint", "TextColor3")

local SearchContainer = Instance.new("Frame")
SearchContainer.Size = UDim2.new(1, -24, 0, 24)
SearchContainer.Position = UDim2.new(0, 12, 0, 36)
SearchContainer.BackgroundColor3 = Colors.BgTitlebar
SearchContainer.BorderSizePixel = 0
SearchContainer.Parent = Sidebar
reg(SearchContainer, "BgTitlebar")

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 4)
searchCorner.Parent = SearchContainer

local searchStroke = Instance.new("UIStroke")
searchStroke.Color = Colors.Border
searchStroke.Thickness = 1
searchStroke.Parent = SearchContainer
reg(searchStroke, "Border", "Color")

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -8, 1, 0)
searchBox.Position = UDim2.new(0, 8, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Search tabs..."
searchBox.PlaceholderColor3 = Colors.TextFaint
searchBox.TextColor3 = Colors.TextNormal
searchBox.TextSize = 11
searchBox.Font = Enum.Font.Gotham
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = SearchContainer
reg(searchBox, "TextNormal", "TextColor3")

local filesFolder = Instance.new("Frame")
filesFolder.Size = UDim2.new(1, -24, 0, 24)
filesFolder.Position = UDim2.new(0, 12, 0, 68)
filesFolder.BackgroundTransparency = 1
filesFolder.Parent = Sidebar

local folderLabel = Instance.new("TextLabel")
folderLabel.Size = UDim2.new(1, 0, 1, 0)
folderLabel.BackgroundTransparency = 1
folderLabel.Text = "▼  📁  Tabs"
folderLabel.TextColor3 = Colors.TextMuted
folderLabel.TextSize = 11
folderLabel.Font = Enum.Font.GothamBold
folderLabel.TextXAlignment = Enum.TextXAlignment.Left
folderLabel.Parent = filesFolder
reg(folderLabel, "TextMuted", "TextColor3")

local FileList = Instance.new("ScrollingFrame")
FileList.Size = UDim2.new(1, -12, 1, -156)
FileList.Position = UDim2.new(0, 12, 0, 94)
FileList.BackgroundTransparency = 1
FileList.ScrollBarThickness = 0
FileList.CanvasSize = UDim2.new(0, 0, 0, 0)
FileList.AutomaticCanvasSize = Enum.AutomaticSize.Y
FileList.Parent = Sidebar

local fileLayout = Instance.new("UIListLayout")
fileLayout.SortOrder = Enum.SortOrder.LayoutOrder
fileLayout.Padding = UDim.new(0, 2)
fileLayout.Parent = FileList

local UserCard = Instance.new("Frame")
UserCard.Name = "UserCard"
UserCard.Size = UDim2.new(1, -24, 0, 48)
UserCard.Position = UDim2.new(0, 12, 1, -60)
UserCard.BackgroundColor3 = Colors.BgTitlebar
UserCard.BorderSizePixel = 0
UserCard.Parent = Sidebar
reg(UserCard, "BgTitlebar")

local ucCorner = Instance.new("UICorner")
ucCorner.CornerRadius = UDim.new(0, 6)
ucCorner.Parent = UserCard

local ucStroke = Instance.new("UIStroke")
ucStroke.Color = Colors.Border
ucStroke.Thickness = 1
ucStroke.Parent = UserCard
reg(ucStroke, "Border", "Color")

local AvatarImage = Instance.new("ImageLabel")
AvatarImage.Size = UDim2.new(0, 32, 0, 32)
AvatarImage.Position = UDim2.new(0, 8, 0.5, -16)
AvatarImage.BackgroundColor3 = Colors.BgEditor
AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. Player.UserId .. "&w=150&h=150"
AvatarImage.Parent = UserCard
reg(AvatarImage, "BgEditor")

local avCorner = Instance.new("UICorner")
avCorner.CornerRadius = UDim.new(1, 0)
avCorner.Parent = AvatarImage

local NameLabel = Instance.new("TextLabel")
NameLabel.Size = UDim2.new(1, -52, 0, 16)
NameLabel.Position = UDim2.new(0, 46, 0, 8)
NameLabel.BackgroundTransparency = 1
NameLabel.Text = Player.DisplayName or Player.Name
NameLabel.TextColor3 = Colors.TextNormal
NameLabel.TextSize = 11
NameLabel.Font = Enum.Font.GothamBold
NameLabel.TextXAlignment = Enum.TextXAlignment.Left
NameLabel.ClipsDescendants = true
NameLabel.Parent = UserCard
reg(NameLabel, "TextNormal", "TextColor3")

local ExecLabel = Instance.new("TextLabel")
ExecLabel.Size = UDim2.new(1, -52, 0, 14)
ExecLabel.Position = UDim2.new(0, 46, 0, 24)
ExecLabel.BackgroundTransparency = 1
ExecLabel.Text = getExecutorName()
ExecLabel.TextColor3 = Colors.Accent
ExecLabel.TextSize = 10
ExecLabel.Font = Enum.Font.GothamMedium
ExecLabel.TextXAlignment = Enum.TextXAlignment.Left
ExecLabel.ClipsDescendants = true
ExecLabel.Parent = UserCard
reg(ExecLabel, "Accent", "TextColor3")

local Editor = Instance.new("Frame")
Editor.Size = UDim2.new(1, -220, 1, 0)
Editor.Position = UDim2.new(0, 220, 0, 0)
Editor.BackgroundColor3 = Colors.BgEditor
Editor.BorderSizePixel = 0
Editor.Parent = Container
reg(Editor, "BgEditor")

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 32)
TabBar.BackgroundColor3 = Colors.BgTitlebar
TabBar.BorderSizePixel = 0
TabBar.Parent = Editor
reg(TabBar, "BgTitlebar")

local tabbarBorder = Instance.new("Frame")
tabbarBorder.Size = UDim2.new(1, 0, 0, 1)
tabbarBorder.Position = UDim2.new(0, 0, 1, -1)
tabbarBorder.BackgroundColor3 = Colors.Border
tabbarBorder.BorderSizePixel = 0
tabbarBorder.Parent = TabBar
reg(tabbarBorder, "Border")

local tabScroll = Instance.new("ScrollingFrame")
tabScroll.Size = UDim2.new(1, 0, 1, -1)
tabScroll.BackgroundTransparency = 1
tabScroll.ScrollBarThickness = 0
tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
tabScroll.Parent = TabBar

local tabLayout = Instance.new("UIListLayout")
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Parent = tabScroll

local DocPanel = Instance.new("Frame")
DocPanel.Size = UDim2.new(1, 0, 1, -32)
DocPanel.Position = UDim2.new(0, 0, 0, 32)
DocPanel.BackgroundTransparency = 1
DocPanel.ClipsDescendants = true
DocPanel.Parent = Editor

local DocScroll = Instance.new("ScrollingFrame")
DocScroll.Size = UDim2.new(1, 0, 1, 0)
DocScroll.BackgroundTransparency = 1
DocScroll.ScrollBarThickness = 2
DocScroll.ScrollBarImageColor3 = Colors.Border
DocScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DocScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DocScroll.Parent = DocPanel
reg(DocScroll, "Border", "ScrollBarImageColor3")

local docLayout = Instance.new("UIListLayout")
docLayout.SortOrder = Enum.SortOrder.LayoutOrder
docLayout.Padding = UDim.new(0, 12)
docLayout.Parent = DocScroll

local docPadding = Instance.new("UIPadding")
docPadding.PaddingLeft = UDim.new(0, 24)
docPadding.PaddingRight = UDim.new(0, 24)
docPadding.PaddingTop = UDim.new(0, 20)
docPadding.PaddingBottom = UDim.new(0, 20)
docPadding.Parent = DocScroll

local pageTitle = Instance.new("TextLabel")
pageTitle.Size = UDim2.new(1, 0, 0, 28)
pageTitle.BackgroundTransparency = 1
pageTitle.Text = "# Loading"
pageTitle.TextColor3 = Colors.TextNormal
pageTitle.TextSize = 22
pageTitle.Font = Enum.Font.GothamBold
pageTitle.TextXAlignment = Enum.TextXAlignment.Left
pageTitle.LayoutOrder = 1
pageTitle.Parent = DocScroll
reg(pageTitle, "TextNormal", "TextColor3")

local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(1, 0, 0, 1)
titleLine.BackgroundColor3 = Colors.Border
titleLine.BorderSizePixel = 0
titleLine.LayoutOrder = 3
titleLine.Parent = DocScroll
reg(titleLine, "Border")

local ScriptContainer = Instance.new("Frame")
ScriptContainer.Size = UDim2.new(1, 0, 0, 0)
ScriptContainer.BackgroundTransparency = 1
ScriptContainer.AutomaticSize = Enum.AutomaticSize.Y
ScriptContainer.LayoutOrder = 4
ScriptContainer.Parent = DocScroll

local scriptsLayout = Instance.new("UIListLayout")
scriptsLayout.SortOrder = Enum.SortOrder.LayoutOrder
scriptsLayout.Padding = UDim.new(0, 1)
scriptsLayout.Parent = ScriptContainer

local queuedThisTeleport = false
local function setupTeleportQueue()
    if queuedThisTeleport then return end
    queuedThisTeleport = true

    local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or run_on_teleport
    if queue then
        local success = pcall(function()
            if writefile then
                writefile("MeowHub_cache.lua", getgenv().MeowHubSource)
            end
        end)
        if success and writefile and readfile then
            pcall(queue, [[
                task.spawn(function()
                    if not game:IsLoaded() then game.Loaded:Wait() end
                    task.wait(1)
                    if isfile and isfile("MeowHub_cache.lua") and readfile then
                        local src = readfile("MeowHub_cache.lua")
                        if src then
                            getgenv().MeowHubSource = src
                            loadstring(src)()
                        end
                    end
                end)
            ]])
        else
            pcall(queue, "task.spawn(function() if not game:IsLoaded() then game.Loaded:Wait() end task.wait(1) getgenv().MeowHubSource = [=====" .. "[" .. getgenv().MeowHubSource .. "]" .. "=====] loadstring(getgenv().MeowHubSource)() end)")
        end
    end
end

if getgenv().MeowHubTeleportConnection then
    pcall(function()
        getgenv().MeowHubTeleportConnection:Disconnect()
    end)
    getgenv().MeowHubTeleportConnection = nil
end
getgenv().MeowHubTeleportConnection = Player.OnTeleport:Connect(function(State)
    if autoTeleport then
        local stateStr = tostring(State)
        if stateStr:find("Failed") or stateStr:find("Aborted") then
            queuedThisTeleport = false
        else
            setupTeleportQueue()
        end
    end
end)

local antiAFKConnection = nil
local function startAntiAFK()
    if antiAFKConnection then return end
    antiAFKConnection = Player.Idled:Connect(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new(0,0))
    end)
end

local function stopAntiAFK()
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
end

local function rejoin()
    toast("Rejoining", "Rejoining current server...", 3, Colors.Accent)
    task.wait(0.5)

    if autoTeleport then setupTeleportQueue() end

    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player)
end

local function fpsBoost(enabled)
    local lighting = game:GetService("Lighting")
    if enabled then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        lighting.GlobalShadows = false
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = false
            end
        end
    else
        lighting.GlobalShadows = true
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                v.Enabled = true
            end
        end
    end
end

local function serverHop()
    local PlaceId = game.PlaceId
    local JobId = game.JobId

    local success, result = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = httpRequest({ Url = url, Method = "GET" })
        if res and res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            local servers = {}
            for _, s in ipairs(data.data) do
                if s.id ~= JobId and s.playing < s.maxPlayers then
                    table.insert(servers, s)
                end
            end

            if #servers == 0 then return nil end

            if serverHopMode == "Lowest Players" then
                table.sort(servers, function(a, b)
                    return a.playing < b.playing
                end)
            elseif serverHopMode == "Lowest Ping" then
                table.sort(servers, function(a, b)
                    local aPing = a.ping or 999
                    local bPing = b.ping or 999
                    return aPing < bPing
                end)
            end

            return servers[1].id
        end
    end)

    if success and result then
        toast("Teleporting", "Found server (" .. serverHopMode .. "), joining...", 3, Colors.Accent)
        task.wait(0.5)

        if autoTeleport then setupTeleportQueue() end

        TeleportService:TeleportToPlaceInstance(PlaceId, result, Player)
    else
        toast("Hop Failed", "No alternative servers found.", 3, Colors.Error)
    end
end

local function updateSavedConfigsList()
    savedConfigsList = {"default"}
    if listfiles then
        local success, files = pcall(listfiles, "")
        if success and type(files) == "table" then
            for _, file in ipairs(files) do
                local name = file:match("meow_cfg_(.+)%.json$")
                if name and name ~= "default" then
                    table.insert(savedConfigsList, name)
                end
            end
        end
    end
end

local function applySettingsState(state)
    if state.presenceEnabled ~= nil then
        presenceEnabled = state.presenceEnabled
    end
    if state.showPresenceTags ~= nil then
        showPresenceTags = state.showPresenceTags
    end
    if state.guiToggleKey ~= nil then
        local key = Enum.KeyCode[state.guiToggleKey]
        if key then guiToggleKey = key end
    end
    if state.autoTeleport ~= nil then
        autoTeleport = state.autoTeleport
    end
    if state.serverHopMode ~= nil then
        serverHopMode = state.serverHopMode
    end
    if state.currentThemeName ~= nil then
        currentThemeName = state.currentThemeName
    end
    if state.customBg ~= nil then
        customBg = state.customBg
    end
    if state.customAccent ~= nil then
        customAccent = state.customAccent
    end

    if state.Scripts then
        for _, cat in ipairs(Categories) do
            if not cat.IsInfoPage and not cat.IsSettingsPage then
                for _, s in ipairs(cat.Scripts) do
                    if state.Scripts[s.Name] ~= nil and not s.IsAction then
                        s.Enabled = state.Scripts[s.Name]
                        if s.Name == "Share Presence" then
                            presenceEnabled = s.Enabled
                            task.spawn(function() updatePresenceState(presenceEnabled) end)
                        elseif s.Name == "Render Tags" then
                            showPresenceTags = s.Enabled
                        elseif s.Name == "Anti-AFK" then
                            if s.Enabled then startAntiAFK() else stopAntiAFK() end
                        elseif s.Name == "FPS Boost" then
                            fpsBoost(s.Enabled)
                        end
                    end
                end
            end
        end
    end

    applyThemeByName(currentThemeName)
end

local function saveConfig(name)
    if name == "" then
        toast("Config Error", "Please enter a valid config name.", 3, Colors.Error)
        return
    end
    
    local state = {
        presenceEnabled = presenceEnabled,
        showPresenceTags = showPresenceTags,
        guiToggleKey = guiToggleKey.Name,
        autoTeleport = autoTeleport,
        serverHopMode = serverHopMode,
        currentThemeName = currentThemeName,
        customBg = customBg,
        customAccent = customAccent,
        Scripts = {}
    }
    
    for _, cat in ipairs(Categories) do
        if not cat.IsInfoPage and not cat.IsSettingsPage then
            for _, s in ipairs(cat.Scripts) do
                if s.Enabled ~= nil and not s.IsAction then
                    state.Scripts[s.Name] = s.Enabled
                end
            end
        end
    end
    
    local success, str = pcall(function()
        return HttpService:JSONEncode(state)
    end)
    
    if success and writefile then
        local filename = "meow_cfg_" .. string.lower(name) .. ".json"
        local success2 = pcall(writefile, filename, str)
        if success2 then
            toast("Config Saved", "Successfully saved config: " .. name, 3, Colors.Success)
            updateSavedConfigsList()
        else
            toast("Config Error", "Failed to write config file.", 3, Colors.Error)
        end
    else
        toast("Config Error", "Failed to encode config.", 3, Colors.Error)
    end
end

local function loadConfig(name)
    if name == "" then
        toast("Config Error", "Please enter a valid config name.", 3, Colors.Error)
        return
    end
    
    local filename = "meow_cfg_" .. string.lower(name) .. ".json"
    if isfile and isfile(filename) and readfile then
        local success, content = pcall(readfile, filename)
        if success then
            local success2, state = pcall(function()
                return HttpService:JSONDecode(content)
            end)
            if success2 and type(state) == "table" then
                applySettingsState(state)
                if selectCategory then
                    selectCategory(activeCategoryIdx)
                end
                toast("Config Loaded", "Successfully loaded config: " .. name, 3, Colors.Success)
            else
                toast("Config Error", "Corrupted config file.", 3, Colors.Error)
            end
        else
            toast("Config Error", "Failed to read config file.", 3, Colors.Error)
        end
    else
        toast("Config Error", "Config not found: " .. name, 3, Colors.Error)
    end
end

local function deleteConfig(name)
    if name == "" or string.lower(name) == "default" then
        toast("Config Error", "Cannot delete core default template.", 3, Colors.Error)
        return
    end
    
    local filename = "meow_cfg_" .. string.lower(name) .. ".json"
    if isfile and isfile(filename) and delfile then
        local success = pcall(delfile, filename)
        if success then
            toast("Config Deleted", "Successfully removed config: " .. name, 3, Colors.Success)
            updateSavedConfigsList()
            if currentConfigName == name then
                currentConfigName = "default"
            end
            if selectCategory then
                selectCategory(activeCategoryIdx)
            end
        else
            toast("Config Error", "Failed to delete config file.", 3, Colors.Error)
        end
    else
        toast("Config Error", "Config file not found.", 3, Colors.Error)
    end
end

local function setAutoload(name)
    if name == "" then
        toast("Config Error", "Please enter a valid config name.", 3, Colors.Error)
        return
    end
    
    local filename = "meow_cfg_" .. string.lower(name) .. ".json"
    if isfile and isfile(filename) then
        if writefile then
            local success = pcall(writefile, "meow_autoload.txt", string.lower(name))
            if success then
                toast("Autoload Set", "Config '" .. name .. "' will autoload on rejoin.", 3, Colors.Success)
            else
                toast("Config Error", "Failed to write autoload file.", 3, Colors.Error)
            end
        end
    else
        toast("Config Error", "Config does not exist: " .. name, 3, Colors.Error)
    end
end

local function resetAutoload()
    if delfile and isfile and isfile("meow_autoload.txt") then
        local success = pcall(delfile, "meow_autoload.txt")
        if success then
            toast("Autoload Reset", "Removed autoload configuration.", 3, Colors.Success)
        else
            toast("Config Error", "Failed to delete autoload file.", 3, Colors.Error)
        end
    else
        toast("Autoload Reset", "No autoload was set.", 3, Colors.Success)
    end
end

local function checkAutoload()
    if isfile and isfile("meow_autoload.txt") and readfile then
        local success, name = pcall(readfile, "meow_autoload.txt")
        if success and name and name ~= "" then
            local filename = "meow_cfg_" .. string.lower(name) .. ".json"
            if isfile(filename) then
                loadConfig(name)
            end
        end
    end
end

local function createSliderRow(name, descText, min, max, initialValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -200, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -200, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local sliderTrack = Instance.new("Frame")
    sliderTrack.Size = UDim2.new(0, 130, 0, 6)
    sliderTrack.Position = UDim2.new(1, -182, 0.5, -3)
    sliderTrack.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    sliderTrack.BorderSizePixel = 0
    sliderTrack.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = sliderTrack

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((initialValue - min) / (max - min), 0, 1, 0)
    sliderFill.BackgroundColor3 = Colors.Accent
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderTrack
    reg(sliderFill, "Accent")

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = sliderFill

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, 12, 0, 12)
    sliderKnob.Position = UDim2.new((initialValue - min) / (max - min), -6, 0.5, -6)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Parent = sliderTrack

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = sliderKnob

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 40, 0, 24)
    valLbl.Position = UDim2.new(1, -44, 0.5, -12)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(initialValue)
    valLbl.TextColor3 = Colors.TextNormal
    valLbl.TextSize = 11
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = row

    local sliding = false
    local function updateSlider(input)
        local totalWidth = sliderTrack.AbsoluteSize.X
        local relativeX = input.Position.X - sliderTrack.AbsolutePosition.X
        local percentage = math.clamp(relativeX / totalWidth, 0, 1)
        local value = math.round(min + (max - min) * percentage)
        
        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        sliderKnob.Position = UDim2.new(percentage, -6, 0.5, -6)
        valLbl.Text = tostring(value)
        callback(value)
    end

    sliderTrack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateSlider(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 1 }) end)

    return row
end

local function createActionRow(name, descText, btnText, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -120, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -120, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local actBtn = Instance.new("TextButton")
    actBtn.Size = UDim2.new(0, 70, 0, 24)
    actBtn.Position = UDim2.new(1, -72, 0.5, -12)
    actBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    actBtn.BorderSizePixel = 0
    actBtn.Text = btnText
    actBtn.TextColor3 = Colors.TextNormal
    actBtn.TextSize = 11
    actBtn.Font = Enum.Font.GothamMedium
    actBtn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = actBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Colors.Border
    btnStroke.Thickness = 1
    btnStroke.Parent = actBtn

    actBtn.MouseEnter:Connect(function()
        tween(actBtn, 0.15, { BackgroundColor3 = Colors.Accent })
    end)
    actBtn.MouseLeave:Connect(function()
        tween(actBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(60, 60, 64) })
    end)

    actBtn.MouseButton1Click:Connect(callback)

    row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 1 }) end)

    return row
end

local function createDropdownRow(name, descText, options, defaultOption, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -150, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -150, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local ddBtn = Instance.new("TextButton")
    ddBtn.Size = UDim2.new(0, 130, 0, 24)
    ddBtn.Position = UDim2.new(1, -132, 0.5, -12)
    ddBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    ddBtn.BorderSizePixel = 0
    ddBtn.Text = defaultOption .. "  ▼"
    ddBtn.TextColor3 = Colors.TextNormal
    ddBtn.TextSize = 11
    ddBtn.Font = Enum.Font.GothamMedium
    ddBtn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = ddBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Colors.Border
    btnStroke.Thickness = 1
    btnStroke.Parent = ddBtn

    local ddList = Instance.new("Frame")
    ddList.Size = UDim2.new(0, 130, 0, math.clamp(#options * 24 + 4, 4, 150))
    ddList.BackgroundColor3 = Colors.BgSidebar
    ddList.BorderSizePixel = 0
    ddList.Visible = false
    ddList.ZIndex = 100
    ddList.Parent = GUI

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 4)
    listCorner.Parent = ddList

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = Colors.Border
    listStroke.Thickness = 1
    listStroke.Parent = ddList

    local scrollList = Instance.new("ScrollingFrame")
    scrollList.Size = UDim2.new(1, 0, 1, 0)
    scrollList.BackgroundTransparency = 1
    scrollList.BorderSizePixel = 0
    scrollList.ScrollBarThickness = 3
    scrollList.ScrollBarImageColor3 = Colors.Border
    scrollList.CanvasSize = UDim2.new(0, 0, 0, #options * 24)
    scrollList.Parent = ddList

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollList

    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, 2)
    listPadding.PaddingBottom = UDim.new(0, 2)
    listPadding.PaddingLeft = UDim.new(0, 4)
    listPadding.PaddingRight = UDim.new(0, 4)
    listPadding.Parent = scrollList

    local function updateListPosition()
        local absPos = ddBtn.AbsolutePosition
        ddList.Position = UDim2.new(0, absPos.X, 0, absPos.Y + ddBtn.AbsoluteSize.Y + 4)
    end

    for idx, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 22)
        optBtn.BackgroundTransparency = 1
        optBtn.Text = opt
        optBtn.TextColor3 = Colors.TextNormal
        optBtn.TextSize = 11
        optBtn.Font = Enum.Font.Gotham
        optBtn.LayoutOrder = idx
        optBtn.Parent = scrollList

        local optCorner = Instance.new("UICorner")
        optCorner.CornerRadius = UDim.new(0, 3)
        optCorner.Parent = optBtn

        optBtn.MouseEnter:Connect(function()
            tween(optBtn, 0.1, { BackgroundTransparency = 0, BackgroundColor3 = Colors.BgRowHover })
        end)
        optBtn.MouseLeave:Connect(function()
            tween(optBtn, 0.1, { BackgroundTransparency = 1 })
        end)

        optBtn.MouseButton1Click:Connect(function()
            ddBtn.Text = opt .. "  ▼"
            ddList.Visible = false
            callback(opt)
        end)
    end

    ddBtn.MouseButton1Click:Connect(function()
        ddList.Visible = not ddList.Visible
        if ddList.Visible then
            updateListPosition()
        end
    end)

    local inputConnection
    inputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if ddList.Visible then
                task.wait()
                local mousePos = UserInputService:GetMouseLocation()
                local inset = game:GetService("GuiService"):GetGuiInset()
                mousePos = mousePos - inset
                local absPos = ddList.AbsolutePosition
                local absSize = ddList.AbsoluteSize

                local btnPos = ddBtn.AbsolutePosition
                local btnSize = ddBtn.AbsoluteSize

                local inList = mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
                               mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y

                local inBtn = mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X and
                              mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y

                if not inList and not inBtn then
                    ddList.Visible = false
                end
            end
        end
    end)

    row.Destroying:Connect(function()
        ddList:Destroy()
        if inputConnection then inputConnection:Disconnect() end
    end)

    row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 1 }) end)

    return row
end

local function createKeybindRow(name, descText, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -120, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -120, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0, 90, 0, 24)
    keyBtn.Position = UDim2.new(1, -92, 0.5, -12)
    keyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    keyBtn.BorderSizePixel = 0
    keyBtn.Text = guiToggleKey.Name
    keyBtn.TextColor3 = Colors.TextNormal
    keyBtn.TextSize = 11
    keyBtn.Font = Enum.Font.GothamMedium
    keyBtn.Parent = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = keyBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Colors.Border
    btnStroke.Thickness = 1
    btnStroke.Parent = keyBtn

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Colors.TextMuted

        local con
        con = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                guiToggleKey = input.KeyCode
                keyBtn.Text = input.KeyCode.Name
                keyBtn.TextColor3 = Colors.TextNormal
                listening = false
                toast("Keybind Changed", "Menu toggle key set to: " .. input.KeyCode.Name, 2, Colors.Success)
                con:Disconnect()
            end
        end)
    end)

    row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 1 }) end)

    return row
end

local function createToggleRow(name, descText, initialValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -100, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -100, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local toggleTrack = Instance.new("Frame")
    toggleTrack.Size = UDim2.new(0, 36, 0, 18)
    toggleTrack.Position = UDim2.new(1, -38, 0.5, -9)
    toggleTrack.BackgroundColor3 = initialValue and Colors.Accent or Color3.fromRGB(60, 60, 64)
    toggleTrack.BorderSizePixel = 0
    toggleTrack.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = toggleTrack

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Size = UDim2.new(0, 14, 0, 14)
    toggleKnob.Position = initialValue and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleTrack

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = toggleKnob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = toggleTrack

    local value = initialValue
    btn.MouseButton1Click:Connect(function()
        value = not value
        callback(value)
        if value then
            tween(toggleTrack, 0.15, { BackgroundColor3 = Colors.Accent })
            tween(toggleKnob, 0.15, { Position = UDim2.new(1, -16, 0.5, -7) })
        else
            tween(toggleTrack, 0.15, { BackgroundColor3 = Color3.fromRGB(60, 60, 64) })
            tween(toggleKnob, 0.15, { Position = UDim2.new(0, 2, 0.5, -7) })
        end
    end)

    row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 1 }) end)

    return row
end

local function createTextBoxRow(name, descText, placeholder, initialValue, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -180, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -180, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = descText
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local boxContainer = Instance.new("Frame")
    boxContainer.Size = UDim2.new(0, 160, 0, 24)
    boxContainer.Position = UDim2.new(1, -162, 0.5, -12)
    boxContainer.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
    boxContainer.BorderSizePixel = 0
    boxContainer.Parent = row

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = boxContainer

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Colors.Border
    boxStroke.Thickness = 1
    boxStroke.Parent = boxContainer

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -12, 1, 0)
    box.Position = UDim2.new(0, 6, 0, 0)
    box.BackgroundTransparency = 1
    box.Text = initialValue
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Colors.TextFaint
    box.TextColor3 = Colors.TextNormal
    box.TextSize = 11
    box.Font = Enum.Font.GothamMedium
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Parent = boxContainer

    box.FocusLost:Connect(function(enterPressed)
        callback(box.Text)
    end)

    row.MouseEnter:Connect(function() tween(row, 0.15, { BackgroundTransparency = 0 }) end)
    row.MouseLeave:Connect(function() tween(row, 0.15, { BackgroundTransparency = 1 }) end)

    return row
end

local function createSettingsRow(scriptData)
    if scriptData.IsAction then
        return createActionRow(scriptData.Name, scriptData.Desc, "Run", function()
            if scriptData.Name == "Rejoin" then
                rejoin()
            end
        end)
    end

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = Colors.Border
    line.BorderSizePixel = 0
    line.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -100, 0, 18)
    label.Position = UDim2.new(0, 0, 0.5, -17)
    label.BackgroundTransparency = 1
    label.Text = scriptData.Name
    label.TextColor3 = Colors.TextNormal
    label.TextSize = 13
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -100, 0, 14)
    desc.Position = UDim2.new(0, 0, 0.5, 3)
    desc.BackgroundTransparency = 1
    desc.Text = scriptData.Desc
    desc.TextColor3 = Colors.TextMuted
    desc.TextSize = 11
    desc.Font = Enum.Font.Gotham
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local toggleTrack = Instance.new("Frame")
    toggleTrack.Size = UDim2.new(0, 36, 0, 18)
    toggleTrack.Position = UDim2.new(1, -38, 0.5, -9)
    toggleTrack.BackgroundColor3 = scriptData.Enabled and Colors.Accent or Color3.fromRGB(60, 60, 64)
    toggleTrack.BorderSizePixel = 0
    toggleTrack.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = toggleTrack

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Size = UDim2.new(0, 14, 0, 14)
    toggleKnob.Position = scriptData.Enabled and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleTrack

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = toggleKnob

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = toggleTrack

    btn.MouseButton1Click:Connect(function()
        scriptData.Enabled = not scriptData.Enabled

        if scriptData.Name == "Share Presence" then
            presenceEnabled = scriptData.Enabled
            task.spawn(function() updatePresenceState(presenceEnabled) end)
        elseif scriptData.Name == "Render Tags" then
            showPresenceTags = scriptData.Enabled
        elseif scriptData.Name == "Anti-AFK" then
            if scriptData.Enabled then startAntiAFK() else stopAntiAFK() end
        elseif scriptData.Name == "FPS Boost" then
            fpsBoost(scriptData.Enabled)
        end

        if scriptData.Enabled then
            tween(toggleTrack, 0.15, { BackgroundColor3 = Colors.Accent })
            tween(toggleKnob, 0.15, { Position = UDim2.new(1, -16, 0.5, -7) })
            toast("Enabled", scriptData.Name, 1.5, Colors.Success)
        else
            tween(toggleTrack, 0.15, { BackgroundColor3 = Color3.fromRGB(60, 60, 64) })
            tween(toggleKnob, 0.15, { Position = UDim2.new(0, 2, 0.5, -7) })
            toast("Disabled", scriptData.Name, 1.5, Colors.Error)
        end
    end)

    row.MouseEnter:Connect(function()
        tween(row, 0.15, { BackgroundTransparency = 0 })
    end)

    row.MouseLeave:Connect(function()
        tween(row, 0.15, { BackgroundTransparency = 1 })
    end)

    return row
end

activeCategoryIdx = 1
local tabButtons = {}
local fileNodes = {}
local activeTabs = {}

local function createHeadingRow(titleText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.Parent = ScriptContainer

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = titleText:upper()
    label.TextColor3 = Colors.Accent
    label.TextSize = 11
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    reg(label, "Accent", "TextColor3")

    return row
end

function selectCategory(idx)
    activeCategoryIdx = idx
    local cat = Categories[idx]

    pageTitle.Text = "# " .. cat.Name

    for _, child in ipairs(ScriptContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    if cat.IsInfoPage then
        local callout = Instance.new("Frame")
        callout.Size = UDim2.new(1, 0, 0, 56)
        callout.BackgroundColor3 = Color3.fromRGB(34, 34, 38)
        callout.BorderSizePixel = 0
        callout.Parent = ScriptContainer

        local coCorner = Instance.new("UICorner")
        coCorner.CornerRadius = UDim.new(0, 4)
        coCorner.Parent = callout

        local coStroke = Instance.new("UIStroke")
        coStroke.Color = Colors.Border
        coStroke.Thickness = 1
        coStroke.Parent = callout

        local coLeftBar = Instance.new("Frame")
        coLeftBar.Size = UDim2.new(0, 4, 1, 0)
        coLeftBar.BackgroundColor3 = Colors.Accent
        coLeftBar.BorderSizePixel = 0
        coLeftBar.Parent = callout

        local lbCorner = Instance.new("UICorner")
        lbCorner.CornerRadius = UDim.new(0, 4)
        lbCorner.Parent = coLeftBar

        local coText = Instance.new("TextLabel")
        coText.Size = UDim2.new(1, -20, 1, 0)
        coText.Position = UDim2.new(0, 14, 0, 0)
        coText.BackgroundTransparency = 1
        coText.Text = "💡  credits to @x_vxn for helping with this gui"
        coText.TextColor3 = Colors.TextNormal
        coText.TextSize = 13
        coText.Font = Enum.Font.GothamMedium
        coText.TextXAlignment = Enum.TextXAlignment.Left
        coText.Parent = callout

    elseif cat.IsSettingsPage then
        createHeadingRow("Interface Options")
        
        createDropdownRow("Serverhop Mode", "Choose criteria for public server search", { "Lowest Players", "Lowest Ping" }, serverHopMode, function(val)
            serverHopMode = val
        end)

        createActionRow("Serverhop", "Search and migrate to a different public game instance", "Hop", function()
            serverHop()
        end)

        createKeybindRow("Toggle Keybind", "Change keyboard shortcut to show/hide GUI", function() end)

        createToggleRow("Mobile Toggle Button", "Show a floating shortcut button to toggle GUI", MobileButton.Visible, function(enabled)
            MobileButton.Visible = enabled
        end)

        createToggleRow("Auto Execute on Teleport", "Automatically run MeowHub on teleport (no files required)", autoTeleport, function(enabled)
            autoTeleport = enabled
        end)

        createHeadingRow("Theme Customization")

        local themeOptions = {}
        for themeName, _ in pairs(PredefinedThemes) do
            table.insert(themeOptions, themeName)
        end
        table.sort(themeOptions)

        createDropdownRow("Select Theme", "Pick a built-in appearance template or use Custom", themeOptions, currentThemeName, function(val)
            applyThemeByName(val)
        end)

        if currentThemeName == "Custom" then
            local customBgCol = hexToColor3(customBg) or Color3.fromRGB(30, 30, 30)
            local customAccentCol = hexToColor3(customAccent) or Color3.fromRGB(117, 81, 204)

            createSliderRow("Background Color (R)", "Modify Red channel of custom backplane", 0, 255, math.round(customBgCol.R * 255), function(val)
                local current = hexToColor3(customBg) or Color3.fromRGB(30,30,30)
                customBg = color3ToHex(Color3.fromRGB(val, math.round(current.G * 255), math.round(current.B * 255)))
                applyThemeByName("Custom")
            end)
            createSliderRow("Background Color (G)", "Modify Green channel of custom backplane", 0, 255, math.round(customBgCol.G * 255), function(val)
                local current = hexToColor3(customBg) or Color3.fromRGB(30,30,30)
                customBg = color3ToHex(Color3.fromRGB(math.round(current.R * 255), val, math.round(current.B * 255)))
                applyThemeByName("Custom")
            end)
            createSliderRow("Background Color (B)", "Modify Blue channel of custom backplane", 0, 255, math.round(customBgCol.B * 255), function(val)
                local current = hexToColor3(customBg) or Color3.fromRGB(30,30,30)
                customBg = color3ToHex(Color3.fromRGB(math.round(current.R * 255), math.round(current.G * 255), val))
                applyThemeByName("Custom")
            end)

            createSliderRow("Accent Color (R)", "Modify Red channel of core interactive highlights", 0, 255, math.round(customAccentCol.R * 255), function(val)
                local current = hexToColor3(customAccent) or Color3.fromRGB(117, 81, 204)
                customAccent = color3ToHex(Color3.fromRGB(val, math.round(current.G * 255), math.round(current.B * 255)))
                applyThemeByName("Custom")
            end)
            createSliderRow("Accent Color (G)", "Modify Green channel of core interactive highlights", 0, 255, math.round(customAccentCol.G * 255), function(val)
                local current = hexToColor3(customAccent) or Color3.fromRGB(117, 81, 204)
                customAccent = color3ToHex(Color3.fromRGB(math.round(current.R * 255), val, math.round(current.B * 255)))
                applyThemeByName("Custom")
            end)
            createSliderRow("Accent Color (B)", "Modify Blue channel of core interactive highlights", 0, 255, math.round(customAccentCol.B * 255), function(val)
                local current = hexToColor3(customAccent) or Color3.fromRGB(117, 81, 204)
                customAccent = color3ToHex(Color3.fromRGB(math.round(current.R * 255), math.round(current.G * 255), val))
                applyThemeByName("Custom")
            end)
        end

        createHeadingRow("Configuration Profile Manager")

        createTextBoxRow("New Config Name", "Type your profile workspace identifier here", "default", currentConfigName, function(val)
            currentConfigName = val
        end)

        createActionRow("Save Config", "Write all current values to your workspace identifier", "Save", function()
            saveConfig(currentConfigName)
        end)

        createDropdownRow("Select Saved Config", "Choose a saved workspace profile to work with", savedConfigsList, currentConfigName, function(val)
            currentConfigName = val
        end)

        createActionRow("Load Selected Config", "Pull configuration flags from your profile selection", "Load", function()
            loadConfig(currentConfigName)
        end)

        createActionRow("Delete Selected Config", "Permanently remove selected file from folder layout", "Delete", function()
            deleteConfig(currentConfigName)
        end)

        createActionRow("Refresh Config List", "Force directory scan to check file environment changes", "Refresh", function()
            updateSavedConfigsList()
            selectCategory(activeCategoryIdx)
            toast("Refreshed", "Config profiles updated dynamically.", 1.5, Colors.Success)
        end)

        createActionRow("Set Selection As Autoload", "Configure workspace profile to load on game boot", "Autoload", function()
            setAutoload(currentConfigName)
        end)

        createActionRow("Reset Autoload", "Destroy active profile links on game boot", "Reset", function()
            resetAutoload()
        end)
    else
        for _, s in ipairs(cat.Scripts) do
            createSettingsRow(s)
        end
    end

    for i, node in ipairs(fileNodes) do
        if i == idx then
            node.Frame.BackgroundColor3 = Colors.BgRowHover
            node.Label.TextColor3 = Colors.TextNormal
        else
            node.Frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
            node.Frame.BackgroundTransparency = 1
            node.Label.TextColor3 = Colors.TextMuted
        end
    end

    if not activeTabs[idx] then
        activeTabs[idx] = true
        tabButtons[idx].Visible = true
    end

    for i, tab in ipairs(tabButtons) do
        if i == idx then
            tab.Frame.BackgroundColor3 = Colors.BgEditor
            tab.Label.TextColor3 = Colors.TextNormal
            tab.Accent.BackgroundTransparency = 0
        else
            tab.Frame.BackgroundColor3 = Colors.BgTitlebar
            tab.Label.TextColor3 = Colors.TextFaint
            tab.Accent.BackgroundTransparency = 1
        end
    end
end

for i, cat in ipairs(Categories) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    row.LayoutOrder = i
    row.Parent = FileList

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 4)
    rowCorner.Parent = row

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 18)
    pad.Parent = row

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "📄  " .. cat.Name
    label.TextColor3 = Colors.TextMuted
    label.TextSize = 11
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    btn.MouseEnter:Connect(function()
        if activeCategoryIdx ~= i then
            tween(row, 0.15, { BackgroundTransparency = 0, BackgroundColor3 = Colors.BgTitlebar })
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeCategoryIdx ~= i then
            tween(row, 0.15, { BackgroundTransparency = 1 })
        end
    end)

    btn.MouseButton1Click:Connect(function()
        selectCategory(i)
    end)

    fileNodes[i] = { Frame = row, Label = label }

    local tab = Instance.new("Frame")
    tab.Size = UDim2.new(0, 110, 1, 0)
    tab.BackgroundColor3 = Colors.BgTitlebar
    tab.BorderSizePixel = 0
    tab.LayoutOrder = i
    tab.Visible = (i <= 3)
    tab.Parent = tabScroll

    if i <= 3 then activeTabs[i] = true end

    local tabSep = Instance.new("Frame")
    tabSep.Size = UDim2.new(0, 1, 1, 0)
    tabSep.Position = UDim2.new(1, -1, 0, 0)
    tabSep.BackgroundColor3 = Colors.Border
    tabSep.BorderSizePixel = 0
    tabSep.Parent = tab

    local tabLabel = Instance.new("TextLabel")
    tabLabel.Size = UDim2.new(1, -30, 1, 0)
    tabLabel.Position = UDim2.new(0, 10, 0, 0)
    tabLabel.BackgroundTransparency = 1
    tabLabel.Text = cat.Name
    tabLabel.TextColor3 = Colors.TextFaint
    tabLabel.TextSize = 10
    tabLabel.Font = Enum.Font.Gotham
    tabLabel.TextXAlignment = Enum.TextXAlignment.Left
    tabLabel.Parent = tab

    local tabAccent = Instance.new("Frame")
    tabAccent.Size = UDim2.new(1, 0, 0, 2)
    tabAccent.Position = UDim2.new(0, 0, 0, 0)
    tabAccent.BackgroundColor3 = Colors.Accent
    tabAccent.BackgroundTransparency = 1
    tabAccent.BorderSizePixel = 0
    tabAccent.Parent = tab

    local closeTab = Instance.new("TextButton")
    closeTab.Size = UDim2.new(0, 16, 0, 16)
    closeTab.Position = UDim2.new(1, -20, 0.5, -8)
    closeTab.BackgroundTransparency = 1
    closeTab.Text = "✕"
    closeTab.TextColor3 = Colors.TextFaint
    closeTab.TextSize = 10
    closeTab.Font = Enum.Font.Gotham
    closeTab.Parent = tab

    closeTab.MouseEnter:Connect(function()
        closeTab.TextColor3 = Colors.Error
    end)
    closeTab.MouseLeave:Connect(function()
        closeTab.TextColor3 = Colors.TextFaint
    end)

    closeTab.MouseButton1Click:Connect(function()
        activeTabs[i] = false
        tab.Visible = false
        if activeCategoryIdx == i then
            for j = 1, #Categories do
                if activeTabs[j] then
                    selectCategory(j)
                    break
                end
            end
        end
    end)

    local selectTabBtn = Instance.new("TextButton")
    selectTabBtn.Size = UDim2.new(1, -24, 1, 0)
    selectTabBtn.BackgroundTransparency = 1
    selectTabBtn.Text = ""
    selectTabBtn.Parent = tab

    selectTabBtn.MouseButton1Click:Connect(function()
        selectCategory(i)
    end)

    tabButtons[i] = { Frame = tab, Label = tabLabel, Accent = tabAccent }
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local text = string.lower(searchBox.Text)

    if text == "" then
        selectCategory(activeCategoryIdx)
        for _, node in ipairs(fileNodes) do
            node.Frame.Visible = true
        end
        return
    end

    for i, node in ipairs(fileNodes) do
        local cat = Categories[i]
        local match = string.find(string.lower(cat.Name), text)
        if not match then
            for _, s in ipairs(cat.Scripts) do
                if string.find(string.lower(s.Name), text) or string.find(string.lower(s.Desc), text) then
                    match = true
                    break
                end
            end
        end
        node.Frame.Visible = match and true or false
    end

    pageTitle.Text = "# Search Results"
    for _, child in ipairs(ScriptContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, cat in ipairs(Categories) do
        if not cat.IsInfoPage and not cat.IsSettingsPage then
            for _, s in ipairs(cat.Scripts) do
                if string.find(string.lower(s.Name), text) or string.find(string.lower(s.Desc), text) then
                    createSettingsRow(s)
                end
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == guiToggleKey then
        toggleMenu()
    end
end)

updateSavedConfigsList()
checkAutoload()
selectCategory(1)

Win.Size = UDim2.new(0, 760, 0, 0)
Win.Position = UDim2.new(0.5, -380, 0.5, 0)
task.wait(0.2)
tween(Win, 0.45, {
    Size = UDim2.new(0, 760, 0, 480),
    Position = UDim2.new(0.5, -380, 0.5, -240),
}, Enum.EasingStyle.Back)

toast("MeowHub Loaded", "MeowHub active. Keybind: RightShift.", 3, Colors.Accent)
print("MeowHub Loaded")
]====]

loadstring(getgenv().MeowHubSource)()
