# Roadmap 5 - 玩家成长与动态难度设计稿

> 状态：已确认  
> 范围：玩家局内等级系统、三选一升级、升级能力池、刷怪难度阶梯、荒漠/熔岩地狱关卡差异化。  
> 执行计划：见 `docs/roadmap5-task-plan.md`。

---

## 1. 当前项目基线

现有项目已经具备做“吸血鬼幸存者 LIKE 局内成长”的基础：

- `RunStats` 已记录本局 `score / kills / survival_time`，适合作为经验、等级、难度曲线的时间基准。
- `GameBus` 已是 Autoload 信号总线，可继续承载 `xp_changed / level_up / upgrade_selected` 等成长信号。
- `WeaponData / WeaponNode / WeaponManager` 已支持多武器、伤害、射速、弹匣、换弹、散布、眩晕、击退等可调参数。
- `WhipData / IronWhip` 已支持铁鞭伤害、眩晕、拉取、抓取、盾牌、甩出、冲刺处决等独立能力。
- `Damageable` 已支持生命和护甲上限，HUD 已显示生命、护甲、武器、弹药、击杀、时间和强度。
- `DropManager` 已有弹药、生命、护甲掉落，适合接入“掉落数量/概率/拾取收益”升级。
- `SpawnManager` 已按生存时间计算强度、控制敌人池、刷新间隔、场上上限、波次预算，并区分 `desert / lava` 权重。

需要注意：`Damageable` 注释写的是 DOOM 经典 50% 护甲吸收，但当前代码实际表现为“护甲优先全额吸收伤害，护甲不足后剩余伤害扣血”。Roadmap 5 的数值设计先以当前代码行为为准，是否改回 50% 吸收另开议题。

---

## 2. 设计目标

### 2.1 玩家等级系统

每局从 1 级开始。玩家击杀敌人获得经验，经验满后升级，并弹出 3 个升级选项，玩家选择 1 个立即生效。

核心体验目标：

- 每次升级都让玩家感到战斗方式发生了可感知变化。
- 升级既能强化枪械，也能强化铁鞭、补给、生存能力和数值上限。
- 每种升级有最高等级，避免无限堆叠导致数值失控。
- 升级池支持数据驱动，后续能在 Godot 编辑器里调数值。
- 第一版优先做“局内成长”，暂不做局外永久天赋。

### 2.2 刷怪逻辑跟随玩家成长

刷怪难度以“时间”为主轴，以“玩家等级/能力水平”为修正。

核心体验目标：

- 标准流程下，玩家大约在某个时间点达到预期等级，刷怪强度也进入对应阶段。
- 玩家成长快时，刷怪可以略微提前变强，避免碾压。
- 玩家成长慢时，刷怪不应大幅放水，而是更多通过经验/补给倾斜帮助追赶。
- 熔岩地狱必须明显比荒漠关难：更多远程/飞行/高级敌人，更高密度，更短刷新间隔，并叠加熔岩危险区压力。

---

## 3. 新增模块建议

### 3.1 `scripts/progression/player_progression.gd`

玩家局内成长控制器。建议挂在 `Player` 下，或由 `main.gd` 创建并持有。

职责：

- 保存 `level / xp / xp_to_next / selected_upgrades`。
- 监听敌人击杀，获得经验。
- 处理连续升级。
- 生成三选一升级选项。
- 应用玩家选择的升级。
- 发出 HUD 和难度系统需要的信号。

建议信号：

```gdscript
signal xp_changed(level: int, xp: int, xp_to_next: int)
signal level_up(new_level: int, options: Array[UpgradeData])
signal upgrade_applied(upgrade_id: String, new_upgrade_level: int)
signal player_power_changed(power_score: float)
```

### 3.2 `scripts/progression/upgrade_data.gd`

升级能力 Resource。每个升级做成 `.tres`，放入 `assets/upgrades/`。

建议字段：

```gdscript
class_name UpgradeData extends Resource

enum Category { WEAPON, WHIP, SURVIVAL, ECONOMY, UTILITY }
enum Operation { ADD, MULTIPLY, SET }

@export var upgrade_id: String
@export var display_name: String
@export_multiline var description: String
@export var category: Category
@export var max_level: int = 5
@export var rarity_weight: float = 1.0
@export var tags: Array[String] = []
@export var prerequisites: Array[String] = []
@export var exclusions: Array[String] = []

@export var target_id: String
@export var stat_key: String
@export var operation: Operation
@export var values_by_level: Array[float]
@export var power_value_by_level: Array[float]
```

### 3.3 `scripts/progression/upgrade_catalog.gd`

升级池查询器。第一版可以直接预加载数组，后续再改为扫描 `assets/upgrades/`。

职责：

- 过滤已满级升级。
- 过滤前置条件未满足升级。
- 根据权重抽取 3 个不重复选项。
- 保证选项结构更有趣：尽量提供“武器/生存/功能或经济”三类混合，而不是三个都加伤害。

### 3.4 `scripts/ui/level_up_panel.gd`

升级三选一 UI。升级时暂停游戏，鼠标释放，选择后恢复。

建议行为：

- 显示 3 张升级卡。
- 每张卡显示名称、当前等级、最高等级、效果说明。
- 按 `1 / 2 / 3` 或鼠标点击选择。
- 选择后调用 `PlayerProgression.select_upgrade(index)`。
- 若连续升多级，选择完一个后继续弹下一个。

建议新增 `GameState.LEVEL_UP`，避免和普通暂停菜单混用。若第一版想少改状态机，也可以让 `LevelUpPanel.process_mode = PROCESS_MODE_ALWAYS`，在升级时仅 `get_tree().paused = true`，选择后恢复。

---

## 4. 经验与等级曲线

### 4.1 标准流程

建议第一版以 10 分钟为一局标准流程，而不是 30 分钟长局。现有竞技场、刷怪上限和敌人类型更适合短中局高密度验证。

目标等级节奏：

| 时间 | 预期等级 | 玩家能力状态 |
|---:|---:|---|
| 0:00 | Lv1 | 只有初始武器、铁鞭和基础补给 |
| 0:30 | Lv2 | 获得第一个方向性升级 |
| 1:00 | Lv3 | 主武器或生存能力开始成型 |
| 1:30 | Lv4 | 能稳定处理基础近战怪 |
| 2:00 | Lv5 | 应有 1 个武器 2 级或 2 个基础升级 |
| 3:00 | Lv7 | 开始能处理混合近战/远程压力 |
| 4:00 | Lv9 | 铁鞭或霰弹枪/步枪有明显强化 |
| 5:00 | Lv11 | 有一条主成长路线成型 |
| 7:00 | Lv15 | 能对抗高级敌人和飞行敌人组合 |
| 10:00 | Lv20 | 构筑基本完成，进入高压清场/极限生存 |

### 4.2 经验需求

建议公式：

```text
xp_to_next(level) = round(12 + 6 * level + 1.5 * pow(level, 1.5))
```

示例曲线：

| 升到 | 本级需要经验 | 累计经验 |
|---:|---:|---:|
| Lv2 | 20 | 20 |
| Lv3 | 28 | 48 |
| Lv4 | 38 | 86 |
| Lv5 | 48 | 134 |
| Lv6 | 59 | 193 |
| Lv7 | 70 | 263 |
| Lv8 | 82 | 345 |
| Lv9 | 94 | 439 |
| Lv10 | 107 | 546 |
| Lv11 | 119 | 665 |
| Lv12 | 133 | 798 |
| Lv13 | 146 | 944 |
| Lv14 | 160 | 1104 |
| Lv15 | 175 | 1279 |
| Lv16 | 189 | 1468 |
| Lv17 | 204 | 1672 |
| Lv18 | 219 | 1891 |
| Lv19 | 235 | 2126 |
| Lv20 | 250 | 2376 |

### 4.3 敌人经验值

第一版不必立刻做经验宝石。可以先采用“击杀直接给经验”，减少拾取系统复杂度。后续再加经验碎片和拾取半径升级。

建议在 `EnemyData` 增加：

```gdscript
@export var xp_value: int = 5
```

若旧资源未填写，则用 `max(3, round(score_value * 0.5))` 作为回退。

建议经验值：

| 敌人 | 经验 | 理由 |
|---|---:|---|
| ground_enemy | 5 | 基础近战怪 |
| ranged_enemy | 8 | 更危险，数量较少 |
| flying_enemy | 8 | 机动压力高 |
| orc_melee | 10 | 有护甲/防御机制 |
| advanced_ground_enemy | 12 | 中期近战主力 |
| advanced_ranged_enemy | 14 | 中期远程压力 |
| advanced_flying_enemy | 15 | 高机动高压 |
| flying_ranged_enemy | 16 | 高压混合定位 |
| elite_ground_enemy | 30 | 精英单位，低频高奖励 |

---

## 5. 升级能力池

### 5.1 选择规则

每次升级给 3 个选项：

- 不出现已满级升级。
- 不出现前置条件不满足的升级。
- 不出现互斥升级。
- 尽量避免 3 个选项都属于同一类。
- 如果可选池不足 3 个，提供临时补偿选项：回血、补护甲、加分。

推荐权重：

| 类别 | 基础权重 | 说明 |
|---|---:|---|
| 武器 | 35% | 构筑主轴，强化输出 |
| 铁鞭 | 25% | 强化控制、抓取、盾牌、处决 |
| 生存 | 20% | 血量、护甲、速度、防御 |
| 经济/掉落 | 15% | 掉落数量、拾取收益、经验收益 |
| 功能 | 5% | 拾取半径、特殊机制等 |

### 5.2 武器类升级

| 升级 | 最高等级 | 效果 |
|---|---:|---|
| 步枪膛线 | 5 | 步枪伤害每级 +10% |
| 步枪扳机 | 4 | 步枪射速每级 +8% |
| 步枪稳定器 | 4 | 步枪移动散布惩罚每级 -10% |
| 霰弹重弹 | 5 | 霰弹枪每颗弹丸伤害每级 +8% |
| 霰弹扩容 | 3 | Lv1/Lv3 弹丸数 +1，Lv2 备弹消耗效率 +15% |
| 快速装填 | 5 | 所有有限弹药武器换弹时间每级 -8% |
| 手枪银弹 | 5 | 手枪伤害每级 +15% |
| 拳头碎骨 | 4 | 拳头伤害/眩晕每级 +15% |

实现建议：不要直接永久修改 `.tres` 原始资源。武器初始化时应 `duplicate(true)`，或在 `WeaponNode` 内维护运行时倍率，例如 `damage_mult / fire_rate_mult / reload_mult`。

### 5.3 铁鞭类升级

| 升级 | 最高等级 | 效果 |
|---|---:|---|
| 加长链节 | 4 | `whip_range` 每级 +0.5m |
| 快速回收 | 5 | `cooldown` 每级 -8% |
| 强化电击 | 5 | `stun_damage` 每级 +12% |
| 重力卷扬 | 4 | `pull_speed` 每级 +15%，抓取减速惩罚每级降低 8% |
| 盾牌姿态 | 4 | 盾牌模式移动惩罚降低，格挡反馈更强 |
| 冲刺处决 | 4 | `dash_distance` 每级 +0.75m，`dash_damage` 每级 +15% |
| 投掷爆破 | 4 | 甩出范围每级 +0.5m，`throw_damage` 每级 +15% |

实现建议：`IronWhip` 当前通过 `WhipData` 读取数值。第一版可以在 `setup()` 时复制 `WhipData`，升级只改复制后的运行时数据。

### 5.4 生存类升级

| 升级 | 最高等级 | 效果 |
|---|---:|---|
| 血肉增生 | 5 | 最大生命每级 +20，选择时同步回复 +20 |
| 护甲背板 | 4 | 最大护甲每级 +25，选择时同步补护甲 +25 |
| 肾上腺素 | 4 | 移动速度每级 +4% |
| 硬化皮肤 | 4 | 受到近战伤害 -6%/级 |
| 弹片缓冲 | 4 | 受到远程/投射物伤害 -6%/级 |

第一版可以先做 `max_health / max_armor / move_speed`，伤害减免等到 Damageable 支持通用防御倍率后再做。

### 5.5 经济与掉落类升级

| 升级 | 最高等级 | 效果 |
|---|---:|---|
| 弹药搜刮 | 5 | 弹药掉落数量每级 +20% |
| 医疗搜刮 | 4 | 血包恢复量每级 +15% |
| 护甲回收 | 4 | 护甲拾取量每级 +15% |
| 丰饶掉落 | 4 | 总掉落概率每级 +5 个百分点 |
| 双份补给 | 3 | 掉落时有 10%/20%/30% 概率额外生成一个补给 |
| 战斗学习 | 5 | 获得经验每级 +8% |

实现建议：`DropManager` 增加运行时倍率字段，例如：

```gdscript
var ammo_amount_mult := 1.0
var health_amount_mult := 1.0
var armor_amount_mult := 1.0
var drop_chance_bonus := 0.0
var extra_drop_chance := 0.0
```

---

## 6. 玩家能力评分

刷怪系统不要只看等级，因为不同升级的强度差异很大。建议引入 `power_score`，第一版可以先用等级，第二版再用升级权重。

第一版：

```text
power_score = player_level
```

第二版：

```text
power_score = player_level + sum(selected_upgrade.power_value_by_level)
```

参考评分：

| 能力变化 | power_score 增量 |
|---|---:|
| 单武器伤害 +10% | +0.6 |
| 所有武器换弹 -8% | +0.5 |
| 最大生命 +20 | +0.5 |
| 最大护甲 +25 | +0.5 |
| 铁鞭冷却 -8% | +0.7 |
| 铁鞭眩晕 +12% | +0.8 |
| 掉落收益 +20% | +0.4 |
| 经验收益 +8% | +0.6 |

---

## 7. 标准难度阶梯

现有 `SpawnManager` 有 6 档强度，建议 Roadmap 5 扩展到 8 档，覆盖 10 分钟流程。

基础阶梯：

| 阶梯 | 时间 | 预期等级 | 场上上限 | 刷新间隔 | 波次预算 | 敌人池 |
|---:|---|---:|---:|---:|---:|---|
| 1 | 0:00-0:30 | 1-2 | 6 | 4.4s | 2 | 近战恶魔 |
| 2 | 0:30-1:30 | 2-4 | 10 | 3.5s | 3 | + 远程恶魔 / 兽人 |
| 3 | 1:30-2:30 | 4-6 | 14 | 2.8s | 4 | + 飞行恶魔 |
| 4 | 2:30-4:00 | 6-9 | 18 | 2.2s | 5 | + 高阶近战 / 高阶远程 |
| 5 | 4:00-6:00 | 9-12 | 24 | 1.8s | 7 | + 高阶飞行 / 飞行远程 |
| 6 | 6:00-8:00 | 12-16 | 30 | 1.5s | 9 | + 少量精英 |
| 7 | 8:00-10:00 | 16-20 | 38 | 1.2s | 12 | 全敌人混合，高级敌人权重上升 |
| 8 | 10:00+ | 20+ | 45 | 1.0s | 15 | 极限生存，精英周期性出现 |

### 7.1 玩家成长修正

时间仍是主轴，玩家等级只做轻微修正。

```text
level_delta = player_level - expected_level_at_time
```

建议规则：

| level_delta | 处理 |
---:|---|
| <= -3 | 不降低主阶梯；经验获得 +10%，掉落总概率 +5pp，升级池提高生存类权重 |
| -2~-1 | 不降低主阶梯；经验获得 +5% |
| 0~2 | 按标准阶梯 |
| 3~4 | 波次预算 +10%，高级敌人权重 +10% |
| >= 5 | 阶梯临时 +1，波次预算 +15%，但不超过当前时间下一档 |

这样做的目的：玩家强时游戏追上来，玩家弱时给追赶资源，但不让世界明显“变傻”。

### 7.2 预期等级插值表

`SpawnManager` 可以使用这张表按时间插值，得到当前预期等级：

| 时间 | 预期等级 |
|---:|---:|
| 0s | 1 |
| 30s | 2 |
| 60s | 3 |
| 90s | 4 |
| 120s | 5 |
| 180s | 7 |
| 240s | 9 |
| 300s | 11 |
| 420s | 15 |
| 600s | 20 |

---

## 8. 关卡差异化

### 8.1 荒漠关：入门标准

荒漠是第一关，目标是让玩家学习“走位、铁鞭控制、补给拾取、武器切换”。

建议修正：

| 参数 | 修正 |
|---|---:|
| 场上上限 | x0.90 |
| 刷新间隔 | x1.12 |
| 波次预算 | x0.90 |
| 敌人生命 | x1.00 |
| 敌人伤害 | x1.00 |
| 敌人速度 | x1.00 |
| 精英解锁 | 不早于阶梯 7 |
| 经验/掉落 | x1.00 |

权重方向：

- 近战恶魔、兽人、高阶近战偏多。
- 远程敌人中等。
- 飞行敌人少量出现，用来教学空中目标处理。
- 精英敌人只在后段作为压力峰值。

### 8.2 熔岩地狱：明显更难

熔岩地狱是第二关，除了熔岩河流 18 DPS 的环境压力，还应在刷怪上明显更难。

建议修正：

| 参数 | 修正 |
|---|---:|
| 场上上限 | x1.20 |
| 刷新间隔 | x0.90 |
| 波次预算 | x1.15 |
| 敌人生命 | x1.10 |
| 敌人伤害 | x1.10 |
| 敌人速度 | x1.05 |
| 高级敌人解锁 | 比荒漠提前 1 个阶梯 |
| 精英解锁 | 阶梯 6 起低权重出现 |
| 经验/掉落 | x1.10，作为高风险补偿 |

权重方向：

- 远程、飞行、飞行远程显著增加。
- 高阶近战用来把玩家逼向熔岩河和岩柱死角。
- 精英敌人出现更早，但数量不能过多，避免和熔岩地形形成不可解局面。

---

## 9. SpawnManager 改造方向

### 9.1 新增配置结构

建议把当前 `match current_intensity` 改为数据表，方便调参。

```gdscript
class DifficultyTier:
	var tier: int
	var start_time: float
	var expected_level: int
	var active_limit: int
	var spawn_interval: float
	var wave_budget: int
```

关卡修正：

```gdscript
class SpawnProfile:
	var active_limit_mult: float
	var spawn_interval_mult: float
	var wave_budget_mult: float
	var enemy_health_mult: float
	var enemy_damage_mult: float
	var enemy_speed_mult: float
	var xp_mult: float
	var enemy_weight_overrides: Dictionary
	var unlock_tier_offsets: Dictionary
```

### 9.2 与玩家成长系统连接

`SpawnManager.setup()` 增加 progression 引用，或从 `GameBus.player_progression` 获取。

建议新增：

```gdscript
func set_progression(progression: PlayerProgression) -> void
func _get_expected_level(time: float) -> int
func _get_growth_adjustment() -> Dictionary
func _get_effective_tier() -> int
```

### 9.3 刷怪时应用关卡倍率

敌人生成后不建议直接修改 `.tres` 原资源。可以：

- 复制 `EnemyData` 后赋给敌人。
- 或在 `Enemy` 内支持运行时倍率，例如 `health_mult / damage_mult / speed_mult`。

推荐第一版复制资源：

```gdscript
var data = load(tres_path)
var runtime_data = data.duplicate(true)
runtime_data.max_health *= profile.enemy_health_mult
runtime_data.attack_damage *= profile.enemy_damage_mult
runtime_data.move_speed *= profile.enemy_speed_mult
enemy.set("enemy_data", runtime_data)
```

---

## 10. HUD 与反馈

需要新增显示：

- 当前等级：`Lv 7`
- 经验条：当前经验 / 下级经验
- 升级三选一面板
- 已选择升级列表可选：第一版可以只在升级面板中显示，不常驻 HUD。
- 难度阶梯仍显示为“强度”，但建议改成 `强度: 4 / 地狱` 或 `强度: 4  Lv预期: 6` 供调试。

UI 放置建议：

- 等级和经验条放在左上角分数/时间附近。
- 升级面板居中覆盖，暂停游戏。
- 升级选择后显示 1.5 秒通知，例如 `步枪膛线 Lv2`。

---

## 11. MVP 范围建议

第一版只做最小闭环：

- 击杀给经验。
- 满经验升级。
- 弹出 3 个升级选项。
- 选择后立即应用。
- 做 12-16 个升级，覆盖武器、铁鞭、生存、掉落。
- HUD 显示等级和经验。
- SpawnManager 使用玩家等级修正波次预算和高级敌人权重。
- 荒漠/熔岩地狱使用不同 Profile，让地狱关明显更难。

暂不做：

- 局外永久成长。
- 经验宝石掉落和磁吸。
- 稀有度动画、卡面美术。
- 复杂流派套装和互斥构筑。
- Boss 波次。
- 精确 DPS 模拟器。

---

## 12. 验收标准

功能验收：

- 玩家击杀敌人后经验增加。
- 经验满后游戏暂停并出现 3 个升级选项。
- 选择升级后游戏恢复，升级效果立即生效。
- 已满级升级不会再次出现。
- 玩家最大生命/护甲升级能正确更新 HUD。
- 武器伤害/射速/换弹类升级能在当前局生效。
- 铁鞭范围/冷却/眩晕/冲刺类升级能在当前局生效。
- 掉落数量/概率类升级能影响后续掉落。
- 荒漠关同时间点压力低于熔岩地狱。
- 玩家等级明显超前时，刷怪密度或高级敌人权重上升。
- 玩家等级落后时，经验/补给追赶机制生效。

数值验收：

- 标准玩家在荒漠关 1 分钟左右达到 Lv3。
- 标准玩家在荒漠关 3 分钟左右达到 Lv7。
- 标准玩家在荒漠关 5 分钟左右达到 Lv11。
- 标准玩家在荒漠关 10 分钟左右达到 Lv20。
- 熔岩地狱同时间点敌人数量、远程/飞行比例和环境压力显著高于荒漠。

稳定性验收：

- 升级选择暂停期间，敌人、投射物、刷怪计时器不继续运行。
- 连续升级不会丢失选项或重复恢复暂停状态。
- 切关、重开、死亡后等级、经验、升级效果重置。
- 不修改原始 `.tres` 导致下一局继承上一局升级。

---

## 13. 已确认决策

1. 标准流程以 10 分钟为基准。
2. 第一版经验获取接受“击杀直接给经验”，暂不做经验碎片。
3. 升级三选一时强制暂停游戏。
4. 护甲继续按当前代码行为处理：护甲优先全额吸收伤害，护甲不足后剩余伤害扣血。
5. 熔岩地狱允许提供 +10% 经验/掉落，作为高风险高收益补偿。
