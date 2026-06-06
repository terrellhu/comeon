# Epic: ParryTelegraphSystem

> **Layer**: Feature
> **GDD**: design/gdd/parry-telegraph-system.md
> **Architecture Module**: ParryTelegraphSystem
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories parry-telegraph-system`

## Overview

ParryTelegraphSystem 是刃响战斗循环的核心仲裁者。它消费 `attack_telegraphed(type, damage)` 信号，根据公式 1–3（窗口时机计算、进度追踪、格挡成功判定）判断玩家输入是否在有效格挡窗口内，并驱动三条路径（A = 成功、B = 失败、C = 空格挡）。成功时发出 `parry_succeeded(type)` + `exit_parry_state(dur)`；失败时调用 `apply_damage(PLAYER, damage)` + `parry_failed(type)`；每物理帧发出 `telegraph_updated(progress, window_open, type)` 供 HUD 订阅。系统不拥有 STAGGERING 状态——格挡成功后直接返回 IDLE，Boss 硬直生命周期由 CounterAttackComboSystem 全权管理。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Signal Routing Architecture | EventBus 全局总线；依赖注入 initialize(mock) 模式 | LOW |
| ADR-0002: BossData Resource Architecture | AttackData 承载 telegraph_duration_override；Boss 数据注入，非字面量 | LOW |
| ADR-0005: Animation-to-Code Boundary | CONNECT_ONE_SHOT 模式；_transition_to 模式 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-PTS-001 | Consumes attack_telegraphed; IDLE → TELEGRAPHING | ADR-0001 ✅ |
| TR-PTS-002 | LIGHT/HEAVY/SWEEP 默认时长（0.8/1.2/1.5s）、窗口宽度、硬直时长 | ADR-0001 ✅ |
| TR-PTS-003 | window_open_time = duration × fraction；window_close_time = open + width | ADR-0001 ✅ |
| TR-PTS-004 | 格挡成功：TELEGRAPHING AND open ≤ timer ≤ close（闭区间） | ADR-0001 ✅ |
| TR-PTS-005 | 路径 A：parry_succeeded + exit_parry_state；不调用 apply_damage | ADR-0001 ✅ |
| TR-PTS-006 | 路径 B：telegraph 超时 → apply_damage(PLAYER) + parry_failed | ADR-0001 ✅ |
| TR-PTS-007 | parry_failed(attack_type) 发出 | ADR-0001 ✅ |
| TR-PTS-008 | 每次 parry_input_pressed 发出 exit_parry_state(dur) | ADR-0001 ✅ |
| TR-PTS-009 | telegraph_updated(progress, window_open, type) 每物理帧广播 | ADR-0001 ✅ |
| TR-PTS-010 | STAGGERING 移除；生命周期转移至 CounterAttackComboSystem | ADR-0001 ✅ |
| TR-PTS-011 | 全部时序值通过注入，不用字面量；Boss 数据可覆盖每项参数 | ADR-0002 ⚠️ PARTIAL — GAP-02 |
| TR-PTS-012 | 第二个 attack_telegraphed 被丢弃 + warning | ADR-0001 ✅ |
| TR-PTS-013 | player_died / boss_defeated → 立即 IDLE，不调用 apply_damage | ADR-0001 ✅ |
| TR-PTS-014 | 路径 A 信号到输出延迟 ≤ 0.5ms | ADR-0001 ✅ |

**⚠️ GAP-02（TR-PTS-011）**: window_open_fraction、window_width 等调参参数存储位置（全局 @export vs AttackData 覆盖）尚未由任何 ADR 定义。相关 story 在 S002-I02（GAP-02 解决）前保持 Blocked。

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria (AC-01 to AC-24) from `design/gdd/parry-telegraph-system.md` are verified
- Unit tests exist at `game/tests/unit/parry_system/` — Logic story gate: BLOCKING
- AC-22（性能延迟 ≤ 0.5ms）由 Godot Profiler 验证（pending — native build needed）
- AC-23（字面量 grep）通过 code review 验证

## Next Step

Run `/create-stories parry-telegraph-system` to break this epic into implementable stories.

> **Dependency**: Resolve S002-I02 (GAP-02) before creating stories that depend on TR-PTS-011 parameter injection pattern.
