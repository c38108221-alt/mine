local env = getgenv()

if env.ScriptHub and env.ScriptHub.Unload then
    pcall(env.ScriptHub.Unload)
end

local Options = env.ScriptHubOptions or {}
local REPO = Options.Repo or "c38108221-alt/mine"
local BRANCH = Options.Branch or "main"
local LOCAL = Options.LocalPath
local BASE = ("https://raw.githubusercontent.com/%s/%s/"):format(REPO, BRANCH)

local MODULES = {
    {
        Name = "MM2", Path = "Modules/MM2.lua",
        PlaceIds = { 142823291, 335132309, 636649648 },
        UniverseIds = { 66654135 },
    },
    { Name = "Universal", Path = "Modules/Universal.lua" },
    { Name = "Player", Path = "Modules/Player.lua" },
    { Name = "Settings", Path = "Modules/Settings.lua" },
}

local function fetch(path)
    if LOCAL then
        local full = LOCAL .. "/" .. path
        if type(isfile) == "function" and isfile(full) then
            return readfile(full)
        end
        error("local file not found: " .. full)
    end

    local lastErr
    for attempt = 1, 3 do
        local ok, res = pcall(game.HttpGet, game, BASE .. path .. "?t=" .. os.time(), true)
        if ok and type(res) == "string" and #res > 0 and not res:match("^404") then
            return res
        end
        lastErr = ok and ("empty response / 404: " .. path) or tostring(res)
        task.wait(attempt)
    end
    error(lastErr)
end

local function load(path)
    local src = fetch(path)
    local fn, err = loadstring(src, "=" .. path)
    if not fn then error(("syntax error in %s: %s"):format(path, tostring(err))) end
    return fn()
end

local Hub = load("Lib/Core.lua")({ Folder = "KyronHub" })
env.ScriptHub = Hub
Hub.LoaderUrl = BASE .. "Loader.lua"
Hub.Fetch = fetch

Hub.UI = load("Lib/UI.lua")(Hub)

local gameName = "Universal"
pcall(function()
    gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)

Hub.Window = Hub.UI.CreateWindow({
    Title = Hub.Name,
    Subtitle = gameName,
    Size = Vector2.new(620, 430),
})

local function matches(m)
    if not m.PlaceIds and not m.UniverseIds then return true end
    if m.PlaceIds and table.find(m.PlaceIds, game.PlaceId) then return true end
    if m.UniverseIds and table.find(m.UniverseIds, game.GameId) then return true end
    return false
end

local loaded, failed = {}, {}
for _, m in ipairs(MODULES) do
    if matches(m) then
        local ok, err = pcall(function()
            load(m.Path)(Hub)
        end)
        if ok then
            loaded[#loaded + 1] = m.Name
        else
            failed[#failed + 1] = m.Name
        end
    end
end

Hub.Tracker.Start()

local autoOk, autoRes = Hub.Config.RunAutoload()

Hub.UI.Notify({
    Title = Hub.Name .. " loaded",
    Text = "Modules: " .. table.concat(loaded, ", ")
        .. (autoOk and ("\nConfig: " .. tostring(autoRes)) or "")
        .. "\nMenu: RightShift",
    Type = "good",
})
if #failed > 0 then
    Hub.UI.Notify({
        Title = "Modules failed to load",
        Text = table.concat(failed, ", ") .. " (see F9 console for details)",
        Type = "bad", Duration = 8,
    })
end
if autoOk == false then
    Hub.UI.Notify({ Title = "Autoload", Text = tostring(autoRes), Type = "warn" })
end

return Hub
