# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-06-01
> **Manifest Version**: 2026-06-01
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this date
when created. `/story-readiness` compares a story's embedded version to this field to
detect stories written against stale rules. Always matches `Last Updated`.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each rule,
see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: EventBus, RetryContext, BossDataLoader, HitpauseManager,
GameEnums — any Autoload or shared data module*

### Required Patterns

- **All 1:N cross-module signals must be defined on `autoloads/event_bus.gd`**,
  registered as Autoload "EventBus". Emit via `EventBus.signal_name.emit()`;
  subscribe via `EventBus.signal_name.connect(callable)`. — source: ADR-0001

- **All systems must accept optional EventBus injection for GUT testability**:
  `func initialize(event_bus: EventBus = null) -> void`. In tests, pass a mock;
  in production, omit (falls back to global Autoload). — source: ADR-0001

- **Use Godot 4 typed signals with parameter types** — e.g.,
  `signal player_hp_changed(current: float, max_hp: float)`. Never declare
  untyped signals for cross-module use. — source: ADR-0001

- **All shared enums (AttackType, ComboState, Target, PlayerState) must be defined
  in a single `scripts/data/game_enums.gd`** with `class_name GameEnums`.
  All other scripts reference them as `GameEnums.AttackType` etc. — source: ADR-0002

- **BossData, PhaseData, AttackData must be `class_name` GDScript Resource subclasses**
  with `@export` fields. Store as `.tres` text files under `res://data/bosses/`.
  Never use Dictionary or JSON for Boss-specific data. — source: ADR-0002

- **BossDataLoader must call `_validate()` on every loaded BossData resource.**
  Validation rules: assert `attack_sequence.size() > 0`; assert
  `idle_duration_after_attack > 0` (clamp to 0.1s + warning if <0.1s);
  clamp `telegraph_duration_override < 0.1s` to 0.1s + warning;
  assert `phase_threshold_pct` is descending. — source: ADR-0002

- **GUT tests must inject BossData via `BossData.new()` in code** — never depend
  on `.tres` file I/O. Provide a `_make_test_boss()` factory helper in each test
  class. — source: ADR-0002

- **RetryContext must be a Godot Autoload** registered as "RetryContext"
  (`autoloads/retry_context.gd`, `class_name RetryContextNode`). — source: ADR-0003

- **HitpauseManager must be a Godot Autoload** registered as "HitpauseManager"
  (`autoloads/hitpause_manager.gd`, `class_name HitpauseManagerNode`). — source: ADR-0005

- **Every resettable system must implement `reset_for_retry(ctx: Dictionary) -> void`**
  and reset all stateful variables to their post-death-screen initial values.
  Missing a variable here is a latent gameplay bug. — source: ADR-0003

- **Signal connections must use Callable-based API**: `signal.connect(callable)`
  or `signal.connect(callable, CONNECT_ONE_SHOT)`. Never the deprecated string form. — source: ADR-0001

- **Autoload registration order** (Project Settings → Autoload) must be:
  `EventBus` → `RetryContext` → `HitpauseManager`. Other Autoloads after these
  three. Scene nodes that depend on them will then always find them ready. — source: ADR-0001 + ADR-0003 + ADR-0005

### Forbidden Approaches

- **Never use string-based `connect("signal_name", obj, "method")`** — deprecated
  since Godot 4.0; not type-safe; breaks refactoring. — source: ADR-0001

- **Never define 1:N broadcast signals on individual system nodes** — put them on
  EventBus. Defining them elsewhere makes testability fragile and subscriber
  discovery opaque. — source: ADR-0001

- **Never hardwire subscriber lists in a GameRoot._ready() method** for signals that
  have more than one subscriber — the "God method" pattern fails testability when
  any single system needs to be isolated. — source: ADR-0001

- **Never use JSON + Dictionary for BossData** — no type safety, requires manual
  validation, not Inspector-editable. — source: ADR-0002

- **Never define AttackType, ComboState, Target, or PlayerState enums in more than
  one file** — renaming an enum value in one file silently leaves the others stale. — source: ADR-0002

- **Never use `get_tree().reload_current_scene()` for retry reset** — load time is
  O(asset size) and will exceed the 1.5s Art Bible constraint once HD assets are
  added in Alpha/Full. — source: ADR-0003

- **Never let each system self-reset on `player_died` independently** — reset order
  is a hard requirement (HealthDamageSystem must reset HP before BossStateMachine
  reads it). InstantRetrySystem coordinates the sequence. — source: ADR-0003

- **Never use `get_tree().set_meta()` for RetryContext** — less type-safe than an
  Autoload class; string key lookup is error-prone. — source: ADR-0003

### Performance Guardrails

- **EventBus Autoload**: load time < 1ms at project startup — source: ADR-0001
- **In-place reset** (`_execute_retry_reset()`): wall-clock < 100ms, completing
  within the FADE_TO_GREY window (200–600ms from `player_died`) — source: ADR-0003
- **ResourceLoader.load()** for BossData: called once at battle start and cached;
  never called during active combat — source: ADR-0002

---

## Core Layer Rules

*Applies to: HealthDamageSystem, PlayerController — and by ownership rules,
all systems that interact with HP or player state*

### Required Patterns

- **PlayerController extends CharacterBody2D.** Always call `move_and_slide()` as
  the last statement in `_physics_process`, after `_handle_input()` and
  `_process_state(delta)`. — source: ADR-0004

- **All player state changes must go through `_transition_to(new_state)`** — this
  function calls `_exit_state(old)`, assigns, then calls `_enter_state(new)`.
  Never assign `player_state =` directly anywhere else. — source: ADR-0004

- **`_handle_input()` must use priority-ordered early returns**:
  `DEAD` guard first → `parry` → `dodge` → `jump` → `attack` → `move`.
  This order is load-bearing; changing it changes gameplay semantics. — source: ADR-0004

- **`_can_parry()`, `_can_dodge()`, `_can_attack()` must be separate, standalone
  functions** that can be called from GUT tests without triggering state changes. — source: ADR-0004

- **All PlayerController numeric parameters must be `@export var`** — no float/int
  literals in logic code (not 340, 1400, 600, 0.10, 0.12, 200, 0.30, etc.). — source: ADR-0004

- **Input actions must be referenced by StringName**: `Input.is_action_just_pressed(&"parry")`,
  never by hardcoded key codes. — source: ADR-0004

- **PlayerController's 1:1 signals (`parry_input_pressed`, `attack_input_pressed`,
  `dodge_input_pressed(direction)`) must be emitted as direct node signals** — NOT
  via EventBus. These have single consumers; EventBus overhead is unnecessary
  and the 1:1 exception is established in ADR-0001. — source: ADR-0001 + ADR-0004

- **PlayerController must implement `reset_for_retry(ctx: Dictionary)`** per ADR-0003
  contract: reset `player_state`, `velocity`, `position` (to spawn_position),
  `facing_direction`, and all timers. — source: ADR-0003 + ADR-0004

- **HealthDamageSystem is the sole owner of HP mutation.** Only `apply_damage(target, amount)`
  and `apply_healing(target, amount)` may change `current_player_hp` or
  `current_boss_hp`. No other module writes these fields directly. — source: architecture principle 3

- **CounterAttackComboSystem is the sole emitter of `stagger_ended`.** This
  ownership is load-bearing: the full-combo bonus stagger requires the emitter to
  be the same system that manages bonus duration. — source: ADR-0001

- **HUDSystem is a pure subscriber.** It must never emit any signal, never call
  `apply_damage`, and never hold a write reference to any game-state variable. — source: ADR-0001

- **`GameEnums.PlayerState` enum must be defined before PlayerController**. Add it
  to `scripts/data/game_enums.gd` during Technical Setup before implementing
  the first sprint. — source: ADR-0002 + ADR-0004

### Forbidden Approaches

- **Never use AnimationTree StateMachine nodes for game-logic state control** —
  AnimationTree is designed for animation transitions, not gameplay logic; it
  makes `_can_parry()` / parry-priority rules untestable in GUT. — source: ADR-0004

- **Never assign `player_state =` outside `_transition_to()`** — bypassing this
  dispatcher skips `_exit_state` and `_enter_state` hooks, leaving the system in
  a half-transitioned state. — source: ADR-0004

- **Never call `move_and_slide()` before `_handle_input()` or `_process_state()`** —
  velocity must be set by logic before physics integration, not after. — source: ADR-0004

- **Never let any module other than HealthDamageSystem write HP fields directly** —
  single ownership prevents race conditions and double-decrements. — source: architecture principle 3

- **Never emit `stagger_ended` from any module other than CounterAttackComboSystem** —
  splitting ownership would make full-combo bonus stagger impossible to implement
  correctly. — source: ADR-0001

- **Never have HUDSystem emit signals or mutate game state** — HUD is presentation;
  it must remain a one-way data sink for correctness and testability. — source: ADR-0001

### Performance Guardrails

- **PlayerController `_physics_process` (full frame)**: < 0.5ms/frame — source: ADR-0004
- **HealthDamageSystem per-frame processing** (continuous damage load): < 1.0ms/frame — source: TR-HDS-015

---

## Feature Layer Rules

*Applies to: BossStateMachine, ParryTelegraphSystem, CounterAttackComboSystem,
InstantRetrySystem*

### Required Patterns

- **Boss ATTACKING→IDLE must be driven by `AnimationPlayer.animation_finished`**,
  not a separate Timer. Connect with `CONNECT_ONE_SHOT` on `_enter_state(ATTACKING)`:
  `anim_player.animation_finished.connect(_on_attack_animation_done, CONNECT_ONE_SHOT)`. — source: ADR-0005

- **`_exit_state(ATTACKING)` must disconnect the one-shot callback** if it is still
  connected, to prevent firing after `boss_defeated` interrupts the state:
  `if anim_player.animation_finished.is_connected(_on_attack_animation_done): anim_player.animation_finished.disconnect(_on_attack_animation_done)`. — source: ADR-0005

- **`_on_attack_animation_done` must have a state guard as its first line**:
  `if behavior_state != BehaviorState.ATTACKING: return`. This handles the
  edge case where disconnect is delayed by one frame. — source: ADR-0005

- **BossStateMachine must contain no AttackType default duration literals** (0.8,
  1.2, 1.5 seconds). These live in the data layer; BossStateMachine looks them
  up from BossData or a GameEnums constant table. — source: ADR-0002

- **BossStateMachine.reset_for_retry(ctx) must**: set `behavior_state = IDLE`,
  set `sequence_index = 0`, clear `idle_timer` and `internal_telegraph_timer`,
  restore `phase_index = ctx["boss_phase"]`. — source: ADR-0003

- **InstantRetrySystem.process_mode must be `PROCESS_MODE_ALWAYS`** — it must
  continue running while `SceneTree.paused = true` to drive the death-screen
  animation and detect skip input. — source: ADR-0003

- **The death-screen AnimationPlayer.process_mode must be `PROCESS_MODE_ALWAYS`**
  for the same reason. — source: ADR-0003

- **All Feature-layer systems except InstantRetrySystem default to
  `PROCESS_MODE_PAUSEABLE`** — they must freeze when the death screen pauses the
  tree. Setting `PROCESS_MODE_ALWAYS` without reason causes incorrect updates
  during the death screen. — source: ADR-0003

- **HitpauseManager.trigger_hitpause() must be called at exactly these moments**:
  player receives a hit (60ms); parry success (60ms); 3rd counter-combo hit
  (80ms); full-combo completion BONUS_STAGGER entry (30ms). — source: ADR-0005

- **HitpauseManager must guard against re-entry**:
  `if _active: return` at the top of `trigger_hitpause()`. The first hitpause
  request wins; nested requests are silently dropped. — source: ADR-0005

- **Use `Input.is_anything_pressed()` inside a `PROCESS_MODE_ALWAYS` `_process`**
  for death-screen skip detection. Start listening only after RED_FLASH ends (200ms
  into the sequence) to prevent residual death-frame input from triggering skip.
  *(Note: GDD AC-03 and ADR-0003 are in conflict on this 200ms guard — see CONFLICT-01
  in architecture-review-2026-06-01.md. Implement the 200ms guard per ADR-0003 until
  resolved.)* — source: ADR-0003

### Forbidden Approaches

- **Never use `await anim_player.animation_finished`** — `AnimationPlayer.stop()`
  does NOT emit `animation_finished` (Godot 4 specification). A `boss_defeated`
  interruption calling `stop()` will cause the coroutine to leak and never resolve. — source: ADR-0005

- **Never use a separate Timer node to track ATTACKING duration** — the animation
  length is the sole authority; a Timer creates dual-authority and divergence risk. — source: ADR-0005

- **Never use `SceneTree.paused = true` for hitpause** — that mechanism is
  reserved for the death screen (ADR-0003). Using it for hitpause creates
  a conflict over who restores `paused = false`. — source: ADR-0005

- **Never use a per-system `_hitpause_frames: int` counter** — framerate-dependent;
  at 144fps the same frame count is half the time. — source: ADR-0005

- **Never hardcode BossData values (boss_max_hp, damage, telegraph durations,
  stagger durations) as literals in any Feature .gd file** — all such values
  come from BossData resources or `@export var` on the system. — source: ADR-0002

- **Never allow any system other than InstantRetrySystem to set `SceneTree.paused`** —
  mixed ownership of the pause state creates unresolvable ordering bugs. — source: ADR-0003

### Performance Guardrails

- **In-place reset sequence** (`_execute_retry_reset()`): must complete before
  the FADE_TO_GREY window ends (at most 400ms elapsed from `player_died`) — source: ADR-0003
- **EventBus per-frame stream signals** (`telegraph_updated`, `counter_window_updated`):
  < 0.1ms/frame at 60fps; verify with Godot Profiler — source: ADR-0001

---

## Presentation Layer Rules

*Applies to: HUDSystem, AnimationPlayer usage, any rendering customisation*

### Required Patterns

- **All animation names must be defined as `StringName` constants** in the script
  header or a shared `scripts/data/anim_names.gd`:
  `const ANIM_ATTACK_HEAVY: StringName = &"attack_heavy"`. Use the constant
  everywhere; never inline the string. — source: ADR-0005

- **HUD must be hosted on a CanvasLayer** — this guarantees it renders above the
  game world and is not affected by camera transforms. — source: architecture + ADR-0001

- **HUD per-frame signal handlers (`telegraph_updated`, `counter_window_updated`)
  must be O(1) with no per-frame allocation** — no `Array.new()`, no string
  concatenation, no recursive tree traversal inside these callbacks. — source: ADR-0001

- **Tune glow and post-process effects on an actual D3D12 Windows build** — glow
  now processes before tonemapping in Godot 4.6 (was after). Existing Vulkan-tuned
  glow scenes will look different. The RED_FLASH death screen and HUD glow effects
  are specifically at risk. — source: engine-reference/current-best-practices.md (4.6)

- **Test all menus and HUD navigation with both keyboard/gamepad AND mouse** —
  Godot 4.6's dual-focus system makes keyboard/gamepad focus and mouse hover
  independent. A menu that passes keyboard testing can still have broken mouse
  hover states. — source: engine-reference/current-best-practices.md (4.6)

### Forbidden Approaches

- **Never use string literals for animation names** in `anim_player.play()` calls:
  `anim_player.play("attack_light")` is forbidden. Always reference the StringName
  constant. — source: ADR-0005

- **Never use `AnimationPlayer.playback_active`** — deprecated since Godot 4.3;
  moved to base class. Use `AnimationMixer.active` instead. — source: ADR-0005 + deprecated-apis.md

- **Never assume glow/post-process appearance on D3D12 matches a Vulkan build** —
  treat D3D12 as a separate visual tuning target. — source: engine-reference/current-best-practices.md (4.6)

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `BossEnemy`, `ParrySystem` |
| Variables | snake_case | `move_speed`, `current_health` |
| Functions | snake_case | `apply_parry()`, `take_damage()` |
| Signals / Events | snake_case past tense | `health_changed`, `parry_triggered`, `boss_defeated` |
| Files | snake_case matching class name | `boss_enemy.gd`, `parry_system.gd` |
| Scenes / Resources | PascalCase matching root node | `BossEnemy.tscn`, `MainMenu.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `PARRY_WINDOW_FRAMES` |

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Max scene nodes | ≤ 20,000 (2D batching enabled) |
| Memory ceiling | ≤ 512 MB RAM |

### Approved Libraries / Addons

- **GUT** (Godot Unit Testing) — approved for `tests/` only; installed via AssetLib.
  Not a gameplay dependency; never `import` GUT from `src/`.

### Forbidden APIs — Godot 4.6

These APIs are deprecated or known-broken for Godot 4.6. Any use is a code-review
blocker.

| Forbidden | Use Instead | Since |
|-----------|-------------|-------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` | `VisibleOnScreenNotifier2D` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |

Source: `docs/engine-reference/godot/deprecated-apis.md`

### Cross-Cutting Constraints

- **No gameplay literals in `.gd` logic files.** Every tuning value (HP, damage,
  timing, speed) must come from a `@export var`, a `const`, or a loaded Resource.
  Zero exceptions. — source: ADR-0002 + technical-preferences.md

- **All public methods must be unit-testable** via dependency injection — no
  `get_node("/root/...")` path strings in logic code; systems receive their
  dependencies through `_ready()` exports or `initialize(deps)`. — source: architecture principle 5

- **Every gameplay system must have a corresponding ADR** covering its core
  architectural decision. Starting implementation without an Accepted ADR for
  that system is a gate-check blocker. — source: docs/CLAUDE.md coding standards

- **Commits must reference the relevant story or task ID** in the commit body
  (Conventional Commits format: `feat:`, `fix:`, `chore:`, `docs:`, `test:`,
  `refactor:`). — source: technical-preferences.md coding standards

- **Never search GDScript files with `rg --type gdscript`** — `gdscript` is not
  a registered ripgrep type. Use `rg --glob "*.gd"` or the Grep tool with
  `glob: "*.gd"`. — source: engine-reference/current-best-practices.md tooling note

---

## Open Items (not yet codified — resolve before related stories begin)

These items were flagged as ⚠️ PARTIAL in the architecture review and are
intentionally excluded from the manifest until resolved:

| Item | Unresolved question | Source |
|------|---------------------|--------|
| Parry timing overrides (window_open_fraction, window_width, stagger_duration) | Global @export on ParryTelegraphSystem vs per-attack override in AttackData | TR-PTS-011 / CONFLICT-01 |
| Counter combo tuning (counter_base_damage, multiplier[], bonus_ratio, hit_animation_duration) | Global @export on CounterAttackComboSystem vs a ComboTuning Resource | TR-CAC-002/003/006 |
| HUD counter-bar world-coordinate tracking | CanvasLayer screen-transform vs Node2D world-layer rendering | TR-HUD-008 |

**Default until resolved**: treat all of the above as `@export var` on the owning
system. This is the safe fallback — it satisfies "no literals in code" without
requiring a new Resource schema. Override this default via ADR or control-manifest
update when the design decision is made.
