--[[
	GripEditor - Visual Tool Grip Editor for Roblox Studio
	Version 1.0.0

	A free, open-source Roblox Studio plugin for visually editing Tool.Grip
	using Studio's native Move and Rotate tools. Works with standard R15 rigs,
	R6 rigs, and custom mesh avatars (skinned meshes with bones).

	== TWO MODES ==

	1. PLAYTEST MODE (recommended for custom avatars)
	   - Start a playtest in Studio
	   - Equip the tool you want to edit (press hotbar key, etc.)
	   - Click the "Edit Grip" button in the plugin toolbar
	   - The plugin detects the equipped tool and uses the live character's hand
	   - Changes apply in real-time — what you see is what you get

	2. EDIT MODE (quick iteration, may not match in-game for custom rigs)
	   - Select a Tool instance in Explorer (e.g., ServerStorage/ItemTools/sword)
	   - Click the "Edit Grip" button
	   - A preview rig spawns (cloned from StarterCharacter or default R15)
	   - Note: preview uses T-pose which may not match animated in-game pose

	== HOW TO USE ==

	In both modes:
	- A blue neon sphere ("GripPoint") appears at the current grip position
	- The sphere is auto-selected for you
	- Press W to activate Move tool — drag to reposition the grip
	- Press E to activate Rotate tool — drag to rotate the grip
	- The Grip Editor widget shows live position and rotation values
	- Click "Print Grip CFrame to Output" to copy the code-ready CFrame string
	- Click "Edit Grip" again to stop editing and clean up

	== AVATAR REQUIREMENTS ==

	For the tool to attach to your character's hand, your avatar needs:

	Standard R15:
	  - Works out of the box. Has separate MeshParts for each body part
	    including RightHand.

	Standard R6:
	  - Works out of the box. Tools attach to "Right Arm" Part.

	Custom Mesh Avatar (single skinned mesh):
	  - Your character model MUST have a separate BasePart (Part or MeshPart)
	    named "RightHand" as a direct child of the character Model.
	  - This part should be positioned at the character's right hand area.
	  - It can be small and invisible (Transparency = 1) — it just needs to
	    exist so Roblox's Humanoid:EquipTool() can create the RightGrip weld.
	  - The main body mesh (e.g., "Base_Avatar") with bones handles the visual
	    deformation; the RightHand part handles tool attachment.
	  - The RightHand part should be connected to the rig via Motor6D or
	    welded to follow the hand bone's position.

	Example custom avatar hierarchy:
	  StarterCharacter (Model)
	    ├── Humanoid
	    ├── HumanoidRootPart (Part, anchored root)
	    ├── Base_Avatar (MeshPart, skinned mesh with bones)
	    │   ├── mixamorig:Hips (Bone)
	    │   │   └── ... (full bone hierarchy)
	    │   └── mixamorig:RightHand (Bone)
	    └── RightHand (MeshPart, small, at hand position) ← REQUIRED for tools

	== TOOL REQUIREMENTS ==

	Your Tool instance must have:
	  - A child BasePart (Part or MeshPart) named exactly "Handle"
	  - Handle.Anchored = false
	  - Handle.CanCollide = false
	  - Tool.CanBeDropped = false (recommended)
	  - Tool.RequiresHandle = true
	  - Any additional parts should be welded to Handle via WeldConstraint

	== INSTALLATION ==

	1. In Studio: Plugins tab → Plugins Folder (opens the local plugins folder)
	2. Copy this .lua file into that folder
	3. Restart Studio
	4. "Grip Editor" toolbar appears with "Edit Grip" button

	== LICENSE ==

	MIT License — free to use, modify, and redistribute.

	Created by The Counter Earth team.
	GitHub: https://github.com/TemujinCalidius/GripEditor
--]]

local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local Players = game:GetService("Players")

-- ── Plugin UI Setup ─────────────────────────────────────────────────────

local toolbar = plugin:CreateToolbar("Grip Editor")
local button = toolbar:CreateButton(
	"Edit Grip",
	"Visually edit a Tool's Grip property. Works with custom mesh avatars.",
	"rbxassetid://14978048121"
)

-- State
local active = false
local sourceTool: Tool? = nil
local gripPart: Part? = nil
local rightHand: BasePart? = nil
local updateConn: RBXScriptConnection? = nil
local previewRig: Model? = nil
local toolClone: Tool? = nil
local weld: Weld? = nil
local isPlaytestMode = false

-- ── Widget ──────────────────────────────────────────────────────────────

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, false,
	280, 240, 220, 200
)
local widget = plugin:CreateDockWidgetPluginGui("GripEditorWidget", widgetInfo)
widget.Title = "Grip Editor"

local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.Parent = widget

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 24)
titleLabel.Position = UDim2.new(0, 0, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "No tool selected"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = frame

local valuesLabel = Instance.new("TextLabel")
valuesLabel.Size = UDim2.new(1, -16, 0, 100)
valuesLabel.Position = UDim2.new(0, 8, 0, 32)
valuesLabel.BackgroundTransparency = 1
valuesLabel.Text = ""
valuesLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
valuesLabel.Font = Enum.Font.RobotoMono
valuesLabel.TextSize = 12
valuesLabel.TextXAlignment = Enum.TextXAlignment.Left
valuesLabel.TextYAlignment = Enum.TextYAlignment.Top
valuesLabel.TextWrapped = true
valuesLabel.Parent = frame

local instructLabel = Instance.new("TextLabel")
instructLabel.Size = UDim2.new(1, -8, 0, 36)
instructLabel.Position = UDim2.new(0, 4, 1, -68)
instructLabel.BackgroundTransparency = 1
instructLabel.Text = "Select blue ball, then:\nW = Move  |  E = Rotate"
instructLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
instructLabel.Font = Enum.Font.Gotham
instructLabel.TextSize = 11
instructLabel.TextWrapped = true
instructLabel.Parent = frame

local copyButton = Instance.new("TextButton")
copyButton.Size = UDim2.new(1, -16, 0, 28)
copyButton.Position = UDim2.new(0, 8, 1, -30)
copyButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
copyButton.Text = "Print Grip CFrame to Output"
copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
copyButton.Font = Enum.Font.GothamBold
copyButton.TextSize = 13
copyButton.Parent = frame
Instance.new("UICorner", copyButton).CornerRadius = UDim.new(0, 4)

-- ── Display ─────────────────────────────────────────────────────────────

local function updateDisplay()
	if not sourceTool then
		titleLabel.Text = "No tool selected"
		valuesLabel.Text = ""
		return
	end
	local mode = isPlaytestMode and " (LIVE)" or " (PREVIEW)"
	titleLabel.Text = "Editing: " .. sourceTool.Name .. mode
	local g = sourceTool.Grip
	local pos = g.Position
	local rx, ry, rz = g:ToEulerAnglesYXZ()
	valuesLabel.Text = string.format(
		"Position:\n  X: %.3f\n  Y: %.3f\n  Z: %.3f\n\nRotation (degrees):\n  Pitch: %.1f\n  Yaw: %.1f\n  Roll: %.1f",
		pos.X, pos.Y, pos.Z,
		math.deg(rx), math.deg(ry), math.deg(rz)
	)
end

copyButton.MouseButton1Click:Connect(function()
	if not sourceTool then return end
	local g = sourceTool.Grip
	local pos = g.Position
	local rx, ry, rz = g:ToEulerAnglesYXZ()
	local code = string.format(
		"CFrame.new(%.3f, %.3f, %.3f) * CFrame.Angles(math.rad(%.1f), math.rad(%.1f), math.rad(%.1f))",
		pos.X, pos.Y, pos.Z,
		math.deg(rx), math.deg(ry), math.deg(rz)
	)
	print("[GripEditor] gripCFrame = " .. code)
	copyButton.Text = "Printed! Check Output window"
	task.delay(2, function() copyButton.Text = "Print Grip CFrame to Output" end)
end)

-- ── Hand Detection ──────────────────────────────────────────────────────
-- Supports R15 (RightHand), R6 (Right Arm), and custom mesh avatars
-- with a separate RightHand part.

local function findRightHand(rig: Model): BasePart?
	-- Priority 1: direct child BasePart named RightHand (custom avatar or R15)
	for _, child in rig:GetChildren() do
		if child:IsA("BasePart") and child.Name == "RightHand" then
			return child
		end
	end
	-- Priority 2: descendant BasePart named RightHand or Right Arm (R6)
	for _, name in {"RightHand", "Right Arm"} do
		local found = rig:FindFirstChild(name, true)
		if found and found:IsA("BasePart") then return found end
	end
	-- Priority 3: bone named RightHand → parent MeshPart (single-mesh fallback)
	for _, desc in rig:GetDescendants() do
		if desc:IsA("Bone") then
			local boneName = desc.Name
			if boneName == "mixamorig:RightHand" or boneName == "RightHand"
				or boneName == "Right_Hand" or boneName == "right_hand" then
				if desc.Parent and desc.Parent:IsA("BasePart") then
					return desc.Parent
				end
			end
		end
	end
	return nil
end

-- ── Cleanup ─────────────────────────────────────────────────────────────

local function cleanup()
	if updateConn then updateConn:Disconnect() updateConn = nil end
	if gripPart and gripPart.Parent then gripPart:Destroy() end
	gripPart = nil
	if previewRig and previewRig.Parent then previewRig:Destroy() end
	previewRig = nil
	sourceTool = nil
	toolClone = nil
	rightHand = nil
	weld = nil
	isPlaytestMode = false
	updateDisplay()
end

-- Clean up orphans from previous sessions on plugin load
for _, child in workspace:GetChildren() do
	if child.Name == "GripEditor_Preview" or child.Name == "GripPoint" then
		child:Destroy()
	end
end

-- ── Tool Finders ────────────────────────────────────────────────────────

local function getSelectedTool(): Tool?
	local sel = Selection:Get()
	if #sel ~= 1 then return nil end
	local obj = sel[1]
	if obj:IsA("Tool") then return obj end
	return obj:FindFirstAncestorOfClass("Tool")
end

local function findPlaytestTool(): (Tool?, BasePart?)
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if not char then continue end
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			local hand = findRightHand(char)
			if hand then
				return tool, hand
			end
		end
	end
	return nil, nil
end

-- ── Grip Point ──────────────────────────────────────────────────────────
-- A visible, selectable sphere at the grip position. The user moves/rotates
-- it with Studio's built-in tools (W/E). A Heartbeat poll detects changes
-- and updates Tool.Grip in real-time.

local function createGripPoint(hand: BasePart, tool: Tool)
	gripPart = Instance.new("Part")
	gripPart.Name = "GripPoint"
	gripPart.Size = Vector3.new(0.6, 0.6, 0.6)
	gripPart.Shape = Enum.PartType.Ball
	gripPart.Transparency = 0.3
	gripPart.Color = Color3.fromRGB(0, 150, 255)
	gripPart.Material = Enum.Material.Neon
	gripPart.Anchored = true
	gripPart.CanCollide = false
	gripPart.Locked = false -- must be selectable
	gripPart.CFrame = hand.CFrame * tool.Grip:Inverse()
	gripPart.Parent = workspace

	local lastCF = gripPart.CFrame
	updateConn = RunService.Heartbeat:Connect(function()
		if not gripPart or not gripPart.Parent then return end
		if not rightHand or not rightHand.Parent then return end
		if not sourceTool then return end

		local currentCF = gripPart.CFrame
		if currentCF ~= lastCF then
			lastCF = currentCF
			local newGrip = (rightHand.CFrame:Inverse() * currentCF):Inverse()
			sourceTool.Grip = newGrip

			-- Update weld in edit mode
			if weld then weld.C1 = newGrip end

			-- Update equipped tool in playtest mode
			if isPlaytestMode then
				for _, player in Players:GetPlayers() do
					local char = player.Character
					if not char then continue end
					local eqTool = char:FindFirstChildOfClass("Tool")
					if eqTool and eqTool.Name == sourceTool.Name then
						eqTool.Grip = newGrip
					end
				end
			end

			updateDisplay()
		end
	end)

	-- Auto-select so user can immediately press W or E
	Selection:Set({gripPart})
end

-- ── Session Starters ────────────────────────────────────────────────────

local function startPlaytestSession(tool: Tool, hand: BasePart)
	cleanup()
	isPlaytestMode = true
	sourceTool = tool
	rightHand = hand

	-- Save grip back to the template in ServerStorage (not the equipped clone)
	local templateFolder = game.ServerStorage:FindFirstChild("ItemTools")
	local template = templateFolder and templateFolder:FindFirstChild(tool.Name)
	if template and template:IsA("Tool") then
		sourceTool = template
	end

	print("[GripEditor] PLAYTEST MODE — using live character hand: " .. hand:GetFullName())
	print("[GripEditor] Select the blue ball, press W to move / E to rotate.")
	print("[GripEditor] Changes apply live to the equipped tool!")

	createGripPoint(hand, tool)
	updateDisplay()
	widget.Enabled = true
end

local function startEditSession(tool: Tool)
	cleanup()
	isPlaytestMode = false
	sourceTool = tool

	-- Clone StarterCharacter or use a default R15 rig
	local starterChar = game.StarterPlayer:FindFirstChild("StarterCharacter")
	if starterChar then
		previewRig = starterChar:Clone()
	else
		-- Try to insert a default R15 rig
		warn("[GripEditor] No StarterCharacter found. For custom avatars, use playtest mode instead.")
		return
	end

	previewRig.Name = "GripEditor_Preview"

	-- Position in front of camera
	local camera = workspace.CurrentCamera
	if camera then
		previewRig:PivotTo(CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 12))
	end

	for _, desc in previewRig:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end
	previewRig.Parent = workspace

	rightHand = findRightHand(previewRig)
	if not rightHand then
		warn("[GripEditor] Could not find RightHand in preview rig!")
		warn("[GripEditor] Your avatar needs a BasePart named 'RightHand'. See plugin docs.")
		cleanup()
		return
	end
	print("[GripEditor] PREVIEW MODE — hand: " .. rightHand:GetFullName())
	print("[GripEditor] Note: T-pose may differ from in-game. Use playtest mode for best results.")

	-- Clone tool and weld to hand
	toolClone = tool:Clone()
	local handle = toolClone:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		warn("[GripEditor] Tool has no child BasePart named 'Handle'!")
		cleanup()
		return
	end

	for _, desc in toolClone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
		end
	end
	toolClone.Parent = previewRig

	weld = Instance.new("Weld")
	weld.Name = "RightGrip"
	weld.Part0 = rightHand
	weld.Part1 = handle
	weld.C0 = CFrame.new()
	weld.C1 = tool.Grip
	weld.Parent = rightHand

	-- Auto-cleanup if user deletes the preview rig manually
	previewRig.AncestryChanged:Connect(function()
		if previewRig and not previewRig.Parent then
			active = false
			button:SetActive(false)
			widget.Enabled = false
			cleanup()
		end
	end)

	createGripPoint(rightHand, tool)
	updateDisplay()
	widget.Enabled = true
end

-- ── Button Handler ──────────────────────────────────────────────────────

button.Click:Connect(function()
	if active then
		active = false
		button:SetActive(false)
		widget.Enabled = false
		plugin:Deactivate()
		cleanup()
		return
	end

	-- Prefer playtest mode if a tool is equipped
	local playtestTool, playtestHand = findPlaytestTool()
	if playtestTool and playtestHand then
		active = true
		button:SetActive(true)
		startPlaytestSession(playtestTool, playtestHand)
		return
	end

	-- Fall back to edit mode with selected tool
	local tool = getSelectedTool()
	if not tool then
		warn("[GripEditor] To use this plugin:")
		warn("  Option 1 (recommended): Start a playtest, equip a tool, then click Edit Grip")
		warn("  Option 2: Select a Tool instance in Explorer, then click Edit Grip")
		return
	end

	active = true
	button:SetActive(true)
	startEditSession(tool)
end)

-- ── Cleanup on Plugin Unload ────────────────────────────────────────────

plugin.Unloading:Connect(function()
	cleanup()
	widget.Enabled = false
end)
