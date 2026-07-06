extends Node3D

var body: Node3D
var head_pivot: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D

var walk_time = 0.0
var idle_time = 0.0
var hit_time = 0.0

var steve_material: StandardMaterial3D

func _init():
	# Tạo Material
	steve_material = StandardMaterial3D.new()
	var tex = load("res://steve.png")
	if tex:
		steve_material.albedo_texture = tex
		steve_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Pixel art
		steve_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		steve_material.roughness = 1.0
	else:
		steve_material.albedo_color = Color.WHITE

	body = Node3D.new()
	add_child(body)
	
	# Body (Thân) - UV: 16, 16 | Kích thước pixel: 8x12x4
	var body_mesh = create_part(body, Vector3(0.5, 0.75, 0.25), Vector3(0, 1.125, 0), 16, 16, 8, 12, 4)
	
	# Head (Đầu) - UV: 0, 0 | Kích thước pixel: 8x8x8
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.5, 0)
	body.add_child(head_pivot)
	var head_mesh = create_part(head_pivot, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), 0, 0, 8, 8, 8)
	
	# Mũ/Lớp thứ 2 của đầu (Hat) - UV: 32, 0 | Kích thước pixel: 8x8x8, to hơn 1 chút
	var hat_mesh = create_part(head_pivot, Vector3(0.52, 0.52, 0.52), Vector3(0, 0.25, 0), 32, 0, 8, 8, 8)
	hat_mesh.get_active_material(0).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	hat_mesh.get_active_material(0).alpha_scissor_threshold = 0.5
	
	# Left Arm - UV: 32, 48 | Kích thước: 4x12x4
	left_arm_pivot = Node3D.new()
	left_arm_pivot.position = Vector3(-0.375, 1.5, 0)
	body.add_child(left_arm_pivot)
	var left_arm_mesh = create_part(left_arm_pivot, Vector3(0.25, 0.75, 0.25), Vector3(0, -0.375, 0), 32, 48, 4, 12, 4)
	
	# Right Arm - UV: 40, 16 | Kích thước: 4x12x4
	right_arm_pivot = Node3D.new()
	right_arm_pivot.position = Vector3(0.375, 1.5, 0)
	body.add_child(right_arm_pivot)
	var right_arm_mesh = create_part(right_arm_pivot, Vector3(0.25, 0.75, 0.25), Vector3(0, -0.375, 0), 40, 16, 4, 12, 4)
	
	# Left Leg - UV: 16, 48 | Kích thước: 4x12x4
	left_leg_pivot = Node3D.new()
	left_leg_pivot.position = Vector3(-0.125, 0.75, 0)
	body.add_child(left_leg_pivot)
	var left_leg_mesh = create_part(left_leg_pivot, Vector3(0.25, 0.75, 0.25), Vector3(0, -0.375, 0), 16, 48, 4, 12, 4)
	
	# Right Leg - UV: 0, 16 | Kích thước: 4x12x4
	right_leg_pivot = Node3D.new()
	right_leg_pivot.position = Vector3(0.125, 0.75, 0)
	body.add_child(right_leg_pivot)
	var right_leg_mesh = create_part(right_leg_pivot, Vector3(0.25, 0.75, 0.25), Vector3(0, -0.375, 0), 0, 16, 4, 12, 4)

# Hàm build khối lập phương với UV theo chuẩn Minecraft
func create_part(parent: Node, size: Vector3, pos: Vector3, uv_x: int, uv_y: int, w: int, h: int, d: int) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var sx = size.x / 2.0; var sy = size.y / 2.0; var sz = size.z / 2.0
	
	# Helper: add face
	var add_face = func(p1, p2, p3, p4, u, v, fw, fh, normal):
		var tw = 64.0; var th = 64.0
		var uv1 = Vector2(u / tw, v / th)
		var uv2 = Vector2((u + fw) / tw, v / th)
		var uv3 = Vector2((u + fw) / tw, (v + fh) / th)
		var uv4 = Vector2(u / tw, (v + fh) / th)
		
		st.set_normal(normal)
		st.set_uv(uv1); st.add_vertex(p1)
		st.set_uv(uv2); st.add_vertex(p2)
		st.set_uv(uv3); st.add_vertex(p3)
		st.set_normal(normal)
		st.set_uv(uv1); st.add_vertex(p1)
		st.set_uv(uv3); st.add_vertex(p3)
		st.set_uv(uv4); st.add_vertex(p4)

	# Đỉnh của hình hộp (nhìn từ trước)
	var tfl = Vector3(-sx, sy, sz)  # top front left
	var tfr = Vector3(sx, sy, sz)   # top front right
	var tbl = Vector3(-sx, sy, -sz) # top back left
	var tbr = Vector3(sx, sy, -sz)  # top back right
	var bfl = Vector3(-sx, -sy, sz) # bottom front left
	var bfr = Vector3(sx, -sy, sz)  # bottom front right
	var bbl = Vector3(-sx, -sy, -sz) # bottom back left
	var bbr = Vector3(sx, -sy, -sz)  # bottom back right
	
	# Top (Y+)
	add_face.call(tbl, tbr, tfr, tfl, uv_x + d, uv_y, w, d, Vector3.UP)
	# Bottom (Y-)
	add_face.call(bfl, bfr, bbr, bbl, uv_x + d + w, uv_y, w, d, Vector3.DOWN)
	# Right (X+) (Minecraft Right is -X in Godot view, but let's map it based on looking at face)
	# Minecraft Left/Right are from character's perspective. Right arm is at -X if facing +Z.
	add_face.call(tfr, tbr, bbr, bfr, uv_x, uv_y + d, d, h, Vector3.RIGHT)
	# Front (Z+)
	add_face.call(tfl, tfr, bfr, bfl, uv_x + d, uv_y + d, w, h, Vector3.BACK) # Z+ is towards camera
	# Left (X-)
	add_face.call(tbl, tfl, bfl, bbl, uv_x + d + w, uv_y + d, d, h, Vector3.LEFT)
	# Back (Z-)
	add_face.call(tbr, tbl, bbl, bbr, uv_x + d + w + d, uv_y + d, w, h, Vector3.FORWARD)

	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = st.commit()
	mesh_inst.material_override = steve_material.duplicate() # Để có thể chỉnh alpha_scissor riêng cho mũ
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	
	# Đổ bóng và chia Layer (Layer 2 để có thể ẩn khỏi góc nhìn thứ nhất nhưng vẫn đổ bóng)
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_inst.layers = 2 
	return mesh_inst

func animate(velocity: Vector3, is_mining: bool, head_rotation_x: float, delta: float):
	var speed = Vector2(velocity.x, velocity.z).length()
	
	# Đầu xoay theo pitch (nhìn lên xuống)
	head_pivot.rotation.x = head_rotation_x
	# Đầu xoay yaw (trái phải) được xử lý bởi player_body ở player.gd, 
	# thân và đầu cùng quay theo camera_yaw trong FPS/TPS.
	
	if speed > 0.5:
		walk_time += delta * 15.0
		var swing = sin(walk_time)
		
		# Vung tay chân theo tốc độ di chuyển
		left_arm_pivot.rotation.x = swing * 0.8
		right_arm_pivot.rotation.x = -swing * 0.8
		left_leg_pivot.rotation.x = -swing * 0.8
		right_leg_pivot.rotation.x = swing * 0.8
		
		body.position.y = abs(sin(walk_time)) * 0.05
	else:
		walk_time = 0.0
		left_leg_pivot.rotation.x = lerp(left_leg_pivot.rotation.x, 0.0, delta * 10.0)
		right_leg_pivot.rotation.x = lerp(right_leg_pivot.rotation.x, 0.0, delta * 10.0)
		
		if not is_mining:
			left_arm_pivot.rotation.x = lerp(left_arm_pivot.rotation.x, 0.0, delta * 10.0)
			right_arm_pivot.rotation.x = lerp(right_arm_pivot.rotation.x, 0.0, delta * 10.0)
			
		idle_time += delta * 2.0
		body.position.y = sin(idle_time) * 0.02

	if is_mining:
		hit_time += delta * 25.0
		var hit_swing = abs(sin(hit_time))
		right_arm_pivot.rotation.x = -hit_swing * 1.5 - 0.5
		right_arm_pivot.rotation.z = hit_swing * 0.2
	else:
		hit_time = 0.0
		right_arm_pivot.rotation.z = lerp(right_arm_pivot.rotation.z, 0.0, delta * 10.0)

