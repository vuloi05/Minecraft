extends CharacterBody3D
class_name Zombie

var speed = 3.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: CharacterBody3D
var attack_timer = 0.0

func _ready():
	add_to_group("mobs")
	# Tạo hình dáng (Capsule màu xanh lá đại diện Zombie)
	var mesh_inst = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 0.2)
	mesh.material = mat
	mesh_inst.mesh = mesh
	mesh_inst.position.y = 0.9
	add_child(mesh_inst)
	
	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

func _physics_process(delta):
	# Trọng lực
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if player and is_instance_valid(player):
		var dir = player.global_position - global_position
		dir.y = 0 # Chỉ đi ngang, không bay
		
		# Despawn nếu cách quá xa
		if dir.length() > 40.0:
			queue_free()
			return
			
		if dir.length() > 1.2:
			dir = dir.normalized()
			# Chỉ di chuyển ngang
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			attack_timer = 0.0
		else:
			# Tới gần thì cắn
			velocity.x = 0
			velocity.z = 0
			attack_timer += delta
			if attack_timer >= 1.0:
				if player.has_method("take_damage"):
					player.take_damage(2)
				attack_timer = 0.0
	else:
		velocity.x = 0
		velocity.z = 0
		
	move_and_slide()

var hp = 20

func take_damage(amount: int, knockback_dir: Vector3 = Vector3.ZERO):
	hp -= amount
	if knockback_dir != Vector3.ZERO:
		velocity = knockback_dir * 5.0
		velocity.y = 4.0
	print("Zombie bị đánh mất ", amount, " máu! Còn ", hp)
	if hp <= 0:
		queue_free()
