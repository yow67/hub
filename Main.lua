-- Akatsuki Hub v3.6 | by Fox & Jack
-- Tabs: Aimbot / Player / ESP / Misc   (Delta iOS touch-ready)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local env = (getgenv and getgenv()) or _G
if env.AkatsukiCleanup then pcall(env.AkatsukiCleanup) end

local lp = Players.LocalPlayer
local character = lp.Character or lp.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local State = {
    Open = true,
    ActiveTab = "Aimbot",
    Dragging = false,
    DragOffset = Vector2.new(0, 0),
    Connections = {},
}

local AllConns = {}
local function Track(c) AllConns[#AllConns + 1] = c return c end

local Cleanup -- forward declaration

local T = {
    BG         = Color3.fromRGB(13, 14, 21),
    Sidebar    = Color3.fromRGB(18, 19, 28),
    Panel      = Color3.fromRGB(22, 23, 34),
    Card       = Color3.fromRGB(28, 30, 44),
    Accent     = Color3.fromRGB(88, 120, 255),
    AccentDark = Color3.fromRGB(55, 80, 200),
    AccentGlow = Color3.fromRGB(30, 50, 140),
    TextPri    = Color3.fromRGB(235, 236, 245),
    TextSec    = Color3.fromRGB(130, 133, 160),
    TextMut    = Color3.fromRGB(70, 72, 95),
    Border     = Color3.fromRGB(38, 40, 58),
    ToggleOff  = Color3.fromRGB(45, 47, 66),
    ToggleOn   = Color3.fromRGB(88, 120, 255),
    ToggleKnob = Color3.fromRGB(235, 236, 245),
    Red        = Color3.fromRGB(255, 85, 95),
    Green      = Color3.fromRGB(70, 210, 130),
    TopBar     = Color3.fromRGB(16, 17, 25),
}

local Tabs = {
    { Name = "Aimbot" },
    { Name = "Player" },
    { Name = "Macro"  },
    { Name = "ESP"    },
    { Name = "Performance" },
    { Name = "Misc"   },
}

local TabIcons = {
    Aimbot = "🎯",
    Player = "👤",
    Macro  = "⌨",
    ESP    = "👁",
    Performance = "⚡",
    Misc   = "⚙️",
}

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function Tween(obj, props, dur, style, dir)
    local ti = TweenInfo.new(dur or 0.32, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
end

local function Make(class, props, parent)
    local ok, obj = pcall(Instance.new, class)
    if not ok then return nil end
    for k, v in pairs(props) do
        if k ~= "Parent" then
            pcall(function() obj[k] = v end)
        end
    end
    if parent then obj.Parent = parent end
    return obj
end

local function Corner(obj, r)
    if not obj then return end
    Make("UICorner", {CornerRadius = UDim.new(0, r or 6)}, obj)
end

local function Stroke(obj, color, thickness)
    if not obj then return end
    Make("UIStroke", {Color = color or T.Border, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, obj)
end

local function Pad(obj, top, right, bottom, left)
    if not obj then return end
    Make("UIPadding", {
        PaddingTop    = UDim.new(0, top    or 8),
        PaddingRight  = UDim.new(0, right  or 8),
        PaddingBottom = UDim.new(0, bottom or 8),
        PaddingLeft   = UDim.new(0, left   or 8),
    }, obj)
end

local function Label(text, size, color, parent, props)
    props = props or {}
    props.Text                   = text
    props.TextSize               = size or 13
    props.TextColor3             = color or T.TextPri
    props.BackgroundTransparency = 1
    props.Font                   = props.Font or Enum.Font.GothamMedium
    props.RichText               = false
    props.TextWrapped            = true
    props.TextXAlignment         = props.TextXAlignment or Enum.TextXAlignment.Left
    return Make("TextLabel", props, parent)
end

local function SafeClipboard(text)
    pcall(function()
        if setclipboard then setclipboard(text)
        elseif Clipboard then Clipboard.set(text)
        elseif syn and syn.write_clipboard then syn.write_clipboard(text) end
    end)
end

local function DisconnectKey(key)
    if State.Connections[key] then
        pcall(function() State.Connections[key]:Disconnect() end)
        State.Connections[key] = nil
    end
end

-- ─── Root GUI ─────────────────────────────────────────────────────────────────
-- remove leftovers from older versions
for _, getC in ipairs({
    function() return lp:FindFirstChild("PlayerGui") end,
    function() return game:GetService("CoreGui") end,
    function() return gethui and gethui() end,
}) do
    pcall(function()
        local c = getC()
        local o = c and c:FindFirstChild("AkatsukiHub")
        if o then o:Destroy() end
    end)
end

local ScreenGui = Make("ScreenGui", {
    Name           = "AkatsukiHub",
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn   = false,
    IgnoreGuiInset = true,
})
do
    local targets = {}
    if gethui then pcall(function() targets[#targets + 1] = gethui() end) end
    pcall(function() targets[#targets + 1] = game:GetService("CoreGui") end)
    targets[#targets + 1] = lp:WaitForChild("PlayerGui")
    for _, t in ipairs(targets) do
        pcall(function() ScreenGui.Parent = t end)
        if ScreenGui.Parent == t then break end
    end
end

-- FOV circle (lock-on)
local FovCircle = Make("Frame", {
    Name                   = "FovCircle",
    AnchorPoint            = Vector2.new(0.5, 0.5),
    Position               = UDim2.new(0.5, 0, 0.5, 0),
    Size                   = UDim2.new(0, 360, 0, 360),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    Visible                = false,
}, ScreenGui)
Corner(FovCircle, 1000)
Stroke(FovCircle, Color3.new(1, 1, 1), 1.5)

-- ─── Main Frame ───────────────────────────────────────────────────────────────
local Main = Make("Frame", {
    Name             = "Main",
    Size             = UDim2.new(0, 520, 0, 360),
    Position         = UDim2.new(0.5, -260, 0.5, -180),
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
}, ScreenGui)
Corner(Main, 10)
Stroke(Main, T.Border, 1)

-- floating button (mobile): show / hide the hub
local FloatBtn = Make("TextButton", {
    Size             = UDim2.new(0, 34, 0, 34),
    Position         = UDim2.new(0.5, -17, 0, 6),
    BackgroundColor3 = T.AccentGlow,
    Text             = "☁",
    TextColor3       = T.Accent,
    TextSize         = 16,
    Font             = Enum.Font.GothamBold,
    BorderSizePixel  = 0,
    AutoButtonColor  = false,
    ZIndex           = 20,
}, ScreenGui)
Corner(FloatBtn, 100)
Stroke(FloatBtn, T.Accent, 1)
FloatBtn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)

-- ─── Top Bar ──────────────────────────────────────────────────────────────────
local TopBar = Make("Frame", {
    Name             = "TopBar",
    Size             = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = T.TopBar,
    BorderSizePixel  = 0,
    ZIndex           = 3,
}, Main)

Make("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = T.Border,
    BorderSizePixel  = 0,
}, TopBar)

local LogoPill = Make("Frame", {
    Size             = UDim2.new(0, 130, 0, 26),
    Position         = UDim2.new(0, 12, 0.5, -13),
    BackgroundColor3 = T.AccentGlow,
    BorderSizePixel  = 0,
    ZIndex           = 4,
}, TopBar)
Corner(LogoPill, 5)

Label("☁ Akatsuki Hub", 12, T.Accent, LogoPill, {
    Size           = UDim2.new(1, 0, 1, 0),
    ZIndex         = 5,
    TextXAlignment = Enum.TextXAlignment.Center,
    Font           = Enum.Font.GothamBold,
})

local VerBadge = Make("Frame", {
    Size             = UDim2.new(0, 38, 0, 18),
    Position         = UDim2.new(0, 148, 0.5, -9),
    BackgroundColor3 = T.Card,
    BorderSizePixel  = 0,
    ZIndex           = 4,
}, TopBar)
Corner(VerBadge, 4)
Stroke(VerBadge, T.Border, 1)
Label("v3.6", 10, T.TextSec, VerBadge, {
    Size           = UDim2.new(1, 0, 1, 0),
    ZIndex         = 5,
    TextXAlignment = Enum.TextXAlignment.Center,
})

local function MakeCtrlBtn(label, xpos, onclick)
    local btn = Make("TextButton", {
        Size             = UDim2.new(0, 26, 0, 22),
        Position         = UDim2.new(1, xpos, 0.5, -11),
        BackgroundColor3 = T.Card,
        Text             = label,
        TextColor3       = T.TextSec,
        TextSize         = 13,
        Font             = Enum.Font.GothamBold,
        BorderSizePixel  = 0,
        ZIndex           = 6,
        AutoButtonColor  = false,
    }, TopBar)
    Corner(btn, 4)
    Stroke(btn, T.Border, 1)
    btn.Activated:Connect(onclick)
    return btn
end

local minimizeBtn = MakeCtrlBtn("-", -62, function() end) -- wired after Body exists
MakeCtrlBtn("x", -32, function()
    Tween(Main, {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.3)
    task.delay(0.25, function() Cleanup() end)
end)

-- ─── Drag (mouse + touch) ─────────────────────────────────────────────────────
local dragBtn = Make("TextButton", {
    Size                   = UDim2.new(1, -70, 1, 0),
    BackgroundTransparency = 1,
    Text                   = "",
    ZIndex                 = 2,
    AutoButtonColor        = false,
}, TopBar)

local activeTouchInp = nil
local dragConn = nil

local function applyDrag(pos)
    local screenSize = workspace.CurrentCamera.ViewportSize
    local guiSize    = Main.AbsoluteSize
    local newX = math.clamp(pos.X - State.DragOffset.X, 0, math.max(0, screenSize.X - guiSize.X))
    local newY = math.clamp(pos.Y - State.DragOffset.Y, 0, math.max(0, screenSize.Y - guiSize.Y))
    Main.Position = UDim2.new(0, newX, 0, newY)
end

local function stopTouchDrag()
    activeTouchInp = nil
    if dragConn then dragConn:Disconnect(); dragConn = nil end
end

dragBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.Touch then return end
    if activeTouchInp then return end
    task.defer(function()
        activeTouchInp = inp
        State.DragOffset = Vector2.new(
            inp.Position.X - Main.AbsolutePosition.X,
            inp.Position.Y - Main.AbsolutePosition.Y
        )
        dragConn = RunService.Heartbeat:Connect(function()
            if not activeTouchInp then dragConn:Disconnect(); dragConn = nil; return end
            if inp.UserInputState == Enum.UserInputState.End then stopTouchDrag(); return end
            applyDrag(inp.Position)
        end)
    end)
end)
Track(UserInputService.InputEnded:Connect(function(inp)
    if inp == activeTouchInp then stopTouchDrag() end
end))

dragBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    State.Dragging = true
    State.DragOffset = Vector2.new(
        inp.Position.X - Main.AbsolutePosition.X,
        inp.Position.Y - Main.AbsolutePosition.Y
    )
end)
Track(UserInputService.InputChanged:Connect(function(inp)
    if State.Dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        applyDrag(inp.Position)
    end
end))
Track(UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then State.Dragging = false end
end))

-- ─── Body ─────────────────────────────────────────────────────────────────────
local Body = Make("Frame", {
    Size                   = UDim2.new(1, 0, 1, -42),
    Position               = UDim2.new(0, 0, 0, 42),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
}, Main)

minimizeBtn.Activated:Connect(function()
    State.Open = not State.Open
    if State.Open then
        Body.Visible = true
        task.defer(function() Tween(Main, {Size = UDim2.new(0, 520, 0, 360)}, 0.38) end)
    else
        Tween(Main, {Size = UDim2.new(0, 520, 0, 42)}, 0.38)
        task.delay(0.24, function() Body.Visible = false end)
    end
end)

-- ─── Sidebar ──────────────────────────────────────────────────────────────────
local Sidebar = Make("Frame", {
    Size             = UDim2.new(0, 130, 1, 0),
    BackgroundColor3 = T.Sidebar,
    BorderSizePixel  = 0,
}, Body)

Make("Frame", {
    Size             = UDim2.new(0, 1, 1, 0),
    Position         = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = T.Border,
    BorderSizePixel  = 0,
}, Sidebar)

local SideList = Make("Frame", {
    Size                   = UDim2.new(1, 0, 1, -60),
    BackgroundTransparency = 1,
}, Sidebar)
Make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, SideList)
Pad(SideList, 10, 8, 10, 8)

local SideBottom = Make("Frame", {
    Size             = UDim2.new(1, 0, 0, 60),
    Position         = UDim2.new(0, 0, 1, -60),
    BackgroundColor3 = T.BG,
    BorderSizePixel  = 0,
    ZIndex           = 2,
}, Sidebar)
Make("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = T.Border,
    BorderSizePixel  = 0,
    ZIndex           = 2,
}, SideBottom)
Label(lp.Name, 11, T.TextPri, SideBottom, {
    Size     = UDim2.new(1, -8, 0, 18),
    Position = UDim2.new(0, 8, 0, 10),
    ZIndex   = 3,
    Font     = Enum.Font.GothamBold,
})

-- ─── Content ──────────────────────────────────────────────────────────────────
local Content = Make("Frame", {
    Size             = UDim2.new(1, -130, 1, 0),
    Position         = UDim2.new(0, 130, 0, 0),
    BackgroundColor3 = T.Panel,
    BorderSizePixel  = 0,
    ClipsDescendants = true,
}, Body)

local Pages = {}
local SideButtons = {}

local function CreatePage(name)
    local page = Make("ScrollingFrame", {
        Name                   = name,
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 3,
        ScrollBarImageColor3   = T.Accent,
        Visible                = false,
        CanvasSize             = UDim2.new(0, 0, 0, 0),
    }, Content)
    Pad(page, 14, 14, 14, 14)
    local layout = Make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, page)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 28)
    end)
    Pages[name] = page
    return page
end

local function CreateTabButton(tabName, idx)
    local isActive = tabName == State.ActiveTab
    local btn = Make("TextButton", {
        Size                   = UDim2.new(1, 0, 0, 34),
        BackgroundColor3       = isActive and T.AccentGlow or Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = isActive and 0 or 1,
        Text                   = "",
        BorderSizePixel        = 0,
        LayoutOrder            = idx,
        AutoButtonColor        = false,
        ZIndex                 = 2,
    }, SideList)
    Corner(btn, 6)

    local icon = Label((TabIcons[tabName] or "") .. "  " .. tabName, 12,
        isActive and T.Accent or T.TextSec, btn, {
        Size     = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        ZIndex   = 3,
        Font     = isActive and Enum.Font.GothamBold or Enum.Font.GothamMedium,
    })

    local bar = Make("Frame", {
        Size             = UDim2.new(0, 3, 0.6, 0),
        Position         = UDim2.new(0, 0, 0.2, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
        Visible          = isActive,
        ZIndex           = 4,
    }, btn)
    Corner(bar, 3)

    SideButtons[tabName] = {btn = btn, icon = icon, bar = bar}

    btn.MouseButton1Click:Connect(function()
        if State.ActiveTab == tabName then return end
        local old = SideButtons[State.ActiveTab]
        if old then
            Tween(old.btn, {BackgroundTransparency = 1}, 0.28)
            old.bar.Visible = false
            old.icon.TextColor3 = T.TextSec
            old.icon.Font = Enum.Font.GothamMedium
        end
        if Pages[State.ActiveTab] then Pages[State.ActiveTab].Visible = false end
        State.ActiveTab = tabName
        Pages[tabName].Visible = true
        Tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = T.AccentGlow}, 0.28)
        bar.Visible = true
        Tween(icon, {TextColor3 = T.Accent}, 0.28)
        icon.Font = Enum.Font.GothamBold
    end)
end

-- ─── Components ───────────────────────────────────────────────────────────────
local function SectionHeader(text, parent)
    local frame = Make("Frame", {
        Size                   = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
    }, parent)
    Label(text:upper(), 10, T.TextMut, frame, {
        Size = UDim2.new(1, -20, 1, 0),
        Font = Enum.Font.GothamBold,
    })
    Make("Frame", {
        Size             = UDim2.new(1, -80, 0, 1),
        Position         = UDim2.new(0, 76, 0.5, 0),
        BackgroundColor3 = T.Border,
        BorderSizePixel  = 0,
    }, frame)
    return frame
end

-- ─── Settings memory: every toggle / slider / dropdown is saved and restored on the next execute ───
local Persist = { cfg = {}, cur = {}, reg = {}, used = {}, skip = false, pending = false }
local PERSIST_FILE = "AkatsukiHub/settings.json"
pcall(function()
    if isfolder and makefolder and not isfolder("AkatsukiHub") then makefolder("AkatsukiHub") end
    if isfile and readfile and isfile(PERSIST_FILE) then
        local d = HttpService:JSONDecode(readfile(PERSIST_FILE))
        if type(d) == "table" then Persist.cfg = d end
    end
end)
for k, v in pairs(Persist.cfg) do Persist.cur[k] = v end
function Persist.key(label)
    if Persist.skip then return nil end
    local n = (Persist.used[label] or 0) + 1
    Persist.used[label] = n
    return n == 1 and label or (label .. "#" .. n)
end
function Persist.note(key, v)
    if not key then return end
    Persist.cur[key] = v
    if Persist.pending or not writefile then return end
    Persist.pending = true
    task.delay(1, function()
        Persist.pending = false
        pcall(function() writefile(PERSIST_FILE, HttpService:JSONEncode(Persist.cur)) end)
    end)
end
function Persist.add(key, setter)
    if key then Persist.reg[#Persist.reg + 1] = { key = key, set = setter } end
end
function Persist.restore()
    for _, r in ipairs(Persist.reg) do
        local v = Persist.cfg[r.key]
        if v ~= nil then pcall(r.set, v) end
    end
end

local function Toggle(parent, labelText, desc, default, callback)
    local togState = default or false
    local pkey = Persist.key(labelText)

    local frame = Make("Frame", {
        Size             = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = T.Card,
        BorderSizePixel  = 0,
    }, parent)
    Corner(frame, 7)
    Stroke(frame, T.Border, 1)

    Label(labelText, 13, T.TextPri, frame, {
        Size     = UDim2.new(1, -64, 0, 18),
        Position = UDim2.new(0, 12, 0, 10),
    })
    if desc and desc ~= "" then
        Label(desc, 11, T.TextSec, frame, {
            Size     = UDim2.new(1, -64, 0, 14),
            Position = UDim2.new(0, 12, 0, 28),
        })
    end

    local track = Make("Frame", {
        Size             = UDim2.new(0, 40, 0, 20),
        Position         = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = togState and T.ToggleOn or T.ToggleOff,
        BorderSizePixel  = 0,
    }, frame)
    Corner(track, 100)

    local knob = Make("Frame", {
        Size             = UDim2.new(0, 14, 0, 14),
        Position         = togState and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = T.ToggleKnob,
        BorderSizePixel  = 0,
    }, track)
    Corner(knob, 100)

    local dot = Make("Frame", {
        Size             = UDim2.new(0, 6, 0, 6),
        Position         = UDim2.new(1, -10, 0, 6),
        BackgroundColor3 = togState and T.Green or T.TextMut,
        BorderSizePixel  = 0,
    }, frame)
    Corner(dot, 100)

    local btn = Make("TextButton", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        ZIndex                 = 2,
    }, frame)

    local function apply(v)
        togState = v
        Tween(track, {BackgroundColor3 = togState and T.ToggleOn or T.ToggleOff}, 0.32)
        Tween(knob,  {Position = togState and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}, 0.32)
        Tween(dot,   {BackgroundColor3 = togState and T.Green or T.TextMut}, 0.32)
        Persist.note(pkey, togState)
        if callback then pcall(callback, togState) end
    end

    btn.MouseButton1Click:Connect(function() apply(not togState) end)

    -- 2nd return value: setter, so other UI (small GUIs) can flip this toggle
    local setter = function(v) if type(v) == "boolean" and v ~= togState then apply(v) end end
    Persist.add(pkey, setter)
    return frame, setter
end

-- slider: mouse + touch, locks page scrolling while dragging
local function Slider(parent, labelText, min, max, default, suffix, callback)
    local val = default or min
    local pkey = Persist.key(labelText)

    local frame = Make("Frame", {
        Size             = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = T.Card,
        BorderSizePixel  = 0,
    }, parent)
    Corner(frame, 7)
    Stroke(frame, T.Border, 1)

    Label(labelText, 13, T.TextPri, frame, {
        Size     = UDim2.new(1, -90, 0, 18),
        Position = UDim2.new(0, 12, 0, 8),
    })

    local valLabel = Label(tostring(val) .. (suffix or ""), 12, T.Accent, frame, {
        Size           = UDim2.new(0, 70, 0, 18),
        Position       = UDim2.new(1, -80, 0, 8),
        TextXAlignment = Enum.TextXAlignment.Right,
        Font           = Enum.Font.GothamBold,
    })

    local trackBg = Make("Frame", {
        Size             = UDim2.new(1, -24, 0, 5),
        Position         = UDim2.new(0, 12, 0, 38),
        BackgroundColor3 = T.ToggleOff,
        BorderSizePixel  = 0,
    }, frame)
    Corner(trackBg, 3)

    local pct = (val - min) / (max - min)
    local trackFill = Make("Frame", {
        Size             = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = T.Accent,
        BorderSizePixel  = 0,
    }, trackBg)
    Corner(trackFill, 3)

    local thumb = Make("Frame", {
        Size             = UDim2.new(0, 13, 0, 13),
        Position         = UDim2.new(pct, -6, 0.5, -6),
        BackgroundColor3 = T.ToggleKnob,
        BorderSizePixel  = 0,
        ZIndex           = 2,
    }, trackBg)
    Corner(thumb, 100)
    Stroke(thumb, T.Accent, 2)

    -- big invisible hit area (easy to grab on a phone)
    local hit = Make("TextButton", {
        Size                   = UDim2.new(1, -12, 0, 26),
        Position               = UDim2.new(0, 6, 0, 28),
        BackgroundTransparency = 1,
        Text                   = "",
        ZIndex                 = 3,
    }, frame)

    local activeInp = nil
    local function setFromX(x)
        local rel = math.clamp((x - trackBg.AbsolutePosition.X) / math.max(1, trackBg.AbsoluteSize.X), 0, 1)
        local newVal = math.floor(min + (max - min) * rel + 0.5)
        rel = (newVal - min) / (max - min)
        trackFill.Size = UDim2.new(rel, 0, 1, 0)
        thumb.Position = UDim2.new(rel, -6, 0.5, -6)
        if newVal ~= val then
            val = newVal
            valLabel.Text = tostring(val) .. (suffix or "")
            Persist.note(pkey, val)
            if callback then pcall(callback, val) end
        end
    end

    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            activeInp = inp
            pcall(function() parent.ScrollingEnabled = false end)
            setFromX(inp.Position.X)
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(inp)
        if not activeInp then return end
        if inp == activeInp or inp.UserInputType == Enum.UserInputType.MouseMovement then
            setFromX(inp.Position.X)
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(inp)
        if activeInp and (inp == activeInp or inp.UserInputType == Enum.UserInputType.MouseButton1) then
            activeInp = nil
            pcall(function() parent.ScrollingEnabled = true end)
        end
    end))

    local function setVal(v)
        if type(v) ~= "number" then return end
        v = math.clamp(math.floor(v + 0.5), min, max)
        local rel = (v - min) / (max - min)
        trackFill.Size = UDim2.new(rel, 0, 1, 0)
        thumb.Position = UDim2.new(rel, -6, 0.5, -6)
        valLabel.Text = tostring(v) .. (suffix or "")
        val = v
        Persist.note(pkey, v)
        if callback then pcall(callback, v) end
    end
    Persist.add(pkey, setVal)
    return frame, setVal
end

local function Button(parent, labelText, color, callback)
    local btn = Make("TextButton", {
        Size             = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = color or T.Accent,
        Text             = "",
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
    }, parent)
    Corner(btn, 7)
    Label(labelText, 13, Color3.fromRGB(255, 255, 255), btn, {
        Size           = UDim2.new(1, 0, 1, 0),
        Font           = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    btn.MouseButton1Click:Connect(function()
        Tween(btn, {BackgroundColor3 = (color or T.Accent):Lerp(Color3.new(1, 1, 1), 0.15)}, 0.16)
        task.delay(0.12, function() Tween(btn, {BackgroundColor3 = color or T.Accent}, 0.35) end)
        if callback then pcall(callback) end
    end)
    return btn
end

-- dropdown that expands inline (no clipping), options come from a function so the list can be live
local function Dropdown(parent, labelText, getOptions, default, callback)
    local selected = default
    local pkey = Persist.key(labelText)
    local open = false
    local setOpen

    local outer = Make("Frame", {
        Size             = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = T.Card,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
    }, parent)
    Corner(outer, 7)
    Stroke(outer, T.Border, 1)

    Label(labelText, 13, T.TextPri, outer, {
        Size     = UDim2.new(1, -160, 0, 18),
        Position = UDim2.new(0, 12, 0, 17),
    })

    local selBtn = Make("TextButton", {
        Size             = UDim2.new(0, 130, 0, 26),
        Position         = UDim2.new(1, -142, 0, 13),
        BackgroundColor3 = T.Panel,
        Text             = "",
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
        ZIndex           = 2,
    }, outer)
    Corner(selBtn, 5)
    Stroke(selBtn, T.Border, 1)

    local selLabel = Label(selected, 11, T.TextPri, selBtn, {
        Size     = UDim2.new(1, -24, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        ZIndex   = 3,
    })
    selLabel.TextWrapped = false
    selLabel.TextTruncate = Enum.TextTruncate.AtEnd
    Label("v", 11, T.TextSec, selBtn, {
        Size           = UDim2.new(0, 16, 1, 0),
        Position       = UDim2.new(1, -18, 0, 0),
        ZIndex         = 3,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local list = Make("ScrollingFrame", {
        Size                   = UDim2.new(1, -16, 0, 0),
        Position               = UDim2.new(0, 8, 0, 56),
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        ScrollBarThickness     = 2,
        ScrollBarImageColor3   = T.Accent,
        CanvasSize             = UDim2.new(0, 0, 0, 0),
        Visible                = false,
    }, outer)
    Make("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, list)

    local function rebuild()
        for _, c in ipairs(list:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        local opts = getOptions()
        for i, opt in ipairs(opts) do
            local isSel = opt == selected
            local ob = Make("TextButton", {
                Size             = UDim2.new(1, -4, 0, 26),
                BackgroundColor3 = isSel and T.AccentGlow or T.Panel,
                Text             = "",
                BorderSizePixel  = 0,
                AutoButtonColor  = false,
                LayoutOrder      = i,
            }, list)
            Corner(ob, 4)
            Label(opt, 11, isSel and T.Accent or T.TextPri, ob, {
                Size     = UDim2.new(1, -12, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
            })
            ob.MouseButton1Click:Connect(function()
                selected = opt
                selLabel.Text = opt
                setOpen(false)
                Persist.note(pkey, opt)
                if callback then pcall(callback, opt) end
            end)
        end
        list.CanvasSize = UDim2.new(0, 0, 0, #opts * 28)
        return #opts
    end

    setOpen = function(v)
        open = v
        if v then
            local n = rebuild()
            local h = math.min(math.max(n, 1) * 28, 112)
            list.Size = UDim2.new(1, -16, 0, h)
            list.Visible = true
            Tween(outer, {Size = UDim2.new(1, 0, 0, 52 + h + 8)}, 0.25)
        else
            Tween(outer, {Size = UDim2.new(1, 0, 0, 52)}, 0.25)
            task.delay(0.26, function() if not open then list.Visible = false end end)
        end
    end

    selBtn.MouseButton1Click:Connect(function() setOpen(not open) end)

    Persist.add(pkey, function(v)
        if type(v) ~= "string" then return end
        selected = v; selLabel.Text = v
        if callback then pcall(callback, v) end
    end)
    return {
        Frame = outer,
        Set = function(v) selected = v; selLabel.Text = v end,
    }
end

-- ─── Build tabs ───────────────────────────────────────────────────────────────
-- text box row (label left, input right)
local function TextInput(parent, labelText, default, callback)
    local frame = Make("Frame", {
        Size             = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = T.Card,
        BorderSizePixel  = 0,
    }, parent)
    Corner(frame, 7)
    Stroke(frame, T.Border, 1)

    Label(labelText, 13, T.TextPri, frame, {
        Size     = UDim2.new(0.4, -12, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
    })

    local box = Make("TextBox", {
        Size              = UDim2.new(0.6, -20, 0, 30),
        Position          = UDim2.new(0.4, 8, 0.5, -15),
        BackgroundColor3  = T.Panel,
        TextColor3        = T.TextPri,
        PlaceholderColor3 = T.TextMut,
        PlaceholderText   = "type a name",
        Text              = default or "",
        Font              = Enum.Font.GothamMedium,
        TextSize          = 12,
        ClearTextOnFocus  = false,
        BorderSizePixel   = 0,
        TextXAlignment    = Enum.TextXAlignment.Left,
        ClipsDescendants  = true,
    }, frame)
    Corner(box, 5)
    Stroke(box, T.Border, 1)
    Pad(box, 0, 8, 0, 8)

    box.FocusLost:Connect(function()
        if callback then pcall(callback, box.Text) end
    end)
    return box
end

for i, tab in ipairs(Tabs) do
    CreatePage(tab.Name)
    CreateTabButton(tab.Name, i)
end
Pages[State.ActiveTab].Visible = true

-- ═══ AIMBOT LOGIC ═════════════════════════════════════════════════════════════
local Aim = {
    LockOn     = false,   -- camera lock
    Silent     = false,   -- silent aim, nearest player
    Choose     = false,   -- silent aim (and lock target) on selected player
    Target     = nil,     -- selected player name
    FOV        = 180,
    Smooth     = 0.7,
    Part       = "HumanoidRootPart",
    MaxDist    = 1500,
    Prediction = 0,
    ShowFOV    = true,
    TeamCheck  = true,    -- never aim at teammates
    AutoPredict = true,   -- lead moving targets using ping + distance / ProjSpeed
    ProjSpeed  = 350,     -- studs/sec used for the lead calculation
    Sticky     = true,    -- silent aim keeps the same target instead of flip-flopping
    HoldLock   = true,    -- camera lock stays on its target (even outside the FOV) until it dies / leaves range
    SpoofMouse = true,    -- also redirect Mouse.Hit while silent aim is on
    TargetPlayers = true, -- aimbot works on other players
    TargetNPCs    = false, -- aimbot works on NPC enemies (workspace.Enemies)
    SkipMelee  = false,   -- ON = silent aim leaves melee moves exactly as the game sent them (default: melee is aimed too)
    Debug      = false,   -- print every move the silent aim rewrote
    AutoClosest = true,   -- silent aim always goes to whoever is closest to you
    Cone       = 180,     -- silent aim only redirects a move if the target is within this many degrees of where you aimed it (180 = always)
    Hold       = false,   -- Switch is ON: stay on the player picked when it was turned on (no auto-closest steal)
    Allies     = {},      -- usernames picked in the Allies list: never targeted, whatever team they are on
    Circle     = false,   -- Aim Circle: silent aim only picks targets whose screen position is inside the circle
    CircleR    = 150,     -- circle radius (px)
    CircleDX   = 0,       -- circle centre offset from the screen centre (px), to line it up with your crosshair
    CircleDY   = 0,
}

local function RefreshFov()
    FovCircle.Visible = Aim.LockOn and Aim.ShowFOV
    FovCircle.Size = UDim2.new(0, Aim.FOV * 2, 0, Aim.FOV * 2)
end

local function alive(char)
    local h = char and char:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function isNpc(p)            -- NPC stand-ins are plain tables; real players are Instances
    return type(p) == "table" and p.IsNpc == true
end

local function isAlly(p)
    if isNpc(p) then return false end
    if Aim.Allies[p.Name] then return true end
    return Aim.TeamCheck and p.Team ~= nil and p.Team == lp.Team
end

-- how far ahead of the target to aim (seconds)
local function leadTime(dist)
    local t = Aim.Prediction
    if Aim.AutoPredict then
        local ping = 0
        pcall(function() ping = lp:GetNetworkPing() end)
        t = t + ping + dist / math.max(Aim.ProjSpeed, 1)
    end
    return math.min(t, 0.6)
end

local function aimPos(char)
    local part = char:FindFirstChild(Aim.Part) or char:FindFirstChild("HumanoidRootPart")
    if not part then return nil end
    local dist = (rootPart and rootPart.Parent) and (part.Position - rootPart.Position).Magnitude or 0
    local v = part.AssemblyLinearVelocity
    v = Vector3.new(v.X, v.Y * 0.3, v.Z)          -- jumps/falls make vertical lead overshoot
    local lead = v * leadTime(dist)
    if lead.Magnitude > 30 then lead = lead.Unit * 30 end   -- dashes / teleports must not throw the aim off
    return part.Position + lead, part
end

-- NPC enemies behave like players for the aimbot: a small stand-in object per mob (same object every time, so
-- "the current target" comparisons keep working)
local npcCache = setmetatable({}, { __mode = "k" })
local function npcProxy(m)
    local px = npcCache[m]
    if not px then
        px = setmetatable({ IsNpc = true, Model = m, Name = m.Name, Character = m }, {
            __index = function(_, k)
                if k == "Parent" then return m.Parent end
                return nil
            end,
        })
        npcCache[m] = px
    end
    return px
end

-- everything the aimbot may pick from, depending on Target Players / Target NPCs
local function eachTarget()
    local list = {}
    if Aim.TargetPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then list[#list + 1] = p end
        end
    end
    if Aim.TargetNPCs then
        local f = workspace:FindFirstChild("Enemies")
        if f then
            for _, m in ipairs(f:GetChildren()) do
                if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then list[#list + 1] = npcProxy(m) end
            end
        end
    end
    return list
end

-- Aim Circle: drawn on screen, and (when on) silent aim ignores everybody outside it
local AimCircle = Make("Frame", {
    Name                   = "AimCircle",
    AnchorPoint            = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    Visible                = false,
    ZIndex                 = 0,
}, ScreenGui)
Corner(AimCircle, 1000)
Stroke(AimCircle, Color3.fromRGB(120, 160, 255), 1.5)
local function circleCenter()
    local cam = workspace.CurrentCamera
    local vs = cam.ViewportSize
    return Vector2.new(vs.X / 2 + Aim.CircleDX, vs.Y / 2 + Aim.CircleDY)
end
local function inCircle(p)
    if not Aim.Circle then return true end
    local cam = workspace.CurrentCamera
    local pos = p and p.Character and aimPos(p.Character)
    if not pos then return false end
    local sp, on = cam:WorldToViewportPoint(pos)
    if not on then return false end
    return (Vector2.new(sp.X, sp.Y) - circleCenter()).Magnitude <= Aim.CircleR
end
Track(RunService.RenderStepped:Connect(function()
    local vis = Aim.Circle
    AimCircle.Visible = vis
    if not vis then return end
    local c = circleCenter()
    AimCircle.Position = UDim2.fromOffset(c.X, c.Y)
    AimCircle.Size = UDim2.fromOffset(Aim.CircleR * 2, Aim.CircleR * 2)
end))

local stickyP = nil
local function nearestPlayer()
    if not (rootPart and rootPart.Parent) then return nil end
    local bestD, bestP = Aim.MaxDist, nil
    for _, p in ipairs(eachTarget()) do
        if p ~= lp and not isAlly(p) and alive(p.Character) and inCircle(p) then
            local hr = p.Character:FindFirstChild("HumanoidRootPart")
            if hr then
                local d = (hr.Position - rootPart.Position).Magnitude
                if d < bestD then bestD, bestP = d, p end
            end
        end
    end
    if Aim.Sticky and stickyP and stickyP ~= bestP and stickyP.Parent
        and not isAlly(stickyP) and alive(stickyP.Character) and inCircle(stickyP) then
        local hr = stickyP.Character:FindFirstChild("HumanoidRootPart")
        if hr then
            local sd = (hr.Position - rootPart.Position).Magnitude
            -- keep this player until they die, leave, become an ally or go out of range ...
            if sd <= Aim.MaxDist then
                -- ... unless Auto Switch is on: then whoever is closest to you always wins
                local steal = Aim.AutoClosest and not Aim.Hold and bestP and bestP ~= stickyP
                if not steal then return stickyP end
            end
        end
    end
    stickyP = bestP
    return bestP
end

-- manual switch: jump to the closest valid player other than your current target
local function switchTarget()
    if not (rootPart and rootPart.Parent) then return nil end
    local list = {}
    for _, p in ipairs(eachTarget()) do
        if p ~= lp and not isAlly(p) and alive(p.Character) and inCircle(p) then
            local hr = p.Character:FindFirstChild("HumanoidRootPart")
            if hr then
                local d = (hr.Position - rootPart.Position).Magnitude
                if d <= Aim.MaxDist then list[#list + 1] = { p = p, d = d } end
            end
        end
    end
    if #list == 0 then stickyP = nil return nil end
    table.sort(list, function(a, b) return a.d < b.d end)
    -- the closest player who is NOT the one you are on right now (if you are on the closest one: the 2nd closest)
    for _, e in ipairs(list) do
        if e.p ~= stickyP then stickyP = e.p return stickyP end
    end
    return stickyP
end

local function nearestPos()
    local p = nearestPlayer()
    if p then return (aimPos(p.Character)) end
    return nil
end

local function chosenPos()
    if not Aim.Target then return nil end
    local p = Players:FindFirstChild(Aim.Target)
    if p and not isAlly(p) and alive(p.Character) then
        return (aimPos(p.Character))
    end
    return nil
end

local function validLockP(p)
    if not p or not p.Parent or isAlly(p) or not alive(p.Character) then return false end
    local hr = p.Character:FindFirstChild("HumanoidRootPart")
    if not hr then return false end
    return not (rootPart and rootPart.Parent) or (hr.Position - rootPart.Position).Magnitude <= Aim.MaxDist
end

-- player closest to the screen centre inside the FOV circle
local function fovPlayer()
    local cam = workspace.CurrentCamera
    local vs = cam.ViewportSize
    local center = Vector2.new(vs.X / 2, vs.Y / 2)
    local bestD, bestP = Aim.FOV, nil
    for _, p in ipairs(eachTarget()) do
        if p ~= lp and validLockP(p) then
            local pos = aimPos(p.Character)
            if pos then
                local sp, on = cam:WorldToViewportPoint(pos)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD then bestD, bestP = d, p end
                end
            end
        end
    end
    return bestP
end

-- who does silent aim redirect to right now
local function silentPos()
    if not (Aim.Silent or Aim.Choose) then return nil end
    if Aim.Choose then
        local c = chosenPos()
        if c then return c end
        if not Aim.Silent then return nil end
    end
    return nearestPos()
end

env.AkatsukiSilent = function()
    local t = silentPos()
    if t and rootPart and rootPart.Parent then return t, rootPart.Position end
    return nil
end

-- camera lock: bound just after the game camera so nothing overrides it, and it HOLDS its target
local lockP = nil

-- where the aimbot is pointing right now (silent target first, then the camera-lock target)
local function currentAimPos()
    local t = silentPos()
    if t then return t end
    if Aim.LockOn and lockP and validLockP(lockP) then return (aimPos(lockP.Character)) end
    return nil
end

-- Godhuman dash redirect state (logic lives after the move tracking in the Player tab)
local Chase = { On = true, Range = 60, Cone = 70, decided = -10, allow = false, reported = -10, said = {}, gyro = nil, bpos = nil, pressAt = -10, lastFire = -10, prev = nil, bv = nil, root = nil, conn = nil }

pcall(function() RunService:UnbindFromRenderStep("AkatsukiAim") end)
RunService:BindToRenderStep("AkatsukiAim", Enum.RenderPriority.Camera.Value + 1, function()
    if not Aim.LockOn then lockP = nil return end
    local p
    if Aim.Choose and Aim.Target then
        p = Players:FindFirstChild(Aim.Target)
        if not validLockP(p) then p = nil end
    end
    if not p then
        if not (Aim.HoldLock and validLockP(lockP)) then lockP = fovPlayer() end
        p = lockP
    end
    if not p then return end
    local pos = aimPos(p.Character)
    if not pos then return end
    local cam = workspace.CurrentCamera
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, pos), math.clamp(Aim.Smooth, 0.02, 1))
end)

-- is the target roughly in the direction the move was aimed? (flat angle, so heights don't matter)
local function withinCone(origDir, myPos, target)
    if Aim.Cone >= 180 then return true end
    local a = Vector3.new(origDir.X, 0, origDir.Z)
    local b = Vector3.new(target.X - myPos.X, 0, target.Z - myPos.Z)
    if a.Magnitude < 0.01 or b.Magnitude < 0.01 then return true end
    return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))) <= Aim.Cone
end

-- silent aim: __namecall hook, installed once per session
-- touches only FireServer on RemoteEvents under Workspace.Characters.<me>,
-- skips the "Humanoid" remote and calls whose first arg is a boolean
if not env.AkatsukiHooked39 then
    env.AkatsukiHooked39 = pcall(function()
        local wrap = newcclosure or function(f) return f end
        local setm = setnamecallmethod or function() end
        local old
        old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
            local method = getnamecallmethod()
            local fn = env.AkatsukiSilent

            -- move start/stop tracking: the game sends boolean true/false when a move is pressed/released
            local onMove = env.AkatsukiMove
            local isCall = method == "FireServer" or method == "InvokeServer"
            if onMove and isCall and not checkcaller() then
                local a1 = ...
                local wantMove = onMove and method == "FireServer" and type(a1) == "boolean"
                if wantMove and typeof(self) == "Instance" then
                    -- move remotes: Workspace.Characters.<me>.<MovesetFolder>.RemoteEvent
                    local ok, mine = pcall(function()
                        local gp = self.Parent and self.Parent.Parent
                        return self.ClassName == "RemoteEvent" and gp ~= nil and gp.Name == lp.Name
                            and gp.Parent ~= nil and gp.Parent.Name == "Characters"
                    end)
                    if ok then
                        if wantMove and mine and self.Name ~= "Humanoid" then pcall(onMove, a1, self) end
                    end
                end
                setm(method)
            end

            if fn and method == "FireServer" and not checkcaller() then
                local target, myPos = fn()
                if target and myPos and typeof(self) == "Instance" and self.Name ~= "Humanoid"
                    and self:IsA("RemoteEvent")
                    and self:GetFullName():find("Workspace.Characters." .. lp.Name, 1, true) then

                    local n = select("#", ...)
                    local args = { ... }
                    -- melee moves are aimed like every other move (redirected to the target); "Skip Melee Moves" leaves them
                    -- exactly as the game sent them.
                    local skipMelee = false
                    if Aim.SkipMelee then
                        local okT, tt = pcall(function()
                            local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
                            return tool and tool.ToolTip
                        end)
                        skipMelee = okT and tt == "Melee"
                    end
                    if typeof(args[1]) ~= "boolean" and not skipMelee then
                        local orig
                        if Aim.Debug then
                            orig = {}
                            for i = 1, n do orig[i] = typeof(args[i]) .. ":" .. tostring(args[i]) end
                        end
                        local changed = false
                        for i = 1, n do
                            local v = args[i]
                            local t = typeof(v)
                            if t == "Vector3" then
                                if math.abs(v.Magnitude - 1) < 0.1 then
                                    if withinCone(v, myPos, target) then
                                        args[i] = (target - myPos).Unit      -- direction arg
                                        changed = true
                                    end
                                elseif (v - myPos).Magnitude > 6 then
                                    if withinCone(v - myPos, myPos, target) then
                                        args[i] = target                      -- aim position arg
                                        changed = true
                                    end
                                end
                            elseif t == "CFrame" then
                                if (v.Position - myPos).Magnitude > 6 and withinCone(v.Position - myPos, myPos, target) then
                                    args[i] = CFrame.new(target)
                                    changed = true
                                end
                            end
                        end
                        if changed then
                            if Aim.Debug then
                                local nw = {}
                                for i = 1, n do nw[i] = typeof(args[i]) .. ":" .. tostring(args[i]) end
                                print("[AkatsukiHub] aim rewrote " .. self.Name .. "\n  was: " .. table.concat(orig, ", ") .. "\n  now: " .. table.concat(nw, ", "))
                            end
                            local zf = env.AkatsukiZFire
                            if zf then pcall(zf, self) end
                            setm(method) -- my calls above clobbered the namecall method
                            return old(self, table.unpack(args, 1, n))
                        end
                        if Aim.Debug then
                            print("[AkatsukiHub] aim saw " .. self.Name .. " (left as is)\n  args: " .. table.concat(orig, ", "))
                        end
                    end
                end
            end
            setm(method)
            return old(self, ...)
        end))
    end)
end

-- Mouse.Hit spoof: moves read the mouse position client-side too, so redirect it while silent aim is on
if not env.AkatsukiIdxHooked then
    env.AkatsukiIdxHooked = pcall(function()
        local mouse = lp:GetMouse()
        local wrap = newcclosure or function(f) return f end
        local oldIdx
        oldIdx = hookmetamethod(game, "__index", wrap(function(self, k)
            if self == mouse and k == "Hit" and Aim.SpoofMouse and not checkcaller() then
                local fn = env.AkatsukiSilent
                local t = fn and fn()
                if t then
                    if Aim.Debug and os.clock() - (env.AkatsukiMouseLog or 0) > 0.4 then
                        env.AkatsukiMouseLog = os.clock()
                        local cs
                        pcall(function() cs = getcallingscript and getcallingscript() end)
                        print("[AkatsukiHub] aim spoofed Mouse.Hit for script: " .. (cs and cs:GetFullName() or "?"))
                    end
                    return CFrame.new(t)
                end
            end
            return oldIdx(self, k)
        end))
    end)
end

-- ═══ ESP LOGIC ════════════════════════════════════════════════════════════════
-- Drawn every frame on its own overlay (boxes, health bars, names, tracers) so it follows players smoothly.
local ESP = {
    Box = false, Names = false, Health = false, Tracers = false, Chams = false, Info = false,
    HideAllies = false, MaxDist = 3000, TracerFrom = "Bottom", ChamFill = 0.5,
}

local espGui = Make("ScreenGui", {
    Name = "AK_ESPGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3,
}, ScreenGui.Parent)
local espObjs = {}

local function newEspObj()
    local o = {}
    o.box = Make("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, espGui)
    o.boxStroke = Instance.new("UIStroke")
    o.boxStroke.Thickness = 1.5
    o.boxStroke.Parent = o.box
    o.hpBg = Make("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25,
        BorderSizePixel = 0, Visible = false,
    }, espGui)
    o.hp = Make("Frame", {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 1, 0),
    }, o.hpBg)
    local function text(anchorY)
        return Make("TextLabel", {
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
            TextStrokeTransparency = 0.35, Visible = false, Size = UDim2.fromOffset(200, 14),
            AnchorPoint = Vector2.new(0.5, anchorY), Text = "",
        }, espGui)
    end
    o.name = text(1)
    o.info = text(0)
    o.info.TextSize = 12
    o.line = Make("Frame", {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false,
    }, espGui)
    return o
end

local function hideEspObj(o)
    o.box.Visible = false
    o.hpBg.Visible = false
    o.name.Visible = false
    o.info.Visible = false
    o.line.Visible = false
end

local function RemoveESPFor(p)
    local o = espObjs[p]
    if o then
        for _, k in ipairs({ "box", "hpBg", "name", "info", "line" }) do pcall(function() o[k]:Destroy() end) end
        espObjs[p] = nil
    end
    local c = p.Character
    if not c then return end
    local hl = c:FindFirstChild("AK_CHAMS")
    if hl then hl:Destroy() end
    local hr = c:FindFirstChild("HumanoidRootPart")
    local tag = hr and hr:FindFirstChild("AK_ESP")     -- old billboard tag from earlier versions
    if tag then tag:Destroy() end
end

local function ClearESP()
    for _, p in ipairs(Players:GetPlayers()) do RemoveESPFor(p) end
    pcall(function() espGui:Destroy() end)
end

local npcHl, npcHlFor = nil, nil
local function updateNpcTarget()
    local t = (isNpc(stickyP) and stickyP) or (isNpc(lockP) and lockP) or nil
    if t and not (t.Model and t.Model.Parent) then t = nil end
    if t == npcHlFor and (not t or npcHl) then return end
    if npcHl then pcall(function() npcHl:Destroy() end) npcHl = nil end
    npcHlFor = t
    if t then
        npcHl = Make("Highlight", {
            Name = "AK_NPC", Adornee = t.Model, FillColor = T.Green, FillTransparency = 0.55,
            OutlineColor = Color3.new(1, 1, 1), DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        }, t.Model)
    end
end

local function fmtNum(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    local str = tostring(n)
    local out = str:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function espColor(p)
    if Aim.Target == p.Name or (Aim.LockOn and lockP == p) or (stickyP == p and alive(p.Character)) then   -- Near Player target, or the one you picked with Switch
        return T.Green, true                                  -- current aimbot target
    end
    if Aim.Allies[p.Name] then return Color3.fromRGB(255, 170, 90), false end   -- your picked allies: light orange (green is only the aimbot target)
    local teamName = p.Team and p.Team.Name or ""
    if teamName == "Pirates" then return T.Red, false end
    if teamName == "Marines" then return Color3.fromRGB(60, 140, 255), false end
    return Color3.fromRGB(235, 236, 245), false
end

Track(RunService.RenderStepped:Connect(function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vs = cam.ViewportSize
    -- keep the Near Player target current every frame, so the green ESP always shows who the aimbot is on right now
    if Aim.Silent then pcall(nearestPlayer) end
    pcall(updateNpcTarget)
    local any2d = ESP.Box or ESP.Names or ESP.Health or ESP.Tracers or ESP.Info
    local origin
    if ESP.TracerFrom == "Center" then origin = Vector2.new(vs.X / 2, vs.Y / 2)
    elseif ESP.TracerFrom == "Top" then origin = Vector2.new(vs.X / 2, 0)
    else origin = Vector2.new(vs.X / 2, vs.Y) end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local c = p.Character
            local hr = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local show = hr ~= nil and hum ~= nil and hum.Health > 0
            local dist = 0
            if show then
                local from = (rootPart and rootPart.Parent) and rootPart.Position or cam.CFrame.Position
                dist = (hr.Position - from).Magnitude
                if dist > ESP.MaxDist then show = false end
                if ESP.HideAllies and p.Team ~= nil and p.Team == lp.Team then show = false end
            end

            -- chams (Highlight)
            local hl = c and c:FindFirstChild("AK_CHAMS")
            if show and ESP.Chams then
                if not hl then
                    hl = Make("Highlight", {
                        Name = "AK_CHAMS", Adornee = c, OutlineColor = Color3.new(1, 1, 1),
                        OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                    }, c)
                end
                if hl then
                    hl.FillColor = (espColor(p))
                    hl.FillTransparency = ESP.ChamFill
                end
            elseif hl then
                hl:Destroy()
            end

            local o = espObjs[p]
            if show and any2d then
                local top = cam:WorldToViewportPoint(hr.Position + Vector3.new(0, 3, 0))
                local bot = cam:WorldToViewportPoint(hr.Position - Vector3.new(0, 3.2, 0))
                if top.Z > 0 and bot.Z > 0 then
                    if not o then o = newEspObj(); espObjs[p] = o end
                    local col, isTarget = espColor(p)
                    local h = math.max(math.abs(bot.Y - top.Y), 8)
                    local w = h * 0.6
                    local cx = (top.X + bot.X) / 2
                    local y0 = math.min(top.Y, bot.Y)

                    o.box.Visible = ESP.Box
                    if ESP.Box then
                        o.box.Position = UDim2.fromOffset(cx - w / 2, y0)
                        o.box.Size = UDim2.fromOffset(w, h)
                        o.boxStroke.Color = col
                        o.boxStroke.Thickness = isTarget and 2.5 or 1.5
                    end

                    o.hpBg.Visible = ESP.Health
                    if ESP.Health then
                        local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        o.hpBg.Position = UDim2.fromOffset(cx - w / 2 - 6, y0)
                        o.hpBg.Size = UDim2.fromOffset(3, h)
                        o.hp.Size = UDim2.new(1, 0, frac, 0)
                        o.hp.BackgroundColor3 = Color3.fromRGB(235, 70, 70):Lerp(Color3.fromRGB(70, 220, 110), frac)
                    end

                    local showText = ESP.Names or ESP.Info
                    o.name.Visible = showText
                    o.info.Visible = showText
                    if showText then
                        o.name.Position = UDim2.fromOffset(cx, y0 - 2)
                        o.name.Text = isTarget and (p.Name .. "  [TARGET]") or p.Name
                        o.name.TextColor3 = col
                        o.info.Position = UDim2.fromOffset(cx, y0 + h + 2)
                        local pct = math.floor(hum.Health / math.max(hum.MaxHealth, 1) * 100)
                        if ESP.Info then
                            -- Level / Race come from the game's own Data folder on each player
                            local data = p:FindFirstChild("Data")
                            local lvV = data and data:FindFirstChild("Level")
                            local raceV = data and data:FindFirstChild("Race")
                            local lvl = lvV and lvV.Value
                            local race = raceV and tostring(raceV.Value) or "?"
                            if c:FindFirstChild("RaceTransformed") and c.RaceTransformed.Value == true then race = race .. " (awakened)" end
                            o.info.Size = UDim2.fromOffset(260, 28)
                            o.info.TextYAlignment = Enum.TextYAlignment.Top
                            o.info.Text = ("Lv %s  |  %s\nHP %s / %s (%d%%)  |  %dm"):format(
                                lvl and fmtNum(lvl) or "?", race, fmtNum(hum.Health), fmtNum(hum.MaxHealth), pct, math.floor(dist))
                        else
                            o.info.Size = UDim2.fromOffset(200, 14)
                            o.info.Text = ("%dm   HP %d%%"):format(math.floor(dist), pct)
                        end
                        o.info.TextColor3 = col
                    end

                    o.line.Visible = ESP.Tracers
                    if ESP.Tracers then
                        local to = Vector2.new(cx, y0 + h)
                        local d = to - origin
                        o.line.BackgroundColor3 = col
                        o.line.Size = UDim2.fromOffset(d.Magnitude, isTarget and 2 or 1.2)
                        o.line.Position = UDim2.fromOffset((to.X + origin.X) / 2, (to.Y + origin.Y) / 2)
                        o.line.Rotation = math.deg(math.atan2(d.Y, d.X))
                    end
                elseif o then
                    hideEspObj(o)
                end
            elseif o then
                hideEspObj(o)
            end
        end
    end
end))

-- ═══ AIMBOT TAB ═══════════════════════════════════════════════════════════════
local AP = Pages["Aimbot"]

-- small floating buttons (draggable, tap = toggle), synced with the hub toggles
local LockSmall, NearSmall, SwitchSmall, ChooseSmall, SetLockTog, SetNearTog, SetChooseTog

local function MakeSmallToggle(label, yOffset, getState, onTap, plain, xOffset)
    local b = Make("TextButton", {
        Size             = UDim2.new(0, 160, 0, 40),
        Position         = UDim2.new(0, 20 + (xOffset or 0), 0.5, yOffset),
        BackgroundColor3 = T.Card,
        TextColor3       = Color3.new(1, 1, 1),
        Text             = "",
        Font             = Enum.Font.GothamBold,
        TextSize         = 13,
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
        Visible          = false,
        ZIndex           = 15,
    }, ScreenGui)
    Corner(b, 8)
    Stroke(b, T.Border, 1)

    b.TextTruncate = Enum.TextTruncate.AtEnd

    local function refresh()
        local on = getState()
        local text = (type(label) == "function") and label() or label
        b.Text = plain and text or (text .. (on and ": ON" or ": OFF"))
        b.BackgroundColor3 = on and Color3.fromRGB(0, 140, 70) or T.Card
    end
    refresh()

    local dragging, moved, dragStart, startPos, activeInp = false, false, nil, nil, nil
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging, moved, activeInp = true, false, i
            dragStart, startPos = i.Position, b.Position
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i == activeInp or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = i.Position - dragStart
            if d.Magnitude > 8 then moved = true end
            if moved then
                b.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
    Track(UserInputService.InputEnded:Connect(function(i)
        if dragging and (i == activeInp or i.UserInputType == Enum.UserInputType.MouseButton1) then
            dragging, activeInp = false, nil
            if not moved then onTap() end
        end
    end))

    return {
        Refresh = refresh,
        Show = function(v) b.Visible = v; if v then refresh() end end,
    }
end

LockSmall = MakeSmallToggle("Lock On Player", -50, function() return Aim.LockOn end, function()
    if SetLockTog then SetLockTog(not Aim.LockOn) end
end)
NearSmall = MakeSmallToggle("Near Player", 0, function() return Aim.Silent end, function()
    if SetNearTog then SetNearTog(not Aim.Silent) end
end)
-- separate floating button: tap = take the closest player who is not your current target
-- floating Switch toggle: ON = silent aim on + grab the closest player right now and stay on them,
-- OFF = silent aim off. Turn it off and on again to re-grab whoever is closest at that moment.
local function setSwitch(on)
    if on then
        Aim.Hold = true
        if SetNearTog and not Aim.Silent then SetNearTog(true) end
        stickyP = nil
        pcall(nearestPlayer)                 -- picks the closest player now and remembers them
    else
        Aim.Hold = false
        stickyP = nil
        if SetNearTog and Aim.Silent then SetNearTog(false) end
    end
    if SwitchSmall then SwitchSmall.Refresh() end
end
SwitchSmall = MakeSmallToggle(function()
        return "Switch " .. (Aim.Hold and "ON" or "OFF") .. ((Aim.Hold and stickyP) and (": " .. stickyP.Name) or "")
    end, 150,
    function() return Aim.Hold end, function()
        setSwitch(not Aim.Hold)
    end, true)
ChooseSmall = MakeSmallToggle(function() return "Choose: " .. (Aim.Target or "None") end, 50,
    function() return Aim.Choose end, function()
        if SetChooseTog then SetChooseTog(not Aim.Choose) end
    end)

SectionHeader("Modes", AP)

local _lockFrame, _nearFrame
_lockFrame, SetLockTog = Toggle(AP, "Aimbot Lock On Player", "Camera locks onto target", false, function(on)
    Aim.LockOn = on
    RefreshFov()
    LockSmall.Refresh()
end)
_nearFrame, SetNearTog = Toggle(AP, "Aimbot Near Player", "Silent aim at nearest player", false, function(on)
    Aim.Silent = on
    if not on then Aim.Hold = false end
    stickyP = nil              -- a fresh start: pick the closest player now, not whoever it was stuck on last time
    NearSmall.Refresh()
    if SwitchSmall then SwitchSmall.Refresh() end
end)
local _chooseFrame
_chooseFrame, SetChooseTog = Toggle(AP, "Aimbot Choose Player", "Silent aim at selected player", false, function(on)
    Aim.Choose = on
    stickyP = nil
    ChooseSmall.Refresh()
end)

Persist.skip = true
local PlayerDD = Dropdown(AP, "Select Player", function()
    local opts = {"None"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then opts[#opts + 1] = p.Name end
    end
    return opts
end, "None", function(v)
    Aim.Target = (v ~= "None") and v or nil
    ChooseSmall.Refresh()
end)
Persist.skip = false

Track(Players.PlayerRemoving:Connect(function(p)
    RemoveESPFor(p)
    if Aim.Target == p.Name then
        Aim.Target = nil
        PlayerDD.Set("None")
        ChooseSmall.Refresh()
    end
end))

SectionHeader("Small GUI", AP)

Toggle(AP, "Lock On Player Small GUI", "Floating button, drag it anywhere", false, function(on)
    LockSmall.Show(on)
end)
Toggle(AP, "Near Player Small GUI", "Floating button, drag it anywhere", false, function(on)
    NearSmall.Show(on)
end)
Toggle(AP, "Switch Target Small GUI", "Floating ON/OFF button: ON grabs the closest player and stays on them, OFF turns the aimbot off. Turn off then on to grab whoever is closest now", false, function(on)
    SwitchSmall.Show(on)
end)
Toggle(AP, "Choose Player Small GUI", "Shows selected player, tap to toggle", false, function(on)
    ChooseSmall.Show(on)
end)

SectionHeader("Settings", AP)

Slider(AP, "Lock-On FOV", 50, 500, 180, "", function(v)
    Aim.FOV = v
    RefreshFov()
end)
Slider(AP, "Lock-On Strength", 1, 100, 70, "%", function(v)
    Aim.Smooth = v / 100
end)
Slider(AP, "Max Distance", 100, 5000, 1500, "", function(v)
    Aim.MaxDist = v
end)
Slider(AP, "Prediction", 0, 300, 0, "ms", function(v)
    Aim.Prediction = v / 1000
end)
Dropdown(AP, "Aim Part", function() return {"HumanoidRootPart", "Head"} end, "HumanoidRootPart", function(v)
    Aim.Part = v
end)
Toggle(AP, "Auto Prediction", "Leads moving targets (ping + distance)", true, function(on)
    Aim.AutoPredict = on
end)
Slider(AP, "Projectile Speed", 50, 1000, 350, "", function(v)
    Aim.ProjSpeed = v
end)
Toggle(AP, "Target Players", "Aimbot works on other players", true, function(on)
    Aim.TargetPlayers = on
    stickyP, lockP = nil, nil
end)
Toggle(AP, "Target NPCs", "Aimbot works on NPC enemies (mobs, bosses)", false, function(on)
    Aim.TargetNPCs = on
    stickyP, lockP = nil, nil
end)
Toggle(AP, "Skip Melee Moves", "OFF (default) = the aimbot works on melee moves too", false, function(on)
    Aim.SkipMelee = on
end)
Toggle(AP, "Godhuman Dash Toward Target", "Godhuman Z/C dashes go toward your target instead of where the cursor points", true, function(on)
    Chase.On = on
end)
Slider(AP, "Dash Redirect Cone", 20, 180, 70, "", function(v)
    Chase.Cone = v
end)
Slider(AP, "Dash Redirect Range", 10, 120, 60, "", function(v)
    Chase.Range = v
end)
Toggle(AP, "Aim Debug (console)", "Prints every move the silent aim changed", false, function(on)
    Aim.Debug = on
end)
Toggle(AP, "Sticky Target", "Silent aim stays on one player", true, function(on)
    Aim.Sticky = on
    stickyP = nil
end)
Toggle(AP, "Auto Switch to Closest", "Near Player always aims at whoever is closest to you", true, function(on)
    Aim.AutoClosest = on
end)
Toggle(AP, "Hold Lock", "Camera stays on its target until it dies or leaves range", true, function(on)
    Aim.HoldLock = on
    lockP = nil
end)
Toggle(AP, "Spoof Mouse", "Also redirects Mouse.Hit (tighter tracking)", true, function(on)
    Aim.SpoofMouse = on
end)
Toggle(AP, "Ignore Allies", "Aimbot skips your teammates", true, function(on)
    Aim.TeamCheck = on
end)

Button(AP, "Switch Near Target", nil, function()
    switchTarget()
    SwitchSmall.Refresh()
end)

-- Allies: pick any usernames (as many as you want), the aimbot never targets them
do
    for _, n in ipairs(Persist.cfg.AimAllies or {}) do
        if type(n) == "string" then Aim.Allies[n] = true end
    end
    local open = false
    local outer = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.Card, BorderSizePixel = 0, ClipsDescendants = true,
    }, AP)
    Corner(outer, 7)
    Stroke(outer, T.Border, 1)
    Label("Allies (aimbot skips them)", 13, T.TextPri, outer, {
        Size = UDim2.new(1, -160, 0, 18), Position = UDim2.new(0, 12, 0, 17),
    })
    local selBtn = Make("TextButton", {
        Size = UDim2.new(0, 130, 0, 26), Position = UDim2.new(1, -142, 0, 13), BackgroundColor3 = T.Panel,
        Text = "", BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 2,
    }, outer)
    Corner(selBtn, 5)
    Stroke(selBtn, T.Border, 1)
    local selLabel = Label("", 11, T.TextPri, selBtn, {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 8, 0, 0), ZIndex = 3,
    })
    Label("v", 11, T.TextSec, selBtn, {
        Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -18, 0, 0), ZIndex = 3,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local list = Make("ScrollingFrame", {
        Size = UDim2.new(1, -16, 0, 0), Position = UDim2.new(0, 8, 0, 56), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false,
    }, outer)
    Make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, list)

    local function count()
        local n = 0
        for _ in pairs(Aim.Allies) do n = n + 1 end
        return n
    end
    local function save()
        local arr = {}
        for n in pairs(Aim.Allies) do arr[#arr + 1] = n end
        table.sort(arr)
        Persist.cfg.AimAllies = arr
        Persist.note("AimAllies", arr)
        local c = count()
        selLabel.Text = c == 0 and "None" or (c .. " selected")
    end
    save()

    local function rebuild()
        local keep = list.CanvasPosition
        for _, c in ipairs(list:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        local names, seen = {}, {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= lp then names[#names + 1] = pl.Name; seen[pl.Name] = true end
        end
        for n in pairs(Aim.Allies) do          -- picked allies stay listed even while they are offline
            if not seen[n] then names[#names + 1] = n end
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)

        local rows = {}
        if count() > 0 then rows[#rows + 1] = { clear = true } end
        for _, n in ipairs(names) do rows[#rows + 1] = { name = n } end
        if #rows == 0 then rows[1] = { empty = true } end

        for i, r in ipairs(rows) do
            local on = r.name and Aim.Allies[r.name]
            local ob = Make("TextButton", {
                Size = UDim2.new(1, -4, 0, 26), BackgroundColor3 = on and T.AccentGlow or T.Panel,
                Text = "", BorderSizePixel = 0, AutoButtonColor = false, LayoutOrder = i,
            }, list)
            Corner(ob, 4)
            local text = r.clear and "Clear all" or r.empty and "No other players" or r.name
            Label(text, 11, on and T.Accent or (r.clear and T.Red or T.TextPri), ob, {
                Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 8, 0, 0),
            })
            if r.name then
                Label(on and "[x]" or "[ ]", 11, on and T.Accent or T.TextMut, ob, {
                    Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -32, 0, 0),
                    TextXAlignment = Enum.TextXAlignment.Center,
                })
            end
            ob.MouseButton1Click:Connect(function()
                if r.clear then
                    Aim.Allies = {}
                elseif r.name then
                    Aim.Allies[r.name] = (not Aim.Allies[r.name]) or nil
                else
                    return
                end
                save()
                rebuild()
            end)
        end
        local h = math.min(#rows * 28, 140)
        list.CanvasSize = UDim2.new(0, 0, 0, #rows * 28)
        list.Size = UDim2.new(1, -16, 0, h)
        list.CanvasPosition = keep
        if open then outer.Size = UDim2.new(1, 0, 0, 52 + h + 8) end
    end

    selBtn.MouseButton1Click:Connect(function()
        open = not open
        if open then
            list.Visible = true
            rebuild()
        else
            outer.Size = UDim2.new(1, 0, 0, 52)
            list.Visible = false
        end
    end)
    Track(Players.PlayerAdded:Connect(function() if open then rebuild() end end))
    Track(Players.PlayerRemoving:Connect(function() if open then task.defer(rebuild) end end))
end
Slider(AP, "Aim Cone (180 = always aim)", 20, 180, 180, "", function(v)
    Aim.Cone = v
end)
Toggle(AP, "Aim Circle (silent aim)", "Draws a circle on screen. Silent aim only picks players inside it, line it up with your crosshair", false, function(on)
    Aim.Circle = on
end)
Slider(AP, "Circle Size", 40, 450, 150, "", function(v)
    Aim.CircleR = v
end)
Slider(AP, "Circle Left / Right", -400, 400, 0, "", function(v)
    Aim.CircleDX = v
end)
Slider(AP, "Circle Up / Down", -300, 300, 0, "", function(v)
    Aim.CircleDY = v
end)
Toggle(AP, "Show FOV Circle", "Circle for lock-on range", true, function(on)
    Aim.ShowFOV = on
    RefreshFov()
end)

-- ═══ PLAYER TAB ═══════════════════════════════════════════════════════════════
local PP = Pages["Player"]
SectionHeader("Movement", PP)

local Speed = { Value = 40, PauseOnMoves = true, Debug = false, On = false, DashUntil = 0, DashMode = false, EquipUntil = 0, lastTool = nil }

-- move tracking: one entry per held move remote (true sent, false not sent yet)
local Hold = { remotes = {}, released = 0 }
local HOLD_FAILSAFE = 2   -- a hold older than this is treated as stale (release never arrived)
env.AkatsukiMove = function(on, remote)
    local key = remote or "?"
    if on then
        if Aim.Debug then print("[AkatsukiHub] move press: " .. tostring(key)) end
        Hold.remotes[key] = os.clock()
    else
        Hold.remotes[key] = nil
        Hold.released = os.clock()
    end
end
-- Godhuman dash toward target. Z/C are cursor-aimed dashes and the game streams a Vector3 every frame while they run.
-- The first fire of a stream = a Godhuman move started. For the next ~0.9s:
--   * any BodyVelocity / LinearVelocity the game puts on your root is re-pointed at the target (keeps its speed)
--   * fallback: if you are thrown forward faster than normal, that distance is walked toward the target instead
local function godhumanOn()
    local ok, v = pcall(function()
        local tool = lp.Character and lp.Character:FindFirstChildOfClass("Tool")
        return tool ~= nil and tool.ToolTip == "Melee" and (tool.Name:lower():gsub("%s", "")):find("godhuman", 1, true) ~= nil
    end)
    return ok and v
end
env.AkatsukiZFire = function(remote)
    if not Chase.On or not godhumanOn() then return end
    local now = os.clock()
    if now - Chase.lastFire > 0.15 then
        Chase.pressAt = now
        Chase.bv = nil
        Chase.gyro = nil
        Chase.bpos = nil
        if Aim.Debug then print("[AkatsukiHub] Godhuman move stream started on " .. tostring(remote and remote.Name)) end
    end
    Chase.lastFire = now
end
-- The game re-writes its dash objects every frame, so we write AFTER it (render step last + Stepped + Heartbeat).
local function chaseSaid(kind)
    if Aim.Debug and Chase.said[kind] ~= Chase.pressAt then
        Chase.said[kind] = Chase.pressAt
        print("[AkatsukiHub] re-aimed " .. kind .. " toward target")
    end
end
local function chaseApply()
    if not Chase.On then return false end
    local root = rootPart
    if not (root and root.Parent) then return false end
    if os.clock() - Chase.pressAt > 1 then return false end
    local t = currentAimPos()
    if not t then return false end
    local d = t - root.Position                      -- full 3D, so a target that jumped is still tracked
    if d.Magnitude < 5 or d.Magnitude > Chase.Range then return false end
    local dirv = d.Unit
    local needUp = math.abs(d.Y) > 3
    local did = false
    -- decide once per move: if the dash the GAME made points well away from the target, you are steering on purpose -> leave it
    if Chase.decided ~= Chase.pressAt then
        local cb = Chase.bv
        if cb and cb.Parent then
            local v
            if cb:IsA("BodyVelocity") then v = cb.Velocity elseif cb:IsA("LinearVelocity") then v = cb.VectorVelocity end
            if v and Vector3.new(v.X, 0, v.Z).Magnitude > 20 then
                local a = Vector3.new(v.X, 0, v.Z).Unit
                local bflat = Vector3.new(dirv.X, 0, dirv.Z)
                local ang = 0
                if bflat.Magnitude > 0.01 then ang = math.deg(math.acos(math.clamp(a:Dot(bflat.Unit), -1, 1))) end
                Chase.decided = Chase.pressAt
                Chase.allow = Chase.Cone >= 180 or ang <= Chase.Cone
                if Aim.Debug then
                    print(string.format("[AkatsukiHub] dash is %.0f deg off the target -> %s", ang, Chase.allow and "redirecting" or "left alone (you steered)"))
                end
            end
        end
        if Chase.decided ~= Chase.pressAt then return false end
    end
    if not Chase.allow then return false end
    local c = Chase.bv
    if c and c.Parent then
        pcall(function()
            if c:IsA("BodyVelocity") then
                local v = c.Velocity
                local sp = Vector3.new(v.X, 0, v.Z).Magnitude
                if sp > 20 then
                    if needUp then
                        local mf = c.MaxForce
                        if mf.Y < mf.X then c.MaxForce = Vector3.new(mf.X, mf.X, mf.Z) end
                    end
                    c.Velocity = dirv * sp
                    did = true
                    chaseSaid("BodyVelocity")
                end
            elseif c:IsA("LinearVelocity") then
                local v = c.VectorVelocity
                local sp = Vector3.new(v.X, 0, v.Z).Magnitude
                if sp > 20 then c.VectorVelocity = dirv * sp did = true chaseSaid("LinearVelocity") end
            end
        end)
    end
    local g = Chase.gyro
    if g and g.Parent then
        pcall(function()
            g.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(dirv.X, 0, dirv.Z) + Vector3.new(0, 0.001, 0))
            chaseSaid("BodyGyro")
        end)
    end
    local bp = Chase.bpos
    if bp and bp.Parent then
        pcall(function()
            local off = bp.Position - root.Position
            local L = off.Magnitude
            if needUp then
                -- the move's BodyPosition holds your height; let go of it so the dash can climb / drop
                local mf = bp.MaxForce
                if mf.Y > 0 then bp.MaxForce = Vector3.new(mf.X, 0, mf.Z) end
                chaseSaid("BodyPosition (height released)")
            end
            if L > 3 then
                bp.Position = root.Position + dirv * L
                did = true
                chaseSaid("BodyPosition")
            end
        end)
    end
    return did
end
pcall(function() RunService:UnbindFromRenderStep("AkatsukiChase") end)
RunService:BindToRenderStep("AkatsukiChase", Enum.RenderPriority.Last.Value, function() pcall(chaseApply) end)
Track(RunService.Stepped:Connect(function() pcall(chaseApply) end))
Track(RunService.Heartbeat:Connect(function(dt)
    local root = rootPart
    if not (root and root.Parent) then Chase.prev = nil return end
    if Chase.root ~= root then
        if Chase.conn then pcall(function() Chase.conn:Disconnect() end) end
        Chase.root = root
        Chase.conn = root.ChildAdded:Connect(function(c)
            if os.clock() - Chase.pressAt > 1 or c.Name == "AK_BV" then return end
            if Aim.Debug then print("[AkatsukiHub] root got " .. c.ClassName .. " '" .. c.Name .. "' during Godhuman move") end
            if c:IsA("BodyVelocity") or c:IsA("LinearVelocity") then Chase.bv = c
            elseif c:IsA("BodyGyro") then Chase.gyro = c
            elseif c:IsA("BodyPosition") then Chase.bpos = c end
        end)
    end
    local pos = root.Position
    local prev = Chase.prev
    Chase.prev = pos
    if not Chase.On or dt <= 0 then return end
    if os.clock() - Chase.pressAt > 1 then return end
    local t = currentAimPos()
    local d = t and (t - pos) or nil
    if Aim.Debug and Chase.reported ~= Chase.pressAt then
        Chase.reported = Chase.pressAt
        if not t then print("[AkatsukiHub] Godhuman move: NO aim target -> not redirected")
        elseif d.Magnitude > Chase.Range then print(string.format("[AkatsukiHub] Godhuman move: target %.0f studs, range %d -> too far", d.Magnitude, Chase.Range))
        elseif d.Magnitude < 5 then print("[AkatsukiHub] Godhuman move: target already on you")
        else print(string.format("[AkatsukiHub] Godhuman move: target %.0f studs (%+.0f height) -> redirecting", d.Magnitude, d.Y)) end
    end
    if not d or d.Magnitude < 5 or d.Magnitude > Chase.Range then return end
    if chaseApply() then return end
    if Chase.decided == Chase.pressAt and not Chase.allow then return end
    if not prev then return end
    local dirv = d.Unit
    local flat = Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z)
    local sp = flat.Magnitude / dt
    local need = math.max(60, (Speed.On and Speed.Value or 0) * 1.8)
    if sp < need then return end
    if flat.Magnitude > 0.01 and flat.Unit:Dot(dirv) > 0.97 then return end
    local dflat = Vector3.new(dirv.X, 0, dirv.Z)
    if Chase.Cone < 180 and flat.Magnitude > 0.01 and dflat.Magnitude > 0.01
        and math.deg(math.acos(math.clamp(flat.Unit:Dot(dflat.Unit), -1, 1))) > Chase.Cone then return end
    local mag = math.min(flat.Magnitude, d.Magnitude - 4)
    root.CFrame = root.CFrame + (dirv * mag - flat)
    Chase.prev = root.Position
    if Aim.Debug then print(string.format("[AkatsukiHub] dash moved toward target (%.0f studs/s)", sp)) end
end))
local function skillBusy()
    local now = os.clock()
    for r, t in pairs(Hold.remotes) do
        if now - t < HOLD_FAILSAFE then return true, "move held" end
        Hold.remotes[r] = nil
    end
    if now - Hold.released < 0.2 then return true, "move just released" end
    return false
end

-- states where the speed hack must stay out of the way
local SPEED_PAUSE = {
    [Enum.HumanoidStateType.Dead]             = true,
    [Enum.HumanoidStateType.FallingDown]      = true,
    [Enum.HumanoidStateType.Ragdoll]          = true,
    [Enum.HumanoidStateType.Physics]          = true,
    [Enum.HumanoidStateType.Seated]           = true,
    [Enum.HumanoidStateType.PlatformStanding] = true,
    [Enum.HumanoidStateType.Climbing]         = true,
}

-- a game-made mover on the root (dash / skill / knockback) pauses the hack, but only
-- if it actually pushes (force > 0 / enabled) and only for 2.5s, so leftovers can't pause it forever
local moverSeen = setmetatable({}, { __mode = "k" })
local function foreignMover()
    local now = os.clock()
    for _, c in ipairs(rootPart:GetChildren()) do
        if c.Name ~= "AK_BV" then
            local active = false
            if c:IsA("BodyVelocity") or c:IsA("BodyPosition") then
                active = c.MaxForce.Magnitude > 1
            elseif c:IsA("LinearVelocity") or c:IsA("AlignPosition") or c:IsA("VectorForce") then
                active = c.Enabled
            end
            if active then
                local t0 = moverSeen[c]
                if not t0 then moverSeen[c] = now; t0 = now end
                if now - t0 < 0.6 then return c.ClassName .. ":" .. c.Name end
            end
        end
    end
    return nil
end

-- why the speed hack is currently off (nil = running)
local function pauseReason()
    if humanoid.Health <= 0 then return "dead" end
    if humanoid.Sit then return "seated" end
    local st = humanoid:GetState()
    if SPEED_PAUSE[st] then return "state " .. tostring(st) end
    -- switching weapon / fruit / style: the game fires equip remotes that look like held moves; ignore them
    local tool = humanoid.Parent and humanoid.Parent:FindFirstChildOfClass("Tool")
    if tool ~= Speed.lastTool then
        Speed.lastTool = tool
        Hold.remotes = {}
        Hold.released = 0
        Speed.EquipUntil = os.clock() + 0.8
    end
    local equipping = os.clock() < Speed.EquipUntil
    if os.clock() < Speed.DashUntil then return "dash" end   -- the game's dash runs untouched, then Custom Dash boosts it
    local m = (not equipping) and foreignMover()
    if m then return "mover " .. m end
    if Speed.PauseOnMoves and not equipping then
        local busy, why = skillBusy()
        if busy then return why end
    end
    if humanoid.WalkSpeed < 2 then return "walkspeed " .. tostring(humanoid.WalkSpeed) end
    return nil
end

Toggle(PP, "Speed Hack", "Pauses itself during skills / stuns", false, function(on)
    Speed.On = on
    DisconnectKey("speed")
    local wasMoving = false
    local lastReason = nil
    local cur = 16                      -- current speed: ramps up like a real run instead of snapping to full
    local function syncAnim(speed) end   -- leg animation is handled by "Match Leg Animation To Speed" (two writers fought each other)
    local function dropBV()
        local bv = rootPart and rootPart:FindFirstChild("AK_BV")
        if bv then bv:Destroy() end
    end

    if on then
        State.Connections["speed"] = RunService.Heartbeat:Connect(function(dt)
            if not (humanoid and rootPart and rootPart.Parent) then wasMoving = false return end

            local dir = humanoid.MoveDirection
            local reason = pauseReason()
            if Speed.Debug and reason ~= lastReason then
                print("[AkatsukiHub] speed " .. (reason and ("PAUSED: " .. reason) or "active"))
            end
            lastReason = reason

            -- the game's dash is running: keep the velocity lock object but switch its force off (no destroy / recreate,
            -- so there is no hitch); it comes back on the very next frame after the dash, at full speed
            if reason == "dash" then
                local bvd = rootPart:FindFirstChild("AK_BV")
                if bvd then bvd.MaxForce = Vector3.zero end
                wasMoving = false
                return
            end

            if reason or dir.Magnitude < 0.05 then
                dropBV()
                if wasMoving and not reason then
                    -- released the stick: kill leftover horizontal speed so you don't slide
                    local v = rootPart.AssemblyLinearVelocity
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
                end
                wasMoving = false
                if not reason or (reason ~= "dash" and not reason:find("^mover")) then cur = 16 end   -- after a dash the speed hack resumes at full speed instantly
                return
            end

            -- ramp toward the target speed (about 0.15s to full), like a speed buff in game
            cur = cur + (Speed.Value - cur) * math.min(1, dt * 9)

            local bv = rootPart:FindFirstChild("AK_BV")
            if not bv then
                bv = Make("BodyVelocity", {
                    Name     = "AK_BV",
                    MaxForce = Vector3.new(1e6, 0, 1e6),
                    Velocity = Vector3.new(0, 0, 0),
                    P        = 1e4,
                }, rootPart)
            end
            if bv then
                bv.MaxForce = Vector3.new(1e6, 0, 1e6)
                bv.Velocity = dir.Unit * cur
                wasMoving = true
                syncAnim(cur)
            end
        end)
    else
        dropBV()
    end
end)
Slider(PP, "Player Speed", 16, 300, 40, "", function(v)
    Speed.Value = v
end)

-- Custom dash. Two ways to catch the game's dash, whichever it uses:
--   1) a velocity mover (BodyVelocity / LinearVelocity) added anywhere on your character: its velocity is scaled
--   2) a sudden horizontal speed jump in the direction you are moving / facing: that speed is kept for 0.3s, scaled
-- Both stay out of the way while a move is held, so skills are not touched.
local Dash = { On = false, Mult = 1.5, Debug = false }
local dashSeen = setmetatable({}, { __mode = "k" })
local movers = setmetatable({}, { __mode = "k" })
local boundChar, boundConn = nil, nil
local prevSpeed, boost = 0, nil
local MOVER = { BodyVelocity = true, LinearVelocity = true }

local function bindDashChar(c)
    if boundConn then pcall(function() boundConn:Disconnect() end) end
    boundChar = c
    movers = setmetatable({}, { __mode = "k" })
    if not c then return end
    for _, d in ipairs(c:GetDescendants()) do
        if MOVER[d.ClassName] and d.Name ~= "AK_BV" then movers[d] = true end
    end
    boundConn = c.DescendantAdded:Connect(function(d)
        if MOVER[d.ClassName] and d.Name ~= "AK_BV" then
            movers[d] = true
            if Dash.Debug then
                print(("[AkatsukiHub] new mover %s '%s' under %s"):format(d.ClassName, d.Name, d.Parent and d.Parent.Name or "?"))
            end
        end
    end)
end

local function playingDash()
    local found
    pcall(function()
        for _, tr in ipairs(humanoid:GetPlayingAnimationTracks()) do
            local n = tr.Name:lower()
            if n:find("dash", 1, true) or n:find("dodge", 1, true) or n:find("roll", 1, true) then found = tr.Name end
        end
    end)
    return found
end

local prevPos = nil
local dashing = false
local prevAnim, animStart = nil, 0
local baseline, dashUntil, warm = 0, 0, 0     -- baseline = your normal movement speed (smoothed)
Track(RunService.Heartbeat:Connect(function(dt)
    if not Dash.On or not (rootPart and rootPart.Parent and humanoid) then prevSpeed = 0; boost = nil; prevPos = nil; dashing = false; baseline = 0; warm = os.clock() + 1 return end
    if lp.Character ~= boundChar then bindDashChar(lp.Character) end
    local now = os.clock()
    -- dash animation playing: step the speed hack aside so it cannot override the dash velocity
    local dashAnim = playingDash()
    if dashAnim and not prevAnim then animStart = now end
    prevAnim = dashAnim
    if dashAnim and now - animStart < 0.12 then Speed.DashUntil = now + 0.08 end   -- only the start of the anim, not its whole length
    if Dash.Debug then
        pcall(function()
            for _, tr in ipairs(humanoid:GetPlayingAnimationTracks()) do
                if not dashSeen[tr] then
                    dashSeen[tr] = true
                    print("[AkatsukiHub] anim playing: " .. tr.Name)
                end
            end
        end)
    end
    local busy = next(Hold.remotes) ~= nil or now - Hold.released < 0.4
    local pos = rootPart.Position
    -- real movement this frame (works for velocity dashes AND dashes that move the character by CFrame)
    local delta = prevPos and Vector3.new(pos.X - prevPos.X, 0, pos.Z - prevPos.Z) or Vector3.zero
    if dt > 0.1 then prevPos = pos; return end   -- lag spike: not a real dash
    local dsp = dt > 0 and delta.Magnitude / dt or 0
    prevPos = pos
    local v = rootPart.AssemblyLinearVelocity
    local flat = Vector3.new(v.X, 0, v.Z)
    local sp = math.max(flat.Magnitude, dsp)

    if busy then boost = nil; prevSpeed = sp; dashing = false return end

    -- (movers are only logged by Dash Debug, never changed: the game also uses them for normal running)

    -- 2) displacement boost. A dash is a sudden SPIKE above your normal movement speed (running, speed hack, sprint
    --    all count as normal), so steady running is never touched. While the spike lasts, (mult - 1) times each
    --    step is added on top.
    local want = humanoid.MoveDirection
    local function aligned(dir)
        if want.Magnitude > 0.05 then return dir:Dot(want.Unit) > 0.3 end
        return dir:Dot(rootPart.CFrame.LookVector) > 0.3
    end
    if not dashing then
        baseline = baseline + (dsp - baseline) * math.min(1, dt * 4)
        -- normal speed comes from WalkSpeed / Speed Hack, NOT from the lagging average (that made run-start look like a dash)
        local normal = math.max(humanoid.WalkSpeed, Speed.On and Speed.Value or 0, baseline)
        -- the low trigger only applies in the first 0.35s after a dash-type animation STARTS; a dash/roll-named
        -- animation that is merely still playing must not make normal speed-hack running look like a dash
        local animName = (dashAnim and now - animStart < 0.35) and dashAnim or nil
        local need
        if animName then
            need = math.max(humanoid.WalkSpeed * 1.4, 28)      -- dash anim playing + speed hack stepped aside
        else
            need = math.max(normal * 2.4, 55)
        end
        -- not a dash: a Godhuman move is running (its own dash), or the jump is a teleport / portal (huge in one frame)
        local moveRunning = now - Chase.lastFire < 1.2 or now - Chase.pressAt < 1.2
        if now > warm and dsp > need and dsp < 300 and not moveRunning and delta.Magnitude > 0 and aligned(delta.Unit) then
            dashing = true
            dashUntil = now + 0.45
            if Dash.Debug then
                print(("[AkatsukiHub] dash detected: %.0f studs/s (normal %.0f) x%.2f  anim=%s"):format(dsp, baseline, Dash.Mult, tostring(playingDash())))
            end
        end
    end
    if dashing then
        if now < dashUntil and dsp < 300 and not (now - Chase.lastFire < 1.2) and dsp > math.max(26, (dashAnim and humanoid.WalkSpeed or math.max(humanoid.WalkSpeed, Speed.On and Speed.Value or 0)) * 1.3) and delta.Magnitude > 0 and aligned(delta.Unit) then
            rootPart.CFrame = rootPart.CFrame + delta * (Dash.Mult - 1)
            prevPos = rootPart.Position
            Speed.DashUntil = now + 0.06      -- keep the speed hack out of the way only while the dash is really moving
        else
            dashing = false
        end
    end
    prevSpeed = sp
end))
-- Leg animation sync: the speed hack moves you with a BodyVelocity, but the game still plays the run animation at your
-- WalkSpeed pace, so the legs look slow. While Speed Hack is on, the run / walk animation is sped up by the same ratio.
local AnimSync = { On = true, rec = setmetatable({}, { __mode = "k" }) }
Track(RunService.Heartbeat:Connect(function()
    local hum, root = humanoid, rootPart
    if not (hum and root and root.Parent) then return end
    local ratio = 1
    if AnimSync.On and Speed.On and hum.MoveDirection.Magnitude > 0.1 then
        local v = root.AssemblyLinearVelocity
        local sp = Vector3.new(v.X, 0, v.Z).Magnitude
        ratio = math.clamp(sp / math.max(hum.WalkSpeed, 8), 1, 4)
    end
    local tracks
    pcall(function() tracks = hum:GetPlayingAnimationTracks() end)
    if not tracks then return end
    for _, tr in ipairs(tracks) do
        local n = tr.Name:lower()
        if n:find("run", 1, true) or n:find("walk", 1, true) or n:find("jog", 1, true) or n:find("sprint", 1, true) then
            local r = AnimSync.rec[tr]
            if not r then r = { game = tr.Speed, set = tr.Speed } AnimSync.rec[tr] = r end
            if math.abs(tr.Speed - r.set) > 0.001 then r.game = tr.Speed end    -- the game changed it: that is the new base
            local want = r.game * ratio
            if math.abs(tr.Speed - want) > 0.001 then pcall(function() tr:AdjustSpeed(want) end) end
            r.set = want
        end
    end
end))
Toggle(PP, "Match Leg Animation To Speed", "Run animation plays as fast as you really move while Speed Hack is on", true, function(on)
    AnimSync.On = on
end)
Toggle(PP, "Custom Dash Speed", "Makes the game's dash faster / farther", false, function(on)
    Dash.On = on
    Speed.DashMode = on
end)
Slider(PP, "Dash Speed", 100, 500, 150, "%", function(v)
    Dash.Mult = v / 100
end)
Toggle(PP, "Dash Debug (console)", "Prints when a dash gets boosted", false, function(on)
    Dash.Debug = on
end)
Toggle(PP, "Pause While Using Moves", "Off = speed hack never pauses for held moves", true, function(on)
    Speed.PauseOnMoves = on
end)
Toggle(PP, "Speed Debug (console)", "Prints why the speed hack paused", false, function(on)
    Speed.Debug = on
end)
Toggle(PP, "Infinite Jump", "Jump again mid-air", false, function(on)
    DisconnectKey("infJump")
    if on then
        State.Connections["infJump"] = UserInputService.JumpRequest:Connect(function()
            if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end)
Toggle(PP, "No Clip", "Walk through walls", false, function(on)
    DisconnectKey("noclip")
    if on then
        State.Connections["noclip"] = RunService.Stepped:Connect(function()
            for _, p in ipairs(character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    else
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end)

SectionHeader("Defense", PP)

-- stun flags the game keeps on the character (Value objects / attributes)
local function isStunName(n)
    n = n:lower()
    return n:find("stun", 1, true) ~= nil or n == "ragdoll" or n == "frozen"
        or n == "freeze" or n == "paralyzed" or n == "knocked"
end

local function stunHolders()
    local list = { character }
    local wc = workspace:FindFirstChild("Characters")
    local m = wc and wc:FindFirstChild(lp.Name)
    if m and m ~= character then list[#list + 1] = m end
    return list
end

local function clearStun()
    if not (humanoid and humanoid.Parent) then return end

    for _, holder in ipairs(stunHolders()) do
        for _, v in ipairs(holder:GetChildren()) do
            if isStunName(v.Name) then
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    if v.Value ~= 0 then v.Value = 0 end
                elseif v:IsA("BoolValue") then
                    if v.Value then v.Value = false end
                end
            end
        end
        for k, val in pairs(holder:GetAttributes()) do
            if isStunName(k) then
                if type(val) == "number" and val ~= 0 then holder:SetAttribute(k, 0)
                elseif type(val) == "boolean" and val then holder:SetAttribute(k, false) end
            end
        end
    end

    -- client side: get back up instead of staying ragdolled / platform-stood
    local st = humanoid:GetState()
    if st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Ragdoll then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if humanoid.PlatformStand then humanoid.PlatformStand = false end
end

Toggle(PP, "Anti Stun", "Clears stun / ragdoll flags every frame", false, function(on)
    DisconnectKey("antistun")
    if on then
        State.Connections["antistun"] = RunService.Heartbeat:Connect(function()
            pcall(clearStun)
        end)
    end
end)

Button(PP, "Print Stun Info (console)", T.AccentDark, function()
    print("[AkatsukiHub] state:", humanoid and humanoid:GetState(), "| WalkSpeed:", humanoid and humanoid.WalkSpeed)
    for _, holder in ipairs(stunHolders()) do
        print("[AkatsukiHub] holder:", holder:GetFullName())
        for _, v in ipairs(holder:GetChildren()) do
            if v:IsA("ValueBase") then
                print("   ", v.ClassName, v.Name, "=", v.Value)
            end
        end
        for k, val in pairs(holder:GetAttributes()) do
            print("    attr", k, "=", val)
        end
    end
end)

SectionHeader("Utility", PP)

Toggle(PP, "Anti-AFK", "Prevent idle kick", false, function(on)
    DisconnectKey("antiafk")
    if on then
        State.Connections["antiafk"] = lp.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end)
    end
end)

-- ═══ REMOVE SHAKES ════════════════════════════════════════════════════════════
-- Turns the game's camera shake into nothing: the shaker modules' shake functions are replaced with no-ops
-- (restored when you switch it off) and the camera offset is zeroed every frame.
local ShakeCleanup
do
    local RS = game:GetService("ReplicatedStorage")
    local NAMES = { "Shake", "ShakeOnce", "ShakeSustain", "ShakeSustained", "StartShake", "ShakeFromInstance", "ShakeOnceFromInstance" }
    local patched, scanning = {}, false
    local dummy = setmetatable({}, { __index = function() return function() return nil end end })
    local function noop() return dummy end

    local function patchTable(tbl)
        pcall(function() if setreadonly then setreadonly(tbl, false) end end)
        for _, n in ipairs(NAMES) do
            local f = rawget(tbl, n)
            if type(f) == "function" and f ~= noop then
                local ok = pcall(rawset, tbl, n, noop)
                if ok then patched[#patched + 1] = { tbl, n, f } end
            end
        end
    end
    local function scan()
        for _, m in ipairs(RS:GetDescendants()) do
            if m:IsA("ModuleScript") and m.Name:lower():find("shak", 1, true) then
                local ok, t = pcall(require, m)
                if ok and type(t) == "table" then
                    patchTable(t)
                    local mt = getmetatable(t)
                    if type(mt) == "table" and type(mt.__index) == "table" then patchTable(mt.__index) end
                end
            end
        end
    end
    local function restore()
        for _, e in ipairs(patched) do pcall(rawset, e[1], e[2], e[3]) end
        patched = {}
    end
    local function stop()
        scanning = false
        pcall(function() RunService:UnbindFromRenderStep("AkatsukiNoShake") end)
        restore()
    end
    ShakeCleanup = stop

    Toggle(PP, "Remove Shakes", "No camera shake from skills, hits or explosions", false, function(on)
        stop()
        if not on then return end
        scanning = true
        pcall(scan)
        RunService:BindToRenderStep("AkatsukiNoShake", Enum.RenderPriority.Last.Value, function()
            if humanoid and humanoid.Parent and humanoid.CameraOffset.Magnitude > 0 then
                humanoid.CameraOffset = Vector3.zero
            end
        end)
        task.spawn(function()
            while scanning do                       -- shaker modules that load later get patched too
                task.wait(5)
                if scanning then pcall(scan) end
            end
        end)
    end)
end

Persist.skip = true   -- macro blocks have their own save / load
-- ═══ MACRO TAB ════════════════════════════════════════════════════════════════
-- 10 blocks, played top to bottom. Each block: pick a weapon type (switched to automatically),
-- a skill key, how long to hold it and how long to wait before the next block.
-- Delay 0 + Hold 0 on neighbouring blocks = both moves go off in the same instant.
local MacroCleanup
do
local MPg = Pages["Macro"]
local MACRO_DIR = "AkatsukiHub/MacroBlocks"
local HAS_FS = (writefile and readfile and isfolder and makefolder and listfiles) ~= nil

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local WEAPONS = { "None", "Melee", "Sword", "Fruit", "Gun" }
local SKILLS = { "None", "Z", "X", "C", "V", "F" }
local COUNT = 10

local B = {}
for i = 1, COUNT do
    B[i] = { weapon = "None", skill = (i == 1) and "Z" or "None" }
end
local run = { on = false, id = 0, loop = false }
local saved = {}
local SetRunTog, MacroSmall, ConfigDD, nameBox

-- ── pop-up message ───────────────────────────────────────────────────────────
local toast
local function notify(text)
    if not toast then
        toast = Make("TextLabel", {
            Size = UDim2.new(0, 340, 0, 30), Position = UDim2.new(0.5, -170, 0, 70),
            BackgroundColor3 = T.Card, TextColor3 = T.TextPri, Font = Enum.Font.GothamMedium,
            TextSize = 12, BorderSizePixel = 0, ZIndex = 30, Visible = false, TextWrapped = true,
        }, ScreenGui)
        Corner(toast, 8)
        Stroke(toast, T.Border, 1)
    end
    toast.Text = text
    toast.Visible = true
    task.delay(3, function() if toast and toast.Text == text then toast.Visible = false end end)
end

-- ── input ────────────────────────────────────────────────────────────────────
local function pressKey(k, down)
    local ok = false
    if VIM then
        ok = pcall(function() VIM:SendKeyEvent(down, Enum.KeyCode[k], false, game) end)
    end
    if not ok then                                    -- executors with keypress / keyrelease (virtual-key code = ascii capital)
        local f = down and keypress or keyrelease
        if f then pcall(f, string.byte(k)) end
    end
end

local TYPE_MATCH = {
    Melee = function(tip) return tip == "melee" end,
    Sword = function(tip) return tip == "sword" end,
    Gun   = function(tip) return tip == "gun" end,
    Fruit = function(tip) return tip:find("fruit", 1, true) ~= nil end,
}

-- takes out the first tool of that type (Blox Fruits stores the type in Tool.ToolTip)
local function equipType(wtype)
    local match = TYPE_MATCH[wtype]
    if not match then return end
    local c = lp.Character
    local function isType(t) return t:IsA("Tool") and match((t.ToolTip or ""):lower()) end
    for _, t in ipairs(c and c:GetChildren() or {}) do
        if isType(t) then return end                  -- already in hand
    end
    local bp = lp:FindFirstChildOfClass("Backpack")
    for _, t in ipairs(bp and bp:GetChildren() or {}) do
        if isType(t) then
            if humanoid and humanoid.Parent then
                pcall(function() humanoid:EquipTool(t) end)
                task.wait(0.25)
            end
            return
        end
    end
end

local function waitAlive(sec, alive)
    local t0 = os.clock()
    while os.clock() - t0 < sec and alive() do RunService.Heartbeat:Wait() end
end

local function runBlocks(alive)
    for i = 1, COUNT do
        if not alive() then return end
        local b = B[i]
        if b.skill ~= "None" then
            if b.weapon ~= "None" then equipType(b.weapon) end
            if not alive() then return end
            pressKey(b.skill, true)
            local hold = tonumber(b.hBox.Text) or 0
            if hold > 0 then waitAlive(hold, alive) else RunService.Heartbeat:Wait() end
            pressKey(b.skill, false)                  -- always let go, even when stopped mid-hold
            local d = tonumber(b.dBox.Text) or 0
            if d > 0 then waitAlive(d, alive) end
        end
    end
end

local function refreshSmall() if MacroSmall then MacroSmall.Refresh() end end

local function stopMacro()
    run.on = false
    run.id = run.id + 1
    refreshSmall()
end

local function startMacro()
    if run.on then return end
    local active = 0
    for i = 1, COUNT do if B[i].skill ~= "None" then active = active + 1 end end
    if active == 0 then
        notify("Set a Skill on at least one block first")
        if SetRunTog then SetRunTog(false) end
        return
    end
    if not VIM and not (keypress and keyrelease) then
        notify("This executor can't press keys (no VirtualInputManager / keypress)")
    end
    run.id = run.id + 1
    local id = run.id
    run.on = true
    refreshSmall()
    task.spawn(function()
        local function alive() return run.on and run.id == id end
        repeat
            runBlocks(alive)
            if run.loop and alive() then task.wait(0.05) end
        until not (run.loop and alive())
        if run.id == id then
            run.on = false
            if SetRunTog then SetRunTog(false) end
            refreshSmall()
            notify("Macro finished")
        end
    end)
end

-- ── configs ──────────────────────────────────────────────────────────────────
local function cleanName(x)
    x = tostring(x or ""):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return x:sub(1, 24)
end

local function ensureDir()
    if not HAS_FS then return false end
    pcall(function()
        if not isfolder("AkatsukiHub") then makefolder("AkatsukiHub") end
        if not isfolder(MACRO_DIR) then makefolder(MACRO_DIR) end
    end)
    return true
end

local function snapshot()
    local out = { loop = run.loop, b = {} }
    for i = 1, COUNT do
        out.b[i] = { w = B[i].weapon, s = B[i].skill, h = B[i].hBox.Text, d = B[i].dBox.Text }
    end
    return out
end

local function inList(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function validConfig(c)
    if type(c) ~= "table" or type(c.b) ~= "table" then return nil end
    local out = { loop = c.loop == true, b = {} }
    for i = 1, COUNT do
        local x = c.b[i]
        if type(x) ~= "table" then x = {} end
        out.b[i] = {
            w = inList(WEAPONS, x.w) and x.w or "None",
            s = inList(SKILLS, x.s) and x.s or "None",
            h = tostring(tonumber(x.h) or 0),
            d = tostring(tonumber(x.d) or 0),
        }
    end
    return out
end

local function applyConfig(c)
    for i = 1, COUNT do
        local x = c.b[i]
        B[i].weapon, B[i].skill = x.w, x.s
        B[i].wDD.Set(x.w)
        B[i].sDD.Set(x.s)
        B[i].hBox.Text = x.h
        B[i].dBox.Text = x.d
    end
    run.loop = c.loop
end

local function configNames()
    local t = { "None" }
    local names = {}
    for n in pairs(saved) do names[#names + 1] = n end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    for _, n in ipairs(names) do t[#t + 1] = n end
    return t
end

local function loadFromDisk()
    if not ensureDir() then return end
    pcall(function()
        for _, path in ipairs(listfiles(MACRO_DIR)) do
            local name = tostring(path):match("([^/\\]+)%.json$")
            if name then
                local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
                local c = ok and validConfig(data)
                if c then saved[name] = c end
            end
        end
    end)
end
loadFromDisk()

-- ── UI ───────────────────────────────────────────────────────────────────────
SectionHeader("Macro", MPg)

Label(VIM and "Blocks play top to bottom. Weapon switches automatically, then the skill key is pressed."
    or "VirtualInputManager not found - using keypress fallback if your executor has it.", 11, T.TextMut, MPg, {
    Size = UDim2.new(1, 0, 0, 30),
})

local _runFrame
_runFrame, SetRunTog = Toggle(MPg, "Run Macro", "Plays all blocks that have a skill set", false, function(on)
    if on then startMacro() else stopMacro() end
end)
Toggle(MPg, "Loop", "Repeat the whole macro until you switch it off", false, function(on) run.loop = on end)

MacroSmall = MakeSmallToggle("Macro", 100, function() return run.on end, function()
    if run.on then stopMacro() if SetRunTog then SetRunTog(false) end
    else if SetRunTog then SetRunTog(true) end end
end)
Toggle(MPg, "Macro Small GUI", "Floating run button, drag it anywhere", false, function(on) MacroSmall.Show(on) end)

SectionHeader("Saved Configs (kept after you leave the game)", MPg)

nameBox = TextInput(MPg, "Config name", "", nil)
nameBox.PlaceholderText = "type a name, then Save"
Button(MPg, "Save Config", T.AccentDark, function()
    local name = cleanName(nameBox.Text)
    if name == "" then notify("Type a config name first") return end
    local c = validConfig(snapshot())
    saved[name] = c
    local msg = "Saved '" .. name .. "'"
    if HAS_FS then
        ensureDir()
        local ok = pcall(function() writefile(MACRO_DIR .. "/" .. name .. ".json", HttpService:JSONEncode(c)) end)
        if not ok then msg = msg .. " (file write failed, kept for this session)" end
    else
        msg = msg .. " (this session only)"
    end
    nameBox.Text = name
    ConfigDD.Set(name)
    Persist.cfg.MacroLast = name
    Persist.note("MacroLast", name)
    notify(msg)
end)
ConfigDD = Dropdown(MPg, "Load Config", configNames, "None", function(v)
    if v ~= "None" and saved[v] then
        applyConfig(saved[v])
        nameBox.Text = v
        Persist.cfg.MacroLast = v
        Persist.note("MacroLast", v)
        notify("Loaded '" .. v .. "'")
    end
end)
Button(MPg, "Delete Config", T.Red, function()
    local name = cleanName(nameBox.Text)
    if not saved[name] then notify("No config named '" .. name .. "'") return end
    saved[name] = nil
    if HAS_FS and delfile then pcall(delfile, MACRO_DIR .. "/" .. name .. ".json") end
    ConfigDD.Set("None")
    notify("Deleted '" .. name .. "'")
end)
Button(MPg, "Clear All Blocks", T.Red, function()
    for i = 1, COUNT do
        B[i].weapon, B[i].skill = "None", "None"
        B[i].wDD.Set("None")
        B[i].sDD.Set("None")
        B[i].hBox.Text = "0"
        B[i].dBox.Text = "0.5"
    end
    notify("Cleared")
end)

for i = 1, COUNT do
    SectionHeader("Block " .. i, MPg)
    B[i].wDD = Dropdown(MPg, "Weapon", function() return WEAPONS end, B[i].weapon, function(v) B[i].weapon = v end)
    B[i].sDD = Dropdown(MPg, "Skill / Action", function() return SKILLS end, B[i].skill, function(v) B[i].skill = v end)
    B[i].hBox = TextInput(MPg, "Hold Duration", "0", nil)
    B[i].hBox.PlaceholderText = "0 = instant"
    B[i].dBox = TextInput(MPg, "Delay After Skill", "0.5", nil)
    B[i].dBox.PlaceholderText = "seconds"
end

-- last config you saved / loaded comes back by itself the next time you execute the hub
do
    local last = Persist.cfg.MacroLast
    if type(last) == "string" and saved[last] then
        pcall(function()
            applyConfig(saved[last])
            nameBox.Text = last
            ConfigDD.Set(last)
        end)
    end
end

MacroCleanup = function()
    stopMacro()
    pcall(function() MacroSmall.Show(false) end)
end
end

Persist.skip = false
-- ═══ ESP TAB ══════════════════════════════════════════════════════════════════
local EP = Pages["ESP"]
SectionHeader("Players", EP)

Toggle(EP, "Box ESP", "Box around every player", false, function(on) ESP.Box = on end)
Toggle(EP, "Name ESP", "Name, distance and HP above / below the box", false, function(on) ESP.Names = on end)
Toggle(EP, "Player Info (Level / Race / HP)", "One button: level, race, HP and distance under every player", false, function(on) ESP.Info = on end)
Toggle(EP, "Health Bar", "Health bar next to the box", false, function(on) ESP.Health = on end)
Toggle(EP, "Tracers", "Line from the screen to every player", false, function(on) ESP.Tracers = on end)
Toggle(EP, "Chams", "Highlight players through walls", false, function(on)
    ESP.Chams = on
    if not on then
        for _, p in ipairs(Players:GetPlayers()) do
            local hl = p.Character and p.Character:FindFirstChild("AK_CHAMS")
            if hl then hl:Destroy() end
        end
    end
end)

SectionHeader("ESP Settings", EP)

Slider(EP, "ESP Max Distance", 200, 5000, 3000, "", function(v) ESP.MaxDist = v end)
Slider(EP, "Chams Fill", 0, 100, 50, "%", function(v) ESP.ChamFill = 1 - v / 100 end)
Dropdown(EP, "Tracer Origin", function() return { "Bottom", "Center", "Top" } end, "Bottom", function(v)
    ESP.TracerFrom = v
end)
Toggle(EP, "Hide Teammates", "Don't draw players on your team", false, function(on) ESP.HideAllies = on end)
Label("Pirates = red, Marines = blue, aimbot target = green.", 11, T.TextMut, EP, {
    Size = UDim2.new(1, 0, 0, 18),
})

-- ═══ PERFORMANCE TAB ═════════════════════════════════════════════════════════
do
    local PF = Pages["Performance"]
    local Stats = game:GetService("Stats")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    local undo = {}                       -- every feature registers how to switch itself off (used on unload)

    Label("Real ping depends on your connection and the server, no script can lower it. These cut lag spikes, GPU and CPU load.", 11, T.TextMut, PF, {
        Size = UDim2.new(1, 0, 0, 30), TextWrapped = true,
    })

    SectionHeader("Graphics", PF)

    local origQuality
    local function setLow(on)
        pcall(function()
            local r = settings().Rendering
            if on then
                origQuality = origQuality or r.QualityLevel
                r.QualityLevel = Enum.QualityLevel.Level01
            elseif origQuality then
                r.QualityLevel = origQuality
            end
        end)
    end
    undo[#undo + 1] = function() setLow(false) end
    Toggle(PF, "Low Graphics Mode", "Lowest render quality level, biggest FPS gain", false, setLow)

    local origShadows
    local function setShadows(on)
        if on then
            if origShadows == nil then origShadows = Lighting.GlobalShadows end
            Lighting.GlobalShadows = false
        elseif origShadows ~= nil then
            Lighting.GlobalShadows = origShadows
        end
    end
    undo[#undo + 1] = function() setShadows(false) end
    Toggle(PF, "Disable Shadows", "No dynamic shadows", false, setShadows)

    local fxOff = {}
    local function setPost(on)
        if on then
            local function scan(parent)
                for _, e in ipairs(parent:GetChildren()) do
                    if e:IsA("PostEffect") and e.Enabled then fxOff[#fxOff + 1] = e e.Enabled = false end
                end
            end
            scan(Lighting)
            pcall(scan, workspace.CurrentCamera)
        else
            for _, e in ipairs(fxOff) do pcall(function() e.Enabled = true end) end
            fxOff = {}
        end
    end
    undo[#undo + 1] = function() setPost(false) end
    Toggle(PF, "Remove Lighting Effects", "Bloom, blur, sun rays, depth of field, color effects off", false, setPost)

    local origWater
    local function setWater(on)
        if not Terrain then return end
        if on then
            origWater = origWater or {
                WaterWaveSize = Terrain.WaterWaveSize, WaterWaveSpeed = Terrain.WaterWaveSpeed,
                WaterReflectance = Terrain.WaterReflectance,
            }
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
        elseif origWater then
            for k, v in pairs(origWater) do Terrain[k] = v end
        end
    end
    undo[#undo + 1] = function() pcall(setWater, false) end
    Toggle(PF, "Flat Water", "No waves or reflections", false, function(on) pcall(setWater, on) end)

    SectionHeader("World", PF)

    -- Smooth Materials: every map part becomes plain SmoothPlastic (cheaper to draw). Characters are skipped.
    local origMat = setmetatable({}, { __mode = "k" })
    local matOn, matConn = false, nil
    local function plain(o)
        if o:IsA("BasePart") and not o:IsA("Terrain") and o.Material ~= Enum.Material.SmoothPlastic then
            local par = o.Parent
            if par and par:FindFirstChildOfClass("Humanoid") then return end
            origMat[o] = o.Material
            o.Material = Enum.Material.SmoothPlastic
        end
    end
    local function setMat(on)
        matOn = on
        if matConn then matConn:Disconnect() matConn = nil end
        if on then
            matConn = workspace.DescendantAdded:Connect(function(o) if matOn then pcall(plain, o) end end)
            task.spawn(function()
                local n = 0
                for _, o in ipairs(workspace:GetDescendants()) do
                    if not matOn then break end
                    pcall(plain, o)
                    n = n + 1
                    if n % 400 == 0 then task.wait() end
                end
            end)
        else
            task.spawn(function()
                local n = 0
                for o, m in pairs(origMat) do
                    pcall(function() o.Material = m end)
                    origMat[o] = nil
                    n = n + 1
                    if n % 400 == 0 then task.wait() end
                end
            end)
        end
    end
    undo[#undo + 1] = function() setMat(false) end
    Toggle(PF, "Smooth Materials", "Plain materials on the map, less GPU load (takes a few seconds)", false, setMat)

    -- Hide Effects: particles, trails, beams, smoke, fire, sparkles are switched off (best effort, move visuals included)
    local EFFECT = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }
    local fxWas = setmetatable({}, { __mode = "k" })
    local fxOn, fxConn = false, nil
    local function killFx(o)
        if EFFECT[o.ClassName] and o.Enabled then
            fxWas[o] = true
            o.Enabled = false
        end
    end
    local function setFx(on)
        fxOn = on
        if fxConn then fxConn:Disconnect() fxConn = nil end
        if on then
            fxConn = workspace.DescendantAdded:Connect(function(o) if fxOn then pcall(killFx, o) end end)
            task.spawn(function()
                local n = 0
                for _, o in ipairs(workspace:GetDescendants()) do
                    if not fxOn then break end
                    pcall(killFx, o)
                    n = n + 1
                    if n % 400 == 0 then task.wait() end
                end
            end)
        else
            for o in pairs(fxWas) do
                pcall(function() o.Enabled = true end)
                fxWas[o] = nil
            end
        end
    end
    undo[#undo + 1] = function() setFx(false) end
    Toggle(PF, "Hide Effects", "Particles, trails, beams, smoke, fire off. Also hides some move visuals", false, setFx)

    SectionHeader("Frame Rate", PF)

    local capOn, capVal, origCap = false, 60, nil
    local function applyCap()
        if not setfpscap then return end
        pcall(function()
            if capOn then
                if origCap == nil then origCap = (getfpscap and getfpscap()) or 60 end
                setfpscap(capVal)
            elseif origCap ~= nil then
                setfpscap(origCap)
                origCap = nil
            end
        end)
    end
    undo[#undo + 1] = function() capOn = false applyCap() end
    Toggle(PF, "Set FPS Cap", "Locks your frame rate (needs executor support)", false, function(on)
        capOn = on
        applyCap()
    end)
    Slider(PF, "FPS Cap", 30, 240, 60, "", function(v)
        capVal = v
        if capOn then applyCap() end
    end)

    local function set3d(off)
        pcall(function() RunService:Set3dRenderingEnabled(not off) end)
    end
    undo[#undo + 1] = function() set3d(false) end
    Toggle(PF, "3D Rendering Off (AFK)", "Black screen, near 0 GPU use. Turn it off to see the game again", false, set3d)

    SectionHeader("Monitor", PF)

    local statText = "FPS --  Ping --"
    local StatSmall = MakeSmallToggle(function() return statText end, -110, function() return false end, function() end, true)
    local frames, lastT = 0, os.clock()
    Track(RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - lastT >= 0.5 then
            local fps = frames / (now - lastT)
            frames, lastT = 0, now
            local ping = 0
            pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            statText = string.format("FPS %d  Ping %d ms", math.floor(fps + 0.5), math.floor(ping + 0.5))
            StatSmall.Refresh()
        end
    end))
    Toggle(PF, "FPS / Ping Counter", "Small floating box, drag it anywhere", false, function(on) StatSmall.Show(on) end)

    SectionHeader("Cleanup", PF)

    Button(PF, "Clean Memory", T.AccentDark, function()
        pcall(function() collectgarbage("collect") end)
        local mb = 0
        pcall(function() mb = Stats:GetTotalMemoryUsageMb() end)
        print(string.format("[AkatsukiHub] memory cleaned | client memory %.0f MB", mb))
    end)

    env.AkatsukiPerfCleanup = function()
        for _, f in ipairs(undo) do pcall(f) end
    end
end

-- ═══ MISC TAB ═════════════════════════════════════════════════════════════════
local MP = Pages["Misc"]
SectionHeader("World", MP)

Slider(MP, "Field of View", 40, 120, math.floor(workspace.CurrentCamera.FieldOfView + 0.5), "", function(v)
    workspace.CurrentCamera.FieldOfView = v
end)

local origLight
Toggle(MP, "Fullbright", "Max brightness", false, function(on)
    if on then
        origLight = origLight or {
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
        }
        Lighting.Brightness = 10
        Lighting.ClockTime = 12
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    elseif origLight then
        for k, v in pairs(origLight) do Lighting[k] = v end
    end
end)

SectionHeader("Game", MP)

Button(MP, "Copy Place ID", T.AccentDark, function()
    SafeClipboard(tostring(game.PlaceId))
end)
Button(MP, "Rejoin Server", T.Red, function()
    pcall(function() TeleportService:Teleport(game.PlaceId, lp) end)
end)
Button(MP, "Unload Hub", Color3.fromRGB(80, 20, 20), function()
    Cleanup()
end)

SectionHeader("Credits", MP)
local cred = Make("Frame", {
    Size             = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = T.Card,
    BorderSizePixel  = 0,
}, MP)
Corner(cred, 7)
Stroke(cred, T.Border, 1)
Label("☁ Akatsuki Hub v3.6  |  by Fox & Jack", 12, T.TextSec, cred, {
    Size     = UDim2.new(1, -12, 0, 20),
    Position = UDim2.new(0, 12, 0, 8),
})
Label("Keyless  |  Blox Fruits  |  Aimbot + ESP", 11, T.TextMut, cred, {
    Size     = UDim2.new(1, -12, 0, 16),
    Position = UDim2.new(0, 12, 0, 30),
})

-- ─── Keybind (PC): RightShift shows / hides the hub ───────────────────────────
Track(UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end))

-- ─── Character respawn ────────────────────────────────────────────────────────
Track(lp.CharacterAdded:Connect(function(c)
    character = c
    humanoid = c:WaitForChild("Humanoid")
    rootPart = c:WaitForChild("HumanoidRootPart")
    Hold.remotes = {}
end))

-- ─── Cleanup / unload ─────────────────────────────────────────────────────────
Cleanup = function()
    Aim.LockOn, Aim.Silent, Aim.Choose = false, false, false
    pcall(function() RunService:UnbindFromRenderStep("AkatsukiAim") end)
    pcall(function() RunService:UnbindFromRenderStep("AkatsukiChase") end)
    env.AkatsukiSilent = nil
    env.AkatsukiMove = nil
    if ShakeCleanup then pcall(ShakeCleanup) end
    if env.AkatsukiPerfCleanup then pcall(env.AkatsukiPerfCleanup) env.AkatsukiPerfCleanup = nil end
    for k in pairs(State.Connections) do DisconnectKey(k) end
    for _, c in ipairs(AllConns) do pcall(function() c:Disconnect() end) end
    if MacroCleanup then pcall(MacroCleanup) end
    pcall(ClearESP)
    pcall(function()
        local bv = rootPart and rootPart:FindFirstChild("AK_BV")
        if bv then bv:Destroy() end
    end)
    pcall(function() ScreenGui:Destroy() end)
    env.AkatsukiCleanup = nil
end
env.AkatsukiCleanup = Cleanup

Persist.restore()
print("[AkatsukiHub] v3.6 loaded | tap the cloud button or RightShift to show/hide")
