extends Node3D

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16
const RENDER_DISTANCE = 3

var chunks = {} # Dictionary mapping Vector2i -> Chunk
var material = StandardMaterial3D.new()
var noise = FastNoiseLite.new()
var player: CharacterBody3D

# Hàng đợi để sinh Chunk dần dần, tránh giật lag
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
		
		# Xử lý hàng đợi sinh Chunk (1 Chunk mỗi Frame)
		if chunk_queue.size() > 0:
			# Sắp xếp ưu tiên sinh Chunk gần người chơi nhất trước
			chunk_queue.sort_custom(func(a, b):
				var da = abs(a.x - pcx) + abs(a.y - pcz)
				var db = abs(b.x - pcx) + abs(b.y - pcz)
				return da < db
			)
			
			var cpos = chunk_queue.pop_front()
			# Chỉ sinh nếu nó vẫn còn nằm trong tầm nhìn
			if abs(cpos.x - pcx) <= RENDER_DISTANCE and abs(cpos.y - pcz) <= RENDER_DISTANCE:
				if not chunks.has(cpos):
					var chunk = Chunk.new(cpos, noise, material, self)
					chunks[cpos] = chunk
					add_child(chunk)
					chunk.update_chunk_mesh()
					update_neighbor_meshes(cpos)
					
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
		var chunk = chunks[cpos]
		chunk.queue_free()
		chunks.erase(cpos)

func update_neighbor_meshes(cpos: Vector2i):
	var neighbors = [
		cpos + Vector2i(1, 0),
		cpos + Vector2i(-1, 0),
		cpos + Vector2i(0, 1),
		cpos + Vector2i(0, -1)
	]
	for npos in neighbors:
		if chunks.has(npos):
			chunks[npos].update_chunk_mesh()

func get_block_global(x: int, y: int, z: int) -> int:
	if y < 0 or y >= CHUNK_SIZE_Y: return 0
	
	var cx = int(floor(float(x) / CHUNK_SIZE_X))
	var cz = int(floor(float(z) / CHUNK_SIZE_Z))
	
	var cpos = Vector2i(cx, cz)
	if chunks.has(cpos):
		var lx = x - (cx * CHUNK_SIZE_X)
		var lz = z - (cz * CHUNK_SIZE_Z)
		return chunks[cpos].blocks[lx][y][lz]
	
	return 0

func set_block(global_pos: Vector3, block_type: int):
	var x = int(round(global_pos.x))
	var y = int(round(global_pos.y))
	var z = int(round(global_pos.z))
	
	if y < 0 or y >= CHUNK_SIZE_Y: return
	
	var cx = int(floor(float(x) / CHUNK_SIZE_X))
	var cz = int(floor(float(z) / CHUNK_SIZE_Z))
	
	var cpos = Vector2i(cx, cz)
	if chunks.has(cpos):
		var lx = x - (cx * CHUNK_SIZE_X)
		var lz = z - (cz * CHUNK_SIZE_Z)
		chunks[cpos].set_block(lx, y, lz, block_type)
		update_neighbor_meshes(cpos)
		
		# --- Xử lý Ánh sáng Đuốc ---
		var pos = Vector3(x, y, z)
		if block_type == 5:
			if not torches.has(pos):
				var light = OmniLight3D.new()
				light.shadow_enabled = true # Bật đổ bóng để không xuyên tường
				light.shadow_bias = 0.02 # Giảm shadow bias để không lọt sáng qua kẽ hở (Peter panning)
				light.shadow_normal_bias = 0.0
				light.light_color = Color(1.0, 0.9, 0.6)
				light.light_energy = 2.0
				light.omni_range = 10.0
				light.position = pos + Vector3(0, 0.3, 0) # Đẩy ánh sáng lên phần ngọn
				add_child(light)
				torches[pos] = light
		elif block_type == 0:
			if torches.has(pos):
				torches[pos].queue_free()
				torches.erase(pos)
