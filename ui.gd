extends CanvasLayer

var health_label: Label
var hunger_label: Label
var mine_progress: ProgressBar

var hud: Control
var loading_panel: ColorRect
var loading_label: Label

var inventory_panel: Panel
var inv_data = [] # Mảng 41 ô đồ {id, count}
var inv_slots = [] # Các ô UI trong túi đồ
var hud_hotbar_slots = [] # 9 ô UI dưới HUD

var selected_hotbar_index = 0

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
	inventory_panel = Panel.new()
	inventory_panel.custom_minimum_size = Vector2(600, 400)
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.visible = false
	$Control.add_child(inventory_panel)
	
	var inv_vbox = VBoxContainer.new()
	inv_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	inv_vbox.add_theme_constant_override("separation", 20)
	inventory_panel.add_child(inv_vbox)
	
	# Phần trên: Chế tạo
	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 50)
	inv_vbox.add_child(top_hbox)
	
	var craft_grid = GridContainer.new()
	craft_grid.columns = 2
	top_hbox.add_child(craft_grid)
	
	# Index 36-39
	for i in range(36, 40):
		var slot = InventorySlot.new(i, "craft", self)
		inv_slots.append(slot)
		craft_grid.add_child(slot)
		
	var arrow = Label.new()
	arrow.text = "➡"
	arrow.add_theme_font_size_override("font_size", 30)
	top_hbox.add_child(arrow)
	
	var res_slot = InventorySlot.new(40, "result", self)
	inv_slots.append(res_slot)
	top_hbox.add_child(res_slot)
	
	# Phần dưới: Túi đồ chính
	var main_grid = GridContainer.new()
	main_grid.columns = 9
	inv_vbox.add_child(main_grid)
	
	# Index 9-35
	for i in range(9, 36):
		var slot = InventorySlot.new(i, "main", self)
		inv_slots.append(slot)
		main_grid.add_child(slot)
		
	# Index 0-8 (Hotbar trong túi)
	var inv_hotbar = HBoxContainer.new()
	inv_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
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
	loading_label.text = "Đang tạo thế giới...\n0%"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 24)
	loading_panel.add_child(loading_label)
	
	select_hotbar(0)

func update_slot(idx: int, id: int, count: int):
	inv_data[idx].id = id
	inv_data[idx].count = count
	if inv_slots[idx]: inv_slots[idx].update_item(id, count)
	if idx < 9: hud_hotbar_slots[idx].update_item(id, count)
	
	if idx >= 36 and idx <= 39:
		check_crafting()

func check_crafting():
	var c = []
	for i in range(36, 40): c.append(inv_data[i].id)
	
	var r_id = 0
	var r_count = 0
	
	var woods = c.count(2)
	var planks = c.count(3)
	var empty = c.count(0)
	
	if woods == 1 and empty == 3: # Gỗ -> 4 Ván
		r_id = 3
		r_count = 4
	elif planks == 2 and empty == 2:
		# Check nếu ván xếp dọc (VD: 36, 38 hoặc 37, 39)
		if (c[0]==3 and c[2]==3) or (c[1]==3 and c[3]==3):
			r_id = 6 # Tạm dùng gậy/cuốc là 6 (Cuốc gỗ)
			r_count = 1
			
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

# --- DRAG & DROP CALLBACKS ---
func on_drag_start(idx: int, take_count: int):
	if idx == 40: # Rút đồ từ Crafting Result
		var id = inv_data[idx].id
		var count = inv_data[idx].count
		# Giảm đồ trong lưới
		for i in range(36, 40):
			if inv_data[i].count > 0:
				update_slot(i, inv_data[i].id, inv_data[i].count - 1)
		# Ô 40 sẽ tự động cập nhật qua check_crafting
	else:
		update_slot(idx, inv_data[idx].id, inv_data[idx].count - take_count)

func on_drop(data: Dictionary, target_idx: int):
	var src = data.source_index
	var id = data.id
	var c = data.count
	
	if target_idx == 40: # Không thể thả vào ô Result
		update_slot(src, inv_data[src].id, inv_data[src].count + c)
		return
		
	# Nếu ô đích trống
	if inv_data[target_idx].id == 0:
		update_slot(target_idx, id, c)
	# Nếu ô đích cùng loại
	elif inv_data[target_idx].id == id:
		var total = inv_data[target_idx].count + c
		if total <= 64:
			update_slot(target_idx, id, total)
		else:
			update_slot(target_idx, id, 64)
			var dư = total - 64
			# Trả về gốc
			update_slot(src, id, inv_data[src].count + dư)
	# Nếu ô đích khác loại (Swap)
	else:
		var old_id = inv_data[target_idx].id
		var old_c = inv_data[target_idx].count
		update_slot(target_idx, id, c)
		# Swap đồ về ô gốc
		# Nếu ô gốc là Result (40) thì ko swap đc, ném ra ngoài (tạm thời nhét vào túi)
		if src == 40:
			add_item(old_id, old_c)
		else:
			update_slot(src, old_id, inv_data[src].count + old_c)

func toggle_inventory():
	inventory_panel.visible = !inventory_panel.visible
	if inventory_panel.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
