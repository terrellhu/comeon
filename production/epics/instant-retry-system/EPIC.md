# Epic: InstantRetrySystem

> **Layer**: Feature
> **GDD**: design/gdd/instant-retry-system.md
> **Architecture Module**: InstantRetrySystem
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories instant-retry-system`

## Overview

InstantRetrySystem 监听 `player_died` 信号，在 Art Bible Section 7.5 定义的 1.5 秒死亡屏幕序列（RED_FLASH → FADE_TO_GREY → PHASE_SYMBOL → SYMBOL_FADE_OUT）后自动将玩家重置至战斗起始状态。玩家可在序列任意帧按键跳过。系统使用 `SceneTree.paused = true` 冻结游戏逻辑，自身以 `PROCESS_MODE_ALWAYS` 继续运行播放动画和检测跳过输入。重置采用 in-place 策略（ADR-0003）：按依赖顺序调用各系统的 `reset_for_retry(ctx)` 方法，RetryContext 从 Autoload 中读取保留的 Boss HP 和阶段。玩家以满 HP + 2.0s 无敌期重生，Boss HP 保留为玩家死亡时的值。收到 `boss_defeated` 时调用 `RetryContext.clear_context()`，下次战斗从满 Boss HP 开始。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Signal Routing Architecture | player_died/boss_defeated 路由；retry_death_count_changed | LOW |
| ADR-0002: BossData Resource Architecture | phase_symbol 来自 PhaseData；Boss 数据注入 | LOW |
| ADR-0003: RetryContext and Scene Reset Strategy | In-place reset；RetryContext Autoload；reset_for_retry(ctx) 接口 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-IRS-001 | 订阅 player_died → DYING + SceneTree.paused=true | ADR-0001 ✅ |
| TR-IRS-002 | phase_symbol 来自 PhaseData.phase_index（Boss 相位符号展示） | ADR-0002 ✅ |
| TR-IRS-003 | SceneTree.paused=true 期间游戏逻辑时间冻结；死亡屏幕 PROCESS_MODE_ALWAYS | ADR-0003 ✅ |
| TR-IRS-004 | 任意键立即跳过死亡屏幕（CONFLICT-01：ADR-0003 200ms guard vs GDD AC-03） | ADR-0003 ❌ CONFLICT-01 |
| TR-IRS-005 | RetryContext.save_context(boss_hp, boss_phase, death_count+1) | ADR-0003 ✅ |
| TR-IRS-006 | in-place reset ≤ 1.5s（Art Bible 7.5 硬约束） | ADR-0003 ✅ |
| TR-IRS-007 | 玩家重生 HP = player_max_hp | ADR-0003 ✅ |
| TR-IRS-008 | 重生后 Boss HP = RetryContext.preserved_boss_hp（非满血重置） | ADR-0003 ✅ |
| TR-IRS-009 | Boss 状态机 reset_for_retry → IDLE（依赖 BossStateMachine 实现） | ADR-0003 ✅ |
| TR-IRS-010 | boss_defeated → RetryContext.clear_context() | ADR-0003 ✅ |
| TR-IRS-011 | session_death_count++ + retry_death_count_changed(count) | ADR-0001 ✅ |
| TR-IRS-012 | 死亡屏幕 4 阶段时长（0.2+0.4+0.6+0.3=1.5s，各阶段 ±16.6ms）| Art Bible 7.5 ✅ |
| TR-IRS-013 | boss_defeated + player_died 同帧：boss_defeated 优先（玩家胜利） | ADR-0001 ✅ |
| TR-IRS-014 | 死亡屏幕期间无 UI 元素（NO UI rule，Art Bible 7.5） | Art Bible 7.5 ✅ |
| TR-IRS-015 | 重试无敌 2.0s = RETRY_INVULN_BASE > player_hit_invuln_duration(0.5s) | GDD Formula 1 ✅ |

**❌ CONFLICT-01（TR-IRS-004）**: ADR-0003 的风险缓解方案（200ms 跳过黑名单）与 GDD AC-03「序列任意帧可跳过」直接冲突。此冲突必须在 S002-I01 中通过修订 ADR-0003 或 GDD 解决。所有 InstantRetrySystem story **BLOCKED** 直到 CONFLICT-01 解决。

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria (AC-01 to AC-08+) from `design/gdd/instant-retry-system.md` are verified
- Integration tests exist at `game/tests/integration/instant_retry_system/` — Integration story gate: BLOCKING
- AC-02（死亡屏幕 4 阶段时长）由 native build 测试验证（GUT headless 受 SceneTree.paused 影响）
- AC-03（skip 任意帧）由 CONFLICT-01 解决后的明确定义验证
- Reset sequence verified: all 5 systems' `reset_for_retry()` called in dependency order (HealthDamageSystem → PlayerController → BossStateMachine → ParryTelegraphSystem → CounterAttackComboSystem)

## Dependencies

| 依赖 | 方向 | 说明 |
|---|---|---|
| CONFLICT-01 解决 | 必须先 | 所有 story 被 Blocked 直到 S002-I01 完成 |
| HealthDamageSystem | 必须完成 | reset_for_retry ✅（Sprint 001 done） |
| PlayerController | 必须完成 | reset_for_retry ✅（Sprint 001 done，pc-attack-retry story） |
| BossStateMachine | 必须完成 | reset_for_retry 需在此 epic 中实现 |
| ParryTelegraphSystem | 必须完成 | reset_for_retry 需在此 epic 中实现 |
| CounterAttackComboSystem | 必须完成 | reset_for_retry 需在此 epic 中实现 |

## Next Step

Run `/create-stories instant-retry-system` to break this epic into implementable stories.

> **BLOCKED**: Do not start until S002-I01 resolves CONFLICT-01. This is the last Feature system to implement.
