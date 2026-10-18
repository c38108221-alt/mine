return function(Hub)
    local S = Hub.Services
    local RunService, UIS = S.RunService, S.UserInputService
    local LocalPlayer = Hub.Player

    local State = {
        fly = false, flySpeed = 60,
        speed = false, walkSpeed = 50,
        noclip = false,
        jump = false, jumpPower = 100,
    }

    local function getChar()
        local char = LocalPlayer.Character
        return char, char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
    end

    local flyConn, flyStep = nil, nil
    local flyCF = nil

    local function stopFly()
        for _, c in ipairs({ flyConn, flyStep }) do
            if c then c:Disconnect() end
        end
        flyConn, flyStep, flyCF = nil, nil, nil
        local _, hum, hrp = getChar()
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
        end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    end

    local function startFly()
        if flyConn then return end
        local _, _, hrp0 = getChar()
        flyCF = hrp0 and hrp0.CFrame

        flyConn = RunService.Heartbeat:Connect(function(dt)
            local _, hum, hrp = getChar()
            local cam = workspace.CurrentCamera
            if not (hum and hrp and cam and hum.Health > 0) then return end

            if not flyCF or (flyCF.Position - hrp.Position).Magnitude > 15 then flyCF = hrp.CFrame end

            hum.PlatformStand = true
            hum.AutoRotate = false

            local move = hum.MoveDirection
            local look = cam.CFrame.LookVector
            local flatLook = Vector3.new(look.X, 0, look.Z)
            if flatLook.Magnitude < 0.01 then flatLook = flyCF.LookVector end
            flatLook = flatLook.Unit
            local vertical = 0

            if move.Magnitude > 0 then
                vertical = look.Y * move:Dot(flatLook)
            end
            if not UIS:GetFocusedTextBox() then
                if UIS:IsKeyDown(Enum.KeyCode.Space) then vertical += 1 end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
                    vertical -= 1
                end
            end

            local dir = Vector3.new(move.X, vertical, move.Z)
            if dir.Magnitude > 1 then dir = dir.Unit end

            local pos = flyCF.Position + dir * State.flySpeed * dt
            flyCF = CFrame.lookAt(pos, pos + flatLook)
            hrp.CFrame = flyCF
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        flyStep = RunService.Stepped:Connect(function()
            local _, _, hrp = getChar()
            if hrp and flyCF then
                hrp.CFrame = flyCF
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
    end

    local function setFly(on)
        State.fly = on
        if on then startFly() else stopFly() end
    end

    local original = {}

    local function remember(hum)
        if not original[hum] then
            original[hum] = { walk = hum.WalkSpeed, power = hum.JumpPower, use = hum.UseJumpPower }
        end
        return original[hum]
    end

    local statConn = RunService.Heartbeat:Connect(function()
        local _, hum = getChar()
        if not hum then return end
        if State.speed then
            remember(hum)
            hum.WalkSpeed = State.walkSpeed
        end
        if State.jump then
            remember(hum)
            hum.UseJumpPower = true
            hum.JumpPower = State.jumpPower
        end
    end)
    Hub.Track(statConn)

    local function restoreSpeed()
        local _, hum = getChar()
        local o = hum and original[hum]
        if o then hum.WalkSpeed = o.walk end
    end

    local function restoreJump()
        local _, hum = getChar()
        local o = hum and original[hum]
        if o then
            hum.UseJumpPower = o.use
            hum.JumpPower = o.power
        end
    end

    local noclipConn = nil
    local collide = {}

    local function setNoclip(on)
        State.noclip = on
        if on then
            if noclipConn then return end
            noclipConn = RunService.Stepped:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        collide[p] = true
                        p.CanCollide = false
                    end
                end
            end)
        else
            if noclipConn then
                noclipConn:Disconnect()
                noclipConn = nil
            end
            for part in pairs(collide) do
                if part and part.Parent then part.CanCollide = true end
            end
            collide = {}
        end
    end

    local tab = Hub.Window:AddTab({ Name = "Player", Icon = "person" })

    local move = tab:AddSection("Movement")
    move:Toggle({
        Name = "Fly", Description = "Flying: Space to go up, Ctrl / Shift to go down",
        Flag = "player.fly", Default = State.fly, Callback = setFly,
    })
    move:Slider({
        Name = "Fly speed", Flag = "player.flySpeed",
        Min = 10, Max = 200, Default = State.flySpeed, Suffix = " st/s",
        Callback = function(v) State.flySpeed = v end,
    })
    move:Toggle({
        Name = "Speed", Description = "Character speed, set by the slider below",
        Flag = "player.speed", Default = State.speed,
        Callback = function(v)
            State.speed = v
            if not v then restoreSpeed() end
        end,
    })
    move:Slider({
        Name = "Character speed", Flag = "player.walkSpeed",
        Min = 16, Max = 200, Default = State.walkSpeed,
        Callback = function(v) State.walkSpeed = v end,
    })

    local misc = tab:AddSection("Physics")
    misc:Toggle({
        Name = "Noclip", Description = "Walk through walls",
        Flag = "player.noclip", Default = State.noclip, Callback = setNoclip,
    })
    misc:Toggle({
        Name = "High jump", Description = "Jump power, set by the slider below",
        Flag = "player.jump", Default = State.jump,
        Callback = function(v)
            State.jump = v
            if not v then restoreJump() end
        end,
    })
    misc:Slider({
        Name = "Jump power", Flag = "player.jumpPower",
        Min = 50, Max = 300, Default = State.jumpPower,
        Callback = function(v) State.jumpPower = v end,
    })

    Hub.OnUnload(function()
        State.speed, State.jump = false, false
        restoreSpeed()
        restoreJump()
        setFly(false)
        setNoclip(false)
    end)
end

