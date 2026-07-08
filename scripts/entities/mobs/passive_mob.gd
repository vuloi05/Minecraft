extends CharacterBody3D
class_name PassiveMob

const GRAVITY = 20.0
var move_speed = 2.0
var state = "IDLE"
var state_timer = 0.0
var wander_target: Vector3

var mesh_root = Node3D.new()
var collision = CollisionShape3D.new()

func _ready():
	add_child(mesh_root)
	add_child(collision)
	build_model()
	setup_collision()
	state_timer = randf() * 3.0 + 1.0
	
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	state_timer -= delta
	if state_timer <= 0:
		pick_new_state()
		
	if state == "WANDER":
		var dir = (wander_target - global_position)
		dir.y = 0
		if dir.length() > 0.5:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			
			mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, atan2(-velocity.x, -velocity.z), 10 * delta)
			play_animation("Walk", "walk", "run")
		else:
			state = "IDLE"
			velocity.x = 0; velocity.z = 0
			play_animation("Idle", "idle", "stand")
	elif state == "IDLE":
		velocity.x = 0; velocity.z = 0
		play_animation("Idle", "idle", "stand")
		
	move_and_slide()

var hp = 10

func take_damage(amount: int, knockback_dir: Vector3 = Vector3.ZERO):
	hp -= amount
	
	# Hất văng nhẹ khi bị đánh
	if knockback_dir != Vector3.ZERO:
		velocity = knockback_dir * 5.0
		velocity.y = 4.0 # Nảy lên
		
	# Đổi màu đỏ chớp nháy (có thể thêm sau, hiện tại để log)
	print(self.name, " bị đánh mất ", amount, " máu! Còn ", hp)
	
	if hp <= 0:
		print(self.name, " ĐÃ CHẾT!")
		queue_free()

var anim_player: AnimationPlayer = null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for c in node.get_children():
		var p = _find_animation_player(c)
		if p: return p
	return null

func play_animation(anim_name1: String, anim_name2: String, anim_name3: String):
	if not anim_player and mesh_root.get_child_count() > 0:
		anim_player = _find_animation_player(mesh_root.get_child(0))
		
	if anim_player:
		if anim_player.has_animation(anim_name1):
			if anim_player.current_animation != anim_name1: anim_player.play(anim_name1)
		elif anim_player.has_animation(anim_name2):
			if anim_player.current_animation != anim_name2: anim_player.play(anim_name2)
		elif anim_player.has_animation(anim_name3):
			if anim_player.current_animation != anim_name3: anim_player.play(anim_name3)

func pick_new_state():
	if randf() > 0.5:
		state = "WANDER"
		state_timer = randf() * 4.0 + 2.0
		var r = randf() * 2 * PI
		var dist = randf() * 5.0 + 3.0
		wander_target = global_position + Vector3(cos(r) * dist, 0, sin(r) * dist)
	else:
		state = "IDLE"
		state_timer = randf() * 3.0 + 1.0

func build_model():
	pass

func setup_collision():
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.9, 0.9, 0.9) # Default
	collision.shape = shape
	collision.position = Vector3(0, 0.45, 0)

func create_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mesh_root.add_child(mi)
	return mi
