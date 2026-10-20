return function(Hub)
    local S = Hub.Services
    local TweenService, UIS = S.TweenService, S.UserInputService

    local UI = {}

    local Theme = {
        Bg = Color3.fromRGB(13, 13, 18),
        Panel = Color3.fromRGB(18, 18, 25),
        Card = Color3.fromRGB(21, 21, 29),
        Row = Color3.fromRGB(28, 28, 38),
        RowHover = Color3.fromRGB(35, 35, 48),
        Stroke = Color3.fromRGB(40, 40, 54),
        Text = Color3.fromRGB(248, 248, 253),
        Sub = Color3.fromRGB(168, 168, 192),
        Off = Color3.fromRGB(48, 48, 63),
        Good = Color3.fromRGB(52, 211, 130),
        Bad = Color3.fromRGB(244, 91, 105),
        Warn = Color3.fromRGB(245, 176, 65),
        Accent = Color3.fromRGB(110, 114, 255),
    }
    UI.Theme = Theme

    UI.Accents = {
        { Name = "Indigo", Color = Color3.fromRGB(110, 114, 255) },
        { Name = "Emerald", Color = Color3.fromRGB(16, 185, 129) },
        { Name = "Rose", Color = Color3.fromRGB(244, 63, 94) },
        { Name = "Amber", Color = Color3.fromRGB(245, 158, 11) },
        { Name = "Sky", Color = Color3.fromRGB(14, 165, 233) },
        { Name = "Violet", Color = Color3.fromRGB(168, 85, 247) },
        { Name = "Cyan", Color = Color3.fromRGB(34, 211, 238) },
        { Name = "Lime", Color = Color3.fromRGB(132, 204, 22) },
        { Name = "Pink", Color = Color3.fromRGB(236, 72, 153) },
        { Name = "Crimson", Color = Color3.fromRGB(239, 68, 68) },
        { Name = "Rainbow", Color = Color3.fromRGB(168, 85, 247), Rainbow = true },
    }
    UI.AccentName = "Indigo"

    local FONT, FONT_BOLD, FONT_SEMI = Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.GothamSemibold

    local function new(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props or {}) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end
    UI.New = new

    local function corner(o, r)
        return new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
    end
    UI.Corner = corner

    local function stroke(o, color, thickness, transparency)
        return new("UIStroke", {
            Color = color or Theme.Stroke,
            Thickness = thickness or 1,
            Transparency = transparency or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, o)
    end
    UI.Stroke = stroke

    local function pad(o, t, r, b, l)
        return new("UIPadding", {
            PaddingTop = UDim.new(0, t or 0), PaddingRight = UDim.new(0, r or t or 0),
            PaddingBottom = UDim.new(0, b or t or 0), PaddingLeft = UDim.new(0, l or r or t or 0),
        }, o)
    end
    UI.Pad = pad

    local function list(o, padding, dir)
        return new("UIListLayout", {
            Padding = UDim.new(0, padding or 0),
            FillDirection = dir or Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, o)
    end
    UI.List = list

    local function gradient(o, c0, c1, rotation, t0, t1)
        return new("UIGradient", {
            Color = ColorSequence.new(c0, c1),
            Transparency = NumberSequence.new(t0 or 0, t1 or 0),
            Rotation = rotation or 90,
        }, o)
    end
    UI.Gradient = gradient

    local function accentGradient(o, rotation, soft)
        local g = new("UIGradient", { Rotation = rotation or 0 }, o)
        UI.BindAccent(function()
            local a = Theme.Accent
            g.Color = ColorSequence.new(a, a:Lerp(Color3.fromRGB(255, 255, 255), soft or 0.28))
        end)
        return g
    end

    local perfMode = false
    local halos    = {}   -- weak refs so GC can clean destroyed instances

    local function tween(o, props, t, style, dir)
        if perfMode then
            -- skip animation, apply instantly
            for k, v in pairs(props) do pcall(function() o[k] = v end) end
            -- return dummy tween so callers doing tw.Completed:Wait() don't crash
            return { Completed = { Wait = function() end } }
        end
        local tw = TweenService:Create(o, TweenInfo.new(t or 0.15,
            style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
        tw:Play()
        return tw
    end
    UI.Tween = tween

    UI.IconNames = {}
    for _, n in ipairs({ "knife", "globe", "person", "gear", "minus", "plus", "close", "chevron_down",
        "chevron_up", "check", "save", "load", "trash", "star", "power", "crosshair", "spin" }) do
        UI.IconNames[n] = true
    end
    local ICON_VERSION = "2"
    local assetCache, assetWaiters = {}, {}

    local function assetFunc() return getcustomasset or getsynasset end

    local function resolveAsset(key, repoPath, cb)
        if assetCache[key] ~= nil then
            if assetCache[key] then cb(assetCache[key]) end
            return
        end
        if assetWaiters[key] then
            table.insert(assetWaiters[key], cb)
            return
        end
        assetWaiters[key] = { cb }
        task.spawn(function()
            local asset = false
            local ok = pcall(function()
                local make = assetFunc()
                if not (make and writefile and isfile) then return end
                local root = Hub.Folder or "ScriptHub"
                pcall(function() if not isfolder(root) then makefolder(root) end end)
                local dir = root .. "/icons"
                pcall(function() if not isfolder(dir) then makefolder(dir) end end)
                local file = ("%s/%s_v%s.png"):format(dir, key, ICON_VERSION)
                if not isfile(file) then
                    writefile(file, Hub.Fetch(repoPath))
                end
                asset = make(file)
            end)
            assetCache[key] = ok and asset or false
            local waiters = assetWaiters[key]
            assetWaiters[key] = nil
            if assetCache[key] then
                for _, fn in ipairs(waiters) do pcall(fn, assetCache[key]) end
            end
        end)
    end

    local function resolveIcon(name, cb)
        resolveAsset("i_" .. name, "Assets/Icons/" .. name .. ".png", cb)
    end

    function UI.Icon(parent, name, props)
        local img = new("ImageLabel", {
            BackgroundTransparency = 1,
            ImageColor3 = Theme.Sub,
            ScaleType = Enum.ScaleType.Fit,
        }, nil)
        for k, v in pairs(props or {}) do img[k] = v end
        img.Parent = parent
        resolveIcon(name, function(asset)
            if img.Parent then img.Image = asset end
        end)
        return img
    end

    function UI.SetIcon(img, name)
        resolveIcon(name, function(asset)
            if img.Parent then img.Image = asset end
        end)
    end

    local SPRITES = {
        shadow = { slice = Rect.new(110, 110, 146, 146), pad = 64 },
        glow = { slice = Rect.new(110, 110, 146, 146), pad = 64 },
        glow_s = { slice = Rect.new(26, 26, 38, 38), pad = 16 },
        radial = {},
        dots = {},
    }

    function UI.Sprite(parent, name, props)
        local info = SPRITES[name]
        local img = new("ImageLabel", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScaleType = info.slice and Enum.ScaleType.Slice or Enum.ScaleType.Stretch,
        }, nil)
        if info.slice then img.SliceCenter = info.slice end
        for k, v in pairs(props or {}) do img[k] = v end
        img.Parent = parent
        resolveAsset("s_" .. name, "Assets/UI/" .. name .. ".png", function(asset)
            if img.Parent then img.Image = asset end
        end)
        return img
    end

    function UI.Halo(parent, name, opts)
        opts = opts or {}
        local pad = SPRITES[name].pad
        local img = UI.Sprite(parent, name, {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, opts.OffsetY or 0),
            Size = UDim2.new(1, pad * 2, 1, pad * 2),
            ImageTransparency = opts.Transparency or 0.6,
            ZIndex = opts.ZIndex or 0,
            Visible = not perfMode,
        })
        if opts.Color then
            img.ImageColor3 = opts.Color
        else
            UI.BindAccent(function() img.ImageColor3 = Theme.Accent end)
        end
        halos[#halos + 1] = img
        return img
    end

    function UI.SetPerfMode(on)
        perfMode = on
        -- hide/show all glow, shadow, radial, dots sprites
        for i = #halos, 1, -1 do
            local h = halos[i]
            if h and h.Parent then
                h.Visible = not on
            else
                table.remove(halos, i)   -- clean up destroyed instances
            end
        end
        -- stop rainbow loop immediately when perf mode is on
        if on and UI.AccentName == "Rainbow" then
            UI.SetAccent("Indigo")
        end
    end

    function UI.Format(n)
        local s = tostring(math.floor(n or 0))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end

    function UI.FormatTime(sec)
        sec = math.max(0, math.floor(sec or 0))
        return ("%02d:%02d:%02d"):format(math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
    end

    local function isPointer(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch
    end
    local function isMove(i)
        return i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch
    end

    function UI.Draggable(handle, target)
        local dragging, startPointer, startPos = false, nil, nil
        Hub.Track(handle.InputBegan:Connect(function(input)
            if isPointer(input) then
                dragging = true
                startPointer = input.Position
                startPos = target.Position
            end
        end))
        Hub.Track(UIS.InputChanged:Connect(function(input)
            if dragging and isMove(input) then
                local d = input.Position - startPointer
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
        Hub.Track(UIS.InputEnded:Connect(function(input)
            if isPointer(input) then dragging = false end
        end))
    end

    local accentBinders, scales, glass = {}, {}, {}
    local glassValue, scaleValue = 0, 100

    function UI.BindAccent(fn)
        accentBinders[#accentBinders + 1] = fn
        fn()
    end

    local rainbowRunning = false

    local function startRainbow()
        if rainbowRunning then return end
        rainbowRunning = true
        task.spawn(function()
            while UI.AccentName == "Rainbow" and Hub.Alive do
                Theme.Accent = Color3.fromHSV((os.clock() * 0.07) % 1, 0.62, 1)
                for _, fn in ipairs(accentBinders) do pcall(fn) end
                task.wait(0.1)
            end
            rainbowRunning = false
        end)
    end

    function UI.SetAccent(name)
        for _, a in ipairs(UI.Accents) do
            if a.Name == name then
                UI.AccentName = a.Name
                Theme.Accent = a.Color
                for _, fn in ipairs(accentBinders) do pcall(fn) end
                if a.Rainbow then startRainbow() end
                return true
            end
        end
        return false
    end

    function UI.RegisterScale(uiScale)
        scales[#scales + 1] = uiScale
        uiScale.Scale = scaleValue / 100
    end

    function UI.SetScale(percent)
        scaleValue = percent
        for _, s in ipairs(scales) do s.Scale = percent / 100 end
    end

    function UI.RegisterGlass(frame)
        glass[#glass + 1] = frame
        frame.BackgroundTransparency = glassValue / 100
    end

    function UI.SetTransparency(percent)
        glassValue = percent
        for _, f in ipairs(glass) do f.BackgroundTransparency = percent / 100 end
    end

    function UI.NewGui(name, order)
        local g = new("ScreenGui", {
            Name = name,
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            DisplayOrder = order or 100,
        })
        pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(g) end
        end)
        local ok = pcall(function()
            g.Parent = (gethui and gethui()) or S.CoreGui
        end)
        if not ok or not g.Parent then g.Parent = Hub.Player:WaitForChild("PlayerGui") end
        Hub.Track(g)
        return g
    end

    local rootGui = UI.NewGui("ScriptHub", 2147483000)
    UI.Root = rootGui

    local toasts = new("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(280, 400),
        BackgroundTransparency = 1,
    }, rootGui)
    new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
    }, toasts)

    local toastId = 0

    function UI.Notify(def)
        toastId = toastId + 1
        local color = ({ good = Theme.Good, bad = Theme.Bad, warn = Theme.Warn })[def.Type] or Theme.Accent
        local wrap = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = toastId,
        }, toasts)
        local card = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(300, 0),
            BackgroundColor3 = Theme.Panel,
            BorderSizePixel = 0,
        }, wrap)
        corner(card, 10)
        stroke(card, color, 1, 0.6)
        UI.Halo(card, "glow_s", { Color = color, Transparency = 0.55 })
        local bar = new("Frame", {
            Size = UDim2.new(0, 3, 1, -12),
            Position = UDim2.fromOffset(6, 6),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
        }, card)
        corner(bar, 2)
        local body = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
        }, card)
        list(body, 2)
        pad(body, 10, 12, 10, 20)
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = def.Title or Hub.Name,
            Font = FONT_BOLD, TextSize = 14, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }, body)
        if def.Text and def.Text ~= "" then
            new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = def.Text,
                Font = FONT, TextSize = 13, TextColor3 = Theme.Sub,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }, body)
        end

        local life = def.Duration or 4
        local prog = new("Frame", {
            Size = UDim2.new(1, -16, 0, 2),
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 8, 1, -4),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
        }, card)
        corner(prog, 1)
        tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, life, Enum.EasingStyle.Linear)
        tween(card, { Position = UDim2.fromOffset(0, 0) }, 0.25, Enum.EasingStyle.Back)
        task.delay(life, function()
            if not card.Parent then return end
            local tw = tween(card, { Position = UDim2.fromOffset(300, 0) }, 0.2)
            tw.Completed:Wait()
            wrap:Destroy()
        end)
    end

    local Window = {}
    Window.__index = Window
    local Tab = {}
    Tab.__index = Tab
    local Section = {}
    Section.__index = Section

    function UI.Splash(title, version, onDone)
        local wrap = new("Frame", {
            Name = "Splash",
            Size = UDim2.fromOffset(340, 150),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1,
        }, rootGui)
        local sc = new("UIScale", { Scale = 0.88 }, wrap)
        local shadow = UI.Halo(wrap, "shadow", { Color = Color3.new(0, 0, 0), Transparency = 0.4, OffsetY = 8 })
        local glow = UI.Halo(wrap, "glow", { Transparency = 0.45 })

        local card = new("CanvasGroup", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Bg, BorderSizePixel = 0,
        }, wrap)
        corner(card, 16)
        stroke(card, Theme.Stroke, 1, 0.2)
        local light = UI.Sprite(card, "radial", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(60, 40),
            Size = UDim2.fromOffset(420, 260), ImageTransparency = 0.7,
        })
        UI.BindAccent(function() light.ImageColor3 = Theme.Accent end)

        local logo = new("Frame", {
            Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(24, 26),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        }, card)
        corner(logo, 12)
        accentGradient(logo, 45, 0.35)
        new("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = string.upper(string.sub(title, 1, 1)),
            Font = FONT_BOLD, TextSize = 24, TextColor3 = Color3.new(1, 1, 1),
        }, logo)
        new("TextLabel", {
            Size = UDim2.new(1, -110, 0, 28), Position = UDim2.fromOffset(84, 24),
            BackgroundTransparency = 1, Text = title,
            Font = FONT_BOLD, TextSize = 24, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
        local status = new("TextLabel", {
            Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(84, 54),
            BackgroundTransparency = 1, Text = "v" .. tostring(version) .. "  ·  loading",
            Font = FONT, TextSize = 13, TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)

        local track = new("Frame", {
            Size = UDim2.new(1, -48, 0, 6), Position = UDim2.fromOffset(24, 108),
            BackgroundColor3 = Theme.Off, BorderSizePixel = 0,
        }, card)
        corner(track, 3)
        local fill = new("Frame", {
            Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        }, track)
        corner(fill, 3)
        accentGradient(fill, 0, 0.35)

        tween(sc, { Scale = 1 }, 0.4, Enum.EasingStyle.Back)
        tween(fill, { Size = UDim2.fromScale(1, 1) }, 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

        task.delay(1.7, function()
            status.Text = "v" .. tostring(version) .. "  ·  ready"
            task.wait(0.2)
            tween(card, { GroupTransparency = 1 }, 0.35)
            tween(shadow, { ImageTransparency = 1 }, 0.35)
            tween(glow, { ImageTransparency = 1 }, 0.35)
            tween(sc, { Scale = 1.08 }, 0.35)
            task.wait(0.4)
            wrap:Destroy()
            if onDone then onDone() end
        end)
    end

    function UI.CreateWindow(def)
        local self = setmetatable({}, Window)
        self.Tabs, self.Order, self.Current = {}, {}, nil
        self.Key = def.ToggleKey or Enum.KeyCode.RightShift
        self.Visible = true

        local size = def.Size or Vector2.new(600, 420)
        local shell = new("Frame", {
            Name = "Window",
            Size = UDim2.fromOffset(size.X, size.Y),
            Position = UDim2.fromOffset(40, 60),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Active = true,
        }, rootGui)
        UI.Halo(shell, "shadow", { Color = Color3.new(0, 0, 0), Transparency = 0.35, OffsetY = 10 })
        local neon = UI.Halo(shell, "glow", { Transparency = 0.7 })
        TweenService:Create(neon, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { ImageTransparency = 0.4 }):Play()

        local main = new("Frame", {
            Name = "Body",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0,
            ClipsDescendants = false,
        }, shell)
        corner(main, 14)
        local winStroke = stroke(main, Color3.new(1, 1, 1), 1.6, 0.05)
        local winGrad = new("UIGradient", { Rotation = 0 }, winStroke)
        UI.BindAccent(function()
            winGrad.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Theme.Accent),
                ColorSequenceKeypoint.new(0.3, Theme.Stroke),
                ColorSequenceKeypoint.new(0.7, Theme.Stroke),
                ColorSequenceKeypoint.new(1, Theme.Accent),
            })
        end)
        TweenService:Create(winGrad, TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
            { Rotation = 360 }):Play()
        UI.RegisterGlass(main)

        local bg = new("Frame", {
            Name = "Ambient", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true,
        }, main)
        corner(bg, 14)
        local light1 = UI.Sprite(bg, "radial", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(90, 30),
            Size = UDim2.fromOffset(520, 340), ImageTransparency = 0.78,
        })
        UI.BindAccent(function() light1.ImageColor3 = Theme.Accent end)
        UI.Sprite(bg, "radial", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -60, 1, -20),
            Size = UDim2.fromOffset(440, 300), ImageTransparency = 0.88,
            ImageColor3 = Color3.fromRGB(168, 85, 247),
        })
        local dots = UI.Sprite(bg, "dots", { Size = UDim2.fromScale(1, 1), ImageTransparency = 0.9 })
        dots.ScaleType = Enum.ScaleType.Tile
        dots.TileSize = UDim2.fromOffset(24, 24)

        local uiScale = new("UIScale", { Scale = 1 }, shell)
        UI.RegisterScale(uiScale)
        self.Main = shell

        shell.Visible = false

        local top = new("Frame", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundTransparency = 1,
        }, main)
        local logo = new("Frame", {
            Size = UDim2.fromOffset(26, 26),
            Position = UDim2.fromOffset(14, 9),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, top)
        corner(logo, 8)
        local logoGrad = accentGradient(logo, 45, 0.35)
        TweenService:Create(logoGrad, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
            { Rotation = 45 + 360 }):Play()
        UI.Halo(logo, "glow_s", { Transparency = 0.35 })
        new("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = string.upper(string.sub(def.Title or Hub.Name, 1, 1)),
            Font = FONT_BOLD, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
        }, logo)
        new("TextLabel", {
            Size = UDim2.fromOffset(200, 18),
            Position = UDim2.fromOffset(48, 6),
            BackgroundTransparency = 1,
            Text = def.Title or Hub.Name,
            Font = FONT_BOLD, TextSize = 15, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, top)
        self.SubtitleLabel = new("TextLabel", {
            Size = UDim2.new(1, -170, 0, 14),
            Position = UDim2.fromOffset(48, 24),
            BackgroundTransparency = 1,
            Text = def.Subtitle or "",
            Font = FONT, TextSize = 12, TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, top)

        local topLine = new("Frame", {
            Size = UDim2.new(1, -28, 0, 1),
            Position = UDim2.new(0, 14, 1, -1),
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
        }, top)
        new("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.8), NumberSequenceKeypoint.new(1, 1),
            }),
        }, topLine)
        UI.BindAccent(function() topLine.BackgroundColor3 = Theme.Accent end)

        local function topButton(iconName, x, hoverColor)
            local b = new("TextButton", {
                Size = UDim2.fromOffset(28, 28),
                Position = UDim2.new(1, x, 0, 8),
                BackgroundColor3 = Theme.Row,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
            }, top)
            corner(b, 8)
            local ic = UI.Icon(b, iconName, {
                Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5), ImageColor3 = Theme.Sub,
            })
            b.MouseEnter:Connect(function()
                tween(b, { BackgroundTransparency = 0, BackgroundColor3 = hoverColor or Theme.RowHover })
                tween(ic, { ImageColor3 = Theme.Text })
            end)
            b.MouseLeave:Connect(function()
                tween(b, { BackgroundTransparency = 1 })
                tween(ic, { ImageColor3 = Theme.Sub })
            end)
            return b, ic
        end
        local minBtn, minIcon = topButton("minus", -70)
        local closeBtn = topButton("close", -38, Theme.Bad)
        UI.Draggable(top, shell)

        local body = new("Frame", {
            Size = UDim2.new(1, 0, 1, -44),
            Position = UDim2.fromOffset(0, 44),
            BackgroundTransparency = 1,
        }, main)
        self.Body = body

        local sidebar = new("Frame", {
            Size = UDim2.new(0, 156, 1, -16),
            Position = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Theme.Panel,
            BorderSizePixel = 0,
        }, body)
        corner(sidebar, 12)
        UI.RegisterGlass(sidebar)
        stroke(sidebar, Theme.Stroke, 1, 0.4)
        local tabList = new("Frame", {
            Size = UDim2.new(1, 0, 1, -56),
            BackgroundTransparency = 1,
        }, sidebar)
        list(tabList, 4)
        pad(tabList, 8, 8, 0, 8)
        self.TabList = tabList

        local me = new("Frame", {
            Size = UDim2.new(1, -16, 0, 40),
            Position = UDim2.new(0, 8, 1, -48),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
        }, sidebar)
        corner(me, 10)
        stroke(me, Theme.Stroke, 1, 0.5)
        local av = new("ImageLabel", {
            Size = UDim2.fromOffset(28, 28),
            Position = UDim2.fromOffset(6, 6),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
        }, me)
        corner(av, 14)
        task.spawn(function()
            local ok, img = pcall(S.Players.GetUserThumbnailAsync, S.Players, Hub.Player.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            if ok and av.Parent then av.Image = img end
        end)
        new("TextLabel", {
            Size = UDim2.new(1, -42, 0, 16),
            Position = UDim2.fromOffset(40, 6),
            BackgroundTransparency = 1,
            Text = Hub.Player.Name,
            Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, me)
        new("TextLabel", {
            Size = UDim2.new(1, -42, 0, 12),
            Position = UDim2.fromOffset(40, 22),
            BackgroundTransparency = 1,
            Text = "v" .. Hub.Version,
            Font = FONT, TextSize = 11, TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, me)

        self.Content = new("Frame", {
            Size = UDim2.new(1, -180, 1, -16),
            Position = UDim2.fromOffset(172, 8),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
        }, body)

        local fab = new("TextButton", {
            Name = "OpenButton",
            Size = UDim2.fromOffset(40, 40),
            Position = UDim2.new(0, 12, 0.5, -20),
            BackgroundColor3 = Theme.Panel,
            AutoButtonColor = false,
            Text = "☰",
            Font = FONT_BOLD, TextSize = 18, TextColor3 = Theme.Text,
            Visible = false,
        }, rootGui)
        corner(fab, 20)
        UI.Halo(fab, "glow_s", { Transparency = 0.4 })
        local fabStroke = stroke(fab, Theme.Accent, 2)
        UI.BindAccent(function() fabStroke.Color = Theme.Accent end)
        local fabScale = new("UIScale", { Scale = 1 }, fab)
        UI.RegisterScale(fabScale)
        local fabMoved = false
        do
            local dragging, sp, spos = false, nil, nil
            Hub.Track(fab.InputBegan:Connect(function(i)
                if isPointer(i) then dragging, fabMoved, sp, spos = true, false, i.Position, fab.Position end
            end))
            Hub.Track(UIS.InputChanged:Connect(function(i)
                if dragging and isMove(i) then
                    local d = i.Position - sp
                    if d.Magnitude > 6 then fabMoved = true end
                    if fabMoved then
                        fab.Position = UDim2.new(spos.X.Scale, spos.X.Offset + d.X, spos.Y.Scale, spos.Y.Offset + d.Y)
                    end
                end
            end))
            Hub.Track(UIS.InputEnded:Connect(function(i)
                if isPointer(i) then dragging = false end
            end))
        end
        fab.MouseButton1Click:Connect(function()
            if not fabMoved then self:SetVisible(true) end
        end)

        local collapsed = false
        local fullSize = shell.Size
        minBtn.MouseButton1Click:Connect(function()
            collapsed = not collapsed
            body.Visible = not collapsed
            tween(shell, { Size = collapsed and UDim2.fromOffset(size.X, 44) or fullSize }, 0.2)
            UI.SetIcon(minIcon, collapsed and "plus" or "minus")
        end)
        closeBtn.MouseButton1Click:Connect(function() self:SetVisible(false) end)

        function self:SetVisible(v)
            self.Visible = v
            shell.Visible = v
            fab.Visible = not v
        end

        function self:Toggle()
            self:SetVisible(not self.Visible)
        end

        function self:SetKey(keyCode)
            self.Key = keyCode
        end

        Hub.Track(UIS.InputBegan:Connect(function(input, processed)
            if processed or self.Listening then return end
            if input.KeyCode == self.Key then self:Toggle() end
        end))

        local function reveal()
            if not shell.Parent then return end
            shell.Visible = self.Visible
            fab.Visible = not self.Visible
            shell.Position = UDim2.fromOffset(40, 84)
            tween(shell, { Position = UDim2.fromOffset(40, 60) }, 0.5, Enum.EasingStyle.Back)
        end
        local opts = getgenv().ScriptHubOptions
        if opts and opts.NoSplash then
            reveal()
        else
            local ok = pcall(UI.Splash, def.Title or Hub.Name, Hub.Version, reveal)
            if not ok then reveal() end
        end

        return self
    end

    function Window:AddTab(def)
        local tab = setmetatable({ Window = self, Name = def.Name }, Tab)
        local idx = #self.Order + 1

        local named = type(def.Icon) == "string" and UI.IconNames[def.Icon] == true
        local isImage = named or (type(def.Icon) == "string" and def.Icon:find("^rbxassetid://") ~= nil)
        local btn = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = idx,
        }, self.TabList)
        corner(btn, 9)
        accentGradient(btn, 0, 0.3)
        local tabGlow = UI.Halo(btn, "glow_s", { Transparency = 1 })
        local indicator = new("Frame", {
            Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        }, btn)
        local icon
        if named then
            icon = UI.Icon(btn, def.Icon, {
                Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(12, 9), ImageColor3 = Theme.Sub,
            })
        elseif isImage then
            icon = new("ImageLabel", {
                Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(12, 9),
                BackgroundTransparency = 1, Image = def.Icon, ImageColor3 = Theme.Sub,
            }, btn)
        else
            icon = new("TextLabel", {
                Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(11, 7),
                BackgroundTransparency = 1, Text = def.Icon or "•",
                Font = FONT_BOLD, TextSize = 15, TextColor3 = Theme.Sub,
            }, btn)
        end
        local label = new("TextLabel", {
            Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(38, 0),
            BackgroundTransparency = 1, Text = def.Name,
            Font = FONT_BOLD, TextSize = 14, TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, btn)

        local page = new("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Off,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
        }, self.Content)
        list(page, 10)
        pad(page, 0, 8, 8, 0)

        tab.Button, tab.Page, tab.Counter = btn, page, 0

        function tab:Paint()
            local active = self.Window.Current == self
            local hovered = self.Hovered
            tween(btn, { BackgroundTransparency = active and 0 or (hovered and 0.92 or 1) })
            tween(tabGlow, { ImageTransparency = active and 0.45 or 1 }, 0.25)
            tween(label, { TextColor3 = active and Color3.new(1, 1, 1) or (hovered and Theme.Text or Theme.Sub) })
            local ic = active and Color3.new(1, 1, 1) or Theme.Sub
            if isImage then tween(icon, { ImageColor3 = ic }) else tween(icon, { TextColor3 = ic }) end
        end

        btn.MouseEnter:Connect(function() tab.Hovered = true tab:Paint() end)
        btn.MouseLeave:Connect(function() tab.Hovered = false tab:Paint() end)
        btn.MouseButton1Click:Connect(function() self:Select(tab) end)
        UI.BindAccent(function() tab:Paint() end)

        self.Tabs[def.Name] = tab
        self.Order[idx] = tab
        if not self.Current then self:Select(tab) end
        return tab
    end

    function Window:Select(tab)
        if type(tab) == "string" then tab = self.Tabs[tab] end
        if not tab then return end
        local prev = self.Current
        self.Current = tab
        for _, t in ipairs(self.Order) do
            t.Page.Visible = (t == tab)
            t:Paint()
        end
        if prev ~= tab then
            tab.Page.Position = UDim2.fromOffset(0, 16)
            tween(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.3, Enum.EasingStyle.Quint)
        end
        if tab.OnShow then pcall(tab.OnShow) end
        return prev
    end

    function Tab:AddSection(title)
        local sec = setmetatable({ Tab = self, Counter = 0 }, Section)
        self.Counter = self.Counter + 1

        local card = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            LayoutOrder = self.Counter,
        }, self.Page)
        corner(card, 12)
        local cardStroke = stroke(card, Color3.new(1, 1, 1), 1, 0.2)
        local cardEdge = new("UIGradient", { Rotation = 90 }, cardStroke)
        UI.BindAccent(function()
            cardEdge.Color = ColorSequence.new(Theme.Accent:Lerp(Theme.Stroke, 0.6), Theme.Stroke)
        end)
        new("UIGradient", {
            Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 215)),
            Rotation = 90,
        }, card)
        pad(card, 12, 12, 12, 12)
        list(card, 8)

        if title and title ~= "" then
            local head = new("Frame", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                LayoutOrder = -1,
            }, card)
            local pip = new("Frame", {
                Size = UDim2.fromOffset(3, 12),
                Position = UDim2.fromOffset(0, 2),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
            }, head)
            corner(pip, 2)
            local txt = new("TextLabel", {
                Size = UDim2.new(1, -12, 1, 0),
                Position = UDim2.fromOffset(10, 0),
                BackgroundTransparency = 1,
                Text = string.upper(title),
                Font = FONT_BOLD, TextSize = 12, TextColor3 = Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, head)
            UI.BindAccent(function() pip.BackgroundColor3 = Theme.Accent end)
        end
        sec.Card = card
        return sec
    end

    local function nextOrder(sec)
        sec.Counter = sec.Counter + 1
        return sec.Counter
    end

    local function rowFrame(sec, height, interactive)
        local f = new(interactive and "TextButton" or "Frame", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = Theme.Row,
            BorderSizePixel = 0,
            LayoutOrder = nextOrder(sec),
        }, sec.Card)
        if interactive then
            f.AutoButtonColor = false
            f.Text = ""
        end
        corner(f, 10)
        return f
    end

    local function hoverable(f)
        f.MouseEnter:Connect(function() tween(f, { BackgroundColor3 = Theme.RowHover }, 0.12) end)
        f.MouseLeave:Connect(function() tween(f, { BackgroundColor3 = Theme.Row }, 0.12) end)
    end

    local function rowLabel(parent, text, y, h)
        return new("TextLabel", {
            Size = UDim2.new(1, -70, 0, h or 20),
            Position = UDim2.fromOffset(12, y or 0),
            BackgroundTransparency = 1,
            Text = text,
            Font = FONT_SEMI, TextSize = 14, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parent)
    end

    function Section:Toggle(def)
        local hasDesc = def.Description ~= nil
        local row = rowFrame(self, hasDesc and 50 or 36, true)
        hoverable(row)
        if hasDesc then
            rowLabel(row, def.Name, 8, 18)
            new("TextLabel", {
                Size = UDim2.new(1, -70, 0, 16), Position = UDim2.fromOffset(12, 27),
                BackgroundTransparency = 1, Text = def.Description,
                Font = FONT, TextSize = 12, TextColor3 = Theme.Sub,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            }, row)
        else
            rowLabel(row, def.Name, 8, 20)
        end

        local pill = new("Frame", {
            Size = UDim2.fromOffset(40, 22),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
        }, row)
        corner(pill, 11)
        local pillGrad = accentGradient(pill, 0, 0.3)
        local pillGlow = UI.Halo(pill, "glow_s", { Transparency = 1 })
        local knob = new("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(3, 3),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, pill)
        corner(knob, 8)

        local obj = { Value = def.Default and true or false }
        local function paint(animate)
            local c = obj.Value and Color3.new(1, 1, 1) or Theme.Off
            local p = obj.Value and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3)
            pillGrad.Enabled = obj.Value
            local glowT = obj.Value and 0.4 or 1
            if animate then
                tween(pill, { BackgroundColor3 = c })
                tween(knob, { Position = p }, 0.22, Enum.EasingStyle.Back)
                tween(pillGlow, { ImageTransparency = glowT }, 0.25)
            else
                pill.BackgroundColor3 = c
                knob.Position = p
                pillGlow.ImageTransparency = glowT
            end
        end
        function obj:Set(v, silent)
            if type(v) ~= "boolean" then return end
            self.Value = v
            paint(true)
            if not silent and def.Callback then task.spawn(def.Callback, v) end
        end
        function obj:Get() return self.Value end
        row.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
        UI.BindAccent(function() paint(false) end)
        if def.Flag then Hub.RegisterFlag(def.Flag, function() return obj.Value end, function(v) obj:Set(v) end) end
        return obj
    end

    function Section:Slider(def)
        local min, max = def.Min or 0, def.Max or 100
        local step = def.Step or 1
        local suffix = def.Suffix or ""
        local decimals = 0
        if step < 1 then decimals = #(tostring(step):match("%.(%d+)") or "") end
        local function fmtValue(v) return (("%." .. decimals .. "f"):format(v)) end

        local row = rowFrame(self, 54, false)
        rowLabel(row, def.Name, 7, 20)
        local box = new("TextBox", {
            Size = UDim2.fromOffset(62, 20),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 7),
            BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0,
            Text = "",
            Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.Accent,
            ClearTextOnFocus = false,
        }, row)
        corner(box, 6)
        stroke(box, Theme.Stroke, 1, 0.3)

        local hit = new("TextButton", {
            Size = UDim2.new(1, -24, 0, 18),
            Position = UDim2.fromOffset(12, 31),
            BackgroundTransparency = 1,
            Text = "",
        }, row)
        local bar = new("Frame", {
            Size = UDim2.new(1, 0, 0, 6),
            Position = UDim2.new(0, 0, 0.5, -3),
            BackgroundColor3 = Theme.Off,
            BorderSizePixel = 0,
        }, hit)
        corner(bar, 3)
        local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(1, 1, 1) }, bar)
        corner(fill, 3)
        accentGradient(fill, 0, 0.3)
        local halo = UI.Sprite(bar, "radial", {
            Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5), ImageTransparency = 0.45,
        })
        UI.BindAccent(function() halo.ImageColor3 = Theme.Accent end)
        local knob = new("Frame", {
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
        }, bar)
        corner(knob, 7)
        local knobRing = stroke(knob, Theme.Accent, 2.5, 0)
        UI.BindAccent(function()
            knobRing.Color = Theme.Accent
            box.TextColor3 = Theme.Accent
        end)

        local obj = { Value = def.Default or min }
        local function normalize(v)
            v = math.floor((v - min) / step + 0.5) * step + min
            return math.clamp(v, min, max)
        end
        function obj:Set(v, silent)
            if type(v) ~= "number" then return end
            v = normalize(v)
            self.Value = v
            local a = (max > min) and (v - min) / (max - min) or 0
            fill.Size = UDim2.fromScale(a, 1)
            knob.Position = UDim2.fromScale(a, 0.5)
            halo.Position = UDim2.fromScale(a, 0.5)
            box.Text = fmtValue(v) .. suffix
            if not silent and def.Callback then task.spawn(def.Callback, v) end
        end
        function obj:Get() return self.Value end

        local dragging = false
        local function fromInput(input)
            local a = math.clamp((input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
            obj:Set(min + a * (max - min))
        end
        hit.InputBegan:Connect(function(input)
            if isPointer(input) then
                dragging = true
                tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.12)
                tween(halo, { Size = UDim2.fromOffset(56, 56), ImageTransparency = 0.25 }, 0.15)
                fromInput(input)
            end
        end)
        Hub.Track(UIS.InputChanged:Connect(function(input)
            if dragging and isMove(input) then fromInput(input) end
        end))
        Hub.Track(UIS.InputEnded:Connect(function(input)
            if isPointer(input) and dragging then
                dragging = false
                tween(knob, { Size = UDim2.fromOffset(14, 14) }, 0.12)
                tween(halo, { Size = UDim2.fromOffset(40, 40), ImageTransparency = 0.45 }, 0.15)
            end
        end))
        box.FocusLost:Connect(function()
            local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
            obj:Set(n or obj.Value)
        end)

        obj:Set(obj.Value, true)
        if def.Flag then Hub.RegisterFlag(def.Flag, function() return obj.Value end, function(v) obj:Set(v) end) end
        return obj
    end

    function Section:Buttons(defs)
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(self),
        }, self.Card)
        list(row, 6, Enum.FillDirection.Horizontal)
        local n = #defs
        local out = {}
        for i, d in ipairs(defs) do
            local slot = new("Frame", {
                Size = UDim2.new(1 / n, -(6 * (n - 1)) / n, 1, 0),
                BackgroundTransparency = 1,
                LayoutOrder = i,
            }, row)
            local glow
            if d.Primary or d.Danger then
                glow = UI.Halo(slot, "glow_s", { Transparency = 0.6, Color = d.Danger and Theme.Bad or nil })
            end
            local fill = new("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundColor3 = d.Primary and Color3.new(1, 1, 1) or (d.Danger and Theme.Bad or Theme.Row),
                BorderSizePixel = 0,
                ZIndex = 1,
            }, slot)
            corner(fill, 9)
            if d.Primary then
                accentGradient(fill, 0, 0.3)
            elseif not d.Danger then
                stroke(fill, Theme.Stroke, 1, 0.3)
            end
            local hasIcon = d.Icon and UI.IconNames[d.Icon]
            local b = new("TextButton", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = d.Text,
                Font = FONT_BOLD, TextSize = 13,
                TextColor3 = (d.Primary or d.Danger) and Color3.new(1, 1, 1) or Theme.Text,
                ZIndex = 2,
            }, slot)
            if hasIcon then
                UI.Icon(b, d.Icon, {
                    Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0, 0.5),
                    Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 3,
                    ImageColor3 = (d.Primary or d.Danger) and Color3.new(1, 1, 1) or Theme.Sub,
                })
                pad(b, 0, 0, 0, 14)
            end
            local function hover(on)
                if glow then tween(glow, { ImageTransparency = on and 0.3 or 0.6 }, 0.15) end
                if d.Primary then
                    tween(fill, { BackgroundTransparency = on and 0.15 or 0 }, 0.12)
                elseif d.Danger then
                    tween(fill, { BackgroundColor3 = on and Theme.Bad:Lerp(Color3.new(1, 1, 1), 0.15) or Theme.Bad }, 0.12)
                else
                    tween(fill, { BackgroundColor3 = on and Theme.RowHover or Theme.Row }, 0.12)
                end
            end
            b.MouseEnter:Connect(function() hover(true) end)
            b.MouseLeave:Connect(function() hover(false) end)
            b.MouseButton1Click:Connect(function()
                if d.Callback then task.spawn(d.Callback) end
            end)
            out[i] = b
        end
        return out
    end

    function Section:Button(d)
        return self:Buttons({ { Text = d.Name or d.Text, Primary = d.Primary, Danger = d.Danger,
            Callback = d.Callback } })[1]
    end

    function Section:TextBox(def)
        local row = rowFrame(self, 34, false)
        local tb = new("TextBox", {
            Size = UDim2.new(1, -16, 1, -10),
            Position = UDim2.fromOffset(8, 5),
            BackgroundTransparency = 1,
            Text = def.Default or "",
            PlaceholderText = def.Placeholder or def.Name or "",
            PlaceholderColor3 = Theme.Sub,
            Font = FONT, TextSize = 14, TextColor3 = Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
        }, row)
        local line = stroke(row, Theme.Row, 1)
        tb.Focused:Connect(function() line.Color = Theme.Accent end)
        tb.FocusLost:Connect(function(enter)
            line.Color = Theme.Row
            if def.Callback then task.spawn(def.Callback, tb.Text, enter) end
        end)
        local obj = { Box = tb }
        function obj:Get() return tb.Text end
        function obj:Set(v) tb.Text = tostring(v or "") end
        return obj
    end

    function Section:Label(text, color)
        local l = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = text,
            Font = FONT, TextSize = 13, TextColor3 = color or Theme.Sub,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = nextOrder(self),
        }, self.Card)
        local obj = { Instance = l }
        function obj:Set(t, c)
            l.Text = t
            if c then l.TextColor3 = c end
        end
        return obj
    end

    function Section:Custom(height)
        return new("Frame", {
            Size = UDim2.new(1, 0, 0, height),
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(self),
        }, self.Card)
    end

    function Section:Dropdown(def)
        local holder = new("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = nextOrder(self),
        }, self.Card)
        list(holder, 4)

        local head = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Theme.Row,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = 1,
        }, holder)
        corner(head, 6)
        hoverable(head)
        rowLabel(head, def.Name, 8, 20)
        local valueL = new("TextLabel", {
            Size = UDim2.new(0, 120, 1, 0),
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -30, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.Sub,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, head)
        local arrow = UI.Icon(head, "chevron_down", {
            Size = UDim2.fromOffset(14, 14),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            ImageColor3 = Theme.Sub,
        })

        local listFrame = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Off,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            LayoutOrder = 2,
        }, holder)
        corner(listFrame, 6)
        list(listFrame, 2)
        pad(listFrame, 4, 4, 4, 4)

        local obj = { Value = def.Default, Options = def.Options or {}, Open = false }
        local optionButtons = {}

        local function paintOptions()
            for _, ob in ipairs(optionButtons) do
                local sel = ob.name == obj.Value
                ob.btn.BackgroundColor3 = sel and Theme.Accent or Theme.Card
                ob.btn.TextColor3 = sel and Color3.new(1, 1, 1) or Theme.Text
            end
        end
        UI.BindAccent(paintOptions)

        local function setOpen(v)
            obj.Open = v
            listFrame.Visible = v
            UI.SetIcon(arrow, v and "chevron_up" or "chevron_down")
            listFrame.Size = UDim2.new(1, 0, 0, math.min(#obj.Options, 5) * 26 + 8)
        end

        function obj:SetOptions(opts)
            self.Options = opts
            for _, ob in ipairs(optionButtons) do ob.btn:Destroy() end
            table.clear(optionButtons)
            for i, name in ipairs(opts) do
                local b = new("TextButton", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundColor3 = Theme.Card,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = name,
                    Font = FONT, TextSize = 13, TextColor3 = Theme.Text,
                    LayoutOrder = i,
                }, listFrame)
                corner(b, 5)
                b.MouseButton1Click:Connect(function()
                    self:Set(name)
                    setOpen(false)
                end)
                optionButtons[#optionButtons + 1] = { name = name, btn = b }
            end
            if self.Value and not table.find(opts, self.Value) then
                self.Value = nil
                valueL.Text = "—"
            end
            paintOptions()
            if self.Open then setOpen(true) end
        end

        function obj:Set(v, silent)
            if type(v) ~= "string" then return end
            self.Value = v
            valueL.Text = v
            paintOptions()
            if not silent and def.Callback then task.spawn(def.Callback, v) end
        end
        function obj:Get() return self.Value end

        head.MouseButton1Click:Connect(function() setOpen(not obj.Open) end)

        obj:SetOptions(obj.Options)
        valueL.Text = obj.Value or "—"
        if def.Flag then
            Hub.RegisterFlag(def.Flag, function() return obj.Value end, function(v) obj:Set(v) end)
        end
        return obj
    end

    function Section:Keybind(def)
        local row = rowFrame(self, 36, false)
        rowLabel(row, def.Name, 8, 20)
        local btn = new("TextButton", {
            Size = UDim2.fromOffset(96, 24),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            BackgroundColor3 = Theme.Bg,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            Font = FONT_BOLD, TextSize = 13, TextColor3 = Theme.Text,
        }, row)
        corner(btn, 5)

        local obj = { Value = def.Default or Enum.KeyCode.RightShift, Listening = false }
        local win = def.Window
        local function paint()
            btn.Text = obj.Listening and "..." or obj.Value.Name
        end
        function obj:Set(v, silent)
            if type(v) == "string" then v = Enum.KeyCode[v] end
            if typeof(v) ~= "EnumItem" then return end
            self.Value = v
            paint()
            if not silent and def.Callback then task.spawn(def.Callback, v) end
        end
        function obj:Get() return self.Value end

        btn.MouseButton1Click:Connect(function()
            obj.Listening = true
            if win then win.Listening = true end
            paint()
        end)
        Hub.Track(UIS.InputBegan:Connect(function(input)
            if not obj.Listening or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            obj.Listening = false
            task.defer(function() if win then win.Listening = false end end)
            if input.KeyCode ~= Enum.KeyCode.Escape then obj:Set(input.KeyCode) else paint() end
        end))

        paint()
        if def.Flag then
            Hub.RegisterFlag(def.Flag, function() return obj.Value.Name end, function(v) obj:Set(v) end)
        end
        return obj
    end

    return UI
end

