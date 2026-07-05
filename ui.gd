extends CanvasLayer

@onready var hp_bar = $Control/HBoxContainer/HPBar
@onready var hunger_bar = $Control/HBoxContainer/HungerBar
@onready var inventory_label = $Control/Hotbar/ItemCount
@onready var hp_label = $Control/HBoxContainer/HPBar/Label
@onready var hunger_label = $Control/HBoxContainer/HungerBar/Label

func _ready():
	# Đổi màu ProgressBar bằng code (để đơn giản không cần tạo StyleBox)
	hp_bar.modulate = Color(1.0, 0.2, 0.2) # Màu đỏ cho Máu
	hunger_bar.modulate = Color(1.0, 0.6, 0.0) # Màu cam cho Đói

func update_hp(hp: int):
	hp_bar.value = hp
	hp_label.text = "HP: " + str(hp) + "/20"

func update_hunger(hunger: int):
	hunger_bar.value = hunger
	hunger_label.text = "Đói: " + str(hunger) + "/20"

func update_inventory(count: int):
	inventory_label.text = "Túi đồ - Đá: " + str(count)
