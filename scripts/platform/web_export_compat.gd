extends Node

## Web 平台材质兼容：将 StandardMaterial3D 切换到 UNSHADED 模式
## 补偿 Compatibility 渲染器光照损失，保持 DOOM 风格纯色外观

func _ready() -> void:
	if not _is_compatibility_renderer():
		return
	# 延迟一帧等待场景完全加载
	await get_tree().process_frame
	_convert_all_materials(get_tree().root)

func _is_compatibility_renderer() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"

func _convert_all_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			_convert_material(mi.get_surface_override_material(i))
		_convert_material(mi.material_override)

	for child in node.get_children():
		_convert_all_materials(child)

func _convert_material(mat: Material) -> void:
	if mat == null:
		return
	if mat is StandardMaterial3D:
		var sm := mat as StandardMaterial3D
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif mat is ShaderMaterial:
		push_warning("WebExportCompat: ShaderMaterial 在 Compatibility 渲染器下可能无法正常显示: %s" % mat.resource_path)
