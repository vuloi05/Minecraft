extends Node3D

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16
const RENDER_DISTANCE = 3

var chunks = {} # Dictionary mapping Vector2i -> Chunk
var chunks_mutex = Mutex.new() # Mutex để đồng bộ đa luồng khi đọc/ghi vào dictionary chunks

const MAX_THREADS = 4
var active_threads = 0

var material = StandardMaterial3D.new()
var noise = FastNoiseLite.new()
var player: CharacterBody3D

# Hàng đợi để sinh Chunk dần dần
var chunk_queue = []

var torches = {} # Vector3 -> OmniLight3D
var zombie_timer = 0.0

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
	
	material.albedo_color = Color(1, 1, 1) # Cho phép màu đỉnh hiển thị
	material.albedo_texture = tex
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true # Bật Vertex Colors
	
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
			# Chỉ sinh nếu nó vẫn còn nằm trong tầm nhìn
			if abs(cpos.x - pcx) <= RENDER_DISTANCE and abs(cpos.y - pcz) <= RENDER_DISTANCE:
				chunks_mutex.lock()
				var has_chunk = chunks.has(cpos)
				chunks_mutex.unlock()
				
				if not has_chunk:
					var chunk = Chunk.new(cpos, noise, material, self)
					
					chunks_mutex.lock()
					chunks[cpos] = chunk
					active_threads += 1
					chunks_mutex.unlock()
					
					add_child(chunk)
					
					# Giao việc sinh khối và tạo Mesh cho WorkerThreadPool (Luồng ngầm)
					WorkerThreadPool.add_task(chunk.thread_generate)
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
	chunks_mutex.lock()
	active_threads -= 1
	chunks_mutex.unlock()
	
	# Gọi luồng ngầm update hàng xóm thay vì update đồng bộ trên Main Thread
	update_neighbor_meshes_async(cpos)
	
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
			if not chunks.has(cpos) and not chunk_queue.has(cpos):
				chunk_queue.append(cpos)
	
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
		chunk.queue_free()

func update_neighbor_meshes_async(cpos: Vector2i):
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
				c.is_meshing = true
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
		return c.blocks[lx][y][lz]
	
	# Xử lý Race Condition: Nếu Chunk hàng xóm chưa sinh data xong, 
	# ta coi như nó là đá đặc (trả về 7) để tạm thời che đi mặt giáp ranh, không bị thủng lưới
	return 7

func set_block(global_pos: Vector3, block_type: int):
	var x = int(round(global_pos.x))
	var y = int(round(global_pos.y))
	var z = int(round(global_pos.z))
	
	if y < 0 or y >= CHUNK_SIZE_Y: return
	
	var cx = int(floor(float(x) / CHUNK_SIZE_X))
	var cz = int(floor(float(z) / CHUNK_SIZE_Z))
	
	var cpos = Vector2i(cx, cz)
	var c = get_chunk_safe(cpos)
	if c:
		var lx = x - (cx * CHUNK_SIZE_X)
		var lz = z - (cz * CHUNK_SIZE_Z)
		c.set_block(lx, y, lz, block_type)
		c.update_chunk_mesh() # Cập nhật lưới chunk hiện tại
		
		# Cập nhật lưới chunk hàng xóm nếu đập/đặt ở mép
		var neighbors = []
		if lx == 0: neighbors.append(cpos + Vector2i(-1, 0))
		elif lx == CHUNK_SIZE_X - 1: neighbors.append(cpos + Vector2i(1, 0))
		if lz == 0: neighbors.append(cpos + Vector2i(0, -1))
		elif lz == CHUNK_SIZE_Z - 1: neighbors.append(cpos + Vector2i(0, 1))
		
		for npos in neighbors:
			var n = get_chunk_safe(npos)
			if n and n.is_data_ready:
				n.update_chunk_mesh()
		
		# --- Xử lý Ánh sáng Đuốc ---
		var pos = Vector3(x, y, z)
		if block_type == 5:
			if not torches.has(pos):
				var torch_node = Node3D.new()
				torch_node.position = pos
				
				# Vẽ đuốc bằng Sprite3D (Crossed planes)
				var tex = load("res://Torch.webp") as Texture2D
				if tex != null:
					var p_size = 0.04
					
					var s1 = Sprite3D.new()
					s1.texture = tex
					s1.pixel_size = p_size
					s1.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					s1.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD # Tránh lỗi chèn hình trong Godot
					s1.position = Vector3(0, -0.2, 0)
					torch_node.add_child(s1)
					
					var s2 = Sprite3D.new()
					s2.texture = tex
					s2.pixel_size = p_size
					s2.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
					s2.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
					s2.position = Vector3(0, -0.2, 0)
					s2.rotation_degrees = Vector3(0, 90, 0)
					torch_node.add_child(s2)
				else:
					var mesh = MeshInstance3D.new()
					var box = BoxMesh.new()
					box.size = Vector3(0.1, 0.5, 0.1)
					mesh.mesh = box
					mesh.position = Vector3(0, -0.25, 0)
					torch_node.add_child(mesh)
						
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
