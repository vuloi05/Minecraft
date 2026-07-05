extends CanvasLayer

var crafting_panel: Panel
var mine_progress: ProgressBar
signal craft_requested(item_name)

var health_label: Label
var hunger_label: Label
var hotbar_slots = []

func _ready():
	# --- MÀN HÌNH CHÍNH (HUD) ---
	var hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Control.add_child(hud)
	
	# Container chính ở giữa dưới màn hình
	var bottom_center = VBoxContainer.new()
	bottom_center.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_center.position = Vector2(-200, -90)
	bottom_center.custom_minimum_size = Vector2(400, 60)
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom_center)
	
	# Hàng 1: Máu và Đói
	var stats_row = HBoxContainer.new()
	stats_row.custom_minimum_size = Vector2(400, 20)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(stats_row)
	
	health_label = Label.new()
	health_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	health_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
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
	hunger_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hunger_label.add_theme_constant_override("outline_size", 4)
	hunger_label.add_theme_font_size_override("font_size", 20)
	hunger_label.text = "🍖🍖🍖🍖🍖🍖🍖🍖🍖🍖"
	stats_row.add_child(hunger_label)
	
	# Hàng 2: Hotbar
	var hotbar_row = HBoxContainer.new()
	hotbar_row.custom_minimum_size = Vector2(400, 40)
	hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_row.add_theme_constant_override("separation", 4)
	hotbar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_center.add_child(hotbar_row)
	
	for i in range(5): # 5 ô đồ
		var slot = ColorRect.new()
		slot.custom_minimum_size = Vector2(44, 44)
		slot.color = Color(0.2, 0.2, 0.2, 0.8)
		
		var border = ReferenceRect.new()
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.border_color = Color(0.1, 0.1, 0.1)
		border.border_width = 2.0
		border.editor_only = false
		slot.add_child(border)
		
		var item_label = Label.new()
		item_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_label.add_theme_font_size_override("font_size", 12)
		slot.add_child(item_label)
		
		hotbar_slots.append({"rect": slot, "border": border, "label": item_label})
		hotbar_row.add_child(slot)
	
	# --- TẠO GIAO DIỆN CHẾ TẠO (CRAFTING) ---
	crafting_panel = Panel.new()
	crafting_panel.custom_minimum_size = Vector2(400, 300)
	crafting_panel.set_anchors_preset(Control.PRESET_CENTER)
	crafting_panel.visible = false
	crafting_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	$Control.add_child(crafting_panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	crafting_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "CHẾ TẠO (CRAFTING)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var btn_plank = Button.new()
	btn_plank.text = "Chế tạo Ván gỗ (Cần 1 Gỗ -> 4 Ván)"
	btn_plank.pressed.connect(func(): emit_signal("craft_requested", "plank"))
	vbox.add_child(btn_plank)
	
	var btn_pickaxe = Button.new()
	btn_pickaxe.text = "Chế tạo Cuốc chim (Cần 2 Ván)"
	btn_pickaxe.pressed.connect(func(): emit_signal("craft_requested", "pickaxe"))
	vbox.add_child(btn_pickaxe)
	
	# --- TẠO THANH TIẾN ĐỘ ĐÀO KHỐI ---
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
	$Control.add_child(mine_progress)

func toggle_crafting():
	crafting_panel.visible = !crafting_panel.visible
	if crafting_panel.visible:
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

func update_inventory(rocks: int, woods: int, planks: int, has_pickaxe: bool, selected: int):
	hotbar_slots[0].label.text = "Đá\n" + str(rocks)
	hotbar_slots[1].label.text = "Gỗ\n" + str(woods)
	hotbar_slots[2].label.text = "Ván\n" + str(planks)
	hotbar_slots[3].label.text = "Đuốc\n∞"
	hotbar_slots[4].label.text = "Cuốc\n" + ("(Có)" if has_pickaxe else "(0)")
	
	var map_sel = {1: 0, 2: 1, 4: 2, 5: 3}
	var sel_idx = map_sel.get(selected, 0)
	
	for i in range(5):
		if i == sel_idx:
			hotbar_slots[i].border.border_color = Color(1, 1, 1)
			hotbar_slots[i].border.border_width = 3.0
		else:
			hotbar_slots[i].border.border_color = Color(0.1, 0.1, 0.1)
			hotbar_slots[i].border.border_width = 2.0

func update_mining_ui(progress: float, total: float):
	if progress > 0:
		mine_progress.visible = true
		mine_progress.max_value = total
		mine_progress.value = progress
	else:
		mine_progress.visible = false
