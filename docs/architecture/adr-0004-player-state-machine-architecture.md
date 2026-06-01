# ADR-0004: Player State Machine Architecture

## Status
Accepted

## Date
2026-06-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Physics / Input |
| **Knowledge Risk** | LOW — CharacterBody2D.move_and_slide(), Input.is_action_just_pressed(), is_on_floor() are all stable since Godot 4.0; 2D physics unchanged in 4.4/4.5/4.6 (Jolt only affects 3D) |
| **References Consulted** | `docs/engine-reference/godot/modules/physics.md`, `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Confirm `Input.is_action_just_pressed()` returns true only once per press even in `_physics_process` at 60fps; confirm coyote time and jump buffer timers behave correctly with fixed physics tick |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — PlayerController emits signals via EventBus and direct node); ADR-0003 (RetryContext — DEAD state exits only via retry system reset signal) |
| **Enables** | ADR-0005 (Animation Boundary — PlayerController's state transitions trigger AnimationPlayer calls per this ADR's _enter_state pattern) |
| **Blocks** | PlayerController implementation story; all Feature-layer systems that consume PlayerController signals (ParryTelegraphSystem, CounterAttackComboSystem) |
| **Ordering Note** | GameEnums must include `PlayerState` enum (defined in ADR-0002's game_enums.gd) before PlayerController can be implemented. |

## Context

### Problem Statement

PlayerController の 7 状態ステートマシン（IDLE / RUNNING / AIRBORNE / PARRYING / DODGING / HIT_STUN / DEAD）には複数の設計決定が必要：(1) 実装パターン（enum vs クラス階層 vs AnimationTree）、(2) 優先度ルールの実装箇所（parry > dodge 同フレーム、DEAD が全ての入力を無効化）、(3) 状態遷移のシグナル発出タイミング、(4) CharacterBody2D の velocity 管理責任境界。

### Constraints

- GDScript が言語（C# / GDExtension ではない）
- GUT で各状態ロジックを単体テスト可能にする
- parry > dodge 同フレーム優先ルールは GDD 明確要件（TR-PC-004）
- DEAD 状態は外部信号（RetrySystem の reset）のみで退出できる（TR-PC-010）
- 全パラメータは @export — コードに数値リテラルなし（TR-PC-011）
- `_physics_process` 内で完結（60fps 固定物理ティック）

### Requirements

- 7 状態の完全ステートマシン（IDLE / RUNNING / AIRBORNE / PARRYING / DODGING / HIT_STUN / DEAD）
- 入力優先順位: `DEAD` ガード → `parry` → `dodge` → `jump` → `move`
- 状態遷移時のシグナル発出（parry_input_pressed、attack_input_pressed 等）
- Coyote Time（0.10s）と Jump Buffer（0.12s）計時
- `reset_for_retry()` インタフェース（ADR-0003 契約）

---

## Decision

**Enum-based state machine with a central `_transition_to()` dispatcher.**

状態を `PlayerState` enum 値で表現し、`_transition_to(new_state)` が `_exit_state(old)` + 代入 + `_enter_state(new)` を担保する。入力優先度は `_handle_input()` の早期リターン構造で解決する。`_process_state(delta)` が現在状態の毎フレームロジックを処理し、`move_and_slide()` は常に最後に呼ばれる。

### Architecture Diagram

```
_physics_process(delta)
│
├─① _handle_input()          ← 入力優先度解決 (早期リターン)
│     DEAD? → return
│     parry (can_parry?)  → _transition_to(PARRYING); return
│     dodge (can_dodge?)  → _transition_to(DODGING); return
│     jump  (can_jump?)   → _transition_to(AIRBORNE); velocity.y = -jump_impulse
│     attack (can_attack?) → emit attack_input_pressed; no state change
│     move                → velocity.x = dir × move_speed
│
├─② _process_state(delta)    ← 現在状態の毎フレームロジック
│     IDLE:      velocity.x = 0 if no move input
│     RUNNING:   apply velocity.x
│     AIRBORNE:  velocity.y += gravity × delta; clamp to terminal_velocity
│                is_on_floor() → _transition_to(IDLE or RUNNING)
│     PARRYING:  velocity.x = 0; parry_exit_timer countdown
│     HIT_STUN:  velocity.x = knockback; hit_stun_timer countdown
│     DODGING:   position controlled by DodgeSystem (controller pauses physics)
│     DEAD:      velocity = Vector2.ZERO; no input
│
└─③ move_and_slide()         ← 常に最後
```

### Key Interfaces

```gdscript
# scripts/core/player_controller.gd
class_name PlayerController
extends CharacterBody2D

# ─── State enum (defined in GameEnums — ADR-0002) ─────────────────────────
# GameEnums.PlayerState: IDLE, RUNNING, AIRBORNE, PARRYING, DODGING, HIT_STUN, DEAD

# ─── Exported parameters (no literals in logic) ────────────────────────────
@export var move_speed: float = 340.0
@export var gravity: float = 1400.0
@export var terminal_velocity: float = 1200.0
@export var jump_impulse: float = 600.0
@export var coyote_time_duration: float = 0.10
@export var jump_buffer_duration: float = 0.12
@export var knockback_speed: float = 200.0
@export var hit_stun_duration: float = 0.30
@export var parry_exit_duration: float = 0.40  # set by exit_parry_state signal

# ─── State ────────────────────────────────────────────────────────────────
var player_state: GameEnums.PlayerState = GameEnums.PlayerState.IDLE
var facing_direction: int = 1             # 1 = right, -1 = left
var spawn_position: Vector2               # set in _ready() from initial position

# ─── Internal timers ──────────────────────────────────────────────────────
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var hit_stun_timer: float = 0.0
var parry_exit_timer: float = 0.0

# ─── Signals (1:1 direct connect — not via EventBus, per ADR-0001 exception) ─
signal parry_input_pressed
signal attack_input_pressed
signal dodge_input_pressed(direction: int)

# ─── Transition guard functions ───────────────────────────────────────────

func _can_parry() -> bool:
    return player_state in [
        GameEnums.PlayerState.IDLE,
        GameEnums.PlayerState.RUNNING,
        GameEnums.PlayerState.AIRBORNE
    ]

func _can_dodge() -> bool:
    return player_state in [
        GameEnums.PlayerState.IDLE,
        GameEnums.PlayerState.RUNNING
    ]

func _can_jump() -> bool:
    return is_on_floor() or coyote_timer > 0.0

func _can_attack() -> bool:
    return player_state in [
        GameEnums.PlayerState.IDLE,
        GameEnums.PlayerState.RUNNING,
        GameEnums.PlayerState.AIRBORNE
    ]

# ─── Central transition dispatcher ────────────────────────────────────────

func _transition_to(new_state: GameEnums.PlayerState) -> void:
    _exit_state(player_state)
    player_state = new_state
    _enter_state(new_state)

func _enter_state(state: GameEnums.PlayerState) -> void:
    match state:
        GameEnums.PlayerState.PARRYING:
            velocity.x = 0.0
            parry_input_pressed.emit()      # direct signal to ParryTelegraphSystem
        GameEnums.PlayerState.HIT_STUN:
            hit_stun_timer = hit_stun_duration
            velocity.x = -facing_direction * knockback_speed
        GameEnums.PlayerState.DEAD:
            velocity = Vector2.ZERO
        GameEnums.PlayerState.DODGING:
            dodge_input_pressed.emit(facing_direction)  # direct signal to DodgeSystem

func _exit_state(state: GameEnums.PlayerState) -> void:
    match state:
        GameEnums.PlayerState.HIT_STUN:
            hit_stun_timer = 0.0
        GameEnums.PlayerState.PARRYING:
            parry_exit_timer = 0.0

# ─── Input handler (priority-ordered early returns) ───────────────────────

func _handle_input() -> void:
    if player_state == GameEnums.PlayerState.DEAD:
        return

    # Priority 1: parry (IDLE / RUNNING / AIRBORNE allowed)
    if Input.is_action_just_pressed(&"parry") and _can_parry():
        _transition_to(GameEnums.PlayerState.PARRYING)
        return

    # Priority 2: dodge (IDLE / RUNNING only)
    if Input.is_action_just_pressed(&"dodge") and _can_dodge():
        _transition_to(GameEnums.PlayerState.DODGING)
        return

    # Priority 3: jump
    if Input.is_action_just_pressed(&"jump"):
        jump_buffer_timer = jump_buffer_duration  # start buffer regardless

    # Priority 4: attack (IDLE / RUNNING / AIRBORNE; no state change)
    if Input.is_action_just_pressed(&"attack") and _can_attack():
        attack_input_pressed.emit()  # direct signal to CounterAttackComboSystem
        # no state change — attack is a forwarded impulse, not a state

    # Priority 5: horizontal movement (affects velocity, not state directly)
    var move_dir: int = int(Input.get_axis(&"move_left", &"move_right"))
    if move_dir != 0:
        facing_direction = move_dir
    if player_state not in [GameEnums.PlayerState.PARRYING, GameEnums.PlayerState.DODGING,
                             GameEnums.PlayerState.HIT_STUN]:
        velocity.x = move_dir * move_speed

# ─── ADR-0003 reset contract ──────────────────────────────────────────────

func reset_for_retry(ctx: Dictionary) -> void:
    player_state = GameEnums.PlayerState.IDLE
    velocity = Vector2.ZERO
    position = spawn_position
    facing_direction = 1
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
    hit_stun_timer = 0.0
    parry_exit_timer = 0.0
    # retry_invuln handled separately by InstantRetrySystem post-resume
```

---

## Alternatives Considered

### Alternative 1: State クラス階層 (Gang of Four State パターン)

- **Description**: 各状態を `PlayerStateBase` を継承した独立クラス（IdleState.gd, RunningState.gd 等）に分離。Controller が現在の State オブジェクトに処理を委譲。
- **Pros**: 各状態が独立ファイル → 大規模プロジェクトで保守性高い; 状態ごとの責務が明確
- **Cons**: 7 状態 × 7 ファイル; GUT テストでそれぞれのファイルを個別インスタンス化する必要; 状態間の遷移ロジック（parry > dodge 優先）が複数ファイルに散らばる; コード量が 3〜4 倍増加
- **Rejection Reason**: 7 状態に対してオーバーエンジニアリング。Enum-based の方が GUT テストの可読性・保守性ともに高い。状態数が 15+ になったら再検討する価値がある。

### Alternative 2: Godot AnimationTree + StateMachine ノード

- **Description**: AnimationTree の StateMachine ノードを状態機制御に使用。遷移条件をパラメータで設定。
- **Pros**: エディタ可視化; アニメーションと状態を統合管理
- **Cons**: AnimationTree は**アニメーション管理のためのツール**、ゲームロジック状態機のためのものではない; コード外でロジックを管理することで GUT テスト困難; `parry > dodge` 同フレーム優先などのロジックをパラメータで表現できない
- **Rejection Reason**: アニメーション駆動ではなくロジック駆動の状態機 — AnimationTree は不適切なツール。

---

## Consequences

### Positive
- 全状態とその遷移が 1 ファイルで読める → 新メンバーのオンボーディングが速い
- `_transition_to()` が唯一の状態変更点 → デバッグ時のブレークポイント設置が容易
- GUT テスト: 状態遷移を `_transition_to(PlayerState.X)` で直接起動でき、入力シミュレーション不要
- `_can_parry()` 等のガード関数が単体でテスト可能

### Negative
- 状態数が増えると match ブランチが長くなる（現在 7 状態 → 許容範囲）
- `_handle_input()` が複数の入力を処理するため、テスト時に「同フレームで parry + dodge 両押し」等のエッジケースを手動で構築する必要がある

### Risks

| 風险 | 可能性 | 影響 | 缓解方案 |
|---|---|---|---|
| 遷移漏れ（ある状態から特定のトリガーで遷移できるはずが漏れている）| 中 | 入力が無視される | GUT で全 7 状態 × 全入力の遷移マトリックスをテスト |
| DEAD 状態から外部リセットなしに抜け出せる経路が残る | 低 | 重試後の不整合 | `_handle_input()` の先頭の DEAD ガードが唯一の入力出口; DEAD 退出は `reset_for_retry()` のみ経由 |
| coyote_timer / jump_buffer_timer の物理フレーム境界での挙動 | 低 | 微妙な操作感バグ | `_physics_process` 内でのみ decrement; GUT 時間ステップシミュレーションで検証 |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| player-controller-system.md | TR-PC-002: 7 状態ステートマシン | `GameEnums.PlayerState` enum 7 値 + `_transition_to()` |
| player-controller-system.md | TR-PC-003: InputMap 動作 6 種 | `_handle_input()` が StringName 経由で検出; @export param (no literals) |
| player-controller-system.md | TR-PC-004: parry 優先ルール（同フレーム parry+dodge → parry wins） | `_handle_input()` の早期リターン — parry チェックが dodge より先 |
| player-controller-system.md | TR-PC-005: Coyote Time + Jump Buffer | `coyote_timer` / `jump_buffer_timer` float タイマー; `_can_jump()` がチェック |
| player-controller-system.md | TR-PC-006: attack_input_pressed 信号転送（IDLE/RUNNING/AIRBORNE のみ） | `_can_attack()` ガード + `attack_input_pressed.emit()` (状態変更なし) |
| player-controller-system.md | TR-PC-007: parry_input_pressed + exit_parry_state(duration) 双方向 | `_enter_state(PARRYING)` で `parry_input_pressed.emit()`; exit_parry_state は外部信号で受信後 `parry_exit_timer` 設定 |
| player-controller-system.md | TR-PC-009: HIT_STUN 状態 + knockback velocity | `_enter_state(HIT_STUN)`: `velocity.x = -facing_direction × knockback_speed`; timer からの自動退出 |
| player-controller-system.md | TR-PC-010: DEAD 状態 — 外部リセットのみで退出 | `_handle_input()` 先頭 DEAD ガード; 退出は `reset_for_retry()` のみ |
| player-controller-system.md | TR-PC-011: 全パラメータ @export | 全 float パラメータを `@export var` 宣言; コードに 340, 1400 等のリテラルなし |

---

## Performance Implications

- **CPU**: `_handle_input()` + `_process_state()` + `move_and_slide()` = O(1) per frame; 60fps で < 0.5ms 目標（GDD AC 要件）
- **Memory**: enum + float タイマー数本 + Vector2 = < 100 bytes
- **Load Time**: 影響なし
- **Network**: 不適用

---

## Migration Plan

首次代码编写前建立。创建顺序：
1. `GameEnums` に `PlayerState` を追加（game_enums.gd — ADR-0002）
2. `PlayerController.gd` を上記パターンで実装
3. GUT テストで全遷移マトリックスをカバー

---

## Validation Criteria

- [ ] GUT: `_handle_input()` に parry + dodge 同フレーム入力 → PARRYING に遷移（dodge 無視）
- [ ] GUT: DEAD 状態中に全入力 → velocity = Vector2.ZERO のまま、状態変化なし
- [ ] GUT: PARRYING 中に jump / dodge / move → 全て無視
- [ ] GUT: `_can_parry()` は IDLE/RUNNING/AIRBORNE に対して true, DODGING/HIT_STUN/DEAD に false
- [ ] GUT: `_can_attack()` は PARRYING/HIT_STUN/DEAD に false
- [ ] パフォーマンス: Godot Profiler で `_physics_process` 全体 < 0.5ms / frame
- [ ] コード審査: `.gd` ファイルに `340`, `1400`, `600`, `0.10`, `0.12`, `200`, `0.30` のリテラルなし（全て @export）

## Related Decisions
- [ADR-0001](adr-0001-signal-routing-architecture.md): parry_input_pressed / attack_input_pressed は 1:1 直結シグナル例外（EventBus を使わない）
- [ADR-0003](adr-0003-retrycontext-scene-reset.md): DEAD 退出は `reset_for_retry(ctx)` のみ
- [ADR-0005](adr-0005-animation-to-code-boundary.md): `_enter_state()` 内の `anim_player.play(anim_name)` 呼び出し規則を ADR-0005 で定義
- [design/gdd/player-controller-system.md](../../design/gdd/player-controller-system.md)
