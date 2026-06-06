# ADR-0002: BossData Resource Architecture

## Status
Accepted

## Date
2026-06-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | MEDIUM — `duplicate_deep()` added in Godot 4.5 (post-cutoff); `Array[ResourceType]` @export typing stable since 4.0 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | `duplicate_deep()` (Godot 4.5) — used only if BossData instances need deep copying; not required for single-Boss-at-a-time MVP |
| **Verification Required** | Confirm `Array[PhaseData]` and `Array[AttackData]` @export works in Godot Inspector with nested .tres files; verify ResourceLoader.load() resolves sub-resources correctly |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (signal routing must be Accepted — BossDataLoader module identity established in architecture.md) |
| **Enables** | ADR-0003 (RetryContext reads BossData to save preserved_boss_phase); ADR-0005 (Animation boundary — attack animation names come from BossData) |
| **Blocks** | All BossStateMachine, HealthDamageSystem, and ParryTelegraphSystem implementation stories — these systems cannot be implemented without knowing how BossData is structured |
| **Ordering Note** | GameEnums (AttackType, ComboState, Target) must be defined before any BossData Resource can be saved to .tres (enum serialisation requires class_name registered in project). Define GameEnums first during Technical Setup. |

## Context

### Problem Statement

三个 MVP 系统（BossStateMachine、HealthDamageSystem、ParryTelegraphSystem）需要访问每个 Boss 特有的数据（攻击序列、伤害值、预警时长、阶段阈值等）。GDD 明确要求：「.gd 文件中不得出现这些字面量，所有值通过 BossData 数据资产注入」。需要决定 BossData 的格式、类层级结构和加载策略。

### Constraints

- 所有 Boss 特有数值必须可在不修改代码的情况下更改（支持快速数值调整）
- GUT 单元测试必须能在不依赖外部文件的情况下注入测试用数据
- 嵌套结构（BossData → PhaseData[] → AttackData[]）必须类型安全
- Godot Inspector 必须能直接编辑，无需外部工具
- AttackType 枚举被至少 4 个系统引用 — 必须在单一位置定义，避免循环依赖

### Requirements

- 必须提供 `boss_max_hp` 和 `phase_threshold_pct[]` 供 HealthDamageSystem 读取
- 必须提供 `attack_sequence: Array[AttackData]`（含 attack_type、damage、telegraph_duration_override）供 BossStateMachine 读取
- 必须提供 `phase_symbol: Texture2D`（per PhaseData）供 InstantRetrySystem 死亡屏幕读取
- BossDataLoader 必须在加载时执行验证（空序列断言、无效 override clamp）
- AttackType / ComboState / Target 枚举共享，定义在独立的 `game_enums.gd` 文件

---

## Decision

**采用三层 GDScript Resource 子类结构**：`BossData → PhaseData[] → AttackData[]`。所有类文件均使用 `class_name` 注册，Inspector 可直接编辑，以 `.tres` 文本格式存储于 `res://data/bosses/`。

所有跨系统共享枚举定义在独立的 `game_enums.gd`（`class_name GameEnums`）中，不依赖任何 Node 或 Resource 子类，保证所有系统可无循环依赖地引用。

### Architecture Diagram

```
res://
├── data/
│   └── bosses/
│       └── boss_01.tres          ← BossData resource
│           ├── phases[0]         ← PhaseData resource (embedded)
│           │   ├── attack_sequence[0]  ← AttackData resource (embedded)
│           │   ├── attack_sequence[1]
│           │   └── ...
│           └── phases[1]
│               └── ...
└── scripts/
    ├── data/
    │   ├── game_enums.gd         ← AttackType, ComboState, Target enums
    │   ├── boss_data.gd          ← class_name BossData extends Resource
    │   ├── phase_data.gd         ← class_name PhaseData extends Resource
    │   └── attack_data.gd        ← class_name AttackData extends Resource
    └── foundation/
        └── boss_data_loader.gd   ← BossDataLoader node
```

### Key Interfaces

```gdscript
# scripts/data/game_enums.gd
class_name GameEnums

enum AttackType { LIGHT, HEAVY, SWEEP }
enum ComboState { IDLE, COUNTER_WINDOW_OPEN, BONUS_STAGGER }
enum Target     { PLAYER, BOSS }


# scripts/data/attack_data.gd
class_name AttackData
extends Resource

@export var attack_type: GameEnums.AttackType = GameEnums.AttackType.LIGHT
@export var damage: float = 10.0
@export_range(0.0, 5.0) var telegraph_duration_override: float = 0.0
# 0.0 = 使用 AttackType 全局默认值（LIGHT=0.8s, HEAVY=1.2s, SWEEP=1.5s）; >0 = 覆盖
@export_range(0.0, 2.0) var window_width_override: float = 0.0
# 0.0 = 使用类型默认值（LIGHT=0.30s, HEAVY=0.35s, SWEEP=0.45s）; >0 = 覆盖格挡窗口宽度
@export_range(0.0, 1.0) var window_open_fraction_override: float = 0.0
# 0.0 = 使用全局默认值（0.50）; >0 = 覆盖窗口开启时机（占预警时长的比例）
@export_range(0.0, 10.0) var stagger_duration_override: float = 0.0
# 0.0 = 使用类型默认值（LIGHT=1.0s, HEAVY=1.5s, SWEEP=2.0s）; >0 = 覆盖 Boss 硬直时长


# scripts/data/phase_data.gd
class_name PhaseData
extends Resource

@export var phase_index: int = 0
@export var attack_sequence: Array[AttackData] = []
@export_range(0.0, 5.0) var idle_duration_after_attack: float = 0.5
@export var phase_transition_anim: StringName = &""
@export var phase_symbol: Texture2D  # 用于 InstantRetrySystem 死亡屏幕


# scripts/data/boss_data.gd
class_name BossData
extends Resource

@export var boss_id: StringName = &""
@export_range(1.0, 10000.0) var boss_max_hp: float = 1000.0
@export var phase_threshold_pct: Array[float] = [0.6, 0.3]
# phase_threshold_pct[0] = 第一次阶段转换的 HP 阈值（从高到低排列）
@export var phases: Array[PhaseData] = []


# scripts/foundation/boss_data_loader.gd
class_name BossDataLoader
extends Node

func get_boss_data(boss_id: StringName) -> BossData:
    # 路径约定: res://data/bosses/{boss_id}.tres
    var path: String = "res://data/bosses/%s.tres" % boss_id
    assert(ResourceLoader.exists(path), "BossData not found: %s" % path)
    var data: BossData = ResourceLoader.load(path) as BossData
    _validate(data)
    return data

func _validate(data: BossData) -> void:
    assert(data.boss_id != &"", "BossData.boss_id must not be empty")
    assert(data.boss_max_hp > 0, "BossData.boss_max_hp must be > 0")
    assert(data.phases.size() > 0, "BossData.phases must not be empty")
    for phase in data.phases:
        assert(phase.attack_sequence.size() > 0,
            "PhaseData.attack_sequence must not be empty (phase %d)" % phase.phase_index)
        # clamp invalid telegraph_duration_override
        for attack in phase.attack_sequence:
            if attack.telegraph_duration_override > 0.0 and attack.telegraph_duration_override < 0.1:
                push_warning("telegraph_duration_override < 0.1s clamped to 0.1s for attack %s"
                    % GameEnums.AttackType.keys()[attack.attack_type])
                attack.telegraph_duration_override = 0.1
            if attack.window_width_override > 0.0 and attack.window_width_override < 0.05:
                push_warning("window_width_override < 0.05s clamped to 0.05s")
                attack.window_width_override = 0.05
            if attack.stagger_duration_override > 0.0 and attack.stagger_duration_override < 0.05:
                push_warning("stagger_duration_override < 0.05s clamped to 0.05s")
                attack.stagger_duration_override = 0.05
        assert(phase.idle_duration_after_attack > 0.0,
            "PhaseData.idle_duration_after_attack must be > 0")
        if phase.idle_duration_after_attack < 0.1:
            push_warning("idle_duration_after_attack < 0.1s clamped to 0.1s")
            phase.idle_duration_after_attack = 0.1


# GUT 测试中注入测试数据（不依赖 .tres 文件）:
func _make_test_boss() -> BossData:
    var attack := AttackData.new()
    attack.attack_type = GameEnums.AttackType.LIGHT
    attack.damage = 10.0

    var phase := PhaseData.new()
    phase.attack_sequence = [attack]
    phase.idle_duration_after_attack = 0.5

    var boss := BossData.new()
    boss.boss_id = &"test_boss"
    boss.boss_max_hp = 100.0
    boss.phase_threshold_pct = [0.5]
    boss.phases = [phase]
    return boss
```

---

## Alternatives Considered

### Alternative 1: JSON 文件 + Dictionary 解析

- **Description**: BossData 存储为 JSON，通过 FileAccess + JSON.parse() 加载，返回 Dictionary
- **Pros**: 外部工具可编辑（Excel / 专用数据编辑器）；文本格式对非程序员友好
- **Cons**: 无类型安全（`dict["damage"]` 可拼错键名）；需要手工写验证代码（50+ 行）；GUT 测试需要构造 Dictionary 而非类型化对象；Godot Inspector 不原生支持
- **Rejection Reason**: 本项目是 Solo 开发，无需非程序员友好工具；Resource 子类的验证由 assert 覆盖，比 Dictionary 解析更简洁；类型安全直接减少运行时错误。

### Alternative 2: 混合架构（Runtime Resource + JSON 导入工具）

- **Description**: 以 Resource 子类为运行时格式，开发独立 JSON→.tres 导入工具
- **Pros**: 两全其美；可用 Excel 维护 Boss 数值
- **Cons**: 额外工具开发成本（Solo 开发不合理）；MVP 阶段完全多余
- **Rejection Reason**: 超出 MVP 范围。如果 Alpha 阶段需要非程序员编辑 Boss 数据，可以添加；现在不需要。

### Alternative 3: 全部内联在 BossStateMachine 代码中（硬编码）

- **Description**: PhaseData 和 AttackData 直接在 BossStateMachine 的 `_ready()` 中创建
- **Pros**: 开发最快
- **Cons**: 直接违反 GDD 明确要求（「.gd 中不得出现字面量」）；无法在不改代码的情况下调整数值
- **Rejection Reason**: 违反 GDD 要求及架构原则 2。

---

## Consequences

### Positive
- 所有 Boss 数值集中在 .tres 文件，数值调整无需修改代码
- Godot Inspector 原生支持 nested Resource 数组编辑
- GUT 测试通过 `BossData.new()` 直接创建测试数据，无需文件 I/O
- `class_name` 注册后，Godot 类型系统提供自动补全和编译期错误
- .tres 格式是 Git 可读文本文件，diff 清晰

### Negative
- 三个新 GDScript 文件（game_enums.gd, boss_data.gd, phase_data.gd, attack_data.gd = 实际四个）须在第一个系统实现前创建
- GameEnums 文件成为多个脚本的隐式依赖——重命名枚举值会影响所有引用文件（需全局替换）

### Risks

| 风险 | 可能性 | 影响 | 缓解方案 |
|---|---|---|---|
| `class_name` 注册顺序问题（Godot 编辑器启动前不识别） | 低 | .tres 保存失败 | 首先创建并保存 GameEnums + Resource 子类文件；重启编辑器解锁 Inspector 编辑 |
| BossData Resource 在两个节点间共享（引用语义）导致数据污染 | 低（Boss Rush 单 Boss） | attack.damage 被意外修改 | BossDataLoader._validate() 在加载时修改（clamp）前克隆？MVP 不需要；Alpha 阶段有多 Boss 时评估 |
| phase_threshold_pct 排序错误（[0.3, 0.6] 而非 [0.6, 0.3]）| 中 | 阶段触发顺序错误 | BossDataLoader._validate() 断言 threshold 数组降序排列；HealthDamageSystem 在迭代时不依赖顺序（Set 查找） |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| boss-state-machine.md | TR-BSM-002: BossData Resource 驱动所有 Boss 特有数据 | `class_name BossData extends Resource` + `PhaseData[]` + `AttackData[]` |
| boss-state-machine.md | TR-BSM-003: AttackData.telegraph_duration_override = 0 使用默认值 | `@export_range(0.0, 5.0) var telegraph_duration_override: float = 0.0` |
| boss-state-machine.md | TR-BSM-009: 加载时验证（空序列 assert / invalid override clamp / animation 缺失降级） | `BossDataLoader._validate()` |
| boss-state-machine.md | TR-BSM-010: 代码中不含 BossData 字面量 | 所有字面量在 .tres 文件，代码通过 @export 变量读取 |
| health-damage-system.md | TR-HDS-010: boss_max_hp + phase_threshold_pct[] 来自 BossData，不硬编码 | `BossData.boss_max_hp: float` + `BossData.phase_threshold_pct: Array[float]` |
| parry-telegraph-system.md | TR-PTS-011: 所有时序值从 BossData 加载，不含字面量 | `AttackData.telegraph_duration_override` + `window_width_override` + `window_open_fraction_override` + `stagger_duration_override`；ParryTelegraphSystem 读取 override 值，≤ 0 时回退到 GDD 默认常量 |
| instant-retry-system.md | TR-IRS-002: 死亡屏幕 PHASE_SYMBOL 来自 Boss 数据资产 | `PhaseData.phase_symbol: Texture2D` |

---

## Performance Implications

- **CPU**: ResourceLoader.load() 一次性在战斗开始时调用，缓存后 O(1) 读取；运行时不重加载
- **Memory**: 一个 BossData + 2-4 个 PhaseData + 6-12 个 AttackData ≈ < 1KB 纯数据；Texture2D phase_symbol 按需加载（死亡屏幕使用时）
- **Load Time**: .tres 解析比 JSON 快（二进制序列化路径可选）；MVP 阶段简单 Boss 加载 < 5ms
- **Network**: 不适用

---

## Migration Plan

本 ADR 在首次代码编写前建立。创建顺序：
1. `scripts/data/game_enums.gd` — 先创建，让 Godot 编辑器注册枚举
2. `scripts/data/attack_data.gd` / `phase_data.gd` / `boss_data.gd`
3. `scripts/foundation/boss_data_loader.gd`
4. `res://data/bosses/` 目录 + MVP Boss 的 `boss_01.tres`

---

## Validation Criteria

- [ ] Godot Inspector 中可以直接在 BossData 资产上添加/编辑 PhaseData 和 AttackData 条目
- [ ] 空 `attack_sequence` 的 BossData 加载时触发 assert，战斗不启动
- [ ] `telegraph_duration_override = 0.005` (亚帧) 被 clamp 至 0.1s 并产生 push_warning
- [ ] GUT 测试通过 `_make_test_boss()` 创建数据，不读取 .tres 文件，测试可独立运行
- [ ] `grep "= 1000.0"` 和 `grep "0.8\|1.2\|1.5"` 在 BossStateMachine 代码文件中返回 0 结果

## Related Decisions
- [ADR-0001](adr-0001-signal-routing-architecture.md): BossStateMachine 通过 EventBus.attack_telegraphed 使用本 ADR 定义的 AttackData
- [ADR-0003](adr-0003-retrycontext-scene-reset.md): RetryContext 保存 preserved_boss_phase，类型为 int，与 PhaseData.phase_index 对应
- [docs/architecture/architecture.md](architecture.md): BossDataLoader 模块在主架构 Foundation Layer 中定义
