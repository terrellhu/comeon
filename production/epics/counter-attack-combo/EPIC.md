# Epic: CounterAttackComboSystem

> **Layer**: Feature
> **GDD**: design/gdd/counter-attack-combo.md
> **Architecture Module**: CounterAttackComboSystem
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories counter-attack-combo`

## Overview

CounterAttackComboSystem 是刃响战斗循环的"奖励输出层"。系统订阅 `parry_succeeded(type)` 开启反击窗口（`base_counter_window[type]`：LIGHT=1.0s / HEAVY=1.5s / SWEEP=2.0s）。玩家在窗口内每次按攻击键触发一次连击，对 Boss 造成递增伤害（公式 1：n=1→16hp、n=2→22hp、n=3→32hp，基于 counter_base_damage=20 × multiplier[n]）；每击有冷却保护（hit_animation_duration≤0.30s）。完成 3 次全连击后，系统发出 `counter_full_combo_completed`，进入 BONUS_STAGGER（延长 Boss 硬直 = base_counter_window × bonus_ratio，公式 2）；最终发出 `stagger_ended`（**本系统是此信号的唯一发出者**）通知 Boss 状态机恢复行动。窗口到期或被中断时同样发出 `stagger_ended`（boss_defeated/player_died 例外：静默返回 IDLE，不发出 stagger_ended）。每物理帧广播 `counter_window_updated(hit_count, time_remaining, state)` 供 HUD 显示。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Signal Routing Architecture | stagger_ended 唯一发出者模式；apply_damage 调用路由 | LOW |
| ADR-0005: Animation-to-Code Boundary | hit cooldown 计时协调；hitpause 计时集成 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-CAC-001 | parry_succeeded(type) → COUNTER_WINDOW_OPEN；window_timer = base_counter_window[type] | ADR-0001 ✅ |
| TR-CAC-002 | base_counter_window[type]（1.0/1.5/2.0s）存储与注入 | ⚠️ PARTIAL — GAP-02 |
| TR-CAC-003 | counter_base_damage（20）+ multiplier[n]（0.8/1.1/1.6）注入来源 | ⚠️ PARTIAL — GAP-02 |
| TR-CAC-004 | hit_animation_duration 冷却协调（≤0.307s 可行性约束） | ADR-0005 ✅ |
| TR-CAC-005 | counter_full_combo_completed 信号 + bonus_stagger 入口 | ADR-0001 + ADR-0005 ✅ |
| TR-CAC-006 | bonus_ratio（0.5，安全范围 [0.4, 0.8]）存储位置 | ⚠️ PARTIAL — GAP-02 |
| TR-CAC-007 | stagger_ended 是唯一发出者；boss_defeated/player_died 时不发出 | ADR-0001 ✅ |
| TR-CAC-008 | counter_window_updated(hit_count, time_remaining, state) 每物理帧 | ADR-0001 ✅ |
| TR-CAC-009 | apply_damage(BOSS, hit_damage) 每击调用 | ADR-0001 ✅ |
| TR-CAC-010 | boss_defeated → IDLE，不发出 stagger_ended | ADR-0001 ✅ |
| TR-CAC-011 | player_died → IDLE，不发出 stagger_ended | ADR-0001 ✅ |
| TR-CAC-012 | 加载时校验：hit_animation_duration 超限 → clamp；bonus_ratio 超限 → clamp | GDD load-time clamp ✅ |
| TR-CAC-013 | parry_succeeded 被丢弃（当已在 COUNTER_WINDOW_OPEN 时）+ warning | ADR-0001 ✅ |

**⚠️ GAP-02（TR-CAC-002/003/006）**: counter_base_damage、multiplier[n]、base_counter_window[type]、bonus_ratio 的具体存储和注入架构（@export 全局 vs AttackData 扩展 vs 独立 Resource）未由任何 ADR 定义。相关 story 在 S002-I02（GAP-02 解决）前保持 Blocked。

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria (AC-01 to AC-16) from `design/gdd/counter-attack-combo.md` are verified
- Unit tests exist at `game/tests/unit/counter_attack_combo/` — Logic story gate: BLOCKING
- `stagger_ended` sole-emitter invariant verified via grep (no other `.gd` file calls `stagger_ended.emit()` except counter_attack_combo_system.gd)
- `reset_for_retry(ctx)` implemented: combo_state=IDLE, hit_count=0, timers=0.0 (ADR-0003)

## Next Step

Run `/create-stories counter-attack-combo` to break this epic into implementable stories.

> **Dependency**: Resolve S002-I02 (GAP-02) before creating or starting stories for parameter injection pattern (TR-CAC-002/003/006).
> **Ordering**: Must implement after ParryTelegraphSystem (consumes `parry_succeeded`).
