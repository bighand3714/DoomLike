# DoomLike 测试文档

> 基于 2026-05-19 Bug 修复轮次编写，覆盖核心系统的手动测试用例。

---

## 1. 测试环境

| 项目 | 说明 |
|------|------|
| 引擎 | Godot 4.6 (Forward Plus, D3D12) |
| 物理 | Jolt Physics |
| 主场景 | `res://scenes/main.tscn` |
| 测试关卡 | `res://scenes/levels/test_arena.tscn` （手动放敌，无自动刷怪） |
| 测试方式 | 手动测试（无自动化框架） |

---

## 2. 敌人系统测试

### 2.1 共享护甲隔离（Bug Fix: Resource armor 变异）

| 项目 | 内容 |
|------|------|
| **严重度** | Critical |
| **修改文件** | `enemy.gd`, `orc_enemy.gd`, `iron_whip.gd` |
| **Root Cause** | `enemy_data` 是共享 Resource，修改 `.armor` 会污染所有同类型敌人 |

**测试步骤：**
1. 在测试关卡放置 3 个 OrcEnemy（有护甲）
2. 鞭打 Orc A 直至破甲
3. 切换到 Orc B，检查其护甲是否仍为完整值

**预期结果：** 每个敌人的护甲独立计算，Orc A 破甲不影响 Orc B、Orc C。

---

### 2.2 StandardEnemy 跳跃攻击单次伤害（Bug Fix: multi-hit ~21x）

| 项目 | 内容 |
|------|------|
| **严重度** | Critical |
| **修改文件** | `standard_enemy.gd` |
| **Root Cause** | 跳跃阶段每帧检测距离 <1.5m 就造成伤害，60fps 下可命中 ~21 次 |

**测试步骤：**
1. 在测试关卡放置 1 个 StandardEnemy
2. 靠近敌人触发跳跃攻击，站在落点不动
3. 观察玩家 HP 减少量

**预期结果：** 每次跳跃攻击只造成 1 次 `attack_damage`（20 HP），而非多次。

---

### 2.3 OrcEnemy 双重伤害（Bug Fix: base _execute_attack + hitbox）

| 项目 | 内容 |
|------|------|
| **严重度** | Critical |
| **修改文件** | `orc_enemy.gd` |
| **Root Cause** | 基类 `_state_attack_active` 调用 `_execute_attack()`，同时 hitbox 信号也造成伤害 |

**测试步骤：**
1. 在测试关卡放置 1 个 OrcEnemy
2. 贴近兽人吃一次斧击
3. 观察玩家 HP 减少量

**预期结果：** 每次攻击只造成 1 次 `attack_damage`，不会出现双倍伤害。

---

### 2.4 兽人防御状态移动（Bug Fix: _state_defending 缺少 move_and_slide）

| 项目 | 内容 |
|------|------|
| **严重度** | Critical |
| **修改文件** | `enemy.gd` |
| **Root Cause** | `_state_defending` 只调用 `_face_player_flat()`，不调用 `move_and_slide()` |

**测试步骤：**
1. 在测试关卡放置多个 OrcEnemy（≥3个）
2. 保持在 1~2m 距离（MEDIUM bracket）
3. 观察兽人是否有横向移动/绕圈行为

**预期结果：** 兽人在防御状态下有横向移动，而非原地不动。

---

### 2.5 DemonSoldier 受控状态下不开枪（Bug Fix: 状态检查不完整）

| 项目 | 内容 |
|------|------|
| **严重度** | Moderate |
| **修改文件** | `demon_soldier.gd` |
| **Root Cause** | Timer 回调只检查 DEATH/PAIN，不检查 STUNNED/GRABBED |

**测试步骤：**
1. 在测试关卡放置 1 个 DemonSoldier
2. 用鞭子晕眩士兵后立即开枪（在 0.15s 瞄准窗口内）
3. 或抓取士兵后观察是否还会开枪

**预期结果：** 士兵被晕眩或抓取后，Timer 触发的射击不会造成伤害。

---

### 2.6 DemonSoldier 多层父节点命中检测（Bug Fix: 浅层 parent check）

| 项目 | 内容 |
|------|------|
| **严重度** | Moderate |
| **修改文件** | `demon_soldier.gd` |
| **Root Cause** | 只检查 1 层 parent，与基类 `_is_player_target` 递归检查不一致 |

**测试步骤：**
1. 正常游戏，让 DemonSoldier 攻击玩家
2. 命中检测应正常工作

**预期结果：** 无论 Player 节点下有多少层子节点，hitscan 命中检测一致。

---

### 2.7 基类增伤标记在子类生效（Bug Fix: _on_damaged 缺少 super）

| 项目 | 内容 |
|------|------|
| **严重度** | Moderate |
| **修改文件** | `orc_enemy.gd`, `standard_enemy.gd` |
| **Root Cause** | 子类覆写 `_on_damaged` 完全跳过基类逻辑 |

**测试步骤：**
1. 使用能施加增伤标记的机制（如有）对 Orc/StandardEnemy 标记
2. 在标记有效期内攻击该敌人
3. 观察伤害数字

**预期结果：** 增伤标记（`_damage_mark_multiplier`）在 OrcEnemy 和 StandardEnemy 上正确生效。

---

## 3. 武器系统测试

### 3.1 铁鞭护甲消耗（Bug Fix: 共享 Resource 变异）

| 项目 | 内容 |
|------|------|
| **严重度** | High |
| **修改文件** | `iron_whip.gd` |
| **Root Cause** | `enemy.enemy_data.armor -=` 变异共享 Resource |

**测试步骤：**
1. 放置 2 个同类型 OrcEnemy
2. 用铁鞭（右键）鞭打 Orc A 多次
3. 再鞭打 Orc B，检查护甲是否独立

**预期结果：** 每个敌人的护甲独立计算。

---

### 3.2 铁鞭处决后安全性（Bug Fix: execute() 后 stale reference）

| 项目 | 内容 |
|------|------|
| **严重度** | High |
| **修改文件** | `iron_whip.gd` |
| **Root Cause** | `enemy.execute()` 后可能触发 `queue_free`，后续访问崩溃 |

**测试步骤：**
1. 抓取一个敌人
2. 按 R 键执行处决
3. 确认无崩溃、无报错

**预期结果：** 处决流程正常完成，控制台无 "Attempt to call method on a null instance" 错误。

---

### 3.3 铁鞭双重视觉特效（Bug Fix: armored 分支重复 spawn）

| 项目 | 内容 |
|------|------|
| **严重度** | High |
| **修改文件** | `iron_whip.gd` |
| **Root Cause** | `_execute_whip_hit` + `_try_whip` 都调用 `_spawn_whip_effect` |

**测试步骤：**
1. 鞭打有护甲的敌人
2. 观察鞭痕视觉效果

**预期结果：** 只出现 1 条鞭痕视觉特效（而非 2 条重叠）。

---

### 3.4 拳头快速连击不抖动（Bug Fix: tween 堆积）

| 项目 | 内容 |
|------|------|
| **严重度** | High |
| **修改文件** | `fist.gd` |
| **Root Cause** | 每次 `_apply_recoil` 创建新 tween，不 kill 旧 tween |

**测试步骤：**
1. 切换到拳头（按键 4）
2. 最快速度连击（连续按鼠标左键）
3. 观察拳头模型位置

**预期结果：** 拳头前冲后座动画平滑，不出现位置抖动/跳跃。

---

## 4. UI 系统测试

### 4.1 波次/盾牌通知自动消失（Bug Fix: 计时器嵌套）

| 项目 | 内容 |
|------|------|
| **严重度** | Critical |
| **修改文件** | `player_status.gd` |
| **Root Cause** | wave/shield 计时器缩进在 `if _boundary_warning_timer > 0.0` 块内 |

**测试步骤：**
1. 触发波次通知（进入有刷怪的关卡）
2. 触发盾牌格挡通知（抓取敌人后受击）
3. 等待通知自动消失

**预期结果：** 两种通知在计时器到期后自动隐藏，不依赖边界警告状态。

---

### 4.2 受击方向指示器方向正确（Bug Fix: 忽略相机旋转）

| 项目 | 内容 |
|------|------|
| **严重度** | Major |
| **修改文件** | `hit_direction_indicator.gd` |
| **Root Cause** | 使用世界空间 XZ 计算方向，未转换到相机空间 |

**测试步骤：**
1. 面向北方，从南侧受击 → 指示器应指向下方
2. 旋转 180° 面向南方，同样从南侧受击 → 指示器应指向上方（背后）

**预期结果：** 指示器方向基于当前视角，而非固定世界方向。

---

### 4.3 HUD 刷新频率（Bug Fix: update_interval 被绕过）

| 项目 | 内容 |
|------|------|
| **严重度** | Major |
| **修改文件** | `player_status.gd` |
| **Root Cause** | `_update_timer = 0.0` 在缩进块内，导致每帧全刷新 |

**测试步骤：**
1. 运行游戏，观察 FPS
2. 对比修复前后 HUD 刷新对性能的影响

**预期结果：** HUD 数据每 0.1s 刷新一次，不每帧刷新。

---

## 5. 集成测试

### 5.1 完整战斗循环

**步骤：**
1. 启动游戏 → 主菜单
2. 进入测试关卡
3. 测试 4 把武器切换（1/2/3/4 + 滚轮）
4. 击杀敌人，确认掉落物生成
5. 收集掉落物（血包/护甲/弹药）
6. 使用铁鞭完整连招：右键挥鞭 → 晕眩 → 拉取 → 举起 → R处决
7. 按 Esc 暂停/继续

**预期结果：** 所有流程无崩溃，掉落物正确生成和消失。

### 5.2 多敌人同场景

**步骤：**
1. 在测试关卡放置多种敌人（Orc + StandardEnemy + DemonSoldier + Imp）
2. 同时与 3+ 敌人战斗
3. 切换武器、收集掉落、使用铁鞭

**预期结果：** 各敌人 AI 独立运作，护甲独立，无交互 bug。

### 5.3 关卡切换

**步骤：**
1. 从荒漠关卡切换到熔岩关卡
2. 确认旧关卡敌人/掉落物被清理
3. 新关卡雾颜色/敌人正确

**预期结果：** 关卡切换无残留节点，无报错。

---

## 6. 回归测试检查表

| # | 测试项 | 状态 |
|---|--------|------|
| 1 | 步枪全自动 + 弹道线 | ⬜ |
| 2 | 霰弹枪 8 弹丸 + 泵动 | ⬜ |
| 3 | 手枪无限弹药 | ⬜ |
| 4 | 拳头 2m 近战 | ⬜ |
| 5 | 铁鞭 7 状态 FSM 完整连招 | ⬜ |
| 6 | 4 槽位切换 (1/2/3/4 + 滚轮) | ⬜ |
| 7 | X 字准星命中反馈 | ⬜ |
| 8 | 伤害数字飘升 | ⬜ |
| 9 | 屏幕震动 | ⬜ |
| 10 | 掉落物弹起 + 30s 消失 | ⬜ |
| 11 | 弹药智能跳过无限武器 | ⬜ |
| 12 | 圈外深度雾 (3 关不同颜色) | ⬜ |
| 13 | 主菜单/暂停/选关/结算 | ⬜ |
| 14 | OrcEnemy 攻击/防御/倒地 | ⬜ |
| 15 | StandardEnemy 跳跃三段式 | ⬜ |
| 16 | DemonSoldier hitscan 攻击 | ⬜ |
| 17 | Imp 火球 + 近战 | ⬜ |
| 18 | 盾牌格挡（抓取敌人后挡伤害） | ⬜ |
| 19 | Wave 波次系统 | ⬜ |
| 20 | 受击方向指示器 | ⬜ |
| 21 | 小地图 | ⬜ |

---

## 7. 已知残留问题

1. **Godot MCP `validate_script` 误报** — 大量脚本报 line 0 语法错，`analyze_script` 和实际运行正常
2. **CSGBox3D 调试条偏暗** — 敌人头顶血条/眩晕条在无直接光照下材质偏暗
3. **`drop_manager.gd`** — 创建在 Main 节点下而非 Level 下，关卡卸载时需手动 queue_free
4. **`_sight_ray` 死节点** — `enemy.gd` 中 `_sight_ray`（RayCast3D）创建后从未使用
5. **`_can_see_player()` 死代码** — 完整视线检测函数，但从未被调用（敌人穿墙感知）
6. **`weapon_data.current_ammo` 无用字段** — Resource 上定义了但从未使用，易误导
7. **`pickup.gd` 用 `body.name == "Player"` 检测玩家** — 重命名 Player 节点会导致掉落物失效
8. **投射物挂在 `get_tree().root`** — 关卡卸载时投射物不被清理（除非 lifetime 到期）

---

## 8. 性能基准

| 指标 | 目标值 | 实际值 |
|------|--------|--------|
| FPS（单人+10敌） | ≥60 | ⬜ |
| FPS（20+敌人） | ≥30 | ⬜ |
| 内存（静态） | <200MB | ⬜ |
| 掉落物上限 | <50 同时存在 | ⬜ |
