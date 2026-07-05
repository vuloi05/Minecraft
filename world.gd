extends Node3D

const CHUNK_SIZE_X = 16
const CHUNK_SIZE_Y = 64
const CHUNK_SIZE_Z = 16

var blocks = []

var st = SurfaceTool.new()
var mesh_instance = MeshInstance3D.new()
var static_body = StaticBody3D.new()
var collision_shape = CollisionShape3D.new()
var material = StandardMaterial3D.new()

var noise = FastNoiseLite.new()

func _ready():
	# Cấu hình Noise để sinh địa hình tự nhiên
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	
	# Tạo texture từ code (Vân đất/cỏ)
	var noise_tex = FastNoiseLite.new()
	noise_tex.seed = randi()
	noise_tex.frequency = 0.5
	var tex = NoiseTexture2D.new()
	tex.noise = noise_tex
	tex.width = 64
	tex.height = 64
	
	# Cấu hình Material
	material.albedo_color = Color(0.3, 0.6, 0.2)
	material.albedo_texture = tex
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	add_child(mesh_instance)
	mesh_instance.add_child(static_body)
	static_body.add_child(collision_shape)
	static_body.add_to_group("blocks")
	
	# Khởi tạo mảng 3D
	blocks.resize(CHUNK_SIZE_X)
	for x in range(CHUNK_SIZE_X):
		blocks[x] = []
		blocks[x].resize(CHUNK_SIZE_Y)
		for y in range(CHUNK_SIZE_Y):
			blocks[x][y] = []
			blocks[x][y].resize(CHUNK_SIZE_Z)
			for z in range(CHUNK_SIZE_Z):
				# Sinh địa hình bằng Noise
				var terrain_height = int((noise.get_noise_2d(x, z) + 1.0) * 0.5 * 20) + 10 # Độ cao từ 10 đến 30
				if y <= terrain_height:
					blocks[x][y][z] = 1 # Đá/Đất
				else:
					blocks[x][y][z] = 0 # Không khí
	
	update_chunk_mesh()

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= CHUNK_SIZE_X or y < 0 or y >= CHUNK_SIZE_Y or z < 0 or z >= CHUNK_SIZE_Z:
		return 0 # Không khí bên ngoài giới hạn
	return blocks[x][y][z]

func set_block(pos: Vector3, block_type: int):
	var x = int(round(pos.x))
	var y = int(round(pos.y))
	var z = int(round(pos.z))
	
	if x >= 0 and x < CHUNK_SIZE_X and y >= 0 and y < CHUNK_SIZE_Y and z >= 0 and z < CHUNK_SIZE_Z:
		blocks[x][y][z] = block_type
		update_chunk_mesh()

func update_chunk_mesh():
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	
	var has_blocks = false
	for x in range(CHUNK_SIZE_X):
		for y in range(CHUNK_SIZE_Y):
			for z in range(CHUNK_SIZE_Z):
				if blocks[x][y][z] == 1:
					create_block_mesh(x, y, z)
					has_blocks = true
	
	if has_blocks:
		var mesh = st.commit()
		mesh_instance.mesh = mesh
		collision_shape.shape = mesh.create_trimesh_shape()
	else:
		mesh_instance.mesh = null
		collision_shape.shape = null

func add_quad(v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3):
	st.set_normal(normal)
	
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	
	st.set_uv(Vector2(1, 0))
	st.add_vertex(v1)
	
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)
	
	st.set_uv(Vector2(0, 0))
	st.add_vertex(v0)
	
	st.set_uv(Vector2(1, 1))
	st.add_vertex(v2)
	
	st.set_uv(Vector2(0, 1))
	st.add_vertex(v3)

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

	# Front (+Z)
	if get_block(x, y, z + 1) == 0:
		add_quad(v4, v7, v6, v5, Vector3(0, 0, 1))
	# Back (-Z)
	if get_block(x, y, z - 1) == 0:
		add_quad(v1, v2, v3, v0, Vector3(0, 0, -1))
	# Right (+X)
	if get_block(x + 1, y, z) == 0:
		add_quad(v5, v6, v2, v1, Vector3(1, 0, 0))
	# Left (-X)
	if get_block(x - 1, y, z) == 0:
		add_quad(v0, v3, v7, v4, Vector3(-1, 0, 0))
	# Top (+Y)
	if get_block(x, y + 1, z) == 0:
		add_quad(v7, v3, v2, v6, Vector3(0, 1, 0))
	# Bottom (-Y)
	if get_block(x, y - 1, z) == 0:
		add_quad(v0, v4, v5, v1, Vector3(0, -1, 0))
