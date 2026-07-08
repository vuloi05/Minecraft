extends CharacterBody3D
class_name FallingBlock

var block_id: int = 0
var world_ref: Node3D = null

var gravity = 12.0
var _mesh_node = MeshInstance3D.new()
var is_landing = false

func _ready():
	collision_layer = 0
	collision_mask = 1 # Va chạm với thế giới
	
	# Khởi tạo CollisionShape3D
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.95, 0.95, 0.95)
	shape.shape = box
	add_child(shape)
	
	# Khởi tạo Mesh
	add_child(_mesh_node)
	_build_mesh()
	
func _physics_process(delta):
	if is_landing: return
	
	velocity.y -= gravity * delta
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		is_landing = true
		_land()

func _land():
	if world_ref:
		# Làm tròn tọa độ để tính ô lưới
		var grid_x = int(round(global_position.x))
		var grid_y = int(round(global_position.y))
		var grid_z = int(round(global_position.z))
		
		# Đặt lại block vào thế giới (nếu ô đó đang trống hoặc là nước)
		var b = world_ref.get_block_global(grid_x, grid_y, grid_z)
		if b == 0 or b == 28:
			world_ref.set_block(grid_x, grid_y, grid_z, block_id)
		else:
			# Đặt lùi lên 1 ô nếu lỡ chìm vào khối khác
			world_ref.set_block(grid_x, grid_y + 1, grid_z, block_id)
			
	queue_free()

func _build_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var uv_top = DataManager.get_block_uv(block_id)
	var uv_bottom = uv_top
	var uv_side = uv_top
	
	var hs = 0.5
	var v0 = Vector3(-hs, -hs, hs)
	var v1 = Vector3(hs, -hs, hs)
	var v2 = Vector3(hs, hs, hs)
	var v3 = Vector3(-hs, hs, hs)
	var v4 = Vector3(-hs, -hs, -hs)
	var v5 = Vector3(hs, -hs, -hs)
	var v6 = Vector3(hs, hs, -hs)
	var v7 = Vector3(-hs, hs, -hs)
	
	var top_color = Color(1, 1, 1)
	var bottom_color = Color(0.6, 0.6, 0.6)
	var side_color = Color(0.8, 0.8, 0.8)
	
	# Mặt trước
	_add_quad(st, v0, v1, v2, v3, Vector3(0, 0, 1), uv_side, side_color)
	# Mặt sau
	_add_quad(st, v5, v4, v7, v6, Vector3(0, 0, -1), uv_side, side_color)
	# Mặt phải
	_add_quad(st, v1, v5, v6, v2, Vector3(1, 0, 0), uv_side, side_color)
	# Mặt trái
	_add_quad(st, v4, v0, v3, v7, Vector3(-1, 0, 0), uv_side, side_color)
	# Mặt trên
	_add_quad(st, v3, v2, v6, v7, Vector3(0, 1, 0), uv_top, top_color)
	# Mặt dưới
	_add_quad(st, v4, v5, v1, v0, Vector3(0, -1, 0), uv_bottom, bottom_color)
	
	var mesh = st.commit()
	var material = StandardMaterial3D.new()
	var atlas_tex = load("res://assets/textures/atlas.png")
	if atlas_tex:
		material.albedo_texture = atlas_tex
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	_mesh_node.mesh = mesh
	_mesh_node.material_override = material

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv_rect: Dictionary, color: Color):
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); st.add_vertex(v0)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_max)); st.add_vertex(v1)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); st.add_vertex(v2)
	
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); st.add_vertex(v0)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); st.add_vertex(v2)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_min)); st.add_vertex(v3)
