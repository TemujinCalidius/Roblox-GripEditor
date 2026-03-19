# Changelog

## [1.0.0] - 2026-03-19

### Added
- **Playtest mode** — edit grip on a live character during playtest for pixel-perfect accuracy with custom mesh avatars
- **Preview mode** — edit grip on a T-pose StarterCharacter clone without playtesting
- **Blue GripPoint sphere** — selectable Part that works with Studio's native Move (W) and Rotate (E) tools
- **Live updates** — grip changes apply in real-time to equipped tools during playtest
- **Widget panel** — shows current position and rotation values
- **CFrame output** — prints code-ready `CFrame.new(...) * CFrame.Angles(...)` string to Output
- **Auto-cleanup** — orphaned preview rigs and grip points cleaned up on plugin load
- **Custom avatar support** — detects RightHand as direct child BasePart, descendant BasePart, or bone parent MeshPart
- **R15 and R6 support** — finds RightHand (R15) or Right Arm (R6) automatically
