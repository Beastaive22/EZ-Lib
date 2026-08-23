--[[
    EZ Hub UI Library
    Premium dark glassmorphism UI for Roblox
    PC + Mobile 
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local EZ = {
    Flags = {},
    Windows = {},
    Notifications = {},
    Theme = nil,
    _connections = {},
    _listeners = {},
    _elements = {},
    _errorLog = {},
    _onError = nil,
    _activeDrag = nil, -- mutex so picker drag doesn't bleed into slider
    _destroyed = false,
    -- most notification cards on screen at once; the holder is a fixed column
    MaxNotifications = 5,
    _version = "3.2.2"
}

-- defaults
local DEFAULT_THEME = {
    Name = "Midnight",
    Base = Color3.fromRGB(10, 10, 14),
    Surface = Color3.fromRGB(18, 18, 26),
    Panel = Color3.fromRGB(24, 24, 36),
    Border = Color3.fromRGB(45, 45, 65),
    Accent = Color3.fromRGB(124, 92, 252),
    AccentDark = Color3.fromRGB(90, 65, 200),
    Text = Color3.fromRGB(232, 232, 240),
    TextDim = Color3.fromRGB(136, 136, 170),
    TextMuted = Color3.fromRGB(80, 80, 110),
    Success = Color3.fromRGB(80, 220, 120),
    Warning = Color3.fromRGB(255, 180, 50),
    Error = Color3.fromRGB(255, 80, 80),
    Info = Color3.fromRGB(80, 160, 255),
}

local function cloneTheme(theme)
    local copy = {}
    for k, v in theme do copy[k] = v end
    return copy
end

EZ.Theme = cloneTheme(DEFAULT_THEME)

-- Track every RBXScriptConnection created by the library so EZ:Destroy()
-- can reliably disconnect callbacks, including global UserInputService
-- and Players connections.
local function trackConnection(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(EZ._connections, connection)

    -- During CreateWindow, also associate the connection with that window so
    -- window:Destroy() can clean up only its own callbacks.
    local owner = EZ._connectionOwner
    if owner then
        owner._connections = owner._connections or {}
        table.insert(owner._connections, connection)
    end

    return connection
end

local function disconnectConnection(connection)
    if not connection then return end
    pcall(function() connection:Disconnect() end)

    for i = #EZ._connections, 1, -1 do
        if EZ._connections[i] == connection then
            table.remove(EZ._connections, i)
            break
        end
    end
end

-- preset themes (devs love these)
EZ.Themes = {
    Midnight = DEFAULT_THEME,

    Catppuccin = {
        Name = "Catppuccin",
        Base = Color3.fromRGB(24, 24, 37),
        Surface = Color3.fromRGB(30, 30, 46),
        Panel = Color3.fromRGB(49, 50, 68),
        Border = Color3.fromRGB(69, 71, 90),
        Accent = Color3.fromRGB(203, 166, 247),
        AccentDark = Color3.fromRGB(166, 132, 213),
        Text = Color3.fromRGB(205, 214, 244),
        TextDim = Color3.fromRGB(166, 173, 200),
        TextMuted = Color3.fromRGB(108, 112, 134),
        Success = Color3.fromRGB(166, 227, 161),
        Warning = Color3.fromRGB(249, 226, 175),
        Error = Color3.fromRGB(243, 139, 168),
        Info = Color3.fromRGB(137, 180, 250),
    },

    TokyoNight = {
        Name = "Tokyo Night",
        Base = Color3.fromRGB(26, 27, 38),
        Surface = Color3.fromRGB(36, 40, 59),
        Panel = Color3.fromRGB(41, 46, 66),
        Border = Color3.fromRGB(65, 72, 104),
        Accent = Color3.fromRGB(125, 207, 255),
        AccentDark = Color3.fromRGB(86, 154, 200),
        Text = Color3.fromRGB(192, 202, 245),
        TextDim = Color3.fromRGB(154, 165, 206),
        TextMuted = Color3.fromRGB(86, 95, 137),
        Success = Color3.fromRGB(158, 206, 106),
        Warning = Color3.fromRGB(224, 175, 104),
        Error = Color3.fromRGB(247, 118, 142),
        Info = Color3.fromRGB(122, 162, 247),
    },

    Dracula = {
        Name = "Dracula",
        Base = Color3.fromRGB(40, 42, 54),
        Surface = Color3.fromRGB(52, 54, 70),
        Panel = Color3.fromRGB(68, 71, 90),
        Border = Color3.fromRGB(98, 114, 164),
        Accent = Color3.fromRGB(189, 147, 249),
        AccentDark = Color3.fromRGB(150, 110, 210),
        Text = Color3.fromRGB(248, 248, 242),
        TextDim = Color3.fromRGB(180, 180, 190),
        TextMuted = Color3.fromRGB(98, 114, 164),
        Success = Color3.fromRGB(80, 250, 123),
        Warning = Color3.fromRGB(241, 250, 140),
        Error = Color3.fromRGB(255, 85, 85),
        Info = Color3.fromRGB(139, 233, 253),
    },

    Nord = {
        Name = "Nord",
        Base = Color3.fromRGB(46, 52, 64),
        Surface = Color3.fromRGB(59, 66, 82),
        Panel = Color3.fromRGB(67, 76, 94),
        Border = Color3.fromRGB(76, 86, 106),
        Accent = Color3.fromRGB(136, 192, 208),
        AccentDark = Color3.fromRGB(94, 129, 172),
        Text = Color3.fromRGB(236, 239, 244),
        TextDim = Color3.fromRGB(216, 222, 233),
        TextMuted = Color3.fromRGB(129, 161, 193),
        Success = Color3.fromRGB(163, 190, 140),
        Warning = Color3.fromRGB(235, 203, 139),
        Error = Color3.fromRGB(191, 97, 106),
        Info = Color3.fromRGB(129, 161, 193),
    },

    Rose = {
        Name = "Rose Pine",
        Base = Color3.fromRGB(25, 23, 36),
        Surface = Color3.fromRGB(38, 35, 58),
        Panel = Color3.fromRGB(49, 46, 77),
        Border = Color3.fromRGB(64, 61, 82),
        Accent = Color3.fromRGB(235, 188, 186),
        AccentDark = Color3.fromRGB(196, 167, 231),
        Text = Color3.fromRGB(224, 222, 244),
        TextDim = Color3.fromRGB(144, 140, 170),
        TextMuted = Color3.fromRGB(110, 106, 134),
        Success = Color3.fromRGB(156, 207, 216),
        Warning = Color3.fromRGB(246, 193, 119),
        Error = Color3.fromRGB(235, 111, 146),
        Info = Color3.fromRGB(196, 167, 231),
    },

    Cyberpunk = {
        Name = "Cyberpunk",
        Base = Color3.fromRGB(13, 13, 20),
        Surface = Color3.fromRGB(20, 20, 35),
        Panel = Color3.fromRGB(28, 28, 48),
        Border = Color3.fromRGB(255, 0, 128),
        Accent = Color3.fromRGB(0, 255, 200),
        AccentDark = Color3.fromRGB(0, 180, 150),
        Text = Color3.fromRGB(240, 240, 255),
        TextDim = Color3.fromRGB(180, 180, 220),
        TextMuted = Color3.fromRGB(120, 100, 180),
        Success = Color3.fromRGB(0, 255, 150),
        Warning = Color3.fromRGB(255, 200, 0),
        Error = Color3.fromRGB(255, 50, 100),
        Info = Color3.fromRGB(100, 200, 255),
    },

    Monochrome = {
        Name = "Monochrome",
        Base = Color3.fromRGB(15, 15, 15),
        Surface = Color3.fromRGB(22, 22, 22),
        Panel = Color3.fromRGB(32, 32, 32),
        Border = Color3.fromRGB(60, 60, 60),
        Accent = Color3.fromRGB(230, 230, 230),
        AccentDark = Color3.fromRGB(180, 180, 180),
        Text = Color3.fromRGB(245, 245, 245),
        TextDim = Color3.fromRGB(170, 170, 170),
        TextMuted = Color3.fromRGB(110, 110, 110),
        Success = Color3.fromRGB(200, 200, 200),
        Warning = Color3.fromRGB(220, 220, 220),
        Error = Color3.fromRGB(255, 100, 100),
        Info = Color3.fromRGB(180, 180, 180),
    },
}

-- utils
local function tween(obj, props, dur, style)
    local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.22, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end

local function create(cls, props)
    local inst = Instance.new(cls)
    for k, v in props do
        if k ~= "Parent" and k ~= "Children" then
            inst[k] = v
        end
    end
    if props.Children then
        for _, child in props.Children do
            child.Parent = inst
        end
    end
    if props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or EZ.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0.5,
        Parent = parent
    })
end

local function isMobile()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function getScreenSize()
    local cam = workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function round(v, inc)
    inc = inc or 1
    return math.floor(v / inc + 0.5) * inc
end

local function color3ToHex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function hexToColor3(hex)
    if type(hex) ~= "string" then return nil end
    hex = hex:gsub("#", "")
    if #hex ~= 6 or not hex:match("^[%x]+$") then return nil end

    local r = tonumber(hex:sub(1,2), 16)
    local g = tonumber(hex:sub(3,4), 16)
    local b = tonumber(hex:sub(5,6), 16)
    if not r or not g or not b then return nil end
    return Color3.fromRGB(r, g, b)
end

-- error handling
local function EZError(source, err)
    local trace = debug.traceback(tostring(err), 3)
    local entry = {
        source = source,
        message = tostring(err),
        traceback = trace,
        time = os.clock(),
    }
    table.insert(EZ._errorLog, entry)
    if #EZ._errorLog > 50 then table.remove(EZ._errorLog, 1) end

    warn(`[EZ] {source}: {err}`)

    if EZ._onError then
        pcall(EZ._onError, entry)
    end

    -- show notification if Notify is available
    pcall(function()
        EZ:Notify({
            Title = "EZ Error",
            Content = source .. ": " .. tostring(err):sub(1, 120),
            Duration = 5,
            Type = "error",
        })
    end)
end

local function safecall(source, fn, ...)
    local args = table.pack(...)
    task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args, 1, args.n))
        if not ok then EZError(source, err) end
    end)
end

function EZ:OnError(fn)
    self._onError = fn
end

function EZ:GetErrors()
    return self._errorLog
end

-- flag listener system
function EZ:OnFlagChanged(id, fn)
    if not self._listeners[id] then self._listeners[id] = {} end
    table.insert(self._listeners[id], fn)
end

function EZ:OffFlagChanged(id, fn)
    local cbs = self._listeners[id]
    if not cbs then return end
    for i = #cbs, 1, -1 do
        if cbs[i] == fn then table.remove(cbs, i) end
    end
    if #cbs == 0 then self._listeners[id] = nil end
end

local function fireListeners(id, val)
    local cbs = EZ._listeners[id]
    if cbs then
        for _, fn in cbs do safecall(`Listener:{id}`, fn, val) end
    end
end

local function tagSearch(frame, text)
    if not frame or not text then return end
    frame:SetAttribute("EZSearch", string.lower(text))
end

-- Conditional visibility and the header search filter both want to own
-- frame.Visible. Each records its own verdict in an attribute and the frame is
-- shown only when neither wants it hidden, so clearing a search no longer
-- reveals elements whose VisibleWhen dependency is still off.
local function applyElementVisibility(frame)
    frame.Visible = not frame:GetAttribute("EZCondHidden")
        and not frame:GetAttribute("EZSearchHidden")
end

local function setupVisibility(elem, frame, opts)
    if not opts.VisibleWhen then return end
    local depId = opts.VisibleWhen
    local function check(v)
        frame:SetAttribute("EZCondHidden", not v) -- truthy check
        applyElementVisibility(frame)
    end
    -- initial state (a missing dependency flag counts as off)
    check(EZ.Flags[depId])
    EZ:OnFlagChanged(depId, check)
end

-- attach OnChanged to element objects
local function attachOnChanged(elem, id)
    function elem:OnChanged(fn)
        EZ:OnFlagChanged(id, fn)
        return self
    end
end

-- wire tooltip if opts.Tooltip is set
local function setupTooltip(frame, opts)
    if not opts or not opts.Tooltip then return end
    if EZ.AttachTooltip then
        pcall(function() EZ:AttachTooltip(frame, opts.Tooltip) end)
    end
end

-- cleanup old gui(s) from a previous library load. Prefer the executor UI
-- container when available, otherwise fall back to PlayerGui.
pcall(function()
    local parent = (gethui and gethui()) or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if parent then
        for _, name in {"EZUI", "EZNotifs"} do
            local old = parent:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end
end)

-- root gui
local gui = create("ScreenGui", {
    Name = "EZUI",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 500
})
pcall(function() gui.Parent = gethui() end)
if not gui.Parent then
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- notifications live in a separate screengui so they always float above the window
local notifGui = create("ScreenGui", {
    Name = "EZNotifs",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    DisplayOrder = 10000,
})
pcall(function() notifGui.Parent = gethui() end)
if not notifGui.Parent then
    notifGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- notification container (top right). Built on demand because EZ:Destroy()
-- empties the notification ScreenGui: without rebuilding it, every later
-- Notify() would parent its card to a destroyed frame and render nothing.
local notifHolder
local function ensureNotifHolder()
    if notifHolder and notifHolder.Parent then return notifHolder end
    notifHolder = create("Frame", {
        Name = "Notifications",
        Size = UDim2.new(0, 300, 1, 0),
        Position = UDim2.new(1, -310, 0, 10),
        BackgroundTransparency = 1,
        Parent = notifGui,
        Children = {
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                VerticalAlignment = Enum.VerticalAlignment.Top,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
            })
        }
    })
    return notifHolder
end
ensureNotifHolder()

-- ~~
-- ICON RESOLVER
-- accepts: rbxassetid://..., plain number id, "rbxassetid://12345",
-- or a lucide icon name ("sword", "heart", "arrow-left") if icons are bound
-- ~~
function EZ:SetIcons(iconPack)
    self._icons = iconPack
end

function EZ:ResolveIcon(ref)
    if not ref then return nil end
    if type(ref) == "number" then return "rbxassetid://" .. ref end
    if type(ref) ~= "string" then return nil end
    -- already an asset url
    if ref:find("rbxassetid://") or ref:find("rbxthumb://") or ref:find("rbxgameasset://") or ref:find("http") then
        return ref
    end
    -- numeric string
    if tonumber(ref) then return "rbxassetid://" .. ref end
    -- lucide name via bound icon pack
    if self._icons then
        local id
        pcall(function()
            if type(self._icons.Get) == "function" then
                id = self._icons:Get(ref)
            end
            if not id and type(self._icons.Fuzzy) == "function" then
                id = self._icons:Fuzzy(ref)
            end
        end)
        if id then return id end
    end
    return nil
end

function EZ:Notify(opts)
    opts = opts or {}
    local title = opts.Title or "EZ"
    local content = opts.Content or ""
    local dur = opts.Duration or 4
    local ntype = opts.Type or "info"
    if self._notifHook then pcall(self._notifHook, opts) end
    local theme = self.Theme

    local accentColor = ({
        info = theme.Info,
        success = theme.Success,
        warning = theme.Warning,
        error = theme.Error,
    })[ntype] or theme.Accent

    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.1,
        ClipsDescendants = true,
        Parent = ensureNotifHolder()
    })
    addCorner(card, 10)
    addStroke(card, accentColor, 1, 0.4)

    -- accent bar left
    create("Frame", {
        Size = UDim2.new(0, 3, 1, -8),
        Position = UDim2.new(0, 6, 0, 4),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        Parent = card,
        Children = { create("UICorner", { CornerRadius = UDim.new(0, 2) }) }
    })

    create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 16, 0, 8),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card
    })

    local contentLbl = create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 0),
        Position = UDim2.new(0, 16, 0, 26),
        BackgroundTransparency = 1,
        Text = content,
        TextColor3 = theme.TextDim,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card
    })

    table.insert(self.Notifications, card)

    -- Cap what is on screen. The holder is a fixed-width column driven by a
    -- list layout, so a burst simply ran off the bottom of the display.
    local maxVisible = math.max(1, tonumber(self.MaxNotifications) or 5)
    while #self.Notifications > maxVisible do
        local oldest = table.remove(self.Notifications, 1)
        if oldest then
            tween(oldest, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.2)
            task.delay(0.25, function() pcall(function() oldest:Destroy() end) end)
        end
    end

    -- Animate in on the next frame. TextBounds is still empty on the frame the
    -- label is created, so measuring immediately clipped every wrapped line.
    task.defer(function()
        if not card.Parent then return end
        local textH = math.max(contentLbl.TextBounds.Y, contentLbl.AbsoluteSize.Y, 14)
        tween(card, {Size = UDim2.new(1, 0, 0, 26 + textH + 12)}, 0.3)
    end)

    -- auto dismiss
    task.delay(dur, function()
        tween(card, {Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1}, 0.25)
        task.wait(0.3)
        local idx = table.find(EZ.Notifications, card)
        if idx then table.remove(EZ.Notifications, idx) end
        pcall(function() card:Destroy() end)
    end)

    return card
end

-- ~~---------
-- WINDOW
-- ~~---------
-- ~~---------
-- KEY SYSTEM
-- ~~---------
function EZ:KeySystem(opts)
    opts = opts or {}
    local title = opts.Title or "Key System"
    local subtitle = opts.SubTitle or "Enter your key to continue"
    local keys = opts.Keys or {}
    local hashedKeys = opts.HashedKeys -- optional: pre-hashed sha256 keys (recommended)
    local saveName = opts.SaveKey or "EZKey.txt"
    local cb = opts.Callback or function() end
    local maxAttempts = opts.MaxAttempts or 5
    local theme = self.Theme
    local mobile = isMobile()

    -- hash helper (SHA-256 with HWID salt for binding)
    local function hwidSalt()
        local h
        pcall(function() h = (gethwid and gethwid()) or "" end)
        return tostring(h or "")
    end

    local hashAvailable = false
    pcall(function()
        hashAvailable = crypt ~= nil and type(crypt.hash) == "function"
    end)

    local function hashKey(k)
        if not hashAvailable then return k end
        local ok, out = pcall(crypt.hash, k .. "::EZ::" .. hwidSalt(), "sha256")
        return ok and out or k
    end

    -- valid hash list
    local validHashes = {}
    if hashedKeys then
        for _, h in hashedKeys do validHashes[h] = true end
    else
        for _, k in keys do validHashes[hashKey(k)] = true end
    end

    local function checkKey(input)
        return validHashes[hashKey(input)] == true
    end

    -- check saved key first (file stores HWID-bound hash, not raw key)
    local savedHash = nil
    pcall(function()
        if isfile and isfile(saveName) then savedHash = readfile(saveName) end
    end)
    if savedHash and validHashes[savedHash] then
        safecall("KeySystem", cb, true)
        return true
    end

    -- attempt counter (in-memory, persists for session)
    local attempts = 0

    local passed = false
    local keyGui = create("Frame", {
        Name = "EZKeySystem",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.4,
        ZIndex = 200,
        Parent = gui
    })

    local card = create("Frame", {
        Size = UDim2.new(0, mobile and 320 or 340, 0, 0),
        Position = UDim2.new(0.5, mobile and -160 or -170, 0.5, 0),
        BackgroundColor3 = theme.Base,
        ClipsDescendants = true,
        ZIndex = 201,
        Parent = keyGui
    })
    addCorner(card, 14)
    addStroke(card, theme.Border, 1, 0.3)

    -- accent line
    create("Frame", {
        Size = UDim2.new(0, 40, 0, 2),
        Position = UDim2.new(0.5, -20, 0, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 210,
        Parent = card
    })

    -- title
    create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 20),
        Position = UDim2.new(0, 20, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = theme.Text,
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 210,
        Parent = card
    })

    create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 14),
        Position = UDim2.new(0, 20, 0, 42),
        BackgroundTransparency = 1,
        Text = subtitle,
        TextColor3 = theme.TextMuted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 210,
        Parent = card
    })

    -- input
    local inputBg = create("Frame", {
        Size = UDim2.new(1, -40, 0, 38),
        Position = UDim2.new(0, 20, 0, 68),
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 210,
        Parent = card
    })
    addCorner(inputBg, 8)
    local keyStroke = addStroke(inputBg, theme.Border, 1, 0.5)

    local keyInput = create("TextBox", {
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Enter key...",
        TextColor3 = theme.Text,
        PlaceholderColor3 = theme.TextMuted,
        TextSize = 13,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 211,
        Parent = inputBg
    })

    trackConnection(keyInput.Focused, function()
        tween(keyStroke, {Color = theme.Accent, Transparency = 0}, 0.15)
    end)
    trackConnection(keyInput.FocusLost, function()
        tween(keyStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
    end)

    -- status label
    local statusLabel = create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 14),
        Position = UDim2.new(0, 20, 0, 112),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.Error,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 210,
        Parent = card
    })

    -- submit button
    local submitBtn = create("TextButton", {
        Size = UDim2.new(1, -40, 0, 36),
        Position = UDim2.new(0, 20, 0, 130),
        BackgroundColor3 = theme.Accent,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 210,
        Parent = card
    })
    addCorner(submitBtn, 8)

    create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "Verify",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ZIndex = 211,
        Parent = submitBtn
    })

    trackConnection(submitBtn.MouseEnter, function()
        tween(submitBtn, {BackgroundColor3 = theme.AccentDark}, 0.15)
    end)
    trackConnection(submitBtn.MouseLeave, function()
        tween(submitBtn, {BackgroundColor3 = theme.Accent}, 0.15)
    end)

    -- get key link (styled, secondary button below verify)
    if opts.GetKeyLink then
        local linkBtn = create("TextButton", {
            Size = UDim2.new(1, -40, 0, mobile and 36 or 32),
            Position = UDim2.new(0, 20, 0, 176),
            BackgroundColor3 = theme.Surface,
            BackgroundTransparency = 0.2,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 210,
            Parent = card
        })
        addCorner(linkBtn, 8)
        local linkStroke = addStroke(linkBtn, theme.Border, 1, 0.5)

        -- icon + text together
        local row = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ZIndex = 211,
            Parent = linkBtn
        })
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            Parent = row
        })

        -- ResolveIcon goes through the pack's own API. Indexing _icons
        -- directly never matched, because the pack keeps its table private.
        local iconImg = EZ:ResolveIcon("external-link") or "rbxassetid://104262388679305"
        create("ImageLabel", {
            Size = UDim2.new(0, 14, 0, 14),
            BackgroundTransparency = 1,
            Image = iconImg,
            ImageColor3 = theme.Accent,
            ZIndex = 212,
            LayoutOrder = 1,
            Parent = row
        })
        local linkLbl = create("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = opts.GetKeyText or "Get Key",
            TextColor3 = theme.Text,
            TextSize = 12,
            Font = Enum.Font.GothamMedium,
            ZIndex = 212,
            LayoutOrder = 2,
            Parent = row
        })

        trackConnection(linkBtn.MouseEnter, function()
            tween(linkBtn, {BackgroundTransparency = 0.05}, 0.15)
            tween(linkStroke, {Color = theme.Accent, Transparency = 0.2}, 0.15)
        end)
        trackConnection(linkBtn.MouseLeave, function()
            tween(linkBtn, {BackgroundTransparency = 0.2}, 0.15)
            tween(linkStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
        end)
        trackConnection(linkBtn.MouseButton1Click, function()
            pcall(function() setclipboard(opts.GetKeyLink) end)
            linkLbl.Text = "Link copied!"
            linkLbl.TextColor3 = theme.Success
            task.delay(1.5, function()
                if linkLbl.Parent then
                    linkLbl.Text = opts.GetKeyText or "Get Key"
                    linkLbl.TextColor3 = theme.Text
                end
            end)
        end)
    end

    local cardH = opts.GetKeyLink and (mobile and 226 or 222) or 180

    -- animate in
    tween(card, {
        Size = UDim2.new(0, mobile and 320 or 340, 0, cardH),
        Position = UDim2.new(0.5, mobile and -160 or -170, 0.5, -cardH/2),
    }, 0.3)

    -- verify
    local locked = false
    local function tryKey()
        if locked then return end
        local input = keyInput.Text
        if input == "" then
            statusLabel.Text = "Enter a key first"
            statusLabel.TextColor3 = theme.Warning
            return
        end

        if checkKey(input) then
            statusLabel.Text = "Key accepted!"
            statusLabel.TextColor3 = theme.Success
            -- store hash, not the raw key (file leak doesn't expose key)
            pcall(function() writefile(saveName, hashKey(input)) end)
            passed = true
            tween(card, {
                Size = UDim2.new(0, mobile and 320 or 340, 0, 0),
                Position = UDim2.new(0.5, mobile and -160 or -170, 0.5, 0),
            }, 0.25)
            tween(keyGui, {BackgroundTransparency = 1}, 0.3)
            task.delay(0.3, function()
                pcall(function() keyGui:Destroy() end)
                safecall("KeySystem", cb, true)
            end)
        else
            attempts = attempts + 1
            if attempts >= maxAttempts then
                locked = true
                statusLabel.Text = `Too many attempts. Locked.`
                statusLabel.TextColor3 = theme.Error
                keyInput.TextEditable = false
                submitBtn.Active = false
                tween(submitBtn, {BackgroundTransparency = 0.6}, 0.2)
                if opts.OnLockout then pcall(opts.OnLockout) end
                return
            end
            statusLabel.Text = `Invalid key ({attempts}/{maxAttempts})`
            statusLabel.TextColor3 = theme.Error
            -- shake
            local orig = card.Position
            for i = 1, 3 do
                tween(card, {Position = orig + UDim2.new(0, 8, 0, 0)}, 0.04)
                task.wait(0.04)
                tween(card, {Position = orig + UDim2.new(0, -8, 0, 0)}, 0.04)
                task.wait(0.04)
            end
            tween(card, {Position = orig}, 0.04)
        end
    end

    trackConnection(submitBtn.MouseButton1Click, tryKey)
    trackConnection(keyInput.FocusLost, function(enter)
        if enter then tryKey() end
    end)

    -- Pre-hashed keys can only be checked where the executor exposes
    -- crypt.hash. Without it every input hashes to itself and can never match
    -- any sha256 digest, so fail loudly instead of letting the user guess
    -- against a gate that cannot open.
    if hashedKeys and not hashAvailable then
        locked = true
        statusLabel.Text = "Key check unsupported on this executor"
        statusLabel.TextColor3 = theme.Error
        keyInput.TextEditable = false
        submitBtn.Active = false
        tween(submitBtn, {BackgroundTransparency = 0.6}, 0.2)
        EZError("KeySystem", "HashedKeys needs crypt.hash, which this executor does not expose")
    end

    -- yield current thread until user passes or hits lockout
    -- (so caller can do `if not EZ:KeySystem(...) then return end` synchronously)
    while not passed and not locked do task.wait() end
    return passed
end

function EZ:CreateWindow(opts)
    self._destroyed = false
    opts = opts or {}
    local theme = self.Theme
    local mobile = isMobile()
    local screen = getScreenSize()

    local winW = opts.Width or (mobile and math.min(screen.X - 20, 380) or 560)
    local winH = opts.Height or (mobile and math.min(screen.Y - 80, 420) or 400)
    local tabW = opts.TabWidth or (mobile and 52 or 150)

    local window = {
        Tabs = {},
        ActiveTab = nil,
        Visible = true,
        _flags = self.Flags,
        _theme = theme,
        _connections = {},
        _popups = {},
        _destroyed = false,
    }

    -- All connections created synchronously while building this window are
    -- associated with it. Restore any previous owner before returning.
    local previousConnectionOwner = EZ._connectionOwner
    EZ._connectionOwner = window

    -- Tabs, sections and elements are built long after CreateWindow() returns,
    -- when the global owner is no longer set. Wrapping each builder re-asserts
    -- this window for the duration of the call, so window:Destroy() really does
    -- disconnect the global input hooks its keybinds/sliders/pickers created.
    local function owned(fn)
        return function(...)
            local prev = EZ._connectionOwner
            EZ._connectionOwner = window
            local ok, result = pcall(fn, ...)
            EZ._connectionOwner = prev
            if not ok then error(result, 0) end
            return result
        end
    end

    -- Popups (colour pickers) are parented to the root ScreenGui so section
    -- clipping cannot cut them off. That also means this window has to close
    -- and destroy them itself, or they outlive it on screen.
    local function registerPopup(frame, close)
        table.insert(window._popups, { frame = frame, close = close })
    end

    local function closePopups()
        for _, popup in window._popups do
            if popup.close then pcall(popup.close, true) end
        end
    end

    -- Only one dropdown may be open at a time, and clicking anywhere else
    -- dismisses it. Previously an open list stayed up indefinitely, covering
    -- whatever sat below it, and two lists could overlap each other.
    local activeDropdown = nil
    local function closeActiveDropdown()
        local d = activeDropdown
        activeDropdown = nil
        if d then pcall(d.close) end
    end
    local function setActiveDropdown(entry)
        if activeDropdown and activeDropdown ~= entry then closeActiveDropdown() end
        activeDropdown = entry
    end
    local function clearActiveDropdown(entry)
        if activeDropdown == entry then activeDropdown = nil end
    end

    local function pointInside(obj, pos)
        if not obj or not obj.Parent or not obj.Visible then return false end
        local p, sz = obj.AbsolutePosition, obj.AbsoluteSize
        return pos.X >= p.X and pos.X <= p.X + sz.X
            and pos.Y >= p.Y and pos.Y <= p.Y + sz.Y
    end

    -- main frame
    local main = create("Frame", {
        Name = "EZWindow",
        Size = UDim2.new(0, winW, 0, winH),
        Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.02,
        ClipsDescendants = true,
        Parent = gui
    })
    addCorner(main, 14)
    addStroke(main, theme.Border, 1, 0.25)
    -- subtle accent ambient (premium glow)
    local glowStroke = create("UIStroke", {
        Color = theme.Accent,
        Thickness = 2,
        Transparency = 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = main
    })
    window._glowStroke = glowStroke
    window._main = main

    -- ui scale (global multiplier for everything inside the window)
    local uiScale = create("UIScale", {
        Scale = opts.Scale or 1,
        Parent = main,
    })
    function window:SetScale(s)
        uiScale.Scale = math.clamp(s, 0.5, 2)
    end
    function window:GetScale() return uiScale.Scale end

    -- glass overlay
    local glass = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = main
    })
    addCorner(glass, 12)

    -- top accent line (gradient-faded edges so it feels like a glow strip)
    local accentLine = create("Frame", {
        Size = UDim2.new(0, 80, 0, 2),
        Position = UDim2.new(0.5, -40, 0, 0),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 10,
        Parent = main
    })
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = accentLine
    })

    -- header
    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = main
    })
    addCorner(header, 12)
    
    -- logo dot (gently pulses so window feels "alive")
    local logoDot = create("Frame", {
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 16, 0.5, -3),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = header
    })
    addCorner(logoDot, 4)
    -- pulse halo
    local logoHalo = create("Frame", {
        Size = UDim2.new(0, 7, 0, 7),
        Position = UDim2.new(0, 16, 0.5, -3),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = header,
    })
    addCorner(logoHalo, 4)
    task.spawn(function()
        while logoHalo.Parent do
            tween(logoHalo, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 12, 0.5, -8), BackgroundTransparency = 1}, 1.4, Enum.EasingStyle.Sine)
            task.wait(1.4)
            logoHalo.Size = UDim2.new(0, 7, 0, 7)
            logoHalo.Position = UDim2.new(0, 16, 0.5, -3)
            logoHalo.BackgroundTransparency = 0.6
            task.wait(0.4)
        end
    end)

    -- title
    create("TextLabel", {
        Size = UDim2.new(0, 200, 0, 16),
        Position = UDim2.new(0, 30, 0, 8),
        BackgroundTransparency = 1,
        Text = opts.Title or "EZ",
        TextColor3 = theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
        Parent = header
    })

    -- subtitle
    if opts.SubTitle then
        create("TextLabel", {
            Size = UDim2.new(0, 200, 0, 12),
            Position = UDim2.new(0, 30, 0, 24),
            BackgroundTransparency = 1,
            Text = opts.SubTitle,
            TextColor3 = theme.TextMuted,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
            Parent = header
        })
    end

    -- search bar (header right, before the 3 buttons; collapses to icon on mobile)
    local searchBarW = mobile and 28 or 160
    local searchBar = create("Frame", {
        Name = "EZSearchBar",
        Size = UDim2.new(0, searchBarW, 0, 26),
        Position = UDim2.new(1, -(110 + searchBarW + 6), 0.5, -13),
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = mobile and 0.4 or 0.1,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = header,
    })
    addCorner(searchBar, 6)
    local searchStroke = addStroke(searchBar, theme.Border, 1, 0.5)

    -- search icon
    create("ImageLabel", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 6, 0.5, -7),
        BackgroundTransparency = 1,
        Image = "rbxassetid://121018724060431",
        ImageColor3 = theme.TextMuted,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 8,
        Parent = searchBar,
    })

    local searchBox = create("TextBox", {
        Size = UDim2.new(1, -28, 1, 0),
        Position = UDim2.new(0, 24, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search...",
        TextColor3 = theme.Text,
        PlaceholderColor3 = theme.TextMuted,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 8,
        Parent = searchBar,
        Visible = not mobile,
    })

    trackConnection(searchBox.Focused, function()
        tween(searchStroke, {Color = theme.Accent, Transparency = 0.2}, 0.15)
    end)
    trackConnection(searchBox.FocusLost, function()
        tween(searchStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
    end)

    -- Dedicated drag handle. Keeping controls outside this hit area prevents
    -- minimize/close/search clicks from also starting a window drag.
    local dragHandle = create("TextButton", {
        Name = "EZDragHandle",
        Size = UDim2.new(1, -(110 + searchBarW + 12), 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
        Parent = header,
    })

    -- mobile: tap icon to expand. expanded bar sits ABOVE the buttons row
    -- (full width minus padding) so it doesnt clip the close/min/toggle.
    -- a small × at the right of the expanded bar lets users collapse it.
    local mobileExpanded = false
    local searchCloseBtn
    -- Where the collapsed bar sits. Recorded rather than recomputed so an
    -- addon that shifts the bar (NotificationHistory adds a header bell)
    -- does not get snapped back the first time the user collapses it.
    local searchCollapsedPos = searchBar.Position
    if mobile then
        local tapBtn = create("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 9,
            Parent = searchBar,
        })

        -- close icon that appears only when expanded, used to collapse
        searchCloseBtn = create("TextButton", {
            Size = UDim2.new(0, 22, 1, 0),
            Position = UDim2.new(1, -22, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 10,
            Visible = false,
            Parent = searchBar,
        })
        create("ImageLabel", {
            Size = UDim2.new(0, 12, 0, 12),
            Position = UDim2.new(0.5, -6, 0.5, -6),
            BackgroundTransparency = 1,
            Image = "rbxassetid://110786993356448",
            ImageColor3 = theme.TextMuted,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 11,
            Parent = searchCloseBtn,
        })

        local function collapse()
            mobileExpanded = false
            searchBox.Text = ""
            searchBox.Visible = false
            searchCloseBtn.Visible = false
            tween(searchBar, {Size = UDim2.new(0, 28, 0, 26), Position = searchCollapsedPos, BackgroundTransparency = 0.4}, 0.2)
            if window._applySearch then window:_applySearch("") end
        end

        trackConnection(tapBtn.MouseButton1Click, function()
            if mobileExpanded then return end
            searchCollapsedPos = searchBar.Position
            mobileExpanded = true
            searchBox.Visible = true
            -- shrink box width to leave room for × button
            searchBox.Size = UDim2.new(1, -52, 1, 0)
            -- Place the expanded bar near the right edge but stop short of the
            -- action buttons. The reserve covers collapse/minimize/close plus
            -- the optional NotificationHistory bell, which sits at -126.
            tween(searchBar, {Size = UDim2.new(1, -160, 0, 26), Position = UDim2.new(0, 12, 0.5, -13), BackgroundTransparency = 0}, 0.2)
            searchCloseBtn.Visible = true
            task.delay(0.22, function()
                if mobileExpanded then searchBox:CaptureFocus() end
            end)
        end)

        trackConnection(searchCloseBtn.MouseButton1Click, collapse)
        -- also collapse if user taps elsewhere & box loses focus with no text
        trackConnection(searchBox.FocusLost, function()
            if mobileExpanded and searchBox.Text == "" then
                task.wait(0.1)
                if mobileExpanded and searchBox.Text == "" then collapse() end
            end
        end)
    end

    -- core filter, walks every elem frame's EZSearch attr
    function window:_applySearch(q)
        q = string.lower(q or "")
        local searching = q ~= ""

        -- returns true when the section still has something worth showing
        local function filterSection(secFrame)
            local anyVisible = false
            for _, child in secFrame:GetDescendants() do
                if child:IsA("GuiObject") then
                    local s = child:GetAttribute("EZSearch")
                    if s then
                        local match = not searching or string.find(s, q, 1, true) ~= nil
                        child:SetAttribute("EZSearchHidden", not match)
                        applyElementVisibility(child)
                        if child.Visible then anyVisible = true end
                    end
                end
            end
            -- hide whole section if nothing matches and there's a query
            secFrame.Visible = not searching or anyVisible
            return secFrame.Visible
        end

        for _, t in self.Tabs do
            local content = t._content
            if content then
                -- sections parented straight to the tab
                for _, secFrame in content:GetChildren() do
                    if secFrame:IsA("Frame")
                        and not secFrame:GetAttribute("EZSubRow")
                        and not secFrame:GetAttribute("EZSubContainer")
                    then
                        filterSection(secFrame)
                    end
                end

                -- Sections that live inside a sub-tab. The container visibility
                -- belongs to the sub-tab selection, so it is only borrowed
                -- while a query is active and handed straight back afterwards
                -- instead of leaving every sub-tab showing at once.
                for _, sub in t.SubTabs or {} do
                    local container = sub._container
                    if container then
                        local anyVisible = false
                        for _, secFrame in container:GetChildren() do
                            if secFrame:IsA("Frame") and filterSection(secFrame) then
                                anyVisible = true
                            end
                        end
                        if searching then
                            container.Visible = anyVisible
                        else
                            container.Visible = t._activeSub == sub
                        end
                    end
                end
            end
        end
    end

    trackConnection(searchBox:GetPropertyChangedSignal("Text"), function()
        window:_applySearch(searchBox.Text)
    end)

    -- close button
    local windowCloseBtn = create("TextButton", {
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -36, 0.5, -12),
    BackgroundColor3 = theme.Panel,
    BackgroundTransparency = 0.15,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 7,
    AutoButtonColor = false,
    Parent = header
})
addCorner(windowCloseBtn, 8)
addStroke(windowCloseBtn, theme.Border, 1, 0.35)
    
    create("ImageLabel", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0.5, -6, 0.5, -6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://110786993356448",
        ImageColor3 = theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 8,
        Parent = windowCloseBtn,
    })
    
    trackConnection(windowCloseBtn.MouseEnter, function()
        tween(windowCloseBtn, {
    BackgroundColor3 = theme.Accent,
    BackgroundTransparency = 0
    }, 0.15)
    end)
    trackConnection(windowCloseBtn.MouseLeave, function()
        tween(windowCloseBtn, {
    BackgroundColor3 = theme.Panel,
    BackgroundTransparency = 0.15
}, 0.15)
    end)

    -- minimize button
    local minBtn = create("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -66, 0.5, -12),
        BackgroundColor3 = theme.Panel,
        BackgroundTransparency = 0.15,
        Text = "",
        BorderSizePixel = 0,
        ZIndex = 7,
        AutoButtonColor = false,
        Parent = header
    })
    create("ImageLabel", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0.5, -6, 0.5, -6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://118026365011536",
        ImageColor3 = theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 8,
        Parent = minBtn,
    })
    addCorner(minBtn, 8)
    addStroke(minBtn, theme.Border, 1, 0.35)

    trackConnection(minBtn.MouseEnter, function()
        tween(minBtn, {
    BackgroundColor3 = theme.Accent,
    BackgroundTransparency = 0
}, 0.15)
    end)
    trackConnection(minBtn.MouseLeave, function()
        tween(minBtn, {
    BackgroundColor3 = theme.Panel,
    BackgroundTransparency = 0.15
}, 0.15)
    end)

    -- tab sidebar
    local sidebar = create("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, tabW, 1, -48),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundColor3 = theme.Panel,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 4,
        ClipsDescendants = true,
        Parent = main
    })
   
        addCorner(collapseBtn, 8)
        addStroke(collapseBtn, theme.Border, 1, 0.35)
    
    -- sidebar separator
    create("Frame", {
        Size = UDim2.new(0, 1, 1, -12),
        Position = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = theme.Border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = sidebar
    })

    local tabList = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -6),
        Position = UDim2.new(0, 0, 0, 6),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 5,
        Parent = sidebar,
        Children = {
            create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 2),
            }),
            create("UIPadding", {
                PaddingTop = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 4),
                PaddingRight = UDim.new(0, 4),
            })
        }
    })

    -- active tab indicator (height adapts to tab content)
    local indicatorH = mobile and 28 or 18
    local tabIndicator = create("Frame", {
        Size = UDim2.new(0, 3, 0, indicatorH),
        Position = UDim2.new(0, 2, 0, 8),
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = sidebar
    })
    addCorner(tabIndicator, 2)

    -- content area
    local contentArea = create("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -(tabW + 2), 1, -48),
        Position = UDim2.new(0, tabW + 2, 0, 48),
        BackgroundTransparency = 1,
        ZIndex = 3,
        ClipsDescendants = true,
        Parent = main
    })

    -- UserInputService fires ahead of the GUI click events, so a click on the
    -- dropdown itself is recognised here and left alone.
    trackConnection(UserInputService.InputBegan, function(inp)
        if not activeDropdown then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = Vector2.new(inp.Position.X, inp.Position.Y)
        if pointInside(activeDropdown.list, pos) or pointInside(activeDropdown.header, pos) then
            return
        end
        closeActiveDropdown()
    end)

    -- dragging
    local dragging, dragStart, startPos = false, nil, nil

    local function beginDrag(pos)
        dragging = true
        dragStart = pos
        startPos = main.Position
    end
    local function updateDrag(pos)
        if not dragging then return end
        local delta = pos - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    local function endDrag() dragging = false end

    trackConnection(dragHandle.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            beginDrag(Vector2.new(inp.Position.X, inp.Position.Y))
        end
    end)
    trackConnection(UserInputService.InputChanged, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            updateDrag(Vector2.new(inp.Position.X, inp.Position.Y))
        end
    end)
    trackConnection(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            endDrag()
        end
    end)

    -- floating toggle pill
    -- toggle pill - supports text OR icon, auto-sizes
    local resolvedToggleIcon = EZ:ResolveIcon(opts.ToggleIcon)
    local pillText = opts.ToggleText or resolvedToggleIcon or "V"
    local pillIsIcon = resolvedToggleIcon ~= nil
    local pillH = mobile and 48 or 36

    -- calc width: auto-size for text length
    local pillW = pillH -- default square
    if not pillIsIcon and #pillText > 1 then
        -- estimate text width + padding
        pillW = math.max(pillH, #pillText * (mobile and 11 or 9) + (mobile and 24 or 18))
    end

    local togglePill = create("TextButton", {
        Name = "EZToggle",
        Size = UDim2.new(0, pillW, 0, pillH),
        Position = UDim2.new(0, 12, 0.5, -pillH/2),
        BackgroundColor3 = theme.Accent,
        BackgroundTransparency = 0.15,
        Text = "",
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 100,
        Visible = false,
        Parent = gui
    })
    addCorner(togglePill, pillH / 2)
    addStroke(togglePill, theme.Accent, 1, 0.3)

    if pillIsIcon then
        -- icon mode: use ImageLabel
        create("ImageLabel", {
            Size = UDim2.new(0, mobile and 22 or 18, 0, mobile and 22 or 18),
            Position = UDim2.new(0.5, mobile and -11 or -9, 0.5, mobile and -11 or -9),
            BackgroundTransparency = 1,
            Image = resolvedToggleIcon,
            ImageColor3 = theme.Text,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 101,
            Parent = togglePill
        })
    else
        -- text mode
        create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = pillText,
            TextColor3 = theme.Text,
            TextSize = mobile and 16 or 13,
            Font = Enum.Font.GothamBold,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 101,
            Parent = togglePill
        })
    end

    -- pill drag
    local pillDrag, pillDragStart, pillStartPos = false, nil, nil
    local pillMoved = false

    trackConnection(togglePill.InputBegan, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            pillDrag = true
            pillMoved = false
            pillDragStart = Vector2.new(inp.Position.X, inp.Position.Y)
            pillStartPos = togglePill.Position
        end
    end)
    trackConnection(UserInputService.InputChanged, function(inp)
        if not pillDrag then return end
        if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
            local pos = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = pos - pillDragStart
            if delta.Magnitude > 5 then pillMoved = true end
            togglePill.Position = UDim2.new(pillStartPos.X.Scale, pillStartPos.X.Offset + delta.X, pillStartPos.Y.Scale, pillStartPos.Y.Offset + delta.Y)
        end
    end)
    trackConnection(UserInputService.InputEnded, function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if pillDrag and not pillMoved then
                -- tap, toggle window
                window:Show()
            end
            pillDrag = false
        end
    end)

    -- hover glow on pill
    trackConnection(togglePill.MouseEnter, function()
        tween(togglePill, {BackgroundTransparency = 0}, 0.15)
    end)
    trackConnection(togglePill.MouseLeave, function()
        tween(togglePill, {BackgroundTransparency = 0.15}, 0.15)
    end)

    window._togglePill = togglePill

    -- show/hide
    local minimized = false
    local restorePosition = main.Position
    local restoreSize = main.Size

    function window:Show()
        if self._destroyed then return end
        if self.Visible and not minimized then return end

        minimized = false
        self.Visible = true
        main.Visible = true
        togglePill.Visible = false

        -- Restore the exact position/size from before minimizing.
        main.Position = restorePosition
        main.Size = UDim2.new(0, math.max(1, restoreSize.X.Offset * 0.9), 0, math.max(1, restoreSize.Y.Offset * 0.9))
        main.BackgroundTransparency = 0.5

        tween(main, {
            Size = restoreSize,
            BackgroundTransparency = 0.02
        }, 0.3)
    end

    function window:Hide()
        if self._destroyed then return end
        if not self.Visible or minimized then return end

        minimized = true
        self.Visible = false
        closePopups()
        restorePosition = main.Position
        restoreSize = main.Size

        -- Put the restore pill at the window's current center instead of
        -- always spawning it at the left side of the screen.
        local center = main.AbsolutePosition + (main.AbsoluteSize / 2)
        local screen = getScreenSize()
        local x = clamp(center.X - pillW / 2, 6, math.max(6, screen.X - pillW - 6))
        local y = clamp(center.Y - pillH / 2, 6, math.max(6, screen.Y - pillH - 6))
        togglePill.Position = UDim2.fromOffset(x, y)

        tween(main, {
            Size = UDim2.new(0, math.max(1, restoreSize.X.Offset * 0.9), 0, math.max(1, restoreSize.Y.Offset * 0.9)),
            BackgroundTransparency = 0.6
        }, 0.2)

        task.delay(0.22, function()
            if not minimized or self.Visible or not main.Parent then return end
            main.Visible = false
            if not self._pillSuppressed then
                togglePill.Visible = true
                tween(togglePill, {BackgroundTransparency = 0.15}, 0.2)
            else
                togglePill.Visible = false
            end
        end)
    end

    function window:Toggle()
        if self._destroyed then return end
        if minimized or not self.Visible then
            self:Show()
        else
            self:Hide()
        end
    end

    function window:Destroy()
        if self._destroyed then return end
        self._destroyed = true
        self.Visible = false

        -- Disconnect only this window's callbacks. This prevents dead windows
        -- from continuing to react to global UserInputService events.
        for _, connection in ipairs(self._connections or {}) do
            disconnectConnection(connection)
        end
        table.clear(self._connections or {})

        -- popups sit outside main, so they need destroying by hand
        for _, popup in self._popups do
            pcall(function() popup.frame:Destroy() end)
        end
        table.clear(self._popups)

        pcall(function() main:Destroy() end)
        pcall(function() togglePill:Destroy() end)

        for i = #EZ.Windows, 1, -1 do
            if EZ.Windows[i] == self then
                table.remove(EZ.Windows, i)
                break
            end
        end
    end
    window.ScreenGui = gui

    -- close / minimize
    trackConnection(windowCloseBtn.MouseButton1Click, function()
        -- full nuke: window + watermark + toggle pill + listeners + all EZ stuff
        EZ:Destroy()
    end)
    trackConnection(minBtn.MouseButton1Click, function()
        window:Hide()
    end)

    -- Delegate instead of aliasing: addons (QuickBar) replace Show/Hide on the
    -- window after this point, and a captured reference would skip their hook.
    function window:Minimize(...) return self:Hide(...) end
    function window:Restore(...) return self:Show(...) end

    -- toggle key
    local toggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
    trackConnection(UserInputService.InputBegan, function(inp, gpe)
        if gpe then return end
        if inp.KeyCode == toggleKey then
            window:Toggle()
        end
    end)

    -- open animation
    main.Size = UDim2.new(0, winW * 0.8, 0, winH * 0.8)
    main.BackgroundTransparency = 0.5
    tween(main, {
        Size = UDim2.new(0, winW, 0, winH),
        BackgroundTransparency = 0.02
    }, 0.35)

    -- ~~--------
    -- SIDEBAR COLLAPSE (mobile or opt-in)
    -- ~~--------
    local sidebarCollapsed = false
    local collapsedW = 0
    local expandedW = tabW

    local function applySidebar()
        local w = sidebarCollapsed and collapsedW or expandedW
        tween(sidebar, {Size = UDim2.new(0, w, 1, -48)}, 0.22)
        tween(contentArea, {
            Size = UDim2.new(1, -(w + 2), 1, -48),
            Position = UDim2.new(0, w + 2, 0, 48),
        }, 0.22)
    end

    function window:ToggleSidebar()
        if self._destroyed then return end
        sidebarCollapsed = not sidebarCollapsed
        applySidebar()
    end

    -- collapse toggle button in header (right side, before minimize)
    local collapseBtn = create("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -96, 0.5, -12),
        BackgroundColor3 = theme.Info,
        BackgroundTransparency = 0.6,
        Text = "",
        BorderSizePixel = 0,
        ZIndex = 7,
        AutoButtonColor = false,
        Parent = header
    })
    create("ImageLabel", {
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(0.5, -6, 0.5, -6),
        BackgroundTransparency = 1,
        Image = "rbxassetid://97419752870313",
        ImageColor3 = theme.Text,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 8,
        Parent = collapseBtn,
    })
    addCorner(collapseBtn, 6)
    collapseBtn.Visible = opts.SidebarToggle ~= false
    trackConnection(collapseBtn.MouseButton1Click, function()
        window:ToggleSidebar()
    end)
    trackConnection(collapseBtn.MouseEnter, function()
        tween(collapseBtn, {BackgroundTransparency = 0.2}, 0.15)
    end)
    trackConnection(collapseBtn.MouseLeave, function()
        tween(collapseBtn, {BackgroundTransparency = 0.6}, 0.15)
    end)

    -- ~~--------
    -- GESTURE: swipe to switch tabs on mobile
    -- ~~--------
    if mobile and opts.Gestures ~= false then
        local swipeStart
        trackConnection(contentArea.InputBegan, function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch then
                swipeStart = Vector2.new(inp.Position.X, inp.Position.Y)
            end
        end)
        trackConnection(contentArea.InputEnded, function(inp)
            if inp.UserInputType ~= Enum.UserInputType.Touch or not swipeStart then return end
            local endP = Vector2.new(inp.Position.X, inp.Position.Y)
            local delta = endP - swipeStart
            swipeStart = nil
            if math.abs(delta.X) < 80 or math.abs(delta.Y) > 60 then return end
            -- find active idx
            local curIdx
            for i, t in window.Tabs do
                if t == window.ActiveTab then curIdx = i break end
            end
            if not curIdx then return end
            local newIdx
            if delta.X < 0 then
                newIdx = curIdx + 1
            else
                newIdx = curIdx - 1
            end
            if newIdx < 1 or newIdx > #window.Tabs then return end
            local nt = window.Tabs[newIdx]
            if nt and nt._activate then
                -- haptic
                if EZ.Haptic then EZ:Haptic("light") end
                -- call the activator directly; firesignal() is executor-only
                -- and swiping silently did nothing wherever it is missing
                nt._activate()
            end
        end)
    end

    -- ~~--------
    -- TAB
    -- ~~--------
    function window:AddTab(name, icon)
        local tabIdx = #self.Tabs + 1
        local tab = {
            Name = name,
            Sections = {},
            _elements = {},
        }

        -- resolve icon (can be lucide name, asset id, or url)
        local iconUrl = EZ:ResolveIcon(icon)

        -- tab button
        local tabBtn = create("TextButton", {
            Size = UDim2.new(1, 0, 0, mobile and 44 or 32),
            BackgroundColor3 = theme.Panel,
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = tabList
        })
        addCorner(tabBtn, 6)

        -- icon (if provided)
        local iconImg
        local iconSize = mobile and 20 or 14
        local textOffset = 10
        if iconUrl and mobile then
            -- mobile: icon centered top, text below
            iconImg = create("ImageLabel", {
                Size = UDim2.new(0, iconSize, 0, iconSize),
                Position = UDim2.new(0.5, -iconSize/2, 0, 4),
                BackgroundTransparency = 1,
                Image = iconUrl,
                ImageColor3 = theme.TextDim,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 7,
                Parent = tabBtn,
            })
        elseif iconUrl then
            -- pc: icon left, text right
            iconImg = create("ImageLabel", {
                Size = UDim2.new(0, iconSize, 0, iconSize),
                Position = UDim2.new(0, 8, 0.5, -iconSize/2),
                BackgroundTransparency = 1,
                Image = iconUrl,
                ImageColor3 = theme.TextDim,
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 7,
                Parent = tabBtn,
            })
            textOffset = 8 + iconSize + 6
        end

        local tabLabel = create("TextLabel", {
            Size = mobile and UDim2.new(1, 0, 0, 12) or UDim2.new(1, -(textOffset + 4), 1, 0),
            Position = mobile and UDim2.new(0, 0, 1, -15) or UDim2.new(0, textOffset, 0, 0),
            BackgroundTransparency = 1,
            Text = mobile and name:sub(1, 3) or name,
            TextColor3 = theme.TextDim,
            TextSize = mobile and 9 or 12,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = mobile and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            ZIndex = 7,
            Parent = tabBtn
        })

        -- active toggle badge, top-right corner of tab btn
        local badge = create("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(1, -(mobile and 4 or 6), 0, mobile and 3 or 4),
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 8,
            Parent = tabBtn,
        })
        addCorner(badge, 7)
        local badgeLbl = create("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "0",
            TextColor3 = Color3.new(1, 1, 1),
            TextSize = 9,
            Font = Enum.Font.GothamBold,
            ZIndex = 9,
            Parent = badge,
        })
        tab._badge = badge
        tab._badgeLbl = badgeLbl
        function tab:_refreshBadge()
            local n = 0
            for _, tg in self._toggles or {} do
                -- only count toggles whose row is currently visible (skip VisibleWhen=false)
                local visible = (not tg._frame) or tg._frame.Visible
                if visible and tg.Get and tg:Get() then n = n + 1 end
            end
            if n > 0 then
                badge.Visible = true
                -- compact: 1234 -> 1.2k, 12345 -> 12k, 1234567 -> 1.2m
                local txt
                if n < 1000 then
                    txt = tostring(n)
                elseif n < 10000 then
                    txt = string.format("%.1fk", n/1000):gsub("%.0k$", "k")
                elseif n < 1000000 then
                    txt = string.format("%dk", math.floor(n/1000))
                elseif n < 10000000 then
                    txt = string.format("%.1fm", n/1000000):gsub("%.0m$", "m")
                else
                    txt = string.format("%dm", math.floor(n/1000000))
                end
                badgeLbl.Text = txt
                -- grow width with text length so it morphs from circle to pill
                local len = #txt
                local w = (len <= 1) and 14 or (10 + len * 5)
                tween(badge, {Size = UDim2.new(0, w, 0, 14)}, 0.18, Enum.EasingStyle.Back)
            else
                badge.Visible = false
            end
        end

        -- content scroll for this tab
        local tabContent = create("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = theme.Accent,
            ScrollBarImageTransparency = 0.5,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            ZIndex = 4,
            Parent = contentArea,
            Children = {
                create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 6),
                }),
                create("UIPadding", {
                    PaddingTop = UDim.new(0, 6),
                    PaddingBottom = UDim.new(0, 10),
                    PaddingLeft = UDim.new(0, 8),
                    PaddingRight = UDim.new(0, 8),
                })
            }
        })
        tab._content = tabContent
        tab._btn = tabBtn
        tab._label = tabLabel
        tab._icon = iconImg

        local function activate()
            -- deactivate all
            for _, t in self.Tabs do
                t._content.Visible = false
                tween(t._label, {TextColor3 = theme.TextDim}, 0.15)
                tween(t._btn, {BackgroundTransparency = 1}, 0.15)
                if t._icon then tween(t._icon, {ImageColor3 = theme.TextDim}, 0.15) end
            end
            -- activate this
            tabContent.Visible = true
            tween(tabLabel, {TextColor3 = theme.Text}, 0.15)
            tween(tabBtn, {BackgroundTransparency = 0.85}, 0.15)
            if iconImg then tween(iconImg, {ImageColor3 = theme.Text}, 0.15) end

            -- Move indicator, centre aligned to whatever the tab btn actually
            -- has (icon-only, text-only, or both). Prefer the button's real
            -- position: index arithmetic drifts as soon as the tab list has
            -- enough tabs to scroll. AbsolutePosition is in screen pixels, so
            -- divide out the window's UIScale to get the local offset back.
            local btnH = mobile and 44 or 32
            local centerY
            if tabBtn.AbsoluteSize.Y > 0 and uiScale.Scale > 0 then
                centerY = (tabBtn.AbsolutePosition.Y - sidebar.AbsolutePosition.Y) / uiScale.Scale
                    + btnH / 2
            else
                -- layout has not run yet, fall back to the nominal slot
                local slot = btnH + 2 -- list padding
                local listTop = 8 -- tabList offset (6) + padTop (2)
                centerY = listTop + (tabIdx - 1) * slot + btnH / 2
            end
            local yPos = centerY - indicatorH / 2
            tween(tabIndicator, {Position = UDim2.new(0, 2, 0, yPos)}, 0.32, Enum.EasingStyle.Back)

            self.ActiveTab = tab
        end

        tab._activate = activate
        trackConnection(tabBtn.MouseButton1Click, activate)

        -- hover
        trackConnection(tabBtn.MouseEnter, function()
            if self.ActiveTab ~= tab then
                tween(tabBtn, {BackgroundTransparency = 0.9}, 0.1)
            end
        end)
        trackConnection(tabBtn.MouseLeave, function()
            if self.ActiveTab ~= tab then
                tween(tabBtn, {BackgroundTransparency = 1}, 0.1)
            end
        end)

        table.insert(self.Tabs, tab)

        -- first tab auto-activate
        if tabIdx == 1 then
            task.defer(activate)
        end

        -- ~~----
        -- SUB-TABS (horizontal pill row inside a tab)
        -- ~~----
        tab.SubTabs = {}
        tab._activeSub = nil

        function tab:AddSubTab(subName)
            -- lazy init the sub-tab row
            if not tab._subRow then
                tab._subRow = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 34 or 28),
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    ZIndex = 5,
                    Parent = tabContent,
                })
                tab._subRow:SetAttribute("EZSubRow", true)
                create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 4),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = tab._subRow,
                })
            end

            local subIdx = #tab.SubTabs + 1
            local sub = { Name = subName, _sections = {} }

            local subBtn = create("TextButton", {
                Size = UDim2.new(0, 0, 1, -4),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = theme.Surface,
                BackgroundTransparency = 0.6,
                Text = "",
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 6,
                LayoutOrder = subIdx,
                Parent = tab._subRow,
            })
            addCorner(subBtn, 6)
            create("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                Parent = subBtn,
            })
            local subLbl = create("TextLabel", {
                Size = UDim2.new(0, 0, 1, 0),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Text = subName,
                TextColor3 = theme.TextDim,
                TextSize = 11,
                Font = Enum.Font.GothamMedium,
                ZIndex = 7,
                Parent = subBtn,
            })

            -- container for this sub-tab's sections
            local subContainer = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Visible = false,
                LayoutOrder = subIdx + 100,
                ZIndex = 4,
                Parent = tabContent,
            })
            create("UIListLayout", {
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = subContainer,
            })
            subContainer:SetAttribute("EZSubContainer", true)
            sub._container = subContainer

            local function activateSub()
                for _, s in tab.SubTabs do
                    if s._container then s._container.Visible = false end
                    if s._btn then
                        tween(s._btn, {BackgroundTransparency = 0.6}, 0.15)
                        tween(s._lbl, {TextColor3 = theme.TextDim}, 0.15)
                    end
                end
                subContainer.Visible = true
                tween(subBtn, {BackgroundTransparency = 0.1}, 0.15)
                tween(subLbl, {TextColor3 = theme.Text}, 0.15)
                tab._activeSub = sub
            end

            sub._btn = subBtn
            sub._lbl = subLbl
            trackConnection(subBtn.MouseButton1Click, activateSub)

            -- sections inside a subtab: proxy to container
            function sub:AddSection(name)
                -- build it against the tab, then move it into this sub-tab
                local s = tab:AddSection(name)
                if s and s.Frame then
                    s.Frame.Parent = subContainer
                end
                return s
            end

            table.insert(tab.SubTabs, sub)
            if subIdx == 1 then task.defer(activateSub) end
            return sub
        end

        -- ~~----
        -- SECTION
        -- ~~----
        function tab:AddSection(sectionName)
            local section = { Elements = {} }

            local sectionFrame = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = theme.Panel,
                BackgroundTransparency = 0.4,
                AutomaticSize = Enum.AutomaticSize.Y,
                ClipsDescendants = true,
                ZIndex = 5,
                Parent = tabContent
            })
            section.Frame = sectionFrame
            addCorner(sectionFrame, 10)
            addStroke(sectionFrame, theme.Border, 1, 0.55)
            -- accent rail on the left edge for a more premium feel
            create("Frame", {
                Size = UDim2.new(0, 2, 0, 16),
                Position = UDim2.new(0, 0, 0, 7),
                BackgroundColor3 = theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 6,
                Parent = sectionFrame,
            })

            -- section header
            local sectionHeader = create("TextButton", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 6,
                Parent = sectionFrame
            })

            create("TextLabel", {
                Size = UDim2.new(1, -20, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = sectionName or "Section",
                TextColor3 = theme.TextDim,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 7,
                Parent = sectionHeader
            })

            -- arrow
            local arrow = create("TextLabel", {
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -24, 0, 0),
                BackgroundTransparency = 1,
                Text = "v",
                TextColor3 = theme.TextMuted,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                ZIndex = 7,
                Parent = sectionHeader
            })

            -- elements container
            local elemContainer = create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 30),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 5,
                Parent = sectionFrame,
                Children = {
                    create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Padding = UDim.new(0, 4),
                    }),
                    create("UIPadding", {
                        PaddingTop = UDim.new(0, 2),
                        PaddingBottom = UDim.new(0, 8),
                        PaddingLeft = UDim.new(0, 10),
                        PaddingRight = UDim.new(0, 10),
                    })
                }
            })

            local collapsed = false
            trackConnection(sectionHeader.MouseButton1Click, function()
                collapsed = not collapsed
                tween(arrow, {Rotation = collapsed and -90 or 0}, 0.2)
                elemContainer.Visible = not collapsed
            end)

            section._container = elemContainer

            -- ===
            -- TOGGLE
            -- ===
            function section:AddToggle(id, opts)
                opts = opts or {}
                local value = opts.Default or false
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, -56, 1, 0),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                -- toggle track
                local track = create("Frame", {
                    Size = UDim2.new(0, 40, 0, 20),
                    Position = UDim2.new(1, -44, 0.5, -10),
                    BackgroundColor3 = theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(track, 10)
                addStroke(track, theme.Border, 1, 0.5)

                -- thumb
                local thumb = create("Frame", {
                    Size = UDim2.new(0, 16, 0, 16),
                    Position = UDim2.new(0, 2, 0.5, -8),
                    BackgroundColor3 = theme.TextDim,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = track
                })
                addCorner(thumb, 8)

                local toggle -- declared early so update() can sync .Value
                local function update(v, silent)
                    value = v
                    if toggle then toggle.Value = v end
                    if v then
                        tween(thumb, {Position = UDim2.new(0, 22, 0.5, -8), BackgroundColor3 = Color3.new(1,1,1)}, 0.28, Enum.EasingStyle.Back)
                        tween(track, {BackgroundColor3 = theme.Accent}, 0.2)
                    else
                        tween(thumb, {Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = theme.TextDim}, 0.22)
                        tween(track, {BackgroundColor3 = theme.Surface}, 0.2)
                    end
                    EZ.Flags[id] = v
                    fireListeners(id, v)
                    if not silent then safecall(`Toggle:{id}`, cb, v) end
                end

                -- click zone
                local clickBtn = create("TextButton", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 9,
                    Parent = elem
                })
                trackConnection(clickBtn.MouseButton1Click, function()
                    update(not value)
                end)

                update(value, true)

                toggle = { Value = value, _frame = elem }
                function toggle:Set(v) update(v) end
                function toggle:Get() return value end
                attachOnChanged(toggle, id)
                setupVisibility(toggle, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)

                EZ._elements[id] = toggle
                table.insert(section.Elements, toggle)
                -- track for tab badge count
                tab._toggles = tab._toggles or {}
                table.insert(tab._toggles, toggle)
                -- if this toggle has VisibleWhen, refresh badge when its visibility flips
                if opts.VisibleWhen then
                    EZ:OnFlagChanged(opts.VisibleWhen, function()
                        if tab._refreshBadge then tab:_refreshBadge() end
                    end)
                end
                EZ:OnFlagChanged(id, function() if tab._refreshBadge then tab:_refreshBadge() end end)
                if tab._refreshBadge then tab:_refreshBadge() end
                return toggle
            end

            -- ===
            -- SLIDER
            -- ===
            function section:AddSlider(id, opts)
                opts = opts or {}
                local min = tonumber(opts.Min) or 0
                local max = tonumber(opts.Max) or 100
                if max < min then min, max = max, min end
                local inc = math.abs(tonumber(opts.Increment) or 1)
                if inc == 0 then inc = 1 end
                local suffix = opts.Suffix or ""
                local value = clamp(tonumber(opts.Default) or min, min, max)
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 48 or 42),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                local label = create("TextLabel", {
                    Size = UDim2.new(0.6, 0, 0, 16),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                local valLabel = create("TextLabel", {
                    Size = UDim2.new(0.4, 0, 0, 16),
                    Position = UDim2.new(0.6, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(value) .. suffix,
                    TextColor3 = theme.Accent,
                    TextSize = 12,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7,
                    Parent = elem
                })

                -- track
                local sliderTrack = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 6),
                    Position = UDim2.new(0, 0, 0, mobile and 28 or 24),
                    BackgroundColor3 = theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(sliderTrack, 3)

                -- fill
                local fill = create("Frame", {
                    Size = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = sliderTrack
                })
                addCorner(fill, 3)

                -- thumb circle
                local sliderThumb = create("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, 0, 0.5, -7),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 9,
                    Parent = sliderTrack
                })
                addCorner(sliderThumb, 7)

                local slider -- declared early so update() can sync .Value
                local function update(v, silent)
                    v = round(clamp(v, min, max), inc)
                    value = v
                    if slider then slider.Value = v end
                    local range = max - min
                    local pct = range > 0 and ((v - min) / range) or 0
                    fill.Size = UDim2.new(pct, 0, 1, 0)
                    sliderThumb.Position = UDim2.new(pct, -7, 0.5, -7)
                    valLabel.Text = tostring(v) .. suffix
                    EZ.Flags[id] = v
                    fireListeners(id, v)
                    if not silent then safecall(`Slider:{id}`, cb, v) end
                end

                -- interaction
                local sliding = false
                local clickArea = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.new(0, 0, 0, mobile and 20 or 16),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 10,
                    Parent = elem
                })

                trackConnection(clickArea.InputBegan, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if EZ._activeDrag and EZ._activeDrag ~= "slider" then return end
                        sliding = true
                        EZ._activeDrag = "slider"
                    end
                end)

                trackConnection(UserInputService.InputChanged, function(inp)
                    if not sliding then return end
                    if EZ._activeDrag ~= "slider" then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        local absPos = sliderTrack.AbsolutePosition.X
                        local absSize = sliderTrack.AbsoluteSize.X
                        if absSize <= 0 then return end
                        local rel = clamp((inp.Position.X - absPos) / absSize, 0, 1)
                        update(min + (max - min) * rel)
                    end
                end)

                trackConnection(UserInputService.InputEnded, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if sliding then
                            sliding = false
                            if EZ._activeDrag == "slider" then EZ._activeDrag = nil end
                        end
                    end
                end)

                update(value, true)

                slider = { Value = value }
                function slider:Set(v) update(v) end
                function slider:Get() return value end
                attachOnChanged(slider, id)
                setupVisibility(slider, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)

                EZ._elements[id] = slider
                table.insert(section.Elements, slider)
                return slider
            end

            -- ===
            -- BUTTON
            -- ===
            function section:AddButton(opts)
                opts = opts or {}
                local cb = opts.Callback or function() end

                local btn = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.3,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 6,
                    Parent = elemContainer
                })
                addCorner(btn, 7)
                local btnStroke = addStroke(btn, theme.Border, 1, 0.55)

                create("TextLabel", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    Text = opts.Text or "Button",
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.GothamMedium,
                    ZIndex = 7,
                    Parent = btn
                })

                trackConnection(btn.MouseEnter, function()
                    tween(btn, {BackgroundTransparency = 0.08}, 0.15)
                    tween(btnStroke, {Color = theme.Accent, Transparency = 0.4}, 0.15)
                end)
                trackConnection(btn.MouseLeave, function()
                    tween(btn, {BackgroundTransparency = 0.3}, 0.15)
                    tween(btnStroke, {Color = theme.Border, Transparency = 0.55}, 0.15)
                end)
                trackConnection(btn.MouseButton1Click, function()
                    -- press flash + tiny scale pulse for haptic feel
                    tween(btn, {BackgroundColor3 = theme.Accent}, 0.08)
                    task.delay(0.12, function()
                        tween(btn, {BackgroundColor3 = theme.Surface}, 0.18)
                    end)
                    safecall(`Button:{opts.Text or "?"}`, cb)
                end)

                -- Buttons accept the same options as every other element, so
                -- wire up the shared behaviour. VisibleWhen and Tooltip were
                -- silently ignored here, and untagged buttons stayed on screen
                -- while the rest of their section was filtered away.
                setupVisibility(btn, btn, opts)
                setupTooltip(btn, opts)
                tagSearch(btn, opts.Text or "Button")

                table.insert(section.Elements, btn)
                return btn
            end

            -- ===
            -- DROPDOWN
            -- ===
            function section:AddDropdown(id, opts)
                opts = opts or {}
                local values = opts.Values or {}
                local multi = opts.Multi or false
                local cb = opts.Callback or function() end
                local selected = multi and {} or (opts.Default or (values[1] or ""))

                if multi and opts.Default then
                    for _, v in opts.Default do selected[v] = true end
                end

                local hasTitle = opts.Text ~= nil
                local headerY = hasTitle and 16 or 0
                local elemH = (mobile and 38 or 32) + headerY

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, elemH),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 6,
                    ClipsDescendants = false,
                    Parent = elemContainer
                })

                local header = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    Position = UDim2.new(0, 0, 0, headerY),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.3,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(header, 6)
                addStroke(header, theme.Border, 1, 0.6)

                local function getDisplayText()
                    if multi then
                        local items = {}
                        for k, v in selected do
                            if v then table.insert(items, k) end
                        end
                        return #items > 0 and table.concat(items, ", ") or (opts.Text or "Select...")
                    else
                        return tostring(selected)
                    end
                end

                local headerLabel = create("TextLabel", {
                    Size = UDim2.new(1, -30, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = getDisplayText(),
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 8,
                    Parent = header
                })

                if hasTitle then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        Position = UDim2.new(0, 0, 0, 0),
                        BackgroundTransparency = 1,
                        Text = opts.Text,
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Font = Enum.Font.GothamMedium,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7,
                        Parent = elem
                    })
                end

                local dropArrow = create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(1, -24, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "v",
                    TextColor3 = theme.TextMuted,
                    TextSize = 10,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 8,
                    Parent = header
                })

                -- dropdown list
                local dropFrame = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 0, headerY + (mobile and 42 or 36)),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.05,
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 20,
                    Parent = elem
                })
                addCorner(dropFrame, 6)
                addStroke(dropFrame, theme.Border, 1, 0.4)

                local dropList = create("ScrollingFrame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundTransparency = 1,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.Accent,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ZIndex = 21,
                    Parent = dropFrame,
                    Children = {
                        create("UIListLayout", {
                            SortOrder = Enum.SortOrder.LayoutOrder,
                            Padding = UDim.new(0, 1),
                        }),
                        create("UIPadding", {
                            PaddingTop = UDim.new(0, 3),
                            PaddingBottom = UDim.new(0, 3),
                            PaddingLeft = UDim.new(0, 4),
                            PaddingRight = UDim.new(0, 4),
                        })
                    }
                })

                local open = false
                local dropdown -- declared early so item clicks can sync .Value
                local closeDrop -- declared early so refreshItems() can call it
                local ddEntry

                local function refreshItems()
                    for _, c in dropList:GetChildren() do
                        if c:IsA("TextButton") then c:Destroy() end
                    end

                    for _, val in values do
                        local isSelected = multi and selected[val] or (selected == val)
                        local item = create("TextButton", {
                            Size = UDim2.new(1, 0, 0, mobile and 32 or 26),
                            BackgroundColor3 = isSelected and theme.Accent or theme.Panel,
                            BackgroundTransparency = isSelected and 0.6 or 0.8,
                            Text = "",
                            BorderSizePixel = 0,
                            AutoButtonColor = false,
                            ZIndex = 22,
                            Parent = dropList
                        })
                        addCorner(item, 4)

                        create("TextLabel", {
                            Size = UDim2.new(1, -10, 1, 0),
                            Position = UDim2.new(0, 8, 0, 0),
                            BackgroundTransparency = 1,
                            Text = tostring(val),
                            TextColor3 = isSelected and theme.Text or theme.TextDim,
                            TextSize = 12,
                            Font = Enum.Font.Gotham,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 23,
                            Parent = item
                        })

                        -- Connected directly rather than tracked: refreshItems()
                        -- rebuilds these rows on every open, and destroying an
                        -- item already drops its own connections. Tracking them
                        -- grew EZ._connections without bound.
                        item.MouseEnter:Connect(function()
                            tween(item, {BackgroundTransparency = 0.5}, 0.1)
                        end)
                        item.MouseLeave:Connect(function()
                            local sel = multi and selected[val] or (selected == val)
                            tween(item, {BackgroundTransparency = sel and 0.6 or 0.8}, 0.1)
                        end)

                        item.MouseButton1Click:Connect(function()
                            if multi then
                                selected[val] = not selected[val]
                            else
                                selected = val
                                closeDrop()
                            end
                            headerLabel.Text = getDisplayText()
                            if dropdown then dropdown.Value = selected end
                            EZ.Flags[id] = selected
                            fireListeners(id, selected)
                            refreshItems()
                            safecall(`Dropdown:{id}`, cb, selected)
                        end)
                    end
                end

                closeDrop = function()
                    if not open then return end
                    open = false
                    clearActiveDropdown(ddEntry)
                    tween(dropFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.2)
                    task.delay(0.2, function()
                        if not open then dropFrame.Visible = false end
                    end)
                    tween(dropArrow, {Rotation = 0}, 0.15)
                end
                ddEntry = { close = closeDrop, list = dropFrame, header = header }

                trackConnection(header.MouseButton1Click, function()
                    if open then
                        closeDrop()
                        return
                    end
                    open = true
                    setActiveDropdown(ddEntry)
                    refreshItems()
                    dropFrame.Visible = true
                    local itemH = mobile and 32 or 26
                    local h = math.min(#values * (itemH + 1) + 8, 180)
                    tween(dropFrame, {Size = UDim2.new(1, 0, 0, h)}, 0.2)
                    tween(dropArrow, {Rotation = 180}, 0.15)
                end)

                EZ.Flags[id] = selected
                refreshItems()

                dropdown = { Value = selected }
                -- Fires the callback like every other :Set() does. Without it,
                -- loading a saved config updated the label but never told the
                -- script the value had changed.
                function dropdown:Set(v, silent)
                    selected = v
                    self.Value = selected
                    headerLabel.Text = getDisplayText()
                    EZ.Flags[id] = selected
                    fireListeners(id, selected)
                    refreshItems()
                    if not silent then safecall(`Dropdown:{id}`, cb, selected) end
                end
                function dropdown:Refresh(newValues)
                    values = newValues
                    refreshItems()
                end
                function dropdown:Get() return selected end

                attachOnChanged(dropdown, id)
                setupVisibility(dropdown, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                EZ._elements[id] = dropdown
                table.insert(section.Elements, dropdown)
                return dropdown
            end

            -- ===
            -- INPUT
            -- ===
            function section:AddInput(id, opts)
                opts = opts or {}
                local value = opts.Default or ""
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 56 or 48),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                if opts.Text then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = opts.Text,
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Font = Enum.Font.GothamMedium,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7,
                        Parent = elem
                    })
                end

                local inputBg = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 36 or 30),
                    Position = UDim2.new(0, 0, 1, mobile and -36 or -30),
                    BackgroundColor3 = theme.Surface,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(inputBg, 6)
                local inputStroke = addStroke(inputBg, theme.Border, 1, 0.5)

                local textBox = create("TextBox", {
                    Size = UDim2.new(1, -16, 1, 0),
                    Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1,
                    Text = value,
                    PlaceholderText = opts.Placeholder or "Type here...",
                    TextColor3 = theme.Text,
                    PlaceholderColor3 = theme.TextMuted,
                    TextSize = 12,
                    Font = Enum.Font.Code,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ClearTextOnFocus = false,
                    ZIndex = 8,
                    Parent = inputBg
                })

                trackConnection(textBox.Focused, function()
                    tween(inputStroke, {Color = theme.Accent, Transparency = 0}, 0.15)
                end)
                local input -- declared early so FocusLost can sync .Value

                trackConnection(textBox.FocusLost, function(enterPressed)
                    tween(inputStroke, {Color = theme.Border, Transparency = 0.5}, 0.15)
                    value = textBox.Text
                    if input then input.Value = value end
                    EZ.Flags[id] = value
                    fireListeners(id, value)
                    safecall(`Input:{id}`, cb, value, enterPressed)
                end)

                EZ.Flags[id] = value

                input = { Value = value }
                function input:Set(v, silent)
                    v = tostring(v)
                    textBox.Text = v
                    value = v
                    self.Value = v
                    EZ.Flags[id] = v
                    fireListeners(id, v)
                    if not silent then safecall(`Input:{id}`, cb, v, false) end
                end
                function input:Get() return value end

                attachOnChanged(input, id)
                setupVisibility(input, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                EZ._elements[id] = input
                table.insert(section.Elements, input)
                return input
            end

            -- ===
            -- KEYBIND
            -- ===
            function section:AddKeybind(id, opts)
                opts = opts or {}
                local key = opts.Default or Enum.KeyCode.Unknown
                local mode = opts.Mode or "Toggle"
                local cb = opts.Callback or function() end
                local active = false
                local listening = false

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, -80, 1, 0),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                local bindBtn = create("TextButton", {
                    Size = UDim2.new(0, 70, 0, 24),
                    Position = UDim2.new(1, -74, 0.5, -12),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.3,
                    Text = key ~= Enum.KeyCode.Unknown and key.Name or "None",
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Font = Enum.Font.Code,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 8,
                    Parent = elem
                })
                addCorner(bindBtn, 4)
                addStroke(bindBtn, theme.Border, 1, 0.6)

                trackConnection(bindBtn.MouseButton1Click, function()
                    listening = true
                    bindBtn.Text = "..."
                    tween(bindBtn, {BackgroundColor3 = theme.Accent}, 0.15)
                end)

                local keybind -- declared early so the handlers can sync state

                trackConnection(UserInputService.InputBegan, function(inp, gpe)
                    if listening then
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            key = inp.KeyCode
                            bindBtn.Text = key.Name
                            listening = false
                            tween(bindBtn, {BackgroundColor3 = theme.Surface}, 0.15)
                            if keybind then keybind.Value = key end
                            EZ.Flags[id] = key
                            fireListeners(id, key)
                        end
                        return
                    end

                    if gpe then return end
                    if inp.KeyCode ~= key or key == Enum.KeyCode.Unknown then return end

                    if mode == "Toggle" then
                        active = not active
                        if keybind then keybind.Active = active end
                        safecall(`Keybind:{id}`, cb, active)
                    elseif mode == "Hold" then
                        active = true
                        if keybind then keybind.Active = true end
                        safecall(`Keybind:{id}`, cb, true)
                    end
                end)

                trackConnection(UserInputService.InputEnded, function(inp)
                    if mode == "Hold" and inp.KeyCode == key and active then
                        active = false
                        if keybind then keybind.Active = false end
                        safecall(`Keybind:{id}`, cb, false)
                    end
                end)

                EZ.Flags[id] = key

                keybind = { Value = key, Active = active }
                function keybind:Set(k)
                    -- a config restore can hand back a string that failed to
                    -- parse; indexing .Name on it would throw
                    if typeof(k) ~= "EnumItem" then return end
                    key = k
                    bindBtn.Text = k ~= Enum.KeyCode.Unknown and k.Name or "None"
                    self.Value = k
                    EZ.Flags[id] = k
                    fireListeners(id, k)
                end
                function keybind:Get() return key end
                function keybind:IsActive() return active end

                attachOnChanged(keybind, id)
                setupVisibility(keybind, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                EZ._elements[id] = keybind
                table.insert(section.Elements, keybind)
                return keybind
            end

            -- ===
            -- COLORPICKER
            -- ===
            function section:AddColorPicker(id, opts)
                opts = opts or {}
                local color = opts.Default or Color3.fromRGB(255, 255, 255)
                local cb = opts.Callback or function() end

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, mobile and 38 or 32),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, -44, 1, 0),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.Text,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                -- swatch preview
                local swatch = create("TextButton", {
                    Size = UDim2.new(0, 28, 0, 20),
                    Position = UDim2.new(1, -32, 0.5, -10),
                    BackgroundColor3 = color,
                    Text = "",
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 8,
                    Parent = elem
                })
                addCorner(swatch, 4)
                addStroke(swatch, theme.Border, 1, 0.4)

                -- picker popup (parented to gui so section ClipsDescendants doesn't clip it)
                local pickerOpen = false
                local pickerFrame = create("Frame", {
                    Size = UDim2.new(0, 180, 0, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.05,
                    ClipsDescendants = true,
                    Visible = false,
                    ZIndex = 100,
                    Parent = gui
                })
                addCorner(pickerFrame, 8)
                addStroke(pickerFrame, theme.Border, 1, 0.3)

                -- hue/sat canvas
                local canvas = create("Frame", {
                    Size = UDim2.new(1, -16, 0, 120),
                    Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Color3.new(1, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 31,
                    Parent = pickerFrame
                })
                addCorner(canvas, 4)

                -- sat overlay (white gradient left to right)
                create("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 32,
                    Parent = canvas,
                    Children = {
                        create("UICorner", {CornerRadius = UDim.new(0, 4)}),
                        create("UIGradient", {
                            Color = ColorSequence.new(Color3.new(1,1,1), Color3.new(1,1,1)),
                            Transparency = NumberSequence.new(0, 1),
                            Rotation = 0,
                        })
                    }
                })

                -- val overlay (black gradient top to bottom)
                create("Frame", {
                    Size = UDim2.fromScale(1, 1),
                    BackgroundColor3 = Color3.new(0, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 33,
                    Parent = canvas,
                    Children = {
                        create("UICorner", {CornerRadius = UDim.new(0, 4)}),
                        create("UIGradient", {
                            Color = ColorSequence.new(Color3.new(0,0,0), Color3.new(0,0,0)),
                            Transparency = NumberSequence.new(1, 0),
                            Rotation = 90,
                        })
                    }
                })

                -- canvas cursor
                local cursor = create("Frame", {
                    Size = UDim2.new(0, 10, 0, 10),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 35,
                    Parent = canvas
                })
                addCorner(cursor, 5)
                addStroke(cursor, Color3.new(0,0,0), 1, 0)

                -- hue slider
                local hueBar = create("Frame", {
                    Size = UDim2.new(1, -16, 0, 12),
                    Position = UDim2.new(0, 8, 0, 134),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 31,
                    Parent = pickerFrame,
                    Children = {
                        create("UICorner", {CornerRadius = UDim.new(0, 6)}),
                        create("UIGradient", {
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
                                ColorSequenceKeypoint.new(0.167, Color3.fromHSV(0.167,1,1)),
                                ColorSequenceKeypoint.new(0.333, Color3.fromHSV(0.333,1,1)),
                                ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
                                ColorSequenceKeypoint.new(0.667, Color3.fromHSV(0.667,1,1)),
                                ColorSequenceKeypoint.new(0.833, Color3.fromHSV(0.833,1,1)),
                                ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1)),
                            })
                        })
                    }
                })

                local hueThumb = create("Frame", {
                    Size = UDim2.new(0, 4, 1, 2),
                    Position = UDim2.new(0, 0, 0, -1),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 33,
                    Parent = hueBar
                })
                addCorner(hueThumb, 2)

                -- hex input
                local hexBox = create("TextBox", {
                    Size = UDim2.new(1, -16, 0, 22),
                    Position = UDim2.new(0, 8, 0, 152),
                    BackgroundColor3 = theme.Panel,
                    Text = color3ToHex(color),
                    TextColor3 = theme.Text,
                    PlaceholderColor3 = theme.TextMuted,
                    TextSize = 11,
                    Font = Enum.Font.Code,
                    BorderSizePixel = 0,
                    ZIndex = 32,
                    Parent = pickerFrame
                })
                addCorner(hexBox, 4)

                -- state
                local h, s, v = Color3.toHSV(color)
                local picker -- declared early so updateColor() can sync .Value

                local function updateColor(silent)
                    color = Color3.fromHSV(h, s, v)
                    if picker then picker.Value = color end
                    swatch.BackgroundColor3 = color
                    canvas.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                    cursor.Position = UDim2.new(s, -5, 1 - v, -5)
                    hueThumb.Position = UDim2.new(h, -2, 0, -1)
                    hexBox.Text = color3ToHex(color)
                    EZ.Flags[id] = color
                    fireListeners(id, color)
                    if not silent then safecall(`ColorPicker:{id}`, cb, color) end
                end

                -- canvas drag (claims mutex so slider underneath stays still)
                local canvasDrag = false
                trackConnection(canvas.InputBegan, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        canvasDrag = true
                        EZ._activeDrag = "picker"
                    end
                end)
                trackConnection(UserInputService.InputChanged, function(inp)
                    if not canvasDrag then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        local pos = Vector2.new(inp.Position.X, inp.Position.Y)
                        local w, hgt = canvas.AbsoluteSize.X, canvas.AbsoluteSize.Y
                        if w <= 0 or hgt <= 0 then return end
                        s = clamp((pos.X - canvas.AbsolutePosition.X) / w, 0, 1)
                        v = 1 - clamp((pos.Y - canvas.AbsolutePosition.Y) / hgt, 0, 1)
                        updateColor()
                    end
                end)
                trackConnection(UserInputService.InputEnded, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if canvasDrag then
                            canvasDrag = false
                            if EZ._activeDrag == "picker" then EZ._activeDrag = nil end
                        end
                    end
                end)

                -- hue drag
                local hueDrag = false
                trackConnection(hueBar.InputBegan, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        hueDrag = true
                        EZ._activeDrag = "picker"
                    end
                end)
                trackConnection(UserInputService.InputChanged, function(inp)
                    if not hueDrag then return end
                    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                        local width = hueBar.AbsoluteSize.X
                        if width <= 0 then return end
                        h = clamp((inp.Position.X - hueBar.AbsolutePosition.X) / width, 0, 1)
                        updateColor()
                    end
                end)
                trackConnection(UserInputService.InputEnded, function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                        if hueDrag then
                            hueDrag = false
                            if EZ._activeDrag == "picker" then EZ._activeDrag = nil end
                        end
                    end
                end)

                -- hex input
                trackConnection(hexBox.FocusLost, function()
                    local ok, c = pcall(hexToColor3, hexBox.Text)
                    if ok and c then
                        h, s, v = Color3.toHSV(c)
                        updateColor()
                    end
                end)

                local function closePicker(instant)
                    if not pickerOpen then return end
                    pickerOpen = false
                    if instant then
                        pickerFrame.Size = UDim2.new(0, 180, 0, 0)
                        pickerFrame.Visible = false
                        return
                    end
                    tween(pickerFrame, {Size = UDim2.new(0, 180, 0, 0)}, 0.15)
                    task.delay(0.15, function()
                        if not pickerOpen then pickerFrame.Visible = false end
                    end)
                end

                trackConnection(swatch.MouseButton1Click, function()
                    if pickerOpen then
                        closePicker()
                        return
                    end
                    pickerOpen = true
                    -- position next to swatch, kept fully on screen
                    local absPos = swatch.AbsolutePosition
                    local absSize = swatch.AbsoluteSize
                    local guiOff = gui.AbsolutePosition
                    local screenSize = getScreenSize()
                    local px = clamp(absPos.X - guiOff.X + absSize.X - 180, 4, math.max(4, screenSize.X - 184))
                    local py = clamp(absPos.Y - guiOff.Y + absSize.Y + 4, 4, math.max(4, screenSize.Y - 186))
                    pickerFrame.Position = UDim2.new(0, px, 0, py)
                    pickerFrame.Visible = true
                    tween(pickerFrame, {Size = UDim2.new(0, 180, 0, 182)}, 0.2)
                end)

                -- The popup lives in the root ScreenGui so section clipping
                -- cannot cut it off, which means the window has to close and
                -- destroy it explicitly.
                registerPopup(pickerFrame, closePicker)

                updateColor(true)

                picker = { Value = color }
                function picker:Set(c)
                    h, s, v = Color3.toHSV(c)
                    updateColor()
                end
                function picker:Get() return color end

                attachOnChanged(picker, id)
                setupVisibility(picker, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                EZ._elements[id] = picker
                table.insert(section.Elements, picker)
                return picker
            end

            -- ===
            -- LABEL
            -- ===
            function section:AddLabel(text)
                -- accept table form too: AddLabel({ Text = "..." })
                if type(text) == "table" then text = text.Text or text.Title or "" end
                local lbl = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = tostring(text or ""),
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elemContainer
                })
                tagSearch(lbl, tostring(text or ""))

                local label = {}
                function label:Set(t)
                    lbl.Text = tostring(t)
                    tagSearch(lbl, tostring(t))
                end
                table.insert(section.Elements, label)
                return label
            end

            -- ===
            -- DIVIDER
            -- ===
            function section:AddDivider()
                create("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    BackgroundColor3 = theme.Border,
                    BackgroundTransparency = 0.5,
                    BorderSizePixel = 0,
                    ZIndex = 6,
                    Parent = elemContainer
                })
            end

            -- ===
            -- PARAGRAPH
            -- ===
            function section:AddParagraph(opts)
                opts = opts or {}
                local frame = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                if opts.Title then
                    create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 16),
                        BackgroundTransparency = 1,
                        Text = opts.Title,
                        TextColor3 = theme.Text,
                        TextSize = 12,
                        Font = Enum.Font.GothamBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 7,
                        Parent = frame
                    })
                end

                local bodyLbl = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 0, opts.Title and 18 or 0),
                    BackgroundTransparency = 1,
                    Text = opts.Content or "",
                    TextColor3 = theme.TextDim,
                    TextSize = 11,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    ZIndex = 7,
                    Parent = frame
                })

                tagSearch(frame, (opts.Title or "") .. " " .. (opts.Content or ""))

                local para = {}
                function para:Set(txt)
                    bodyLbl.Text = tostring(txt)
                    tagSearch(frame, (opts.Title or "") .. " " .. tostring(txt))
                end
                table.insert(section.Elements, para)
                return para
            end

            -- ===
            -- PROGRESS BAR
            -- ===
            function section:AddProgressBar(id, opts)
                opts = opts or {}
                local maxVal = tonumber(opts.Max) or 100
                if maxVal <= 0 then maxVal = 100 end
                local progress = clamp(tonumber(opts.Default) or 0, 0, maxVal)
                local showText = opts.ShowText ~= false

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 34),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    Parent = elemContainer
                })

                create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 14),
                    BackgroundTransparency = 1,
                    Text = opts.Text or id,
                    TextColor3 = theme.TextDim,
                    TextSize = 10,
                    Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                    Parent = elem
                })

                local barBg = create("Frame", {
                    Size = UDim2.new(1, 0, 0, 12),
                    Position = UDim2.new(0, 0, 0, 18),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 7,
                    Parent = elem
                })
                addCorner(barBg, 4)
                addStroke(barBg, theme.Border, 1, 0.6)

                local fill = create("Frame", {
                    Size = UDim2.new(maxVal > 0 and math.clamp(progress / maxVal, 0, 1) or 0, 0, 1, 0),
                    BackgroundColor3 = opts.Color or theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                    Parent = barBg
                })

                local pctLbl
                if showText then
                    pctLbl = create("TextLabel", {
                        Size = UDim2.new(0, 50, 0, 14),
                        Position = UDim2.new(1, -50, 0, 0),
                        BackgroundTransparency = 1,
                        Text = tostring(math.floor(progress)) .. "/" .. tostring(maxVal),
                        TextColor3 = theme.TextDim,
                        TextSize = 10,
                        Font = Enum.Font.Code,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        ZIndex = 7,
                        Parent = elem
                    })
                end

                EZ.Flags[id] = progress

                local bar = { Value = progress }
                function bar:Set(v)
                    progress = math.clamp(tonumber(v) or 0, 0, maxVal)
                    self.Value = progress
                    local pct = maxVal > 0 and (progress / maxVal) or 0
                    tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.12)
                    if pctLbl then pctLbl.Text = tostring(math.floor(progress)) .. "/" .. tostring(maxVal) end
                    EZ.Flags[id] = progress
                    fireListeners(id, progress)
                end
                function bar:SetMax(m)
                    maxVal = tonumber(m) or maxVal
                    if maxVal <= 0 then maxVal = 1 end
                    bar:Set(progress)
                end
                function bar:SetColor(c) fill.BackgroundColor3 = c end
                function bar:Get() return progress end

                attachOnChanged(bar, id)
                setupVisibility(bar, elem, opts)
                setupTooltip(elem, opts)
                tagSearch(elem, opts.Text or id)
                EZ._elements[id] = bar
                table.insert(section.Elements, bar)
                return bar
            end

            -- ===
            -- LOG / CONSOLE
            -- ===
            function section:AddLog(opts)
                opts = opts or {}
                local maxLines = math.max(1, tonumber(opts.MaxLines) or 50)
                local lines = {}

                local elem = create("Frame", {
                    Size = UDim2.new(1, 0, 0, opts.Height or 120),
                    BackgroundColor3 = theme.Surface,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0,
                    ZIndex = 6,
                    Parent = elemContainer
                })
                addCorner(elem, 4)
                addStroke(elem, theme.Border, 1, 0.6)

                local scroll = create("ScrollingFrame", {
                    Size = UDim2.new(1, -8, 1, -8),
                    Position = UDim2.new(0, 4, 0, 4),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.Border,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ScrollingDirection = Enum.ScrollingDirection.Y,
                    ZIndex = 7,
                    Parent = elem
                })

                create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
                    Parent = scroll
                })

                local log = {}
                -- monotonic: reusing #lines + 1 after a trim gave two live
                -- lines the same LayoutOrder and scrambled their order
                local lineSeq = 0
                local function append(txt, color)
                    if #lines >= maxLines then
                        local first = lines[1]
                        if first then first:Destroy() end
                        table.remove(lines, 1)
                    end
                    lineSeq = lineSeq + 1
                    local line = create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = txt,
                        TextColor3 = color or theme.TextDim,
                        TextSize = 11,
                        Font = Enum.Font.Code,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        LayoutOrder = lineSeq,
                        ZIndex = 8,
                        Parent = scroll
                    })
                    table.insert(lines, line)
                    task.defer(function()
                        scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
                    end)
                end

                function log:Info(txt)  append("[i] " .. tostring(txt), theme.Text) end
                function log:Warn(txt)  append("[!] " .. tostring(txt), Color3.fromRGB(255, 200, 90)) end
                function log:Error(txt) append("[x] " .. tostring(txt), Color3.fromRGB(255, 90, 90)) end
                function log:Success(txt) append("[+] " .. tostring(txt), Color3.fromRGB(120, 230, 140)) end
                function log:Print(txt, color) append(tostring(txt), color) end
                function log:Clear()
                    for _, l in lines do l:Destroy() end
                    table.clear(lines)
                end

                table.insert(section.Elements, log)
                return log
            end

            -- ===
            -- PLAYER SELECTOR (dropdown preloaded with players + auto-refresh)
            -- ===
            function section:AddPlayerSelector(id, opts)
                opts = opts or {}
                local excludeSelf = opts.ExcludeSelf ~= false
                local multi = opts.Multi or false

                local function buildList()
                    local list = {}
                    if not excludeSelf then table.insert(list, "@me") end
                    table.insert(list, "@random")
                    table.insert(list, "@nearest")
                    for _, p in pairs(Players:GetPlayers()) do
                        if not excludeSelf or p ~= Players.LocalPlayer then
                            table.insert(list, p.Name)
                        end
                    end
                    return list
                end

                local dropOpts = {
                    Text = opts.Text or "Select Player",
                    Values = buildList(),
                    -- left nil on purpose so AddDropdown falls back to the
                    -- first entry; "" is truthy and left the selector blank
                    Default = opts.Default,
                    Multi = multi,
                    Callback = opts.Callback,
                    VisibleWhen = opts.VisibleWhen,
                }

                local dd = section:AddDropdown(id, dropOpts)

                -- auto-refresh on join/leave
                trackConnection(Players.PlayerAdded, function() dd:Refresh(buildList()) end)
                trackConnection(Players.PlayerRemoving, function() dd:Refresh(buildList()) end)

                function dd:GetPlayers()
                    local sel = dd:Get()
                    if type(sel) == "string" then
                        if sel == "@me" then return {Players.LocalPlayer}
                        elseif sel == "@random" then
                            local list = {}
                            for _, p in pairs(Players:GetPlayers()) do
                                if p ~= Players.LocalPlayer then table.insert(list, p) end
                            end
                            return #list > 0 and {list[math.random(1, #list)]} or {}
                        elseif sel == "@nearest" then
                            local lp = Players.LocalPlayer
                            local myChar = lp.Character
                            if not myChar or not myChar:FindFirstChild("HumanoidRootPart") then return {} end
                            local myPos = myChar.HumanoidRootPart.Position
                            local best, bd = nil, math.huge
                            for _, p in pairs(Players:GetPlayers()) do
                                if p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                                    local d = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                                    if d < bd then best, bd = p, d end
                                end
                            end
                            return best and {best} or {}
                        else
                            local p = Players:FindFirstChild(sel)
                            return p and {p} or {}
                        end
                    elseif type(sel) == "table" then
                        local out = {}
                        for name, on in pairs(sel) do
                            if on then
                                local p = Players:FindFirstChild(name)
                                if p then table.insert(out, p) end
                            end
                        end
                        return out
                    end
                    return {}
                end

                return dd
            end

            -- Same reason as owned() above: element builders run long after
            -- CreateWindow() returned, so each re-asserts the owner.
            local builders = {}
            for key, fn in section do
                if type(fn) == "function" then builders[key] = owned(fn) end
            end
            for key, fn in builders do section[key] = fn end

            table.insert(tab.Sections, section)
            return section
        end

        tab.AddSection = owned(tab.AddSection)
        tab.AddSubTab = owned(tab.AddSubTab)
        return tab
    end

    window.AddTab = owned(window.AddTab)

    table.insert(self.Windows, window)
    EZ._connectionOwner = previousConnectionOwner
    return window
end

-- Live recolouring works by matching an instance's current colour back to a
-- theme role. Several themes give two roles the same RGB (Dracula's Border and
-- TextMuted, Nord's TextMuted and Info), so a single flat colour->role map let
-- whichever role happened to hash last win: switching away from those themes
-- recoloured the wrong elements, and differently on each run. Two maps keyed by
-- how the colour is used, each filled in a fixed precedence order, keeps the
-- result both correct and deterministic.
local TEXT_ROLE_ORDER = {
    "Text", "TextDim", "TextMuted", "Accent", "AccentDark",
    "Success", "Warning", "Error", "Info", "Border", "Panel", "Surface", "Base",
}
local FILL_ROLE_ORDER = {
    "Base", "Surface", "Panel", "Border", "Accent", "AccentDark",
    "Success", "Warning", "Error", "Info", "Text", "TextDim", "TextMuted",
}
-- properties that carry a foreground colour; everything else reads the fill map
local TEXT_PROPS = { TextColor3 = true, PlaceholderColor3 = true, ImageColor3 = true }
local COLOR_PROPS = {
    "BackgroundColor3", "TextColor3", "PlaceholderColor3",
    "ImageColor3", "ScrollBarImageColor3",
}

local function colorKey(c)
    return string.format("%d_%d_%d",
        math.floor(c.R * 255 + .5), math.floor(c.G * 255 + .5), math.floor(c.B * 255 + .5))
end

-- theme setter with live recolor
function EZ:SetTheme(themeTable)
    themeTable = themeTable or {}

    -- Snapshot the old theme first. Updating self.Theme before collecting the
    -- old values made repeated theme changes unreliable.
    local oldTheme = {}
    for k, v in self.Theme do
        oldTheme[k] = v
    end

    local function buildMap(order)
        local map = {}
        for _, role in order do
            local old, new = oldTheme[role], themeTable[role]
            if typeof(old) == "Color3" and typeof(new) == "Color3" then
                local key = colorKey(old)
                if map[key] == nil then map[key] = new end -- earliest role wins
            end
        end
        return map
    end

    local textMap = buildMap(TEXT_ROLE_ORDER)
    local fillMap = buildMap(FILL_ROLE_ORDER)

    for k, v in themeTable do
        self.Theme[k] = v
    end

    local function recolor(desc)
        for _, prop in COLOR_PROPS do
            pcall(function()
                local cur = desc[prop]
                if typeof(cur) == "Color3" then
                    local repl = (TEXT_PROPS[prop] and textMap or fillMap)[colorKey(cur)]
                    if repl then desc[prop] = repl end
                end
            end)
        end
        -- UIStroke keeps its colour on .Color, and strokes are always fills
        if desc:IsA("UIStroke") then
            pcall(function()
                local repl = fillMap[colorKey(desc.Color)]
                if repl then desc.Color = repl end
            end)
        end
    end

    -- recolor all descendants of EZUI + EZNotifs
    local containers = {}
    if gui and gui.Parent then table.insert(containers, gui) end
    if notifGui and notifGui.Parent then table.insert(containers, notifGui) end

    pcall(function()
        local hui = (gethui and gethui()) or Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if hui then
            for _, g in hui:GetChildren() do
                if (g.Name == "EZUI" or g.Name == "EZNotifs") and not table.find(containers, g) then
                    table.insert(containers, g)
                end
            end
        end
    end)

    -- The watermark normally lives inside gui and is covered by the sweep
    -- below. Only walk it separately if it was reparented somewhere else -
    -- visiting it twice could remap an already-updated colour a second time.
    if self._watermark and self._watermark.Parent
        and not table.find(containers, self._watermark.Parent)
    then
        table.insert(containers, self._watermark)
    end

    for _, container in containers do
        recolor(container)
        for _, desc in container:GetDescendants() do
            recolor(desc)
        end
    end
end

function EZ:GetTheme()
    return self.Theme
end

-- ~~
-- WATERMARK / HUD
-- ~~
function EZ:CreateWatermark(opts)
    opts = opts or {}
    local theme = self.Theme

    -- kill old
    if self._watermark then
        pcall(function() self._watermark:Destroy() end)
    end

    local frame = create("Frame", {
        Name = "EZWatermark",
        Size = UDim2.new(0, 200, 0, 26),
        Position = opts.Position or UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = theme.Base,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 200,
        Parent = gui
    })
    addCorner(frame, 6)
    addStroke(frame, theme.Accent, 1, 0.4)

    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = frame,
    })

    local lbl = create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Text = opts.Text or "EZ | {fps} fps | {ping} ms",
        TextColor3 = theme.Text,
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
        Parent = frame,
    })

    self._watermark = frame

    -- live update
    local template = opts.Text or "EZ | {fps} fps | {ping} ms"
    local lastTick = tick()
    local frames = 0
    local fps = 60

    local stats = game:GetService("Stats")
    local lp = Players.LocalPlayer

    local conn = trackConnection(RunService.RenderStepped, function()
        frames = frames + 1
        local now = tick()
        if now - lastTick >= 0.5 then
            fps = math.floor(frames / (now - lastTick))
            frames = 0
            lastTick = now
        end

        local ping = 0
        pcall(function()
            ping = math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)

        local txt = template
        txt = txt:gsub("{fps}", tostring(fps))
        txt = txt:gsub("{ping}", tostring(ping))
        txt = txt:gsub("{time}", os.date("%H:%M:%S"))
        txt = txt:gsub("{user}", lp and lp.Name or "?")
        txt = txt:gsub("{place}", tostring(game.PlaceId))

        -- substitute flags
        txt = txt:gsub("{flag:([%w_]+)}", function(flag)
            local v = EZ.Flags[flag]
            if v == nil then return "?" end
            return tostring(v)
        end)

        lbl.Text = txt
    end)

    local watermark = {}
    function watermark:SetText(t) template = t end
    function watermark:SetPosition(p) frame.Position = p end
    function watermark:Destroy()
        -- disconnectConnection also drops it from EZ._connections
        disconnectConnection(conn)
        pcall(function() frame:Destroy() end)
        EZ._watermark = nil
    end
    function watermark:Show() frame.Visible = true end
    function watermark:Hide() frame.Visible = false end

    return watermark
end

-- ~~
-- HAPTIC FEEDBACK
-- Gamepad rumble through HapticService. Roblox exposes no vibration API for
-- phones, so this is a no-op unless a controller is actually connected.
-- ~~
function EZ:Haptic(strength)
    -- strength: "light" | "medium" | "heavy"
    strength = strength or "light"
    local HapticService = game:GetService("HapticService")
    pcall(function()
        local motor = Enum.VibrationMotor.Large
        local amp = strength == "heavy" and 1 or strength == "medium" and 0.6 or 0.3
        for _, gp in pairs(Enum.UserInputType:GetEnumItems()) do
            if tostring(gp):find("Gamepad") then
                pcall(function()
                    -- skip slots with nothing plugged in rather than firing
                    -- SetMotor at every gamepad index on every call
                    local supported = true
                    pcall(function()
                        supported = HapticService:IsVibrationSupported(gp)
                    end)
                    if not supported then return end
                    HapticService:SetMotor(gp, motor, amp)
                    task.delay(0.05, function()
                        pcall(function() HapticService:SetMotor(gp, motor, 0) end)
                    end)
                end)
            end
        end
    end)
end

-- ~~
-- AUTO-UPDATE CHECK (fetches latest tag from github)
-- ~~
function EZ:CheckForUpdate(repo)
    repo = repo or "Beastaive22/EZ-Hub"
    local url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
    local ok, resp = pcall(function()
        if request then
            return request({Url = url, Method = "GET"})
        elseif http_request then
            return http_request({Url = url, Method = "GET"})
        end
    end)
    if not ok or not resp or not resp.Body then return nil end
    local okDec, data = pcall(function() return HttpService:JSONDecode(resp.Body) end)
    if not okDec or not data.tag_name then return nil end
    -- release tags are conventionally prefixed ("v3.2.2") while _version is
    -- not; comparing them raw reported every up-to-date build as outdated
    local function stripV(ver)
        return (tostring(ver):gsub("^[vV]", ""))
    end
    return {
        latest = data.tag_name,
        current = self._version,
        outdated = stripV(data.tag_name) ~= stripV(self._version),
        url = data.html_url,
        body = data.body,
    }
end

-- ~~
-- TOOLTIP helper (attach to any GuiObject)
-- ~~
function EZ:AttachTooltip(guiObj, text)
    if not guiObj or not text then return end
    local theme = self.Theme
    local tip
    local function show()
        if tip then pcall(function() tip:Destroy() end) end
        tip = create("Frame", {
            Name = "EZTooltip",
            Size = UDim2.new(0, 0, 0, 22),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = theme.Base,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ZIndex = 250,
            Parent = gui,
        })
        addCorner(tip, 4)
        addStroke(tip, theme.Border, 1, 0.5)
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            Parent = tip,
        })
        create("TextLabel", {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = theme.Text,
            TextSize = 11,
            Font = Enum.Font.Gotham,
            ZIndex = 251,
            Parent = tip,
        })
        -- keep it on screen; anchored blindly below the object it could sit
        -- off the bottom or right edge for anything near the border
        local pos = guiObj.AbsolutePosition
        local sz = guiObj.AbsoluteSize
        local screenSize = getScreenSize()
        local tipW = math.max(tip.AbsoluteSize.X, 80)
        local x = clamp(pos.X, 4, math.max(4, screenSize.X - tipW - 4))
        local y = pos.Y + sz.Y + 4
        if y + 26 > screenSize.Y then y = pos.Y - 26 end
        tip.Position = UDim2.new(0, x, 0, math.max(4, y))
    end
    local function hide()
        if tip then pcall(function() tip:Destroy() end) tip = nil end
    end
    trackConnection(guiObj.MouseEnter, show)
    trackConnection(guiObj.MouseLeave, hide)
    -- The tip is parented to the root gui, so it would survive its owner being
    -- destroyed mid-hover and stay stuck on screen.
    trackConnection(guiObj.AncestryChanged, function()
        if not guiObj.Parent then hide() end
    end)
    if guiObj:IsA("GuiButton") then
        trackConnection(guiObj.MouseButton1Click, hide)
    end
end

-- cleanup: destroy all EZ windows, clear listeners, disconnect everything
function EZ:Destroy()
    if self._destroyed then return end
    self._destroyed = true

    -- Notify registered cleanup handlers before removing the callbacks they
    -- may rely on. Never let one cleanup handler block the others.
    if self._onDestroy then
        for _, fn in self._onDestroy do pcall(fn) end
    end

    -- Disconnect every tracked connection, including window/global handlers.
    for _, c in ipairs(self._connections or {}) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(self._connections or {})
    self._connectionOwner = nil
    self._activeDrag = nil

    if self._watermark then
        pcall(function() self._watermark:Destroy() end)
        self._watermark = nil
    end

    -- Keep the root ScreenGuis alive but empty. This makes EZ reusable after
    -- EZ:Destroy() / the close button instead of leaving dead ScreenGui
    -- references that CreateWindow() cannot parent into again.
    pcall(function()
        for _, child in gui:GetChildren() do
            child:Destroy()
        end
    end)
    pcall(function()
        for _, child in notifGui:GetChildren() do
            child:Destroy()
        end
    end)

    table.clear(self.Windows)
    table.clear(self.Notifications)
    table.clear(self.Flags)
    table.clear(self._listeners)
    table.clear(self._elements)
    self._onDestroy = nil
end

function EZ:OnDestroy(fn)
    if not self._onDestroy then self._onDestroy = {} end
    table.insert(self._onDestroy, fn)
end

return EZ
