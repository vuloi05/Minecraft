extends Node3D
class_name Chunk

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16

var chunk_pos: Vector2i
var blocks = []
var is_data_ready = false
var is_meshing = false
var is_mesh_ready = false

var task_id = -1
var mesh_task_id = -1
var is_marked_for_deletion = false

var mesh_instance = MeshInstance3D.new()
var static_body = StaticBody3D.new()

var collision_pool = []
var active_collisions = 0

var noise: FastNoiseLite
var cave_noise: FastNoiseLite
var world_ref: Node3D

func _init(_pos: Vector2i, _noise: FastNoiseLite, _mat: StandardMaterial3D, _world: Node3D, _cave_noise: FastNoiseLite = null):
	chunk_pos = _pos
	noise = _noise
	cave_noise = _cave_noise
	world_ref = _world
	
	position = Vector3(chunk_pos.x * CHUNK_SIZE_X, 0, chunk_pos.y * CHUNK_SIZE_Z)
	
	add_child(mesh_instance)
	mesh_instance.add_child(static_body)
	static_body.add_to_group("blocks")
	mesh_instance.material_override = _mat
	# Không gọi generate_blocks() ở đây nữa, sẽ được gọi trong thread

func schedule_free():
	is_marked_for_deletion = true
	visible = false # Ẩn đi để người chơi không thấy
	
func _process(_delta):
	if is_marked_for_deletion:
		var can_free = true
		if task_id != -1 and not WorkerThreadPool.is_task_completed(task_id):
			can_free = false
		if mesh_task_id != -1 and not WorkerThreadPool.is_task_completed(mesh_task_id):
			can_free = false
			
		if can_free:
			queue_free()
			set_process(false)

func generate_blocks():
	blocks.resize(CHUNK_SIZE_X)
	for x in range(CHUNK_SIZE_X):
		blocks[x] = []
		blocks[x].resize(CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			blocks[x][y] = []
			blocks[x][y].resize(CHUNK_SIZE_Z)
			blocks[x][y].fill(0) # Đổ đầy không khí trước

	# Tính toán địa hình
	for x in range(CHUNK_SIZE_X):
		for z in range(CHUNK_SIZE_Z):
			var global_x = chunk_pos.x * CHUNK_SIZE_X + x
			var global_z = chunk_pos.y * CHUNK_SIZE_Z + z
			var terrain_height = int((noise.get_noise_2d(global_x, global_z) + 1.0) * 0.5 * 20) + 10
			
			for y in range(terrain_height + 1):
				var block_id = 7 # Mặc định là Đá (Stone)
				var depth = terrain_height - y
				
				if depth == 0:
					block_id = 1 # Grass Block
				elif depth < 4:
					block_id = 8 # Dirt
				else:
					# Thêm khoáng sản ngẫu nhiên khi đào sâu
					if randf() < 0.005 and y < 15: # Diamond Ore
						block_id = 15
					elif randf() < 0.02 and y < 30: # Iron Ore
						block_id = 14
					elif randf() < 0.04: # Coal Ore
						block_id = 13
				
				# Kiểm tra Hang động (Cave Carving)
				if cave_noise != null and depth > 4:
					var cave_val = cave_noise.get_noise_3d(global_x, y, global_z)
					if cave_val > 0.4: # Ngưỡng tạo hang, số càng cao hang càng hẹp
						block_id = 0 # Trở thành không khí
				
				blocks[x][y][z] = block_id
				
			# Trồng cây sồi (Oak tree)
			if randf() < 0.01 and terrain_height + 6 < CHUNK_SIZE_Y and x > 2 and x < CHUNK_SIZE_X - 3 and z > 2 and z < CHUNK_SIZE_Z - 3:
				var tree_height = randi() % 3 + 4 # Cao từ 4-6 lốc
				
				# Vẽ Thân cây
				for i in range(tree_height):
					blocks[x][terrain_height + 1 + i][z] = 2
					
				# Vẽ Tán lá
				var leaf_bottom = terrain_height + tree_height - 2
				for ly in range(leaf_bottom, leaf_bottom + 4):
					var radius = 2 if ly < leaf_bottom + 2 else 1
					for lx in range(-radius, radius + 1):
						for lz in range(-radius, radius + 1):
							# Bo tròn góc tán lá
							if abs(lx) == radius and abs(lz) == radius and (ly == leaf_bottom or ly == leaf_bottom + 3 or randf() < 0.5):
								continue
							var px = x + lx
							var pz = z + lz
							# Nếu đang là không khí thì điền lá vào
							if blocks[px][ly][pz] == 0:
								blocks[px][ly][pz] = 4

	is_data_ready = true

func get_block(x: int, y: int, z: int) -> int:
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		return blocks[x][y][z]
	
	# Gọi world_ref nếu quét ra bên ngoài biên của Chunk này
	var global_x = chunk_pos.x * CHUNK_SIZE_X + x
	var global_z = chunk_pos.y * CHUNK_SIZE_Z + z
	return world_ref.get_block_global(global_x, y, global_z)

func set_block(x: int, y: int, z: int, block_type: int):
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		blocks[x][y][z] = block_type
		update_chunk_mesh()

func is_transparent(id: int) -> bool:
	return id == 0 or id == 4 or id == 5 # 0: Air, 4: Lá, 5: Đuốc

func is_block_exposed(x: int, y: int, z: int) -> bool:
	return is_transparent(get_block(x+1, y, z)) or is_transparent(get_block(x-1, y, z)) or \
		   is_transparent(get_block(x, y+1, z)) or is_transparent(get_block(x, y-1, z)) or \
		   is_transparent(get_block(x, y, z+1)) or is_transparent(get_block(x, y, z-1))

func get_collision_shape() -> CollisionShape3D:
	if active_collisions < collision_pool.size():
		var shape = collision_pool[active_collisions]
		active_collisions += 1
		return shape
	else:
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1, 1, 1)
		shape.shape = box
		static_body.add_child(shape)
		collision_pool.append(shape)
		active_collisions += 1
		return shape

func update_chunk_mesh():
	# Gọi đồng bộ trên Main Thread khi đập/đặt block
	thread_update_mesh_logic(true)

func thread_generate():
	generate_blocks()
	thread_update_mesh_logic(false)

func thread_update_mesh():
	# Gọi bất đồng bộ (Luồng ngầm) khi cần cập nhật hàng xóm
	thread_update_mesh_logic(false)

func thread_update_mesh_logic(is_sync: bool):
	if not is_data_ready: return
	is_meshing = true
	
	var local_st = SurfaceTool.new()
	local_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var has_blocks = false
	var block_shapes = []
	
	for x in range(CHUNK_SIZE_X):
		for y in range(CHUNK_SIZE_Y):
			for z in range(CHUNK_SIZE_Z):
				if blocks[x][y][z] > 0:
					if is_block_exposed(x, y, z):
						create_block_mesh(local_st, x, y, z)
						block_shapes.append(Vector3(x, y, z))
						has_blocks = true
						
	var mesh = null
	if has_blocks:
		mesh = local_st.commit()
		
	if is_marked_for_deletion:
		is_meshing = false
		return
		
	if is_sync:
		apply_mesh_and_collision(mesh, block_shapes)
	else:
		call_deferred("apply_mesh_and_collision", mesh, block_shapes)

func apply_mesh_and_collision(mesh, block_shapes: Array):
	if not is_inside_tree() or is_queued_for_deletion():
		return
		
	is_meshing = false
	
	if mesh:
		mesh_instance.mesh = mesh
	else:
		mesh_instance.mesh = null
		
	active_collisions = 0
	for i in range(block_shapes.size()):
		var shape = get_collision_shape()
		shape.position = block_shapes[i]
		shape.disabled = false
		
	for i in range(block_shapes.size(), collision_pool.size()):
		collision_pool[i].disabled = true
		
	is_mesh_ready = true
		
	if world_ref.has_method("on_chunk_generated"):
		world_ref.on_chunk_generated(chunk_pos)

func get_block_color(block_id: int) -> Color:
	if block_id == 1: return Color(0.3, 0.6, 0.2) # Cỏ (Base)
	elif block_id == 2: return Color(0.4, 0.25, 0.1) # Gỗ
	elif block_id == 3: return Color(0.6, 0.4, 0.2) # Ván gỗ
	elif block_id == 4: return Color(0.1, 0.5, 0.1) # Lá
	elif block_id == 5: return Color(1.0, 0.9, 0.2) # Đuốc
	elif block_id == 7: return Color(0.5, 0.5, 0.5) # Đá
	elif block_id == 8: return Color(0.52, 0.37, 0.26) # Đất
	return Color(1, 1, 1)

func add_quad(local_st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv_rect: Dictionary, color: Color = Color(1, 1, 1)):
	local_st.set_normal(normal)
	local_st.set_color(color)
	local_st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); local_st.add_vertex(v0) # Bottom-Left
	local_st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_min)); local_st.add_vertex(v1) # Top-Left
	local_st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); local_st.add_vertex(v2) # Top-Right
	
	local_st.set_normal(normal)
	local_st.set_color(color)
	local_st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); local_st.add_vertex(v0) # Bottom-Left
	local_st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); local_st.add_vertex(v2) # Top-Right
	local_st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_max)); local_st.add_vertex(v3) # Bottom-Right

func create_block_mesh(local_st: SurfaceTool, x: int, y: int, z: int):
	var block_id = blocks[x][y][z]
	if block_id == 0: return # Không vẽ Air
	
	var pos = Vector3(x, y, z)
	
	var uv_top = DataManager.get_block_uv(block_id)
	var uv_bottom = uv_top
	var uv_side = uv_top
	
	var top_color = Color(1, 1, 1)
	var bottom_color = Color(1, 1, 1)
	var side_color = Color(1, 1, 1)
	
	if block_id == 1: # Grass Block special logic
		top_color = Color(0.4, 0.7, 0.3) # Nhuộm mặt trên màu xanh cỏ
		if DataManager.uv_map.has("grass_block_top"):
			uv_top = DataManager.uv_map["grass_block_top"]
		elif DataManager.uv_map.has("grass_block_side"):
			uv_top = DataManager.uv_map["grass_block_side"]
			
		if DataManager.uv_map.has("dirt"):
			uv_bottom = DataManager.uv_map["dirt"]
			
		if DataManager.uv_map.has("grass_block_side"):
			uv_side = DataManager.uv_map["grass_block_side"]
			
	elif block_id == 4: # Lá cây
		top_color = Color(0.2, 0.55, 0.1)
		bottom_color = top_color
		side_color = top_color
		
	var v_sx = 0.5
	var v_sy = 0.5
	var v_sz = 0.5
	var y_offset = 0.0
	
	if block_id == 5: # Torch
		v_sx = 0.0625 # Rộng 2 pixel (2/16 = 0.125, bán kính = 0.0625)
		v_sy = 0.3125 # Cao 10 pixel (10/16 = 0.625, bán kính = 0.3125)
		v_sz = 0.0625 # Dày 2 pixel
		y_offset = -0.1875 # Dịch xuống đáy ô (0.5 - 0.3125 = 0.1875)
		
		# Cắt chính xác phần hình ảnh cây đuốc (từ pixel 7->9 theo chiều ngang, 6->16 theo chiều dọc)
		var u_w = uv_top.u_max - uv_top.u_min
		var v_h = uv_top.v_max - uv_top.v_min
		uv_side = {
			"u_min": uv_top.u_min + u_w * (7.0/16.0),
			"u_max": uv_top.u_min + u_w * (9.0/16.0),
			"v_min": uv_top.v_min + v_h * (6.0/16.0),
			"v_max": uv_top.v_max
		}
		uv_top = {
			"u_min": uv_top.u_min + u_w * (7.0/16.0),
			"u_max": uv_top.u_min + u_w * (9.0/16.0),
			"v_min": uv_top.v_min + v_h * (6.0/16.0),
			"v_max": uv_top.v_min + v_h * (8.0/16.0)
		}
		uv_bottom = uv_top
		
	var v0 = pos + Vector3(-v_sx, -v_sy + y_offset, -v_sz)
	var v1 = pos + Vector3(v_sx, -v_sy + y_offset, -v_sz)
	var v2 = pos + Vector3(v_sx, v_sy + y_offset, -v_sz)
	var v3 = pos + Vector3(-v_sx, v_sy + y_offset, -v_sz)
	var v4 = pos + Vector3(-v_sx, -v_sy + y_offset, v_sz)
	var v5 = pos + Vector3(v_sx, -v_sy + y_offset, v_sz)
	var v6 = pos + Vector3(v_sx, v_sy + y_offset, v_sz)
	var v7 = pos + Vector3(-v_sx, v_sy + y_offset, v_sz)

	# Bỏ qua kiểm tra is_block_exposed nếu là Đuốc vì đuốc nhỏ luôn thấy các mặt
	if block_id == 5 or is_block_exposed(x, y, z + 1): add_quad(local_st, v4, v7, v6, v5, Vector3(0, 0, 1), uv_side, side_color)
	if block_id == 5 or is_block_exposed(x, y, z - 1): add_quad(local_st, v1, v2, v3, v0, Vector3(0, 0, -1), uv_side, side_color)
	if block_id == 5 or is_block_exposed(x + 1, y, z): add_quad(local_st, v5, v6, v2, v1, Vector3(1, 0, 0), uv_side, side_color)
	if block_id == 5 or is_block_exposed(x - 1, y, z): add_quad(local_st, v0, v3, v7, v4, Vector3(-1, 0, 0), uv_side, side_color)
	if block_id == 5 or is_block_exposed(x, y + 1, z): add_quad(local_st, v7, v3, v2, v6, Vector3(0, 1, 0), uv_top, top_color)
	if block_id == 5 or is_block_exposed(x, y - 1, z): add_quad(local_st, v0, v4, v5, v1, Vector3(0, -1, 0), uv_bottom, bottom_color)
