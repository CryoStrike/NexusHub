--[[
	NEXUS HUB  -  init.lua      (the LAUNCHER: run this one)

		loadstring(game:HttpGet("https://raw.githubusercontent.com/CryoStrike/NexusHub/main/init.lua"))()

	What it does, in order:
		1. loads the UI library from the NexusUI repo   (Library.lua)
		2. languages.lua  texts + languages               -> edit it to translate / add a language
		3. hub.lua        features + the hub UI           -> edit it to change categories, buttons ...
		4. shows the loading screen + language picker, then opens the hub

	Dev options (set BEFORE running):
		getgenv().NEXUSHUB_BASE  = "https://raw.githubusercontent.com/<user>/<repo>/<branch>/"   -- test another branch / fork of THIS repo
		getgenv().NEXUSHUB_LOCAL = true   -- read languages.lua and hub.lua from <workspace>/NexusHub/ instead of GitHub
		getgenv().NEXUS_BASE     = "https://raw.githubusercontent.com/CryoStrike/NexusUI/<branch>/"   -- test another NexusUI branch
]]

local env = (getgenv and getgenv()) or _G
local HUB_BASE = env.NEXUSHUB_BASE or "https://raw.githubusercontent.com/CryoStrike/NexusHub/main/"
local UI_BASE  = env.NEXUS_BASE or "https://raw.githubusercontent.com/CryoStrike/NexusUI/main/"
local LOCAL = env.NEXUSHUB_LOCAL == true

-- Settings shared with hub.lua (and used by the loading screen below).
-- The logo and the tab icons are not stored in this repo: they come from NexusUI.
local Config = {
	Name = "NEXUS",
	Subtitle = "TRANSLUCID THEME",
	Assets = UI_BASE,
	Icon = UI_BASE .. "assets/nexus-ico.png", -- or "rbxassetid://<uploaded logo id>"
}

local function fetch(url)
	local ok, body = pcall(function() return game:HttpGet(url) end)
	assert(ok and type(body) == "string", "[NexusHub] failed to fetch " .. url)
	return body
end

local function execute(label, source, ...)
	local fn, err = loadstring(source, "=" .. label)
	assert(fn, "[NexusHub] syntax error in '" .. label .. "': " .. tostring(err))
	return fn(...)
end

-- Run one of THIS repo's scripts (languages.lua, hub.lua). Extra arguments are handed over as `...`.
local function run(path, ...)
	local source
	if LOCAL then
		local ok, data = pcall(readfile, "NexusHub/" .. path)
		assert(ok and type(data) == "string", "[NexusHub] could not read NexusHub/" .. path)
		source = data
	else
		source = fetch(HUB_BASE .. path)
	end
	return execute("NexusHub/" .. path, source, ...)
end

-- The UI library. Loading it also removes a previous NEXUS (and its hub) if you run the script twice.
local Nexus = execute("NexusUI/Library.lua", fetch(UI_BASE .. "Library.lua"))
assert(type(Nexus) == "table" and Nexus.CreateWindow and Nexus.Load, "[NexusHub] NexusUI/Library.lua did not return the library")

local Language = run("languages.lua")
local Hub      = run("hub.lua", Nexus, Language, Config)

-- Tell the developer about untranslated texts (nothing breaks, English is shown instead)
for _, problem in ipairs(Language.Validate()) do
	warn("[NexusHub] language: " .. problem)
end

-- Loading animation, then the language picker. Yields until the user presses Continue.
local chosen = Nexus:Load({
	Name = Config.Name,
	Subtitle = Config.Subtitle,
	Icon = Config.Icon,
	Accent = Hub.Accent,
	Steps = { "Initializing", "Loading modules", "Preparing interface" },
	Duration = 3,
	Languages = Language.List,
	DefaultLanguage = Language.Default,
	LanguageTitle = "Select language",
	ContinueText = "Continue",
})
if not chosen then return end -- loader was closed (e.g. the script was re-executed)

Language.set(chosen)
Hub.Build()
