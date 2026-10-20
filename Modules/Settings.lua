return function(Hub)
    local UI, Config = Hub.UI, Hub.Config
    local Theme = UI.Theme
    local win = Hub.Window

    local tab = win:AddTab({ Name = "Settings", Icon = "gear" })

    local cfg = tab:AddSection("Configs")
    local selected = nil
    local nameBox, dropdown, autoLabel

    local function refresh()
        local names = Config.List()
        dropdown:SetOptions(names)
        local auto = Config.GetAutoload()
        autoLabel:Set("Autoload: " .. (auto or "off"), auto and Theme.Good or Theme.Sub)
    end

    local function report(ok, res, okText)
        if ok then
            UI.Notify({ Title = okText, Text = res, Type = "good", Duration = 3 })
        else
            UI.Notify({ Title = "Error", Text = tostring(res), Type = "bad", Duration = 4 })
        end
    end

    local function currentName()
        local n = Config.CleanName(nameBox:Get())
        if n == "" and selected then n = selected end
        return n
    end

    dropdown = cfg:Dropdown({
        Name = "Saved configs", Options = {},
        Callback = function(name)
            selected = name
            nameBox:Set(name)
        end,
    })
    nameBox = cfg:TextBox({ Placeholder = "Config name" })

    cfg:Buttons({
        { Text = "Create / Save", Icon = "save", Primary = true, Callback = function()
            local ok, res = Config.Save(currentName())
            if ok then
                selected = res
                nameBox:Set(res)
            end
            report(ok, res, "Config saved")
            refresh()
            if ok then dropdown:Set(res, true) end
        end },
        { Text = "Load", Icon = "load", Callback = function()
            local ok, res = Config.Load(currentName())
            if ok then selected = res end
            report(ok, res, "Config loaded")
        end },
        { Text = "Delete", Icon = "trash", Danger = true, Callback = function()
            local ok, res = Config.Delete(currentName())
            if ok then
                selected = nil
                nameBox:Set("")
            end
            report(ok, res, "Config deleted")
            refresh()
        end },
    })

    local auto = tab:AddSection("Autoload")
    autoLabel = auto:Label("")
    auto:Buttons({
        { Text = "Set autoload", Icon = "check", Primary = true, Callback = function()
            local ok, res = Config.SetAutoload(currentName())
            report(ok, res, "Autoload set")
            refresh()
        end },
        { Text = "Clear", Icon = "close", Callback = function()
            Config.ClearAutoload()
            UI.Notify({ Title = "Autoload turned off", Duration = 3 })
            refresh()
        end },
    })

    local ui = tab:AddSection("Interface")

    local swatchRow = ui:Custom(30)
    UI.List(swatchRow, 10, Enum.FillDirection.Horizontal)
    UI.Pad(swatchRow, 4, 0, 0, 4)
    local strokes = {}
    for i, a in ipairs(UI.Accents) do
        local b = UI.New("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            BackgroundColor3 = a.Color,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = i,
        }, swatchRow)
        UI.Corner(b, 11)
        if a.Rainbow then
            b.BackgroundColor3 = Color3.new(1, 1, 1)
            UI.New("UIGradient", {
                Rotation = 45,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
                    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 200, 60)),
                    ColorSequenceKeypoint.new(0.65, Color3.fromRGB(60, 220, 160)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 110, 255)),
                }),
            }, b)
        end
        strokes[a.Name] = UI.Stroke(b, Color3.new(1, 1, 1), 2, 1)
        b.MouseButton1Click:Connect(function() UI.SetAccent(a.Name) end)
    end
    UI.BindAccent(function()
        for name, s in pairs(strokes) do s.Transparency = (name == UI.AccentName) and 0 or 1 end
    end)
    Hub.RegisterFlag("ui.accent", function() return UI.AccentName end, function(v) UI.SetAccent(v) end)

    ui:Toggle({
        Name = "Performance mode",
        Description = "Скрывает эффекты (glow, shadow, градиенты) — снижает нагрузку на GPU и VRAM. Рекомендуется при ночном фарме",
        Flag = "ui.perfMode", Default = false,
        Callback = UI.SetPerfMode,
    })
    local transparency = ui:Slider({
        Name = "UI transparency", Flag = "ui.transparency",
        Min = 0, Max = 60, Default = 0, Suffix = "%",
        Callback = UI.SetTransparency,
    })
    local scale = ui:Slider({
        Name = "UI scale", Flag = "ui.scale",
        Min = 70, Max = 130, Default = 100, Suffix = "%",
        Callback = UI.SetScale,
    })
    ui:Keybind({
        Name = "Menu key", Flag = "ui.menuKey", Window = win,
        Default = win.Key,
        Callback = function(key) win:SetKey(key) end,
    })
    ui:Buttons({
        { Text = "Reset UI", Callback = function()
            UI.SetAccent("Indigo")
            transparency:Set(0)
            scale:Set(100)
        end },
    })

    local hub = tab:AddSection("Hub")
    hub:Label(("%s v%s · player %s"):format(Hub.Name, Hub.Version, Hub.Player.Name))
    hub:Buttons({
        { Text = "Unload", Icon = "power", Danger = true, Callback = function() Hub.Unload() end },
    })

    tab.OnShow = refresh
    refresh()
end

