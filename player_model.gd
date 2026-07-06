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

const SKIN_COLOR = Color("#b27b58")
const HAIR_COLOR = Color("#331e10")
const SHIRT_COLOR = Color("#00a2a2")
const PANTS_COLOR = Color("#48479e")
const SHOE_COLOR = Color("#444444")

func _init():
	body = Node3D.new()
	add_child(body)
	
	# Body (Thân)
	create_part(body, Vector3(0.5, 0.75, 0.25), Vector3(0, 1.125, 0), SHIRT_COLOR)
	
	# Head (Đầu)
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 1.5, 0)
	body.add_child(head_pivot)
	create_part(head_pivot, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0), SKIN_COLOR)
	# Hair (Tóc - to hơn một chút xíu để trùm lên)
	create_part(head_pivot, Vector3(0.52, 0.15, 0.52), Vector3(0, 0.45, 0), HAIR_COLOR)
	
	# Left Arm (Tay trái)
	left_arm_pivot = Node3D.new()
	left_arm_pivot.position = Vector3(-0.375, 1.5, 0)
	body.add_child(left_arm_pivot)
	create_part(left_arm_pivot, Vector3(0.25, 0.3, 0.25), Vector3(0, -0.15, 0), SHIRT_COLOR) # Tay áo
	create_part(left_arm_pivot, Vector3(0.25, 0.45, 0.25), Vector3(0, -0.525, 0), SKIN_COLOR) # Bàn tay
	
	# Right Arm (Tay phải)
	right_arm_pivot = Node3D.new()
	right_arm_pivot.position = Vector3(0.375, 1.5, 0)
	body.add_child(right_arm_pivot)
	create_part(right_arm_pivot, Vector3(0.25, 0.3, 0.25), Vector3(0, -0.15, 0), SHIRT_COLOR) # Tay áo
	create_part(right_arm_pivot, Vector3(0.25, 0.45, 0.25), Vector3(0, -0.525, 0), SKIN_COLOR) # Bàn tay
	
	# Left Leg (Chân trái)
	left_leg_pivot = Node3D.new()
	left_leg_pivot.position = Vector3(-0.125, 0.75, 0)
	body.add_child(left_leg_pivot)
	create_part(left_leg_pivot, Vector3(0.25, 0.6, 0.25), Vector3(0, -0.3, 0), PANTS_COLOR) # Quần
	create_part(left_leg_pivot, Vector3(0.26, 0.15, 0.26), Vector3(0, -0.675, 0), SHOE_COLOR) # Giày
	
	# Right Leg (Chân phải)
	right_leg_pivot = Node3D.new()
	right_leg_pivot.position = Vector3(0.125, 0.75, 0)
	body.add_child(right_leg_pivot)
	create_part(right_leg_pivot, Vector3(0.25, 0.6, 0.25), Vector3(0, -0.3, 0), PANTS_COLOR) # Quần
	create_part(right_leg_pivot, Vector3(0.26, 0.15, 0.26), Vector3(0, -0.675, 0), SHOE_COLOR) # Giày

func create_part(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	box.material = mat
	mesh_inst.mesh = box
	mesh_inst.position = pos
	parent.add_child(mesh_inst)
	
	# Bật shadow casting
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mesh_inst

func animate(velocity: Vector3, is_mining: bool, head_rotation_x: float, delta: float):
	var speed = Vector2(velocity.x, velocity.z).length()
	
	# Head follows camera pitch (nhìn lên xuống)
	head_pivot.rotation.x = head_rotation_x
	
	if speed > 0.5:
		walk_time += delta * 15.0
		var swing = sin(walk_time)
		
		# Đánh tay và vung chân (tay chân đối xứng)
		left_arm_pivot.rotation.x = swing * 0.8
		right_arm_pivot.rotation.x = -swing * 0.8
		
		left_leg_pivot.rotation.x = -swing * 0.8
		right_leg_pivot.rotation.x = swing * 0.8
		
		# Hơi nhấp nhô cơ thể khi đi
		body.position.y = abs(sin(walk_time)) * 0.05
	else:
		walk_time = 0.0
		# Trở về tư thế đứng im
		left_leg_pivot.rotation.x = lerp(left_leg_pivot.rotation.x, 0.0, delta * 10.0)
		right_leg_pivot.rotation.x = lerp(right_leg_pivot.rotation.x, 0.0, delta * 10.0)
		
		if not is_mining:
			left_arm_pivot.rotation.x = lerp(left_arm_pivot.rotation.x, 0.0, delta * 10.0)
			right_arm_pivot.rotation.x = lerp(right_arm_pivot.rotation.x, 0.0, delta * 10.0)
			
		# Idle animation (hít thở)
		idle_time += delta * 2.0
		body.position.y = sin(idle_time) * 0.02

	# Mining Animation (vung tay phải)
	if is_mining:
		hit_time += delta * 25.0
		var hit_swing = abs(sin(hit_time))
		# Vung tay lên trước rồi dập xuống
		right_arm_pivot.rotation.x = -hit_swing * 1.5 - 0.5
		right_arm_pivot.rotation.z = hit_swing * 0.2
	else:
		hit_time = 0.0
		right_arm_pivot.rotation.z = lerp(right_arm_pivot.rotation.z, 0.0, delta * 10.0)

func set_visible_model(v: bool):
	visible = v
