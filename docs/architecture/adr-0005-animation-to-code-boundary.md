# ADR-0005: Animation to Code Boundary

## Status
Accepted

## Date
2026-06-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Animation |
| **Knowledge Risk** | LOW — AnimationPlayer.animation_finished signal and CONNECT_ONE_SHOT are stable since Godot 4.0; AnimationMixer base class changes are in training data (4.3) |
| **References Consulted** | `docs/engine-reference/godot/modules/animation.md`, `docs/engine-reference/godot/deprecated-apis.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | (1) Confirm `Engine.time_scale = 0.0` correctly freezes AnimationPlayer delta while `SceneTree.create_timer(d, true, false, true)` still counts down in real time. (2) Confirm `animation_finished` is NOT emitted by `AnimationPlayer.stop()` — validate the CONNECT_ONE_SHOT + _exit_state disconnect pattern works correctly when boss_defeated interrupts ATTACKING. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (PlayerController state machine — _enter_state / _exit_state hooks are where animation triggers live) |
| **Enables** | None — final Required ADR |
| **Blocks** | BossStateMachine implementation story; hitpause feel stories (health-damage, parry-telegraph, counter-attack) |
| **Ordering Note** | `HitpauseManager` Autoload must be registered before any combat system is implemented. Animation constant files must be created before BossStateMachine is implemented. |

## Context

### Problem Statement

3つの実装判断が未決定：(1) Boss ATTACKING→IDLE 遷移の「動画終了」検知方法（`animation_finished` vs 別 Timer）、(2) hitpause（受击冻帧）の実装方法（`Engine.time_scale` vs `SceneTree.paused` vs per-system カウンタ）、(3) アニメーション名の参照規則（StringName 定数 vs 文字列リテラル）。これらの決定なしに BossStateMachine、PlayerController の実装は始められない。

### Constraints

- `AnimationPlayer.playback_active` は 4.3 以降 deprecated → `AnimationPlayer.active` を使用
- Hitpause は死亡屏幕（SceneTree.paused）と同時に発生しない（戦闘中のみ）が、実装が衝突してはならない
- `Engine.time_scale = 0` 中に死亡屏幕が始まる場合はありえないが（hitpause 60–80ms 中に player_died は原理上ありうる）、その場合の順序を定義する
- GUT 単元测试で hitpause 機能をテスト可能にする（`Engine.time_scale` を mock/override できる設計）

### Requirements

- Boss ATTACKING→IDLE は動画長さによって自動決定される（Timer との手動同期を禁止）
- Hitpause は動画と物理をともに凍结する（視覚・触覚フィードバックの核心）
- Boss が `boss_defeated` で ATTACKED 中断された場合、animation_finished の残留コールバックがあってはならない
- アニメーション名が文字列リテラルとして散在することを禁止する

---

## Decision

**3つの決定：**

1. **Boss ATTACKING→IDLE**: `animation_finished` を `CONNECT_ONE_SHOT` で接続し、`_exit_state(ATTACKING)` で明示的に disconnect（`await` より割り込み安全）
2. **Hitpause**: `Engine.time_scale = 0.0` + `SceneTree.create_timer(duration, true, false, true)` で実時間タイマー。`HitpauseManager` Autoload として実装
3. **アニメーション名**: 各スクリプトまたは専用定数ファイルの先頭に `const ANIM_XXX: StringName = &"anim_name"` で定義。`anim_player.play("attack")` のような文字列リテラルの直接使用を禁止

### Architecture Diagram

```
ATTACKING→IDLE フロー:

_enter_state(ATTACKING)
    │ anim_player.play(ANIM_ATTACK_LIGHT)
    │ anim_player.animation_finished.connect(
    │     _on_attack_anim_done, CONNECT_ONE_SHOT
    │ )
    ▼
[animation plays for N seconds]
    │
    ├─ 正常終了 → _on_attack_anim_done() fires
    │     sequence_index++; _transition_to(IDLE)
    │
    └─ 中断(boss_defeated) → _transition_to(DEFEATED)
          └─ _exit_state(ATTACKING)
                └─ disconnect _on_attack_anim_done (if connected)
                     [callback NEVER fires]


Hitpause フロー:

HealthDamageSystem (玩家受击): HitpauseManager.trigger_hitpause(0.060)
ParryTelegraphSystem (格挡成功): HitpauseManager.trigger_hitpause(0.060)
CounterAttackComboSystem (第3击): HitpauseManager.trigger_hitpause(0.080)
CounterAttackComboSystem (全连击): HitpauseManager.trigger_hitpause(0.030)
    │
    ▼
HitpauseManager.trigger_hitpause(duration):
    Engine.time_scale = 0.0   ← 全ての delta → 0 (物理/動画凍結)
    real_timer = create_timer(duration, true, false, true)  ← 実時間計時
    await real_timer.timeout
    Engine.time_scale = 1.0   ← 再開
```

### Key Interfaces

```gdscript
# ─── Animation naming convention ──────────────────────────────────────────
# 各スクリプトの先頭に定義（または scripts/data/anim_names.gd に集約）

# boss_state_machine.gd
const ANIM_IDLE: StringName           = &"idle"
const ANIM_ATTACK_LIGHT: StringName   = &"attack_light"
const ANIM_ATTACK_HEAVY: StringName   = &"attack_heavy"
const ANIM_ATTACK_SWEEP: StringName   = &"attack_sweep"
const ANIM_STAGGERED: StringName      = &"staggered"
const ANIM_PHASE_TRANSITION: StringName = &"phase_transition"
const ANIM_DEFEAT: StringName         = &"defeat"

# 使用:
anim_player.play(ANIM_ATTACK_HEAVY)  # ✅
anim_player.play("attack_heavy")     # ❌ リテラル禁止


# ─── ATTACKING→IDLE: CONNECT_ONE_SHOT pattern ─────────────────────────────

class_name BossStateMachine
extends Node

@onready var anim_player: AnimationPlayer = %AnimationPlayer

# 状態遷移: _enter_state / _exit_state (ADR-0004 パターン)

func _enter_state(state: BehaviorState) -> void:
    match state:
        BehaviorState.ATTACKING:
            # Attack animation name determined by current AttackData
            var anim_name: StringName = _get_attack_anim_for_type(current_attack_type)
            anim_player.play(anim_name)
            anim_player.animation_finished.connect(
                _on_attack_animation_done,
                CONNECT_ONE_SHOT  # 自動解除: 1回のみ起動
            )
        BehaviorState.STAGGERED:
            anim_player.play(ANIM_STAGGERED)
            # No callback needed — stagger duration controlled by CounterAttackComboSystem
        BehaviorState.DEFEATED:
            anim_player.play(ANIM_DEFEAT)

func _exit_state(state: BehaviorState) -> void:
    match state:
        BehaviorState.ATTACKING:
            # CRITICAL: cancel pending callback on interrupt (boss_defeated, etc.)
            if anim_player.animation_finished.is_connected(_on_attack_animation_done):
                anim_player.animation_finished.disconnect(_on_attack_animation_done)

func _on_attack_animation_done(_anim_name: StringName) -> void:
    # Guard: state may have changed if disconnect was delayed
    if behavior_state != BehaviorState.ATTACKING:
        return
    sequence_index = (sequence_index + 1) % current_phase.attack_sequence.size()
    _transition_to(BehaviorState.IDLE)
    idle_timer = current_phase.idle_duration_after_attack


# ─── HitpauseManager Autoload ─────────────────────────────────────────────
# autoloads/hitpause_manager.gd — registered as Autoload "HitpauseManager"

class_name HitpauseManagerNode
extends Node

var _active: bool = false  # re-entrancy guard

func trigger_hitpause(duration_secs: float) -> void:
    if _active:
        return  # skip nested hitpause (e.g. player hit + attack land same frame)
    _active = true
    Engine.time_scale = 0.0
    # ignore_time_scale=true: timer counts down in real time even at time_scale=0
    var timer := get_tree().create_timer(duration_secs, true, false, true)
    await timer.timeout
    Engine.time_scale = 1.0
    _active = false

# 呼び出し方 (直接 Autoload 呼び出し):
# HealthDamageSystem: HitpauseManager.trigger_hitpause(0.060)
# CounterAttackComboSystem (hit 3): HitpauseManager.trigger_hitpause(0.080)
# CounterAttackComboSystem (full combo): HitpauseManager.trigger_hitpause(0.030)
# ParryTelegraphSystem (parry success): HitpauseManager.trigger_hitpause(0.060)


# ─── Deprecated API note ──────────────────────────────────────────────────
# NEVER use:  anim_player.playback_active  (deprecated Godot 4.3)
# ALWAYS use: anim_player.active           (current API)
#
# NEVER use:  anim_player.animation_finished.connect(func, "method_name")
# ALWAYS use: anim_player.animation_finished.connect(callable)
```

---

## Alternatives Considered

### Alternative 1: Separate Timer Node for ATTACKING→IDLE

- **Description**: `AnimationPlayer` は視覚のみ担当。別の `Timer` ノードが ATTACKING 継続時間を管理し、`timeout` で IDLE に遷移。
- **Pros**: 動画とロジックを完全に分離できる; Timer は `CONNECT_ONE_SHOT` なしでも扱いやすい
- **Cons**: 動画変更のたびに Timer の `wait_time` も手動で同期する必要がある; 攻撃動画ごとに Timer 値を BossData に持たせると重複データになる; 動画と Timer がずれるリスク
- **Rejection Reason**: 動画の長さが「攻撃が終わった」という事実の唯一の権威。Timer を別に持つことはその権威を二重管理することになる。`CONNECT_ONE_SHOT` で十分安全。

### Alternative 2: `await animation_finished` (ベアコルーチン)

- **Description**: `await anim_player.animation_finished` でコルーチンとして記述。`boss_defeated` による中断は `if behavior_state != ATTACKING: return` ガードで対処。
- **Pros**: 読みやすい逐次フロー; Godot の慣用パターン
- **Cons**: `AnimationPlayer.stop()` は `animation_finished` を emit しない (Godot 4 仕様)。`boss_defeated` が発生して `anim_player.stop()` が呼ばれると、await は永遠に解決しない (コルーチンリーク)。`is_inside_tree()` ガードもノード生存は確認できるが await 解決は保証できない。
- **Rejection Reason**: コルーチンリークの可能性がある。`CONNECT_ONE_SHOT` + `_exit_state` disconnect は同等の可読性で完全な interrupt safety を提供する。

### Alternative 3: `SceneTree.paused` for Hitpause

- **Description**: `SceneTree.paused = true` を hitpause にも使用。ADR-0003 の死亡屏幕と同じメカニズム。
- **Pros**: 一種類のメカニズムで統一
- **Cons**: `SceneTree.paused = true` が死亡屏幕中にも設定されており、hitpause が死亡屏幕の resume タイミング（ADR-0003: 1500ms で paused=false）と競合する可能性。`process_mode` の設定が両ケースで異なる。
- **Rejection Reason**: `Engine.time_scale = 0` は `SceneTree.paused` と独立したメカニズム。両者が重なっても互いに上書きしない。Hitpause と死亡屏幕は設計上同時に発生しないが（hitpause は受击時に生じ、受击で死亡した場合は即 player_died が優先）、実装の独立性を保つことが正しい。

### Alternative 4: Per-system `_hitpause_frames` Counter

- **Description**: 全システムが `hitpause_frames_remaining: int` を保持し、`_physics_process` 先頭で `> 0` なら return。
- **Pros**: `Engine.time_scale` の副作用なし（SceneTree タイマーへの影響なし）
- **Cons**: 全システムに hitpause ロジックを実装する必要; フレームレート非依存でない（144fps では同じ「フレーム数」でも短い時間になる）; GUT テストで hitpause 効果を検証しにくい
- **Rejection Reason**: システム横断のボイラープレート増加。`Engine.time_scale = 0` が最小実装で最大効果。

---

## Consequences

### Positive
- 攻撃動画変更時にコードを触らなくてよい（動画長が唯一の権威）
- `CONNECT_ONE_SHOT` + `_exit_state` disconnect で Boss 状態機の全割り込みケースを安全に処理
- `Engine.time_scale = 0` により動画・物理・タイマーの全てが一貫して凍结（視覚的に「重量感」のある打击感）
- StringName 定数でタイポ即コンパイルエラー化、リファクタリング安全

### Negative
- `HitpauseManager` という新しい Autoload が追加される（小さいが管理コスト）
- `CONNECT_ONE_SHOT` パターンはコルーチンより若干冗長（ただしより安全）
- `Engine.time_scale = 0` は GUT でのテストが難しい（実時間タイマーが必要）— テストでは hitpause を mock する設計が必要

### Risks

| 風险 | 可能性 | 影響 | 缓解方案 |
|---|---|---|---|
| `SceneTree.create_timer(d, true, false, true)` が `Engine.time_scale=0` 中に正しく計時しない | 低 | hitpause 終了しない | ADR Engine Compatibility「Verification Required」でテスト必須 |
| hitpause 中に player_died → 死亡屏幕が SceneTree.paused → hitpause の Engine.time_scale=1.0 復元が死亡屏幕後に実行 | 低 | time_scale が 1.0 に戻らない | `HitpauseManager._on_tree_paused()` コールバックで SceneTree.paused 検知 → 即 time_scale 復元して `_active = false` |
| 複数システムが同フレームに hitpause を要求 | 中 | 最初の hitpause が最短のものに上書きされる | `_active` フラグで re-entrant ガード; 最初の hitpause が優先される |
| アニメーション定数が GDD の攻撃タイプ名と不一致 | 中 | 実行時に動画見つからずエラー | BossData バリデーションで `phase_transition_anim` が AnimationPlayer に存在することを確認（ADR-0002 の BossDataLoader._validate() に追加） |

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| boss-state-machine.md | TR-BSM-010: ATTACKING→IDLE は `AnimationPlayer.animation_finished` で駆動 | `CONNECT_ONE_SHOT` + `_exit_state` disconnect パターン |
| boss-state-machine.md | TR-BSM-005: STAGGERED 中断（boss_defeated / parry_succeeded）は即座に | `_exit_state(ATTACKING)` で CONNECT_ONE_SHOT callback を disconnect; STAGGERED への割り込みは次 `_enter_state` で新 callback |
| health-damage-system.md | Game Feel: 玩家受击 hitpause 60ms / Boss 第3击 80ms | `HitpauseManager.trigger_hitpause(0.060)` / `trigger_hitpause(0.080)` |
| parry-telegraph-system.md | Game Feel: 格挡成功 hitpause 60ms | `HitpauseManager.trigger_hitpause(0.060)` (ParryTelegraphSystem から呼び出し) |
| counter-attack-combo.md | Game Feel: 全连击完成 hitpause 30ms | `HitpauseManager.trigger_hitpause(0.030)` (CounterAttackComboSystem BONUS_STAGGER 進入時) |
| boss-state-machine.md | TR-BSM-010: .gd コードに攻撃種別デフォルト時長リテラルなし | StringName 定数経由でアニメーション名参照; 時長は AnimationPlayer から読み取り |

---

## Performance Implications

- **CPU**: `CONNECT_ONE_SHOT` connect/disconnect は O(1); hitpause は 60-80ms の実時間 freeze で CPU 負荷ではなく「停止」
- **Memory**: Autoload 1 個追加 (< 1KB); StringName 定数は interned で最小化
- **Load Time**: 影響なし
- **Network**: 不適用

---

## Migration Plan

首次代码编写前建立。創作順序：
1. 全定数ファイル（`anim_names.gd` または各システム先頭）
2. `autoloads/hitpause_manager.gd` + Autoload 登録
3. BossStateMachine の `_enter_state(ATTACKING)` で CONNECT_ONE_SHOT パターン実装
4. 各 combat システムの hitpause 呼び出し追加

---

## Validation Criteria

- [ ] `boss_defeated` が ATTACKING 中に発生したとき、`_on_attack_animation_done` が**呼ばれない**ことを GUT で検証
- [ ] `anim_player.stop()` が `animation_finished` を emit **しない**ことを Godot エディタで確認（仕様検証）
- [ ] `HitpauseManager.trigger_hitpause(0.060)` 実行時、60ms ± 1フレーム (16.6ms) 後に `Engine.time_scale` が 1.0 に戻ることを計時テスト
- [ ] hitpause 中に `player_died` が emit されたとき、死亡屏幕開始後に `Engine.time_scale == 1.0` であることを確認（死亡屏幕は SceneTree.paused を使用するため互いに独立）
- [ ] `grep "\"attack\|\"idle\|\"stagger"` で .gd ファイルを検索 → 文字列リテラルのアニメーション名が 0 件

## Related Decisions
- [ADR-0004](adr-0004-player-state-machine-architecture.md): `_enter_state` / `_exit_state` フックが animation trigger と CONNECT_ONE_SHOT disconnect の設置場所
- [ADR-0003](adr-0003-retrycontext-scene-reset.md): SceneTree.paused（死亡屏幕）と Engine.time_scale（hitpause）は独立したメカニズム
- [design/gdd/boss-state-machine.md](../../design/gdd/boss-state-machine.md)
- [design/gdd/health-damage-system.md](../../design/gdd/health-damage-system.md)
