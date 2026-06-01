# Test Infrastructure — 刃响 (Blade Echo)

**Engine**: Godot 4.6
**Test Framework**: GUT (Godot Unit Testing) — install via AssetLib
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-06-01

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Installing GUT

1. Open Godot → AssetLib → search **"GUT"** → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GUT ✓
3. Restart the editor
4. Verify: `res://addons/gut/` exists

## Running Tests

**In editor**: GUT panel (bottom bar after plugin enabled) → Run All

**Headless (CI)**:
```
godot --headless --script tests/gut_runner.gd
```

**Single system**:
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=tests/unit/health_damage/
```

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]()`
- **Example**: `health_damage_test.gd` → `test_apply_damage_reduces_player_hp()`

## Required Test Coverage (per GDD)

| System | Minimum coverage | Notes |
|--------|-----------------|-------|
| HealthDamageSystem | 100% AC | 格挡/重试系统的数学基础 |
| ParryTelegraphSystem | 100% AC | 时机公式必须精确 |
| BossStateMachine | 100% AC | 状态机转换 |
| CounterAttackComboSystem | 100% AC | stagger 生命周期 |
| PlayerController | 100% AC | 输入优先级 + 状态转换 |
| InstantRetrySystem | 100% AC | 重试数据一致性 |
| HUDSystem | ADVISORY | 视觉——截图 + 负责人批准 |

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging. See `.github/workflows/tests.yml`.

## GUT Test Template

```gdscript
# tests/unit/[system]/[system]_[feature]_test.gd
extends GutTest

# Inject dependencies here:
var _health_sys: HealthDamageSystem

func before_each() -> void:
    _health_sys = HealthDamageSystem.new()
    # inject mock EventBus per ADR-0001:
    # _health_sys.initialize(MockEventBus.new())
    add_child(_health_sys)

func after_each() -> void:
    _health_sys.queue_free()

func test_apply_damage_reduces_player_hp() -> void:
    _health_sys.apply_damage(GameEnums.Target.PLAYER, 10.0)
    assert_eq(_health_sys.current_player_hp, 90.0,
        "apply_damage(PLAYER, 10) should reduce HP from 100 to 90")
```
