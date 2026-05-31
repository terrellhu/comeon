# Systems Index: 刃响 (Blade Echo)

> **Status**: Draft
> **Created**: 2026-05-31
> **Last Updated**: 2026-05-31
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

刃响是一款 2D Boss Rush 动作游戏，核心机制是"视觉预警格挡→反击连段"循环。游戏无开放地图、无随机生成，Boss 设计完全精确——这意味着系统数量少但设计密度高。每个系统都服务于同一个核心问题：「如何让玩家在学会读懂一个神明的攻击语言时获得满足感？」

MVP 系统集中在战斗核心循环验证（单 Boss 格挡手感）；垂直切片扩展至完整战斗选项和叙事呈现；Alpha 阶段加入跨会话持久化和横向进阶。

---

## Systems Enumeration

| # | 系统名称 | 分类 | 优先级 | 状态 | 设计文档 | 依赖 |
|---|----------|------|--------|------|----------|------|
| 1 | 伤害/生命系统 | Core | MVP | Designed | design/gdd/health-damage-system.md | 无 |
| 2 | 玩家角色控制系统 | Core | MVP | Designed | design/gdd/player-controller-system.md | 设置/无障碍系统、反击连段 |
| 3 | 格挡/预警系统 | Gameplay | MVP | Designed | design/gdd/parry-telegraph-system.md | 玩家角色控制、伤害/生命、音频 |
| 4 | Boss 状态机系统 | Gameplay | MVP | Designed | design/gdd/boss-state-machine.md | 伤害/生命、格挡/预警（词汇表） |
| 5 | 反击连段系统 | Gameplay | MVP | Designed | design/gdd/counter-attack-combo.md | 格挡/预警、伤害/生命、玩家角色控制 |
| 6 | 即时重试系统 | Core | MVP | Designed | design/gdd/instant-retry-system.md | 伤害/生命、存档系统 |
| 7 | HUD 系统 | UI | MVP | Designed | design/gdd/hud-system.md | 伤害/生命、Boss 状态机、格挡/预警、反击连段、即时重试（信号预留） |
| 8 | 闪避系统 | Gameplay | 垂直切片 | Not Started | — | 玩家角色控制、伤害/生命 |
| 9 | Boss 节奏模式系统 (inferred) | Gameplay | 垂直切片 | Not Started | — | Boss 状态机 |
| 10 | 治疗系统 | Gameplay | 垂直切片 | Not Started | — | 伤害/生命、玩家角色控制 |
| 11 | 叙事解锁系统 | Narrative | 垂直切片 | Not Started | — | Boss 状态机、存档 |
| 12 | 音频系统 (inferred) | Audio | 垂直切片 | Not Started | — | 无（服务层） |
| 13 | 存档系统 | Persistence | Alpha | Not Started | — | 无 |
| 14 | 进阶/能力系统 | Progression | Alpha | Not Started | — | 格挡/预警、反击连段、存档 |
| 15 | 设置/无障碍系统 (inferred) | Meta | Alpha | Not Started | — | 无 |

---

## Categories

| 分类 | 描述 |
|------|------|
| **Core** | 基础系统，其他系统依赖于此 |
| **Gameplay** | 产生游戏乐趣的玩法系统（格挡、Boss、战斗） |
| **Progression** | 玩家随时间成长的方式（横向解锁，非数值碾压） |
| **Persistence** | 存档与跨会话持久化 |
| **UI** | 玩家信息显示（HUD、菜单） |
| **Audio** | 音乐与音效系统 |
| **Narrative** | 叙事呈现与故事解锁 |
| **Meta** | 游戏循环外的系统（无障碍、设置） |

---

## Priority Tiers

| 级别 | 定义 | 目标里程碑 |
|------|------|------------|
| **MVP** | 核心循环运转所必需。没有这些，无法测试"好不好玩" | 第一个可玩原型 |
| **垂直切片** | 完整体验演示所必需。3 个 Boss + 简化叙事 | 垂直切片 Demo |
| **Alpha** | 所有功能粗糙版本存在。完整机制范围，占位内容可接受 | Alpha 里程碑 |
| **Full Vision** | 打磨、边缘案例、内容完整 | Beta / 发布 |

---

## Dependency Map

### Foundation Layer（无依赖——最先设计）

1. **存档系统** — 持久化合约：定义什么数据跨会话存在，其他系统才知道如何存储状态
2. **音频系统** — 服务层：定义音效事件词汇表和音乐层架构，其他系统引用事件名称而非实现
3. **设置/无障碍系统** — 基础配置层：控制重映射、音量等；玩家角色控制依赖其输入定义

### Core Layer（依赖 Foundation）

4. **伤害/生命系统** — 依赖：存档（HP 持久化）| 所有战斗系统的数学基础：HP 公式、伤害计算、死亡条件
5. **玩家角色控制系统** — 依赖：设置（控制映射）| 定义玩家在世界中能做什么：移动、输入动作、基础状态机

### Core Gameplay Layer（依赖 Core）

6. **格挡/预警系统** — 依赖：玩家角色控制、伤害/生命、音频 | **THE 核心机制**；首先设计，定义预警事件词汇表作为两个系统的共享契约
7. **闪避系统** — 依赖：玩家角色控制、伤害/生命 | "格挡 or 闪避"决策的另一半
8. **Boss 状态机系统** — 依赖：伤害/生命、格挡/预警（词汇表）| 引用格挡/预警 GDD 的事件词汇表；通过信号解耦避免循环依赖

### Feature Layer（依赖 Core Gameplay）

9. **反击连段系统** — 依赖：格挡/预警、伤害/生命 | 格挡成功后发生什么，完成 30 秒循环
10. **Boss 节奏模式系统** — 依赖：Boss 状态机 | 多 Boss 时的节奏差异设计规则
11. **即时重试系统** — 依赖：伤害/生命、存档 | 死亡后 3 秒内重新开始，无惩罚
12. **治疗系统** — 依赖：伤害/生命、玩家角色控制 | 失败路径的资源管理
13. **叙事解锁系统** — 依赖：Boss 状态机、存档 | Boss 击败后触发 HD 插画 + 文字

### Presentation Layer（包装游戏玩法）

14. **HUD 系统** — 依赖：伤害/生命、Boss 状态机、格挡/预警 | "读懂才能赢"的 UI 基础：Boss 血条阶段标记、格挡窗口可视化

### Polish Layer（依赖所有系统）

15. **进阶/能力系统** — 依赖：格挡/预警、反击连段、存档 | 横向解锁：新格挡技巧、反击连段扩展

---

## Recommended Design Order

| 顺序 | 系统 | 优先级 | 层级 | 工作量 |
|------|------|--------|------|--------|
| ① | 伤害/生命系统 | MVP | Core | S |
| ② | 玩家角色控制系统 | MVP | Core | M |
| ③ | **格挡/预警系统** | MVP | Core Gameplay | L（最关键 GDD） |
| ④ | Boss 状态机系统 | MVP | Core Gameplay | L |
| ⑤ | 反击连段系统 | MVP | Feature | M |
| ⑥ | 即时重试系统 | MVP | Feature | S |
| ⑦ | HUD 系统 | MVP | Presentation | M |
| —— | ▶ MVP 截止 ——————————————————— | | | |
| ⑧ | 闪避系统 | 垂直切片 | Core Gameplay | M |
| ⑨ | Boss 节奏模式系统 | 垂直切片 | Feature | M |
| ⑩ | 治疗系统 | 垂直切片 | Feature | S |
| ⑪ | 叙事解锁系统 | 垂直切片 | Feature | M |
| ⑫ | 音频系统 | 垂直切片 | Foundation | M |
| —— | ▶ 垂直切片截止 ————————————————— | | | |
| ⑬ | 存档系统 | Alpha | Foundation | M |
| ⑭ | 进阶/能力系统 | Alpha | Polish | L |
| ⑮ | 设置/无障碍系统 | Alpha | Foundation | S |

*工作量：S = 1 次会话，M = 2-3 次会话，L = 4+ 次会话（每次会话产出一份完整 GDD）*

---

## Circular Dependencies

- **格挡/预警系统 ↔ Boss 状态机系统**
  - 循环原因：格挡系统需要知道"Boss 发出的预警事件格式"；Boss 状态机需要知道"格挡系统期望的信号规范"
  - **解决方案**：**格挡/预警系统 GDD 首先定义"预警事件词汇表"**（telegraph event vocabulary），作为两个系统的共享契约。Boss 状态机 GDD 引用此词汇表。Godot 实现中通过信号解耦：Boss 发出 `attack_telegraphed(type, duration)`，格挡系统订阅，无代码循环依赖。
  - **设计行动**：在格挡/预警 GDD 的"Detailed Rules"节中完整定义词汇表，然后在 Boss 状态机 GDD 中引用。

---

## High-Risk Systems

| 系统 | 风险类型 | 风险描述 | 缓解方案 |
|------|----------|----------|----------|
| **格挡/预警系统** | 设计风险 | 时机窗口宽度是整个游戏最难的设计参数——太宽=无挑战，太窄=挫败感 | 原型已验证（TELEGRAPH=1.0s, WINDOW=0.35s）；GDD 使用这些值作为基线调校旋钮 |
| **Boss 状态机系统** | 技术风险 | 多阶段 Boss + 视觉预警系统的状态机复杂度；错误的架构早期很难重构 | 垂直切片前进行架构审查（ADR）；先设计数据结构再写代码 |
| **进阶/能力系统** | 范围风险 | "横向扩展"边界模糊——能力太少无意义，太多破坏"读懂才能赢" | 等 MVP 循环稳定后再设计；仅解锁"新格挡动作读取方式"，不提升基础数值 |
| **叙事解锁系统** | 成本风险 | 每个 Boss 的 HD 插画+文字内容是最大美术成本项之一 | MVP 完全跳过；垂直切片用占位插画验证系统架构 |

---

## Progress Tracker

| 指标 | 数量 |
|------|------|
| 已识别系统总数 | 15 |
| GDD 已开始 | 7 |
| GDD 已审查 | 0 |
| GDD 已批准 | 0 |
| MVP 系统已设计 | 7 / 7 |
| 垂直切片系统已设计 | 0 / 5 |

---

## Next Steps

- [ ] 按设计顺序逐系统运行 `/design-system [系统名]`
- [ ] 从 ① 伤害/生命系统开始（最小、最快，解锁所有后续 GDD）
- [ ] 每完成一份 GDD 后运行 `/design-review design/gdd/[系统].md`
- [ ] MVP 7 个系统全部完成后运行 `/gate-check pre-production`
- [ ] 进入垂直切片前运行 `/architecture-review` 建立需求可追溯矩阵
