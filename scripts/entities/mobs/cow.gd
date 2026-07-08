extends "res://scripts/entities/mobs/passive_mob.gd"
class_name CowMob

func _ready():
	move_speed = 1.2
	super._ready()

func build_model():
	var model_scene = load("res://assets/models/minecraft_-_cow.glb")
	if model_scene:
		var model = model_scene.instantiate()
		mesh_root.add_child(model)
		model.scale = Vector3(0.0625, 0.0625, 0.0625)
		model.rotation_degrees.y = 180
		model.position.y = 0.7

func setup_collision():
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.9, 1.4, 0.9)
	collision.shape = shape
	collision.position = Vector3(0, 0.7, 0)
