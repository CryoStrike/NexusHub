--[[
	NEXUS HUB  -  hub.lua      (what the hub does + its UI)

	Loaded by init.lua, which hands over three things:
		Nexus     the UI library (NexusUI, Library.lua)
		Language  the texts      (languages.lua)
		Config    { Name, Subtitle, Icon, Assets }   shared settings from init.lua

	This file has two parts:
		1. FEATURES    what the hub actually does (ESP, walk speed, anti-AFK, teleport ...)
		2. CATEGORIES  the UI: one function per category + the CATEGORIES list at the bottom

	HOW TO EDIT
		Add a button / slider / toggle ...  open that category's function (buildCombat, buildFarm ...)
		                                    and add a  tab:AddButton({ ... })  line.
		Add a category ..................... 1. write a  local function buildMyCategory(tab) ... end
		                                     2. add one line for it in the CATEGORIES list
		                                     3. add its name to languages.lua:  tab_mycategory = "My Category"
		Remove / reorder a category ........ delete or move its line in the CATEGORIES list
		Change a category icon ............. the  icon  field in CATEGORIES (file name in NexusUI/assets/icons/)
		Change window size, resizing ....... the CreateWindow options in Hub.Build (bottom of this file)
		Change a visible text .............. languages.lua  (every text is  tr("key"))
]]

local Nexus, Language, Config = ...
local tr = Language.tr

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local lp = Players.LocalPlayer

local Hub = {}

--------------------------------------------------------------- Settings
local ACCENTS = {
	Cyan = Color3.fromRGB(0, 170, 255), Violet = Color3.fromRGB(150, 110, 255),
	Emerald = Color3.fromRGB(40, 210, 140), Crimson = Color3.fromRGB(255, 80, 100), Gold = Color3.fromRGB(230, 190, 100),
	Red = Color3.fromRGB(255, 50, 50), Blue = Color3.fromRGB(50, 100, 255), Green = Color3.fromRGB(50, 255, 50),
}
local ACCENT_NAMES = { "Cyan", "Violet", "Emerald", "Crimson", "Gold", "Red", "Blue", "Green" }
Hub.Accent = ACCENTS.Cyan -- accent used by the loading screen (init.lua) and by the first window

-- Kept across rebuilds (a language change rebuilds the window and must not reset these)
local state = {
	toggleKey = Enum.KeyCode.RightShift,
	accentName = "Cyan",
	walkSpeed = 16, walkTouched = false, -- a stat is only forced onto the character after the player moved its slider
	jumpPower = 50, jumpTouched = false,
	fov = 70, fovTouched = false,
	antiAfkEnabled = true,
	espEnabled = false,
	selectedTarget = nil,
	colorMurderer = Color3.fromRGB(255, 50, 50),
	colorSheriff = Color3.fromRGB(50, 100, 255),
	colorInnocent = Color3.fromRGB(50, 255, 50),
}

local Window         -- the current hub window
local rebuilding = false
local running = false -- true while the features below are active

--------------------------------------------------------------- Tab icons
-- White PNGs from NexusUI/assets/icons/ (NEXUS tints them: grey, or the accent colour when selected).
-- Downloading them needs writefile + isfile + getcustomasset. Without those the tabs are text-only.
-- To use Roblox images instead, make icon() return "rbxassetid://<image id>".
local CAN_ICON = writefile ~= nil and isfile ~= nil and getcustomasset ~= nil
if not CAN_ICON then
	warn("[NEXUS] this executor lacks writefile/isfile/getcustomasset: tab icons are off (use rbxassetid:// icons instead).")
end
local function icon(name)
	if CAN_ICON and name then return Config.Assets .. "assets/icons/" .. name .. ".png" end
	return nil
end

local function notify(title, content, kind)
	if Window then Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = 3 }) end
end

--==============================================================================
--  1. FEATURES
--==============================================================================
local connections = {}
local antiAfkConnection
local espHighlights = {}
local originals = {}      -- game values to give back when the hub is unloaded
local targetDropdown      -- the "Select Target" dropdown of the current window

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function getHumanoid()
	local char = lp.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart()
	local char = lp.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function applyCharacterStats()
	local hum = getHumanoid()
	if not hum then return end
	if state.walkTouched then hum.WalkSpeed = state.walkSpeed end
	if state.jumpTouched then
		if hum.UseJumpPower == false then
			hum.JumpHeight = state.jumpPower / 5
		else
			hum.JumpPower = state.jumpPower
		end
	end
end

local function setAntiAfk(enabled)
	if enabled and not antiAfkConnection then
		antiAfkConnection = lp.Idled:Connect(function()
			if state.antiAfkEnabled then
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end
		end)
	elseif not enabled and antiAfkConnection then
		antiAfkConnection:Disconnect()
		antiAfkConnection = nil
	end
end

-- Names of the other players in the server (sorted). `leaving` is a player that is about to go.
local function getPlayerNames(leaving)
	local names = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp and p ~= leaving then table.insert(names, p.Name) end
	end
	table.sort(names)
	return names
end

-- Keep state.selectedTarget valid and the "Select Target" dropdown up to date.
local function refreshTargets(leaving)
	local names = getPlayerNames(leaving)
	local stillThere = false
	for _, n in ipairs(names) do
		if n == state.selectedTarget then stillThere = true end
	end
	if not stillThere then state.selectedTarget = names[1] end -- nil when nobody else is in the server
	if targetDropdown then
		targetDropdown:SetOptions(#names > 0 and names or { "None" })
		targetDropdown:Set(state.selectedTarget or "None", true)
	end
end

-- MM2 ESP
local function getMM2Role(player)
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")
	if (char and char:FindFirstChild("Knife")) or (backpack and backpack:FindFirstChild("Knife")) then
		return "Murderer"
	end
	if (char and (char:FindFirstChild("Gun") or char:FindFirstChild("Revolver"))) or
	   (backpack and (backpack:FindFirstChild("Gun") or backpack:FindFirstChild("Revolver"))) then
		return "Sheriff"
	end
	return "Innocent"
end

local function clearEsp()
	for _, hl in pairs(espHighlights) do pcall(function() hl:Destroy() end) end
	espHighlights = {}
end

local function updateEsp()
	if not state.espEnabled then return end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= lp and player.Character then
			local char = player.Character
			local role = getMM2Role(player)
			local color = state.colorInnocent
			if role == "Murderer" then color = state.colorMurderer
			elseif role == "Sheriff" then color = state.colorSheriff end

			local hl = espHighlights[player]
			if not hl or hl.Parent ~= char then
				if hl then hl:Destroy() end
				hl = Instance.new("Highlight")
				hl.Adornee = char
				hl.OutlineColor = Color3.fromRGB(255, 255, 255)
				hl.Parent = char
				espHighlights[player] = hl
			end
			hl.FillColor = color
		end
	end
end

local function startFeatures()
	if running then return end
	running = true

	-- remember what the game had, so unloading can give it back
	local hum, cam = getHumanoid(), workspace.CurrentCamera
	originals = {
		walkSpeed = hum and hum.WalkSpeed, jumpPower = hum and hum.JumpPower,
		jumpHeight = hum and hum.JumpHeight, fov = cam and cam.FieldOfView,
	}
	if cam then state.fov = math.clamp(math.floor(cam.FieldOfView + 0.5), 40, 120) end

	setAntiAfk(state.antiAfkEnabled)
	connect(RunService.Heartbeat, updateEsp)
	connect(lp.CharacterAdded, function(char)
		if not char:WaitForChild("Humanoid", 10) then return end
		task.wait(0.2)
		if running then applyCharacterStats() end
	end)
	connect(Players.PlayerAdded, function() refreshTargets() end)
	connect(Players.PlayerRemoving, function(player)
		local hl = espHighlights[player]
		if hl then
			pcall(function() hl:Destroy() end)
			espHighlights[player] = nil
		end
		refreshTargets(player)
	end)
	refreshTargets()
end

-- Disconnect everything, remove the ESP and give back the changed game values.
local function stopFeatures()
	if not running then return end
	running = false
	for _, c in ipairs(connections) do c:Disconnect() end
	connections = {}
	setAntiAfk(false)
	clearEsp()
	state.espEnabled = false
	targetDropdown = nil

	local hum, cam = getHumanoid(), workspace.CurrentCamera
	if hum then
		if state.walkTouched and originals.walkSpeed then hum.WalkSpeed = originals.walkSpeed end
		if state.jumpTouched then
			if hum.UseJumpPower == false then
				if originals.jumpHeight then hum.JumpHeight = originals.jumpHeight end
			elseif originals.jumpPower then
				hum.JumpPower = originals.jumpPower
			end
		end
	end
	if cam and state.fovTouched and originals.fov then cam.FieldOfView = originals.fov end
end

--==============================================================================
--  2. CATEGORIES   (one function per category; `tab` is where you add components)
--==============================================================================

---------------------------------------------------------------- Combat
local function buildCombat(tab)
	tab:AddToggle({ Name = tr("combat_module"), Default = false, Flag = "combat_module", Callback = function(on) print("Combat:", on) end })
	tab:AddSlider({ Name = tr("range"), Min = 0, Max = 1000, Default = 250, Increment = 1, Suffix = " / 1000", Flag = "combat_range", Callback = function(v) print("Range:", v) end })
	tab:AddDropdown({ Name = tr("priority"), Options = { "Nearest", "Lowest Health", "Random" }, Default = "Nearest", Flag = "combat_priority", Callback = function(v) print("Priority:", v) end })
	tab:AddKeybind({ Name = tr("combat_key"), Default = Enum.KeyCode.R, Flag = "combat_key", Callback = function(key) print("Key:", key.Name) end })
end

---------------------------------------------------------------- Character
local function buildCharacter(tab)
	tab:AddSlider({
		Name = tr("walk_speed"), Min = 16, Max = 100, Default = state.walkSpeed, Increment = 1, Flag = "walk_speed",
		Callback = function(v) state.walkSpeed = v state.walkTouched = true applyCharacterStats() end,
	})
	tab:AddSlider({
		Name = tr("jump_power"), Min = 50, Max = 200, Default = state.jumpPower, Increment = 1, Flag = "jump_power",
		Callback = function(v) state.jumpPower = v state.jumpTouched = true applyCharacterStats() end,
	})
	tab:AddToggle({
		Name = tr("anti_afk"), Default = state.antiAfkEnabled, Flag = "anti_afk",
		Callback = function(on) state.antiAfkEnabled = on setAntiAfk(on) end,
	})
	tab:AddButton({
		Name = tr("reset_char"),
		Callback = function()
			local hum = getHumanoid()
			if hum then hum.Health = 0 end
			notify(tr("tab_character"), tr("reset_requested"))
		end,
	})
end

---------------------------------------------------------------- Farm
local function buildFarm(tab)
	tab:AddToggle({ Name = tr("farm_toggle"), Default = false, Flag = "farm_toggle", Callback = function(on) print("Farm:", on) end })
	tab:AddDropdown({ Name = tr("farm_mode"), Options = { "Nearest", "Selected" }, Default = "Nearest", Flag = "farm_mode", Callback = function(v) print("Mode:", v) end })
	tab:AddSlider({ Name = tr("farm_delay"), Min = 0, Max = 10, Default = 1, Increment = 1, Suffix = " s", Flag = "farm_delay", Callback = function(v) print("Delay:", v) end })
	tab:AddInput({ Name = tr("target_name"), Placeholder = tr("target_ph"), Flag = "farm_target", Callback = function(text, enter) if enter then print("Target:", text) end end })
end

---------------------------------------------------------------- Troll
local function buildTroll(tab)
	tab:AddToggle({ Name = tr("troll_module"), Default = false, Flag = "troll_module", Callback = function(on) print("Troll:", on) end })
	tab:AddDropdown({ Name = tr("effect"), Options = { "Spin", "Bounce", "Shake" }, Default = "Spin", Flag = "troll_effect", Callback = function(v) print("Effect:", v) end })
	tab:AddSlider({ Name = tr("intensity"), Min = 1, Max = 10, Default = 3, Increment = 1, Flag = "troll_intensity", Callback = function(v) print("Intensity:", v) end })

	local names = getPlayerNames()
	targetDropdown = tab:AddDropdown({
		Name = tr("tp_target"), Options = #names > 0 and names or { "None" }, Default = state.selectedTarget or "None", Flag = "tp_target_dropdown",
		Callback = function(name)
			for _, n in ipairs(getPlayerNames()) do
				if n == name then state.selectedTarget = name return end
			end
		end,
	})
	tab:AddButton({
		Name = tr("tp_button"),
		Callback = function()
			local target = state.selectedTarget and Players:FindFirstChild(state.selectedTarget)
			local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			local root = getRootPart()
			if targetRoot and root then
				root.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
				notify(tr("tp_title"), tr("tp_success", target.Name), "Success")
			else
				notify(tr("tp_title"), tr("tp_err"), "Error")
			end
		end,
	})
	tab:AddButton({ Name = tr("run_effect"), Callback = function() notify(tr("tab_troll"), tr("effect_started"), "Success") end })
	tab:AddButton({ Name = tr("stop_all"), Callback = function() notify(tr("tab_troll"), tr("effects_stopped"), "Warning") end })
end

---------------------------------------------------------------- Visuals
local function buildVisuals(tab)
	local display = tab:AddSection(tr("sec_display"))
	display:AddToggle({
		Name = tr("highlight"), Default = state.espEnabled, Flag = "highlight",
		Callback = function(on)
			state.espEnabled = on
			if not on then clearEsp() end
		end,
	})
	display:AddSlider({
		Name = tr("fov"), Min = 40, Max = 120, Default = state.fov, Increment = 1, Suffix = "°", Flag = "fov",
		Callback = function(v)
			state.fov = v
			state.fovTouched = true
			local cam = workspace.CurrentCamera
			if cam then cam.FieldOfView = v end
		end,
	})
	display:AddDropdown({ Name = tr("style"), Options = { "Balanced", "Performance", "Quality" }, Default = "Balanced", Callback = function(v) print("Style:", v) end })

	local roleColors = tab:AddSection(tr("sec_esp_colors"))
	roleColors:AddColorPicker({ Name = tr("col_murder"), Default = state.colorMurderer, Flag = "col_murder", Callback = function(color) state.colorMurderer = color end })
	roleColors:AddColorPicker({ Name = tr("col_sheriff"), Default = state.colorSheriff, Flag = "col_sheriff", Callback = function(color) state.colorSheriff = color end })
	roleColors:AddColorPicker({ Name = tr("col_innocent"), Default = state.colorInnocent, Flag = "col_innocent", Callback = function(color) state.colorInnocent = color end })
end

---------------------------------------------------------------- Settings
local function buildSettings(tab)
	local theming = tab:AddSection(tr("sec_theme"))
	theming:AddDropdown({
		Name = tr("accent"), Options = ACCENT_NAMES, Default = state.accentName,
		Callback = function(name)
			state.accentName = name
			Window:SetAccent(ACCENTS[name])
		end,
	})

	local interface = tab:AddSection(tr("sec_interface"))
	interface:AddKeybind({
		Name = tr("hide_key"), Default = state.toggleKey,
		OnChanged = function(key)
			if key then
				state.toggleKey = key
				Window:SetToggleKey(key)
			end
		end,
	})
	interface:AddButton({ Name = tr("minimize"), Callback = function() Window:Minimize() end })
	interface:AddDropdown({
		Name = tr("language"), Options = Language.List, Default = Language.Current,
		Callback = function(lang)
			if lang == Language.Current then return end
			if Language.set(lang) then
				task.defer(Hub.Rebuild) -- rebuild the window in the new language
			end
		end,
	})
	interface:AddLabel({ Text = tr("resize_hint") })
	interface:AddButton({ Name = tr("unload"), Callback = function() Nexus:Destroy() end })
end

---------------------------------------------------------------- About
local function buildAbout(tab)
	local info = tab:AddSection(tr("about_title"))
	info:AddLabel({ Text = tr("about_version", tostring(Nexus.Version)) })
	info:AddLabel({ Text = tr("about_signed", lp.DisplayName, lp.Name) })
	info:AddLabel({ Text = "github.com/CryoStrike/NexusUI" })
end

--==============================================================================
--  CATEGORY LIST   (sidebar order, top to bottom)
--      name   key in languages.lua for the category name
--      icon   file name in NexusUI/assets/icons/ (without .png), or nil for text only
--      build  the function above that fills the category
--==============================================================================
local CATEGORIES = {
	{ name = "tab_combat",    icon = "combat",    build = buildCombat },
	{ name = "tab_character", icon = "character", build = buildCharacter },
	{ name = "tab_farm",      icon = "farm",      build = buildFarm },
	{ name = "tab_troll",     icon = "troll",     build = buildTroll },
	{ name = "tab_visuals",   icon = "visuals",   build = buildVisuals },
	{ name = "tab_settings",  icon = "settings",  build = buildSettings },
	{ name = "tab_about",     icon = "about",     build = buildAbout },
}

--==============================================================================
--  BUILD
--==============================================================================
function Hub.Build(rebuilt)
	startFeatures()

	Window = Nexus:CreateWindow({
		Name = Config.Name,
		Subtitle = Config.Subtitle,
		Icon = Config.Icon, -- or "rbxassetid://<uploaded logo id>"
		Accent = ACCENTS[state.accentName],
		ToggleKey = state.toggleKey,
		Size = UDim2.fromOffset(700, 500),
		Resizable = true,
		MinSize = Vector2.new(560, 360),
	})
	-- Closing the window (x), Nexus:Destroy() and re-running the script all end up here.
	-- A language change also destroys the window, but must keep the features running.
	Window.Maid:Give(function()
		if not rebuilding then stopFeatures() end
	end)

	for _, category in ipairs(CATEGORIES) do
		local tab = Window:CreateTab(tr(category.name), icon(category.icon))
		category.build(tab)
	end

	if rebuilt then
		notify(tr("loaded_title"), tr("lang_set", Language.Current), "Success")
	else
		notify(tr("loaded_title"), tr("loaded_text", state.toggleKey.Name), "Success")
	end
end

-- Destroy the window and build it again (used when the language changes)
function Hub.Rebuild()
	if not running then return end -- the hub was closed in the meantime
	rebuilding = true
	targetDropdown = nil
	if Window then Window:Destroy() end
	rebuilding = false
	Hub.Build(true)
end

return Hub
