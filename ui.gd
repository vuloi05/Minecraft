extends CanvasLayer

var health_label: Label
var hunger_label: Label
var mine_progress: ProgressBar

var hud: Control
var loading_panel: ColorRect
var loading_label: Label

var inventory_overlay: ColorRect
var inventory_panel: PanelContainer
var inv_data = [] # Mảng 41 ô đồ {id, count}
var inv_slots = [] # Các ô UI trong túi đồ
var hud_hotbar_slots = [] # 9 ô UI dưới HUD

var selected_hotbar_index = 0
var held_item = {"id": 0, "count": 0}
var cursor_item: Label

func _ready():
	# Khởi tạo data trống
	for i in range(41):
		inv_data.append({"id": 0, "count": 0})
		
	# --- MÀN HÌNH CHÍNH (HUD) ---
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	$Control.add_child(hud)
	
	var bottom_center = VBoxContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_center.position = Vector2(-250, -90)
	bottom_center.custom_minimum_size = Vector2(500, 60)
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom_center)
	
	var stats_row = HBoxContainer.new()
	stats_row.custom_minimum_size = Vector2(500, 20)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(stats_row)
	
	health_label = Label.new()
	health_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	health_label.add_theme_constant_override("outline_size", 4)
	health_label.add_theme_font_size_override("font_size", 20)
	health_label.text = "♥♥♥♥♥♥♥♥♥♥"
	stats_row.add_child(health_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_row.add_child(spacer)
	
	hunger_label = Label.new()
	hunger_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.1))
	hunger_label.add_theme_constant_override("outline_size", 4)
	hunger_label.add_theme_font_size_override("font_size", 20)
	hunger_label.text = "🍖🍖🍖🍖🍖🍖🍖🍖🍖🍖"
	stats_row.add_child(hunger_label)
	
	var hotbar_row = HBoxContainer.new()
	hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(hotbar_row)
	
	for i in range(9):
		var slot = InventorySlot.new(i, "hud_hotbar", self)
		hud_hotbar_slots.append(slot)
		hotbar_row.add_child(slot)
		
	mine_progress = ProgressBar.new()
	mine_progress.custom_minimum_size = Vector2(100, 10)
	mine_progress.set_anchors_preset(Control.PRESET_CENTER)
	mine_progress.offset_left = -50
	mine_progress.offset_right = 50
	mine_progress.offset_top = 20
	mine_progress.offset_bottom = 30
	mine_progress.show_percentage = false
	mine_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mine_progress.visible = false
	hud.add_child(mine_progress)
	
	# --- MÀN HÌNH TÚI ĐỒ (INVENTORY) ---
	inventory_overlay = ColorRect.new()
	inventory_overlay.color = Color(0, 0, 0, 0.5) # Làm tối màn hình đằng sau
	inventory_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.visible = false
	$Control.add_child(inventory_overlay)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.add_child(center_container)
	
	inventory_panel = PanelContainer.new()
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#C6C6C6")
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color("#373737")
	inventory_panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(inventory_panel)
	
	var margin_c = MarginContainer.new()
	margin_c.add_theme_constant_override("margin_left", 20)
	margin_c.add_theme_constant_override("margin_right", 20)
	margin_c.add_theme_constant_override("margin_top", 20)
	margin_c.add_theme_constant_override("margin_bottom", 20)
	inventory_panel.add_child(margin_c)
	
	var inv_vbox = VBoxContainer.new()
	inv_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inv_vbox.add_theme_constant_override("separation", 16)
	margin_c.add_child(inv_vbox)
	
	# Phần trên: Chế tạo
	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_END # Ép sát qua phải
	top_hbox.add_theme_constant_override("separation", 24)
	inv_vbox.add_child(top_hbox)
	
	var craft_vbox = VBoxContainer.new()
	craft_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(craft_vbox)
	
	var craft_label = Label.new()
	craft_label.text = "Crafting"
	craft_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	craft_vbox.add_child(craft_label)
	
	var craft_grid = GridContainer.new()
	craft_grid.columns = 2
	craft_grid.add_theme_constant_override("h_separation", 2)
	craft_grid.add_theme_constant_override("v_separation", 2)
	craft_vbox.add_child(craft_grid)
	
	# Index 36-39
	for i in range(36, 40):
		var slot = InventorySlot.new(i, "craft", self)
		inv_slots.append(slot)
		craft_grid.add_child(slot)
		
	var arrow = Label.new()
	arrow.text = "➡"
	arrow.add_theme_font_size_override("font_size", 30)
	arrow.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	top_hbox.add_child(arrow)
	
	var res_slot = InventorySlot.new(40, "result", self)
	inv_slots.append(res_slot)
	top_hbox.add_child(res_slot)
	
	# Phần dưới: Túi đồ chính
	var main_grid = GridContainer.new()
	main_grid.columns = 9
	main_grid.add_theme_constant_override("h_separation", 4)
	main_grid.add_theme_constant_override("v_separation", 4)
	inv_vbox.add_child(main_grid)
	
	# Index 9-35
	for i in range(9, 36):
		var slot = InventorySlot.new(i, "main", self)
		inv_slots.append(slot)
		main_grid.add_child(slot)
		
	# Khoảng hở nhỏ giữa túi chính và túi nhanh (Hotbar)
	var inv_spacer = Control.new()
	inv_spacer.custom_minimum_size = Vector2(0, 10)
	inv_vbox.add_child(inv_spacer)
	
	# Index 0-8 (Hotbar trong túi)
	var inv_hotbar = GridContainer.new()
	inv_hotbar.columns = 9
	inv_hotbar.add_theme_constant_override("h_separation", 4)
	inv_hotbar.add_theme_constant_override("v_separation", 4)
	inv_vbox.add_child(inv_hotbar)
	
	# Phải sort array inv_slots cho đúng index để dễ truy cập
	var temp_inv_slots = []
	for i in range(41): temp_inv_slots.append(null)
	
	for i in range(9):
		var slot = InventorySlot.new(i, "main", self)
		temp_inv_slots[i] = slot
		inv_hotbar.add_child(slot)
		
	for i in range(9, 36): temp_inv_slots[i] = inv_slots[i-9]
	for i in range(36, 40): temp_inv_slots[i] = inv_slots[i-9]
	temp_inv_slots[40] = inv_slots[31]
	
	inv_slots = temp_inv_slots
	
	# --- MÀN HÌNH LOADING ---
	loading_panel = ColorRect.new()
	loading_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_panel.color = Color(0.12, 0.1, 0.08)
	$Control.add_child(loading_panel)
	
	loading_label = Label.new()
	loading_label.set_anchors_preset(Control.PRESET_CENTER)
	loading_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loading_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	loading_label.text = "Đang tạo thế giới...\n0%"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 24)
	loading_panel.add_child(loading_label)
	
	cursor_item = Label.new()
	cursor_item.add_theme_font_size_override("font_size", 32)
	cursor_item.add_theme_constant_override("outline_size", 4)
	cursor_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_item.z_index = 100
	cursor_item.visible = false
	$Control.add_child(cursor_item)
	
	select_hotbar(0)

func _process(delta):
	if cursor_item.visible:
		cursor_item.global_position = get_viewport().get_mouse_position() + Vector2(10, 10)

func update_slot(idx: int, id: int, count: int):
	inv_data[idx].id = id
	inv_data[idx].count = count
	if inv_slots[idx]: inv_slots[idx].update_item(id, count)
	if idx < 9: hud_hotbar_slots[idx].update_item(id, count)
	
	if idx >= 36 and idx <= 39:
		check_crafting()

var crafting_recipes = [
	# Gỗ -> 4 Ván (có thể đặt ở 4 góc)
	{ "input": [2, 0, 0, 0], "output": 3, "count": 4 },
	{ "input": [0, 2, 0, 0], "output": 3, "count": 4 },
	{ "input": [0, 0, 2, 0], "output": 3, "count": 4 },
	{ "input": [0, 0, 0, 2], "output": 3, "count": 4 },
	# 2 Ván (dọc) -> 4 Que
	{ "input": [3, 0, 3, 0], "output": 9, "count": 4 },
	{ "input": [0, 3, 0, 3], "output": 9, "count": 4 },
	# 4 Ván -> 1 Bàn chế tạo
	{ "input": [3, 3, 3, 3], "output": 10, "count": 1 },
	# Ván + Que -> 1 Cuốc gỗ (Ván trên, Que dưới)
	{ "input": [3, 0, 9, 0], "output": 11, "count": 1 },
	{ "input": [0, 3, 0, 9], "output": 11, "count": 1 },
	# Đá + Que -> 1 Cuốc đá (Đá trên, Que dưới)
	{ "input": [7, 0, 9, 0], "output": 6, "count": 1 },
	{ "input": [0, 7, 0, 9], "output": 6, "count": 1 }
]

func check_crafting():
	var c = []
	for i in range(36, 40): c.append(inv_data[i].id)
	
	var r_id = 0
	var r_count = 0
	
	for recipe in crafting_recipes:
		var match_all = true
		for i in range(4):
			if c[i] != recipe["input"][i]:
				match_all = false
				break
		if match_all:
			r_id = recipe["output"]
			r_count = recipe["count"]
			break
			
	# Update ô 40 nhưng không gọi lại check_crafting (tránh lặp vô hạn)
	inv_data[40].id = r_id
	inv_data[40].count = r_count
	inv_slots[40].update_item(r_id, r_count)

func add_item(id: int, count: int) -> int:
	var remain = count
	# 1. Cộng dồn vào stack cũ
	for i in range(36):
		if inv_data[i].id == id and inv_data[i].count < 64:
			var add = min(remain, 64 - inv_data[i].count)
			update_slot(i, id, inv_data[i].count + add)
			remain -= add
			if remain == 0: return 0
			
	# 2. Bỏ vào ô trống
	for i in range(36):
		if inv_data[i].id == 0:
			var add = min(remain, 64)
			update_slot(i, id, add)
			remain -= add
			if remain == 0: return 0
			
	return remain # Đầy túi

func get_selected_item_id() -> int:
	return inv_data[selected_hotbar_index].id

func consume_selected_item():
	if inv_data[selected_hotbar_index].count > 0:
		update_slot(selected_hotbar_index, inv_data[selected_hotbar_index].id, inv_data[selected_hotbar_index].count - 1)

func select_hotbar(idx: int):
	selected_hotbar_index = clamp(idx, 0, 8)
	for i in range(9):
		if i == selected_hotbar_index:
			hud_hotbar_slots[i].border.border_color = Color(1, 1, 1)
			hud_hotbar_slots[i].border.border_width = 3.0
		else:
			hud_hotbar_slots[i].border.border_color = Color(0.1, 0.1, 0.1)
			hud_hotbar_slots[i].border.border_width = 2.0

# --- CLICK TO HOLD (NEW LOGIC) ---
func on_slot_clicked(idx: int, button: int):
	var is_left = (button == MOUSE_BUTTON_LEFT)
	var is_right = (button == MOUSE_BUTTON_RIGHT)
	if not is_left and not is_right: return
	
	var s_id = inv_data[idx].id
	var s_count = inv_data[idx].count
	var h_id = held_item.id
	var h_count = held_item.count
	
	if idx == 40: # Ô Result
		if s_id != 0:
			if h_id == 0 or (h_id == s_id and h_count + s_count <= 64):
				# Lấy đồ
				held_item.id = s_id
				held_item.count = h_count + s_count
				# Giảm nguyên liệu
				for i in range(36, 40):
					if inv_data[i].count > 0:
						update_slot(i, inv_data[i].id, inv_data[i].count - 1)
				update_cursor()
		return
		
	if h_id == 0:
		# Đang tay không
		if s_id != 0:
			if is_left: # Nhấc hết
				held_item.id = s_id
				held_item.count = s_count
				update_slot(idx, 0, 0)
			elif is_right: # Nhấc một nửa
				var half = ceil(float(s_count) / 2.0)
				var left = s_count - half
				held_item.id = s_id
				held_item.count = half
				update_slot(idx, s_id, left)
	else:
		# Đang cầm đồ
		if s_id == 0:
			if is_left: # Đặt hết
				update_slot(idx, h_id, h_count)
				held_item.id = 0
				held_item.count = 0
			elif is_right: # Đặt 1
				update_slot(idx, h_id, 1)
				held_item.count -= 1
				if held_item.count <= 0: held_item.id = 0
		elif s_id == h_id:
			if is_left: # Gộp hết
				var space = 64 - s_count
				var add = min(space, h_count)
				update_slot(idx, h_id, s_count + add)
				held_item.count -= add
				if held_item.count <= 0: held_item.id = 0
			elif is_right: # Gộp 1
				if s_count < 64:
					update_slot(idx, h_id, s_count + 1)
					held_item.count -= 1
					if held_item.count <= 0: held_item.id = 0
		else:
			if is_left: # Hoán đổi (Swap)
				update_slot(idx, h_id, h_count)
				held_item.id = s_id
				held_item.count = s_count
				
	update_cursor()

func update_cursor():
	if held_item.id != 0 and held_item.count > 0:
		cursor_item.visible = true
		cursor_item.text = inv_slots[0].get_icon(held_item.id) + ("\n" + str(held_item.count) if held_item.count > 1 else "")
	else:
		cursor_item.visible = false
		held_item.id = 0
		held_item.count = 0

func toggle_inventory():
	inventory_overlay.visible = !inventory_overlay.visible
	if inventory_overlay.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		# Vứt đồ lại vào túi nếu đóng túi mà vẫn đang cầm
		if held_item.id != 0:
			add_item(held_item.id, held_item.count)
			held_item.id = 0
			held_item.count = 0
			update_cursor()

func update_hp(hp: int):
	var full = int(ceil(hp / 2.0))
	var empty = 10 - full
	var text = ""
	for i in range(full): text += "♥"
	for i in range(empty): text += "♡"
	health_label.text = text

func update_hunger(hunger: int):
	var full = int(ceil(hunger / 2.0))
	var empty = 10 - full
	var text = ""
	for i in range(full): text += "🍖"
	for i in range(empty): text += "🦴"
	hunger_label.text = text

func update_loading(percent: int):
	loading_label.text = "Đang tạo thế giới...\n" + str(percent) + "%"

func finish_loading():
	loading_panel.visible = false
	hud.visible = true

func update_mining_ui(progress: float, total: float):
	if progress > 0:
		mine_progress.visible = true
		mine_progress.max_value = total
		mine_progress.value = progress
	else:
		mine_progress.visible = false
