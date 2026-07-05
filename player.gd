extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- SINH TỒN ---
var hp = 20
var hunger = 20
var inv_rocks = 0
var inv_woods = 0
var inv_planks = 0
var has_pickaxe = false
var selected_block = 1

var hunger_timer = 0.0
const HUNGER_INTERVAL = 10.0 # 10 giây trừ 1 đói

var fall_start_y = 0.0
var was_on_floor = true

var ui: CanvasLayer

var mine_timer = 0.0
var mining_pos = Vector3.ZERO
# ----------------

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
var world_node: Node3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	world_node = get_parent().get_node("World")
	
	respawn() # Khởi tạo vị trí và máu
	
	if has_node("../UI"):
		ui = get_node("../UI")
		ui.craft_requested.connect(_on_craft_requested)
		ui.call_deferred("update_hp", hp)
		ui.call_deferred("update_hunger", hunger)
		update_inv_ui()

func update_inv_ui():
	if ui: ui.call_deferred("update_inventory", inv_rocks, inv_woods, inv_planks, has_pickaxe, selected_block)

func _on_craft_requested(item: String):
	if item == "plank" and inv_woods >= 1:
		inv_woods -= 1
		inv_planks += 4
		print("Chế tạo thành công 4 Ván gỗ!")
	elif item == "pickaxe" and inv_planks >= 2 and not has_pickaxe:
		inv_planks -= 2
		has_pickaxe = true
		print("Chế tạo thành công Cuốc chim!")
	update_inv_ui()

func respawn():
	var spawn_x = 8.0
	var spawn_z = 8.0
	var terrain_y = 30.0
	
	if world_node and world_node.noise:
		terrain_y = float(int((world_node.noise.get_noise_2d(spawn_x, spawn_z) + 1.0) * 0.5 * 20) + 10)
		
	global_position = Vector3(spawn_x, terrain_y + 2.0, spawn_z)
	hp = 20
	hunger = 20
	fall_start_y = global_position.y
	was_on_floor = false
	
	if ui:
		ui.call_deferred("update_hp", hp)
		ui.call_deferred("update_hunger", hunger)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if not (ui and ui.crafting_panel.visible):
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
			
		if raycast.is_colliding() and event.button_index == MOUSE_BUTTON_RIGHT:
			var hit_point = raycast.get_collision_point()
			var hit_normal = raycast.get_collision_normal()
			
			if selected_block == 1 and inv_rocks <= 0: return
			if selected_block == 2 and inv_woods <= 0: return
			if selected_block == 4 and inv_planks <= 0: return
			
			var block_pos = hit_point + hit_normal * 0.5
			var grid_pos = Vector3(round(block_pos.x), round(block_pos.y), round(block_pos.z))
			
			# Kiểm tra va chạm Player
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
				return
				
			world_node.set_block(grid_pos, selected_block)
			if selected_block == 1: inv_rocks -= 1
			elif selected_block == 2: inv_woods -= 1
			elif selected_block == 4: inv_planks -= 1
			update_inv_ui()
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if ui and ui.crafting_panel.visible:
				ui.toggle_crafting()
			elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.keycode == KEY_E or event.keycode == KEY_TAB:
			if ui: ui.toggle_crafting()
		elif event.keycode == KEY_1: selected_block = 1; update_inv_ui()
		elif event.keycode == KEY_2: selected_block = 2; update_inv_ui()
		elif event.keycode == KEY_3: selected_block = 4; update_inv_ui()
		elif event.keycode == KEY_4: selected_block = 5; update_inv_ui()

func take_damage(amount: int):
	hp -= amount
	if hp < 0: hp = 0
	if ui: ui.update_hp(hp)
	print("Mất máu! HP còn: ", hp)
	if hp == 0:
		print("BẠN ĐÃ CHẾT! Hồi sinh...")
		respawn()

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
	
	# Xử lý đào khối (Giữ chuột trái)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if raycast.is_colliding():
			var hit_point = raycast.get_collision_point()
			var hit_normal = raycast.get_collision_normal()
			var block_pos = hit_point - hit_normal * 0.5
			var grid_pos = Vector3(round(block_pos.x), round(block_pos.y), round(block_pos.z))
			
			if grid_pos == mining_pos:
				mine_timer += delta
			else:
				mining_pos = grid_pos
				mine_timer = 0.0
				
			var block_id = world_node.get_block_global(grid_pos.x, grid_pos.y, grid_pos.z)
			var req_time = 3.0 # Tay không đập đá 3s
			if block_id == 2 or block_id == 3: req_time = 1.0 # Gỗ và lá 1s
			if has_pickaxe and block_id == 1: req_time = 0.5 # Có cuốc đập đá 0.5s
			
			if ui: ui.update_mining_ui(mine_timer, req_time)
			
			if mine_timer >= req_time:
				world_node.set_block(grid_pos, 0)
				if block_id == 1: inv_rocks += 1
				elif block_id == 2: inv_woods += 1
				elif block_id == 3: inv_woods += 1 # Lá rụng ra gỗ cho dễ
				elif block_id == 4: inv_planks += 1
				
				mine_timer = 0.0
				update_inv_ui()
				if ui: ui.update_mining_ui(0, 1)
		else:
			mine_timer = 0.0
			if ui: ui.update_mining_ui(0, 1)
	else:
		mine_timer = 0.0
		if ui: ui.update_mining_ui(0, 1)

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
