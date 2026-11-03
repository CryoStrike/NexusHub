--[[
	NEXUS HUB  -  hub.lua      (what the hub does + its UI)

	Loaded by init.lua, which hands over three things:
		Nexus     the UI library (NexusUI, Library.lua)
		Language  the texts      (languages.lua)
		Config    { Name, Subtitle, Icon, Assets }   shared settings from init.lua

	This file has two parts:
		1. FEATURES    what the hub actually does (aimbot, fly, invisible, auto farm, ESP, teleport ...)
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
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer

local Hub = {}

--------------------------------------------------------------- Settings
local ACCENTS = {
	Cyan = Color3.fromRGB(0, 224, 255), Violet = Color3.fromRGB(150, 110, 255),
	Emerald = Color3.fromRGB(40, 210, 140), Crimson = Color3.fromRGB(255, 80, 100), Gold = Color3.fromRGB(230, 190, 100),
	Red = Color3.fromRGB(255, 50, 50), Blue = Color3.fromRGB(50, 100, 255), Green = Color3.fromRGB(50, 255, 50),
}
local ACCENT_NAMES = { "Cyan", "Violet", "Emerald", "Crimson", "Gold", "Red", "Blue", "Green" }
Hub.Accent = ACCENTS.Cyan -- accent used by the loading screen (init.lua) and by the first window

-- Kept across rebuilds (a language change rebuilds the window and must not reset these)
local state = {
	toggleKey = Enum.KeyCode.RightShift,
	accentName = "Cyan",
	fov = 70, fovTouched = false,
	antiAfkEnabled = true,
	selectedTarget = nil,

	-- Character
	walkSpeed = 16, walkSpeedActive = false,
	jumpPower = 50, jumpPowerActive = false,
	flyEnabled = false, flySpeed = 50, flyPose = false, flyTwoArms = false,
	noclipEnabled = false, infJumpEnabled = false,
	invisibleEnabled = false, invisibleDepth = 200000, ghostAlpha = 0.5, revealKey = Enum.KeyCode.R,

	-- Combat / Troll / Farm / TP
	aimbotEnabled = false, aimbotRange = 250,
	flingEnabled = false, killAllEnabled = false,
	autoFarm = false, farmMethod = "Nearest Coin", farmSpeed = 20, farmOffset = 1, farmStay = 0.4,
	autoGrabGun = false,

	-- Visuals
	espEnabled = false,
	colorMurderer = Color3.fromRGB(255, 50, 50),
	colorSheriff = Color3.fromRGB(50, 100, 255),
	colorInnocent = Color3.fromRGB(50, 255, 50),

	-- Keybinds (nil = not set)
	keyGrabGun = nil, keyInfJump = nil, keyFly = nil, keyWalkSpeed = nil, keyNoclip = nil, keyJumpPower = nil,
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
local session = 0             -- bumped on every start; background loops stop when it changes
local antiAfkConnection
local espHighlights = {}
local originals = {}          -- game values to give back when the hub is unloaded
local targetDropdowns = {}    -- every "Select Target" dropdown of the current window
local refs = {}               -- UI elements that key presses keep in sync (walk, jump, fly, noclip, infjump)
local setters = {}            -- feature name -> function(on) that applies it

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

-- Runs fn every `delay` seconds until the hub is unloaded.
local function loop(delay, fn)
	local mine = session
	task.spawn(function()
		while running and session == mine do
			task.wait(delay)
			if not (running and session == mine) then break end
			local ok, err = pcall(fn)
			if not ok then warn("[NEXUS] " .. tostring(err)) end
		end
	end)
end

local function getHumanoid()
	local char = lp.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function getRootPart()
	local char = lp.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function getParts()
	local char = lp.Character
	return char, getRootPart(), getHumanoid()
end

local walkApplied, jumpApplied = false, false
local function applyCharacterStats()
	local hum = getHumanoid()
	if not hum then return end
	if state.walkSpeedActive then
		hum.WalkSpeed = state.walkSpeed
		walkApplied = true
	elseif walkApplied then
		hum.WalkSpeed = originals.walkSpeed or 16
		walkApplied = false
	end
	if state.jumpPowerActive then
		jumpApplied = true
		if hum.UseJumpPower == false then hum.JumpHeight = state.jumpPower / 5 else hum.JumpPower = state.jumpPower end
	elseif jumpApplied then
		jumpApplied = false
		if hum.UseJumpPower == false then hum.JumpHeight = originals.jumpHeight or 7.2 else hum.JumpPower = originals.jumpPower or 50 end
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

-- Keep state.selectedTarget valid and every "Select Target" dropdown up to date.
local function refreshTargets(leaving)
	local names = getPlayerNames(leaving)
	local stillThere = false
	for _, n in ipairs(names) do
		if n == state.selectedTarget then stillThere = true end
	end
	if not stillThere then state.selectedTarget = names[1] end -- nil when nobody else is in the server
	for _, dd in ipairs(targetDropdowns) do
		dd:SetOptions(#names > 0 and names or { "None" })
		dd:Set(state.selectedTarget or "None", true)
	end
end

local function targetRoot()
	local target = state.selectedTarget and Players:FindFirstChild(state.selectedTarget)
	local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	return target, root
end

---------------------------------------------------------------- Roles + ESP (Murder Mystery 2)
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

---------------------------------------------------------------- Noclip
local noclipParts = {} -- parts whose collision we turned off (given back afterwards)
local function restoreCollisions()
	for part in pairs(noclipParts) do
		if part.Parent then part.CanCollide = true end
	end
	noclipParts = {}
end

local function noclipStep()
	if not (state.noclipEnabled or state.autoFarm or state.flingEnabled or state.killAllEnabled) then return end
	local char = lp.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			noclipParts[part] = true
			part.CanCollide = false
		end
	end
end

---------------------------------------------------------------- Aimbot (smart role mode)
local function aimbotStep()
	if not state.aimbotEnabled then return end
	local _, myRoot = getParts()
	local camera = Workspace.CurrentCamera
	if not myRoot or not camera then return end

	local myRole = getMM2Role(lp)
	if myRole == "Innocent" then return end

	local closest, shortest = nil, state.aimbotRange
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hum = char and char:FindFirstChild("Humanoid")
		if player ~= lp and char and char:FindFirstChild("HumanoidRootPart") and hum and hum.Health > 0 then
			local role = getMM2Role(player)
			local pos = char:FindFirstChild("Head") and char.Head.Position or char.HumanoidRootPart.Position
			local dist = (myRoot.Position - pos).Magnitude
			local wanted = ((myRole == "Sheriff" or myRole == "Hero") and role == "Murderer") or (myRole == "Murderer" and role == "Sheriff")
			if wanted and dist <= state.aimbotRange and dist < shortest then
				shortest, closest = dist, pos
			end
		end
	end
	if closest then camera.CFrame = CFrame.new(camera.CFrame.Position, closest) end
end

---------------------------------------------------------------- Invisible (GhostTrick)
-- Each frame the character is moved far below the map for the server, then put back before it is drawn.
local ghostChar, ghostRoot, ghostHum
local savedTransform, savedCamOffset
local currentFade = 0
local cachedParts, cachedTime = {}, 0

local function applyLocalTransparency(value)
	if not ghostChar then return end
	if os.clock() - cachedTime > 1 then
		cachedParts, cachedTime = {}, os.clock()
		for _, d in ipairs(ghostChar:GetDescendants()) do
			if (d:IsA("BasePart") or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" then
				table.insert(cachedParts, d)
			end
		end
	end
	for _, p in ipairs(cachedParts) do
		if p.Parent then p.LocalTransparencyModifier = value end
	end
end

local function restoreGhostPosition()
	if savedTransform and ghostRoot and ghostRoot.Parent and ghostHum then
		ghostRoot.CFrame = savedTransform
		ghostHum.CameraOffset = savedCamOffset
	end
	savedTransform = nil
end

local function bindGhostCharacter(char)
	restoreGhostPosition()
	ghostChar = char
	ghostRoot = char:WaitForChild("HumanoidRootPart")
	ghostHum = char:WaitForChild("Humanoid")
	cachedParts, cachedTime = {}, 0
	currentFade = 0
end

local function ghostRenderStep(dt)
	restoreGhostPosition()
	local target = state.invisibleEnabled and state.ghostAlpha or 0
	currentFade = currentFade + (target - currentFade) * math.min(1, 8 * dt)
	if math.abs(target - currentFade) < 0.005 then currentFade = target end
	applyLocalTransparency(currentFade)
end

local function ghostHeartbeat()
	if not state.invisibleEnabled or not ghostRoot or not ghostRoot.Parent or not ghostHum or ghostHum.Health <= 0 then return end
	if UserInputService:IsKeyDown(state.revealKey) and not UserInputService:GetFocusedTextBox() then return end

	savedTransform = ghostRoot.CFrame
	savedCamOffset = ghostHum.CameraOffset
	local fake = savedTransform * CFrame.new(0, -state.invisibleDepth, 0)
	ghostHum.CameraOffset = fake:ToObjectSpace(CFrame.new(savedTransform.Position)).Position
	ghostRoot.CFrame = fake
end

---------------------------------------------------------------- Fly
-- Superhero pose: while flying the Motor6D joints are posed by hand (no animation IDs, R6 + R15).
-- Each joint's C0 is offset, and the original C0 is given back when the pose stops.
local motors = {}          -- [joint name without spaces] = { motor = Motor6D, c0 = CFrame }
local poseActive = false

local function capturePose()
	local char, _, hum = getParts()
	if not char then return end
	motors = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") then
			local key = d.Name:gsub("%s", "")
			motors[key] = { motor = d, c0 = d.C0 }
		end
	end
	-- stop leftover animation tracks so nothing fights the pose
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do track:Stop(0.15) end
	end
	poseActive = true
end

local function restorePose()
	for _, m in pairs(motors) do
		if m.motor and m.motor.Parent then m.motor.C0 = m.c0 end
	end
	motors = {}
	poseActive = false
end

local function setJoint(name, rot)
	local m = motors[name]
	if m and m.motor.Parent then
		m.motor.C0 = CFrame.new(m.c0.Position) * rot * m.c0.Rotation
	end
end

local function lerpNum(a, b, t) return a + (b - a) * t end

-- p: 0 = relaxed hover, 1 = full Superman pose
local function applyPose(p)
	local A = CFrame.Angles
	local side = math.rad(32)
	local rArm = A(lerpNum(0, math.rad(175), p), 0, 0) * A(0, 0, lerpNum(side, 0.05, p))
	local lArm
	if state.flyTwoArms then
		lArm = A(lerpNum(0, math.rad(175), p), 0, 0) * A(0, 0, lerpNum(-side, -0.05, p))
	else
		lArm = A(lerpNum(0, -0.3, p), 0, 0) * A(0, 0, lerpNum(-side, -0.12, p))
	end
	local rLeg = A(lerpNum(0.1, -math.rad(14), p), 0, 0) * A(0, 0, lerpNum(0.12, 0.02, p))
	local lLeg = A(lerpNum(0.1, -math.rad(8), p), 0, 0) * A(0, 0, lerpNum(-0.12, -0.02, p))
	local knee = A(lerpNum(-0.15, -math.rad(25), p), 0, 0)
	local neck = A(math.rad(60) * p, 0, 0) -- head tilts up to look ahead

	setJoint("RightShoulder", rArm)
	setJoint("LeftShoulder", lArm)
	setJoint("RightHip", rLeg)
	setJoint("LeftHip", lLeg)
	setJoint("RightKnee", knee)
	setJoint("LeftKnee", knee)
	setJoint("Neck", neck)
end

local bodyGyro, bodyVelocity
local function toggleFly(on)
	state.flyEnabled = on
	local _, root, hum = getParts()

	if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
	if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
	if not on then
		restorePose()
		if hum then hum.PlatformStand = false end
		return
	end
	if not root then return end
	if hum then hum.PlatformStand = true end

	local gyro = Instance.new("BodyGyro")
	gyro.P = 9e4
	gyro.MaxTorque = Vector3.new(9e4, 9e4, 9e4)
	gyro.CFrame = root.CFrame
	gyro.Parent = root
	local vel = Instance.new("BodyVelocity")
	vel.Velocity = Vector3.new(0, 0, 0)
	vel.MaxForce = Vector3.new(9e4, 9e4, 9e4)
	vel.Parent = root
	bodyGyro, bodyVelocity = gyro, vel

	local mine = session
	task.spawn(function()
		local curVel, blend = Vector3.new(), 0
		while running and session == mine and state.flyEnabled and root.Parent and bodyVelocity == vel do
			local camera = Workspace.CurrentCamera
			local camCF = camera.CFrame
			local dir = Vector3.new()
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camCF.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camCF.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				dir = dir - Vector3.new(0, 1, 0)
			end
			local target = dir.Magnitude > 0 and dir.Unit * state.flySpeed or Vector3.new(0, 0, 0)
			vel.Velocity = target

			local dt = RunService.RenderStepped:Wait()

			if state.flyPose then
				if not poseActive then capturePose() end
				curVel = curVel:Lerp(target, 1 - math.exp(-7 * dt))
				local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
				flatLook = flatLook.Magnitude < 0.001 and Vector3.zAxis or flatLook.Unit

				local speedNow = curVel.Magnitude
				local pTarget, heading = 0, flatLook
				if speedNow > 2 then
					heading = curVel.Unit
					local facing = heading:Dot(camCF.LookVector) -- flying backwards stays upright
					pTarget = math.clamp(speedNow / (state.flySpeed * 0.75), 0, 1) * math.clamp((facing + 0.3) / 0.6, 0, 1)
				end
				blend = blend + (pTarget - blend) * (1 - math.exp(-6 * dt))

				local upright = CFrame.lookAt(Vector3.zero, flatLook)
				local hint = math.abs(heading.Y) > 0.98 and flatLook or Vector3.yAxis
				local horizontal = CFrame.lookAt(Vector3.zero, heading, hint) * CFrame.Angles(-math.pi / 2, 0, 0)
				gyro.CFrame = upright:Lerp(horizontal, blend)
				applyPose(blend)
			else
				if poseActive then restorePose() blend, curVel = 0, Vector3.new() end
				gyro.CFrame = camCF
			end
		end
		restorePose()
		if bodyVelocity == vel then
			if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
			vel:Destroy()
			bodyVelocity = nil
		end
	end)
end

---------------------------------------------------------------- Grab gun
local function grabGunAction()
	local _, root, hum = getParts()
	if not hum or hum.Health <= 0 or not root then return end
	if getMM2Role(lp) == "Murderer" then return end

	local drop
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:FindFirstChild("GunDrop") then drop = child.GunDrop break end
	end
	drop = drop or Workspace:FindFirstChild("GunDrop")
	if drop then
		local back = root.CFrame
		root.CFrame = drop.CFrame
		task.wait(0.05)
		root.CFrame = back
	end
end

---------------------------------------------------------------- Fling
local savedFlingPos
local function flingStep()
	local _, root, hum = getParts()
	if state.flingEnabled and state.selectedTarget then
		local _, tRoot = targetRoot()
		if tRoot and root then
			savedFlingPos = savedFlingPos or root.CFrame
			if hum then hum.PlatformStand = true end
			root.CFrame = tRoot.CFrame
			root.Velocity = Vector3.new(30000, 30000, 30000)
			root.RotVelocity = Vector3.new(50000, 50000, 50000)
		end
	elseif savedFlingPos then
		if root then
			root.Velocity = Vector3.new(0, 0, 0)
			root.RotVelocity = Vector3.new(0, 0, 0)
			root.CFrame = savedFlingPos
		end
		if hum then hum.PlatformStand = false end
		savedFlingPos = nil
	end
end

---------------------------------------------------------------- Kill All
local function equipKnife()
	local char = lp.Character
	local backpack = lp:FindFirstChild("Backpack")
	if not char then return end
	local knife = char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife"))
	if knife and knife.Parent == backpack then knife.Parent = char end
end

local function killAllStep()
	if not state.killAllEnabled then return end
	local _, root, hum = getParts()
	if not (root and hum and hum.Health > 0) then return end
	equipKnife()
	local knife = lp.Character and lp.Character:FindFirstChild("Knife")
	for _, player in ipairs(Players:GetPlayers()) do
		if not state.killAllEnabled then break end
		local char = player.Character
		local pHum = char and char:FindFirstChild("Humanoid")
		if player ~= lp and char and char:FindFirstChild("HumanoidRootPart") and pHum and pHum.Health > 0 then
			root.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
			if knife then pcall(function() knife:Activate() end) end
			task.wait(0.05)
		end
	end
end

---------------------------------------------------------------- Auto Farm (float + noclip, coins)
local normalGravity = Workspace.Gravity
local currentPos = Vector3.new()
local arrivedAt = nil
local visited = {}

local function getCoinPos(coin)
	if coin:IsA("BasePart") then return coin.Position end
	if coin:IsA("Model") then return coin:GetPivot().Position end
end

local function isCoinValid(coin)
	if not coin or not coin.Parent or not coin:IsDescendantOf(Workspace) then return false end
	if coin:GetAttribute("Collected") then return false end
	local visual = coin:FindFirstChild("CoinVisual")
	if not visual then return false end
	if visual:IsA("BasePart") and visual.Transparency >= 1 then return false end
	return true
end

local function touchCoin(coin, rootPart)
	if not firetouchinterest then return end
	local part = coin:IsA("BasePart") and coin or coin:FindFirstChildWhichIsA("BasePart", true)
	if part and rootPart then
		firetouchinterest(rootPart, part, 0)
		firetouchinterest(rootPart, part, 1)
	end
end

local function getNearestCoin()
	local container = Workspace:FindFirstChild("CoinContainer", true)
	if not container then return end
	local best, bestPos, bestDist
	local now = os.clock()
	for _, coin in ipairs(container:GetChildren()) do
		if visited[coin] and now - visited[coin] > 3 then visited[coin] = nil end
		if not visited[coin] and isCoinValid(coin) then
			local pos = getCoinPos(coin)
			if pos then
				local d = (pos - currentPos).Magnitude
				if not bestDist or d < bestDist then best, bestPos, bestDist = coin, pos, d end
			end
		end
	end
	return best, bestPos, bestDist
end

local function setAutoFarm(on)
	state.autoFarm = on
	arrivedAt = nil
	local _, root, hum = getParts()
	if hum then hum.PlatformStand = on end
	Workspace.Gravity = on and 0 or normalGravity
	if on and root then
		currentPos = root.Position
	elseif root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(root.Position)
	end
end

local function farmStep(dt)
	if not state.autoFarm then return end
	local _, root, hum = getParts()
	if not root or not hum or hum.Health <= 0 or getMM2Role(lp) == "Murderer" then
		if hum and hum.PlatformStand then hum.PlatformStand = false end
		return
	end

	local coin, pos = getNearestCoin()
	if coin then
		local target = pos + Vector3.new(0, state.farmOffset, 0)
		local d = (target - currentPos).Magnitude
		if d > 1 then
			arrivedAt = nil
			currentPos = currentPos + (target - currentPos).Unit * math.min(state.farmSpeed * dt, d)
		else
			currentPos = target
			touchCoin(coin, root)
			arrivedAt = arrivedAt or os.clock()
			if os.clock() - arrivedAt >= state.farmStay then
				visited[coin] = os.clock()
				arrivedAt = nil
			end
		end
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(currentPos) * CFrame.Angles(math.rad(-90), 0, 0)
end

---------------------------------------------------------------- Feature switches (used by the UI and by the keybinds)
setters.walk = function(on) state.walkSpeedActive = on applyCharacterStats() end
setters.jump = function(on) state.jumpPowerActive = on applyCharacterStats() end
setters.fly = function(on) toggleFly(on) end
setters.noclip = function(on)
	state.noclipEnabled = on
	if not on and not (state.autoFarm or state.flingEnabled or state.killAllEnabled) then restoreCollisions() end
end
setters.infjump = function(on) state.infJumpEnabled = on end

local function flipFeature(name, current)
	local on = not current
	setters[name](on)
	local ref = refs[name]
	if ref and ref.Set then ref:Set(on, true) end -- move the switch without running its callback again
end

local function onKey(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local k = input.KeyCode
	if state.keyGrabGun and k == state.keyGrabGun then task.spawn(grabGunAction)
	elseif state.keyInfJump and k == state.keyInfJump then flipFeature("infjump", state.infJumpEnabled)
	elseif state.keyFly and k == state.keyFly then flipFeature("fly", state.flyEnabled)
	elseif state.keyWalkSpeed and k == state.keyWalkSpeed then flipFeature("walk", state.walkSpeedActive)
	elseif state.keyNoclip and k == state.keyNoclip then flipFeature("noclip", state.noclipEnabled)
	elseif state.keyJumpPower and k == state.keyJumpPower then flipFeature("jump", state.jumpPowerActive)
	end
end

local function startFeatures()
	if running then return end
	running = true
	session = session + 1

	-- remember what the game had, so unloading can give it back
	local hum, cam = getHumanoid(), Workspace.CurrentCamera
	originals = {
		walkSpeed = hum and hum.WalkSpeed, jumpPower = hum and hum.JumpPower,
		jumpHeight = hum and hum.JumpHeight, fov = cam and cam.FieldOfView,
	}
	normalGravity = Workspace.Gravity
	if cam then state.fov = math.clamp(math.floor(cam.FieldOfView + 0.5), 40, 120) end

	setAntiAfk(state.antiAfkEnabled)
	connect(RunService.Heartbeat, updateEsp)
	connect(RunService.Heartbeat, ghostHeartbeat)
	connect(RunService.Stepped, noclipStep)
	connect(RunService.RenderStepped, aimbotStep)
	connect(RunService.PreSimulation, farmStep)
	pcall(function() RunService:BindToRenderStep("NexusGhostRestore", Enum.RenderPriority.First.Value, ghostRenderStep) end)
	connect(UserInputService.JumpRequest, function()
		if state.infJumpEnabled then
			local h = getHumanoid()
			if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
		end
	end)
	connect(UserInputService.InputBegan, onKey)

	if lp.Character then task.spawn(bindGhostCharacter, lp.Character) end
	connect(lp.CharacterAdded, function(char)
		task.spawn(bindGhostCharacter, char)
		if not char:WaitForChild("Humanoid", 10) then return end
		task.wait(0.2)
		if not running then return end
		walkApplied, jumpApplied = false, false
		applyCharacterStats()
		if state.flyEnabled then task.wait(0.3) toggleFly(true) end
		if state.autoFarm then setAutoFarm(true) end
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

	loop(0.5, function() if state.autoGrabGun then grabGunAction() end end)
	loop(0.03, flingStep)
	loop(0.2, killAllStep)
end

-- Disconnect everything, switch every feature off and give back the changed game values.
local function stopFeatures()
	if not running then return end
	running = false
	session = session + 1
	for _, c in ipairs(connections) do c:Disconnect() end
	connections = {}
	pcall(function() RunService:UnbindFromRenderStep("NexusGhostRestore") end)
	setAntiAfk(false)
	clearEsp()

	-- switch the features off (this also puts the character and the gravity back)
	state.invisibleEnabled = false
	restoreGhostPosition()
	applyLocalTransparency(0)
	state.flingEnabled, state.killAllEnabled, state.aimbotEnabled, state.autoGrabGun = false, false, false, false
	flingStep()
	if state.autoFarm then setAutoFarm(false) end
	if state.flyEnabled then toggleFly(false) end
	state.noclipEnabled, state.infJumpEnabled, state.espEnabled = false, false, false
	restoreCollisions()
	state.walkSpeedActive, state.jumpPowerActive = false, false
	targetDropdowns, refs = {}, {}

	local hum, cam = getHumanoid(), Workspace.CurrentCamera
	if hum then
		if walkApplied and originals.walkSpeed then hum.WalkSpeed = originals.walkSpeed end
		if jumpApplied then
			if hum.UseJumpPower == false then
				if originals.jumpHeight then hum.JumpHeight = originals.jumpHeight end
			elseif originals.jumpPower then
				hum.JumpPower = originals.jumpPower
			end
		end
	end
	walkApplied, jumpApplied = false, false
	if cam and state.fovTouched and originals.fov then cam.FieldOfView = originals.fov end
end

--==============================================================================
--  2. CATEGORIES   (one function per category; `tab` is where you add components)
--==============================================================================

-- A toggle that runs setters[name] and is remembered in refs[name] (so its key can flip it).
local function featureToggle(tab, name, label, current, flag)
	refs[name] = tab:AddToggle({ Name = label, Default = current, Flag = flag, Callback = function(on) setters[name](on) end })
end

local function targetPicker(tab, label)
	local names = getPlayerNames()
	local dd = tab:AddDropdown({
		Name = label, Options = #names > 0 and names or { "None" }, Default = state.selectedTarget or "None",
		Callback = function(name)
			for _, n in ipairs(getPlayerNames()) do
				if n == name then state.selectedTarget = name refreshTargets() return end
			end
		end,
	})
	table.insert(targetDropdowns, dd)
end

---------------------------------------------------------------- Combat
local function buildCombat(tab)
	tab:AddToggle({
		Name = tr("aimbot"), Default = state.aimbotEnabled, Flag = "aimbot_switch",
		Callback = function(on)
			state.aimbotEnabled = on
			notify(tr("tab_combat"), tr(on and "aimbot_on" or "aimbot_off"), on and "Success" or "Warning")
		end,
	})
	tab:AddSlider({
		Name = tr("aimbot_range"), Min = 50, Max = 1000, Default = state.aimbotRange, Increment = 10, Suffix = " studs", Flag = "aimbot_range",
		Callback = function(v) state.aimbotRange = v end,
	})
end

---------------------------------------------------------------- Character
local function buildCharacter(tab)
	featureToggle(tab, "walk", tr("enable_walk"), state.walkSpeedActive, "walkspeed_active")
	tab:AddSlider({
		Name = tr("walk_speed"), Min = 16, Max = 100, Default = state.walkSpeed, Increment = 1, Flag = "walk_speed",
		Callback = function(v) state.walkSpeed = v applyCharacterStats() end,
	})
	featureToggle(tab, "jump", tr("enable_jump"), state.jumpPowerActive, "jumppower_active")
	tab:AddSlider({
		Name = tr("jump_power"), Min = 50, Max = 200, Default = state.jumpPower, Increment = 1, Flag = "jump_power",
		Callback = function(v) state.jumpPower = v applyCharacterStats() end,
	})

	tab:AddToggle({
		Name = tr("invisible"), Default = state.invisibleEnabled, Flag = "invisible_toggle",
		Callback = function(on)
			state.invisibleEnabled = on
			notify(tr("invisible"), on and tr("invisible_on", state.revealKey.Name) or tr("invisible_off"), on and "Success" or "Warning")
		end,
	})
	tab:AddSlider({
		Name = tr("ghost_opacity"), Min = 0, Max = 0.9, Default = state.ghostAlpha, Increment = 0.1, Flag = "ghost_opacity",
		Callback = function(v) state.ghostAlpha = v end,
	})

	featureToggle(tab, "fly", tr("fly"), state.flyEnabled, "fly_toggle")
	tab:AddToggle({ Name = tr("fly_pose"), Default = state.flyPose, Flag = "fly_pose", Callback = function(on) state.flyPose = on end })
	tab:AddToggle({ Name = tr("fly_two_arms"), Default = state.flyTwoArms, Flag = "fly_two_arms", Callback = function(on) state.flyTwoArms = on end })
	tab:AddSlider({
		Name = tr("fly_speed"), Min = 16, Max = 200, Default = state.flySpeed, Increment = 1, Flag = "fly_speed",
		Callback = function(v) state.flySpeed = v end,
	})
	featureToggle(tab, "noclip", tr("noclip"), state.noclipEnabled, "noclip_toggle")
	featureToggle(tab, "infjump", tr("inf_jump"), state.infJumpEnabled, "infjump_toggle")
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
	tab:AddToggle({
		Name = tr("farm_toggle"), Default = state.autoFarm, Flag = "farm_toggle",
		Callback = function(on)
			setAutoFarm(on)
			notify(tr("tab_farm"), tr(on and "farm_on" or "farm_off"), on and "Success" or "Warning")
		end,
	})
	tab:AddDropdown({
		Name = tr("farm_method"), Options = { "Nearest Coin" }, Default = state.farmMethod, Flag = "farm_method",
		Callback = function(v) state.farmMethod = v end,
	})
	tab:AddSlider({
		Name = tr("farm_speed"), Min = 5, Max = 60, Default = state.farmSpeed, Increment = 1, Suffix = " studs/s", Flag = "farm_speed",
		Callback = function(v) state.farmSpeed = v end,
	})
	tab:AddSlider({
		Name = tr("farm_offset"), Min = 0, Max = 5, Default = state.farmOffset, Increment = 0.5, Suffix = " studs", Flag = "farm_offset",
		Callback = function(v) state.farmOffset = v end,
	})
	tab:AddSlider({
		Name = tr("farm_stay"), Min = 0, Max = 2, Default = state.farmStay, Increment = 0.05, Suffix = " s", Flag = "farm_stay",
		Callback = function(v) state.farmStay = v end,
	})
end

---------------------------------------------------------------- TP
local function buildTeleport(tab)
	tab:AddToggle({
		Name = tr("auto_grab"), Default = state.autoGrabGun, Flag = "auto_grab_gun",
		Callback = function(on)
			state.autoGrabGun = on
			notify(tr("auto_grab"), tr(on and "auto_grab_on" or "auto_grab_off"), on and "Success" or "Warning")
		end,
	})
	targetPicker(tab, tr("tp_target"))
	tab:AddButton({
		Name = tr("tp_button"),
		Callback = function()
			local target, tRoot = targetRoot()
			local root = getRootPart()
			if tRoot and root then
				root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 3)
				notify(tr("tp_title"), tr("tp_success", target.Name), "Success")
			else
				notify(tr("tp_title"), tr("tp_err"), "Error")
			end
		end,
	})
	tab:AddButton({
		Name = tr("tp_map"),
		Callback = function()
			local root = getRootPart()
			if root then
				root.CFrame = CFrame.new(0, 100, 0)
				notify(tr("tp_title"), tr("tp_map_done"), "Success")
			end
		end,
	})
	tab:AddButton({
		Name = tr("tp_lobby"),
		Callback = function()
			local root = getRootPart()
			if root then
				root.CFrame = CFrame.new(-108.3, 137.1, 8.5)
				notify(tr("tp_title"), tr("tp_lobby_done"), "Success")
			end
		end,
	})
end

---------------------------------------------------------------- Keys
local function buildKeys(tab)
	local function bind(label, field, flag)
		tab:AddKeybind({ Name = label, Default = state[field], Flag = flag, OnChanged = function(key) state[field] = key end })
	end
	bind(tr("key_grab"), "keyGrabGun", "key_grab_gun")
	bind(tr("key_infjump"), "keyInfJump", "key_inf_jump")
	bind(tr("key_fly"), "keyFly", "key_fly")
	bind(tr("key_walk"), "keyWalkSpeed", "key_walk_speed")
	bind(tr("key_noclip"), "keyNoclip", "key_noclip")
	bind(tr("key_jump"), "keyJumpPower", "key_jump_power")
	tab:AddKeybind({
		Name = tr("key_reveal"), Default = state.revealKey, Flag = "key_reveal",
		OnChanged = function(key) if key then state.revealKey = key end end,
	})
end

---------------------------------------------------------------- Troll
local function buildTroll(tab)
	targetPicker(tab, tr("fling_target"))
	tab:AddToggle({
		Name = tr("fling"), Default = state.flingEnabled, Flag = "fling_toggle",
		Callback = function(on)
			state.flingEnabled = on
			notify(tr("tab_troll"), on and tr("fling_on", tostring(state.selectedTarget)) or tr("fling_off"), on and "Success" or "Warning")
		end,
	})
	tab:AddToggle({
		Name = tr("kill_all"), Default = state.killAllEnabled, Flag = "kill_all_toggle",
		Callback = function(on)
			state.killAllEnabled = on
			notify(tr("kill_all"), tr(on and "kill_on" or "kill_off"), on and "Success" or "Warning")
		end,
	})
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
			local cam = Workspace.CurrentCamera
			if cam then cam.FieldOfView = v end
		end,
	})

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
	{ name = "tab_tp",        icon = "tp",        build = buildTeleport },
	{ name = "tab_keys",      icon = "keys",      build = buildKeys },
	{ name = "tab_troll",     icon = "troll",     build = buildTroll },
	{ name = "tab_visuals",   icon = "visuals",   build = buildVisuals },
	{ name = "tab_settings",  icon = "settings",  build = buildSettings },
	{ name = "tab_about",     icon = "about",     build = buildAbout },
}

--==============================================================================
--  BUILD
--==============================================================================
function Hub.Build(rebuilt)
	targetDropdowns, refs = {}, {}
	startFeatures()

	Window = Nexus:CreateWindow({
		Name = Config.Name,
		Subtitle = Config.Subtitle,
		Icon = Config.Icon, -- or "rbxassetid://<uploaded logo id>"
		Accent = ACCENTS[state.accentName],
		ToggleKey = state.toggleKey,
		Size = UDim2.fromOffset(720, 580),
		Footer = tr("footer", Nexus.Version),
		Resizable = true,
		MinSize = Vector2.new(600, 460),
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
	targetDropdowns, refs = {}, {}
	if Window then Window:Destroy() end
	rebuilding = false
	Hub.Build(true)
end

return Hub
