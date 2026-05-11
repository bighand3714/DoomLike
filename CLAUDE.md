# DoomLike - Godot 4.6 DOOM风格FPS游戏

## 项目概览

Godot 4.6 项目，正在构建一款DOOM风格的第一人称射击游戏。当前处于**第一阶段（原型搭建）**——核心移动已可运行，武器/敌人/地图编辑器等系统待实现。

- **引擎**：Godot 4.6 (Forward Plus, D3D12)
- **物理**：Jolt Physics
- **主场景**：`res://scenes/main.tscn`
- **窗口**：1280×720

## 目录结构

```
scripts/        GDScript 源代码
  main.gd           主游戏控制器（初始化、测试房间搭建、准星）
  player/           玩家相关（player_controller.gd）
  level/            关卡系统（level_data.gd 数据蓝图, level_builder.gd 建造器）
  editor/           编辑器模式切换（game_mode.gd）
  utils/            FPS计数器（fps_counter.gd）
scenes/         Godot 场景文件（main.tscn + 子场景占位目录）
assets/         游戏资源（audio/fonts/levels/textures，当前为空）
shaders/        自定义着色器（当前为空）
docs/           文档（当前为空）
```

## 场景树结构

```
Main (Node3D)                          ← main.gd
├── Player (CharacterBody3D)           ← player_controller.gd [%Player]
│   ├── Camera3D                       [%Camera3D]
│   ├── CollisionShape3D               (胶囊体: 半径0.4, 高1.8)
│   └── WeaponHolder (Node3D)
├── Level (Node3D)                     [%Level] ← 程序化CSG几何体生成位置
└── UI (CanvasLayer)
    ├── Crosshair (ColorRect)           [%Crosshair]
    └── FPS (Label)                     ← fps_counter.gd
```

## 输入映射

| 动作 | 键位 | 用途 |
|------|------|------|
| `move_forward/back/left/right` | WASD | 移动 |
| `jump` | Space | 跳跃 |
| `ui_cancel` | Escape | 释放/捕获鼠标 |

## 编码约定

- 注释使用**中文**
- 类名/枚举：`PascalCase`，变量/函数：`snake_case`，私有成员：`_前缀`
- 使用 `@export` 暴露可调参数到编辑器
- 使用 `%UniqueName` 引用场景节点（如 `%Player`、`%Level`）
- 类型注解：`func _ready() -> void`、`var speed: float = 8.0`

## 当前架构说明

- **无自动加载（Autoload）**，所有节点手动实例化
- **关卡管线未连接**：`LevelData`/`LevelBuilder` 已定义但未被 `main.gd` 调用，当前测试房间直接通过 `_build_test_room()` 硬编码 CSG 生成
- **无武器/敌人/伤害系统**，无投射物，无AI
- **编辑器模式切换器**（GameModeManager）已定义但未挂载到场景树
- 所有 assets 子目录为空

## 关键参数（player_controller.gd）

| 参数 | 值 | 说明 |
|------|-----|------|
| `move_speed` | 8.0 | 移动速度 (m/s) |
| `acceleration` | 40.0 | 加速度 |
| `friction` | 30.0 | 摩擦力 |
| `gravity` | 20.0 | 重力（比现实大，DOOM手感） |
| `jump_velocity` | 12.0 | 跳跃初速（约3.6米高） |
| `mouse_sensitivity` | 0.002 | 鼠标灵敏度 |
| `vertical_limit` | 90.0° | 垂直视角限制 |
