# 投掷视觉改造 + 落地处决

## 改什么

修改 `scripts/weapon/iron_whip.gd` 中的抛物线投掷系统，涉及三项改动：

### 1. 抛物线预览：黄点 → 渐变色线段

**现状**：20个黄色半透明小球（SphereMesh, radius=0.04, Color(1.0, 0.6, 0.1, 0.7)）沿抛物线排列成虚线。

**目标**：改为连续的线段，颜色从前（落点/远端）灰白渐变到后（玩家/近端）淡红。

**实现方案**：
- 将 `_parabola_nodes` 从 SphereMesh 数组改为 BoxMesh 线段数组
- 线段数：~30段（保证平滑）
- 每段：BoxMesh(0.02, 0.02, segment_length)，放在相邻两个抛物线采样点之间，朝向对齐两点连线方向
- 颜色插值：
  - 落点端（前）：`Color(0.85, 0.85, 0.85, 0.6)` 灰白
  - 玩家端（后）：`Color(1.0, 0.25, 0.25, 0.6)` 淡红
  - 中间各段按线性插值
- 材质：SHADING_MODE_UNSHADED + TRANSPARENCY_ALPHA（与现有一致）

**涉及方法**：
- `_create_parabola_preview()` — 改创建逻辑
- `_update_parabola_preview()` — 改更新逻辑（计算相邻点→设置线段位置/旋转/颜色）
- `_clear_parabola_preview()` — 不变（仍是 queue_free 所有节点）

### 2. 落点地面红圈

**现状**：无落点标记。

**目标**：瞄准落点地面显示一个 2m 半径的红色圆圈。

**实现方案**：
- 使用 TorusMesh（环形）平放在地面：
  - `major_radius = 2.0`（外圈半径 2m，与 `explosion_radius` 一致）
  - `minor_radius = 0.04`（线粗 4cm）
  - 绕 X 轴旋转 90° 使其平贴地面
- 材质：红色半透明 `Color(1.0, 0.15, 0.15, 0.5)`，UNSHADED + TRANSPARENCY_ALPHA
- 生命周期：和抛物线预览同步创建/更新/销毁
- 位置：每帧跟随 `_aim_point`，Y 轴微偏移（+0.05m）避免 z-fighting

**涉及方法**：
- `_create_parabola_preview()` — 额外创建一个 TorusMesh 节点
- `_update_parabola_preview()` — 更新圆圈位置到 `_aim_point`
- `_clear_parabola_preview()` — 一起销毁

### 3. 落地按处决处理

**现状**：`_on_throw_impact()` 对被投掷的敌人只给 weight 伤害 + 击退 + 转 KNOCKED_DOWN，敌人不死亡。

**目标**：投掷的敌人落地后执行处决逻辑（即按 F 键处决的同等效果：execute() + 加分 + 通知），AOE 范围内其他敌人仍受溅射伤害。

**实现方案**：
- 新增成员变量 `var _thrown_enemy: Enemy = null` 追踪正在飞行的被投敌人
- `_execute_throw()` 中设置 `_thrown_enemy = enemy`
- `_on_throw_impact()` 中：
  1. 对被投掷敌人调用处决流程（与 `_execute_grabbed()` 一致）：
     - `enemy.execute()` → 血量清零 + 转 EXECUTED 状态 + 发射 died 信号
     - `GameBus.run_stats.add_kill(execution_score_bonus)` 加分
     - `GameBus.pickup_notification` 显示"投掷处决 +N"
     - `trigger_on_damaged(execution_damage, MELEE)` 触发死亡特效
  2. 对 AOE 范围内**其他**敌人（排除被投掷者）造成溅射伤害和击退（保持现有逻辑）
  3. 清理 `_thrown_enemy = null`

**注意**：被投掷敌人已通过 `start_throw()` 脱离了抓取状态，且在 `_trigger_thrown_impact()` 中回调执行后才转 KNOCKED_DOWN，所以回调内直接 execute() 是安全的。

**涉及方法**：
- `_execute_throw()` — 设置 `_thrown_enemy`
- `_on_throw_impact()` — 改为处决逻辑 + AOE 排除被投掷者


## 不改什么

- 抛物线物理计算（`_calculate_throw_velocity`、`_estimate_flight_time`、`_find_aim_point`）不变
- 盾牌模式进出逻辑不变
- `start_throw` / `_state_thrown` / `_trigger_thrown_impact` 不变
- `WhipData` 资源配置不变
- 冲刺处决（DASHING）不变


## 影响范围

| 文件 | 改动类型 |
|------|----------|
| `scripts/weapon/iron_whip.gd` | 修改 5 个方法，新增 1 个成员变量 |

约 80 行改动（大部分是替换现有代码），无新增文件。
