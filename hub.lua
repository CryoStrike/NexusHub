--[[
	NEXUS UI - Main Hub Module
]]

return function(REPO)
	local Nexus = loadstring(game:HttpGet(REPO .. "init.lua"))()
	local Locales = loadstring(game:HttpGet(REPO .. "locales.lua"))()

	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local VirtualUser = game:GetService("VirtualUser")
	local lp = Players.LocalPlayer

	local CAN_ICON = writefile ~= nil and isfile ~= nil and getcustomasset ~= nil
	local function icon(name)
		if CAN_ICON then return REPO .. "assets/icons/" .. name .. ".png" end
		return nil
	end

	local state = {
		language = "English",
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

	local function tr(key)
		local set = Locales.Strings[state.language]
		return (set and set[key]) or Locales.Strings.English[key] or key
	end

	-- Core Logic Loop
	local function getHumanoid()
		local char = lp.Character
		return char and char:FindFirstChildOfClass("Humanoid") or nil
	end

	local function getRootPart()
		local char = lp.Character
		return char and char:FindFirstChild("HumanoidRootPart") or nil
	end

	RunService.Stepped:Connect(function()
		local hum = getHumanoid()
		if hum then
			if state.walkSpeed and hum.WalkSpeed ~= state.walkSpeed then
				hum.WalkSpeed = state.walkSpeed
			end
			if state.jumpPower then
				if hum.RigType == Enum.HumanoidRigType.R15 and hum.UseJumpPower == false then
					local targetHeight = state.jumpPower / 5
					if hum.JumpHeight ~= targetHeight then hum.JumpHeight = targetHeight end
				else
					if hum.JumpPower ~= state.jumpPower then hum.JumpPower = state.jumpPower end
				end
			end
		end
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

	local Window
	local function notify(title, content, kind)
		if Window then Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = 3 }) end
	end

	local function build(rebuilt)
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

		-- Combat Tab
		local Combat = Window:CreateTab(tr("tab_combat"), icon("combat"))
		Combat:AddToggle({ Name = tr("combat_module"), Default = false, Flag = "combat_module", Callback = function(on) print("Combat:", on) end })
		Combat:AddSlider({ Name = tr("range"), Min = 0, Max = 1000, Default = 250, Increment = 1, Suffix = " / 1000", Flag = "combat_range", Callback = function(v) print("Range:", v) end })
		Combat:AddDropdown({ Name = tr("priority"), Options = { "Nearest", "Lowest Health", "Random" }, Default = "Nearest", Flag = "combat_priority", Callback = function(v) print("Priority:", v) end })
		Combat:AddKeybind({ Name = tr("combat_key"), Default = Enum.KeyCode.R, Flag = "combat_key", Callback = function(key) print("Key:", key.Name) end })

		-- Character Tab
		local Character = Window:CreateTab(tr("tab_character"), icon("character"))
		Character:AddSlider({
			Name = tr("walk_speed"), Min = 16, Max = 100, Default = state.walkSpeed, Increment = 1, Flag = "walk_speed",
			Callback = function(v) state.walkSpeed = v local hum = getHumanoid() if hum then hum.WalkSpeed = v end end,
		})
		Character:AddSlider({
			Name = tr("jump_power"), Min = 50, Max = 200, Default = state.jumpPower, Increment = 1, Flag = "jump_power",
			Callback = function(v) state.jumpPower = v local hum = getHumanoid() if hum then hum.JumpPower = v if hum.UseJumpPower == false then hum.JumpHeight = v / 5 end end end,
		})
		Character:AddToggle({ Name = tr("anti_afk"), Default = state.antiAfkEnabled, Flag = "anti_afk", Callback = function(on) state.antiAfkEnabled = on setupAntiAFK(on) end })
		Character:AddButton({ Name = tr("reset_char"), Callback = function() local hum = getHumanoid() if hum then hum.Health = 0 end notify(tr("tab_character"), tr("pressed")) end })

		-- Farm Tab
		local Farm = Window:CreateTab(tr("tab_farm"), icon("farm"))
		Farm:AddToggle({ Name = tr("farm_toggle"), Default = false, Flag = "farm_toggle", Callback = function(on) print("Farm:", on) end })
		Farm:AddDropdown({ Name = tr("farm_mode"), Options = { "Nearest", "Selected" }, Default = "Nearest", Flag = "farm_mode", Callback = function(v) print("Mode:", v) end })
		Farm:AddSlider({ Name = tr("farm_delay"), Min = 0, Max = 10, Default = 1, Increment = 1, Suffix = " s", Flag = "farm_delay", Callback = function(v) print("Delay:", v) end })
		Farm:AddInput({ Name = tr("target_name"), Placeholder = tr("target_ph"), Flag = "farm_target", Callback = function(text, enter) if enter then print("Target:", text) end end })

		-- Troll & Teleport Tab
		local Troll = Window:CreateTab(tr("tab_troll"), icon("troll"))
		Troll:AddToggle({ Name = tr("troll_module"), Default = false, Flag = "troll_module", Callback = function(on) print("Troll:", on) end })
		Troll:AddDropdown({ Name = tr("effect"), Options = { "Spin", "Bounce", "Shake" }, Default = "Spin", Flag = "troll_effect", Callback = function(v) print("Effect:", v) end })
		Troll:AddSlider({ Name = tr("intensity"), Min = 1, Max = 10, Default = 3, Increment = 1, Flag = "troll_intensity", Callback = function(v) print("Intensity:", v) end })
		Troll:AddDropdown({ Name = tr("tp_target"), Options = getPlayerNames(), Default = getPlayerNames()[1], Flag = "tp_target_dropdown", Callback = function(name) state.selectedTarget = name end })
		Troll:AddButton({
			Name = tr("tp_button"),
			Callback = function()
				local targetPlayer = Players:FindFirstChild(state.selectedTarget)
				if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local root = getRootPart()
					if root then
						root.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
						notify(tr("tab_troll"), string.format(tr("tp_success"), targetPlayer.Name), "Success")
					end
				else
					notify(tr("tab_troll"), tr("tp_err"), "Error")
				end
			end,
		})

		-- Visuals Tab
		local Visuals = Window:CreateTab(tr("tab_visuals"), icon("visuals"))
		local Display = Visuals:AddSection(tr("sec_display"))
		Display:AddToggle({ Name = tr("highlight"), Default = state.espEnabled, Flag = "highlight", Callback = function(on) state.espEnabled = on end })
		Display:AddSlider({ Name = tr("fov"), Min = 40, Max = 120, Default = 70, Increment = 1, Suffix = "°", Flag = "fov", Callback = function(v) workspace.CurrentCamera.FieldOfView = v end })
		
		local RoleColors = Visuals:AddSection(tr("sec_esp_colors"))
		RoleColors:AddColorPicker({ Name = tr("col_murder"), Default = state.colorMurderer, Flag = "col_murder", Callback = function(color) state.colorMurderer = color end })
		RoleColors:AddColorPicker({ Name = tr("col_sheriff"), Default = state.colorSheriff, Flag = "col_sheriff", Callback = function(color) state.colorSheriff = color end })
		RoleColors:AddColorPicker({ Name = tr("col_innocent"), Default = state.colorInnocent, Flag = "col_innocent", Callback = function(color) state.colorInnocent = color end })

		-- Settings Tab
		local Settings = Window:CreateTab(tr("tab_settings"), icon("settings"))
		local Theming = Settings:AddSection(tr("sec_theme"))
		Theming:AddDropdown({
			Name = tr("accent"), Options = { "Cyan", "Violet", "Emerald", "Crimson", "Gold", "Red", "Blue", "Green" }, Default = state.accentName,
			Callback = function(name) state.accentName = name Window:SetAccent(ACCENTS[name]) end,
		})

		local Interface = Settings:AddSection(tr("sec_interface"))
		Interface:AddKeybind({ Name = tr("hide_key"), Default = state.toggleKey, OnChanged = function(key) if key then state.toggleKey = key Window:SetToggleKey(key) end end })
		Interface:AddButton({ Name = tr("minimize"), Callback = function() Window:Minimize() end })
		Interface:AddDropdown({
			Name = tr("language"), Options = Locales.Languages, Default = state.language,
			Callback = function(lang)
				if lang == state.language then return end
				state.language = lang
				task.defer(function() Window:Destroy() build(true) end)
			end,
		})
		Interface:AddLabel({ Text = tr("resize_hint") })
		Interface:AddButton({ Name = tr("unload"), Callback = function() Nexus:Destroy() end })

		-- About Tab
		local About = Window:CreateTab(tr("tab_about"), icon("about"))
		local Info = About:AddSection(tr("about_title"))
		Info:AddLabel({ Text = string.format(tr("about_version"), tostring(Nexus.Version)) })
		Info:AddLabel({ Text = string.format(tr("about_signed"), lp.DisplayName, lp.Name) })
		Info:AddLabel({ Text = "github.com/CryoStrike/NexusUI" })

		if rebuilt then
			notify(tr("loaded_title"), string.format(tr("lang_set"), state.language), "Success")
		else
			notify(tr("loaded_title"), string.format(tr("loaded_text"), state.toggleKey.Name), "Success")
		end
	end

	local chosen = Nexus:Load({
		Name = "NEXUS", Subtitle = "TRANSLUCID THEME", Icon = REPO .. "assets/nexus-ico.png",
		Accent = ACCENTS.Cyan, Steps = { "Initializing", "Loading modules", "Preparing interface" },
		Duration = 3, Languages = Locales.Languages, DefaultLanguage = "English",
		LanguageTitle = "Select language", ContinueText = "Continue",
	})
	if not chosen then return end

	state.language = chosen
	build(false)
end