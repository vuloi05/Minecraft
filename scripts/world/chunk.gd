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
var world_ref: Node3D

func _init(_pos: Vector2i, _noise: FastNoiseLite, _mat: StandardMaterial3D, _world: Node3D):
	chunk_pos = _pos
	noise = _noise
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
				if y == terrain_height:
					blocks[x][y][z] = 1 # Cỏ (Grass Block)
				elif y > terrain_height - 4:
					blocks[x][y][z] = 8 # Đất (Dirt)
				else:
					blocks[x][y][z] = 7 # Đá (Stone)
				
			# Trồng cây (Tỷ lệ 1%, chỉ mọc nếu cách rìa để tránh lỗi mảng)
			if randf() < 0.01 and terrain_height + 5 < CHUNK_SIZE_Y and x > 1 and x < CHUNK_SIZE_X - 2 and z > 1 and z < CHUNK_SIZE_Z - 2:
				blocks[x][terrain_height + 1][z] = 2 # Gỗ
				blocks[x][terrain_height + 2][z] = 2
				blocks[x][terrain_height + 3][z] = 2
				
				# Lá cây (ID 4)
				blocks[x][terrain_height + 4][z] = 4
				blocks[x-1][terrain_height + 3][z] = 4
				blocks[x+1][terrain_height + 3][z] = 4
				blocks[x][terrain_height + 3][z-1] = 4
				blocks[x][terrain_height + 3][z+1] = 4

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

func add_quad(local_st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, color: Color):
	local_st.set_normal(normal)
	local_st.set_color(color)
	local_st.set_uv(Vector2(0, 0)); local_st.add_vertex(v0)
	local_st.set_uv(Vector2(1, 0)); local_st.add_vertex(v1)
	local_st.set_uv(Vector2(1, 1)); local_st.add_vertex(v2)
	local_st.set_uv(Vector2(0, 0)); local_st.add_vertex(v0)
	local_st.set_uv(Vector2(1, 1)); local_st.add_vertex(v2)
	local_st.set_uv(Vector2(0, 1)); local_st.add_vertex(v3)

func create_block_mesh(local_st: SurfaceTool, x: int, y: int, z: int):
	var block_id = blocks[x][y][z]
	if block_id == 0 or block_id == 5: return # Không vẽ Air và Đuốc (Đuốc vẽ bằng Sprite3D)
	
	var pos = Vector3(x, y, z)
	
	var color_top = get_block_color(block_id)
	var color_bottom = color_top
	var color_side = color_top
	
	if block_id == 1: # Grass Block
		color_top = Color(0.3, 0.6, 0.2) # Mặt cỏ xanh
		color_bottom = Color(0.52, 0.37, 0.26) # Mặt đất nâu
		color_side = Color(0.52, 0.37, 0.26) # Cạnh bên nâu
		
	var v_sx = 0.5
	var v_sy = 0.5
	var v_sz = 0.5
	var y_offset = 0.0
		
	var v0 = pos + Vector3(-v_sx, -v_sy + y_offset, -v_sz)
	var v1 = pos + Vector3(v_sx, -v_sy + y_offset, -v_sz)
	var v2 = pos + Vector3(v_sx, v_sy + y_offset, -v_sz)
	var v3 = pos + Vector3(-v_sx, v_sy + y_offset, -v_sz)
	var v4 = pos + Vector3(-v_sx, -v_sy + y_offset, v_sz)
	var v5 = pos + Vector3(v_sx, -v_sy + y_offset, v_sz)
	var v6 = pos + Vector3(v_sx, v_sy + y_offset, v_sz)
	var v7 = pos + Vector3(-v_sx, v_sy + y_offset, v_sz)

	if is_transparent(get_block(x, y, z + 1)): add_quad(local_st, v4, v7, v6, v5, Vector3(0, 0, 1), color_side)
	if is_transparent(get_block(x, y, z - 1)): add_quad(local_st, v1, v2, v3, v0, Vector3(0, 0, -1), color_side)
	if is_transparent(get_block(x + 1, y, z)): add_quad(local_st, v5, v6, v2, v1, Vector3(1, 0, 0), color_side)
	if is_transparent(get_block(x - 1, y, z)): add_quad(local_st, v0, v3, v7, v4, Vector3(-1, 0, 0), color_side)
	if is_transparent(get_block(x, y + 1, z)): add_quad(local_st, v7, v3, v2, v6, Vector3(0, 1, 0), color_top)
	if is_transparent(get_block(x, y - 1, z)): add_quad(local_st, v0, v4, v5, v1, Vector3(0, -1, 0), color_bottom)
