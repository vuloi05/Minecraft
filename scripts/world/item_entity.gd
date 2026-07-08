extends RigidBody3D
class_name ItemEntity

static var _atlas_cache: Texture2D = null
static var _tex_cache: Dictionary = {}

var item_id: int = 0
var count: int = 1
var bob_time: float = 0.0

@onready var sprite = $Sprite3D
@onready var block_mesh_node = $BlockMesh
@onready var pickup_area = $PickupArea

var is_block = false

func _ready():
	# Cấu hình RigidBody
	collision_layer = 0
	collision_mask = 1 # Va chạm với thế giới (StaticBody3D của chunk)
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	
	# Load texture cho item
	var b_data = DataManager.get_block_data(item_id)
	if b_data:
		is_block = not b_data.get("is_item", false)
		
		# Flora and some specific blocks render as sprites
		if item_id in [42, 45, 46, 47, 48, 5]: 
			is_block = false
		
		if is_block:
			sprite.hide()
			block_mesh_node.show()
			_build_block_mesh()
		else:
			if b_data.has("model_3d"):
				sprite.hide()
				block_mesh_node.hide()
				var model_path = b_data["model_3d"]
				var model_scene = load("res://assets/models/" + model_path)
				if model_scene:
					tool_model = model_scene.instantiate()
					add_child(tool_model)
					tool_model.scale = Vector3(0.3, 0.3, 0.3)
			else:
				sprite.show()
				block_mesh_node.hide()
				var tex_name = b_data.get("texture", "")
				var tex = null
				
				if _tex_cache.has(tex_name):
					tex = _tex_cache[tex_name]
				else:
					var tex_item = "res://assets/textures/items/" + tex_name
					var tex_block = "res://assets/textures/blocks/" + tex_name
					if FileAccess.file_exists(tex_item) or FileAccess.file_exists(tex_item + ".import"):
						tex = load(tex_item) as Texture2D
					elif FileAccess.file_exists(tex_block) or FileAccess.file_exists(tex_block + ".import"):
						tex = load(tex_block) as Texture2D
					_tex_cache[tex_name] = tex
					
				if tex:
					sprite.texture = tex
					var max_dim = max(tex.get_width(), tex.get_height())
					if max_dim > 0:
						sprite.pixel_size = 0.5 / float(max_dim)
					else:
						sprite.pixel_size = 0.03

	pickup_area.body_entered.connect(_on_body_entered)

var tool_model: Node3D = null

func _process(delta):
	bob_time += delta * 2.0
	var offset_y = sin(bob_time) * 0.1
	sprite.position.y = offset_y
	block_mesh_node.position.y = offset_y
	if tool_model: tool_model.position.y = offset_y
	
	sprite.rotation.y += delta
	block_mesh_node.rotation.y += delta
	if tool_model: tool_model.rotation.y += delta

func _on_body_entered(body):
	if body.name == "Player" or body.has_method("take_damage"):
		if body.ui:
			body.ui.add_item(item_id, count)
			queue_free()

func _build_block_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var uv_top = DataManager.get_block_uv(item_id)
	var uv_bottom = uv_top
	var uv_side = uv_top
	
	var c_top = Color(1, 1, 1)
	var c_side = Color(0.8, 0.8, 0.8)
	var c_bottom = Color(0.6, 0.6, 0.6)
	
	if item_id == 1: # Grass Block
		c_top *= Color(0.4, 0.7, 0.3)
		if DataManager.uv_map.has("grass_block_top"): uv_top = DataManager.uv_map["grass_block_top"]
		elif DataManager.uv_map.has("grass_block_side"): uv_top = DataManager.uv_map["grass_block_side"]
		if DataManager.uv_map.has("dirt"): uv_bottom = DataManager.uv_map["dirt"]
		if DataManager.uv_map.has("grass_block_side"): uv_side = DataManager.uv_map["grass_block_side"]
	elif item_id == 4: # Leaves
		var tint = Color(0.2, 0.55, 0.1)
		c_top *= tint; c_side *= tint; c_bottom *= tint
		
	var hs = 0.5 # half size
	var v0 = Vector3(-hs, -hs, hs)
	var v1 = Vector3(hs, -hs, hs)
	var v2 = Vector3(hs, -hs, -hs)
	var v3 = Vector3(-hs, -hs, -hs)
	var v4 = Vector3(-hs, hs, hs)
	var v5 = Vector3(hs, hs, hs)
	var v6 = Vector3(hs, hs, -hs)
	var v7 = Vector3(-hs, hs, -hs)
	
	_add_quad(st, v4, v7, v6, v5, Vector3(0, 1, 0), uv_top, c_top)
	_add_quad(st, v0, v1, v2, v3, Vector3(0, -1, 0), uv_bottom, c_bottom)
	_add_quad(st, v0, v4, v5, v1, Vector3(0, 0, 1), uv_side, c_side)
	_add_quad(st, v2, v6, v7, v3, Vector3(0, 0, -1), uv_side, c_side)
	_add_quad(st, v3, v7, v4, v0, Vector3(-1, 0, 0), uv_side, c_side)
	_add_quad(st, v1, v5, v6, v2, Vector3(1, 0, 0), uv_side, c_side)
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	if _atlas_cache == null:
		_atlas_cache = load("res://assets/textures/atlas.png")
	if _atlas_cache:
		mat.albedo_texture = _atlas_cache
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.no_depth_test = false
	
	block_mesh_node.mesh = mesh
	block_mesh_node.material_override = mat

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv_rect: Dictionary, color: Color = Color(1, 1, 1)):
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); st.add_vertex(v0)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_min)); st.add_vertex(v1)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); st.add_vertex(v2)
	
	st.set_normal(normal)
	st.set_color(color)
	st.set_uv(Vector2(uv_rect.u_min, uv_rect.v_max)); st.add_vertex(v0)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_min)); st.add_vertex(v2)
	st.set_uv(Vector2(uv_rect.u_max, uv_rect.v_max)); st.add_vertex(v3)
