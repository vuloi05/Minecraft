extends Node3D
class_name Chunk

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16

var chunk_pos: Vector2i
var blocks = []
var st = SurfaceTool.new()
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
	
	generate_blocks()

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

func is_block_exposed(x: int, y: int, z: int) -> bool:
	return get_block(x+1, y, z) == 0 or get_block(x-1, y, z) == 0 or \
		   get_block(x, y+1, z) == 0 or get_block(x, y-1, z) == 0 or \
		   get_block(x, y, z+1) == 0 or get_block(x, y, z-1) == 0

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
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	active_collisions = 0
	var has_blocks = false
	
	for x in range(CHUNK_SIZE_X):
		for y in range(CHUNK_SIZE_Y):
			for z in range(CHUNK_SIZE_Z):
				if blocks[x][y][z] > 0:
					if is_block_exposed(x, y, z):
						create_block_mesh(x, y, z, blocks[x][y][z])
						var shape = get_collision_shape()
						shape.position = Vector3(x, y, z)
						shape.disabled = false
						has_blocks = true
	
	for i in range(active_collisions, collision_pool.size()):
		collision_pool[i].disabled = true
	
	if has_blocks:
		mesh_instance.mesh = st.commit()
	else:
		mesh_instance.mesh = null

func get_block_color(block_id: int) -> Color:
	if block_id == 1: return Color(0.3, 0.6, 0.2) # Cỏ (Base)
	elif block_id == 2: return Color(0.4, 0.25, 0.1) # Gỗ
	elif block_id == 3: return Color(0.6, 0.4, 0.2) # Ván gỗ
	elif block_id == 4: return Color(0.1, 0.5, 0.1) # Lá
	elif block_id == 5: return Color(1.0, 0.9, 0.2) # Đuốc
	elif block_id == 7: return Color(0.5, 0.5, 0.5) # Đá
	elif block_id == 8: return Color(0.52, 0.37, 0.26) # Đất
	return Color(1, 1, 1)

func add_quad(v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, color: Color):
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(v1)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(v3)

func create_block_mesh(x: int, y: int, z: int, block_id: int):
	var pos = Vector3(x, y, z)
	
	var color_top = get_block_color(block_id)
	var color_bottom = color_top
	var color_side = color_top
	
	if block_id == 1: # Grass Block
		color_top = Color(0.3, 0.6, 0.2) # Mặt cỏ xanh
		color_bottom = Color(0.52, 0.37, 0.26) # Mặt đất nâu
		color_side = Color(0.52, 0.37, 0.26) # Cạnh bên nâu
	
	var size_x = 0.5
	var size_y = 0.5
	var size_z = 0.5
	var offset_y = 0.0
	
	if block_id == 5: # Đuốc
		size_x = 0.06
		size_y = 0.3
		size_z = 0.06
		offset_y = -0.2 # Kéo xuống chạm đáy ô
		color_top = Color(1.0, 0.9, 0.2) # Lửa
		color_side = Color(0.5, 0.3, 0.1) # Thân gỗ
		color_bottom = Color(0.5, 0.3, 0.1)
		
	var v0 = pos + Vector3(-size_x, -size_y + offset_y, -size_z)
	var v1 = pos + Vector3(size_x, -size_y + offset_y, -size_z)
	var v2 = pos + Vector3(size_x, size_y + offset_y, -size_z)
	var v3 = pos + Vector3(-size_x, size_y + offset_y, -size_z)
	var v4 = pos + Vector3(-size_x, -size_y + offset_y, size_z)
	var v5 = pos + Vector3(size_x, -size_y + offset_y, size_z)
	var v6 = pos + Vector3(size_x, size_y + offset_y, size_z)
	var v7 = pos + Vector3(-size_x, size_y + offset_y, size_z)

	if get_block(x, y, z + 1) == 0: add_quad(v4, v7, v6, v5, Vector3(0, 0, 1), color_side)
	if get_block(x, y, z - 1) == 0: add_quad(v1, v2, v3, v0, Vector3(0, 0, -1), color_side)
	if get_block(x + 1, y, z) == 0: add_quad(v5, v6, v2, v1, Vector3(1, 0, 0), color_side)
	if get_block(x - 1, y, z) == 0: add_quad(v0, v3, v7, v4, Vector3(-1, 0, 0), color_side)
	if get_block(x, y + 1, z) == 0: add_quad(v7, v3, v2, v6, Vector3(0, 1, 0), color_top)
	if get_block(x, y - 1, z) == 0: add_quad(v0, v4, v5, v1, Vector3(0, -1, 0), color_bottom)
