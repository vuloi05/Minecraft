extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var block_scene = preload("res://Block.tscn")

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
			
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			var hit_point = raycast.get_collision_point()
			var hit_normal = raycast.get_collision_normal()
			var world_node = get_tree().root.get_node("Main/World")
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Xóa khối: lùi vào trong khối bị click
				var block_pos = hit_point - hit_normal * 0.5
				var grid_pos = Vector3(round(block_pos.x), round(block_pos.y), round(block_pos.z))
				world_node.set_block(grid_pos, 0)
				
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				# Đặt khối: tiến ra ngoài bề mặt click
				var block_pos = hit_point + hit_normal * 0.5
				var grid_pos = Vector3(round(block_pos.x), round(block_pos.y), round(block_pos.z))
				world_node.set_block(grid_pos, 1)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
	input_dir = input_dir.normalized()

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
