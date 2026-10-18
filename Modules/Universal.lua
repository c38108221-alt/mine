return function(Hub)
    local UI, S = Hub.UI, Hub.Services
    local Theme = UI.Theme
    local new, corner, Format, FormatTime = UI.New, UI.Corner, UI.Format, UI.FormatTime
    local RunService, UIS, Lighting, Players = S.RunService, S.UserInputService, S.Lighting, S.Players

    local State = { fpsOn = false, fps = 60, reduce = false, alt = false, altFps = 10, alts = true }

    local originalFps = 60
    pcall(function()
        if type(getfpscap) == "function" then
            local v = getfpscap()
            if type(v) == "number" and v > 0 then originalFps = v end
        end
    end)

    local focused, altActive = true, false

    local function applyFps()
        if type(setfpscap) ~= "function" then return end
        local cap
        if altActive then
            cap = State.fpsOn and math.min(State.fps, State.altFps) or State.altFps
        elseif State.fpsOn then
            cap = State.fps
        else
            cap = originalFps
        end
        pcall(setfpscap, cap)
    end

    local overlayGui = UI.NewGui("ScriptHubOverlay", 2147482000)
    local overlay = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(6, 6, 9),
        BorderSizePixel = 0,
        Active = true,
        Visible = false,
    }, overlayGui)

    local card = new("Frame", {
        Size = UDim2.fromOffset(360, 190),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    }, overlay)
    corner(card, 14)
    UI.Stroke(card)

    local pill = new("TextLabel", {
        Size = UDim2.fromOffset(130, 22),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 18),
        Text = "ALT MODE ENABLED",
        Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, card)
    corner(pill, 11)
    UI.BindAccent(function() pill.BackgroundColor3 = Theme.Accent end)

    local function ovLabel(y, h, size, font, color)
        return new("TextLabel", {
            Size = UDim2.new(1, -24, 0, h),
            Position = UDim2.fromOffset(12, y),
            BackgroundTransparency = 1,
            Text = "",
            Font = font, TextSize = size, TextColor3 = color,
        }, card)
    end
    local ovName = ovLabel(50, 20, 14, Enum.Font.GothamBold, Theme.Sub)
    local ovTimer = ovLabel(72, 44, 36, Enum.Font.GothamBold, Theme.Text)
    local ovStats = ovLabel(124, 20, 13, Enum.Font.GothamMedium, Theme.Sub)
    local ovHint = ovLabel(154, 18, 11, Enum.Font.GothamMedium, Theme.Off)
    ovName.Text = Hub.Player.Name
    ovHint.Text = "Window not focused · 3D rendering paused"

    local function updateOverlay()
        local st = Hub.Tracker.Stats()
        ovTimer.Text = FormatTime(st.elapsed)
        if st.coins then
            ovStats.Text = ("%s coins   ·   +%s   ·   %s/h"):format(Format(st.coins), Format(st.farmed), Format(st.cph))
        else
            ovStats.Text = ("+%s coins   ·   %s/h"):format(Format(st.farmed), Format(st.cph))
        end
    end

    local function applyAlt()
        local active = State.alt and not focused
        Hub.Tracker.Meta.Focused = focused
        Hub.Tracker.Meta.AltMode = active
        if active == altActive then return end
        altActive = active
        pcall(RunService.Set3dRenderingEnabled, RunService, not active)
        overlay.Visible = active
        if active then pcall(updateOverlay) end
        applyFps()
    end

    Hub.Track(UIS.WindowFocused:Connect(function() focused = true applyAlt() end))
    Hub.Track(UIS.WindowFocusReleased:Connect(function() focused = false applyAlt() end))

    local origProps = setmetatable({}, { __mode = "k" })
    local origTech, origQuality, origDeco, decoTerrain

    local function stash(inst, prop, value)
        local t = origProps[inst]
        if not t then
            t = {}
            origProps[inst] = t
        end
        if t[prop] == nil then
            local ok, cur = pcall(function() return inst[prop] end)
            if not ok then return end
            t[prop] = cur
        end
        pcall(function() inst[prop] = value end)
    end

    local EFFECT_CLASSES = {
        "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles",
        "PointLight", "SpotLight", "SurfaceLight", "PostEffect", "Clouds", "Highlight",
    }

    local function reduceInstance(inst)
        if inst:IsA("BasePart") then
            if inst:IsA("Terrain") then return end
            stash(inst, "Material", Enum.Material.SmoothPlastic)
            stash(inst, "Reflectance", 0)
            stash(inst, "CastShadow", false)
            if inst:IsA("MeshPart") then
                stash(inst, "RenderFidelity", Enum.RenderFidelity.Performance)
            end
        elseif inst:IsA("Decal") then
            stash(inst, "Transparency", 1)
        elseif inst:IsA("Atmosphere") then
            stash(inst, "Density", 0)
            stash(inst, "Haze", 0)
        else
            for _, cls in ipairs(EFFECT_CLASSES) do
                if inst:IsA(cls) then
                    stash(inst, "Enabled", false)
                    return
                end
            end
        end
    end

    local function applyGlobalReduce()
        stash(Lighting, "GlobalShadows", false)
        stash(Lighting, "ShadowSoftness", 0)

        pcall(function()
            if sethiddenproperty and gethiddenproperty then
                if origTech == nil then origTech = gethiddenproperty(Lighting, "Technology") end
                sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
            end
        end)

        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            stash(terrain, "WaterWaveSize", 0)
            stash(terrain, "WaterWaveSpeed", 0)
            stash(terrain, "WaterReflectance", 0)
            pcall(function()
                if sethiddenproperty and gethiddenproperty then
                    if origDeco == nil then
                        origDeco = gethiddenproperty(terrain, "Decoration")
                        decoTerrain = terrain
                    end
                    sethiddenproperty(terrain, "Decoration", false)
                end
            end)
        end

        pcall(function()
            local r = settings().Rendering
            if origQuality == nil then origQuality = r.QualityLevel end
            r.QualityLevel = Enum.QualityLevel.Level01
        end)
    end

    local function restoreAll()
        for inst, props in pairs(origProps) do
            for prop, v in pairs(props) do
                pcall(function() inst[prop] = v end)
            end
        end
        table.clear(origProps)

        pcall(function()
            if origTech ~= nil then sethiddenproperty(Lighting, "Technology", origTech) end
        end)
        origTech = nil

        pcall(function()
            if origDeco ~= nil and decoTerrain then sethiddenproperty(decoTerrain, "Decoration", origDeco) end
        end)
        origDeco, decoTerrain = nil, nil

        pcall(function()
            if origQuality ~= nil then settings().Rendering.QualityLevel = origQuality end
        end)
        origQuality = nil
    end

    local reduceToken, reduceConns = 0, {}

    local function setReduce(on)
        reduceToken = reduceToken + 1
        local token = reduceToken

        for _, c in ipairs(reduceConns) do pcall(function() c:Disconnect() end) end
        reduceConns = {}

        if not on then
            restoreAll()
            return
        end

        applyGlobalReduce()
        local roots = { workspace, Lighting }
        for _, root in ipairs(roots) do
            reduceConns[#reduceConns + 1] = root.DescendantAdded:Connect(reduceInstance)
        end

        task.spawn(function()
            for _, root in ipairs(roots) do
                local all = root:GetDescendants()
                for i, inst in ipairs(all) do
                    if token ~= reduceToken then return end
                    reduceInstance(inst)
                    if i % 300 == 0 then task.wait() end
                end
            end
        end)
    end

    local ROW_H, ROW_GAP, HEAD_H, WIDTH = 46, 4, 34, 390
    local MAX_ROWS_VISIBLE = 8 -- max visible rows before scroll kicks in

    local altsFrame = new("Frame", {
        Name = "AltsList",
        Size = UDim2.fromOffset(WIDTH, HEAD_H + 8),
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -20, 0, 60),
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        Active = true,
        Visible = State.alts,
    }, UI.Root)
    corner(altsFrame, 10)
    UI.Stroke(altsFrame)
    UI.RegisterGlass(altsFrame)
    UI.RegisterScale(new("UIScale", {}, altsFrame))

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, HEAD_H),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
    }, altsFrame)
    UI.Draggable(head, altsFrame)
    local headDot = new("Frame", {
        Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 13),
        BorderSizePixel = 0,
    }, head)
    corner(headDot, 4)
    UI.BindAccent(function() headDot.BackgroundColor3 = Theme.Accent end)
    new("TextLabel", {
        Size = UDim2.fromOffset(80, 34), Position = UDim2.fromOffset(30, 0),
        BackgroundTransparency = 1, Text = "Alts",
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, head)
    local headInfo = new("TextLabel", {
        Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(76, 0),
        BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Theme.Sub,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, head)

    local rowsFrame = new("ScrollingFrame", {
        Size = UDim2.new(1, -12, 1, -HEAD_H - 4),
        Position = UDim2.fromOffset(6, HEAD_H),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Sub,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, altsFrame)
    UI.List(rowsFrame, ROW_GAP)

    local rows, thumbCache = {}, {}

    local function loadAvatar(userId, img)
        if not userId then return end
        if thumbCache[userId] then
            img.Image = thumbCache[userId]
            return
        end
        task.spawn(function()
            local ok, content = pcall(Players.GetUserThumbnailAsync, Players, userId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            if ok and content then
                thumbCache[userId] = content
                if img.Parent then img.Image = content end
            end
        end)
    end

    local function rowLabel(parent, pos, size, bold, textSize, align)
        return new("TextLabel", {
            Position = pos, Size = size,
            BackgroundTransparency = 1, Text = "",
            Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
            TextSize = textSize, TextColor3 = Theme.Text,
            TextXAlignment = align,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, parent)
    end

    local function createRow()
        local row = new("Frame", {
            Size = UDim2.new(1, 0, 0, ROW_H),
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
        }, rowsFrame)
        corner(row, 8)
        local avatar = new("ImageLabel", {
            Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(7, 6),
            BackgroundColor3 = Theme.Off, BorderSizePixel = 0,
        }, row)
        corner(avatar, 17)
        local dot = new("Frame", {
            Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(32, 31),
            BorderSizePixel = 0, BackgroundColor3 = Theme.Good,
        }, row)
        corner(dot, 5)
        UI.Stroke(dot, Theme.Card, 2)
        local L = Enum.TextXAlignment.Left
        local R = Enum.TextXAlignment.Right
        return {
            row = row, avatar = avatar, dot = dot,
            nameL = rowLabel(row, UDim2.fromOffset(48, 6), UDim2.new(1, -170, 0, 16), true, 13, L),
            statusL = rowLabel(row, UDim2.fromOffset(48, 24), UDim2.new(1, -170, 0, 16), false, 12, L),
            balL = rowLabel(row, UDim2.new(1, -122, 0, 6), UDim2.fromOffset(112, 16), true, 13, R),
            statL = rowLabel(row, UDim2.new(1, -122, 0, 24), UDim2.fromOffset(112, 16), false, 12, R),
        }
    end

    local function refreshAlts()
        local data = Hub.Tracker.ReadAll()
        local seen, live = {}, 0

        for i, d in ipairs(data) do
            local name = tostring(d.Name)
            seen[name] = true
            local r = rows[name]
            if not r then
                r = createRow()
                rows[name] = r
                loadAvatar(d.UserId, r.avatar)
            end
            r.row.LayoutOrder = i
            r.nameL.Text = name
            local elapsed = (d.Live and os.time() or (d.Updated or 0)) - (d.Added or 0)
            if d.Live then
                live = live + 1
                r.statusL.Text = (d.AltMode and "Live · Alt mode · " or "Live · ") .. FormatTime(elapsed)
                r.statusL.TextColor3 = Theme.Good
                r.dot.BackgroundColor3 = d.AltMode and Theme.Warn or Theme.Good
            else
                r.statusL.Text = "Offline · " .. FormatTime(elapsed)
                r.statusL.TextColor3 = Theme.Sub
                r.dot.BackgroundColor3 = Theme.Off
            end
            r.balL.Text = d.Coins and (Format(d.Coins) .. " coins") or "— coins"
            r.statL.Text = ("+%s  ·  %s/h"):format(Format(d.Farmed), Format(d.CPH))
            r.statL.TextColor3 = Theme.Sub
        end

        for name, r in pairs(rows) do
            if not seen[name] then
                r.row:Destroy()
                rows[name] = nil
            end
        end

        headInfo.Text = ("%d live · %d total"):format(live, #data)
        local visRows = math.min(#data, MAX_ROWS_VISIBLE)
        local rowsH = visRows > 0 and (visRows * ROW_H + math.max(0, visRows - 1) * ROW_GAP) or 0
        altsFrame.Size = UDim2.fromOffset(WIDTH, HEAD_H + 8 + rowsH)
    end

    local tab = Hub.Window:AddTab({ Name = "Universal", Icon = "globe" })

    local perf = tab:AddSection("Performance")
    perf:Toggle({
        Name = "FPS limit", Description = "Caps the client FPS using the slider below",
        Flag = "fpsLimit.enabled", Default = State.fpsOn,
        Callback = function(v) State.fpsOn = v applyFps() end,
    })
    perf:Slider({
        Name = "FPS limit", Flag = "fpsLimit.value",
        Min = 5, Max = 240, Default = State.fps,
        Callback = function(v) State.fps = v applyFps() end,
    })
    perf:Toggle({
        Name = "Reduce FPS", Description = "Minimal graphics, no VFX or extra effects",
        Flag = "reduceFps.enabled", Default = State.reduce,
        Callback = function(v) State.reduce = v setReduce(v) end,
    })

    local alt = tab:AddSection("Alt mode")
    alt:Toggle({
        Name = "Alt mode", Description = "When the window loses focus: 3D is disabled, FPS is capped, overlay is shown",
        Flag = "altMode.enabled", Default = State.alt,
        Callback = function(v) State.alt = v applyAlt() end,
    })
    alt:Slider({
        Name = "Alt mode FPS", Flag = "altMode.fps",
        Min = 1, Max = 30, Default = State.altFps,
        Callback = function(v) State.altFps = v applyFps() end,
    })

    local alts = tab:AddSection("Alts list")
    alts:Toggle({
        Name = "Alts list", Description = "Mini window listing every active account on this PC",
        Flag = "altsList.enabled", Default = State.alts,
        Callback = function(v)
            State.alts = v
            altsFrame.Visible = v
            if v then pcall(refreshAlts) end
        end,
    })
    alts:Label("List is stored in workspace/" .. Hub.Folder .. "/alts. An entry is removed when the client closes.")

    Hub.OnUnload(function()
        pcall(setReduce, false)
        pcall(RunService.Set3dRenderingEnabled, RunService, true)
        if type(setfpscap) == "function" then pcall(setfpscap, originalFps) end
    end)

    applyFps()
    applyAlt()

    task.spawn(function()
        while Hub.Alive do
            if State.alts then pcall(refreshAlts) end
            task.wait(2)
        end
    end)

    task.spawn(function()
        while Hub.Alive do
            if altActive then pcall(updateOverlay) end
            task.wait(1)
        end
    end)
end

