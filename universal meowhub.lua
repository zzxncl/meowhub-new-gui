getgenv().MeowHubSource = [====[--[[
    ╔══════════════════════════════════════════╗
    ║            MeowHub v2.3                  ║
    ║     True Obsidian-Style Script Hub       ║
    ╚══════════════════════════════════════════╝
    
    Design features:
    • Authentic Obsidian dark-mode palette
    • Minimalist macOS window controls
    • Thin ribbon side strip with tooltips
    • File explorer tree with folder structure
    • Clean tab-bar at the top with closing tabs
    • Markdown-style headings and properties lists
    • Flat settings rows with subtle hover transitions (no bulky cards)
    • HTTP-based peer presence synchronization via kvdb.io
    • Floating logo above head for active MeowHub users
    • Draggable floating mobile shortcut button for mobile compatibility
    • Dropdown menu selection for server hop criteria
    • Pure in-memory auto-execute queue on teleport (no files required!)
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local Player = Players.LocalPlayer

-- Clean up any previous MeowHub GUI
if game.CoreGui:FindFirstChild("MeowHub") then
    game.CoreGui:FindFirstChild("MeowHub"):Destroy()
end

-- ═══════════════════════════════════════════
-- CONFIGURATION & STATE
-- ═══════════════════════════════════════════
local presenceEnabled = true
local showPresenceTags = true
local guiToggleKey = Enum.KeyCode.RightShift
local guiVisible = true
local autoTeleport = true
local serverHopMode = "Lowest Players"

local presenceBucket = "meowhub_presence_v2"
local gameJobId = (game.JobId ~= "" and game.JobId) or "studio_testing"
local playerUserId = tostring(Player.UserId)
local lastPresenceKey = nil

-- Colors (Obsidian Dark Theme)
local Colors = {
    BgTitlebar   = Color3.fromRGB(22, 22, 22),       -- Darkest gray for titlebar and inactive tabs
    BgRibbon     = Color3.fromRGB(26, 26, 26),       -- Vertical thin action strip
    BgSidebar    = Color3.fromRGB(28, 28, 28),       -- File explorer container
    BgEditor     = Color3.fromRGB(30, 30, 30),       -- Main edit window (Obsidian default dark bg)
    BgRowHover   = Color3.fromRGB(37, 37, 37),       -- Flat settings list hover state
    Border       = Color3.fromRGB(45, 45, 45),       -- Thin boundary line color
    BorderLight  = Color3.fromRGB(55, 55, 55),
    
    -- Accent (Obsidian Purple)
    Accent       = Color3.fromRGB(117, 81, 204),
    AccentHover  = Color3.fromRGB(135, 100, 224),
    AccentFaint  = Color3.fromRGB(60, 48, 90),
    
    -- Text states
    TextNormal   = Color3.fromRGB(226, 226, 227),    -- White-ish body text
    TextMuted    = Color3.fromRGB(154, 154, 156),    -- Grey description text
    TextFaint    = Color3.fromRGB(104, 104, 106),    -- Darker grey decoration/system tags
    
    -- States
    Success      = Color3.fromRGB(72, 191, 132),
    Error        = Color3.fromRGB(235, 87, 87),
}

-- Tweening helper
local function tween(obj, duration, props, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- ═══════════════════════════════════════════
-- DATA MODEL
-- ═══════════════════════════════════════════
local Categories = {
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

-- ═══════════════════════════════════════════
-- PEER-TO-PEER PRESENCE SYNCHRONIZATION
-- ═══════════════════════════════════════════
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
                        -- clean up dead key
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

-- ═══════════════════════════════════════════
-- HEAD BILLBOARD CREATION
-- ═══════════════════════════════════════════
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

-- Start background presence thread
task.spawn(function()
    while true do
        pcall(function()
            if presenceEnabled then
                updatePresenceState(true)
                local peers = getActivePeers()
                peers[Player.UserId] = true -- Always show ourselves if active
                rebuildPresenceTags(peers)
            else
                cleanPresence()
                cleanAllTags()
            end
        end)
        task.wait(12)
    end
end)

-- Remove tags when characters despawn
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if p.Character then clearHeadTag(p.Character) end
end)

-- ═══════════════════════════════════════════
-- CORE GUI LAYOUT
-- ═══════════════════════════════════════════
local GUI = Instance.new("ScreenGui")
GUI.Name = "MeowHub"
GUI.ResetOnSpawn = false
GUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.Parent = game.CoreGui

-- Toast Notifications Frame
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

-- Main Window
local Win = Instance.new("Frame")
Win.Size = UDim2.new(0, 760, 0, 480)
Win.Position = UDim2.new(0.5, -380, 0.5, -240)
Win.BackgroundColor3 = Colors.BgEditor
Win.BorderSizePixel = 0
Win.ClipsDescendants = true
Win.Parent = GUI

local winCorner = Instance.new("UICorner")
winCorner.CornerRadius = UDim.new(0, 8)
winCorner.Parent = Win

local winStroke = Instance.new("UIStroke")
winStroke.Color = Colors.Border
winStroke.Thickness = 1
winStroke.Parent = Win

-- Drop shadow
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

-- Mobile Toggle Button (Shortcut)
local MobileButton = Instance.new("ImageButton")
MobileButton.Name = "MobileToggle"
MobileButton.Size = UDim2.new(0, 42, 0, 42)
MobileButton.Position = UDim2.new(0, 15, 0.15, 0)
MobileButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MobileButton.Image = "rbxassetid://110721752576238"
MobileButton.ScaleType = Enum.ScaleType.Fit
MobileButton.ZIndex = 98
MobileButton.Parent = GUI

local mbCorner = Instance.new("UICorner")
mbCorner.CornerRadius = UDim.new(0.5, 0)
mbCorner.Parent = MobileButton

local mbStroke = Instance.new("UIStroke")
mbStroke.Color = Colors.Accent
mbStroke.Thickness = 1.5
mbStroke.Parent = MobileButton

-- Mobile Button Dragging
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

-- ═══════════════════════════════════════════
-- TITLEBAR
-- ═══════════════════════════════════════════
local Titlebar = Instance.new("Frame")
Titlebar.Size = UDim2.new(1, 0, 0, 36)
Titlebar.BackgroundColor3 = Colors.BgTitlebar
Titlebar.BorderSizePixel = 0
Titlebar.Parent = Win

local tbBorder = Instance.new("Frame")
tbBorder.Size = UDim2.new(1, 0, 0, 1)
tbBorder.Position = UDim2.new(0, 0, 1, 0)
tbBorder.BackgroundColor3 = Colors.Border
tbBorder.BorderSizePixel = 0
tbBorder.Parent = Titlebar

-- Title Label (Centered)
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 1, 0)
titleLabel.Position = UDim2.new(0.5, -100, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MeowHub"
titleLabel.TextColor3 = Colors.TextMuted
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamSemibold
titleLabel.Parent = Titlebar

local function toggleMenu()
    guiVisible = not guiVisible
    if guiVisible then
        Win.Visible = true
        Win.Size = UDim2.new(0, 760, 0, 0)
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

-- macOS Window Controls (Left side)
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

-- Close Button (Red)
createMacDot(Color3.fromRGB(235, 87, 87), 16, function()
    presenceEnabled = false
    cleanPresence()
    cleanAllTags()
    
    tween(Win, 0.25, { Size = UDim2.new(0, 760, 0, 0), Position = UDim2.new(0.5, -380, 0.5, 0) })
    task.wait(0.26)
    GUI:Destroy()
end)

-- Minimize Button (Yellow)
createMacDot(Color3.fromRGB(242, 201, 76), 33, function()
    toggleMenu()
    toast("MeowHub", "GUI Hidden. Use Keybind or Shortcut button to open.", 3, Colors.Accent)
end)

-- Expand Dot (Green)
createMacDot(Color3.fromRGB(39, 174, 96), 50, function()
    tween(Win, 0.3, { Position = UDim2.new(0.5, -380, 0.5, -240) })
end)

-- Draggable Logic
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

-- ═══════════════════════════════════════════
-- CONTAINER FRAME
-- ═══════════════════════════════════════════
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, 0, 1, -36)
Container.Position = UDim2.new(0, 0, 0, 36)
Container.BackgroundTransparency = 1
Container.Parent = Win

-- ═══════════════════════════════════════════
-- RIBBON (Action Strip)
-- ═══════════════════════════════════════════
local Ribbon = Instance.new("Frame")
Ribbon.Size = UDim2.new(0, 42, 1, 0)
Ribbon.BackgroundColor3 = Colors.BgRibbon
Ribbon.BorderSizePixel = 0
Ribbon.Parent = Container

local ribbonBorder = Instance.new("Frame")
ribbonBorder.Size = UDim2.new(0, 1, 1, 0)
ribbonBorder.Position = UDim2.new(1, -1, 0, 0)
ribbonBorder.BackgroundColor3 = Colors.Border
ribbonBorder.BorderSizePixel = 0
ribbonBorder.Parent = Ribbon

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
    
    -- Tooltip
    local tooltip = Instance.new("Frame")
    tooltip.Size = UDim2.new(0, 0, 0, 22)
    tooltip.Position = UDim2.new(1, 8, 0.5, -11)
    tooltip.BackgroundColor3 = Colors.BgTitlebar
    tooltip.BorderSizePixel = 0
    tooltip.ClipsDescendants = true
    tooltip.ZIndex = 50
    tooltip.Parent = frame
    
    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 4)
    tooltipCorner.Parent = tooltip
    
    local tooltipStroke = Instance.new("UIStroke")
    tooltipStroke.Color = Colors.Border
    tooltipStroke.Thickness = 1
    tooltipStroke.Parent = tooltip
    
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

-- Add padding to ribbon list
local ribbonPad = Instance.new("UIPadding")
ribbonPad.PaddingTop = UDim.new(0, 6)
ribbonPad.Parent = Ribbon

-- ═══════════════════════════════════════════
-- FILE EXPLORER SIDEBAR
-- ═══════════════════════════════════════════
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 178, 1, 0)
Sidebar.Position = UDim2.new(0, 42, 0, 0)
Sidebar.BackgroundColor3 = Colors.BgSidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Container

local sidebarBorder = Instance.new("Frame")
sidebarBorder.Size = UDim2.new(0, 1, 1, 0)
sidebarBorder.Position = UDim2.new(1, -1, 0, 0)
sidebarBorder.BackgroundColor3 = Colors.Border
sidebarBorder.BorderSizePixel = 0
sidebarBorder.Parent = Sidebar

-- Vault Label
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

-- Search Box
local SearchContainer = Instance.new("Frame")
SearchContainer.Size = UDim2.new(1, -24, 0, 24)
SearchContainer.Position = UDim2.new(0, 12, 0, 36)
SearchContainer.BackgroundColor3 = Colors.BgTitlebar
SearchContainer.BorderSizePixel = 0
SearchContainer.Parent = Sidebar

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 4)
searchCorner.Parent = SearchContainer

local searchStroke = Instance.new("UIStroke")
searchStroke.Color = Colors.Border
searchStroke.Thickness = 1
searchStroke.Parent = SearchContainer

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -8, 1, 0)
searchBox.Position = UDim2.new(0, 8, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Search notes..."
searchBox.PlaceholderColor3 = Colors.TextFaint
searchBox.TextColor3 = Colors.TextNormal
searchBox.TextSize = 11
searchBox.Font = Enum.Font.Gotham
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.ClearTextOnFocus = false
searchBox.Parent = SearchContainer

-- Folder node ("Files")
local filesFolder = Instance.new("Frame")
filesFolder.Size = UDim2.new(1, -24, 0, 24)
filesFolder.Position = UDim2.new(0, 12, 0, 68)
filesFolder.BackgroundTransparency = 1
filesFolder.Parent = Sidebar

local folderLabel = Instance.new("TextLabel")
folderLabel.Size = UDim2.new(1, 0, 1, 0)
folderLabel.BackgroundTransparency = 1
folderLabel.Text = "▼  📁  Notes"
folderLabel.TextColor3 = Colors.TextMuted
folderLabel.TextSize = 11
folderLabel.Font = Enum.Font.GothamBold
folderLabel.TextXAlignment = Enum.TextXAlignment.Left
folderLabel.Parent = filesFolder

-- File list container
local FileList = Instance.new("ScrollingFrame")
FileList.Size = UDim2.new(1, -12, 1, -100)
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

-- ═══════════════════════════════════════════
-- EDITOR (Main Area)
-- ═══════════════════════════════════════════
local Editor = Instance.new("Frame")
Editor.Size = UDim2.new(1, -220, 1, 0)
Editor.Position = UDim2.new(0, 220, 0, 0)
Editor.BackgroundColor3 = Colors.BgEditor
Editor.BorderSizePixel = 0
Editor.Parent = Container

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 32)
TabBar.BackgroundColor3 = Colors.BgTitlebar
TabBar.BorderSizePixel = 0
TabBar.Parent = Editor

local tabbarBorder = Instance.new("Frame")
tabbarBorder.Size = UDim2.new(1, 0, 0, 1)
tabbarBorder.Position = UDim2.new(0, 0, 1, -1)
tabbarBorder.BackgroundColor3 = Colors.Border
tabbarBorder.BorderSizePixel = 0
tabbarBorder.Parent = TabBar

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

-- Document area (Obsidian markdown panel)
local DocPanel = Instance.new("Frame")
DocPanel.Size = UDim2.new(1, 0, 1, -32)
DocPanel.Position = UDim2.new(0, 0, 0, 32)
DocPanel.BackgroundTransparency = 1
DocPanel.ClipsDescendants = true
DocPanel.Parent = Editor

-- Scrollable content
local DocScroll = Instance.new("ScrollingFrame")
DocScroll.Size = UDim2.new(1, 0, 1, 0)
DocScroll.BackgroundTransparency = 1
DocScroll.ScrollBarThickness = 2
DocScroll.ScrollBarImageColor3 = Colors.Border
DocScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
DocScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
DocScroll.Parent = DocPanel

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

-- Page Title
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

local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(1, 0, 0, 1)
titleLine.BackgroundColor3 = Colors.Border
titleLine.BorderSizePixel = 0
titleLine.LayoutOrder = 3
titleLine.Parent = DocScroll

-- Scripts container inside doc list
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

-- ═══════════════════════════════════════════
-- AUTO-EXECUTE & TELEPORT QUEUE SYSTEM
-- ═══════════════════════════════════════════
local function setupTeleportQueue()
    local queue = queue_on_teleport or (syn and syn.queue_on_teleport)
    if queue and getgenv().MeowHubSource then
        pcall(queue, "task.spawn(function() if not game:IsLoaded() then game.Loaded:Wait() end task.wait(1) getgenv().MeowHubSource = [====" .. "[" .. getgenv().MeowHubSource .. "]" .. "====] loadstring(getgenv().MeowHubSource)() end)")
    end
end

-- ═══════════════════════════════════════════
-- UTILITY EXTRA ACTIONS
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
-- VIEW UTILITIES
-- ═══════════════════════════════════════════
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
    ddList.Size = UDim2.new(0, 130, 0, #options * 24 + 4)
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
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = ddList
    
    local listPadding = Instance.new("UIPadding")
    listPadding.PaddingTop = UDim.new(0, 2)
    listPadding.PaddingBottom = UDim.new(0, 2)
    listPadding.PaddingLeft = UDim.new(0, 4)
    listPadding.PaddingRight = UDim.new(0, 4)
    listPadding.Parent = ddList
    
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
        optBtn.Parent = ddList
        
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

-- ═══════════════════════════════════════════
-- VIEW & ROW DATA POPULATION
-- ═══════════════════════════════════════════
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
    
    -- Slider Toggle (Obsidian Style - minimal rounded pill)
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
        
        -- Custom settings dependencies
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
    
    -- Subtly highlight row on hover
    row.MouseEnter:Connect(function()
        tween(row, 0.15, { BackgroundTransparency = 0 })
    end)
    
    row.MouseLeave:Connect(function()
        tween(row, 0.15, { BackgroundTransparency = 1 })
    end)
    
    return row
end
-- ═══════════════════════════════════════════
-- VIEW MANAGEMENT
-- ═══════════════════════════════════════════
local activeCategoryIdx = 1
local tabButtons = {}
local fileNodes = {}
local activeTabs = {}

local function selectCategory(idx)
    activeCategoryIdx = idx
    local cat = Categories[idx]
    
    -- Set page title
    pageTitle.Text = "# " .. cat.Name
    
    -- Remove previous nodes
    for _, child in ipairs(ScriptContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Render based on page type
    if cat.IsInfoPage then
        -- Render groupbox (callout box)
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
        -- Render settings controls
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
        
    else
        -- Normal scripts list
        for _, s in ipairs(cat.Scripts) do
            createSettingsRow(s)
        end
    end
    
    -- Highlight active file explorer node
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
    
    -- Ensure tab exists and set it active
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

-- ═══════════════════════════════════════════
-- BUILD FILE LIST AND TABS
-- ═══════════════════════════════════════════
for i, cat in ipairs(Categories) do
    -- Create file explorer tree item
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
    
    -- Create tab button
    local tab = Instance.new("Frame")
    tab.Size = UDim2.new(0, 110, 1, 0)
    tab.BackgroundColor3 = Colors.BgTitlebar
    tab.BorderSizePixel = 0
    tab.LayoutOrder = i
    tab.Visible = (i <= 3) -- Default show first three tabs
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
    
    -- Accent line (indicating tab selection)
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

-- ═══════════════════════════════════════════
-- SEARCH LOGIC
-- ═══════════════════════════════════════════
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local text = string.lower(searchBox.Text)
    
    if text == "" then
        selectCategory(activeCategoryIdx)
        for _, node in ipairs(fileNodes) do
            node.Frame.Visible = true
        end
        return
    end
    
    -- Filter explorer list
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
    
    -- Display search result list in Editor
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

-- ═══════════════════════════════════════════
-- TOGGLE INTERACTION (Keybind)
-- ═══════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == guiToggleKey then
        toggleMenu()
    end
end)

-- ═══════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════
selectCategory(1)

-- Opening Animation
Win.Size = UDim2.new(0, 760, 0, 0)
Win.Position = UDim2.new(0.5, -380, 0.5, 0)
task.wait(0.2)
tween(Win, 0.45, {
    Size = UDim2.new(0, 760, 0, 480),
    Position = UDim2.new(0.5, -380, 0.5, -240),
}, Enum.EasingStyle.Back)

toast("MeowHub Loaded", "hello mate. Keybind: RightShift.", 3, Colors.Accent)
print("[MeowHub] Obsidian GUI initialized.")
]====]

loadstring(getgenv().MeowHubSource)()
