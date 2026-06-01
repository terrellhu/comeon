# Smoke Test: Critical Paths — 刃响 (Blade Echo)

**Purpose**: Run these checks (< 15 minutes) before any QA hand-off.
**Run via**: `/smoke-check` (reads this file)
**Update**: Add entries when new core systems are implemented.

---

## Core Stability (always run)

1. 项目在 Godot 4.6 中无报错打开
2. 游戏场景启动不崩溃（占位美术）
3. 玩家角色出现在战场起始位置

## 核心战斗循环 (update per sprint)

4. Boss 发出攻击预警 → 玩家看到发光效果（视觉确认）
5. 格挡成功 → Boss 进入硬直动画
6. 反击连段 → Boss HP 减少（HUD 血条更新）
7. 玩家 HP 归零 → 死亡屏幕序列播放（1.5s）
8. 死亡屏幕结束 → 玩家满 HP 复活，Boss HP 保留

## 数据完整性

9. Boss 血量在多次重试中持久化（死亡前 X → 重试后仍为 X）
10. Boss 阶段转换时 HUD 阶段标记变化正确

## 性能

11. 战斗中 60fps 稳定（Godot Profiler 检查）
12. 5 分钟持续战斗无明显内存增长

---

*最后更新*: 2026-06-01（Technical Setup 阶段 — 战斗系统未实现，条目 4-12 待 MVP sprint 完成后验证）
