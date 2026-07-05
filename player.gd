extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- SINH TỒN ---
var hp = 20
var hunger = 20

var hunger_timer = 0.0
const HUNGER_INTERVAL = 10.0 # 10 giây trừ 1 đói

var fall_start_y = 0.0
var was_on_floor = true

var ui: CanvasLayer

var mine_timer = 0.0
var mining_pos = Vector3.ZERO

var is_loading = true

# --- TAY CẦM ---
var hand_base: Node3D
var hand_label: Label3D
var hand_block: MeshInstance3D
var current_hand_id = -1
var bob_time = 0.0
var hit_time = 0.0
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
		ui.call_deferred("update_hp", hp)
		ui.call_deferred("update_hunger", hunger)
		
		ui.call_deferred("add_item", 6, 1) # Cuốc chim
		ui.call_deferred("add_item", 5, 64) # Đuốc
		ui.call_deferred("add_item", 2, 64) # Gỗ

	# Khởi tạo Tay cầm (Hand)
	hand_base = Node3D.new()
	camera.add_child(hand_base)
	
	hand_label = Label3D.new()
	hand_label.font_size = 150
	hand_label.outline_size = 8
	hand_label.position = Vector3(0.5, -0.4, -0.7)
	hand_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hand_base.add_child(hand_label)
	
	hand_block = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	hand_block.mesh = box
	hand_block.position = Vector3(0.5, -0.4, -0.7)
	hand_block.rotation_degrees = Vector3(15, -45, 0)
	hand_base.add_child(hand_block)

func update_hand(id: int):
	hand_label.visible = false
	hand_block.visible = false
	
	if id in [1, 2, 3, 4, 7, 8]: # Blocks
		hand_block.visible = true
		var mat = StandardMaterial3D.new()
		if id == 1: mat.albedo_color = Color(0.3, 0.6, 0.2) # Cỏ
		elif id == 2: mat.albedo_color = Color(0.4, 0.2, 0.0) # Gỗ
		elif id == 3: mat.albedo_color = Color(0.6, 0.4, 0.2) # Ván
		elif id == 4: mat.albedo_color = Color(0.2, 0.6, 0.2) # Lá
		elif id == 7: mat.albedo_color = Color(0.5, 0.5, 0.5) # Đá
		elif id == 8: mat.albedo_color = Color(0.52, 0.37, 0.26) # Đất
		hand_block.material_override = mat
	elif id > 0: # Items
		hand_label.visible = true
		if id == 5: hand_label.text = "🔦"
		elif id == 6: hand_label.text = "⛏️"

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
	if is_loading: return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * 0.005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if not (ui and ui.inventory_panel.visible):
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			return
			
		# Lăn chuột để chọn Hotbar
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if ui:
				var new_idx = ui.selected_hotbar_index - 1
				if new_idx < 0: new_idx = 8
				ui.select_hotbar(new_idx)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if ui:
				var new_idx = ui.selected_hotbar_index + 1
				if new_idx > 8: new_idx = 0
				ui.select_hotbar(new_idx)
			return
			
		if raycast.is_colliding() and event.button_index == MOUSE_BUTTON_RIGHT:
			var hit_point = raycast.get_collision_point()
			var hit_normal = raycast.get_collision_normal()
			
			var selected_block = 0
			if ui: selected_block = ui.get_selected_item_id()
			if selected_block == 0 or selected_block == 6: return # Cuốc hoặc ô trống không đặt được
			
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
			if ui: ui.consume_selected_item()
	
	if event is InputEventKey and event.pressed:
		if is_loading: return
		
		if event.keycode == KEY_ESCAPE:
			if ui and ui.inventory_panel.visible:
				ui.toggle_inventory()
			elif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.keycode == KEY_E or event.keycode == KEY_TAB:
			if ui: ui.toggle_inventory()
		
		# Chọn Hotbar 1-9
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			if ui: ui.select_hotbar(event.keycode - KEY_1)

func take_damage(amount: int):
	hp -= amount
	if hp < 0: hp = 0
	if ui: ui.update_hp(hp)
	print("Mất máu! HP còn: ", hp)
	if hp == 0:
		print("BẠN ĐÃ CHẾT! Hồi sinh...")
		respawn()

func _physics_process(delta):
	if is_loading: return
	
	# Cập nhật hiển thị tay cầm
	var id = 0
	if ui: id = ui.get_selected_item_id()
	if id != current_hand_id:
		current_hand_id = id
		update_hand(id)
		
	# Animation tay cầm (Bobbing & Swinging)
	var bob_offset = Vector3.ZERO
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5:
		bob_time += delta * 12.0
		bob_offset.y = sin(bob_time) * 0.05
		bob_offset.x = cos(bob_time) * 0.02
	else:
		bob_time = 0.0
		
	var swing_rot = Vector3.ZERO
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		hit_time += delta * 20.0
		swing_rot.x = -abs(sin(hit_time)) * 60.0 # Vung tay xuống
	else:
		hit_time = 0.0
		
	hand_base.position = hand_base.position.lerp(bob_offset, delta * 15.0)
	hand_base.rotation_degrees = hand_base.rotation_degrees.lerp(swing_rot, delta * 25.0)
	
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
			if block_id in [1, 8]: req_time = 1.0 # Cỏ, Đất 1s
			if block_id in [2, 4]: req_time = 1.5 # Gỗ và lá 1.5s
			
			var selected_item = 0
			if ui: selected_item = ui.get_selected_item_id()
			if selected_item == 6 and block_id == 7: req_time = 0.5 # Có cuốc đập đá 0.5s
			
			if ui: ui.update_mining_ui(mine_timer, req_time)
			
			if mine_timer >= req_time:
				world_node.set_block(grid_pos, 0)
				
				# Rớt đồ
				var drop_id = block_id
				if block_id == 1: drop_id = 8 # Cỏ rớt ra Đất
				elif block_id == 4: drop_id = 2 # Lá rớt ra Gỗ
				
				if ui and drop_id > 0:
					ui.add_item(drop_id, 1)
				
				mine_timer = 0.0
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

func finish_loading():
	is_loading = false
