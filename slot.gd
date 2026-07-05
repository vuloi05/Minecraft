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
	color = Color(0.2, 0.2, 0.2, 0.8)
	
	border = ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.1, 0.1, 0.1)
	border.border_width = 2.0
	border.editor_only = false
	add_child(border)
	
	label = Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	
	count_label = Label.new()
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.add_theme_constant_override("outline_size", 4)
	add_child(count_label)

func update_item(id: int, count: int):
	item_id = id
	item_count = count
	if id == 0 or count <= 0:
		label.text = ""
		count_label.text = ""
		item_id = 0
		item_count = 0
	else:
		label.text = get_icon(id)
		count_label.text = str(count) if count > 1 else ""

func get_icon(id: int) -> String:
	match id:
		1: return "🟩" # Cỏ
		2: return "🪵" # Gỗ
		3: return "🟫" # Ván
		4: return "🌿" # Lá
		5: return "🔦" # Đuốc
		6: return "⛏️" # Cuốc chim
		7: return "🪨" # Đá
		8: return "🟫" # Đất
	return ""

# --- DRAG AND DROP ---
func _get_drag_data(at_position):
	if item_id == 0: return null
	
	# Hỗ trợ chuột phải để chia đôi stack
	var is_right_click = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var take_count = item_count
	
	if is_right_click and item_count > 1:
		take_count = item_count / 2
		
	var data = {"source_index": slot_index, "source_type": slot_type, "id": item_id, "count": take_count}
	
	var preview = Label.new()
	preview.text = get_icon(item_id)
	preview.add_theme_font_size_override("font_size", 32)
	set_drag_preview(preview)
	
	if ui_node and ui_node.has_method("on_drag_start"):
		ui_node.on_drag_start(slot_index, take_count)
	
	return data

func _can_drop_data(at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("id") and slot_type != "result"

func _drop_data(at_position, data):
	if ui_node and ui_node.has_method("on_drop"):
		ui_node.on_drop(data, slot_index)
