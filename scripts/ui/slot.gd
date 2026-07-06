extends ColorRect
class_name InventorySlot

var slot_index = 0
var slot_type = "main" # "main", "craft", "result"
var item_id = 0
var item_count = 0
var ui_node: Node

var icon_rect: TextureRect
var count_label: Label
var border: ReferenceRect
var block_view: Control

var is_block = false

func _init(idx: int, type: String, ui: Node):
	slot_index = idx
	slot_type = type
	ui_node = ui
	custom_minimum_size = Vector2(48, 48)
	color = Color("#373737") # Nền dưới cùng (viền tối ở trên-trái)
	
	var br = ColorRect.new()
	br.color = Color("#FFFFFF") # Viền sáng ở dưới-phải
	br.set_anchors_preset(Control.PRESET_FULL_RECT)
	br.offset_left = 2
	br.offset_top = 2
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br)
	
	var center = ColorRect.new()
	center.color = Color("#8B8B8B") # Màu nền chính giữa
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 2
	center.offset_top = 2
	center.offset_right = -2
	center.offset_bottom = -2
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.1, 0.1, 0.1, 0.0) # Ẩn viền đen mặc định
	border.border_width = 3.0
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)
	
	icon_rect = TextureRect.new()
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = Control.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_preset(Control.PRESET_CENTER)
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.offset_left = -16
	icon_rect.offset_top = -16
	icon_rect.offset_right = 16
	icon_rect.offset_bottom = 16
	add_child(icon_rect)
	
	block_view = Control.new()
	block_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	block_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_view.draw.connect(_on_block_view_draw)
	add_child(block_view)
	
	count_label = Label.new()
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_constant_override("outline_size", 4)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)

func update_item(id: int, count: int):
	item_id = id
	item_count = count
	if id == 0 or count <= 0:
		icon_rect.texture = null
		count_label.text = ""
		item_id = 0
		item_count = 0
		tooltip_text = ""
		is_block = false
		block_view.queue_redraw()
	else:
		var b_data = DataManager.get_block_data(id)
		if b_data and b_data.has("texture"):
			var tex_block = "res://assets/textures/blocks/" + b_data["texture"]
			var tex_item = "res://assets/textures/items/" + b_data["texture"]
			var tex = null
			
			if FileAccess.file_exists(tex_block) or FileAccess.file_exists(tex_block + ".import"):
				tex = load(tex_block)
			elif FileAccess.file_exists(tex_item) or FileAccess.file_exists(tex_item + ".import"):
				tex = load(tex_item)
				
			if tex != null:
				icon_rect.texture = tex
				is_block = not b_data.get("is_item", false)
				if is_block:
					icon_rect.hide()
				else:
					icon_rect.show()
			else:
				icon_rect.hide()
				is_block = false
		else:
			icon_rect.texture = null
			is_block = false
			
		count_label.text = str(count) if count > 1 else ""
		if b_data and b_data.has("display_name"):
			tooltip_text = b_data["display_name"]
			
		block_view.queue_redraw()

func _on_block_view_draw():
	if is_block:
		var tex = load("res://assets/textures/atlas.png") as Texture2D
		if not tex: return
		
		var uv_base = DataManager.get_block_uv(item_id)
		var uv_top = uv_base
		var uv_side = uv_base
		
		if item_id == 1: # Grass Block
			if DataManager.uv_map.has("grass_block_top"): uv_top = DataManager.uv_map["grass_block_top"]
			elif DataManager.uv_map.has("grass_block_side"): uv_top = DataManager.uv_map["grass_block_side"]
			if DataManager.uv_map.has("grass_block_side"): uv_side = DataManager.uv_map["grass_block_side"]
			
		var center = Vector2(size.x / 2, size.y / 2)
		var w = 12.0
		var h = 6.0
		
		var p_center = center
		var p_top = center + Vector2(0, -h*2)
		var p_bottom = center + Vector2(0, h*2)
		var p_left = center + Vector2(-w, -h)
		var p_right = center + Vector2(w, -h)
		var p_b_left = center + Vector2(-w, h)
		var p_b_right = center + Vector2(w, h)
		
		var c_top = Color(1.0, 1.0, 1.0)
		var c_left = Color(0.8, 0.8, 0.8)
		var c_right = Color(0.6, 0.6, 0.6)
		
		if item_id == 1: # Grass block tint
			c_top *= Color(0.4, 0.7, 0.3)
		elif item_id == 4: # Leaves tint
			var tint = Color(0.2, 0.55, 0.1)
			c_top *= tint; c_left *= tint; c_right *= tint
			
		var uvs_top = PackedVector2Array([Vector2(uv_top.u_min, uv_top.v_min), Vector2(uv_top.u_max, uv_top.v_min), Vector2(uv_top.u_max, uv_top.v_max), Vector2(uv_top.u_min, uv_top.v_max)])
		var uvs_side = PackedVector2Array([Vector2(uv_side.u_min, uv_side.v_min), Vector2(uv_side.u_max, uv_side.v_min), Vector2(uv_side.u_max, uv_side.v_max), Vector2(uv_side.u_min, uv_side.v_max)])
		
		# Draw Isometric Faces
		block_view.draw_polygon(PackedVector2Array([p_top, p_right, p_center, p_left]), PackedColorArray([c_top, c_top, c_top, c_top]), uvs_top, tex)
		block_view.draw_polygon(PackedVector2Array([p_left, p_center, p_bottom, p_b_left]), PackedColorArray([c_left, c_left, c_left, c_left]), uvs_side, tex)
		block_view.draw_polygon(PackedVector2Array([p_center, p_right, p_b_right, p_bottom]), PackedColorArray([c_right, c_right, c_right, c_right]), uvs_side, tex)

# --- CLICK TO HOLD ---
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if ui_node and ui_node.has_method("on_slot_clicked"):
			ui_node.on_slot_clicked(slot_index, event.button_index)
