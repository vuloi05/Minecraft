extends Node3D

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16
const RENDER_DISTANCE = 3

var chunks = {} # Dictionary mapping Vector2i -> Chunk
var chunks_mutex = Mutex.new() # Mutex để đồng bộ đa luồng khi đọc/ghi vào dictionary chunks

const MAX_THREADS = 8
var active_threads = 0

var material = StandardMaterial3D.new()
var water_material = StandardMaterial3D.new()
var noise = FastNoiseLite.new()
var cave_noise = FastNoiseLite.new()
var temp_noise = FastNoiseLite.new()
var humid_noise = FastNoiseLite.new()
var player: CharacterBody3D

# Hàng đợi để sinh Chunk dần dần
var chunk_queue = []
var chunk_queue_set = {} # HashSet O(1) lookup thay vì Array.has() O(n)

var torches = {} # Vector3 -> OmniLight3D
var zombie_timer = 0.0
var passive_mob_timer = 0.0

var active_blocks = {} # Dictionary mapping Vector3i -> bool for physics update
var physics_tick_timer = 0.0
const PHYSICS_TICK_RATE = 0.2

var is_initial_load = true
var total_initial_chunks = (RENDER_DISTANCE * 2 + 1) * (RENDER_DISTANCE * 2 + 1)
var loaded_initial_chunks = 0

func _ready():
	noise.seed = 1234
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	var noise_tex = FastNoiseLite.new()
	noise_tex.seed = 1234
	noise_tex.frequency = 0.5
	var tex = NoiseTexture2D.new()
	tex.noise = noise_tex
	tex.width = 64
	tex.height = 64
	
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = 4321
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise.frequency = 0.05
	
	temp_noise = FastNoiseLite.new()
	temp_noise.seed = 1111
	temp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temp_noise.frequency = 0.005 # Biome chuyển đổi rất chậm
	
	humid_noise = FastNoiseLite.new()
	humid_noise.seed = 2222
	humid_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	humid_noise.frequency = 0.005
	
	material = ShaderMaterial.new()
	var chunk_shader = load("res://assets/shaders/chunk.gdshader")
	material.shader = chunk_shader
	
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://assets/shaders/water.gdshader")
	
	var atlas_tex = load("res://assets/textures/atlas.png")
	if atlas_tex:
		material.set_shader_parameter("atlas", atlas_tex)
		water_material.set_shader_parameter("atlas", atlas_tex)
	else:
		material.set_shader_parameter("atlas", tex)
		water_material.set_shader_parameter("atlas", tex)
		
	material.set_shader_parameter("use_alpha_scissor", true)
	water_material.set_shader_parameter("use_alpha_scissor", false)
		
	# Mặc định ShaderMaterial tự dùng cull_back, opaque/alpha thông qua shader render_mode
	# Tint lá và cỏ sẽ được cấp qua v_color trong shader
	
	# Tính năng trong suốt của nước đã được định nghĩa là một phần của vertex_color và alpha của nước

	
	player = get_parent().get_node("Player")

func _process(delta):
	if player:
		var px = int(floor(player.global_position.x))
		var pz = int(floor(player.global_position.z))
		
		var pcx = int(floor(float(px) / CHUNK_SIZE_X))
		var pcz = int(floor(float(pz) / CHUNK_SIZE_Z))
		
		var player_chunk = Vector2i(pcx, pcz)
		update_chunks(player_chunk)
		
		# Xử lý hàng đợi sinh Chunk (Giới hạn task đồng thời)
		if chunk_queue.size() > 0 and active_threads < MAX_THREADS:
			# Sắp xếp ưu tiên sinh Chunk gần người chơi nhất trước
			chunk_queue.sort_custom(func(a, b):
				var da = abs(a.x - pcx) + abs(a.y - pcz)
				var db = abs(b.x - pcx) + abs(b.y - pcz)
				return da < db
			)
			
			var cpos = chunk_queue.pop_front()
			chunk_queue_set.erase(cpos)
			# Chỉ sinh nếu nó vẫn còn nằm trong tầm nhìn
			if abs(cpos.x - pcx) <= RENDER_DISTANCE and abs(cpos.y - pcz) <= RENDER_DISTANCE:
				chunks_mutex.lock()
				var has_chunk = chunks.has(cpos)
				chunks_mutex.unlock()
				
				if not has_chunk:
					var chunk = Chunk.new(cpos, noise, material, self, cave_noise, water_material, temp_noise, humid_noise)
					
					chunks_mutex.lock()
					chunks[cpos] = chunk
					active_threads += 1
					chunks_mutex.unlock()
					
					add_child(chunk)
					
					# Giao việc sinh khối và tạo Mesh cho WorkerThreadPool (Luồng ngầm)
					chunk.task_id = WorkerThreadPool.add_task(chunk.thread_generate)
		
		# Xử lý vật lý (Tick System)
		physics_tick_timer += delta
		if physics_tick_timer >= PHYSICS_TICK_RATE:
			physics_tick_timer = 0.0
			process_block_physics()
			
		# --- Xử lý sinh Passive Mobs ---
		passive_mob_timer += delta
		if passive_mob_timer >= 5.0:
			passive_mob_timer = 0.0
			var current_mobs = get_tree().get_nodes_in_group("passive_mobs").size()
			if current_mobs < 15: # Giới hạn tối đa 15 con vật
				spawn_passive_mob()
		
		# --- Xử lý sinh Zombie vào ban đêm ---
		var sun = get_parent().get_node_or_null("DirectionalLight3D")
		# Khi rotation.x của mặt trời nhỏ hơn 0 tức là nó đang chiếu từ dưới lên -> Ban đêm
		if sun and sun.rotation.x < 0:
			zombie_timer += delta
			if zombie_timer >= 3.0:
				zombie_timer = 0.0
				var current_zombies = get_tree().get_nodes_in_group("mobs").size()
				if current_zombies < 5: # Giới hạn tối đa 5 Zombie
					pass # spawn_zombie() - Tạm thời tắt quái vật theo yêu cầu của user
		else:
			# Nếu là ban ngày, tiêu diệt toàn bộ zombie (Zombie cháy nắng)
			var zombies = get_tree().get_nodes_in_group("mobs")
			for z in zombies:
				z.queue_free()

func spawn_passive_mob():
	if not player: return
	var spawn_x = int(player.global_position.x) + randi_range(-30, 30)
	var spawn_z = int(player.global_position.z) + randi_range(-30, 30)
	
	if abs(spawn_x - player.global_position.x) < 10 and abs(spawn_z - player.global_position.z) < 10:
		return
		
	var highest_y = 60
	while highest_y > 0 and get_block_global(spawn_x, highest_y, spawn_z) == 0:
		highest_y -= 1
		
	if highest_y <= 0: return
	
	var block_id = get_block_global(spawn_x, highest_y, spawn_z)
	if block_id == 1: # Chỉ spawn trên cỏ
		var mob
		var r = randi() % 3
		if r == 0: mob = load("res://scripts/entities/mobs/pig.gd").new()
		elif r == 1: mob = load("res://scripts/entities/mobs/cow.gd").new()
		else: mob = load("res://scripts/entities/mobs/sheep.gd").new()
		
		mob.position = Vector3(spawn_x, highest_y + 2, spawn_z)
		mob.add_to_group("passive_mobs")
		add_child(mob)

func spawn_zombie():
	var z = Zombie.new()
	var spawn_x = player.global_position.x + randf_range(-20, 20)
	var spawn_z = player.global_position.z + randf_range(-20, 20)
	
	if abs(spawn_x - player.global_position.x) < 5 and abs(spawn_z - player.global_position.z) < 5:
		return # Không spawn quá gần
		
	z.position = Vector3(spawn_x, 60, spawn_z) # Thả từ trên trời
	z.player = player
	add_child(z)

func on_chunk_generated(cpos: Vector2i):
	update_neighbor_meshes(cpos)
	chunks_mutex.lock()
	active_threads -= 1
	chunks_mutex.unlock()
	
	if is_initial_load:
		loaded_initial_chunks += 1
		var percent = int(float(loaded_initial_chunks) / total_initial_chunks * 100)
		if player and player.ui and player.ui.has_method("update_loading"):
			player.ui.update_loading(percent)
		if loaded_initial_chunks >= total_initial_chunks:
			is_initial_load = false
			if player.has_method("finish_loading"):
				player.finish_loading()
			if player.ui and player.ui.has_method("finish_loading"):
				player.ui.finish_loading()

func update_chunks(player_chunk: Vector2i):
	# Thêm chunk mới vào hàng đợi thay vì sinh ngay lập tức
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			var cpos = player_chunk + Vector2i(x, z)
			if not chunks.has(cpos) and not chunk_queue_set.has(cpos):
				chunk_queue.append(cpos)
				chunk_queue_set[cpos] = true
	
	# Xóa chunk ở xa
	var chunks_to_remove = []
	for cpos in chunks.keys():
		var dist_x = abs(cpos.x - player_chunk.x)
		var dist_z = abs(cpos.y - player_chunk.y)
		if dist_x > RENDER_DISTANCE + 1 or dist_z > RENDER_DISTANCE + 1:
			chunks_to_remove.append(cpos)
	
	for cpos in chunks_to_remove:
		chunks_mutex.lock()
		var chunk = chunks[cpos]
		chunks.erase(cpos)
		chunks_mutex.unlock()
		chunk.schedule_free()

func update_neighbor_meshes(cpos: Vector2i):
	var neighbors = [
		cpos + Vector2i(1, 0),
		cpos + Vector2i(-1, 0),
		cpos + Vector2i(0, 1),
		cpos + Vector2i(0, -1)
	]
	
	chunks_mutex.lock()
	for npos in neighbors:
		if chunks.has(npos):
			var c = chunks[npos]
			if c.is_data_ready and not c.is_meshing:
				# Đẩy sang WorkerThreadPool thay vì chạy đồng bộ trên Main Thread
				WorkerThreadPool.add_task(c.thread_update_mesh)
	chunks_mutex.unlock()

func get_chunk_safe(pos: Vector2i) -> Chunk:
	chunks_mutex.lock()
	var c = chunks.get(pos)
	chunks_mutex.unlock()
	return c

func get_block_global(x: int, y: int, z: int) -> int:
	if y < 0 or y >= CHUNK_SIZE_Y: return 0
	
	var cx = int(floor(float(x) / CHUNK_SIZE_X))
	var cz = int(floor(float(z) / CHUNK_SIZE_Z))
	
	var cpos = Vector2i(cx, cz)
	var c = get_chunk_safe(cpos)
	if c and c.is_data_ready:
		var lx = x - (cx * CHUNK_SIZE_X)
		var lz = z - (cz * CHUNK_SIZE_Z)
		return c.get_block_local(lx, y, lz)
	
	# Xử lý Race Condition: Nếu Chunk hàng xóm chưa sinh data xong, 
	# ta coi như nó là đá đặc (trả về 7) để tạm thời che đi mặt giáp ranh, không bị thủng lưới
	return 7

func set_block(x: int, y: int, z: int, block_type: int):
	var cx = int(floor(float(x) / CHUNK_SIZE_X))
	var cz = int(floor(float(z) / CHUNK_SIZE_Z))
	var cpos = Vector2i(cx, cz)
	
	var c = get_chunk_safe(cpos)
	if c:
		var lx = x - (cx * CHUNK_SIZE_X)
		var lz = z - (cz * CHUNK_SIZE_Z)
		c.set_block(lx, y, lz, block_type)
		
		# Ẩn collision ngay lập tức để người chơi không va vào "block ma"
		if block_type == 0:
			c.hide_block_collision_at(lx, y, lz)
			
		WorkerThreadPool.add_task(c.thread_update_mesh) # Cập nhật lưới chunk hiện tại ngầm
		
		# Cập nhật lưới chunk hàng xóm nếu đập/đặt ở mép
		var neighbors = []
		if lx == 0: neighbors.append(Vector2i(cx - 1, cz))
		elif lx == CHUNK_SIZE_X - 1: neighbors.append(Vector2i(cx + 1, cz))
		if lz == 0: neighbors.append(Vector2i(cx, cz - 1))
		elif lz == CHUNK_SIZE_Z - 1: neighbors.append(Vector2i(cx, cz + 1))
		
		for npos in neighbors:
			var n = get_chunk_safe(npos)
			if n and n.is_data_ready:
				WorkerThreadPool.add_task(n.thread_update_mesh)
				
		# Cập nhật vật lý cho block này và các block xung quanh
		schedule_block_update(x, y, z)
		schedule_block_update(x, y + 1, z)
		schedule_block_update(x, y - 1, z)
		schedule_block_update(x + 1, y, z)
		schedule_block_update(x - 1, y, z)
		schedule_block_update(x, y, z + 1)
		schedule_block_update(x, y, z - 1)
		
		# --- Xử lý Ánh sáng Đuốc ---
		var pos = Vector3(x, y, z)
		if block_type == 5:
			if not torches.has(pos):
				var torch_node = Node3D.new()
				torch_node.position = pos
				
				# Lưới của Đuốc giờ đây được vẽ bởi chunk.gd
				# Ở đây chỉ sinh ra ánh sáng (OmniLight3D)
				var light = OmniLight3D.new()
				light.shadow_enabled = true # Bật đổ bóng để không xuyên tường
				light.shadow_bias = 0.02 # Giảm shadow bias để không lọt sáng qua kẽ hở (Peter panning)
				light.shadow_normal_bias = 0.0
				light.light_color = Color(1.0, 0.9, 0.6)
				light.light_energy = 2.0
				light.omni_range = 10.0
				light.position = Vector3(0, 0.3, 0) # Đẩy ánh sáng lên phần ngọn của Node
				
				torch_node.add_child(light)
				add_child(torch_node)
				torches[pos] = torch_node
		elif block_type == 0:
			if torches.has(pos):
				torches[pos].queue_free()
				torches.erase(pos)

var _item_scene_cache = null

func spawn_item(id: int, count: int, pos: Vector3):
	if _item_scene_cache == null:
		_item_scene_cache = load("res://scenes/ItemEntity.tscn")
	if _item_scene_cache:
		var item = _item_scene_cache.instantiate()
		item.item_id = id
		item.count = count
		item.position = pos + Vector3(0.5, 0.5, 0.5) # Center of the block
		
		# Thêm lực bật ngẫu nhiên nhẹ lên trên
		item.linear_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 4.0), randf_range(-1.0, 1.0))
		call_deferred("add_child", item)

func schedule_block_update(x: int, y: int, z: int):
	if y >= 0 and y < CHUNK_SIZE_Y:
		active_blocks[Vector3i(x, y, z)] = true

func set_block_silent(x: int, y: int, z: int, block_type: int, remesh_dict: Dictionary):
	var cx = int(floor(float(x) / CHUNK_SIZE_X))
	var cz = int(floor(float(z) / CHUNK_SIZE_Z))
	var cpos = Vector2i(cx, cz)
	var c = get_chunk_safe(cpos)
	if c and c.is_data_ready:
		var lx = x - (cx * CHUNK_SIZE_X)
		var lz = z - (cz * CHUNK_SIZE_Z)
		if c.get_block_local(lx, y, lz) != block_type:
			c.set_block(lx, y, lz, block_type)
			remesh_dict[cpos] = c
			
			if block_type == 0:
				c.hide_block_collision_at(lx, y, lz)
			
			if lx == 0: remesh_dict[Vector2i(cx - 1, cz)] = get_chunk_safe(Vector2i(cx - 1, cz))
			elif lx == CHUNK_SIZE_X - 1: remesh_dict[Vector2i(cx + 1, cz)] = get_chunk_safe(Vector2i(cx + 1, cz))
			if lz == 0: remesh_dict[Vector2i(cx, cz - 1)] = get_chunk_safe(Vector2i(cx, cz - 1))
			elif lz == CHUNK_SIZE_Z - 1: remesh_dict[Vector2i(cx, cz + 1)] = get_chunk_safe(Vector2i(cx, cz + 1))

func process_block_physics():
	if active_blocks.is_empty(): return
	
	var blocks_to_process = active_blocks.keys()
	active_blocks.clear()
	
	var chunks_to_remesh = {}
	
	for pos in blocks_to_process:
		var b = get_block_global(pos.x, pos.y, pos.z)
		
		# Cát (26) hoặc Sỏi (27)
		if b == 26 or b == 27:
			if pos.y > 0:
				var below = get_block_global(pos.x, pos.y - 1, pos.z)
				if below == 0 or below == 28: # Rơi vào không khí hoặc nước
					set_block_silent(pos.x, pos.y, pos.z, 0, chunks_to_remesh)
					spawn_falling_block(pos.x, pos.y, pos.z, b)
					
					schedule_block_update(pos.x, pos.y, pos.z)
					# Chú ý: cập nhật các block bên cạnh để chúng cũng rơi nếu cần
					schedule_block_update(pos.x, pos.y + 1, pos.z)
					
					var dirs = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
					for d in dirs:
						schedule_block_update(pos.x + d.x, pos.y, pos.z + d.z)
					
		# Nước (28 và các trạng thái chảy)
		elif b == 28 or (b >= 101 and b <= 107):
			if pos.y > 0:
				var below = get_block_global(pos.x, pos.y - 1, pos.z)
				var spread_down = false
				
				# Rơi thẳng xuống (Cascade) - Giữ nguyên level theo yêu cầu của user để tránh tràn vô hạn trên dốc
				if below == 0 or (below >= 101 and below <= 107 and below > b):
					var fall_id = b if b != 28 else 101
					set_block_silent(pos.x, pos.y - 1, pos.z, fall_id, chunks_to_remesh)
					schedule_block_update(pos.x, pos.y - 1, pos.z)
					spread_down = true
				
				# Nếu chạm sàn cứng, chảy lan ra xung quanh
				if not spread_down and b != 107:
					var next_flow_id = 101 if b == 28 else (b + 1)
					
					var dirs = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
					for d in dirs:
						var neighbor = get_block_global(pos.x + d.x, pos.y, pos.z + d.z)
						if neighbor == 0:
							set_block_silent(pos.x + d.x, pos.y, pos.z + d.z, next_flow_id, chunks_to_remesh)
							schedule_block_update(pos.x + d.x, pos.y, pos.z + d.z)
						elif neighbor >= 101 and neighbor <= 107 and neighbor > next_flow_id:
							# Chiếm luồng nước nếu luồng nước hiện tại mạnh hơn
							set_block_silent(pos.x + d.x, pos.y, pos.z + d.z, next_flow_id, chunks_to_remesh)
							schedule_block_update(pos.x + d.x, pos.y, pos.z + d.z)
							
	for c in chunks_to_remesh.values():
		if c and c.is_data_ready:
			WorkerThreadPool.add_task(c.thread_update_mesh)

var _falling_block_script = preload("res://scripts/world/falling_block.gd")

func spawn_falling_block(x: int, y: int, z: int, block_id: int):
	var fb = _falling_block_script.new()
	fb.block_id = block_id
	fb.world_ref = self
	fb.position = Vector3(x, y, z)
	add_child(fb)
