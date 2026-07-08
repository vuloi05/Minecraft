extends "res://scripts/entities/mobs/passive_mob.gd"
class_name PigMob

func _ready():
	move_speed = 1.5
	super._ready()

func build_model():
	var model_scene = load("res://assets/models/minecraft_-_pig.glb")
	if model_scene:
		var model = model_scene.instantiate()
		mesh_root.add_child(model)
		model.scale = Vector3(0.0625, 0.0625, 0.0625)
		model.rotation_degrees.y = 180 # Thử xoay 180 độ
		model.position.y = 0.45 

func setup_collision():
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.9, 0.9, 0.9)
	collision.shape = shape
	collision.position = Vector3(0, 0.45, 0)
