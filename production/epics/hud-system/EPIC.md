# Epic: HUDSystem

> **Layer**: Feature (Presentation)
> **GDD**: design/gdd/hud-system.md
> **Architecture Module**: HUDSystem
> **Status**: Ready
> **Stories**: Not yet created — see story files in this directory

## Overview

HUDSystem 是刃响战斗循环的「视觉基础设施」。系统由 4 组独立 HUD 元素组成，通过 CanvasLayer 渲染：**玩家 HP 段数条**（5 段式，订阅 `player_hp_changed`）、**Boss HP 连续血条**（含阶段分隔线，订阅 `boss_hp_changed`）、**预警进度条**（订阅 `telegraph_updated` 每帧，三色态）、**反击窗口计时条 + 连击计数器**（订阅 `counter_window_updated` 每帧）。系统是纯订阅者——不向任何系统发出信号，不修改游戏逻辑状态。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|---|---|---|
| ADR-0001: Signal Routing Architecture | EventBus 全局总线；HUD 只订阅不发出信号 | LOW |
| ADR-0003: RetryContext and Scene Reset | reset_for_retry(ctx) 接口；HUD pass 即可 | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|---|---|---|
| TR-HUD-001 | player_hp_changed → 5 段显示（ceil formula） | ADR-0001 ✅ |
| TR-HUD-002 | HP 临界（1 段）0.5 Hz 闪烁 | ADR-0001 ✅ |
| TR-HUD-003 | boss_hp_changed → fill_ratio = current/max | ADR-0001 ✅ |
| TR-HUD-004 | 阶段分隔线位置由 phase_threshold_pct 静态渲染 | ADR-0002 ✅ |
| TR-HUD-005 | telegraph_updated → 三态颜色切换（PRE/OPEN/POST） | ADR-0001 ✅ |
| TR-HUD-006 | 无活跃预警时进度条隐藏 | ADR-0001 ✅ |
| TR-HUD-007 | counter_window_updated → 时间条填充 + 状态颜色（青/金） | ADR-0001 ✅ |
| TR-HUD-008 | 反击条跟随玩家世界坐标（CanvasLayer 坐标转换）| ⚠️ PARTIAL — GAP-03 OPEN |
| TR-HUD-009 | FULL COMBO 闪烁文字 0.5s | ADR-0001 ✅ |
| TR-HUD-010 | reset_for_retry → 重新渲染初始状态 | ADR-0003 ✅ |
| TR-HUD-011 | boss_defeated → 停止响应流数据信号 | ADR-0001 ✅ |

**⚠️ GAP-03（TR-HUD-008）**: 反击条世界坐标跟随（CanvasLayer 屏幕坐标转换 vs Node2D 游戏世界层）待架构决策。MVP 实现：将反击条固定在屏幕角落，届时升级。

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All automated ACs pass in GUT headless
- Visual ACs (颜色、动画) documented in `production/qa/evidence/hud-visual-[date].md`
- HUDSystem never emits signals (grep: `EventBus.*emit` returns 0 in hud_system.gd)
- `reset_for_retry(ctx)` implemented (pass is valid — HUD re-renders via signals after resume)

## Story Overview

| Story | Title | Type | ACs |
|---|---|---|---|
| 001 | HP Bars — Player Segments + Boss Fill | UI | AC-HUD-01 to 09 |
| 002 | Telegraph Progress Bar | UI | AC-HUD-10 to 14 |
| 003 | Counter Window HUD | UI | AC-HUD-15 to 22 |
| 004 | Boss Defeated Guard + reset_for_retry | Integration | AC-HUD-23 |
