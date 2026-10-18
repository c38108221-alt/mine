return function(Options)
    Options = Options or {}

    local Hub = {
        Name = "Kyron Hub",
        Version = "2.0.0",
        Folder = Options.Folder or "KyronHub",
    }

    Hub.Services = setmetatable({}, {
        __index = function(t, name)
            local ok, svc = pcall(game.GetService, game, name)
            if not ok then return nil end
            rawset(t, name, svc)
            return svc
        end,
    })
    local S = Hub.Services

    if not game:IsLoaded() then game.Loaded:Wait() end

    local Player = S.Players.LocalPlayer
    while not Player do
        task.wait()
        Player = S.Players.LocalPlayer
    end
    Hub.Player = Player
    Hub.Alive = true

    local cleanups = {}

    function Hub.Track(obj)
        cleanups[#cleanups + 1] = obj
        return obj
    end

    function Hub.OnUnload(fn)
        cleanups[#cleanups + 1] = fn
        return fn
    end

    function Hub.Unload()
        if not Hub.Alive then return end
        Hub.Alive = false
        for i = #cleanups, 1, -1 do
            local obj = cleanups[i]
            local kind = typeof(obj)
            pcall(function()
                if kind == "function" then
                    obj()
                elseif kind == "RBXScriptConnection" then
                    obj:Disconnect()
                elseif kind == "Instance" then
                    obj:Destroy()
                end
            end)
        end
        table.clear(cleanups)
        local env = getgenv()
        if env.ScriptHub == Hub then env.ScriptHub = nil end
    end

    local FS = {}
    Hub.FS = FS
    FS.Available = type(writefile) == "function" and type(readfile) == "function"
        and type(isfile) == "function" and type(isfolder) == "function"
        and type(makefolder) == "function" and type(listfiles) == "function"
        and type(delfile) == "function"

    local ALTS_DIR = Hub.Folder .. "/alts"
    local CONFIG_DIR = Hub.Folder .. "/configs"
    local AUTOLOAD_PATH = Hub.Folder .. "/autoload.json"

    if FS.Available then
        for _, dir in ipairs({ Hub.Folder, ALTS_DIR, CONFIG_DIR }) do
            if not isfolder(dir) then pcall(makefolder, dir) end
        end
    end

    function FS.Exists(path)
        return FS.Available and isfile(path)
    end

    function FS.ReadJSON(path)
        if not FS.Exists(path) then return nil end
        local ok, data = pcall(function()
            return S.HttpService:JSONDecode(readfile(path))
        end)
        if ok and type(data) == "table" then return data end
        return nil
    end

    function FS.WriteJSON(path, tbl)
        if not FS.Available then return false, "file functions unavailable" end
        local ok, err = pcall(function()
            writefile(path, S.HttpService:JSONEncode(tbl))
        end)
        if not ok then return false, tostring(err) end
        return true
    end

    function FS.Delete(path)
        if FS.Exists(path) then return (pcall(delfile, path)) end
        return false
    end

    function FS.List(dir)
        local out = {}
        if not FS.Available then return out end
        local ok, files = pcall(listfiles, dir)
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local name = tostring(path):match("([^/\\]+)%.json$")
                if name then out[#out + 1] = { name = name, path = path } end
            end
        end
        return out
    end

    Hub.Flags = {}

    function Hub.RegisterFlag(flag, get, set)
        Hub.Flags[flag] = { get = get, set = set }
    end

    local Config = {}
    Hub.Config = Config

    local function cleanName(name)
        name = tostring(name or ""):gsub("[^%w _%-]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        return name:sub(1, 32)
    end
    Config.CleanName = cleanName

    local function pathOf(name)
        return CONFIG_DIR .. "/" .. name .. ".json"
    end

    function Config.Collect()
        local cfg = { _meta = { version = 2, saved = os.time(), player = Player.Name } }
        for flag, f in pairs(Hub.Flags) do
            local ok, v = pcall(f.get)
            if ok and v ~= nil then
                local group, key = flag:match("^([^%.]+)%.(.+)$")
                if group then
                    cfg[group] = cfg[group] or {}
                    cfg[group][key] = v
                else
                    cfg[flag] = v
                end
            end
        end
        return cfg
    end

    function Config.Apply(cfg)
        local applied = 0
        local function apply(flag, v)
            local f = Hub.Flags[flag]
            if f and pcall(f.set, v) then applied = applied + 1 end
        end
        for k, v in pairs(cfg) do
            if k:sub(1, 1) ~= "_" then
                if type(v) == "table" then
                    for key, val in pairs(v) do apply(k .. "." .. key, val) end
                else
                    apply(k, v)
                end
            end
        end
        return applied
    end

    function Config.List()
        local names = {}
        for _, f in ipairs(FS.List(CONFIG_DIR)) do names[#names + 1] = f.name end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
        return names
    end

    function Config.Exists(name)
        return name ~= "" and FS.Exists(pathOf(name))
    end

    function Config.Save(name)
        name = cleanName(name)
        if name == "" then return false, "enter a config name" end
        local ok, err = FS.WriteJSON(pathOf(name), Config.Collect())
        if not ok then return false, err end
        return true, name
    end

    function Config.Load(name)
        name = cleanName(name)
        if not FS.Available then return false, "file functions unavailable" end
        if not Config.Exists(name) then return false, "config not found" end
        local cfg = FS.ReadJSON(pathOf(name))
        if not cfg then return false, "file is corrupted" end
        Config.Apply(cfg)
        return true, name
    end

    function Config.Delete(name)
        name = cleanName(name)
        if not Config.Exists(name) then return false, "config not found" end
        FS.Delete(pathOf(name))
        if Config.GetAutoload() == name then Config.ClearAutoload() end
        return true, name
    end

    function Config.GetAutoload()
        local data = FS.ReadJSON(AUTOLOAD_PATH)
        if data and type(data.config) == "string" and data.config ~= "" then
            return data.config
        end
        return nil
    end

    function Config.SetAutoload(name)
        name = cleanName(name)
        if not Config.Exists(name) then return false, "save the config first" end
        local ok, err = FS.WriteJSON(AUTOLOAD_PATH, { config = name })
        if not ok then return false, err end
        return true, name
    end

    function Config.ClearAutoload()
        FS.Delete(AUTOLOAD_PATH)
    end

    function Config.RunAutoload()
        local name = Config.GetAutoload()
        if not name then return nil end
        return Config.Load(name)
    end

    local Tracker = {
        LiveTimeout = 15,
        DeleteTimeout = 45,
        WriteInterval = 4,
        SessionStart = os.time(),
        Meta = {},
    }
    Hub.Tracker = Tracker

    local selfPath = ALTS_DIR .. "/" .. Player.Name .. ".json"
    local coinsProvider = nil
    local startCoins = nil
    local manualFarmed = 0

    function Tracker.SetCoinsProvider(fn)
        coinsProvider = fn
    end

    function Tracker.AddFarmed(n)
        manualFarmed = manualFarmed + (n or 1)
    end

    function Tracker.GetCoins()
        if coinsProvider then
            local ok, v = pcall(coinsProvider)
            if ok and type(v) == "number" then return v end
        end
        local ext = getgenv().AltTracker and getgenv().AltTracker.Coins
        if type(ext) == "number" then return ext end
        return nil
    end

    function Tracker.Stats()
        local coins = Tracker.GetCoins()
        if coins and not startCoins then startCoins = coins end
        local elapsed = os.time() - Tracker.SessionStart
        local farmed = manualFarmed
        if coins and startCoins then farmed = coins - startCoins end
        local cph = 0
        if elapsed >= 60 then cph = farmed / (elapsed / 3600) end
        return { coins = coins, farmed = farmed, cph = math.floor(cph), elapsed = elapsed }
    end

    function Tracker.WriteSelf()
        if not FS.Available then return end
        local st = Tracker.Stats()
        local data = {
            Name = Player.Name,
            UserId = Player.UserId,
            Status = "Live",
            Added = Tracker.SessionStart,
            Updated = os.time(),
            Coins = st.coins,
            Farmed = st.farmed,
            CPH = st.cph,
        }
        for k, v in pairs(Tracker.Meta) do data[k] = v end
        FS.WriteJSON(selfPath, data)
    end

    function Tracker.RemoveSelf()
        FS.Delete(selfPath)
    end

    function Tracker.ReadAll()
        local list = {}
        local now = os.time()
        for _, f in ipairs(FS.List(ALTS_DIR)) do
            local okR, content = pcall(readfile, f.path)
            if okR then
                local okJ, data = pcall(function() return S.HttpService:JSONDecode(content) end)
                if okJ and type(data) == "table" and data.Name then
                    local age = now - (data.Updated or 0)
                    if age > Tracker.DeleteTimeout and data.Name ~= Player.Name then
                        pcall(delfile, f.path)
                    else
                        data.Live = age <= Tracker.LiveTimeout
                        list[#list + 1] = data
                    end
                end
            end
        end
        table.sort(list, function(a, b)
            local aa, bb = a.Added or 0, b.Added or 0
            if aa ~= bb then return aa < bb end
            return tostring(a.Name) < tostring(b.Name)
        end)
        return list
    end

    function Tracker.Start()
        if Tracker.Started then return end
        Tracker.Started = true

        task.spawn(function()
            while Hub.Alive do
                local ok, err = pcall(Tracker.WriteSelf)
                if not ok then warn("[" .. Hub.Name .. "] tracker:", err) end
                task.wait(Tracker.WriteInterval)
            end
        end)

        pcall(function() Hub.Track(S.GuiService.NativeClose:Connect(Tracker.RemoveSelf)) end)
        Hub.Track(S.Players.PlayerRemoving:Connect(function(p)
            if p == Player then Tracker.RemoveSelf() end
        end))
        Hub.OnUnload(Tracker.RemoveSelf)
    end

    Hub.ExternalScripts = {
        "https://raw.githubusercontent.com/c38108221-alt/tracker/refs/heads/main/one.lua",
        "https://raw.githubusercontent.com/c38108221-alt/tracker/refs/heads/main/two.lua",
    }

    function Hub.RunExternal()
        for _, url in ipairs(Hub.ExternalScripts) do
            task.spawn(function()
                local ok, err = pcall(function()
                    loadstring(game:HttpGet(url))()
                end)
                if not ok then
                    warn(("[%s] external script %s: %s"):format(Hub.Name, url, tostring(err)))
                end
            end)
        end
    end

    return Hub
end
