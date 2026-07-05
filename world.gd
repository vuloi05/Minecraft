extends Node3D

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16

var blocks = []

var st = SurfaceTool.new()
var mesh_instance = MeshInstance3D.new()
var static_body = StaticBody3D.new()

var material = StandardMaterial3D.new()
var noise = FastNoiseLite.new()

# Object Pool để tái sử dụng CollisionShape3D thay vì Trimesh (chống lỗi xuyên tường)
var collision_pool = []
var active_collisions = 0

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
	
	add_child(mesh_instance)
	mesh_instance.add_child(static_body)
	static_body.add_to_group("blocks")
	
	blocks.resize(CHUNK_SIZE_X)
	for x in range(CHUNK_SIZE_X):
		blocks[x] = []
		blocks[x].resize(CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			blocks[x][y] = []
			blocks[x][y].resize(CHUNK_SIZE_Z)
			for z in range(CHUNK_SIZE_Z):
				var terrain_height = int((noise.get_noise_2d(x, z) + 1.0) * 0.5 * 20) + 10
				if y <= terrain_height:
					blocks[x][y][z] = 1
				else:
					blocks[x][y][z] = 0
	
	update_chunk_mesh()

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE_X or y < 0 or y >= CHUNK_SIZE_Y or z < 0 or z >= CHUNK_SIZE_Z:
		return 0
	return blocks[x][y][z]

func set_block(pos: Vector3, block_type: int):
	var x = int(round(pos.x))
	var y = int(round(pos.y))
	var z = int(round(pos.z))
	
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
	st.set_material(material)
	
	active_collisions = 0
	
	var has_blocks = false
	for x in range(CHUNK_SIZE_X):
		for y in range(CHUNK_SIZE_Y):
			for z in range(CHUNK_SIZE_Z):
				if blocks[x][y][z] == 1:
					if is_block_exposed(x, y, z):
						create_block_mesh(x, y, z)
						var shape = get_collision_shape()
						shape.position = Vector3(x, y, z)
						shape.disabled = false
						has_blocks = true
	
	# Vô hiệu hóa các CollisionBox thừa trong Pool
	for i in range(active_collisions, collision_pool.size()):
		collision_pool[i].disabled = true
	
	if has_blocks:
		mesh_instance.mesh = st.commit()
	else:
		mesh_instance.mesh = null

func add_quad(v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3):
	st.set_normal(normal)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 0)); st.add_vertex(v1)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
	st.set_uv(Vector2(1, 1)); st.add_vertex(v2)
	st.set_uv(Vector2(0, 1)); st.add_vertex(v3)

func create_block_mesh(x: int, y: int, z: int):
	var pos = Vector3(x, y, z)
	var v0 = pos + Vector3(-0.5, -0.5, -0.5)
	var v1 = pos + Vector3(0.5, -0.5, -0.5)
	var v2 = pos + Vector3(0.5, 0.5, -0.5)
	var v3 = pos + Vector3(-0.5, 0.5, -0.5)
	var v4 = pos + Vector3(-0.5, -0.5, 0.5)
	var v5 = pos + Vector3(0.5, -0.5, 0.5)
	var v6 = pos + Vector3(0.5, 0.5, 0.5)
	var v7 = pos + Vector3(-0.5, 0.5, 0.5)

	if get_block(x, y, z + 1) == 0: add_quad(v4, v7, v6, v5, Vector3(0, 0, 1))
	if get_block(x, y, z - 1) == 0: add_quad(v1, v2, v3, v0, Vector3(0, 0, -1))
	if get_block(x + 1, y, z) == 0: add_quad(v5, v6, v2, v1, Vector3(1, 0, 0))
	if get_block(x - 1, y, z) == 0: add_quad(v0, v3, v7, v4, Vector3(-1, 0, 0))
	if get_block(x, y + 1, z) == 0: add_quad(v7, v3, v2, v6, Vector3(0, 1, 0))
	if get_block(x, y - 1, z) == 0: add_quad(v0, v4, v5, v1, Vector3(0, -1, 0))
