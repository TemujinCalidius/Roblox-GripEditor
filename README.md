# GripEditor - Visual Tool Grip Editor for Roblox Studio

A free, open-source Roblox Studio plugin for visually editing `Tool.Grip` using Studio's native Move and Rotate tools. **Works with standard R15, R6, and custom mesh avatars** (skinned meshes with bones).

Most existing grip editor plugins only work with standard Roblox rigs. GripEditor was built specifically to support **custom mesh avatars** (single-mesh characters with bone hierarchies like Mixamo rigs), which are increasingly common in modern Roblox games.

## Installation

1. In Roblox Studio: **Plugins** tab > **Plugins Folder** (opens your local plugins folder)
2. Copy `GripEditor.lua` into that folder
3. Restart Studio
4. A "**Grip Editor**" toolbar appears with an "**Edit Grip**" button

## Usage

### Playtest Mode (Recommended)

Best for custom mesh avatars — uses the live character so what you see is exactly what you get in-game.

1. Click **Play** in Studio to start a playtest
2. Equip the tool you want to edit (press a hotbar key, use a pickup prompt, etc.)
3. Click **Edit Grip** in the plugin toolbar
4. A blue neon sphere appears at the current grip position (auto-selected)
5. Press **W** to move it, **E** to rotate it — standard Studio tools
6. The tool updates **live** on the character as you drag
7. Click **"Print Grip CFrame to Output"** in the widget to get the code-ready value
8. Click **Edit Grip** again to stop and clean up

### Preview Mode

Quick iteration without playtesting. Uses your StarterCharacter in T-pose.

1. Select a **Tool** instance in Explorer (e.g., `ServerStorage/ItemTools/stone_axe`)
2. Click **Edit Grip**
3. A preview rig spawns holding the tool
4. Adjust the blue sphere with Move (W) / Rotate (E)

> **Note:** Preview mode shows the T-pose, which may not match the in-game idle animation. For custom avatars, playtest mode gives more accurate results.

## Avatar Requirements

### Standard R15

Works out of the box. No changes needed.

### Standard R6

Works out of the box. Tools attach to the "Right Arm" part.

### Custom Mesh Avatar (Single Skinned Mesh)

Your character model **must** have a separate BasePart named `RightHand`:

```
StarterCharacter (Model)
  ├── Humanoid
  ├── HumanoidRootPart (Part)
  ├── Base_Avatar (MeshPart, skinned mesh with bones)
  │   ├── mixamorig:Hips (Bone)
  │   │   └── ... (full bone hierarchy)
  │   └── mixamorig:RightHand (Bone)
  └── RightHand (MeshPart) ← REQUIRED for tools
```

**Why?** Roblox's `Humanoid:EquipTool()` creates a `RightGrip` weld between the character's `RightHand` part and the tool's `Handle` part. Without a separate `RightHand` BasePart, the tool has nowhere to attach.

**How to set it up:**

1. Add a small **MeshPart** or **Part** named `RightHand` as a direct child of your character Model
2. Position it at the character's right hand area
3. It can be small and invisible (`Transparency = 1`) — it just needs to exist
4. Connect it to your rig so it follows the hand bone during animation (via Motor6D or Weld)
5. Set `Anchored = false`, `CanCollide = false`

## Tool Requirements

Your Tool instance must have:

- A child **BasePart** (Part or MeshPart) named exactly `Handle`
- `Handle.Anchored = false`
- `Handle.CanCollide = false`
- `Tool.RequiresHandle = true`
- `Tool.CanBeDropped = false` (recommended)
- Any additional mesh parts welded to Handle via **WeldConstraint**

## Using the Output CFrame

The "Print Grip CFrame to Output" button prints a code-ready string to the Output window:

```
[GripEditor] gripCFrame = CFrame.new(0.093, -0.454, 0.078) * CFrame.Angles(math.rad(-9.6), math.rad(-171.5), math.rad(-82.6))
```

### Option 1: Set grip directly when equipping

In whatever script handles tool equipping, set `tool.Grip` before or after parenting the tool to the character:

```lua
local tool = toolTemplate:Clone()
tool.Grip = CFrame.new(0.093, -0.454, 0.078) * CFrame.Angles(math.rad(-9.6), math.rad(-171.5), math.rad(-82.6))
tool.Parent = player.Backpack
humanoid:EquipTool(tool)
```

### Option 2: Store in a config table (recommended for multiple tools)

Keep grip values in a central config so they're easy to update:

```lua
-- GripConfig.lua
return {
    stone_axe = CFrame.new(0.093, -0.454, 0.078) * CFrame.Angles(math.rad(-9.6), math.rad(-171.5), math.rad(-82.6)),
    stone_knife = CFrame.new(0.1, -0.3, 0.0) * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
    pickaxe = CFrame.new(0.0, -0.5, 0.1) * CFrame.Angles(math.rad(10), math.rad(-80), math.rad(-15)),
}
```

Then apply when equipping:

```lua
local GripConfig = require(path.to.GripConfig)

local tool = toolTemplate:Clone()
tool.Grip = GripConfig[tool.Name] or CFrame.new()
tool.Parent = player.Backpack
```

### Option 3: Set grip in the Tool's properties (no code needed)

If you don't need to set grip at runtime, you can paste the values directly into the Tool's **Grip** property in Studio's Properties panel. However, this is harder to version-control and share across tools.

## Troubleshooting

**"Could not find RightHand"**
Your avatar doesn't have a BasePart named `RightHand`. See [Avatar Requirements](#custom-mesh-avatar-single-skinned-mesh).

**Tool appears at wrong position in-game vs editor**
Use **playtest mode** instead of preview mode. The T-pose preview doesn't account for animation bone transforms.

**Blue sphere doesn't appear**
Make sure you either have a tool equipped (playtest mode) or a Tool selected in Explorer (preview mode) before clicking Edit Grip.

**Orphaned blue spheres or preview rigs**
Click Edit Grip twice (on then off) to clean up. The plugin also auto-cleans orphans on restart.

## License

MIT License — free to use, modify, and redistribute.

Created by [The Counter Earth](https://github.com/TemujinCalidius) team.
