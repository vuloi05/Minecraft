extends Node3D

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16
const RENDER_DISTANCE = 3

var chunks = {} # Dictionary mapping Vector2i -> Chunk
var material = StandardMaterial3D.new()
var noise = FastNoiseLite.new()
var player: CharacterBody3D

func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	
	var noise_tex = FastNoiseLite.new()
	noise_tex.seed = randi()
	noise_tex.frequency = 0.5
	var tex = NoiseTexture2D.new()
	tex.noise = noise_tex
	tex.width = 64
	tex.height = 64
	
	material.albedo_color = Color(0.3, 0.6, 0.2)
	material.albedo_texture = tex
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	player = get_parent().get_node("Player")

func _process(_delta):
	if player:
		var px = int(floor(player.global_position.x))
		var pz = int(floor(player.global_position.z))
		
		var pcx = int(floor(float(px) / CHUNK_SIZE_X))
		var pcz = int(floor(float(pz) / CHUNK_SIZE_Z))
		
		var player_chunk = Vector2i(pcx, pcz)
		update_chunks(player_chunk)

func update_chunks(player_chunk: Vector2i):
	# Sinh chunk mới
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			var cpos = player_chunk + Vector2i(x, z)
			if not chunks.has(cpos):
				var chunk = Chunk.new(cpos, noise, material, self)
				chunks[cpos] = chunk
				add_child(chunk)
				# Gọi update_chunk_mesh cho chunk hiện tại
				chunk.update_chunk_mesh()
				# Nếu sinh chunk mới, cập nhật lại mặt lưới của hàng xóm
				update_neighbor_meshes(cpos)
	
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
