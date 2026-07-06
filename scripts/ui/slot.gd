extends ColorRect
class_name InventorySlot

var slot_index = 0
var slot_type = "main" # "main", "craft", "result"
var item_id = 0
var item_count = 0
var ui_node: Node

var label: Label
var count_label: Label
var border: ReferenceRect

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
	
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	
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
		label.text = ""
		count_label.text = ""
		item_id = 0
		item_count = 0
		tooltip_text = ""
	else:
		label.text = get_icon(id)
		count_label.text = str(count) if count > 1 else ""
		tooltip_text = get_item_name(id)

func get_item_name(id: int) -> String:
	match id:
		1: return "Cỏ"
		2: return "Khúc Gỗ"
		3: return "Ván Gỗ"
		4: return "Lá Cây"
		5: return "Đuốc"
		6: return "Cúp Đá"
		7: return "Đá"
		8: return "Đất"
		9: return "Que"
		10: return "Bàn Chế Tạo"
		11: return "Cúp Gỗ"
	return "Unknown"

func get_icon(id: int) -> String:
	match id:
		1: return "🟩" # Cỏ
		2: return "🪵" # Gỗ
		3: return "🟫" # Ván
		4: return "🌿" # Lá
		5: return "🔦" # Đuốc
		6: return "⛏️" # Cuốc chim (Đá)
		7: return "🪨" # Đá
		8: return "🟫" # Đất
		9: return "🦯" # Que
		10: return "🧰" # Bàn chế tạo
		11: return "🪓" # Cuốc gỗ
	return ""

# --- CLICK TO HOLD ---
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if ui_node and ui_node.has_method("on_slot_clicked"):
			ui_node.on_slot_clicked(slot_index, event.button_index)
