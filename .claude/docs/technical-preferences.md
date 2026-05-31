# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript
- **Rendering**: Forward+ (2D mode) — D3D12 default on Windows in Godot 4.6
- **Physics**: Godot 2D Physics (Jolt is the new default 3D physics in 4.6; 2D physics is a separate subsystem)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam)
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Gamepad (Boss Rush 动作游戏首选)
- **Gamepad Support**: Partial
- **Touch Support**: None
- **Platform Notes**: 所有核心玩法（格挡/反击/移动）必须可通过键盘/鼠标访问；手柄是推荐输入但非必须。UI 需支持两种输入模式切换。Steam Input 集成推荐用于手柄映射。

## Naming Conventions

- **Classes**: PascalCase (e.g., `BossEnemy`, `ParrySystem`)
- **Variables**: snake_case (e.g., `move_speed`, `current_health`)
- **Functions**: snake_case (e.g., `apply_parry()`, `take_damage()`)
- **Signals/Events**: snake_case 过去式 (e.g., `health_changed`, `parry_triggered`, `boss_defeated`)
- **Files**: snake_case 匹配类名 (e.g., `boss_enemy.gd`, `parry_system.gd`)
- **Scenes/Prefabs**: PascalCase 匹配根节点 (e.g., `BossEnemy.tscn`, `MainMenu.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`, `PARRY_WINDOW_FRAMES`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: ≤ 20,000 nodes; 2D batching enabled
- **Memory Ceiling**: ≤ 512 MB RAM

## Testing

- **Framework**: GUT (Godot Unit Testing) — install via AssetLib
- **Minimum Coverage**: 80%（核心系统：格挡系统、Boss 状态机、伤害计算必须有测试）
- **Required Tests**: 格挡时机公式、Boss 阶段状态机转换、伤害/治疗数值、预警触发逻辑

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- **GUT** — Godot Unit Testing framework (testing only, install via AssetLib)
- [其他插件待架构决策时按需添加；不预先添加投机性依赖]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (所有 .gd 文件)
- **Shader Specialist**: godot-shader-specialist (.gdshader 文件, VisualShader 资源)
- **UI Specialist**: godot-specialist (无独立 UI specialist — primary 负责所有 UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / 原生 C++ 绑定，仅在需要时)
- **Routing Notes**: 调用 primary 做架构决策、ADR 验证、跨系统代码评审。调用 GDScript specialist 做代码质量、信号架构、静态类型强制执行和 GDScript 惯例。调用 shader specialist 做材质设计和着色器代码。仅在涉及原生扩展时调用 GDExtension specialist。

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
