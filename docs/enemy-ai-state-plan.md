# 计划：敌人AI细化——以状态为行动单位（兽人示例）

## 核心原则

**每个状态 = 一种完整的行动策略。** 不看额外变量，只看当前状态名就能知道敌人在做什么。

---

## 兽人状态机重新编排

以兽人为例，登场后按距离档位进入不同状态：

### 状态流转图

```
SPAWNING → IDLE ─┬─ SUPER_FAR (>25m) ──→ RUNNING（跑动靠近）
                 ├─ FAR (8~25m) ──────→ ADVANCING（跑动举盾靠近）
                 ├─ MEDIUM (3~8m) ─┬─→ ADVANCING（行走举盾靠近，附近敌<3）
                 │                  └─→ CIRCLING（举盾绕圈，附近敌≥3）
                 └─ CLOSE (1~3m) ─┬─→ ATTACK_PREPARE → ACTIVE → RECOVER（距>1m）
                                   └─→ RETREATING（步行后退至1m外，距<1m）
```

### 各状态详细定义

| 状态 | 触发条件 | 行为描述 |
|------|----------|----------|
| **IDLE** | 登场默认 | 静默站立，每 0.1s 检测玩家距离，按档位切到对应状态 |
| **RUNNING** | SUPER_FAR (>25m) | 1.5 倍移速向玩家奔跑（无盾） |
| **ADVANCING** | FAR (8~25m) | 跑动速度向玩家靠近，举盾。或 MEDIUM 且附近敌 <3 时，行走速度举盾靠近 |
| **CIRCLING** | MEDIUM (3~8m) 且附近敌 ≥3 | 举盾，横向绕玩家踱步，保持 3~8m 环形距离 |
| **RETREATING** | CLOSE 且距玩家 <1m | 举盾，步行后退至 1m 以外，然后切回 CLOSE 判定 |
| **ATTACK_PREPARE** | CLOSE 且距玩家 >1m | 瞬移至最远攻击距离（~1m），举斧蓄力，进入前摇 |
| **ATTACK_ACTIVE** | 前摇结束 | 斧子挥砍判定，造成伤害，进入后摇 |
| **ATTACK_RECOVER** | 判定窗口结束 | 收斧，完成后回到 IDLE 重新检测距离 |

---

## 实施步骤

### Step 1: 新增状态枚举值

在 `enemy.gd` 的 `EnemyState` enum 中添加：
- `ADVANCING` — 举盾靠近（合并 FAR 跑动 + MEDIUM 行走）
- `CIRCLING` — 举盾绕圈
- `RETREATING` — 举盾后退

### Step 2: 基类 `_ai_tick()` 实现

在 `enemy.gd` 中给基类一个默认 AI tick（所有敌人通用框架，子类可覆写）：
- 获取玩家距离档位
- 按档位调用对应状态
- 不做具体策略（具体策略由各状态函数实现）

### Step 3: 兽人状态函数实现

在 `orc_enemy.gd` 中覆写各状态的 enter/process/exit：

- **`_on_idle_entered()`**：收盾收斧，静默站立
- **`_state_running()`**：跑向玩家，1.5x 移速，到达 FAR 范围后切 ADVANCING
- **`_state_advancing()`**：举盾，按当前距离决定跑/走速度，到达 MEDIUM 后按敌人数量分流
- **`_state_circling()`**：举盾，横向绕圈，保持 MEDIUM 环形距离
- **`_state_retreating()`**：举盾，后退至 1m，到达后切 IDLE
- **攻击链**（已有）：ATTACK_PREPARE → ACTIVE → RECOVER，完成后回 IDLE

### Step 4: 基类辅助方法

确保以下辅助方法在 `enemy.gd` 中可用：
- `get_player_distance_bracket()` — 已有，改用 enemy_data 配置的阈值
- `_count_enemies_near_player(radius)` — 已有
- `_count_nearby_melee_enemies(radius)` — 已有
- `_move_towards_player()` / `_move_away_from_player()` / `_strafe_around_player()` — 已有

### Step 5: 距离阈值配置化

在 `enemy_data.gd` 添加可配置的档位边界：
```gdscript
@export var bracket_melee_max: float = 1.0
@export var bracket_close_max: float = 3.0
@export var bracket_medium_max: float = 8.0
@export var bracket_far_max: float = 25.0
```

### Step 6: SPAWNING 出生动画

新敌人从 SPAWNING 状态开始，0.5s 内 scale 从 0.1 缩放到 1.0，完成后切 IDLE。

---

## 状态机总览（更新后）

```
SPAWNING → IDLE → RUNNING / ADVANCING / CIRCLING / RETREATING / ATTACK_PREPARE
                                                           ↑
ATTACK_ACTIVE → ATTACK_RECOVER ───────────────────────────┘
                                                           ↓
PAIN ← 受击（非Counter）                         回到 IDLE 重新判定
STUNNED ← Counter/眩晕满
GRABBED ← 被铁鞭抓取
KNOCKED_DOWN ← 被甩出/冲刺
DEATH ← 血量归零
```

**核心循环**：IDLE(检测) → 距离档位状态(行动) → IDLE(重新检测) → ...

---

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `scripts/enemy/enemy.gd` | 新增 ADVANCING/CIRCLING/RETREATING 状态枚举；添加状态处理函数框架；默认 `_ai_tick()`；SPAWNING 动画；统一 `_on_damaged()` |
| `scripts/enemy/enemy_data.gd` | 新增 4 个距离档位阈值 `@export`；降低 `detection_interval` 默认值 |
| `scripts/enemy/orc_enemy.gd` | 全部重写状态 enter/process/exit；映射到新状态编排 |
| `scripts/enemy/standard_enemy.gd` | 适配新状态框架，保留跳跃攻击 |
| `scripts/enemy/spawn_manager.gd` | 新敌人初始化为 SPAWNING 状态 |

---

## 向后兼容

- 旧版 `ATTACK` 状态保留，未迁移的旧敌人（Imp/DemonSoldier 等）继续使用
- `CHASE` 状态保留但兽人不再使用
- OrcEnemy 完全覆写所有相关方法，新行为不影响旧敌人

---

## 验证方法

1. 启动测试竞技场 → 兽人初始站立（IDLE），0.1s 后检测到玩家
2. 玩家远离兽人到 >25m → 兽人进入 RUNNING，高速跑来
3. 兽人到 8~25m → 进入 ADVANCING，举盾跑来
4. 兽人到 3~8m → 若附近兽人 ≥3，绕圈踱步（CIRCLING）；若 <3，举盾走进（ADVANCING）
5. 兽人到 1~3m → 若距 >1m，进入 ATTACK_PREPARE → 瞬移至 1m → 举斧 → 挥砍 → 收斧 → 回 IDLE
6. 玩家贴到 <1m → 进入 RETREATING，举盾后退至 1m
7. Counter 触发 → STUNNED 状态，眩晕脉冲闪烁
