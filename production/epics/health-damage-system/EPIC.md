# Epic: HealthDamageSystem

> **Layer**: Core
> **GDD**: design/gdd/health-damage-system.md
> **Architecture Module**: HealthDamageSystem (Core Layer — architecture.md)
> **Status**: Ready
> **Stories**: 7 stories created — see table below

## Overview

HealthDamageSystem is the single authority for all HP mutation in the game. It
owns the player HP pool and the Boss HP pool, applies incoming damage and healing
via `apply_damage(target, amount)` and `apply_healing(target, amount)`, and emits
all downstream signals: `player_died`, `boss_defeated`, `player_hp_changed`,
`boss_hp_changed`, and `boss_phase_changed`. It enforces the "失败是学习" pillar
by preserving Boss HP across retries (via RetryContext), so progress made in
previous attempts is never erased. Every combat system that reads or writes health
data must go through this module — no other system may directly write HP fields.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Signal Routing Architecture | All 1:N cross-module signals emitted via EventBus Autoload; typed signals; Callable-based connect | LOW |
| ADR-0002: BossData Resource Architecture | Boss-specific data (boss_max_hp, phase_threshold_pct[]) stored in GDScript Resource subclasses (.tres); never hardcoded | LOW |
| ADR-0003: RetryContext and Scene Reset Strategy | RetryContext Autoload preserves Boss HP and entered_phases across player death; in-place module reset via reset_for_retry(ctx) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-HDS-001 | Player HP is a continuous float in [0, player_max_hp]; damage via apply_damage(target, amount); system does not judge whether damage applies | ✅ Architecture Principle 3 (single ownership) |
| TR-HDS-002 | After a hit: INVULNERABLE window (0.5s); apply_damage(PLAYER) ignored; timer does NOT reset on re-hit | ℹ️ Pure logic (no ADR needed) |
| TR-HDS-003 | Damage clamps current_player_hp to 0; no negative HP stored | ℹ️ Pure logic (no ADR needed) |
| TR-HDS-004 | current_player_hp ≤ 0 emits player_died same frame with no buffer | ✅ ADR-0001 (signal routing) |
| TR-HDS-005 | Boss HP first crossing a phase threshold emits boss_phase_changed(from, to) exactly once; phase added to entered_phases | ✅ ADR-0001 (signal routing) |
| TR-HDS-006 | Boss HP ≤ 0 clamps to 0 and emits boss_defeated exactly once; residual attacks do not re-emit | ✅ ADR-0001 (signal routing) |
| TR-HDS-007 | On player death + retry, Boss HP is NOT reset; entered_phases persists across retry | ✅ ADR-0003 (RetryContext) |
| TR-HDS-008 | apply_healing(PLAYER, amount) clamps to player_max_hp; HP never exceeds max | ℹ️ Pure logic (no ADR needed) |
| TR-HDS-009 | Single damage crossing multiple phase thresholds emits boss_phase_changed in ascending phase order; no phase skipped | ℹ️ Pure logic (no ADR needed) |
| TR-HDS-010 | boss_max_hp and phase_threshold_pct[] come from BossData asset; not hardcoded in any .gd file | ✅ ADR-0002 (BossData Resource) |
| TR-HDS-011 | apply_damage(PLAYER, 0 or negative) is a no-op: no HP change, no signal, does not consume invuln window | ℹ️ Pure logic (no ADR needed) |
| TR-HDS-012 | HUD segment count = (hp≤0) ? 0 : ceil(current_hp / hp_per_segment); hp_per_segment = max_hp / segments | ℹ️ Pure logic (no ADR needed) |
| TR-HDS-013 | Emits player_hp_changed(current, max) and boss_hp_changed(current, max, phase) for HUD updates | ✅ ADR-0001 (signal routing) |
| TR-HDS-014 | Boss damage intake = counter_base_damage × multiplier[n]; full 3-hit combo = {16, 22, 32} = 70 HP; multiplier table owned by counter-attack-combo GDD formula 1 | ℹ️ Pure logic (formula ownership documented in GDD) |
| TR-HDS-015 | Per-frame processing under 1.0ms across 1000 consecutive damage frames | ℹ️ Performance budget (no ADR needed) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/health-damage-system.md` are verified
- All Logic stories have passing test files in `game/tests/unit/health_damage/`
- Performance budget confirmed: < 1.0ms/frame under continuous damage load (Godot Profiler)
- No HP literals (100, 1000, 0.5, etc.) appear in any `.gd` logic file — all via @export or BossData

## Stories

| # | Story | Type | Status | Primary ADR |
|---|-------|------|--------|-------------|
| 001 | [HP Initialization and BossData Contract](story-001-hp-initialization.md) | Logic | Complete | ADR-0002 |
| 002 | [Player Damage Application and Invulnerability Window](story-002-player-damage-and-invuln.md) | Logic | Complete | ADR-0001 |
| 003 | [Player Death Detection and HP Clamping](story-003-player-death.md) | Logic | Complete | ADR-0001 |
| 004 | [Healing Application and Over-Heal Guard](story-004-player-healing.md) | Logic | Ready | ADR-0001 |
| 005 | [Boss HP, Phase Detection, and Defeat](story-005-boss-hp-phases-defeat.md) | Logic | Ready | ADR-0001 |
| 006 | [HUD Segment Count Formula](story-006-hud-segment-formula.md) | Logic | Ready | N/A |
| 007 | [Retry Reset Contract](story-007-retry-reset-contract.md) | Integration | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/health-damage-system/story-001-hp-initialization.md` to validate the first story before picking it up.
