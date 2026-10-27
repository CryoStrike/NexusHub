--[[
    NEXUS UI - Master Loader
    Usage:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/init.lua"))()
]]

local REPO = "https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME/main/"
local HubModule = loadstring(game:HttpGet(REPO .. "hub.lua"))

if HubModule then
    HubModule(REPO)
else
    warn("[NEXUS]: Failed to load main hub module.")
end