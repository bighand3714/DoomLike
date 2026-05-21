# 投掷逻辑重做

## 需求

1. 投掷方向跟随镜头朝向（非瞄准地面某点）
2. 标准敌人（60kg）45°镜头角投掷 20m 远
3. 碰到敌人/障碍物（枯树等）/地面时，以撞击点为中心生成 3m 半径球形判定区
4. 对区域内敌人造成 = 被投敌人重量 的伤害
5. 击退方向 = 圆心到受击敌人在水平面的投影方向，击退力度中等

## 物理校准

- g = 20 m/s²（项目统一常量）
- 60kg @ 45° → 20m：`v₀² = R·g / sin(2θ) = 20·20 / 1 = 400 → v₀ = 20 m/s`
- 速度按恒定动能缩放：`v = 20 · sqrt(60 / weight)`，钳制 [10, 25]

| 体重 | 速度 | 45°射程 |
|------|------|---------|
| 30kg | 25.0 | 31m |
| 40kg | 24.5 | 30m |
| 60kg | 20.0 | 20m |
| 80kg | 17.3 | 15m |
| 100kg | 15.5 | 12m |

## 改动清单

### 1. `scripts/weapon/whip_data.gd` — 数据资源

| 操作 | 字段 | 说明 |
|------|------|------|
| **改** | `explosion_radius` 默认值 2.0→3.0 | 3m球形判定区 |
| **删** | `throw_speed` | 旧垂直速度参数 |
| **删** | `throw_speed_horizontal` | 旧水平速度参数 |
| **删** | `throw_damage` | 伤害改为 = 被投敌人重量 |
| **增** | `throw_speed_base: float = 20.0` | 60kg基准初速 |
| **增** | `throw_reference_weight: float = 60.0` | 基准体重 |
| **增** | `throw_impact_knockback: float = 10.0` | 落地溅射击退力 |

### 2. `scripts/weapon/iron_whip.gd` — 铁鞭脚本

#### 删除
- `_aim_point` 成员变量
- `_find_aim_point()` — 不再射线瞄地
- `_calculate_throw_velocity()` — 不再计算抛物线瞄准
- `_estimate_flight_time()` — 不再估算飞行时间

#### 新增
- `_calc_throw_speed(weight: float) -> float` — 按体重计算初速
- `_find_ground_height_at(xz: Vector3, above: float) -> float` — 给定XZ位置射线向下找地面Y
- `_trace_trajectory(origin, velocity, max_time) -> Dictionary` — 采样轨迹，返回 `{points, landing, hit_time}`

#### 修改

**`_process_shielding()`** — 改为调用新的轨迹预览（基于镜头方向，非瞄准点）

**`_update_parabola_preview()`** — 重写：
1. 取镜头前向 → `cam_forward`
2. 计算初速：`cam_forward * _calc_throw_speed(weight)`
3. 轨迹采样（每0.05s，最长3s），每个采样点射线向下找地
4. 找到落点后截断抛物线并更新地面圆圈位置
5. 圆圈半径改用 `explosion_radius`（3m）

**`_execute_throw()`** — 简化：
```
var cam_forward := (-_camera.global_transform.basis.z).normalized()
var weight := enemy.enemy_data.weight if enemy.enemy_data else 60.0
var speed := _calc_throw_speed(weight)
var throw_origin := _player.global_position + cam_forward * 2.0 + Vector3(0, 0.5, 0)
enemy.global_position = throw_origin
enemy.start_throw(cam_forward * speed, func(pos): _on_throw_impact(pos, enemy))
```

**`_on_throw_impact()`** — 重写：
1. **不处决被投敌人** — 改为造成 `throw_damage = enemy_data.weight` 伤害 + 击退
2. 以 `impact_pos` 为中心，3m 半径球体检测（`PhysicsShapeQueryParameters3D` sphere）
3. 对范围内每个敌人：伤害 = weight，击退 = 水平方向 * `throw_impact_knockback`
4. 被投掷的敌人转入 KNOCKED_DOWN
5. 生成爆炸范围圈（`_spawn_explosion_ring` 已实现）
6. **不再**调用 `enemy.execute()`、`trigger_on_damaged(execution_damage)`、计分等

#### 成员变量清理
- 删除 `var _aim_point: Vector3 = Vector3.ZERO`

### 3. `scripts/enemy/enemy.gd` — 不改

`_state_thrown()` 已正确处理：
- `is_on_floor()` → 落地
- `moved < expected * 0.15` → 撞障碍物（枯树等）
- `get_slide_collision_count()` 检测到 Enemy → 撞敌人
- 超时/掉出世界兜底

## 预览算法

```
func _update_parabola_preview():
    cam_forward = -camera.global_transform.basis.z.normalized()
    origin = player_pos + cam_forward * 2.0 + (0, 0.5, 0)
    speed = _calc_throw_speed(grabbed_enemy.enemy_data.weight)
    vel = cam_forward * speed
    
    points = []
    landing = null
    for t in 0..3.0 step 0.05:
        pos = origin + vel*t + (0, -10*t², 0)
        ground_y = raycast_down_at(pos.xz, from_y=pos.y+10)
        points.append(pos)
        if pos.y <= ground_y:
            landing = Vector3(pos.x, ground_y, pos.z)
            break
    
    更新线段和圆圈位置到 landing
```

## 不在改动范围

- 冲刺处决（DASHING）逻辑不变
- F 键处决（`_execute_grabbed`）不变
- 盾牌模式进出逻辑不变
- 半透明/材质处理不变
- 铁链挥鞭/拉取/抓取流程不变
- `start_throw()` / `_state_thrown()` / `_trigger_thrown_impact()` 接口不变

## 影响文件

| 文件 | 改动量 |
|------|--------|
| `scripts/weapon/whip_data.gd` | ~5行增删 |
| `scripts/weapon/iron_whip.gd` | ~80行增/改/删 |
