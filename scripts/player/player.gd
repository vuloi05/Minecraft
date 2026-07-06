extends CharacterBody3D

const SPEED = 3.5
const JUMP_VELOCITY = 8.5

# Thay vì dùng trọng lực mặc định (9.8), tăng mạnh trọng lực lên để nhân vật rớt xuống nhanh, cảm giác nặng nề chân thực hơn giống Minecraft
var gravity = 25.0

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
var hand_sprite: Sprite3D
var current_hand_id = -1
var bob_time = 0.0
var hit_time = 0.0
# ----------------

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
var world_node: Node3D

var player_model_script = preload("res://scripts/player/player_model.gd")
var player_model: Node3D
var spring_arm: SpringArm3D
var camera_mode = 0 # 0: First, 1: Third Back, 2: Third Front

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
	hand_base.position = Vector3(0.5, -0.4, -0.7)
	camera.add_child(hand_base)
	
	# Khởi tạo Player Model (Steve)
	player_model = player_model_script.new()
	add_child(player_model)
	
	# Khởi tạo SpringArm3D cho Camera F5
	spring_arm = SpringArm3D.new()
	spring_arm.position = Vector3(0, 1.5, 0)
	spring_arm.collision_mask = 1
	spring_arm.add_excluded_object(self.get_rid())
	var arm_shape = SphereShape3D.new()
	arm_shape.radius = 0.2
	spring_arm.shape = arm_shape
	add_child(spring_arm)
	
	remove_child(camera)
	spring_arm.add_child(camera)
	camera.position = Vector3.ZERO
	
	update_camera_mode()
	
	hand_label = Label3D.new()
	hand_label.font_size = 150
	hand_label.outline_size = 8
	hand_label.position = Vector3.ZERO
	hand_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hand_label.no_depth_test = true
	hand_base.add_child(hand_label)
	
	hand_block = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	hand_block.mesh = box
	hand_block.position = Vector3.ZERO
	hand_block.rotation_degrees = Vector3(15, -45, 0)
	hand_base.add_child(hand_block)
	
	hand_sprite = Sprite3D.new()
	hand_sprite.position = Vector3.ZERO
	hand_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hand_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Render pixel art sắc nét
	hand_sprite.no_depth_test = true
	hand_base.add_child(hand_sprite)

func update_hand(id: int):
	hand_label.visible = false
	hand_block.visible = false
	hand_sprite.visible = false
	
	var b_data = DataManager.get_block_data(id)
	var is_block = false
	if b_data and not b_data.get("is_item", false):
		is_block = true
		
	if is_block: # Blocks
		hand_block.visible = true
		
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var uv_top = DataManager.get_block_uv(id)
		var uv_bottom = uv_top
		var uv_side = uv_top
		
		var c_top = Color(1, 1, 1)
		var c_side = Color(0.8, 0.8, 0.8) # Đánh bóng giả tạo chiều sâu
		var c_bottom = Color(0.6, 0.6, 0.6)
		
		if id == 1: # Grass Block
			c_top *= Color(0.4, 0.7, 0.3)
			if DataManager.uv_map.has("grass_block_top"): uv_top = DataManager.uv_map["grass_block_top"]
			elif DataManager.uv_map.has("grass_block_side"): uv_top = DataManager.uv_map["grass_block_side"]
			if DataManager.uv_map.has("dirt"): uv_bottom = DataManager.uv_map["dirt"]
			if DataManager.uv_map.has("grass_block_side"): uv_side = DataManager.uv_map["grass_block_side"]
		elif id == 4: # Leaves
			var tint = Color(0.2, 0.55, 0.1)
			c_top *= tint; c_side *= tint; c_bottom *= tint
			
		var hs = 0.15 # half size
		
		# Define vertices
		var v0 = Vector3(-hs, -hs, hs)
		var v1 = Vector3(hs, -hs, hs)
		var v2 = Vector3(hs, -hs, -hs)
		var v3 = Vector3(-hs, -hs, -hs)
		var v4 = Vector3(-hs, hs, hs)
		var v5 = Vector3(hs, hs, hs)
		var v6 = Vector3(hs, hs, -hs)
		var v7 = Vector3(-hs, hs, -hs)
		
		# Top
		_add_quad(st, v4, v7, v6, v5, Vector3(0, 1, 0), uv_top, c_top)
		# Bottom
		_add_quad(st, v0, v1, v2, v3, Vector3(0, -1, 0), uv_bottom, c_bottom)
		# Front
		_add_quad(st, v0, v4, v5, v1, Vector3(0, 0, 1), uv_side, c_side)
		# Back
		_add_quad(st, v2, v6, v7, v3, Vector3(0, 0, -1), uv_side, c_side)
		# Left
		_add_quad(st, v3, v7, v4, v0, Vector3(-1, 0, 0), uv_side, c_side)
		# Right
		_add_quad(st, v1, v5, v6, v2, Vector3(1, 0, 0), uv_side, c_side)
		
		st.generate_normals()
		var mesh = st.commit()
		
		var mat = StandardMaterial3D.new()
		var atlas = load("res://assets/textures/atlas.png")
		if atlas:
			mat.albedo_texture = atlas
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.no_depth_test = true
		
		hand_block.mesh = mesh
		hand_block.material_override = mat
	elif id > 0: # Items
		var tex_path = ""
		var is_tool = false
		if id in [6, 11, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]:
			is_tool = true
			
		b_data = DataManager.get_block_data(id)
		var tex = null
		
		if b_data and b_data.has("texture"):
			var tex_block = "res://assets/textures/blocks/" + b_data["texture"]
			var tex_item = "res://assets/textures/items/" + b_data["texture"]
			
			if FileAccess.file_exists(tex_block) or FileAccess.file_exists(tex_block + ".import"):
				tex = load(tex_block) as Texture2D
			elif FileAccess.file_exists(tex_item) or FileAccess.file_exists(tex_item + ".import"):
				tex = load(tex_item) as Texture2D
				
		if tex:
			hand_sprite.texture = tex
			
			# Tự động điều chỉnh kích thước hiển thị
			var max_dim = max(tex.get_width(), tex.get_height())
			if max_dim > 0:
				hand_sprite.pixel_size = 0.5 / float(max_dim)
			else:
				hand_sprite.pixel_size = 0.03
				
			if is_tool:
				hand_sprite.flip_h = true
				hand_sprite.rotation_degrees = Vector3(0, 0, 0)
			else:
				hand_sprite.flip_h = false
				hand_sprite.rotation_degrees = Vector3(0, 0, -20) # Đuốc nghiêng giống cúp
				
			hand_sprite.visible = true
			return
				
		hand_label.visible = true
		if id == 5: hand_label.text = "🔦"
		elif id == 6: hand_label.text = "⛏️"

func respawn():
	var spawn_x = 8.0
	var spawn_z = 8.0
	var terrain_y = 30.0
	
	if world_node and world_node.noise:
		terrain_y = float(int((world_node.noise.get_noise_2d(spawn_x, spawn_z) + 1.0) * 0.5 * 20) + 10)
		
	# Spawn người chơi cao hơn địa hình 15 block để tránh bị kẹt trong cây/lá
	global_position = Vector3(spawn_x, terrain_y + 15.0, spawn_z)
	hp = 20
	hunger = 20
	# Đặt fall_start_y thấp xuống để không bị mất máu khi rơi từ điểm spawn
	fall_start_y = terrain_y
	was_on_floor = false
	
	if ui:
		ui.call_deferred("update_hp", hp)
		ui.call_deferred("update_hunger", hunger)

func _unhandled_input(event):
	if is_loading: return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.005)
		if camera_mode == 2:
			spring_arm.rotate_x(event.relative.y * 0.005)
		else:
			spring_arm.rotate_x(-event.relative.y * 0.005)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x, -PI/2, PI/2)
	
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
			
			var target_pos = hit_point - hit_normal * 0.5
			var target_grid_pos = Vector3(round(target_pos.x), round(target_pos.y), round(target_pos.z))
			var target_block = world_node.get_block_global(target_grid_pos.x, target_grid_pos.y, target_grid_pos.z)
			
			if target_block == 10:
				if ui: ui.toggle_inventory(true)
				return
			
			var selected_block = 0
			if ui: selected_block = ui.get_selected_item_id()
			
			# Ngăn đặt block nếu cầm công cụ
			if selected_block == 0 or selected_block == 6 or selected_block == 11: return
			
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
			
		# Phím F5 để đổi góc nhìn
		if event.keycode == KEY_F5:
			camera_mode = (camera_mode + 1) % 3
			update_camera_mode()

func update_camera_mode():
	if camera_mode == 0:
		spring_arm.spring_length = 0.0
		spring_arm.rotation.y = 0
		camera.rotation = Vector3.ZERO
		camera.cull_mask &= ~(1 << 1) # Tắt render Layer 2 (giấu mô hình)
		hand_base.visible = true
	elif camera_mode == 1:
		spring_arm.spring_length = 4.0
		spring_arm.rotation.y = 0
		camera.rotation = Vector3.ZERO
		camera.cull_mask |= (1 << 1) # Bật render Layer 2
		hand_base.visible = false
	elif camera_mode == 2:
		spring_arm.spring_length = 4.0
		spring_arm.rotation.y = PI
		camera.rotation = Vector3(0, PI, 0)
		camera.cull_mask |= (1 << 1) # Bật render Layer 2
		hand_base.visible = false

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
	
	# Đóng băng (Freeze) người chơi nếu Chunk đang đứng chưa có lưới 3D
	# Phòng trường hợp người chơi rơi lọt thỏm xuống hư không
	if world_node:
		var px = global_position.x
		var pz = global_position.z
		var cpos = Vector2i(floor(px / 16.0), floor(pz / 16.0))
		var chunk = world_node.get_chunk_safe(cpos)
		if not chunk or not chunk.is_mesh_ready:
			velocity = Vector3.ZERO
			move_and_slide()
			return
	
	# Cập nhật hiển thị tay cầm
	var id = 0
	if ui: id = ui.get_selected_item_id()
	if id != current_hand_id:
		current_hand_id = id
		update_hand(id)
		
	# Animation tay cầm (Bobbing & Swinging)
	var base_pos = Vector3(0.5, -0.4, -0.7)
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
		var swing = abs(sin(hit_time))
		swing_rot.z = swing * 45.0   # Vung chéo xuống như gạt nước (giữ nguyên mặt 2D)
		swing_rot.x = -swing * 20.0  # Hơi gập xuống một chút
		base_pos.y -= swing * 0.15   # Giật tay xuống dưới
		base_pos.z -= swing * 0.15   # Đâm tay về phía trước
	else:
		hit_time = 0.0
		
	hand_base.position = hand_base.position.lerp(base_pos + bob_offset, delta * 15.0)
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
			var selected_item = 0
			if ui: selected_item = ui.get_selected_item_id()
			
			var req_time = DataManager.get_mining_time(block_id, selected_item)
			
			# Nếu req_time < 0 (Bedrock), không cho phép đào
			if req_time >= 0:
				if ui: ui.update_mining_ui(mine_timer, req_time)
				
				if mine_timer >= req_time:
					world_node.set_block(grid_pos, 0)
					
					# Rớt đồ xuống đất thay vì hút thẳng vào túi
					var drops = DataManager.get_drops(block_id, selected_item)
					for d in drops:
						world_node.spawn_item(d.id, d.count, grid_pos)
					
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

	# Chạy Animation cho Mô hình
	var is_mining = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	var head_rot_x = spring_arm.rotation.x
	if camera_mode == 2: head_rot_x = -head_rot_x
	player_model.animate(velocity, is_mining, head_rot_x, delta)

	move_and_slide()

func finish_loading():
	is_loading = false

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv_rect: Dictionary, color: Color = Color(1, 1, 1)):
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); st.add_vertex(v0)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_min)); st.add_vertex(v1)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); st.add_vertex(v2)
	
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); st.add_vertex(v0)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); st.add_vertex(v2)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_max)); st.add_vertex(v3)
