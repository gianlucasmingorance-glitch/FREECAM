--[[ FreeCam v2 - PC / Móvil / Gamepad ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local env = (getgenv and getgenv()) or _G
if env.__FreeCam then pcall(env.__FreeCam) end

-- ============ CONFIG ============
local TOGGLE_KEY = Enum.KeyCode.P
local speed = 50
local MIN_SPEED, MAX_SPEED = 1, 2000
local MOUSE_SENS = 0.25
local TOUCH_SENS = 0.35
local PRESETS = {10, 25, 50, 100, 250, 500}
-- ================================

local enabled = false
local yaw, pitch = 0, 0
local pos = Vector3.new()
local joyVec = Vector2.new()
local joyTouch, lookTouch
local vertUp, vertDown = false, false
local rmbHeld = false
local saved = {}
local conns = {}

local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(conns, c)
	return c
end

-- ============ GUI ============
local gui = Instance.new("ScreenGui")
gui.Name = "FreeCamGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = lp:WaitForChild("PlayerGui")

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
end

local function makeButton(text, size, position, parent)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	b.BackgroundTransparency = 0.1
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Text = text
	b.BorderSizePixel = 0
	corner(b, 8)
	b.Parent = parent
	return b
end

-- Minihub
local hub = Instance.new("Frame")
hub.Name = "Hub"
hub.Size = UDim2.fromOffset(210, 190)
hub.Position = UDim2.new(0, 20, 0.5, -95)
hub.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
hub.BackgroundTransparency = 0.05
hub.BorderSizePixel = 0
corner(hub, 12)
hub.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundColor3 = Color3.fromRGB(60, 90, 200)
title.BorderSizePixel = 0
title.Text = "FreeCam (arrastra aquí)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
corner(title, 12)
title.Parent = hub

local toggleBtn = makeButton("FreeCam: OFF", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 34), hub)
toggleBtn.TextScaled = false
toggleBtn.TextSize = 16

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.fromOffset(70, 28)
speedLabel.Position = UDim2.fromOffset(8, 70)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Velocidad:"
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 14
speedLabel.Parent = hub

local minusBtn = makeButton("-", UDim2.fromOffset(28, 28), UDim2.fromOffset(80, 70), hub)
local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.fromOffset(50, 28)
speedBox.Position = UDim2.fromOffset(112, 70)
speedBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
speedBox.BorderSizePixel = 0
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.Font = Enum.Font.GothamBold
speedBox.TextSize = 14
speedBox.Text = tostring(speed)
speedBox.ClearTextOnFocus = false
corner(speedBox, 6)
speedBox.Parent = hub
local plusBtn = makeButton("+", UDim2.fromOffset(28, 28), UDim2.fromOffset(168, 70), hub)

-- Presets
for i, v in ipairs(PRESETS) do
	local col = (i - 1) % 3
	local row = math.floor((i - 1) / 3)
	local b = makeButton(tostring(v), UDim2.fromOffset(60, 28), UDim2.fromOffset(8 + col * 66, 106 + row * 34), hub)
	b.TextScaled = false
	b.TextSize = 14
	connect(b.MouseButton1Click, function()
		speed = v
		speedBox.Text = tostring(speed)
	end)
end

-- Controles móviles
local mobileFrame = Instance.new("Frame")
mobileFrame.BackgroundTransparency = 1
mobileFrame.Size = UDim2.fromScale(1, 1)
mobileFrame.Visible = false
mobileFrame.Parent = gui

local joyBase = Instance.new("Frame")
joyBase.Size = UDim2.fromOffset(140, 140)
joyBase.Position = UDim2.new(0, 40, 1, -180)
joyBase.BackgroundColor3 = Color3.new(1, 1, 1)
joyBase.BackgroundTransparency = 0.7
corner(joyBase, 70)
joyBase.Parent = mobileFrame

local joyKnob = Instance.new("Frame")
joyKnob.Size = UDim2.fromOffset(60, 60)
joyKnob.AnchorPoint = Vector2.new(0.5, 0.5)
joyKnob.Position = UDim2.fromScale(0.5, 0.5)
joyKnob.BackgroundColor3 = Color3.new(1, 1, 1)
joyKnob.BackgroundTransparency = 0.3
corner(joyKnob, 30)
joyKnob.Parent = joyBase

local upBtn = makeButton("▲", UDim2.fromOffset(60, 60), UDim2.new(1, -90, 1, -260), mobileFrame)
local downBtn = makeButton("▼", UDim2.fromOffset(60, 60), UDim2.new(1, -90, 1, -190), mobileFrame)

-- ============ Lógica ============
local function setSpeed(v)
	speed = math.clamp(v, MIN_SPEED, MAX_SPEED)
	speedBox.Text = tostring(math.floor(speed * 10 + 0.5) / 10)
end

local function sink()
	return Enum.ContextActionResult.Sink
end

local function setChar(frozen)
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		pcall(function() hrp.Anchored = frozen end)
	end
end

local function step(dt)
	local typing = UIS:GetFocusedTextBox() ~= nil
	local x, y, z = 0, 0, 0

	if not typing then
		if UIS:IsKeyDown(Enum.KeyCode.W) then z += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.S) then z -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.D) then x += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.A) then x -= 1 end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then y += 1 end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then y -= 1 end
	end
	if vertUp then y += 1 end
	if vertDown then y -= 1 end

	x += joyVec.X
	z -= joyVec.Y

	-- Mouse (click derecho mantenido)
	if rmbHeld then
		local d = UIS:GetMouseDelta()
		yaw -= math.rad(d.X * MOUSE_SENS)
		pitch = math.clamp(pitch - math.rad(d.Y * MOUSE_SENS), -math.rad(89), math.rad(89))
	end

	-- Gamepad
	if #UIS:GetConnectedGamepads() > 0 then
		for _, st in ipairs(UIS:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			local k, p = st.KeyCode, st.Position
			if k == Enum.KeyCode.Thumbstick1 then
				if Vector2.new(p.X, p.Y).Magnitude > 0.15 then x += p.X; z += p.Y end
			elseif k == Enum.KeyCode.Thumbstick2 then
				if Vector2.new(p.X, p.Y).Magnitude > 0.15 then
					yaw -= p.X * 2.5 * dt
					pitch = math.clamp(pitch + p.Y * 2.5 * dt, -math.rad(89), math.rad(89))
				end
			elseif k == Enum.KeyCode.ButtonR2 then
				y += p.Z
			elseif k == Enum.KeyCode.ButtonL2 then
				y -= p.Z
			end
		end
	end

	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local dir = rot.RightVector * x + rot.LookVector * z + Vector3.new(0, y, 0)
	if dir.Magnitude > 1 then dir = dir.Unit end
	pos = pos + dir * speed * dt

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.new(pos) * rot
end

local function setEnabled(state)
	if state == enabled then return end
	enabled = state
	toggleBtn.Text = state and "FreeCam: ON" or "FreeCam: OFF"
	toggleBtn.BackgroundColor3 = state and Color3.fromRGB(40, 150, 60) or Color3.fromRGB(40, 40, 40)
	mobileFrame.Visible = state and UIS.TouchEnabled

	if state then
		cam = workspace.CurrentCamera
		saved.type = cam.CameraType
		saved.fov = cam.FieldOfView

		local rx, ry = cam.CFrame:ToOrientation()
		pitch, yaw = rx, ry
		pos = cam.CFrame.Position

		setChar(true)
		CAS:BindActionAtPriority("FreeCamSink", sink, false, 9000,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
			Enum.KeyCode.Space, Enum.KeyCode.LeftShift,
			Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
			Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA)

		RunService:BindToRenderStep("FreeCamStep", Enum.RenderPriority.Camera.Value + 1, step)
	else
		pcall(function() RunService:UnbindFromRenderStep("FreeCamStep") end)
		pcall(function() CAS:UnbindAction("FreeCamSink") end)
		setChar(false)
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		cam.CameraType = saved.type or Enum.CameraType.Custom
		cam.FieldOfView = saved.fov or 70
		joyVec, joyTouch, lookTouch = Vector2.new(), nil, nil
		vertUp, vertDown, rmbHeld = false, false, false
		joyKnob.Position = UDim2.fromScale(0.5, 0.5)
	end
end

-- ============ Input ============
connect(toggleBtn.MouseButton1Click, function() setEnabled(not enabled) end)
connect(plusBtn.MouseButton1Click, function() setSpeed(speed * 1.25) end)
connect(minusBtn.MouseButton1Click, function() setSpeed(speed * 0.8) end)
connect(speedBox.FocusLost, function()
	local n = tonumber(speedBox.Text)
	if n then setSpeed(n) else setSpeed(speed) end
end)

-- Arrastrar el hub
do
	local dragging, dragStart, startPos
	connect(title.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = i.Position
			startPos = hub.Position
			local c
			c = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					c:Disconnect()
				end
			end)
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			hub.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

connect(UIS.InputBegan, function(input, gp)
	if input.KeyCode == TOGGLE_KEY and not UIS:GetFocusedTextBox() then
		setEnabled(not enabled)
		return
	end
	if not enabled then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbHeld = true
		UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif input.UserInputType == Enum.UserInputType.Touch and not gp then
		if not lookTouch and input.Position.X > cam.ViewportSize.X * 0.4 then
			lookTouch = input
		end
	end
end)

connect(UIS.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbHeld = false
		if enabled then UIS.MouseBehavior = Enum.MouseBehavior.Default end
	end
	if input == lookTouch then lookTouch = nil end
	if input == joyTouch then
		joyTouch, joyVec = nil, Vector2.new()
		joyKnob.Position = UDim2.fromScale(0.5, 0.5)
	end
end)

connect(UIS.InputChanged, function(input)
	if not enabled then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		setSpeed(speed * (input.Position.Z > 0 and 1.2 or 0.83))
	elseif input == lookTouch then
		yaw -= math.rad(input.Delta.X * TOUCH_SENS)
		pitch = math.clamp(pitch - math.rad(input.Delta.Y * TOUCH_SENS), -math.rad(89), math.rad(89))
	elseif input == joyTouch then
		local center = joyBase.AbsolutePosition + joyBase.AbsoluteSize / 2
		local off = (Vector2.new(input.Position.X, input.Position.Y) - center) / (joyBase.AbsoluteSize.X / 2)
		if off.Magnitude > 1 then off = off.Unit end
		joyVec = off
		joyKnob.Position = UDim2.fromScale(0.5 + off.X * 0.4, 0.5 + off.Y * 0.4)
	end
end)

connect(joyBase.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.Touch and not joyTouch then
		joyTouch = input
	end
end)

local function hold(btn, setter)
	connect(btn.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(true) end
	end)
	connect(btn.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then setter(false) end
	end)
end
hold(upBtn, function(v) vertUp = v end)
hold(downBtn, function(v) vertDown = v end)

-- ============ Limpieza ============
env.__FreeCam = function()
	setEnabled(false)
	for _, c in ipairs(conns) do c:Disconnect() end
	gui:Destroy()
	env.__FreeCam = nil
end

setEnabled(true) -- arranca activada
print("[FreeCam] cargado. P = activar/desactivar")
