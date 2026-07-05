extends Node3D

const CHUNK_SIZE = 16
var blocks = []

var st = SurfaceTool.new()
var mesh_instance = MeshInstance3D.new()
var static_body = StaticBody3D.new()
var collision_shape = CollisionShape3D.new()
var material = StandardMaterial3D.new()

func _ready():
	material.albedo_color = Color(0.4, 0.8, 0.4)
	
	add_child(mesh_instance)
	mesh_instance.add_child(static_body)
	static_body.add_child(collision_shape)
	static_body.add_to_group("blocks")
	
	blocks.resize(CHUNK_SIZE)
	for x in range(CHUNK_SIZE):
		blocks[x] = []
		blocks[x].resize(CHUNK_SIZE)
		for y in range(CHUNK_SIZE):
			blocks[x][y] = []
			blocks[x][y].resize(CHUNK_SIZE)
			for z in range(CHUNK_SIZE):
				blocks[x][y][z] = 1 # 1 = Đá
	
	print("Kích thước mảng: ", blocks.size(), "x", blocks[0].size(), "x", blocks[0][0].size())
	update_chunk_mesh()

func set_block(pos: Vector3, block_type: int):
	var x = int(pos.x)
	var y = int(pos.y)
	var z = int(pos.z)
	
	if x >= 0 and x < CHUNK_SIZE and y >= 0 and y < CHUNK_SIZE and z >= 0 and z < CHUNK_SIZE:
		blocks[x][y][z] = block_type
		update_chunk_mesh()

func update_chunk_mesh():
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	
	var has_blocks = false
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				if blocks[x][y][z] == 1:
					create_block_mesh(Vector3(x, y, z))
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
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

func create_block_mesh(pos: Vector3):
	var v0 = pos + Vector3(-0.5, -0.5, -0.5)
	var v1 = pos + Vector3(0.5, -0.5, -0.5)
	var v2 = pos + Vector3(0.5, 0.5, -0.5)
	var v3 = pos + Vector3(-0.5, 0.5, -0.5)
	var v4 = pos + Vector3(-0.5, -0.5, 0.5)
	var v5 = pos + Vector3(0.5, -0.5, 0.5)
	var v6 = pos + Vector3(0.5, 0.5, 0.5)
	var v7 = pos + Vector3(-0.5, 0.5, 0.5)

	# Front (+Z)
	add_quad(v4, v7, v6, v5, Vector3(0, 0, 1))
	# Back (-Z)
	add_quad(v1, v2, v3, v0, Vector3(0, 0, -1))
	# Right (+X)
	add_quad(v5, v6, v2, v1, Vector3(1, 0, 0))
	# Left (-X)
	add_quad(v0, v3, v7, v4, Vector3(-1, 0, 0))
	# Top (+Y)
	add_quad(v7, v3, v2, v6, Vector3(0, 1, 0))
	# Bottom (-Y)
	add_quad(v0, v4, v5, v1, Vector3(0, -1, 0))
