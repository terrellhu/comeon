# ADR-0003: RetryContext and Scene Reset Strategy

## Status
Accepted

## Date
2026-06-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — SceneTree.paused, Node.process_mode, and Autoload singleton patterns are stable since Godot 4.0; no post-cutoff breaking changes in these APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `Input.is_action_just_pressed()` returns correct values during `SceneTree.paused = true` with `process_mode = PROCESS_MODE_ALWAYS`; measure in-place reset wall-clock time on target hardware to confirm < 100ms |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — player_died must be routable before retry system can subscribe); ADR-0002 (BossData — preserved_boss_phase corresponds to PhaseData.phase_index) |
| **Enables** | None — no subsequent ADR depends on this decision specifically |
| **Blocks** | InstantRetrySystem implementation story — cannot implement without knowing RetryContext structure and reset pattern |
| **Ordering Note** | RetryContext Autoload must be registered in Godot Project Settings before HealthDamageSystem can use it at _ready(). Create and register Autoload early in Technical Setup. |

## Context

### Problem Statement

玩家死亡后，即时重试系统需要在 1.5 秒死亡屏幕窗口内完成以下工作：（1）暂停游戏逻辑时间，（2）保存跨重试需要持久化的 Boss 数据，（3）重置所有系统至初始状态（但恢复 Boss HP 和阶段），（4）恢复游戏运行。有两个核心决策点：RetryContext 放在哪里（Autoload vs 场景参数），以及如何在 1.5s 内可靠地重置场景（in-place reset vs 场景重载）。

### Constraints

- 1.5s 总时长为 Art Bible Section 7.5 硬约束；场景重置必须在此窗口内完成
- RetryContext 必须在场景切换/重置后仍然存在
- 玩家死亡时 Boss HP 和当前阶段必须保存，重试时恢复（GDD 明确设计决策）
- InstantRetrySystem 的动画（死亡屏幕）必须在 SceneTree.paused = true 期间继续运行
- 跳过逻辑（任意键立即跳至重试）必须在暂停期间可检测

### Requirements

- 必须在场景重置后可读取 preserved_boss_hp, preserved_boss_phase, session_death_count
- 必须支持 Boss 被击败后的「新战斗」路径（清除 preserved_boss_hp）
- 所有系统提供 `reset_for_retry(ctx)` 接口以支持 in-place reset
- InstantRetrySystem 的 `process_mode` 必须为 `PROCESS_MODE_ALWAYS`
- 其他所有游戏系统默认 `PROCESS_MODE_PAUSEABLE`（暂停时自动停止）

---

## Decision

**两个决策：**

1. **RetryContext**: Godot Autoload 单例（`class_name RetryContextNode extends Node`）
2. **场景重置**: In-place reset — InstantRetrySystem 按依赖顺序调用各系统的 `reset_for_retry(context)` 方法，无场景重载

死亡屏幕序列期间：
- 游戏逻辑在 RED_FLASH（0ms）时立即暂停（`SceneTree.paused = true`）
- RetryContext 在 RED_FLASH 阶段（0–200ms）保存数据
- In-place reset 在 FADE_TO_GREY 阶段（200–600ms）执行
- 重置完成后等待 PHASE_SYMBOL + SYMBOL_FADE_OUT 播放完毕
- 1500ms 到达（或玩家跳过）：`SceneTree.paused = false`，游戏恢复

### Architecture Diagram

```
player_died signal
        │
        ▼
InstantRetrySystem._on_player_died()
        │
        ├─1. SceneTree.paused = true  ←── 游戏逻辑时间冻结
        │   (Boss animation stops, physics stops)
        │
        ├─2. RetryContext.save_context(boss_hp, boss_phase, death_count + 1)
        │   (saved during RED_FLASH phase, 0–200ms)
        │
        ├─3. _execute_retry_reset()  ←── in FADE_TO_GREY, 200–600ms
        │   └─ calls each system's reset_for_retry(ctx) in order:
        │       HealthDamageSystem → PlayerController → BossStateMachine
        │       → ParryTelegraphSystem → CounterAttackComboSystem → HUDSystem
        │
        ├─4. Play PHASE_SYMBOL + SYMBOL_FADE_OUT (600–1500ms)
        │   (AnimationPlayer on PROCESS_MODE_ALWAYS continues)
        │   (Input polling for skip: Input.is_anything_pressed())
        │
        └─5. 1500ms (or skip): SceneTree.paused = false
            EventBus.retry_death_count_changed.emit(count)
```

### Key Interfaces

```gdscript
# autoloads/retry_context.gd — registered as Autoload "RetryContext"
class_name RetryContextNode
extends Node

var preserved_boss_hp: float = -1.0      # -1 = fresh start (no saved context)
var preserved_boss_phase: int = 0
var session_death_count: int = 0

func save_context(boss_hp: float, boss_phase: int, death_count: int) -> void:
    preserved_boss_hp = boss_hp
    preserved_boss_phase = boss_phase
    session_death_count = death_count

func load_context() -> Dictionary:
    return {
        "boss_hp": preserved_boss_hp,
        "boss_phase": preserved_boss_phase,
        "death_count": session_death_count
    }

func clear_context() -> void:        # called when boss_defeated
    preserved_boss_hp = -1.0
    preserved_boss_phase = 0
    # session_death_count is NOT cleared — accumulates across boss fights in session

func is_fresh_start() -> bool:
    return preserved_boss_hp < 0.0


# ─── reset_for_retry contract (each system implements) ─────────────────────

# HealthDamageSystem:
func reset_for_retry(ctx: Dictionary) -> void:
    current_player_hp = player_max_hp           # full restore
    current_boss_hp = ctx["boss_hp"]             # preserved value
    invuln_timer = 0.0                           # clear leftover invuln
    # entered_phases: keep as-is — phase transitions up to preserved_boss_phase
    # already occurred; no need to re-trigger them on this retry

# PlayerController:
func reset_for_retry(ctx: Dictionary) -> void:
    player_state = PlayerState.IDLE
    velocity = Vector2.ZERO
    position = spawn_position          # @export var spawn_position: Vector2
    facing_direction = 1
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
    # invuln not set here — InstantRetrySystem sets it via separate signal
    # after SceneTree.paused = false (retry_invuln_timer = RETRY_INVULN_BASE)

# BossStateMachine:
func reset_for_retry(ctx: Dictionary) -> void:
    behavior_state = BehaviorState.IDLE
    sequence_index = 0
    idle_timer = 0.0
    internal_telegraph_timer = 0.0
    phase_index = ctx["boss_phase"]              # restore to preserved phase

# ParryTelegraphSystem:
func reset_for_retry(_ctx: Dictionary) -> void:
    system_state = ParryState.IDLE
    telegraph_timer = 0.0

# CounterAttackComboSystem:
func reset_for_retry(_ctx: Dictionary) -> void:
    combo_state = ComboState.IDLE
    hit_count = 0
    window_timer = 0.0
    hit_cooldown_timer = 0.0
    hit_cooldown_active = false

# HUDSystem:
func reset_for_retry(_ctx: Dictionary) -> void:
    # Re-render initial state (player HP full, boss HP = preserved)
    # HUD will update via signals once game resumes and systems emit initial state
    pass


# ─── InstantRetrySystem death screen flow ──────────────────────────────────

class_name InstantRetrySystem
extends Node

# process_mode must be PROCESS_MODE_ALWAYS in scene tree
# to continue running during SceneTree.paused

@export var health_system: HealthDamageSystem
@export var player_controller: PlayerController
@export var boss_state_machine: BossStateMachine
@export var parry_system: ParryTelegraphSystem
@export var counter_system: CounterAttackComboSystem
@export var hud_system: HUDSystem
@export var death_screen_anim: AnimationPlayer  # also PROCESS_MODE_ALWAYS

func _on_player_died() -> void:
    get_tree().paused = true
    _save_retry_context()
    death_screen_anim.play("death_screen_full")  # RED_FLASH → FADE_TO_GREY → PHASE_SYMBOL → SYMBOL_FADE_OUT

func _on_animation_frame_fade_to_grey_start() -> void:
    # Called via AnimationPlayer callback at 0.2s into animation
    _execute_retry_reset()

func _execute_retry_reset() -> void:
    var ctx: Dictionary = RetryContext.load_context()
    health_system.reset_for_retry(ctx)
    player_controller.reset_for_retry(ctx)
    boss_state_machine.reset_for_retry(ctx)
    parry_system.reset_for_retry(ctx)
    counter_system.reset_for_retry(ctx)
    hud_system.reset_for_retry(ctx)

func _save_retry_context() -> void:
    RetryContext.save_context(
        health_system.current_boss_hp,
        health_system.get_current_phase(),
        RetryContext.session_death_count + 1
    )

func _on_death_screen_animation_finished() -> void:
    # Also triggered early if player presses any key during animation
    _resume_game()

func _resume_game() -> void:
    get_tree().paused = false
    EventBus.retry_death_count_changed.emit(RetryContext.session_death_count)
    # PlayerController handles retry_invuln_duration via a separate timer
    # that starts in _physics_process after paused = false

func _unhandled_input(event: InputEvent) -> void:
    if get_tree().paused and death_screen_anim.is_playing():
        if event.is_pressed() and not event.is_echo():
            death_screen_anim.stop()
            _resume_game()
```

---

## Alternatives Considered

### Alternative 1: Scene Reload (`get_tree().reload_current_scene()`)

- **Description**: Save RetryContext to Autoload, call `reload_current_scene()`, each system reads RetryContext in its `_ready()` on reload.
- **Pros**: Guaranteed clean state — no risk of forgotten reset variables; simpler per-system code (no `reset_for_retry()` method needed)
- **Cons**: Load time unpredictable — depends on asset sizes. MVP placeholder art may be fast (<200ms), but Alpha/Full with HD Boss assets could easily exceed 1.5s. Once resource streaming is enabled, reload time scales with asset complexity.
- **Rejection Reason**: 1.5s budget is a hard constraint from Art Bible. In-place reset is O(variable count) ≈ 50ms regardless of asset volume. Reload is O(asset size) and grows unboundedly. Risk-adjusted: in-place reset is the safer choice for full production.

### Alternative 2: Scene Parameter Passing (no Autoload)

- **Description**: Before any scene transition, attach RetryContext as a metadata or `get_tree().set_meta()` dictionary. Each system reads from scene metadata in `_ready()`.
- **Pros**: No global state (Autoload); pure dependency injection
- **Cons**: `get_tree().set_meta()` is less type-safe than an Autoload class; requires all systems to know the metadata key string; harder to discover and test; doesn't survive `get_tree().reload_current_scene()` unless explicitly handled
- **Rejection Reason**: Autoload provides equivalent survival-across-changes semantics with better type safety via `class_name RetryContextNode`. The global-state concern for an Autoload whose sole purpose is transient cross-reset data is not significant in a single-player solo game.

### Alternative 3: Each System Self-Resets on `player_died`

- **Description**: Each system subscribes to `player_died` via EventBus and resets itself; no coordinator.
- **Pros**: Fully decoupled; no InstantRetrySystem coordination dependency
- **Cons**: Reset order is undefined (signal callbacks fire in connection order); HealthDamageSystem needs to reset HP before HUDSystem reads it; timing collisions likely. Also, the in-place reset needs RetryContext data — systems would need to read RetryContext directly, making their `_ready()` and reset() logic entangled with retry semantics.
- **Rejection Reason**: Ordered reset is a hard requirement (HealthDamageSystem must reset before BossStateMachine reads HP from it). Centralised coordination by InstantRetrySystem is the correct pattern.

---

## Consequences

### Positive
- In-place reset completes in < 100ms — always within 1.5s budget regardless of asset count
- Deterministic reset order (Foundation → Core → Feature) prevents intermediate state inconsistencies
- RetryContext Autoload survives any internal state change; accessible from any system without wiring
- Per-system `reset_for_retry()` is explicit documentation of what each system owns on a retry boundary

### Negative
- Each system must implement `reset_for_retry()` correctly — forgetting to reset a state variable is a latent bug
- InstantRetrySystem holds references to all game systems (hard-wired dependency) — cannot add new resettable systems without modifying InstantRetrySystem
- `SceneTree.paused = true` stops all `_process()`/`_physics_process()` — any system that must update during the death screen (e.g., a particle effect) must set `process_mode = PROCESS_MODE_ALWAYS` explicitly

### Risks

| 風險 | 可能性 | 影響 | 缓解方案 |
|---|---|---|---|
| 某系统 reset_for_retry() 遗漏某个状态变量 | 中 | 重试后出现幽灵状态（如 hit_cooldown_active 残留） | GUT 集成测试: 触发 player_died → 验证每个系统所有状态变量; /regression-suite 覆盖 |
| SceneTree.paused 后 delta 积累导致物理跳帧 | 低 | 重试后第一帧物理行为异常 | CharacterBody2D 在 PAUSEABLE 模式下 delta 不积累 (Godot 已处理); 验证重启后第一帧 delta 值 |
| Input.is_anything_pressed() 在暂停期间误触发 | — | — | 已解决（S002-I01）：改用 `_unhandled_input(event)` + `event.is_pressed() and not event.is_echo()`，仅响应新按键事件，天然过滤持续按住的残留输入，无需 200ms 延迟 |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| instant-retry-system.md | TR-IRS-003: 游戏逻辑时间在死亡屏幕期间暂停 | `SceneTree.paused = true` on player_died; game systems use default PROCESS_MODE_PAUSEABLE |
| instant-retry-system.md | TR-IRS-004: 任意按键跳过死亡屏幕（任意帧，含 RED_FLASH） | `_unhandled_input(event)` with PROCESS_MODE_ALWAYS; detects `event.is_pressed() and not event.is_echo()` — 仅响应新按键，不响应持续按住；任意帧生效，无 200ms 延迟 |
| instant-retry-system.md | TR-IRS-005: RetryContext 保存三项数据 | `RetryContextNode.save_context(boss_hp, boss_phase, death_count)` |
| instant-retry-system.md | TR-IRS-006: 场景重置必须在 1.5s 内完成 | In-place reset < 100ms; no asset I/O during reset |
| instant-retry-system.md | TR-IRS-007: 重试后玩家满 HP、2.0s 无敌 | `health_system.reset_for_retry()` restores player_max_hp; invuln timer started on resume |
| instant-retry-system.md | TR-IRS-008: 重试后 Boss HP = preserved_boss_hp | `health_system.reset_for_retry()` reads ctx["boss_hp"]; no round-trip to BossData |
| instant-retry-system.md | TR-IRS-009: 重试后 Boss 状态机 → IDLE | `boss_state_machine.reset_for_retry()` sets behavior_state = IDLE, sequence_index = 0 |
| instant-retry-system.md | TR-IRS-010: boss_defeated → 清除 preserved_boss_hp | `RetryContext.clear_context()` called on boss_defeated |
| instant-retry-system.md | TR-IRS-011: session_death_count++ + retry_death_count_changed signal | count incremented in save_context(); signal emitted on resume via EventBus |
| instant-retry-system.md | TR-IRS-013: 同帧 boss_defeated > player_died | Handled by subscribing to both signals; if boss_defeated fires first, skip player_died handling |

---

## Performance Implications

- **CPU**: in-place reset O(state variable count) ≈ 50ms worst case; well within 400ms FADE_TO_GREY window
- **Memory**: RetryContext Autoload ≈ 24 bytes (3 primitives); negligible
- **Load Time**: Zero — no asset I/O during in-place reset
- **Network**: 不适用

---

## Migration Plan

本 ADR 在首次代码编写前建立。创建顺序：
1. 创建并注册 `autoloads/retry_context.gd` Autoload（Project Settings → Autoload）
2. 为每个 MVP 系统添加 `reset_for_retry(ctx: Dictionary)` 方法（可与系统实现同步进行）
3. InstantRetrySystem 在最后实现（依赖所有其他系统的 reset 接口）

---

## Validation Criteria

- [ ] GUT 集成测试：触发 `EventBus.player_died.emit()` → 验证 1.5s 后 `SceneTree.paused == false`，player HP = 100，boss HP = preserved 值
- [ ] 性能测试：`_execute_retry_reset()` wall-clock 时间 < 100ms（Godot 性能监视器测量）
- [ ] 跳过测试：在 RED_FLASH 期间（0ms 后即可）发送新按键事件（is_pressed=true, is_echo=false）→ 游戏恢复，不等待 1.5s；持续按住的按键（is_echo=true）不触发跳过
- [ ] 阶段保留测试：Boss 进入 Phase 2 → 玩家死亡 → 重试 → Boss 仍在 Phase 2（不重新触发 phase_changed 信号）
- [ ] Boss 击败测试：boss_defeated 信号发出 → RetryContext.preserved_boss_hp 清除为 -1.0 → 下次战斗 Boss 从满血开始

## Related Decisions
- [ADR-0001](adr-0001-signal-routing-architecture.md): player_died signal routed via EventBus to InstantRetrySystem
- [ADR-0002](adr-0002-bossdata-resource-architecture.md): preserved_boss_phase (int) corresponds to PhaseData.phase_index
- [docs/architecture/architecture.md](architecture.md): RetryContext Autoload in Foundation Layer, InstantRetrySystem in Feature Layer
