extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- SINH TỒN ---
var hp = 20
var hunger = 20
var inventory_rocks = 0

var hunger_timer = 0.0
const HUNGER_INTERVAL = 10.0 # 10 giây trừ 1 đói

var fall_start_y = 0.0
var was_on_floor = true

var ui: CanvasLayer
# ----------------

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
var world_node: Node3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	world_node = get_parent().get_node("World")
	if has_node("../UI"):
		ui = get_node("../UI")
		ui.update_hp(hp)
		ui.update_hunger(hunger)
		ui.update_inventory(inventory_rocks)

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
			var hit_point = raycast.get_collision_point()
			var hit_normal = raycast.get_collision_normal()
			
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Xóa khối: lùi vào trong khối bị click
				var block_pos = hit_point - hit_normal * 0.5
				var grid_pos = Vector3(round(block_pos.x), round(block_pos.y), round(block_pos.z))
				world_node.set_block(grid_pos, 0)
				
				# Nhặt đá
				inventory_rocks += 1
				if ui: ui.update_inventory(inventory_rocks)
				
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if inventory_rocks <= 0:
					print("Hết đá trong túi đồ!")
					return
				
				# Đặt khối: tiến ra ngoài bề mặt click
				var block_pos = hit_point + hit_normal * 0.5
				var grid_pos = Vector3(round(block_pos.x), round(block_pos.y), round(block_pos.z))
				
				# Kiểm tra va chạm: Không cho phép đặt khối đè lên vị trí của Player
				var p_pos = global_position
				var px_min = p_pos.x - 0.4; var px_max = p_pos.x + 0.4
				var py_min = p_pos.y;       var py_max = p_pos.y + 1.8
				var pz_min = p_pos.z - 0.4; var pz_max = p_pos.z + 0.4
				
				var bx_min = grid_pos.x - 0.5; var bx_max = grid_pos.x + 0.5
				var by_min = grid_pos.y - 0.5; var by_max = grid_pos.y + 0.5
				var bz_min = grid_pos.z - 0.5; var bz_max = grid_pos.z + 0.5
				
				if (px_min < bx_max and px_max > bx_min) and \
				   (py_min < by_max and py_max > by_min) and \
				   (pz_min < bz_max and pz_max > bz_min):
					print("Không thể đặt khối: Vị trí bị kẹt bởi Player!")
					return
					
				world_node.set_block(grid_pos, 1)
				inventory_rocks -= 1
				if ui: ui.update_inventory(inventory_rocks)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func take_damage(amount: int):
	hp -= amount
	if hp < 0: hp = 0
	if ui: ui.update_hp(hp)
	print("Mất máu! HP còn: ", hp)
	if hp == 0:
		print("BẠN ĐÃ CHẾT! Hồi sinh...")
		global_position = Vector3(8, 70, 8)
		hp = 20
		hunger = 20
		if ui:
			ui.update_hp(hp)
			ui.update_hunger(hunger)

func _physics_process(delta):
	# Xử lý đói
	hunger_timer += delta
	if hunger_timer >= HUNGER_INTERVAL:
		hunger_timer = 0.0
		if hunger > 0:
			hunger -= 1
			if ui: ui.update_hunger(hunger)
		else:
			take_damage(1) # Đói quá mất máu

	# Xử lý rơi (Fall damage)
	if not is_on_floor() and was_on_floor:
		fall_start_y = global_position.y
	
	if is_on_floor() and not was_on_floor:
		var fall_dist = fall_start_y - global_position.y
		if fall_dist > 4.0: # Rơi hơn 4 khối thì mất máu
			var damage = int(fall_dist - 3.0)
			take_damage(damage)

	was_on_floor = is_on_floor()

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
