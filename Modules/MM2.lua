return function(Hub)
    local RunService = Hub.Services.RunService
    local LocalPlayer = Hub.Player

    local State = {
        farm = false,
        speed = 20,
        offset = 3,
        sharpReturn = true,
        grabGun = true,
        killAllFull = false,
        killMurderFull = false,
        flingOut = false,
        bagFull = false,
        effSpeed = 0,
        rejoinEmpty = false,
        rejoinKick = false,
        closeOnKick = false,
        autoFlingSheriff = false,
    }
    local blacklist = {}

    local function isWaiting()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("MainGUI")
        local game_ = main and main:FindFirstChild("Game")
        local w = game_ and game_:FindFirstChild("Waiting")
        return w ~= nil and w.Visible == true
    end

    -- declared before canFarm() so it can reference both
    local flingSheriffing = false
    local flinging = false

    local function canFarm()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return hum ~= nil and hum.Health > 0 and not isWaiting() and not flingSheriffing and not flinging
    end

    local function getContainer()
        for _, child in ipairs(workspace:GetChildren()) do
            local c = child:FindFirstChild("CoinContainer")
            if c then return c end
        end
    end

    local function coinPosition(obj)
        if obj:IsA("BasePart") then return obj.Position end
        if obj:IsA("Model") then return obj:GetPivot().Position end
    end

    local seenTouch = setmetatable({}, { __mode = "k" })
    local function coinValid(coin)
        if not coin or not coin.Parent or not coin:IsDescendantOf(workspace) then return false end
        if coin:GetAttribute("Collected") or coin:GetAttribute("collected") then return false end
        if coin:FindFirstChildWhichIsA("TouchInterest") then
            seenTouch[coin] = true
        elseif seenTouch[coin] then
            return false
        end
        return true
    end

    local CLUSTER_RADIUS = 25
    local CLUSTER_WEIGHT = 2
    local CLUSTER_MAX = 10

    local function getNearestCoin(hrp)
        local container = getContainer()
        if not container then return end

        local list = {}
        for _, obj in ipairs(container:GetDescendants()) do
            if obj.Name == "Coin_Server" and not blacklist[obj] and coinValid(obj) then
                local pos = coinPosition(obj)
                if pos then list[#list + 1] = { obj = obj, pos = pos } end
            end
        end

        local best, bestScore, bestPos
        for i, c in ipairs(list) do
            local neighbors = 0
            for j, o in ipairs(list) do
                if i ~= j and (o.pos - c.pos).Magnitude <= CLUSTER_RADIUS then neighbors += 1 end
            end
            local score = (c.pos - hrp.Position).Magnitude - CLUSTER_WEIGHT * math.min(neighbors, CLUSTER_MAX)
            if not bestScore or score < bestScore then
                best, bestScore, bestPos = c.obj, score, c.pos
            end
        end
        return best, bestPos
    end

    local noclipConn = nil
    local originalCollide = {}

    local function enableNoclip()
        if noclipConn then return end
        noclipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    if originalCollide[p] == nil then originalCollide[p] = p.CanCollide end
                    p.CanCollide = false
                end
            end
        end)
    end

    local function disableNoclip()
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        for part, state in pairs(originalCollide) do
            if part and part.Parent then part.CanCollide = state end
        end
        originalCollide = {}
    end

    local holdConn, holdCF = nil, nil

    local function startHold()
        if holdConn then return end
        holdConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local h = char and char:FindFirstChild("HumanoidRootPart")
            if h and holdCF and State.farm and canFarm() then
                h.CFrame = holdCF
                h.AssemblyLinearVelocity = Vector3.zero
                h.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end

    local function stopHold()
        if holdConn then
            holdConn:Disconnect()
            holdConn = nil
        end
        holdCF = nil
    end

    local function flyTo(hrp, cf, duration, coin)
        startHold()
        local startCF = hrp.CFrame
        local elapsed = 0
        coinValid(coin)

        while elapsed < duration and coinValid(coin) and State.farm and Hub.Alive and canFarm() do
            elapsed += RunService.Heartbeat:Wait()
            holdCF = startCF:Lerp(cf, math.clamp(elapsed / duration, 0, 1))
        end

        holdCF = hrp.CFrame
        return coinValid(coin)
    end

    local LAY = CFrame.Angles(math.rad(90), 0, 0)

    local LONG_DIST = 40
    local WINDOW = 10
    local FREE_DIST = 60
    local longHops = {}

    local function adaptiveSpeed(dist)
        local base = State.speed
        local now = os.clock()
        local sum = 0
        for i = #longHops, 1, -1 do
            if now - longHops[i].t > WINDOW then table.remove(longHops, i) else sum += longHops[i].d end
        end
        local factor = 1 - math.clamp((sum - FREE_DIST) / 400, 0, 0.4)
        if dist > 60 then factor *= math.clamp(1 - (dist - 60) / 300, 0.97, 1) end
        if dist > LONG_DIST then longHops[#longHops + 1] = { t = now, d = dist } end
        local eff = math.max(base * factor, math.min(base, 8))
        State.effSpeed = eff
        return eff
    end

    local function setFarm(on)
        State.farm = on
        if on then
            enableNoclip()
        else
            stopHold()
            disableNoclip()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end

    local Players, TeleportService = Hub.Services.Players, Hub.Services.TeleportService
    local HttpService, GuiService = Hub.Services.HttpService, Hub.Services.GuiService
    local rejoining = false

    local function httpGet(url)
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" and #res > 0 then return res end
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            local ok2, r = pcall(req, { Url = url, Method = "GET" })
            if ok2 and r and r.Body then return r.Body end
        end
    end

    local function pickServer()
        local body = httpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100")
            :format(game.PlaceId))
        if not body then return end
        local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then return end
        local good, any = {}, {}
        for _, sv in ipairs(data.data) do
            if sv.id ~= game.JobId and (sv.playing or 0) < (sv.maxPlayers or 0) then
                any[#any + 1] = sv.id
                if (sv.playing or 0) >= 2 then good[#good + 1] = sv.id end
            end
        end
        local pool = #good > 0 and good or any
        if #pool > 0 then return pool[math.random(#pool)] end
    end

    local function rejoin(reason)
        if rejoining or not Hub.Alive then return end
        rejoining = true
        Hub.UI.Notify({ Title = "Auto rejoin", Text = reason .. " - looking for another server...", Type = "warn", Duration = 6 })

        task.spawn(function()
            for _ = 1, 5 do
                if not Hub.Alive then return end
                local id = pickServer()
                local ok
                if id then
                    ok = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, id, LocalPlayer)
                else
                    ok = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
                end
                task.wait(10)
                if not ok then task.wait(2) end
            end
            rejoining = false
        end)
    end

    local aloneChecks, enabledAt = 0, 0
    task.spawn(function()
        while Hub.Alive do
            task.wait(5)
            if State.rejoinEmpty and os.clock() - enabledAt > 15 then
                if #Players:GetPlayers() <= 1 then
                    aloneChecks += 1
                    if aloneChecks >= 2 then rejoin("You are the only one on the server") end
                else
                    aloneChecks = 0
                end
            else
                aloneChecks = 0
            end
        end
    end)

    local function killViaPid()
        -- Пингуем PID killer: он убьёт процесс и поставит false в players.txt,
        -- гибрид подхватит и запустит бота на новом сервере
        local name = LocalPlayer.Name
        local url = ("http://127.0.0.1:9999/kill?user=%s"):format(name)
        local req = (syn and syn.request) or request or http_request or (http and http.request)
        if req then
            pcall(req, { Url = url, Method = "GET" })
        else
            pcall(function() game:HttpGet(url) end)
        end
    end

    local function onKick(msg)
        if State.closeOnKick then
            killViaPid()
        elseif State.rejoinKick then
            rejoin("Kicked: " .. tostring(msg))
        end
    end
    Hub.Track(GuiService.ErrorMessageChanged:Connect(function()
        local msg = GuiService:GetErrorMessage()
        if msg and msg ~= "" then onKick(msg) end
    end))
    task.spawn(pcall, function()
        local overlay = Hub.Services.CoreGui:WaitForChild("RobloxPromptGui", 5):WaitForChild("promptOverlay", 5)
        Hub.Track(overlay.ChildAdded:Connect(function(child)
            if child.Name == "ErrorPrompt" then
                task.wait(0.5)
                local label = child:FindFirstChildWhichIsA("TextLabel", true)
                onKick(label and label.Text or "ErrorPrompt")
            end
        end))
    end)

    local shooting = false

    local function findTool(player, name)
        local bp, char = player:FindFirstChildOfClass("Backpack"), player.Character
        return (bp and bp:FindFirstChild(name)) or (char and char:FindFirstChild(name))
    end

    local function findMurderer()
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and findTool(pl, "Knife") then return pl end
        end
    end

    local function findSheriff()
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and findTool(pl, "Gun") then return pl end
        end
    end

    local function notify(title, text, kind)
        Hub.UI.Notify({ Title = title, Text = text, Type = kind or "warn", Duration = 4 })
    end

    local function sharpShoot()
        if shooting then return end
        shooting = true
        local ok, err = pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not (hum and hrp and hum.Health > 0) then return notify("Sharp shooter", "Character unavailable") end

            local gun = findTool(LocalPlayer, "Gun")
            if not gun then return notify("Sharp shooter", "You do not have a gun (you are not the sheriff)") end

            local murderer = findMurderer()
            local mchar = murderer and murderer.Character
            local mhrp = mchar and mchar:FindFirstChild("HumanoidRootPart")
            local mhum = mchar and mchar:FindFirstChildOfClass("Humanoid")
            if not murderer then return notify("Sharp shooter", "Murderer not found") end
            if not (mhrp and mhum and mhum.Health > 0) then return notify("Sharp shooter", "Murderer is dead or not loaded") end

            if gun.Parent ~= char then
                hum:EquipTool(gun)
                local t = os.clock()
                while gun.Parent ~= char and os.clock() - t < 1 do task.wait() end
                if gun.Parent ~= char then return notify("Sharp shooter", "Could not pick up the gun") end
            end
            local shoot = gun:FindFirstChild("Shoot")
            if not shoot then return notify("Sharp shooter", "Gun has no Shoot event") end

            local origin = hrp.CFrame
            local behind = mhrp.CFrame * CFrame.new(0, 0, 4)
            hrp.CFrame = CFrame.lookAt(behind.Position, mhrp.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero

            mhrp = mchar:FindFirstChild("HumanoidRootPart")
            if mhrp then
                local from = CFrame.lookAt(hrp.Position + Vector3.new(0, 1.5, 0), mhrp.Position)
                shoot:FireServer(from, CFrame.new(mhrp.Position))
            end

            task.wait(0.5) -- wait for server to register the shot before returning
            if State.sharpReturn and hrp.Parent then hrp.CFrame = origin end
        end)
        shooting = false
        if not ok then notify("Sharp shooter", tostring(err), "bad") end
    end

    local killing = false

    local function alive(pl)
        local c = pl.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return c, h and h.Health > 0
    end

    local function killAll()
        if killing then return end
        killing = true
        local ok, err = pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not (hum and hum.Health > 0) then return notify("Kill all", "Character unavailable") end

            local knife = findTool(LocalPlayer, "Knife")
            if not knife then return notify("Kill all", "You do not have a knife (you are not the murderer)") end

            if knife.Parent ~= char then
                hum:EquipTool(knife)
                local t = os.clock()
                while knife.Parent ~= char and os.clock() - t < 1 do task.wait() end
                if knife.Parent ~= char then return notify("Kill all", "Could not pick up the knife") end
            end
            local events = knife:FindFirstChild("Events")
            local stabbed = events and events:FindFirstChild("KnifeStabbed")
            local touched = events and events:FindFirstChild("HandleTouched")
            if not (stabbed and touched) then return notify("Kill all", "Knife is missing required events") end

            local targets = 0
            for _, pl in ipairs(Players:GetPlayers()) do
                if not Hub.Alive then break end
                if pl ~= LocalPlayer then
                    for _ = 1, 3 do
                        local c, isAlive = alive(pl)
                        if not isAlive then break end
                        local part = c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
                        if not part then break end
                        stabbed:FireServer()
                        task.wait(0.05)
                        for _ = 1, 3 do
                            touched:FireServer(part)
                            task.wait(0.05)
                        end
                        task.wait(0.15)
                    end
                    if not select(2, alive(pl)) then targets += 1 end
                end
            end
            notify("Kill all", "Killed: " .. targets, "good")
        end)
        killing = false
        if not ok then notify("Kill all", tostring(err), "bad") end
    end

    local function findGunDrop()
        local direct = workspace:FindFirstChild("GunDrop")
        if direct then return direct end
        for _, child in ipairs(workspace:GetChildren()) do
            local d = child:FindFirstChild("GunDrop")
            if d then return d end
        end
    end

    local function dropPart(drop)
        if drop:IsA("BasePart") then return drop end
        return drop:FindFirstChildWhichIsA("BasePart", true)
    end

    local function touchPart(obj)
        if obj:IsA("BasePart") then return obj end
        return obj:FindFirstChildWhichIsA("BasePart", true)
    end

    local grabbing = false
    local function grabGun()
        if not canFarm() then return end
        local drop = findGunDrop()
        local part = drop and dropPart(drop)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (part and hrp and hum and hum.Health > 0) then return end
        if findTool(LocalPlayer, "Gun") or findTool(LocalPlayer, "Knife") then return end

        grabbing = true
        local origin = hrp.CFrame
        local t = os.clock()
        while drop.Parent and part.Parent and os.clock() - t < 2 and State.grabGun and Hub.Alive and canFarm() do
            hrp.CFrame = part.CFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            if firetouchinterest then
                pcall(firetouchinterest, hrp, part, 0)
                pcall(firetouchinterest, hrp, part, 1)
            end
            task.wait(0.1)
            if findTool(LocalPlayer, "Gun") then break end
        end
        if hrp.Parent then hrp.CFrame = origin end
        if findTool(LocalPlayer, "Gun") then
            notify("Auto grab gun", "Gun picked up", "good")
        end
        task.wait(1)
        grabbing = false
    end

    task.spawn(function()
        while Hub.Alive do
            task.wait(0.2)
            if State.grabGun and not grabbing then
                local ok, err = pcall(grabGun)
                if not ok then
                    grabbing = false
                    warn("[Auto grab gun] " .. tostring(err))
                end
            end
        end
    end)

    local FPDH = workspace.FallenPartsDestroyHeight

    local function skidFling(targetPlayer, oneShot)
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Humanoid and Humanoid.RootPart
        local TCharacter = targetPlayer.Character
        if not (Character and Humanoid and RootPart) then return notify("Fling", "Character unavailable") end
        if not TCharacter then return end

        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead = TCharacter:FindFirstChild("Head")
        local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
        local Handle = Accessory and Accessory:FindFirstChild("Handle")

        if RootPart.Velocity.Magnitude < 50 then
            Hub.OldPos = RootPart.CFrame
        end
        if THumanoid and THumanoid.Sit then return notify("Fling", targetPlayer.Name .. " is sitting") end

        local camera = workspace.CurrentCamera
        if THead then camera.CameraSubject = THead
        elseif Handle then camera.CameraSubject = Handle
        elseif THumanoid and TRootPart then camera.CameraSubject = THumanoid end

        if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

        local function FPos(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local function SFBasePart(BasePart)
            local TimeToWait = 2
            local Time = tick()
            local Angle = 0
            repeat
                -- stop following if target fell off the map (we'd die with them)
                if BasePart.Position.Y < -50 then break end
                if RootPart and THumanoid then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle += 100
                        local md = THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + md, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + md, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + md, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + md, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)) task.wait()
                    else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)) task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)) task.wait()
                    end
                end
            until Time + TimeToWait < tick() or not Hub.Alive
        end

        workspace.FallenPartsDestroyHeight = 0 / 0

        local BV = Instance.new("BodyVelocity")
        BV.Velocity = Vector3.zero
        BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        BV.Parent = RootPart
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

        local ok, err = pcall(function()
            if TRootPart then SFBasePart(TRootPart)
            elseif THead then SFBasePart(THead)
            elseif Handle then SFBasePart(Handle)
            else notify("Fling", targetPlayer.Name .. " has no suitable parts") end
        end)

        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        camera.CameraSubject = Humanoid

        -- hard-stop fling velocity (first pass — kills the 9e7 impulse)
        for _, part in ipairs(Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.zero
                part.RotVelocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        task.wait(0.15) -- physics settle
        -- hard-stop again (second pass — catches residual momentum)
        for _, part in ipairs(Character:GetChildren()) do
            if part:IsA("BasePart") then
                part.Velocity = Vector3.zero
                part.RotVelocity = Vector3.zero
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
        task.wait(0.05)
        if Hub.OldPos then
            local t = os.clock()
            repeat
                RootPart.CFrame = Hub.OldPos * CFrame.new(0, 0.5, 0)
                Character:SetPrimaryPartCFrame(Hub.OldPos * CFrame.new(0, 0.5, 0))
                Humanoid:ChangeState("GettingUp")
                for _, part in ipairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Velocity = Vector3.zero
                        part.RotVelocity = Vector3.zero
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                task.wait()
            until (RootPart.Position - Hub.OldPos.Position).Magnitude < 25 or os.clock() - t > 5
        end
        workspace.FallenPartsDestroyHeight = FPDH
        if not ok then error(err) end
    end

    local function flingOneSheriff()
        if flingSheriffing then return end
        flingSheriffing = true
        local ok, err = pcall(function()
            -- poll until sheriff appears (roles may not be assigned yet)
            local sheriff
            local deadline = os.clock() + 15
            while not sheriff and os.clock() < deadline and Hub.Alive do
                -- abort if we turned out to be murderer or sheriff during the wait
                if findTool(LocalPlayer, "Knife") or findTool(LocalPlayer, "Gun") then return end
                sheriff = findSheriff()
                if not sheriff then task.wait(0.5) end
            end
            if not sheriff then return notify("Auto fling sheriff", "Sheriff not found", "warn") end
            -- final role check before fling
            if findTool(LocalPlayer, "Knife") then return end -- we are murderer
            if findTool(LocalPlayer, "Gun") then return end   -- we are sheriff
            notify("Auto fling sheriff", "Flinging " .. sheriff.Name, "good")
            local c = sheriff.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if not (sheriff.Parent and h and h.Health > 0 and r) then return end
            -- force-save position before fling (velocity check in skidFling may skip it)
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChildOfClass("Humanoid") and myChar:FindFirstChildOfClass("Humanoid").RootPart
            local preFlingPos = myRoot and myRoot.CFrame
            Hub.OldPos = preFlingPos or Hub.OldPos
            skidFling(sheriff, true) -- oneShot: single fling burst
            -- zero all velocities so server doesn't reject the teleport
            if myChar then
                for _, part in ipairs(myChar:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Velocity = Vector3.zero
                        part.RotVelocity = Vector3.zero
                    end
                end
            end
            -- return to exact pre-fling position
            if preFlingPos and myRoot and myRoot.Parent then
                myRoot.CFrame = preFlingPos
                myChar:SetPrimaryPartCFrame(preFlingPos)
            end
            notify("Auto fling sheriff", "Done — grabbing gun", "good")
        end)
        workspace.FallenPartsDestroyHeight = FPDH
        flingSheriffing = false
        if not ok then notify("Auto fling sheriff", tostring(err), "bad") end
    end

    local function flingMurderer()
        if flinging then return end
        flinging = true
        local ok, err = pcall(function()
            local murderer = findMurderer()
            if not murderer then return notify("Fling", "Murderer not found") end
            notify("Fling", "Flinging " .. murderer.Name, "good")
            for _ = 1, 3 do
                if not Hub.Alive then break end
                local c = murderer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local r = c and c:FindFirstChild("HumanoidRootPart")
                if not (murderer.Parent and h and h.Health > 0 and r) then break end
                if r.Position.Y < -200 then break end
                skidFling(murderer)
                task.wait(0.2)
            end
            notify("Fling", "Done", "good")
        end)
        workspace.FallenPartsDestroyHeight = FPDH
        flinging = false
        if not ok then notify("Fling", tostring(err), "bad") end
    end

    local function coinGui()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("MainGUI")
        local game_ = main and main:FindFirstChild("Game")
        local bags = game_ and game_:FindFirstChild("CoinBags")
        local cont = bags and bags:FindFirstChild("Container")
        return cont and cont:FindFirstChild("Coin")
    end

    local function digitsOnly(text)
        local out = {}
        for i = 1, #text do
            local b = text:byte(i)
            if b >= 48 and b <= 57 then
                out[#out + 1] = text:sub(i, i)
            end
        end
        if #out == 0 then return nil end
        return tonumber(table.concat(out))
    end

    local function readBagCoins()
        local coin = coinGui()
        local cur = coin and coin:FindFirstChild("CurrencyFrame")
        local icon = cur and cur:FindFirstChild("Icon")
        local label = icon and icon:FindFirstChild("Coins")
        if label and label:IsA("TextLabel") then
            return digitsOnly(label.Text)
        end
    end

    local function isBagFull()
        local coin = coinGui()
        local full = coin and coin:FindFirstChild("Full")
        return full ~= nil and full.Visible == true
    end

    local farmedTotal, lastBag = 0, nil
    Hub.Tracker.SetCoinsProvider(function() return farmedTotal end)

    local fullHandled = false
    local outHandled = false

    local function onOutOfGame()
        local t = os.clock()
        while os.clock() - t < 15 and Hub.Alive do
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and char:FindFirstChild("HumanoidRootPart") then break end
            task.wait(0.25)
        end
        local murderer = findMurderer()
        local mchar = murderer and murderer.Character
        local mhum = mchar and mchar:FindFirstChildOfClass("Humanoid")
        if State.flingOut and mhum and mhum.Health > 0 then
            notify("Auto farm", "The game is over for you - Fling murderer", "good")
            flingMurderer()
        end
    end

    local function murdererAlive()
        local m = findMurderer()
        local c = m and m.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return h ~= nil and h.Health > 0
    end

    local function stabilize()
        task.wait(0.2)
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and hrp) then return end
        local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
        hrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, yaw, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.wait(2.5)
    end

    local function onBagFull()
        if not Hub.Alive then return end
        stabilize()
        if not (Hub.Alive and canFarm()) then return end
        if State.grabGun and not findTool(LocalPlayer, "Gun") and not findTool(LocalPlayer, "Knife") and findGunDrop() then
            local t = os.clock()
            while os.clock() - t < 3 and not findTool(LocalPlayer, "Gun") do task.wait(0.1) end
        end

        if findTool(LocalPlayer, "Knife") then
            if State.killAllFull then
                notify("Auto farm", "Bag is full - Kill all", "good")
                killAll()
            end
        elseif State.killMurderFull then
            for attempt = 1, 10 do
                if not (Hub.Alive and State.killMurderFull and canFarm() and murdererAlive()) then break end
                if findTool(LocalPlayer, "Gun") then
                    notify("Auto farm", ("Bag is full - Sharp shooter (%d)"):format(attempt), "good")
                    sharpShoot()
                else
                    notify("Auto farm", ("Bag is full - Fling murderer (%d)"):format(attempt), "good")
                    flingMurderer()
                end
                local t = os.clock()
                while os.clock() - t < 5 and Hub.Alive and murdererAlive() do task.wait(0.25) end
            end
        end
    end

    task.spawn(function()
        while Hub.Alive do
            task.wait(0.25)

            local v = readBagCoins()
            if v then
                if lastBag then
                    if v > lastBag then farmedTotal += v - lastBag
                    elseif v < lastBag then farmedTotal += v end
                end
                lastBag = v
            end

            if State.farm and State.flingOut then
                local murderer = findMurderer()
                local mchar = murderer and murderer.Character
                local mhum = mchar and mchar:FindFirstChildOfClass("Humanoid")
                local roundOn = mhum ~= nil and mhum.Health > 0
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local out = isWaiting() or (hum ~= nil and hum.Health <= 0)
                if roundOn and out and not outHandled then
                    outHandled = true
                    task.spawn(function()
                        local ok, err = pcall(onOutOfGame)
                        if not ok then warn("[Auto farm] " .. tostring(err)) end
                    end)
                elseif not roundOn then
                    outHandled = false
                end
            end

            local full = isBagFull()
            State.bagFull = full
            if full and not fullHandled and State.farm then
                fullHandled = true
                task.spawn(function()
                    local ok, err = pcall(onBagFull)
                    if not ok then warn("[Auto farm] " .. tostring(err)) end
                end)
            elseif not full then
                fullHandled = false
            end
        end
    end)

    -- Auto fling sheriff at round start
    local sheriffFlung = false
    task.spawn(function()
        local wasWaiting = true
        while Hub.Alive do
            task.wait(0.5)
            local waiting = isWaiting()
            if waiting then
                wasWaiting = true
                sheriffFlung = false
            elseif wasWaiting and not waiting then
                wasWaiting = false
                if State.autoFlingSheriff and State.farm and not sheriffFlung then
                    task.wait(2) -- wait for roles to be distributed
                    if Hub.Alive and State.farm and State.autoFlingSheriff
                        and not findTool(LocalPlayer, "Knife") and not findTool(LocalPlayer, "Gun")
                        and not sheriffFlung then
                        sheriffFlung = true
                        task.spawn(function()
                            local ok, err = pcall(flingOneSheriff)
                            if not ok then warn("[Auto fling sheriff] " .. tostring(err)) end
                        end)
                    end
                end
            end
        end
    end)

    local tab = Hub.Window:AddTab({ Name = "MM2", Icon = "knife" })

    local farm = tab:AddSection("Autofarm")
    local statsLabel = farm:Label("Coins: 0 · 0 coins/hour")
    farm:Toggle({
        Name = "Coin farm", Description = "Automatically collects coins during the round",
        Flag = "coinFarm.enabled", Default = State.farm,
        Callback = setFarm,
    })
    farm:Slider({
        Name = "Flight speed", Flag = "coinFarm.speed",
        Min = 1, Max = 50, Default = State.speed, Suffix = " st/s",
        Callback = function(v)
            State.speed = v
            if v > 45 then
                notify("Flight speed", "Speed above 45 may kick you from the game", "warn")
            end
        end,
    })
    farm:Label("Speed above 45 may kick you from the game", Hub.UI.Theme.Warn)
    farm:Toggle({
        Name = "Kill all after full coin bag", Description = "Murderer: run Kill all once the coin bag is full",
        Flag = "coinFarm.killAllFull", Default = State.killAllFull,
        Callback = function(v) State.killAllFull = v end,
    })
    farm:Toggle({
        Name = "Kill murder after full coin bag", Description = "Sheriff: Sharp shooter, otherwise Fling murderer",
        Flag = "coinFarm.killMurderFull", Default = State.killMurderFull,
        Callback = function(v) State.killMurderFull = v end,
    })
    farm:Toggle({
        Name = "Fling murderer when out of game", Description = "You are dead / waiting while the round is on - fling the murderer",
        Flag = "coinFarm.flingOut", Default = State.flingOut,
        Callback = function(v) State.flingOut = v end,
    })
    farm:Toggle({
        Name = "Auto grab gun", Description = "Picks up the gun dropped after the sheriff dies",
        Flag = "grabGun.enabled", Default = State.grabGun,
        Callback = function(v) State.grabGun = v end,
    })
    farm:Toggle({
        Name = "Auto fling sheriff", Description = "Innocent: flings the sheriff once at round start to steal their gun, then finish the round when the bag is full",
        Flag = "coinFarm.autoFlingSheriff", Default = State.autoFlingSheriff,
        Callback = function(v) State.autoFlingSheriff = v end,
    })

    task.spawn(function()
        while Hub.Alive do
            local st = Hub.Tracker.Stats()
            local rate = st.elapsed >= 60 and Hub.UI.Format(st.cph) or "..."
            local spd = State.farm and State.effSpeed > 0 and (" · " .. math.floor(State.effSpeed + 0.5) .. " st/s") or ""
            statsLabel:Set(("Coins: %s · %s coins/hour%s"):format(Hub.UI.Format(farmedTotal), rate, spd))
            task.wait(1)
        end
    end)

    local rj = tab:AddSection("Auto rejoin")
    rj:Toggle({
        Name = "Auto rejoin on empty", Description = "Rejoin a different server if you are the only one left",
        Flag = "rejoin.empty", Default = false,
        Callback = function(v)
            State.rejoinEmpty = v
            enabledAt = os.clock()
            aloneChecks = 0
        end,
    })
    rj:Toggle({
        Name = "Auto rejoin on kicked", Description = "Rejoin a different server if you get kicked",
        Flag = "rejoin.kicked", Default = false,
        Callback = function(v) State.rejoinKick = v end,
    })
    rj:Toggle({
        Name = "Close Roblox when kicked", Description = "Пингует PID killer (порт 9999) — гибрид закроет процесс и переоткроет бота на другом сервере",
        Flag = "rejoin.close", Default = false,
        Callback = function(v) State.closeOnKick = v end,
    })

    local ss = tab:AddSection("Sharp shooter")
    ss:Label("Sheriff: grabs the gun, teleports behind the murderer, and shoots them.")
    ss:Toggle({
        Name = "Return after shooting", Flag = "sharp.return", Default = State.sharpReturn,
        Callback = function(v) State.sharpReturn = v end,
    })
    ss:Buttons({
        { Text = "Sharp shooter", Icon = "crosshair", Primary = true, Callback = sharpShoot },
    })

    local mur = tab:AddSection("Murderer")
    mur:Label("Murderer: grabs the knife and hits every player at range, without teleporting.")
    mur:Buttons({
        { Text = "Kill all", Icon = "knife", Danger = true, Callback = killAll },
    })

    local fl = tab:AddSection("Fling")
    fl:Label("Spins against the murderer and flings them off the map - ends the round quickly.")
    fl:Buttons({
        { Text = "Fling murderer", Icon = "spin", Primary = true, Callback = flingMurderer },
    })

    task.spawn(function()
        while Hub.Alive do
            task.wait(0.05)
            if State.farm then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")

                if not (hrp and hum and hum.Health > 0) or isWaiting() then
                    stopHold()
                    disableNoclip()
                    if hum then hum.PlatformStand = false end
                elseif State.bagFull then
                    stopHold()
                    disableNoclip()
                    hum.PlatformStand = false
                else
                    enableNoclip()

                    local coin, pos = getNearestCoin(hrp)
                    if not coin then
                        blacklist = {}
                    else
                        hum.PlatformStand = true

                        task.wait(0.13)

                        local below = pos - Vector3.new(0, State.offset, 0)
                        local dist = (below - hrp.Position).Magnitude
                        local reached = flyTo(hrp, CFrame.new(below) * LAY, math.max(dist / adaptiveSpeed(dist), 0.05), coin)

                        if reached then
                            local part = touchPart(coin)
                            local t = os.clock()
                            while os.clock() - t < 0.12 and coinValid(coin) and State.farm and canFarm() do
                                if part and firetouchinterest then
                                    pcall(firetouchinterest, hrp, part, 0)
                                    pcall(firetouchinterest, hrp, part, 1)
                                end
                                RunService.Heartbeat:Wait()
                            end

                            blacklist[coin] = true
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
    end)

    Hub.OnUnload(function() setFarm(false) end)
end

