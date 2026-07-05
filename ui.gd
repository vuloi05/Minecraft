extends CanvasLayer

@onready var hp_bar = $Control/HBoxContainer/HPBar
@onready var hunger_bar = $Control/HBoxContainer/HungerBar
@onready var inventory_label = $Control/Hotbar/ItemCount
@onready var hp_label = $Control/HBoxContainer/HPBar/Label
@onready var hunger_label = $Control/HBoxContainer/HungerBar/Label

var crafting_panel: Panel
var btn_plank: Button
var btn_pickaxe: Button

signal craft_requested(item_name)

func _ready():
	# Đổi màu ProgressBar bằng code
	hp_bar.modulate = Color(1.0, 0.2, 0.2)
	hunger_bar.modulate = Color(1.0, 0.6, 0.0)
	
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
	
	btn_plank = Button.new()
	btn_plank.text = "Chế tạo Ván gỗ (Cần 1 Gỗ -> 4 Ván)"
	btn_plank.pressed.connect(func(): emit_signal("craft_requested", "plank"))
	vbox.add_child(btn_plank)
	
	btn_pickaxe = Button.new()
	btn_pickaxe.text = "Chế tạo Cuốc chim (Cần 2 Ván)"
	btn_pickaxe.pressed.connect(func(): emit_signal("craft_requested", "pickaxe"))
	vbox.add_child(btn_pickaxe)
	# ----------------------------------------

func update_hp(hp: int):
	hp_bar.value = hp
	hp_label.text = "HP: " + str(hp) + "/20"

func update_hunger(hunger: int):
	hunger_bar.value = hunger
	hunger_label.text = "Đói: " + str(hunger) + "/20"

func toggle_crafting():
	crafting_panel.visible = !crafting_panel.visible
	if crafting_panel.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func update_inventory(rocks: int, woods: int, planks: int, has_pickaxe: bool, selected: int):
	var text = "Đá: %d | Gỗ: %d | Ván: %d" % [rocks, woods, planks]
	if has_pickaxe: text += " | [CUỐC]"
	
	var sel_text = "Đá"
	if selected == 2: sel_text = "Gỗ"
	elif selected == 4: sel_text = "Ván"
	elif selected == 5: sel_text = "Đuốc"
	text += " (Đang cầm: %s)" % sel_text
	
	inventory_label.text = text
