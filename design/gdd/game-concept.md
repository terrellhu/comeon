# Game Concept: 刃响 (Blade Echo)

*Created: 2026-05-30*
*Status: Draft*

---

## Elevator Pitch

> 一款 HD 成人美学 2D Boss Rush 动作游戏——每个堕落神明是一首独特的乐曲，视觉预警是乐谱，格挡是你的演奏。在华丽的黑暗神话世界中，用完美的反击击败可怕的神明。
>
> *It's a 2D boss-rush action game where you learn and exploit the visual rhythm of fallen deities — each boss fight is a different song to master, presented through HD adult illustration aesthetics.*

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 2D Action / Boss Rush（银河恶魔城影响） |
| **Platform** | PC (Steam) |
| **Target Audience** | 18-35 岁中核/硬核动作玩家，Hollow Knight / 魂系受众 |
| **Player Count** | 单人 |
| **Session Length** | 30-60 分钟 |
| **Monetization** | 买断制 (Premium) |
| **Estimated Scope** | Large (18–24 months, solo) |
| **Comparable Titles** | Hollow Knight, Furi, Blasphemous |

---

## Core Fantasy

你是完美的反击者。每个堕落神明都有自己的攻击语言——独特的动作预兆、发光模式、节奏感——而你的工作是读懂它，然后摧毁它。

不靠更高的数值，不靠更快的反应，靠**理解**。当你第一次无伤完成一个曾经杀死你二十次的神明，那种胜利感不是来自力量，是来自智慧。

你也是一个见证者：这些神明曾经是多么强大、多么美丽——而你是送它们入土的最后一人。

---

## Unique Hook

> "像 Sekiro 的格挡系统 × 2D，AND ALSO 每个 Boss 都是有完整神话叙事的 HD 手绘堕落神明——攻击预警本身就是视觉艺术。"

竞争对手的区别：
- vs Hollow Knight：我们是 Boss-focused，不做开放大地图；HD 成人美学代替像素风
- vs Furi：我们有更深的神话叙事锚定，且视觉预警系统是核心机制而非一般动作
- vs Blasphemous：我们的战斗节奏是节奏共鸣型（Rhythmic）而非惩罚型；更清晰的视觉语言

---

## Visual Identity Anchor

**方向名：「暗神话辉煌」*(Dark Mythic Grandeur)***

**视觉规则**：每一帧画面都应该像是一幅腐化神明的手绘宗教图标——华美、沉重、不妥协。

| 视觉原则 | 定义 | 设计测试 |
| ---- | ---- | ---- |
| **攻击预警即艺术** | 发光、光晕、身体语言既是机制，也是美学 | 如果预警效果不好看，就重新设计，直到它既清晰又美 |
| **成熟 ≠ 低俗** | 成人美学意味着不妥协的、面向成年人的视觉决策 | 如果内容让人觉得廉价或哗众取宠，删掉 |
| **剪影即叙事** | 每个 Boss 的轮廓在第一眼就讲述它的故事 | 将 Boss 剪影给陌生人看：他们能猜出这是什么神明吗？ |

**色彩哲学**：深沉饱和的宝石色背景（深靛蓝、暗紫、深墨绿），配合高对比度霓虹/白色发光作为攻击预警。黑暗底色让色彩爆发更有冲击力。成人内容的视觉呈现需精心设计，不以暴露换取注意。

*此部分为 Art Bible 的种子——在 `/art-bible` 中展开。*

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 3 | HD 视觉美学、格挡音效/光效、反击流畅动画 |
| **Fantasy** (make-believe) | 2 | 扮演能击败神明的人；身处暗神话世界 |
| **Narrative** (drama, story) | 4 | 击败 Boss 后解锁叙事碎片；神明的堕落故事 |
| **Challenge** (mastery) | 1 | 视觉预警 + 格挡时机；Boss 多阶段学习曲线 |
| **Fellowship** | N/A | 无多人 |
| **Discovery** (exploration) | 5 | 解锁 Boss 神话背景；发现新攻击模式 |
| **Expression** | N/A | 无创作工具 |
| **Submission** (relaxation) | N/A | 非放松游戏 |

### Key Dynamics (Emergent player behaviors)

- 玩家会开始"解读"Boss 的视觉语言，形成自己的分类和记忆方法
- 玩家会反复挑战同一个 Boss 以追求完美（无伤、最快速度）
- 玩家会因为 Boss 的美术和故事而产生情感依附，在击败时感到一丝悲哀

### Core Mechanics (Systems we build)

1. **视觉预警格挡系统** — Boss 攻击前有清晰的视觉预兆（发光/形态变化），玩家在窗口期格挡触发反击
2. **Boss 节奏模式设计** — 每个 Boss 有独特的攻击节奏序列和多阶段进化
3. **反击连段系统** — 成功格挡后开启时限反击窗口，连段质量影响 Boss 硬直时间
4. **叙事解锁系统** — Boss 被击败后触发短片/图文，揭示神明的历史与堕落故事

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, choice) | 选择挑战顺序；选择技能树路线；自由调整战斗风格 | Supporting |
| **Competence** (mastery) | 从"看不懂预警"到"完美格挡"的可见成长弧；无伤成就感 | **Core** |
| **Relatedness** (connection) | 通过 HD 叙事对 Boss 产生情感连接；击杀时有复杂情绪 | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — 击败所有 Boss、解锁全部叙事、达成无伤成就
- [x] **Explorers** — 发现 Boss 模式、解读视觉语言、探索神话叙事
- [ ] **Socializers** — 无多人元素（社区分享是次级行为）
- [ ] **Killers/Competitors** — 速通排行榜是可能的次级功能，非核心

### Flow State Design

- **Onboarding curve**: 第一个 Boss 使用夸张的视觉预警 + 慢速节奏，教会玩家"看什么"；逐渐提高节奏密度
- **Difficulty scaling**: 每个 Boss 内在有多阶段升级；可选择先挑战哪个 Boss（难度软分层）
- **Feedback clarity**: 格挡成功特效、伤害数字、Boss 血条阶段标记、死亡计数器
- **Recovery from failure**: 即时重试，无读盘，无死亡掉落惩罚；每次死亡后保留学习记忆

---

## Core Loop

### Moment-to-Moment (30 seconds)

```
Boss 进入攻击前摇
→ 身体发光 / 形态变化（视觉预警激活）
→ 玩家判断：格挡 or 闪避
→ 成功格挡：华丽光效 + Boss 硬直 + 反击窗口开启
→ 玩家输出 2-4 连击
→ Boss 恢复，进入下一个攻击序列
失败路径：误判 → 承伤 → 治疗决策（消耗资源 or 忍受）→ 继续
```

**爽感来源**：视觉判断准确的智识满足感、格挡音效+特效的即时反馈、成功后感受到"我控制了这一刻"。

### Short-Term (5-15 minutes)

- 进入 Boss 战 → 观察第一阶段攻击序列（允许 1-3 次死亡作为学习）
- 开始连续格挡，感受节奏 → "再试一次"心理在此触发
- Boss 进入二阶段，新预警模式出现，循环重启于更高难度
- *"我差一点就到下一阶段了"* 是主要留存钩子

### Session-Level (30-60 minutes)

- 一次会话流程：挑战并击败 2-3 个 Boss（Boss Rush 结构）
- 自然停止点：Boss 被击败 → 叙事碎片解锁（HD 插画 + 文字）
- 离线钩子：期待下一个 Boss 的视觉设计；想验证自己学到的格挡时机

### Long-Term Progression

- **能力成长**：解锁新格挡技巧、反击连段、被动能力（横向扩展，非数值碾压）
- **知识成长**：随着 Boss 数量增加，玩家掌握的"神明语言"越来越丰富
- **叙事成长**：收集所有神明故事，拼凑完整的神界堕落叙事
- **完成感**：所有 Boss 无伤通关；解锁真结局（可选高难度目标）

### Retention Hooks

- **Curiosity**: 下一个 Boss 长什么样？它的神话故事是什么？
- **Investment**: 已经投入的学习时间；已解锁的叙事碎片
- **Mastery**: "我想无伤这个 Boss" / "能不能更快"

---

## Game Pillars

### Pillar 1: 读懂，才能赢 (Read to Win)
胜利来自视觉理解，而非手速或数值碾压。每个格挡机会都有足够清晰的视觉预警。

*设计测试*：如果在"更难的闪避"和"更清晰的预警配合更紧的时间窗"之间选择，选后者。

### Pillar 2: 每个神明都是一首歌 (Every Boss is a Song)
每个 Boss 有独特的视觉语言、攻击节奏和叙事背景。打完一个 Boss 就像听完一首完整的曲子。

*设计测试*：如果在"加入更多普通小怪关卡"和"把资源投入打磨 Boss 视觉/节奏/叙事"之间选择，选后者。

### Pillar 3: 画面即叙事 (Art is Story)
高清成人美学不是点缀——视觉上的每一帧都在讲述堕落神明的故事。玩家看画面就能理解世界。

*设计测试*：如果在"功能性占位图 + 更多机制"和"一帧精致的 HD 角色插画 + 成熟的视觉语言"之间选择，选后者（MVP 阶段也是）。

### Pillar 4: 失败是学习，不是惩罚 (Death is a Teacher)
死亡后快速复活，没有读盘，没有跑图惩罚。失败的代价是时间，不是挫败感。

*设计测试*：如果在"加入惩罚型魂系死亡掉落"和"快速重试+保留学习记忆"之间选择，选后者。

### Anti-Pillars (What This Game Is NOT)

- **NOT 开放式探索地图**: 会稀释"每个 Boss 都是精心设计的歌曲"。资源专注 Boss 设计，不做大地图。
- **NOT 数值碾压型成长**: 会破坏"读懂才能赢"。升级是能力扩展，不是 DPS 叠加让 Boss 变简单。
- **NOT 随机生成关卡**: 视觉预警系统依赖精确设计的攻击序列。随机化破坏节奏感和可学习性。

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hollow Knight | 精准操控手感、大气世界叙事、Boss 设计的情感深度 | Boss Rush 代替大地图；HD 成人美学代替像素风；更短更精的体验 | 证明 2D 动作+叙事深度的市场存在 |
| Bloodborne | 侵略性战斗节奏、哥特成熟美学、高压动作感 | 格挡节奏代替纯闪避；视觉清晰度高于混乱感；成人美学更精致 | 证明成人美学+高难度动作的受众规模 |
| Furi | 纯 Boss Rush 结构、每关一个 Boss 的设计密度 | 加入叙事深度和 HD 视觉叙事；视觉预警系统作为核心机制 | 证明 Boss-only 游戏有独立市场 |
| Blasphemous | 黑暗宗教神话美学、成熟内容的精致处理 | 节奏共鸣型战斗代替惩罚型；更清晰的视觉语言 | 证明宗教神话+成人美学在 Steam 的可行性 |

**Non-game inspirations**:
- 日本浮世绘与宗教画（视觉构图参考）
- 北欧/中东神话体系（叙事原料）
- 传统手绘动画（角色动作设计参考：Princess Mononoke, Arcane）

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-35 岁 |
| **Gaming experience** | 中核到硬核 |
| **Time availability** | 工作日 30-60 分钟，周末可能更长；喜欢"一场战斗"作为完整体验 |
| **Platform preference** | PC |
| **Current games they play** | Hollow Knight, Elden Ring, Blasphemous, Furi |
| **What they're looking for** | 精准战斗满足感 + 有重量感的成人视觉叙事；不喜欢像素风但喜欢精致独立游戏 |
| **What would turn them away** | 死亡惩罚过重、视觉预警不清晰、美术风格低质量或低幼 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6 — 2D 能力强，轻量，免费，GDScript 学习曲线适合新手 |
| **Key Technical Challenges** | ① Parry 时机手感调试（最难）② HD 美术管线（最贵）③ Boss 状态机 + 攻击序列系统 |
| **Art Style** | 2D HD 手绘插画风（非像素）；成人美学；暗神话色彩 |
| **Art Pipeline Complexity** | High — 全 HD 手绘角色帧动画；可考虑 AI 辅助 + 手工精修降低成本 |
| **Audio Needs** | Music-heavy — 每个 Boss 独立主题曲；格挡音效与节奏强绑定 |
| **Networking** | 无 |
| **Content Volume** | MVP: 1 Boss; Full: 7-9 Boss + 过渡枢纽区域，约 10-15 小时内容 |
| **Procedural Systems** | 无——Boss 设计必须精确，不适合随机生成 |

---

## Risks and Open Questions

### Design Risks

- **Parry 手感调试难度极高** — "感觉对"的窗口时间需要大量迭代；格挡太宽没挑战，太窄太沮丧
- **单纯 Boss Rush 体量感不足** — 没有探索层，内容量全靠 Boss 质量支撑；8 个 Boss 是否足够？
- **成人内容边界定义** — 多成熟才算"有价值的成人内容"而非"为成人而成人"？需要明确定义

### Technical Risks

- **Godot 4.x 对于首次开发者的学习曲线** — 信号系统、场景树设计需要时间理解
- **HD 美术管线对个人开发者过于昂贵** — 全手绘是最大风险；AI 辅助或外包是可行缓解方案
- **Boss 状态机复杂度** — 多阶段 Boss + 视觉预警系统的技术实现需要良好架构

### Market Risks

- **Boss Rush 是小众品类** — 但有验证的受众（Furi, Sekiro, Hi-Fi Rush）
- **Steam 18+ 内容审核** — 成人美学需了解 Steam 的具体内容政策；明确暴力/性描绘边界
- **HD 美术质量门槛高** — 玩家对"成人美学"有高期待；低质量美术会直接劝退目标受众

### Scope Risks

- **美术管线是最大范围炸弹** — 每个 HD Boss 的完整美术资产远超预期时间
- **Parry 系统调试不可压缩** — 手感设计没有捷径，必须玩测

### Open Questions

- **"成人内容"的具体定义** — 暗示性？写实暴力？还是更明确的内容？需要在 `/art-bible` 中定义
- **视觉预警系统是否足够清晰** — 需要 `/prototype` 阶段快速验证
- **多少个 Boss 才是"足够"** — 最小内容量的玩家满意度下限？

---

## MVP Definition

**Core hypothesis**: 玩家发现"视觉预警格挡反击"循环在 30 分钟内具有足够吸引力，愿意多次尝试同一个 Boss。

**Required for MVP**:
1. 一个完整的 Boss（2 阶段、6-8 种攻击、视觉预警全实现）
2. 基础格挡/反击机制（时机窗口、成功/失败反馈、反击连段）
3. 即时重试系统（死亡后 3 秒内可重新开始，无惩罚）

**Explicitly NOT in MVP**:
- HD 成人美学美术（占位草图足够验证格挡手感）
- 叙事解锁系统
- 多个 Boss
- 技能树/升级系统
- 存档系统

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **Prototype/Jam** | 1 Boss 竞技场，占位美术 | 格挡/反击核心机制 | 数周 |
| **Vertical Slice** | 3 Boss + 简化过渡区域 | 核心机制 + 简化叙事解锁 + 基础 HD 美术 | 3-6 个月 |
| **Alpha** | 7-9 Boss 占位全内容 | 所有机制草版 | 12 个月 |
| **Full Vision** | 7-9 Boss 完整 HD 美术 + 全叙事 | 所有功能打磨完成 | 18-24 个月（solo） |

---

## Next Steps

- [ ] Run `/setup-engine` — 配置 Godot 4.6，填充版本感知参考文档
- [ ] Run `/prototype parry-counter-system` — **第一优先级**：用占位美术验证格挡手感是否好玩（1-3 天原型）
- [ ] Run `/art-bible` — 在写任何 GDD 之前定义完整视觉身份（使用上方 Visual Identity Anchor 作为种子）
- [ ] Run `/design-review design/gdd/game-concept.md` — 概念文档完整性验证
- [ ] Run `/map-systems` — 将概念拆解为独立系统（Boss 状态机、格挡系统、叙事系统等）
- [ ] Run `/design-system [system-name]` — 按依赖顺序逐系统撰写 GDD
- [ ] Run `/create-architecture` — 生成架构蓝图和必要 ADR 列表
- [ ] Run `/architecture-review` — 引导需求可追溯矩阵 (RTM) 建立
- [ ] Run `/gate-check` — 进入 Pre-Production 前的阶段关卡验证
