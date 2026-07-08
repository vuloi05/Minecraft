extends Node3D
class_name Chunk

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16

var chunk_pos: Vector2i
var blocks = PackedInt32Array()
var is_data_ready = false
var is_meshing = false
var is_mesh_ready = false

var task_id = -1
var mesh_task_id = -1
var is_marked_for_deletion = false

var mesh_instance = MeshInstance3D.new()
var water_mesh_instance = MeshInstance3D.new()
var static_body = StaticBody3D.new()
var chunk_collision = CollisionShape3D.new()

var noise: FastNoiseLite
var cave_noise: FastNoiseLite
var temp_noise: FastNoiseLite
var humid_noise: FastNoiseLite
var world_ref: Node3D

func _init(_pos: Vector2i, _noise: FastNoiseLite, _mat: ShaderMaterial, _world: Node3D, _cave_noise: FastNoiseLite = null, _water_mat: ShaderMaterial = null, _temp_noise: FastNoiseLite = null, _humid_noise: FastNoiseLite = null):
	chunk_pos = _pos
	noise = _noise
	cave_noise = _cave_noise
	temp_noise = _temp_noise
	humid_noise = _humid_noise
	world_ref = _world
	
	position = Vector3(chunk_pos.x * CHUNK_SIZE_X, 0, chunk_pos.y * CHUNK_SIZE_Z)
	
	add_child(mesh_instance)
	add_child(water_mesh_instance)
	mesh_instance.add_child(static_body)
	static_body.add_child(chunk_collision)
	static_body.add_to_group("blocks")
	mesh_instance.material_override = _mat
	if _water_mat:
		water_mesh_instance.material_override = _water_mat
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
	blocks.resize(CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z)
	blocks.fill(0)

	for x in range(CHUNK_SIZE_X):
		for z in range(CHUNK_SIZE_Z):
			var global_x = chunk_pos.x * CHUNK_SIZE_X + x
			var global_z = chunk_pos.y * CHUNK_SIZE_Z + z
			
			var temp = 0.5
			var humid = 0.5
			if temp_noise != null: temp = (temp_noise.get_noise_2d(global_x, global_z) + 1.0) * 0.5
			if humid_noise != null: humid = (humid_noise.get_noise_2d(global_x, global_z) + 1.0) * 0.5
			
			var biome = 0 # Plains
			if temp < 0.35: biome = 2 # Winter
			elif temp > 0.6 and humid < 0.4: biome = 1 # Desert
			elif temp > 0.6 and humid >= 0.4: biome = 3 # Jungle
			
			var terrain_height = 0
			if biome == 1:
				terrain_height = int((noise.get_noise_2d(global_x, global_z) + 1.0) * 0.5 * 10) + 12
			elif biome == 3:
				terrain_height = int((noise.get_noise_2d(global_x, global_z) + 1.0) * 0.5 * 30) + 15
			else:
				terrain_height = int((noise.get_noise_2d(global_x, global_z) + 1.0) * 0.5 * 20) + 10
			
			for y in range(terrain_height + 1):
				var block_id = 7 # Stone
				var depth = terrain_height - y
				
				if y == 0:
					block_id = 31 # Bedrock
				elif depth == 0:
					if biome == 1: block_id = 26 # Sand
					elif biome == 2: block_id = 43 # Snow Block
					else: block_id = 1 # Grass Block
				elif depth < 4:
					if biome == 1: block_id = 40 # Sandstone
					else: block_id = 8 # Dirt
				else:
					if randf() < 0.005 and y < 16: block_id = 15 # Diamond
					elif randf() < 0.02 and y < 40: block_id = 14 # Iron
					elif randf() < 0.04: block_id = 13 # Coal
				
				if cave_noise != null and depth > 4 and y > 0:
					var cave_val = cave_noise.get_noise_3d(global_x, y, global_z)
					if cave_val > 0.4:
						block_id = 0
						if y < 10:
							block_id = 49 # Lava
				
				set_block_local(x, y, z, block_id)
				
			# Generate water level (ocean/lakes) up to Y=12
			for y in range(1, 13):
				if y > terrain_height and get_block_local(x, y, z) == 0:
					if biome == 2: set_block_local(x, y, z, 44) # Ice
					else: set_block_local(x, y, z, 28) # Water
					
			var surface_y = terrain_height + 1
			if surface_y < CHUNK_SIZE_Y and get_block_local(x, surface_y, z) == 0:
				var block_below = get_block_local(x, surface_y - 1, z)
				if block_below == 1:
					if randf() < 0.05:
						var flora = [45, 46, 47, 48]
						set_block_local(x, surface_y, z, flora[randi() % flora.size()])
				elif block_below == 26:
					if randf() < 0.01: set_block_local(x, surface_y, z, 41)
					elif randf() < 0.05: set_block_local(x, surface_y, z, 42)
					
			if biome != 1 and randf() < 0.01 and terrain_height + 8 < CHUNK_SIZE_Y and x > 2 and x < CHUNK_SIZE_X - 3 and z > 2 and z < CHUNK_SIZE_Z - 3:
				var is_jungle = (biome == 3)
				var tree_height = randi() % 3 + (7 if is_jungle else 4)
				for i in range(tree_height):
					set_block_local(x, terrain_height + 1 + i, z, 2)
				var leaf_bottom = terrain_height + tree_height - 2
				var radius_max = 3 if is_jungle else 2
				for ly in range(leaf_bottom, leaf_bottom + 4):
					var radius = radius_max if ly < leaf_bottom + 2 else (radius_max - 1)
					for lx in range(-radius, radius + 1):
						for lz in range(-radius, radius + 1):
							if abs(lx) == radius and abs(lz) == radius and (ly == leaf_bottom or ly == leaf_bottom + 3 or randf() < 0.5):
								continue
							var px = x + lx
							var pz = z + lz
							if get_block_local(px, ly, pz) == 0:
								set_block_local(px, ly, pz, 4)

	is_data_ready = true

func get_block_local(x: int, y: int, z: int) -> int:
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		return blocks[x * (CHUNK_SIZE_Y * CHUNK_SIZE_Z) + y * CHUNK_SIZE_Z + z]
	return 0

func set_block_local(x: int, y: int, z: int, block_type: int):
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		blocks[x * (CHUNK_SIZE_Y * CHUNK_SIZE_Z) + y * CHUNK_SIZE_Z + z] = block_type

func get_block(x: int, y: int, z: int) -> int:
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		return blocks[x * (CHUNK_SIZE_Y * CHUNK_SIZE_Z) + y * CHUNK_SIZE_Z + z]
	
	if y < 0 or y >= CHUNK_SIZE_Y:
		return 0
	
	# Gọi world_ref nếu quét ra bên ngoài biên của Chunk này
	var global_x = chunk_pos.x * CHUNK_SIZE_X + x
	var global_z = chunk_pos.y * CHUNK_SIZE_Z + z
	return world_ref.get_block_global(global_x, y, global_z)

func set_block(x: int, y: int, z: int, block_type: int):
	set_block_local(x, y, z, block_type)


func is_flora(id: int) -> bool:
	return id in [42, 45, 46, 47, 48]

func is_transparent(id: int) -> bool:
	return id == 0 or id == 4 or id == 5 or id == 28 or id == 49 or (id >= 101 and id <= 107) or is_flora(id)

func should_draw_face(block_id: int, neighbor_id: int, normal: Vector3) -> bool:
	if block_id == 5: return true
	if is_flora(block_id): return normal == Vector3.UP # Chỉ vẽ 1 lần ở pass mặt trên

	
	var is_water = block_id == 28 or block_id == 49 or (block_id >= 101 and block_id <= 107)
	var is_neighbor_water = neighbor_id == 28 or neighbor_id == 49 or (neighbor_id >= 101 and neighbor_id <= 107)
	
	if is_water and is_neighbor_water:
		# Nước nằm dưới nước (đáy/đỉnh) thì không vẽ
		if normal == Vector3.UP or normal == Vector3.DOWN:
			return false
			
		# Vẽ mặt bên nếu khối nước hiện tại cao hơn khối nước kề cạnh
		var level_b = 0 if block_id == 28 else (block_id - 100)
		var level_n = 0 if neighbor_id == 28 else (neighbor_id - 100)
		return level_b < level_n
		
	return is_transparent(neighbor_id)

func get_block_from_copy(blocks_copy: PackedInt32Array, x: int, y: int, z: int) -> int:
	# Đọc từ bản sao (snapshot) khi tọa độ nằm TRONG chunk này, để đảm bảo toàn bộ
	# phép kiểm tra khối hiện tại + 6 hàng xóm đều dùng chung 1 snapshot dữ liệu,
	# tránh trường hợp main thread sửa `blocks` giữa chừng lúc thread đang mesh.
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		return blocks_copy[x * (CHUNK_SIZE_Y * CHUNK_SIZE_Z) + y * CHUNK_SIZE_Z + z]

	if y < 0 or y >= CHUNK_SIZE_Y:
		return 0

	# Ra ngoài biên chunk: phải hỏi chunk hàng xóm (dữ liệu sống của HỌ, không thể snapshot
	# cùng lúc, nhưng đây là vấn đề của chunk đó tự đảm bảo khi họ tự mesh chunk của họ).
	var global_x = chunk_pos.x * CHUNK_SIZE_X + x
	var global_z = chunk_pos.y * CHUNK_SIZE_Z + z
	return world_ref.get_block_global(global_x, y, global_z)

func hide_block_collision_at(_lx: int, _ly: int, _lz: int):
	# Với Trimesh gộp không thể ẩn riêng 1 khối như Object Pool cũ.
	# KHÔNG force remesh đồng bộ ở đây: world.gd đã tự gọi
	# WorkerThreadPool.add_task(c.thread_update_mesh) ngay sau lệnh này,
	# và visual mesh + collision luôn được apply CÙNG LÚC trong
	# apply_mesh_and_collision() — nên độ trễ 1 khung hình giữa lúc đào
	# và lúc mesh/collision cập nhật là không đáng kể, không có "khối ma"
	# thực sự. Ép sync ở đây từng gây double-remesh + giật main thread
	# mỗi lần click chuột khi chưa có Greedy Meshing — đã bỏ.
	pass

func update_chunk_mesh():
	# Chạy đồng bộ trên Main Thread vì giờ lưới đã được tối ưu siêu tốc
	thread_update_mesh_logic(true)

func thread_generate():
	generate_blocks()
	# Chạy meshing ngay trên worker thread (an toàn nhờ blocks.duplicate() snapshot)
	thread_update_mesh_logic(false)

func thread_update_mesh():
	# Gọi bất đồng bộ (Luồng ngầm) khi cần cập nhật hàng xóm
	thread_update_mesh_logic(false)

var _has_blocks = false
var _has_water = false

func thread_update_mesh_logic(is_sync: bool):
	if not is_data_ready: return
	is_meshing = true
	
	var blocks_copy = blocks.duplicate()
	
	var local_st = SurfaceTool.new()
	local_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	local_st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	
	var water_st = SurfaceTool.new()
	water_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	water_st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	
	_has_blocks = false
	_has_water = false
	
	# Pass 1: +Y (Top)
	for y in range(CHUNK_SIZE_Y):
		var mask = PackedInt32Array(); mask.resize(CHUNK_SIZE_X * CHUNK_SIZE_Z)
		for z in range(CHUNK_SIZE_Z):
			for x in range(CHUNK_SIZE_X):
				var b_id = get_block_from_copy(blocks_copy, x, y, z)
				if b_id != 0 and should_draw_face(b_id, get_block_from_copy(blocks_copy, x, y+1, z), Vector3.UP):
					mask[z * CHUNK_SIZE_X + x] = b_id
		greedy_mesh_plane(mask, CHUNK_SIZE_X, CHUNK_SIZE_Z, y+1, Vector3.UP, local_st, water_st, blocks_copy)

	# Pass 2: -Y (Bottom)
	for y in range(CHUNK_SIZE_Y):
		var mask = PackedInt32Array(); mask.resize(CHUNK_SIZE_X * CHUNK_SIZE_Z)
		for z in range(CHUNK_SIZE_Z):
			for x in range(CHUNK_SIZE_X):
				var b_id = get_block_from_copy(blocks_copy, x, y, z)
				if b_id != 0 and should_draw_face(b_id, get_block_from_copy(blocks_copy, x, y-1, z), Vector3.DOWN):
					mask[z * CHUNK_SIZE_X + x] = b_id
		greedy_mesh_plane(mask, CHUNK_SIZE_X, CHUNK_SIZE_Z, y, Vector3.DOWN, local_st, water_st, blocks_copy)

	# Pass 3: +X (Right)
	for x in range(CHUNK_SIZE_X):
		var mask = PackedInt32Array(); mask.resize(CHUNK_SIZE_Z * CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			for z in range(CHUNK_SIZE_Z):
				var b_id = get_block_from_copy(blocks_copy, x, y, z)
				if b_id != 0 and should_draw_face(b_id, get_block_from_copy(blocks_copy, x+1, y, z), Vector3.RIGHT):
					mask[y * CHUNK_SIZE_Z + z] = b_id
		greedy_mesh_plane(mask, CHUNK_SIZE_Z, CHUNK_SIZE_Y, x+1, Vector3.RIGHT, local_st, water_st, blocks_copy)

	# Pass 4: -X (Left)
	for x in range(CHUNK_SIZE_X):
		var mask = PackedInt32Array(); mask.resize(CHUNK_SIZE_Z * CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			for z in range(CHUNK_SIZE_Z):
				var b_id = get_block_from_copy(blocks_copy, x, y, z)
				if b_id != 0 and should_draw_face(b_id, get_block_from_copy(blocks_copy, x-1, y, z), Vector3.LEFT):
					mask[y * CHUNK_SIZE_Z + z] = b_id
		greedy_mesh_plane(mask, CHUNK_SIZE_Z, CHUNK_SIZE_Y, x, Vector3.LEFT, local_st, water_st, blocks_copy)

	# Pass 5: +Z (Front)
	for z in range(CHUNK_SIZE_Z):
		var mask = PackedInt32Array(); mask.resize(CHUNK_SIZE_X * CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			for x in range(CHUNK_SIZE_X):
				var b_id = get_block_from_copy(blocks_copy, x, y, z)
				if b_id != 0 and should_draw_face(b_id, get_block_from_copy(blocks_copy, x, y, z+1), Vector3.BACK):
					mask[y * CHUNK_SIZE_X + x] = b_id
		greedy_mesh_plane(mask, CHUNK_SIZE_X, CHUNK_SIZE_Y, z+1, Vector3.BACK, local_st, water_st, blocks_copy)

	# Pass 6: -Z (Back)
	for z in range(CHUNK_SIZE_Z):
		var mask = PackedInt32Array(); mask.resize(CHUNK_SIZE_X * CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			for x in range(CHUNK_SIZE_X):
				var b_id = get_block_from_copy(blocks_copy, x, y, z)
				if b_id != 0 and should_draw_face(b_id, get_block_from_copy(blocks_copy, x, y, z-1), Vector3.FORWARD):
					mask[y * CHUNK_SIZE_X + x] = b_id
		greedy_mesh_plane(mask, CHUNK_SIZE_X, CHUNK_SIZE_Y, z, Vector3.FORWARD, local_st, water_st, blocks_copy)

	var mesh = null
	if _has_blocks:
		mesh = local_st.commit()
		
	var water_mesh = null
	if _has_water:
		water_mesh = water_st.commit()
		
	if is_marked_for_deletion:
		is_meshing = false
		return
		
	var collision_shape = null
	if mesh:
		collision_shape = mesh.create_trimesh_shape()
	
	if is_sync:
		apply_mesh_and_collision(mesh, water_mesh, collision_shape)
	else:
		call_deferred("apply_mesh_and_collision", mesh, water_mesh, collision_shape)

func apply_mesh_and_collision(mesh, water_mesh, collision_shape = null):
	if not is_inside_tree() or is_queued_for_deletion():
		return
		
	is_meshing = false
	
	if mesh:
		mesh_instance.mesh = mesh
		chunk_collision.shape = collision_shape  # Chỉ gán, không tính toán — gần như instant
		chunk_collision.disabled = false
	else:
		mesh_instance.mesh = null
		chunk_collision.shape = null
		chunk_collision.disabled = true
		
	if water_mesh:
		water_mesh_instance.mesh = water_mesh
	else:
		water_mesh_instance.mesh = null
		
	if not is_mesh_ready:
		is_mesh_ready = true
		if world_ref.has_method("on_chunk_generated"):
			world_ref.on_chunk_generated(chunk_pos)

func get_block_color(block_id: int) -> Color:
	if block_id == 1: return Color(0.75, 1.0, 0.45) # Cỏ (Bù trừ cho texture grayscale để ra màu xanh tươi)
	elif block_id == 2: return Color(0.4, 0.25, 0.1) # Gỗ
	elif block_id == 3: return Color(0.6, 0.4, 0.2) # Ván gỗ
	elif block_id == 4: return Color(0.7, 1.0, 0.4) # Lá (Bù trừ cho texture grayscale)
	elif block_id == 5: return Color(1.0, 0.9, 0.2) # Đuốc
	elif block_id == 7: return Color(0.5, 0.5, 0.5) # Đá
	elif block_id == 8: return Color(0.52, 0.37, 0.26) # Đất
	elif block_id == 26: return Color(0.9, 0.86, 0.7) # Cát
	elif block_id == 27: return Color(0.6, 0.6, 0.6) # Sỏi
	elif block_id == 28 or (block_id >= 101 and block_id <= 107): return Color(0.247, 0.463, 0.894, 0.8) # Màu nước chuẩn Minecraft (#3F76E4)
	return Color(1, 1, 1)

func greedy_mesh_plane(mask: PackedInt32Array, w_limit: int, h_limit: int, depth: int, normal: Vector3, local_st: SurfaceTool, water_st: SurfaceTool, blocks_copy: PackedInt32Array):
	var n = 0
	for j in range(h_limit):
		var i = 0
		while i < w_limit:
			var b_id = mask[n]
			if b_id != 0:
				var w = 1
				var is_non_greedy = (b_id == 5 or b_id == 28 or b_id == 49 or (b_id >= 101 and b_id <= 107) or is_flora(b_id))
				if not is_non_greedy:
					while i + w < w_limit and mask[n + w] == b_id:
						w += 1
				var h = 1
				if not is_non_greedy:
					var done = false
					while j + h < h_limit:
						for c in range(w):
							if mask[n + c + h * w_limit] != b_id:
								done = true
								break
						if done:
							break
						h += 1
				
				var is_water = (b_id == 28 or b_id == 49 or (b_id >= 101 and b_id <= 107))
				var st = water_st if is_water else local_st
				generate_quad(i, j, w, h, depth, normal, st, b_id, blocks_copy)
				
				for l in range(h):
					for c in range(w):
						mask[n + c + l * w_limit] = 0
				
				i += w
				n += w
			else:
				i += 1
				n += 1

func get_block_color_by_face(block_id: int, face_idx: int) -> Color:
	var c = get_block_color(block_id)
	if block_id == 1:
		if face_idx == 1: return Color(0.3, 0.6, 0.2)
		elif face_idx == 2: return Color(0.52, 0.37, 0.26)
		else: return Color(1, 1, 1)
	elif block_id == 4 or block_id == 18 or block_id == 161:
		return Color(0.1, 0.5, 0.1)

	return c

func generate_quad(u: int, v: int, w: int, h: int, depth: int, normal: Vector3, st: SurfaceTool, b_id: int, blocks_copy: PackedInt32Array):
	if is_flora(b_id):
		var cx = u + 0.5
		var cy = depth - 1.0 # Sửa lỗi hoa bị lơ lửng 1 block
		var cz = v + 0.5
		var center_offset = Vector3(0.5, 0.5, 0.5)
		
		# Quad A (Diagonal /)
		var qa_v0 = Vector3(cx - 0.5, cy, cz - 0.5) - center_offset
		var qa_v1 = Vector3(cx + 0.5, cy, cz + 0.5) - center_offset
		var qa_v2 = Vector3(cx + 0.5, cy + 1, cz + 0.5) - center_offset
		var qa_v3 = Vector3(cx - 0.5, cy + 1, cz - 0.5) - center_offset
		
		# Quad B (Diagonal \)
		var qb_v0 = Vector3(cx - 0.5, cy, cz + 0.5) - center_offset
		var qb_v1 = Vector3(cx + 0.5, cy, cz - 0.5) - center_offset
		var qb_v2 = Vector3(cx + 0.5, cy + 1, cz - 0.5) - center_offset
		var qb_v3 = Vector3(cx - 0.5, cy + 1, cz + 0.5) - center_offset
		
		var uv_rect = DataManager.get_block_uv(b_id)
		st.set_custom(0, Color(uv_rect.u_min, uv_rect.v_min, uv_rect.u_max, uv_rect.v_max))
		st.set_color(Color(1, 1, 1))
		st.set_normal(Vector3.UP)
		_has_blocks = true
		
		var draw_quad_double_sided = func(v0, v1, v2, v3):
			# Mặt trước: v0(bottom-left), v1(bottom-right), v2(top-right), v3(top-left)
			st.set_uv(Vector2(0, 1)); st.add_vertex(v0)
			st.set_uv(Vector2(1, 0)); st.add_vertex(v2)
			st.set_uv(Vector2(1, 1)); st.add_vertex(v1)
			st.set_uv(Vector2(0, 1)); st.add_vertex(v0)
			st.set_uv(Vector2(0, 0)); st.add_vertex(v3)
			st.set_uv(Vector2(1, 0)); st.add_vertex(v2)
			
			# Mặt sau: Lật ngược UV theo chiều ngang (flip X)
			# Triangle 1 (Back): v1, v3, v0
			st.set_uv(Vector2(0, 1)); st.add_vertex(v1)
			st.set_uv(Vector2(1, 0)); st.add_vertex(v3)
			st.set_uv(Vector2(1, 1)); st.add_vertex(v0)
			# Triangle 2 (Back): v1, v2, v3
			st.set_uv(Vector2(0, 1)); st.add_vertex(v1)
			st.set_uv(Vector2(0, 0)); st.add_vertex(v2)
			st.set_uv(Vector2(1, 0)); st.add_vertex(v3)
			
		draw_quad_double_sided.call(qa_v0, qa_v1, qa_v2, qa_v3)
		draw_quad_double_sided.call(qb_v0, qb_v1, qb_v2, qb_v3)
		return

	var v0: Vector3; var v1: Vector3; var v2: Vector3; var v3: Vector3
	
	var bx = 0; var by = 0; var bz = 0
	if normal == Vector3.UP: bx = u; by = depth - 1; bz = v
	elif normal == Vector3.DOWN: bx = u; by = depth; bz = v
	elif normal == Vector3.RIGHT: bx = depth - 1; by = v; bz = u
	elif normal == Vector3.LEFT: bx = depth; by = v; bz = u
	elif normal == Vector3.BACK: bx = u; by = v; bz = depth - 1
	elif normal == Vector3.FORWARD: bx = u; by = v; bz = depth
	
	var block_above = get_block_from_copy(blocks_copy, bx, by + 1, bz)
	var has_water_above = (block_above == 28 or block_above == 49 or (block_above >= 101 and block_above <= 107))
	
	if normal == Vector3.UP:
		v0 = Vector3(u, depth, v + h)
		v1 = Vector3(u + w, depth, v + h)
		v2 = Vector3(u + w, depth, v)
		v3 = Vector3(u, depth, v)
	elif normal == Vector3.DOWN:
		v0 = Vector3(u, depth, v)
		v1 = Vector3(u + w, depth, v)
		v2 = Vector3(u + w, depth, v + h)
		v3 = Vector3(u, depth, v + h)
	elif normal == Vector3.RIGHT:
		v0 = Vector3(depth, v, u + w)
		v1 = Vector3(depth, v, u)
		v2 = Vector3(depth, v + h, u)
		v3 = Vector3(depth, v + h, u + w)
	elif normal == Vector3.LEFT:
		v0 = Vector3(depth, v, u)
		v1 = Vector3(depth, v, u + w)
		v2 = Vector3(depth, v + h, u + w)
		v3 = Vector3(depth, v + h, u)
	elif normal == Vector3.BACK: # +Z
		v0 = Vector3(u, v, depth)
		v1 = Vector3(u + w, v, depth)
		v2 = Vector3(u + w, v + h, depth)
		v3 = Vector3(u, v + h, depth)
	elif normal == Vector3.FORWARD: # -Z
		v0 = Vector3(u + w, v, depth)
		v1 = Vector3(u, v, depth)
		v2 = Vector3(u, v + h, depth)
		v3 = Vector3(u + w, v + h, depth)
		
	var center_offset = Vector3(0.5, 0.5, 0.5)
	v0 -= center_offset; v1 -= center_offset; v2 -= center_offset; v3 -= center_offset
		
	var y_offset = 0.0
	if not has_water_above:
		if b_id == 28: y_offset = 0.125
		elif b_id >= 101 and b_id <= 107: y_offset = 0.125 + (b_id - 100) * 0.11
	
	if y_offset > 0:
		if normal == Vector3.UP:
			v0.y -= y_offset; v1.y -= y_offset; v2.y -= y_offset; v3.y -= y_offset
		elif normal == Vector3.RIGHT or normal == Vector3.LEFT or normal == Vector3.BACK or normal == Vector3.FORWARD:
			if v0.y == v + h - 0.5: v0.y -= y_offset
			if v1.y == v + h - 0.5: v1.y -= y_offset
			if v2.y == v + h - 0.5: v2.y -= y_offset
			if v3.y == v + h - 0.5: v3.y -= y_offset
			
	if b_id == 5: # Torch (1x1 quad only)
		var h_shrink = (1.0 - 0.125) / 2.0
		var v_shrink = 1.0 - 0.625
		if normal == Vector3.UP:
			v0.x += h_shrink; v0.z += h_shrink; v0.y -= v_shrink
			v1.x -= h_shrink; v1.z += h_shrink; v1.y -= v_shrink
			v2.x -= h_shrink; v2.z -= h_shrink; v2.y -= v_shrink
			v3.x += h_shrink; v3.z -= h_shrink; v3.y -= v_shrink
		elif normal == Vector3.DOWN:
			v0.x += h_shrink; v0.z -= h_shrink
			v1.x -= h_shrink; v1.z -= h_shrink
			v2.x -= h_shrink; v2.z += h_shrink
			v3.x += h_shrink; v3.z += h_shrink
		elif normal == Vector3.RIGHT:
			v0.z -= h_shrink; v1.z += h_shrink
			v2.z += h_shrink; v2.y -= v_shrink
			v3.z -= h_shrink; v3.y -= v_shrink
			v0.x -= h_shrink; v1.x -= h_shrink; v2.x -= h_shrink; v3.x -= h_shrink
		elif normal == Vector3.LEFT:
			v0.z += h_shrink; v1.z -= h_shrink
			v2.z -= h_shrink; v2.y -= v_shrink
			v3.z += h_shrink; v3.y -= v_shrink
			v0.x += h_shrink; v1.x += h_shrink; v2.x += h_shrink; v3.x += h_shrink
		elif normal == Vector3.BACK:
			v0.x -= h_shrink; v1.x += h_shrink
			v2.x += h_shrink; v2.y -= v_shrink
			v3.x -= h_shrink; v3.y -= v_shrink
			v0.z -= h_shrink; v1.z -= h_shrink; v2.z -= h_shrink; v3.z -= h_shrink
		elif normal == Vector3.FORWARD:
			v0.x += h_shrink; v1.x -= h_shrink
			v2.x -= h_shrink; v2.y -= v_shrink
			v3.x += h_shrink; v3.y -= v_shrink
			v0.z += h_shrink; v1.z += h_shrink; v2.z += h_shrink; v3.z += h_shrink
			
	var face_idx = 0
	if normal == Vector3.UP: face_idx = 1
	elif normal == Vector3.DOWN: face_idx = 2
	
	var b_data = DataManager.get_block_data(b_id)
	var uv_rect = DataManager.get_block_uv(b_id)
	if b_data.has("faces"):
		if face_idx == 1 and b_data["faces"].has("top"):
			uv_rect = DataManager.uv_map.get(b_data["faces"]["top"], uv_rect)
		elif face_idx == 2 and b_data["faces"].has("bottom"):
			uv_rect = DataManager.uv_map.get(b_data["faces"]["bottom"], uv_rect)
		elif face_idx == 0 and b_data["faces"].has("side"):
			uv_rect = DataManager.uv_map.get(b_data["faces"]["side"], uv_rect)
			
	var color = get_block_color_by_face(b_id, face_idx)
	var is_water = (b_id == 28 or b_id == 49 or (b_id >= 101 and b_id <= 107))
	
	if is_water: _has_water = true
	else: _has_blocks = true
	
	st.set_custom(0, Color(uv_rect.u_min, uv_rect.v_min, uv_rect.u_max, uv_rect.v_max))
	st.set_color(color)
	st.set_normal(normal)
	
	st.set_uv(Vector2(0, h)); st.add_vertex(v0)
	st.set_uv(Vector2(w, 0)); st.add_vertex(v2)
	st.set_uv(Vector2(w, h)); st.add_vertex(v1)
	
	st.set_uv(Vector2(0, h)); st.add_vertex(v0)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v3)
	st.set_uv(Vector2(w, 0)); st.add_vertex(v2)
