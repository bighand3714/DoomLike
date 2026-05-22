class_name TouchButtonPainter extends RefCounted

## 静态工具类：代码生成虚拟按钮的 ImageTexture，避免外部纹理依赖

static func create_circle_texture(size: int, color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center: float = size / 2.0
	var radius: float = center - 1.0
	for y in size:
		for x in size:
			var dist := Vector2(x - center, y - center).length()
			if dist <= radius:
				var border_inner := radius - border_width
				if border_width > 0 and dist >= border_inner:
					var t := clampf((dist - border_inner) / border_width, 0.0, 1.0)
					image.set_pixel(x, y, color.lerp(border_color, t))
				else:
					image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func create_rect_texture(width: int, height: int, color: Color, corner_radius: int = 0) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in height:
		for x in width:
			var in_corner := false
			if corner_radius > 0:
				# 上左
				if x < corner_radius and y < corner_radius:
					var dist := Vector2(x - corner_radius, y - corner_radius).length()
					in_corner = dist > corner_radius
				# 上右
				elif x >= width - corner_radius and y < corner_radius:
					var dist := Vector2(x - (width - corner_radius), y - corner_radius).length()
					in_corner = dist > corner_radius
				# 下左
				elif x < corner_radius and y >= height - corner_radius:
					var dist := Vector2(x - corner_radius, y - (height - corner_radius)).length()
					in_corner = dist > corner_radius
				# 下右
				elif x >= width - corner_radius and y >= height - corner_radius:
					var dist := Vector2(x - (width - corner_radius), y - (height - corner_radius)).length()
					in_corner = dist > corner_radius
			if not in_corner:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func create_weapon_icon(weapon_index: int, color: Color) -> ImageTexture:
	# 武器编号图标：简单的数字形状（用 32×32 矩形 + 圆角表示）
	return create_rect_texture(48, 48, Color(0.0, 0.0, 0.0, 0.5), 6)
