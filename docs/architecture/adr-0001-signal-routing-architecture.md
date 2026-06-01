# ADR-0001: Signal Routing Architecture

## Status
Accepted

## Date
2026-06-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Godot's Callable-based signal API is stable since 4.0; no post-cutoff breaking changes in the signal subsystem |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — all patterns in this ADR are based on Godot 4.0 stable APIs |
| **Verification Required** | Confirm Autoload singleton is accessible as `EventBus` in GUT test context; verify mock injection works with GUT's scene runner |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (BossData), ADR-0003 (RetryContext), ADR-0004 (Player State Machine), ADR-0005 (Animation Boundary) — all four depend on the signal routing pattern established here |
| **Blocks** | All MVP system implementation — no system can be built until its signal interfaces are established |
| **Ordering Note** | This is the first architectural decision. All other Foundation, Core, and Feature ADRs assume the EventBus pattern defined here. |

## Context

### Problem Statement

刃响的 7 个 MVP 系统之间有 20+ 条跨模块信号路径，其中包括 1 对多路径（`player_died` 有 4 个订阅者；`boss_defeated` 有 5 个订阅者）以及每物理帧触发的实时流数据信号（`telegraph_updated`、`counter_window_updated`）。需要决定一种统一的信号路由策略，使所有系统能够解耦通信，同时保持可测试性（GUT 单元测试）和可维护性。

### Constraints

- **GUT 可测试性**：每个系统必须可以在隔离的 GUT 测试中运行，不依赖完整场景树
- **Godot 4.6**：必须使用 Godot 4.0+ 的 Callable 信号 API（不使用已废弃的 `connect("signal_name", obj, "method")`）
- **性能**：每帧最多 2 条流数据信号（`telegraph_updated`、`counter_window_updated`），不能成为性能瓶颈
- **可读性**：开发者必须能通过阅读单一文件了解所有跨模块信号接口

### Requirements

- 必须支持 1 对多信号广播（`player_died` → 4 个订阅者）
- 每个系统可以独立订阅/取消订阅，不需要知道其他订阅者的存在
- 信号接口必须类型安全（使用 Godot 4 typed signal）
- 单元测试必须能够注入 mock EventBus，不依赖全局 Autoload

---

## Decision

**采用 EventBus Autoload 模式**：所有跨模块信号统一定义在 `autoloads/event_bus.gd` 这个 Godot Autoload 节点上。各系统通过 `EventBus.signal_name.emit()` 发出信号，通过 `EventBus.signal_name.connect(callable)` 订阅信号。

### Architecture Diagram

```
[BossStateMachine]
        │ EventBus.attack_telegraphed.emit(HEAVY, 25)
        ▼
[EventBus Autoload]  ← 所有信号的注册中心
        │
        ├─→ [ParryTelegraphSystem]._on_attack_telegraphed()
        │
[ParryTelegraphSystem]
        │ EventBus.parry_succeeded.emit(HEAVY)
        ▼
[EventBus Autoload]
        ├─→ [CounterAttackComboSystem]._on_parry_succeeded()
        └─→ [BossStateMachine]._on_parry_succeeded()

[HealthDamageSystem]
        │ EventBus.player_died.emit()
        ▼
[EventBus Autoload]
        ├─→ [InstantRetrySystem]._on_player_died()
        ├─→ [PlayerController]._on_player_died()
        ├─→ [ParryTelegraphSystem]._on_player_died()
        └─→ [CounterAttackComboSystem]._on_player_died()
```

### Key Interfaces

```gdscript
# autoloads/event_bus.gd
# Project Settings → Autoload → 名称: "EventBus"

extends Node

# ─── 战斗预警生命周期 ───────────────────────────────────────────────
signal attack_telegraphed(attack_type: AttackType, damage: float)
signal parry_succeeded(attack_type: AttackType)
signal parry_failed(attack_type: AttackType)
signal stagger_ended()
signal counter_full_combo_completed(attack_type: AttackType)

# ─── 玩家状态 ───────────────────────────────────────────────────────
signal player_died()
signal player_hp_changed(current: float, max_hp: float)

# ─── Boss 状态 ──────────────────────────────────────────────────────
signal boss_defeated()
signal boss_phase_changed(from_phase: int, to_phase: int)
signal boss_hp_changed(current: float, max_hp: float, phase: int)

# ─── 每帧流数据 (emitted every _physics_process) ────────────────────
signal telegraph_updated(progress: float, window_open: bool, attack_type: AttackType)
signal counter_window_updated(hit_count: int, time_remaining: float, state: ComboState)

# ─── 重试系统 ───────────────────────────────────────────────────────
signal retry_death_count_changed(count: int)

# ─── 控制器内部 (PlayerController → dependents) ─────────────────────
# 注: parry_input_pressed / attack_input_pressed / exit_parry_state 是
# PlayerController 与 Feature 系统之间的直连信号 (1:1)，
# 经由 PlayerController 节点本身发出，不经过 EventBus。
# 理由: 这些信号的消费者是已知的单一系统，不需要广播语义。
# 详见 Alternative 3 段落。
```

### Testability Pattern (GUT)

```gdscript
# 生产代码: 系统接受可选注入，回退到全局 Autoload
class_name HealthDamageSystem extends Node

var _event_bus: EventBus  # injected in tests

func initialize(event_bus: EventBus = null) -> void:
    _event_bus = event_bus if event_bus else EventBus

func _apply_damage_internal(amount: float) -> void:
    # ...
    if _current_player_hp <= 0:
        _event_bus.player_died.emit()

# 测试代码 (GUT):
class_name TestHealthDamageSystem extends GutTest

var _health_sys: HealthDamageSystem
var _mock_bus: MockEventBus  # double/stub

func before_each() -> void:
    _mock_bus = MockEventBus.new()
    _health_sys = HealthDamageSystem.new()
    _health_sys.initialize(_mock_bus)
    add_child(_health_sys)

func test_player_died_emitted_when_hp_zero() -> void:
    _health_sys.apply_damage(Target.PLAYER, 100.0)
    assert_signal_emitted(_mock_bus, "player_died")
```

### Exception: Direct Controller Signals (1:1)

`PlayerController` 通过自身节点发出以下 1:1 控制信号（不经过 EventBus）：
- `parry_input_pressed` → ParryTelegraphSystem（单一消费者）
- `attack_input_pressed` → CounterAttackComboSystem（单一消费者）
- `dodge_input_pressed(direction)` → DodgeSystem（单一消费者，VS 阶段）
- `exit_parry_state(duration)` → PlayerController 自身接收（来自 ParryTelegraphSystem）

这些信号使用 Godot 标准信号连接，在 GameRoot._ready() 中建立。这与"1:1 用直连、1:N 用 EventBus"的实用原则一致。

---

## Alternatives Considered

### Alternative 1: Direct Node Connections (GameRoot 注入)

- **Description**: GameRoot._ready() 持有所有系统引用，手动连接所有信号对
- **Pros**: 连接关系在编辑器可见；无全局状态；符合 Godot 场景树哲学
- **Cons**: GameRoot._ready() 成为包含 20+ 条连接的"上帝方法"；新增系统每次都要修改 GameRoot；单元测试需要模拟完整场景树
- **Rejection Reason**: 可测试性差——在 GUT 单元测试中隔离 HealthDamageSystem 需要实例化 PlayerController、InstantRetrySystem 等多个系统节点。本游戏的 GDD 全部有 GUT 测试要求，这一成本不可接受。

### Alternative 2: Hybrid (1:1 直连 + 1:N EventBus)

- **Description**: 1:1 信号（如 exit_parry_state）直连；1:N 信号（如 player_died）经 EventBus
- **Pros**: 1:1 信号仍在编辑器可见；EventBus 不包含不必要的单发信号
- **Cons**: 两套规则——开发者需要判断"哪个信号用哪种模式"；规则边界模糊（player_died 现在有 4 个订阅者，以后可能变成 2 个）；测试策略不统一
- **Rejection Reason**: 复杂度成本超过收益。本游戏规模小（7 个 MVP 系统），两套路由规则带来的认知开销超过"完整 EventBus"的开销。**已采纳的折中点**：PlayerController 的控制信号（1:1）仍使用直连，其他所有信号经 EventBus——这是本 ADR 决策的实际形态。

### Alternative 3: Godot Signal Bus via Scene Root Export

- **Description**: 每个系统通过 @export var 接收父节点引用，通过父节点信号通信
- **Pros**: 完全遵循 Godot 场景树模式
- **Cons**: 深嵌套信号路径不清晰；与 Autoload 测试策略相比无优势
- **Rejection Reason**: 与 Alternative 1 同样的可测试性问题。

---

## Consequences

### Positive
- 各系统完全解耦——HealthDamageSystem 不需要知道 InstantRetrySystem 存在
- 单元测试通过 `initialize(mock_bus)` 注入即可隔离任意系统
- 所有跨模块信号接口集中在 `event_bus.gd` 一处，便于审查和文档生成
- 新增系统订阅无需修改现有代码

### Negative
- EventBus 是一个全局状态点——误用（如在错误时机 emit）影响所有订阅者
- 信号连接关系不在 Godot 编辑器的连接视图中可见（需查阅代码）
- 调试时信号发出顺序不如直连直观

### Risks

| 风险 | 可能性 | 影响 | 缓解方案 |
|---|---|---|---|
| 测试中忘记调用 `initialize(mock_bus)` | 中 | 测试意外连接到真实 EventBus | GUT setUp fixture 模板强制要求；/test-helpers 工具生成标准 fixture |
| 每帧 EventBus 信号（telegraph_updated）性能影响 | 低 | 轻微 CPU 开销 | Godot typed signal 最优化；60fps 下单帧<0.01ms（Profiler 验证） |
| event_bus.gd 信号数量膨胀 | 低 | 文件变大，难以浏览 | 按域分组（战斗/玩家/Boss/HUD）+注释分隔；Alpha 阶段若超过 40 条信号考虑分拆 |
| 信号名称与 GDD 不同步 | 中 | 开发者实现错误接口 | /consistency-check 在实现阶段扫描信号名称；本 ADR 作为权威命名来源 |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| health-damage-system.md | TR-HDS-004: player_died 无缓冲同帧发出 | `EventBus.player_died.emit()` 在同帧调用，Godot 信号调用是同步的 |
| health-damage-system.md | TR-HDS-005: boss_phase_changed(from, to) | `signal boss_phase_changed(from_phase: int, to_phase: int)` 定义 |
| health-damage-system.md | TR-HDS-013: player_hp_changed + boss_hp_changed | 两条信号均在 event_bus.gd 定义 |
| parry-telegraph-system.md | TR-PTS-001: 消费 attack_telegraphed(type, damage) | `EventBus.attack_telegraphed.connect(_on_attack_telegraphed)` |
| parry-telegraph-system.md | TR-PTS-005/007: parry_succeeded/failed | `EventBus.parry_succeeded.connect(...)` from Counter + BossStateMachine |
| parry-telegraph-system.md | TR-PTS-009: telegraph_updated 每物理帧广播 | `signal telegraph_updated(progress, window_open, attack_type)` — 每帧 emit |
| counter-attack-combo.md | TR-CAC-007: stagger_ended 唯一发出方是本系统 | EventBus.stagger_ended 仅由 CounterAttackComboSystem 调用 .emit()，其他系统只能 .connect() |
| counter-attack-combo.md | TR-CAC-008: counter_window_updated 每物理帧 | `signal counter_window_updated(hit_count, time_remaining, state)` |
| instant-retry-system.md | TR-IRS-001: 订阅 player_died | `EventBus.player_died.connect(_on_player_died)` in _ready() |
| hud-system.md | TR-HUD-007: HUD 不发出任何信号 | HUDSystem 仅调用 EventBus.*.connect()，不调用 .emit() |
| player-controller-system.md | TR-PC-006: attack_input_pressed 信号 | **直连例外**：PlayerController 节点本身定义此信号；CounterAttackComboSystem 直连 |

---

## Performance Implications

- **CPU**: 正常信号调用 <0.01ms/帧；每帧两条流数据信号（telegraph + counter_window）在 144Hz 下约 0.2ms/s 总计 —— 可以接受
- **Memory**: EventBus 节点持有信号连接列表；7 个 MVP 系统约 20 条连接，内存占用可以忽略
- **Load Time**: Autoload 在项目启动时加载，单次 <1ms
- **Network**: 不适用（单机游戏）

---

## Migration Plan

本 ADR 在项目首次代码编写前建立。无需迁移——所有系统从零开始按此模式实现。

---

## Validation Criteria

- [ ] `autoloads/event_bus.gd` 包含所有 GDD 信号（17 条），无遗漏、无重复
- [ ] 每个 MVP 系统的 GUT 单元测试通过 `initialize(mock_bus)` 注入，不依赖全局 Autoload
- [ ] `EventBus.player_died.emit()` 后，同帧 InstantRetrySystem、PlayerController、ParryTelegraphSystem、CounterAttackComboSystem 全部收到信号（集成测试验证）
- [ ] Godot Profiler 显示 `telegraph_updated` 每帧调用开销 < 0.1ms（60fps 目标机器测量）
- [ ] grep `connect("` 和 `emit("` 在 .gd 文件中返回 0 条结果（确认未使用已废弃的字符串信号 API）

## Related Decisions
- [ADR-0002](adr-0002-bossdata-resource-architecture.md): BossData 资产结构决策参考本 ADR 的信号发出接口
- [ADR-0003](adr-0003-retrycontext-scene-reset.md): RetryContext 的 player_died 消费依赖本 ADR
- [docs/architecture/architecture.md](architecture.md): 主架构文档第"Module Ownership"节引用本 ADR 决策
