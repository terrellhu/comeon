# Epic: BossStateMachine

> **Layer**: Feature
> **GDD**: design/gdd/boss-state-machine.md
> **Architecture Module**: BossStateMachine
> **Status**: Ready
> **Stories**: 5 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|---|---|---|---|
| 001 | BSM Skeleton + IDLE/TELEGRAPHING/ATTACKING Main Path | Logic | Ready | ADR-0004, ADR-0005 |
| 002 | STAGGERED + Sequence Index Formula | Logic | Ready | ADR-0004, ADR-0001 |
| 003 | DEFEATED Terminal State + BossData Injection | Logic | Ready | ADR-0004, ADR-0002 |
| 004 | Boss Phase Transitions (4 Source State Paths) | Logic | Ready | ADR-0004, ADR-0001 |
| 005 | Data Validation + reset_for_retry | Logic | Ready | ADR-0002, ADR-0003 |

## Overview

BossStateMachine 是每个 Boss 战斗的"意志"。系统实现一个多层状态机（相位层 → 行为状态层 → 序列索引层），由 BossData Resource（PhaseData[] + AttackData[]）完全驱动——所有 Boss 共享同一代码，通过数据资产区分行为。行为状态包括 IDLE、TELEGRAPHING、ATTACKING、STAGGERED、PHASE_TRANSITION、DEFEATED。序列索引按公式 `(current + 1) mod N` 循环推进；攻击预警时长由公式 2 决定（覆盖值优先，否则用 AttackType 全局默认值）。ATTACKING → IDLE 转换由 `AnimationPlayer.animation_finished` 信号驱动（ADR-0005 确认）。Boss 永不直接修改 HP——它发出 `attack_telegraphed`，收到 `boss_phase_changed` 后转换阶段，收到 `boss_defeated` 后进入 TERMINAL 状态。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Signal Routing Architecture | EventBus 全局总线；attack_telegraphed 发出顺序 | LOW |
| ADR-0002: BossData Resource Architecture | BossData/PhaseData/AttackData Resource 子类；_validate 加载校验 | LOW |
| ADR-0004: Player State Machine Architecture | _transition_to 模式；enum BehaviorState；无字典状态跳转 | LOW |
| ADR-0005: Animation-to-Code Boundary | animation_finished 信号驱动 ATTACKING→IDLE；StringName 动画常量 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-BSM-001 | 多层状态机：相位/行为/序列 | ADR-0004 ✅ |
| TR-BSM-002 | BossData Resource 驱动；所有 Boss 共享一个状态机 | ADR-0002 ✅ |
| TR-BSM-003 | PhaseData + AttackData 结构 | ADR-0002 ✅ |
| TR-BSM-004 | enum BehaviorState；_transition_to 模式 | ADR-0004 ✅ |
| TR-BSM-005 | CONNECT_ONE_SHOT on animation_finished；DEFEATED 无退出 | ADR-0005 ✅ |
| TR-BSM-006 | attack_telegraphed 发出顺序（信号先于 timer 启动） | ADR-0001 ✅ |
| TR-BSM-007 | STAGGERED 进入（parry_succeeded）；stagger_ended 退出 | ADR-0004 ✅ |
| TR-BSM-008 | ATTACKING→IDLE 由 animation_finished 驱动（非独立计时器） | ADR-0005 ✅ |
| TR-BSM-009 | BossData Resource 加载时 _validate（空序列 assert；threshold 单调性验证） | ADR-0002 ✅ |
| TR-BSM-010 | animation_finished StringName 常量；AnimationPlayer API | ADR-0005 ✅ |
| TR-BSM-011 | 序列索引公式：next = (current + 1) mod N | ADR-0004 ✅ |
| TR-BSM-012 | attack_telegraphed 信号解耦（不直接通知格挡系统） | ADR-0001 ✅ |

**全部 12/12 TR-IDs 均有 ADR 覆蓋。此 epic 立即可開始實現。**

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria (AC-01 to AC-24) from `design/gdd/boss-state-machine.md` are verified
- Unit tests exist at `game/tests/unit/boss_state_machine/` — Logic story gate: BLOCKING
- AC-04/AC-16（animation_finished 触发机制）pending note 已解决（确认 ADR-0005 决策：animation_finished 信号驱动 ATTACKING→IDLE）
- Code review: `boss_state_machine.gd` 无字面量 `0.8`、`1.2`、`1.5`（Code Review AC）
- `reset_for_retry(ctx)` 已实现（ADR-0003 合约：phase_index = ctx["boss_phase"]，sequence_index=0，timers cleared）

## Next Step

Run `/create-stories boss-state-machine` to break this epic into implementable stories.

> **No blockers** — this epic is the first Feature system to implement (Day 2 of Sprint 002 plan).
