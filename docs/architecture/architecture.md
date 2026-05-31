# 刃响 (Blade Echo) — Master Architecture

## Document Status

| Field | Value |
|---|---|
| Version | 1.0 |
| Last Updated | 2026-06-01 |
| Engine | Godot 4.6 |
| GDDs Covered | health-damage-system, player-controller-system, parry-telegraph-system, boss-state-machine, counter-attack-combo, instant-retry-system, hud-system |
| ADRs Referenced | None yet (see Required ADRs section) |
| Technical Director Sign-Off | Pending |
| Lead Programmer Feasibility | Skipped — Lean mode |

---

## Engine Knowledge Gap Summary

**Engine**: Godot 4.6 | **LLM cutoff**: ~Godot 4.3 | **Post-cutoff versions**: 4.4, 4.5, 4.6

This is a **2D game**. The highest-risk post-cutoff changes (Jolt 3D physics, IK system) do not apply.

| Risk Level | Domain | Implication for This Project |
|---|---|---|
| LOW | 2D Physics | CharacterBody2D + move_and_slide() unchanged — safe |
| LOW | Signals/Callables | Callable-based connects, GDScript 4.0 pattern stable |
| LOW | CanvasLayer/UI Layout | No breaking changes |
| MEDIUM | Input (4.6) | Dual-focus system: `grab_focus()` affects keyboard/gamepad only, not mouse hover. HUD gamepad navigation must be tested with both input methods. |
| MEDIUM | AnimationPlayer | API stable. `animation_finished` signal confirmed valid. `playback_active` → `active` (deprecated 4.3) — do not use. |
| MEDIUM | Rendering/2D (4.6) | D3D12 default on Windows; glow processes before tonemapping. Affects death screen RED_FLASH and HUD glow effects. Tune visual parameters on actual D3D12 build. |

**No HIGH RISK domains affect the MVP architecture.** All MEDIUM risk items are tuning/testing concerns, not API compatibility blockers.

---

## System Layer Map

```
┌──────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                                  │
│  • HUDSystem                                                         │
│    Pure subscriber. CanvasLayer-hosted. No signals emitted.          │
├──────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                       │
│  • ParryTelegraphSystem   — parry judgment, telegraph timing         │
│  • BossStateMachine       — Boss AI, attack sequencing, phases       │
│  • CounterAttackComboSystem — hit window, stagger lifecycle          │
│  • InstantRetrySystem     — death screen sequence, scene reset       │
├──────────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                          │
│  • HealthDamageSystem     — HP pools, damage/heal, death signals     │
│  • PlayerController       — CharacterBody2D, input→state→signals     │
├──────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER  (architectural modules — not in GDD systems)      │
│  • EventBus               — global signal routing Autoload           │
│  • RetryContext           — cross-reset persistence Autoload         │
│  • BossDataLoader         — BossData Resource load + validation      │
├──────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER (Godot 4.6)                                          │
│  CharacterBody2D · InputMap · AnimationPlayer · CanvasLayer          │
│  SceneTree · ResourceLoader · Timer                                  │
└──────────────────────────────────────────────────────────────────────┘
```

**Layer dependency rule**: Higher layers may only depend on lower layers. Core never imports Feature. Feature never imports Presentation. Violations = architectural defect.

---

## Module Ownership

### Foundation Layer

#### EventBus (Autoload: `EventBus`)

| Aspect | Detail |
|---|---|
| **Owns** | Global signal registry; cross-module signal type definitions |
| **Exposes** | All inter-module signals as typed signals on this node; any module can `EventBus.signal_name.connect(callable)` |
| **Consumes** | Nothing — pure routing hub |
| **Engine APIs** | `Node` (Autoload singleton); Godot typed signals |

Decision rationale: **ADR-001 will choose between EventBus Autoload and direct node connections.** This document assumes EventBus pending that decision. Alternative: direct `get_node()` references established in a `GameManager` scene root.

#### RetryContext (Autoload: `RetryContext`)

| Aspect | Detail |
|---|---|
| **Owns** | `preserved_boss_hp: float`, `preserved_boss_phase: int`, `session_death_count: int`; fresh-start flag |
| **Exposes** | `save_context(boss_hp, boss_phase, death_count)`, `load_context() → RetryData`, `clear_context()`, `is_fresh_start() → bool` |
| **Consumes** | Nothing — written by InstantRetrySystem, read by HealthDamageSystem + BossStateMachine at scene init |
| **Engine APIs** | `Node` (Autoload) |

#### BossDataLoader

| Aspect | Detail |
|---|---|
| **Owns** | BossData Resource cache; load-time validation logic |
| **Exposes** | `get_boss_data(boss_id: StringName) → BossData` |
| **Consumes** | `ResourceLoader.load(path)` |
| **Engine APIs** | `ResourceLoader` ✅ stable across all versions |
| **Validation** | Empty attack_sequence → error, refuse load. Invalid telegraph_duration_override → clamp to 0.1s + warning. Missing phase_symbol → warning + graceful fallback. |

---

### Core Layer

#### HealthDamageSystem

| Aspect | Detail |
|---|---|
| **Owns** | `current_player_hp: float`, `current_boss_hp: float`, `entered_phases: Dictionary[int, bool]`, `invuln_timer: float` |
| **Exposes** | `apply_damage(target: Target, amount: float)`, `apply_healing(target: Target, amount: float)` |
| **Consumes** | BossData (`boss_max_hp`, `phase_threshold_pct[]`) via BossDataLoader at init; RetryContext (`preserved_boss_hp`, `preserved_boss_phase`) at init |
| **Engine APIs** | None (pure logic node) |
| **Signals emitted** | `player_died`, `boss_defeated`, `player_hp_changed(current, max)`, `boss_hp_changed(current, max, phase)`, `boss_phase_changed(from, to)` |
| **Invariants** | HP is always in [0, max]; entered_phases never loses entries mid-fight; apply_damage(PLAYER, 0) is a no-op including invuln frame |

#### PlayerController

| Aspect | Detail |
|---|---|
| **Owns** | `player_state: PlayerState` (enum), `facing_direction: int`, `coyote_timer: float`, `jump_buffer_timer: float`; all @export movement parameters |
| **Exposes** | 6 signals: `parry_input_pressed`, `exit_parry_state(duration: float)`, `dodge_input_pressed(direction: int)`, `attack_input_pressed`, `heal_input_pressed` (Alpha) |
| **Consumes** | `player_hp_changed` → HIT_STUN; `player_died` → DEAD; retry reset signal → exit DEAD; `exit_parry_state(dur)` from ParryTelegraphSystem |
| **Engine APIs** | `CharacterBody2D.move_and_slide()` ✅; `Input.is_action_just_pressed(StringName)` ✅ |
| **State machine** | Enum: IDLE, RUNNING, AIRBORNE, PARRYING, DODGING, HIT_STUN, DEAD. Parry priority: parry > dodge same-frame. Attack forwarded only in IDLE/RUNNING/AIRBORNE. |

---

### Feature Layer

#### ParryTelegraphSystem

| Aspect | Detail |
|---|---|
| **Owns** | `system_state: {IDLE, TELEGRAPHING}`, `telegraph_timer: float`, current attack_type, current damage |
| **Exposes** | `telegraph_updated(progress: float, window_open: bool, type: AttackType)` (every physics frame during TELEGRAPHING) |
| **Consumes** | `attack_telegraphed(type, damage)` → enter TELEGRAPHING; `parry_input_pressed` → run path A/B/C judgment |
| **Calls** | `HealthDamageSystem.apply_damage(PLAYER, damage)` on timeout; signals to EventBus: `parry_succeeded(type)`, `parry_failed(type)`, `exit_parry_state(dur)` |
| **Engine APIs** | _physics_process delta accumulation (timer); no Godot Timer node required |
| **Invariants** | Only one active telegraph at a time. Second `attack_telegraphed` while TELEGRAPHING is rejected + logged. `player_died` or `boss_defeated` → immediate IDLE reset. |

#### BossStateMachine

| Aspect | Detail |
|---|---|
| **Owns** | `phase_index: int`, `behavior_state: BehaviorState`, `sequence_index: int`, internal timers (idle_timer, internal_telegraph_timer) |
| **Exposes** | `attack_telegraphed(type: AttackType, damage: float)` via EventBus |
| **Consumes** | BossData (PhaseData[], AttackData[]) at init; `parry_succeeded` → STAGGERED; `stagger_ended` → IDLE; `boss_phase_changed(from, to)` → PHASE_TRANSITION; `boss_defeated` → DEFEATED; `parry_failed` → optional hit-reaction layer |
| **Engine APIs** | `AnimationPlayer.play(anim_name)`, `AnimationPlayer.animation_finished` signal ✅ (confirmed stable in 4.6) |
| **Animation timing** | ATTACKING → IDLE transition is driven by `AnimationPlayer.animation_finished` signal, **not** a separate timer. This keeps animation and state in sync automatically. |
| **Invariants** | `boss_defeated` is a TERMINAL transition from any state — no recovery. `boss_defeated` priority over `stagger_ended` in same frame. PHASE_TRANSITION: if triggered mid-TELEGRAPHING, waits for current attack resolution first. |

#### CounterAttackComboSystem

| Aspect | Detail |
|---|---|
| **Owns** | `combo_state: {IDLE, COUNTER_WINDOW_OPEN, BONUS_STAGGER}`, `hit_count: int`, `window_timer: float`, `hit_cooldown_timer: float` |
| **Exposes** | `stagger_ended` (sole emitter); `counter_full_combo_completed(type: AttackType)`; `counter_window_updated(hit_count: int, time_remaining: float, state: ComboState)` (every physics frame during active window) |
| **Consumes** | `parry_succeeded(type)` → enter COUNTER_WINDOW_OPEN; `attack_input_pressed` → execute hit; `boss_defeated` / `player_died` → immediate IDLE, **do not** emit stagger_ended |
| **Calls** | `HealthDamageSystem.apply_damage(BOSS, hit_damage)` per hit |
| **Engine APIs** | _physics_process delta accumulation |
| **Invariants** | `stagger_ended` is only emitted from this module. hit_cooldown_active gates sequential hits. `boss_defeated` during COUNTER_WINDOW_OPEN: cancel timers, return IDLE silently. |

#### InstantRetrySystem

| Aspect | Detail |
|---|---|
| **Owns** | `death_screen_state: {ACTIVE, RED_FLASH, FADE_TO_GREY, PHASE_SYMBOL, SYMBOL_FADE_OUT, RESUMING}`, SceneTree pause control |
| **Exposes** | `retry_death_count_changed(count: int)` |
| **Consumes** | `player_died` → start death sequence; `boss_defeated` → clear RetryContext |
| **Engine APIs** | `SceneTree.paused` ✅ stable; `AnimationPlayer` for death screen visual sequence; `Input.is_anything_pressed()` for skip detection |
| **Scene reset strategy** | **In-place reset** (not scene reload): each module exposes a `reset_to_initial_state()` method; InstantRetrySystem calls these in dependency order after death screen. Avoids 1.5s reload budget risk. See ADR-003. |
| **Death screen constraint** | Total 1.5s (Art Bible 7.5). Any player input during sequence → immediate skip to RESUMING. NO UI elements on screen during sequence. |

---

### Presentation Layer

#### HUDSystem

| Aspect | Detail |
|---|---|
| **Owns** | HUD node references; last-known attack_type for counter bar denominator |
| **Exposes** | Nothing. Pure subscriber — never emits signals, never modifies game state |
| **Consumes** | `player_hp_changed`, `boss_hp_changed`, `boss_phase_changed`, `telegraph_updated` (every frame), `counter_window_updated` (every frame), `counter_full_combo_completed`, `retry_death_count_changed`, `boss_defeated` |
| **Engine APIs** | `CanvasLayer` ✅; `Control` node tree; `Label`; world→screen coordinate transform for counter bar player-following |
| **Counter bar positioning** | Counter bar follows player via `get_viewport().get_screen_transform() * player.global_position` each frame. Final method TBD in ADR-004 / UX spec. |
| **Performance** | `telegraph_updated` and `counter_window_updated` fire every physics frame (up to 144Hz). HUD rendering must be O(1) per frame — no per-frame allocation. |

---

## Data Flow

### 1. Frame Update Path

```
_physics_process(delta)
│
├─ PlayerController
│    reads InputMap → state transitions → emit signals → move_and_slide()
│
├─ BossStateMachine
│    idle_timer / internal_telegraph_timer countdown
│    → when idle_timer fires: emit attack_telegraphed(type, dmg)
│
├─ ParryTelegraphSystem
│    telegraph_timer countdown
│    → every frame: emit telegraph_updated(progress, window_open, type) → HUDSystem
│
├─ CounterAttackComboSystem
│    window_timer / hit_cooldown_timer countdown
│    → every frame (if active): emit counter_window_updated(n, t, state) → HUDSystem
│
└─ HUDSystem
     receives telegraph_updated + counter_window_updated → updates Control nodes
```

### 2. Full Parry → Counter Chain (Event Path)

```
BossStateMachine  →[attack_telegraphed(HEAVY, 25)]→  ParryTelegraphSystem (enters TELEGRAPHING)

[Player presses parry button]
PlayerController  →[parry_input_pressed]→  ParryTelegraphSystem
                  → checks: TELEGRAPHING + WINDOW_OPEN → parry_success = true
                    →[parry_succeeded(HEAVY)]→  CounterAttackComboSystem (COUNTER_WINDOW_OPEN, 1.5s)
                                             →  BossStateMachine (enters STAGGERED)
                    →[exit_parry_state(0.4s)]→  PlayerController (exits PARRYING in 0.4s)

[Player presses attack × 3]
PlayerController  →[attack_input_pressed]→  CounterAttackComboSystem
                    → hit 1: apply_damage(BOSS, 16) → HealthDamageSystem
                    → hit 2: apply_damage(BOSS, 22)
                    → hit 3: apply_damage(BOSS, 32)
                             →[counter_full_combo_completed(HEAVY)]→  HUDSystem
                             → enters BONUS_STAGGER (0.75s)
                    → BONUS_STAGGER expires →[stagger_ended]→  BossStateMachine (IDLE, sequence_index++)

HealthDamageSystem (during each hit):
  →[boss_hp_changed(current, 1000, 1)]→  HUDSystem (blood bar update)
  → if hp crosses 60% threshold:
    →[boss_phase_changed(1, 2)]→  BossStateMachine (PHASE_TRANSITION after stagger ends)
```

### 3. Player Death + Retry Path

```
HealthDamageSystem  →[player_died]→  InstantRetrySystem
                                  →  PlayerController (→ DEAD state)
                                  →  ParryTelegraphSystem (→ IDLE, cancel timers)
                                  →  CounterAttackComboSystem (→ IDLE, no stagger_ended)

InstantRetrySystem:
  1. SceneTree.paused = true
  2. Save RetryContext: {preserved_boss_hp, preserved_boss_phase, death_count+1}
  3. Play death screen: RED_FLASH 0.2s → FADE_TO_GREY 0.4s → PHASE_SYMBOL 0.6s → SYMBOL_FADE_OUT 0.3s
     [any input → skip to RESUMING]
  4. Call each module's reset_to_initial_state() in dependency order
  5. SceneTree.paused = false
  6. Emit retry_death_count_changed(count) → HUDSystem

After reset:
  HealthDamageSystem.current_player_hp = player_max_hp (100)
  HealthDamageSystem.current_boss_hp = RetryContext.preserved_boss_hp
  PlayerController → IDLE, position reset, invuln_timer = 2.0s
  BossStateMachine → IDLE, sequence_index = 0 for current phase
```

### 4. Initialisation Order

```
1. EventBus Autoload          (signal registry — must exist before any subscriber)
2. RetryContext Autoload       (persistent data — checked at module init)
3. BossDataLoader              (_ready: preload BossData resource, validate)
4. HealthDamageSystem          (_ready: init HP from BossData + RetryContext)
5. PlayerController            (_ready: connect to HealthDamageSystem signals)
6. BossStateMachine            (_ready: init from BossData, subscribe to signals)
7. ParryTelegraphSystem        (_ready: subscribe to signals)
8. CounterAttackComboSystem    (_ready: subscribe to signals)
9. InstantRetrySystem          (_ready: subscribe to player_died)
10. HUDSystem                  (_ready: subscribe to all update signals, read BossData for phase lines)
```

---

## API Boundaries

### Core Contracts (GDScript pseudocode)

```gdscript
# ─── HealthDamageSystem ───────────────────────────────────────────────
# THE single point of HP mutation. No other module may directly write HP.

enum Target { PLAYER, BOSS }

func apply_damage(target: Target, amount: float) -> void:
    # Preconditions: amount >= 0 (ignored if 0 or negative)
    # For PLAYER: no-op if INVULNERABLE; clamps to 0; emits player_died if ≤ 0
    # For BOSS: clamps to 0; checks phase thresholds; emits boss_defeated if ≤ 0

func apply_healing(target: Target, amount: float) -> void:
    # Preconditions: amount > 0
    # Clamps to max_hp; emits player_hp_changed

signal player_died
signal boss_defeated
signal player_hp_changed(current: float, max_hp: float)
signal boss_hp_changed(current: float, max_hp: float, phase: int)
signal boss_phase_changed(from_phase: int, to_phase: int)

# ─── PlayerController ─────────────────────────────────────────────────
# Input translation → state → signals. Does NOT decide parry success.

signal parry_input_pressed
signal exit_parry_state(duration: float)    # received FROM ParryTelegraphSystem
signal attack_input_pressed
signal dodge_input_pressed(direction: int)  # -1 or 1

# State read-only for other systems (no setter):
var player_state: PlayerState  # exported as @export var for inspector

# ─── ParryTelegraphSystem ─────────────────────────────────────────────
# Single judgment point for parry success. Consumes attack_telegraphed.
# Emitted signals:

signal parry_succeeded(attack_type: AttackType)
signal parry_failed(attack_type: AttackType)
signal exit_parry_state(duration: float)        # to PlayerController
signal telegraph_updated(progress: float, window_open: bool, attack_type: AttackType)

# Consumed signals:
# EventBus.attack_telegraphed(type, damage)
# PlayerController.parry_input_pressed

# ─── CounterAttackComboSystem ─────────────────────────────────────────
# Owns stagger lifecycle. The ONLY emitter of stagger_ended.

signal stagger_ended                                    # → BossStateMachine
signal counter_full_combo_completed(attack_type: AttackType)  # → HUDSystem
signal counter_window_updated(hit_count: int, time_remaining: float, state: ComboState)

# Consumed:
# EventBus.parry_succeeded(type)   → open window
# PlayerController.attack_input_pressed → execute hit
# EventBus.boss_defeated           → cancel, no stagger_ended
# EventBus.player_died             → cancel, no stagger_ended

# ─── RetryContext Autoload ────────────────────────────────────────────

class_name RetryContextNode
extends Node

func save_context(boss_hp: float, boss_phase: int, death_count: int) -> void
func load_context() -> Dictionary  # keys: boss_hp, boss_phase, death_count
func clear_context() -> void       # called on boss_defeated
func is_fresh_start() -> bool      # true if no saved context

# ─── BossData Resource (GDScript Resource subclass) ───────────────────
# Final class hierarchy TBD in ADR-002.

class_name BossData
extends Resource
@export var boss_id: StringName
@export var phases: Array[PhaseData]

class_name PhaseData
extends Resource
@export var phase_index: int
@export var attack_sequence: Array[AttackData]
@export var idle_duration_after_attack: float
@export var phase_transition_anim: StringName

class_name AttackData
extends Resource
@export var attack_type: AttackType  # enum from ParryTelegraphSystem
@export var damage: float
@export var telegraph_duration_override: float  # 0 = use AttackType default
```

---

## ADR Audit

**No existing ADRs** — `docs/architecture/` contains only the TR registry (empty). All decisions are new.

| ADR ID | Title | Status |
|---|---|---|
| ADR-001 | Signal Routing Architecture (EventBus vs direct) | Not yet written |
| ADR-002 | BossData Resource Architecture | Not yet written |
| ADR-003 | RetryContext + Scene Reset Strategy | Not yet written |
| ADR-004 | Player State Machine Architecture | Not yet written |
| ADR-005 | Animation-to-Code Boundary | Not yet written |

---

## Required ADRs

### Foundation Layer (must write before any coding begins)

**1. `/architecture-decision "Signal Routing Architecture"` → ADR-001**
Decides between EventBus Autoload (global decoupling, testable) and direct node connections (simpler, scene-coupled). Covers: TR-PTS-001/005/007/009, TR-CAC-007/008, TR-IRS-001/011, TR-HUD-002-008 — effectively every cross-module signal in the game.

**2. `/architecture-decision "BossData Resource Architecture"` → ADR-002**
Defines BossData/PhaseData/AttackData as Godot Resource subclasses (.tres) vs JSON files. Covers: TR-BSM-002/003/009/010, TR-HDS-010, TR-PTS-011. Unblocks BossStateMachine, HealthDamageSystem, ParryTelegraphSystem.

**3. `/architecture-decision "RetryContext and Scene Reset Strategy"` → ADR-003**
Decides RetryContext as Autoload singleton (recommended) vs scene parameter passing; chooses in-place module reset vs scene reload for the 1.5s retry budget. Covers: TR-IRS-003/004/005/006/007/008/009/010.

### Core Layer (write before coding core systems)

**4. `/architecture-decision "Player State Machine Architecture"` → ADR-004**
Specifies enum-based state machine pattern with CharacterBody2D integration: transition functions, priority rules (parry > dodge), state guards. Covers: TR-PC-001/002/003/004/005.

### Feature Layer (write before coding the relevant system)

**5. `/architecture-decision "Animation to Code Boundary"` → ADR-005**
Specifies that ATTACKING→IDLE transition is triggered by `AnimationPlayer.animation_finished` (not a separate Timer), and defines hitpause implementation (freeze velocity for N frames via SceneTree.paused or per-node process_mode). Covers: TR-BSM-010, hitpause for combat feel.

---

## Architecture Principles

1. **Signal single-direction flow** — Higher layers subscribe to lower-layer signals; Core never imports Feature; Feature never imports Presentation. Any cycle = architectural defect.

2. **Data injected from assets; code contains no gameplay literals** — All tuning parameters (HP, damage, timing) come from BossData Resource or @export variables. No float/int literals in `.gd` logic files. Zero exceptions.

3. **Single ownership per state** — Every piece of state has exactly one owning module. `stagger_ended` is owned exclusively by CounterAttackComboSystem. `apply_damage` is owned exclusively by HealthDamageSystem. No two modules may write the same state.

4. **Foundation-first implementation order** — EventBus → RetryContext → BossDataLoader must be built and tested before any Core or Feature system. A broken signal backbone cannot be patched by correct gameplay code.

5. **Testability via dependency injection** — All modules receive their dependencies (BossData, HealthDamageSystem reference) through `_ready()` or an `initialize(deps)` call. No `get_node("/root/...")` path strings in logic code. This enables GUT unit tests to inject mocks.

---

## Open Questions

| ID | Summary | Priority | Resolution Path |
|---|---|---|---|
| QQ-01 | EventBus vs direct node connections — signal routing style | **High** | ADR-001 |
| QQ-02 | BossData Resource subclass vs JSON | **High** | ADR-002 |
| QQ-03 | In-place scene reset vs scene reload for 1.5s retry budget | **High** | ADR-003 |
| QQ-04 | HUD counter bar world-coordinate tracking method | Medium | ADR-004 or UX spec |
| QQ-05 | AnimationPlayer.animation_finished vs internal timer for Boss ATTACKING→IDLE | Medium | ADR-005 |
| QQ-06 | HUD dual-focus behavior (4.6) — gamepad focus path for any menu overlays | Medium | UX spec + playtest |
| QQ-07 | `attack_input_pressed` — should attack button be distinct from parry button? (InputMap config) | Low | Settings/UX spec |
| QQ-08 | Death screen RED_FLASH implementation — CanvasItem modulate vs shader vs separate ColorRect | Low | ADR-005 or implementation sprint |

---

*Architecture v1.0 — created 2026-06-01 by /create-architecture*
*Next step: Run `/architecture-decision "Signal Routing Architecture"` to begin ADR-001.*
