--[[
	NEXUS UI - Main Hub Module (All Categories Kept, Cleaned)
]]

return function(REPO, selectedLanguage)
	local Nexus = loadstring(game:HttpGet(REPO .. "init.lua"))()

	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local VirtualUser = game:GetService("VirtualUser")
	local lp = Players.LocalPlayer

	--------------------------------------------------------------- Tab icons
	local CAN_ICON = writefile ~= nil and isfile ~= nil and getcustomasset ~= nil
	local function icon(name)
		if CAN_ICON then return REPO .. "assets/icons/" .. name .. ".png" end
		return nil
	end

	local state = {
		language = selectedLanguage or "English",
		toggleKey = Enum.KeyCode.RightShift,
		accentName = "Cyan",
		walkSpeed = 16,
		jumpPower = 50,
		antiAfkEnabled = true,
		espEnabled = false,
		selectedTarget = nil,
		colorMurderer = Color3.fromRGB(255, 50, 50),
		colorSheriff = Color3.fromRGB(50, 100, 255),
		colorInnocent = Color3.fromRGB(50, 255, 50),
	}

	local ACCENTS = {
		Cyan = Color3.fromRGB(0, 170, 255), Violet = Color3.fromRGB(150, 110, 255),
		Emerald = Color3.fromRGB(40, 210, 140), Crimson = Color3.fromRGB(255, 80, 100), Gold = Color3.fromRGB(230, 190, 100),
		Red = Color3.fromRGB(255, 50, 50), Blue = Color3.fromRGB(50, 100, 255), Green = Color3.fromRGB(50, 255, 50),
	}

	--------------------------------------------------------------- Core Logic Loops
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
		if hum then
			hum.WalkSpeed = state.walkSpeed
			if hum.UseJumpPower == false then
				hum.JumpHeight = state.jumpPower / 5
			else
				hum.JumpPower = state.jumpPower
			end
		end
	end

	lp.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid")
		task.wait(0.2)
		applyCharacterStats()
	end)

	local antiAfkConnection
	local function setupAntiAFK(enabled)
		if enabled then
			if not antiAfkConnection then
				antiAfkConnection = lp.Idled:Connect(function()
					if state.antiAfkEnabled then
						VirtualUser:CaptureController()
						VirtualUser:ClickButton2(Vector2.new())
					end
				end)
			end
		else
			if antiAfkConnection then
				antiAfkConnection:Disconnect()
				antiAfkConnection = nil
			end
		end
	end
	setupAntiAFK(true)

	local function getPlayerNames()
		local names = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then table.insert(names, p.Name) end
		end
		if #names == 0 then table.insert(names, "None") end
		return names
	end

	-- MM2 ESP Setup
	local espHighlights = {}
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

	RunService.Heartbeat:Connect(function()
		if not state.espEnabled then
			for _, hl in pairs(espHighlights) do if hl then hl:Destroy() end end
			espHighlights = {}
			return
		end

		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= lp and player.Character then
				local char = player.Character
				local role = getMM2Role(player)
				local targetColor = state.colorInnocent
				if role == "Murderer" then targetColor = state.colorMurderer
				elseif role == "Sheriff" then targetColor = state.colorSheriff end

				local hl = espHighlights[player]
				if not hl or hl.Parent ~= char then
					if hl then hl:Destroy() end
					hl = Instance.new("Highlight")
					hl.Adornee = char
					hl.OutlineColor = Color3.fromRGB(255, 255, 255)
					hl.Parent = char
					espHighlights[player] = hl
				end
				hl.FillColor = targetColor
			end
		end
	end)

	--------------------------------------------------------------- Window Build
	local Window
	local function notify(title, content, kind)
		if Window then Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = 3 }) end
	end

	Window = Nexus:CreateWindow({
		Name = "NEXUS",
		Subtitle = "TRANSLUCID THEME",
		Icon = REPO .. "assets/nexus-ico.png",
		Accent = ACCENTS[state.accentName],
		ToggleKey = state.toggleKey,
		Size = UDim2.fromOffset(700, 500),
		Resizable = true,
		MinSize = Vector2.new(560, 360),
	})

	-- 1. Combat Tab
	local Combat = Window:CreateTab("Combat", icon("combat"))
	Combat:AddToggle({ Name = "Combat Module", Default = false, Flag = "combat_module", Callback = function(on) print("Combat:", on) end })
	Combat:AddSlider({ Name = "Range", Min = 0, Max = 1000, Default = 250, Increment = 1, Suffix = " / 1000", Flag = "combat_range", Callback = function(v) print("Range:", v) end })
	Combat:AddDropdown({ Name = "Target Priority", Options = { "Nearest", "Lowest Health", "Random" }, Default = "Nearest", Flag = "combat_priority", Callback = function(v) print("Priority:", v) end })
	Combat:AddKeybind({ Name = "Combat Key", Default = Enum.KeyCode.R, Flag = "combat_key", Callback = function(key) print("Key:", key.Name) end })

	-- 2. Character Tab
	local Character = Window:CreateTab("Character", icon("character"))
	Character:AddSlider({
		Name = "Walk Speed", Min = 16, Max = 100, Default = state.walkSpeed, Increment = 1, Flag = "walk_speed",
		Callback = function(v) state.walkSpeed = v applyCharacterStats() end,
	})
	Character:AddSlider({
		Name = "Jump Power", Min = 50, Max = 200, Default = state.jumpPower, Increment = 1, Flag = "jump_power",
		Callback = function(v) state.jumpPower = v applyCharacterStats() end,
	})
	Character:AddToggle({ Name = "Anti-AFK", Default = state.antiAfkEnabled, Flag = "anti_afk", Callback = function(on) state.antiAfkEnabled = on setupAntiAFK(on) end })
	Character:AddButton({ Name = "Reset Character", Callback = function() local hum = getHumanoid() if hum then hum.Health = 0 end notify("Character", "Reset requested.") end })

	-- 3. Farm Tab
	local Farm = Window:CreateTab("Farm", icon("farm"))
	Farm:AddToggle({ Name = "Auto Farm", Default = false, Flag = "farm_toggle", Callback = function(on) print("Farm:", on) end })
	Farm:AddDropdown({ Name = "Farm Mode", Options = { "Nearest", "Selected" }, Default = "Nearest", Flag = "farm_mode", Callback = function(v) print("Mode:", v) end })
	Farm:AddSlider({ Name = "Farm Delay", Min = 0, Max = 10, Default = 1, Increment = 1, Suffix = " s", Flag = "farm_delay", Callback = function(v) print("Delay:", v) end })
	Farm:AddInput({ Name = "Target Name", Placeholder = "Enter a name...", Flag = "farm_target", Callback = function(text, enter) if enter then print("Target:", text) end end })

	-- 4. Troll & Teleport Tab
	local Troll = Window:CreateTab("Troll", icon("troll"))
	Troll:AddToggle({ Name = "Troll Module", Default = false, Flag = "troll_module", Callback = function(on) print("Troll:", on) end })
	Troll:AddDropdown({ Name = "Effect", Options = { "Spin", "Bounce", "Shake" }, Default = "Spin", Flag = "troll_effect", Callback = function(v) print("Effect:", v) end })
	Troll:AddSlider({ Name = "Intensity", Min = 1, Max = 10, Default = 3, Increment = 1, Flag = "troll_intensity", Callback = function(v) print("Intensity:", v) end })
	Troll:AddDropdown({ Name = "Select Target", Options = getPlayerNames(), Default = getPlayerNames()[1], Flag = "tp_target_dropdown", Callback = function(name) state.selectedTarget = name end })
	Troll:AddButton({
		Name = "Teleport to Player",
		Callback = function()
			local targetPlayer = Players:FindFirstChild(state.selectedTarget)
			if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local root = getRootPart()
				if root then
					root.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
					notify("Teleport", "Teleported to " .. targetPlayer.Name, "Success")
				end
			else
				notify("Teleport", "Invalid target player.", "Error")
			end
		end,
	})
	Troll:AddButton({ Name = "Run Effect", Callback = function() notify("Troll", "Effect started.", "Success") end })
	Troll:AddButton({ Name = "Stop All", Callback = function() notify("Troll", "Effects stopped.", "Warning") end })

	-- 5. Visuals Tab
	local Visuals = Window:CreateTab("Visuals", icon("visuals"))
	local Display = Visuals:AddSection("Display & ESP")
	Display:AddToggle({ Name = "Player ESP", Default = state.espEnabled, Flag = "highlight", Callback = function(on) state.espEnabled = on end })
	Display:AddSlider({ Name = "Field of View", Min = 40, Max = 120, Default = 70, Increment = 1, Suffix = "°", Flag = "fov", Callback = function(v) workspace.CurrentCamera.FieldOfView = v end })
	Display:AddDropdown({ Name = "Style", Options = { "Balanced", "Performance", "Quality" }, Default = "Balanced", Callback = function(v) print("Style:", v) end })

	local RoleColors = Visuals:AddSection("ESP Role Colors")
	RoleColors:AddColorPicker({ Name = "Murderer Color", Default = state.colorMurderer, Flag = "col_murder", Callback = function(color) state.colorMurderer = color end })
	RoleColors:AddColorPicker({ Name = "Sheriff Color", Default = state.colorSheriff, Flag = "col_sheriff", Callback = function(color) state.colorSheriff = color end })
	RoleColors:AddColorPicker({ Name = "Innocent Color", Default = state.colorInnocent, Flag = "col_innocent", Callback = function(color) state.colorInnocent = color end })

	-- 6. Settings Tab
	local Settings = Window:CreateTab("Settings", icon("settings"))
	local Theming = Settings:AddSection("Theme Selection")
	Theming:AddDropdown({
		Name = "Accent Colour", Options = { "Cyan", "Violet", "Emerald", "Crimson", "Gold", "Red", "Blue", "Green" }, Default = state.accentName,
		Callback = function(name) state.accentName = name Window:SetAccent(ACCENTS[name]) end,
	})

	local Interface = Settings:AddSection("Interface")
	Interface:AddKeybind({ Name = "Hide Hub Key", Default = state.toggleKey, OnChanged = function(key) if key then state.toggleKey = key Window:SetToggleKey(key) end end })
	Interface:AddButton({ Name = "Minimize Hub", Callback = function() Window:Minimize() end })
	Interface:AddLabel({ Text = "Language set to: " .. state.language })
	Interface:AddButton({ Name = "Unload NEXUS", Callback = function() Nexus:Destroy() end })

	-- 7. About Tab
	local About = Window:CreateTab("About", icon("about"))
	local Info = About:AddSection("NEXUS UI")
	Info:AddLabel({ Text = string.format("Translucid Theme - v%s", tostring(Nexus.Version)) })
	Info:AddLabel({ Text = string.format("Signed in as %s (@%s)", lp.DisplayName, lp.Name) })
	Info:AddLabel({ Text = "github.com/CryoStrike/NexusUI" })

	notify("NEXUS Loaded", "Press " .. state.toggleKey.Name .. " to toggle the hub.", "Success")
end
