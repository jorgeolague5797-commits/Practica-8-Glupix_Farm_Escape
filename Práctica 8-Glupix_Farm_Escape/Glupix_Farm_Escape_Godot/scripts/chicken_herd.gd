extends Node3D

const CHICKEN_MODEL := preload("res://models/chicken_voxel.glb")
const WARNING_SOUND := preload("res://audio/chicken_warning.wav")

@export var direction: int = 1
@export var speed: float = 22.0
@export var herd_count: int = 8
@export var spacing: float = 0.92
@export var warning_duration: float = 1.15
@export var cooldown_min: float = 2.6
@export var cooldown_max: float = 4.8
@export var start_x_abs: float = 13.0
@export var end_x_abs: float = 13.0

var rng := RandomNumberGenerator.new()
var state: String = "waiting"
var timer: float = 0.0
var can_hit: bool = true
var anim_time: float = 0.0
var dust_timer: float = 0.0

var mover: Node3D
var hit_area: Area3D
var warning_player: AudioStreamPlayer
var chicken_nodes: Array[Node3D] = []
var dust_particles: Array[Dictionary] = []

func _ready() -> void:
	rng.randomize()
	direction = 1 if direction >= 0 else -1
	_build_herd()
	_set_waiting()

func _process(delta: float) -> void:
	anim_time += delta
	_update_chicken_animation(delta)
	_update_dust_particles(delta)

	if state == "waiting":
		timer -= delta
		if timer <= 0.0:
			_start_warning()
	elif state == "warning":
		timer -= delta
		# ligera vibración mientras esperan salir
		mover.position.z = sin(anim_time * 10.0) * 0.02
		if timer <= 0.0:
			mover.position.z = 0.0
			_start_passing()
	elif state == "passing":
		mover.position.x += float(direction) * speed * delta
		dust_timer -= delta
		if dust_timer <= 0.0:
			dust_timer = 0.06
			_spawn_dust_puff()
		if _has_finished_crossing():
			_set_waiting()

func _build_herd() -> void:
	mover = Node3D.new()
	mover.name = "ManadaMovil"
	add_child(mover)

	for i in range(herd_count):
		var holder := Node3D.new()
		holder.name = "PolloHolder_%d" % i
		var x_offset: float = (float(i) - float(herd_count - 1) * 0.5) * spacing
		var z_offset: float = 0.18 if i % 2 == 0 else -0.18
		holder.position = Vector3(x_offset, 0.34, z_offset)
		mover.add_child(holder)
		chicken_nodes.append(holder)

		var chicken = CHICKEN_MODEL.instantiate()
		chicken.name = "Pollo_Rapido_%d" % i
		chicken.scale = Vector3(0.30, 0.30, 0.30)
		# Miran hacia la derecha; si el carril viene del otro lado, se voltean.
		chicken.rotation_degrees = Vector3(-90, 90 if direction > 0 else -90, 0)
		holder.add_child(chicken)

		var shadow := MeshInstance3D.new()
		shadow.name = "Sombra_%d" % i
		var shadow_mesh := BoxMesh.new()
		shadow_mesh.size = Vector3(0.55, 0.025, 0.38)
		shadow.mesh = shadow_mesh
		shadow.position = Vector3(0.0, 0.025, 0.0)
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.albedo_color = Color(0.05, 0.04, 0.03, 0.35)
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow.set_surface_override_material(0, shadow_mat)
		holder.add_child(shadow)

	hit_area = Area3D.new()
	hit_area.name = "HitArea_ManadaPollos"
	hit_area.monitoring = false
	hit_area.monitorable = true
	mover.add_child(hit_area)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(float(herd_count) * spacing + 1.2, 1.2, 1.35)
	collision.shape = box
	collision.position = Vector3(0.0, 0.65, 0.0)
	hit_area.add_child(collision)
	hit_area.body_entered.connect(_on_body_entered)

	warning_player = AudioStreamPlayer.new()
	warning_player.name = "AlertaPollos"
	warning_player.stream = WARNING_SOUND
	warning_player.volume_db = -2.0
	add_child(warning_player)

func _set_waiting() -> void:
	state = "waiting"
	timer = rng.randf_range(cooldown_min, cooldown_max)
	can_hit = true
	hit_area.monitoring = false
	mover.position.x = -start_x_abs if direction > 0 else start_x_abs
	mover.position.z = 0.0

func _start_warning() -> void:
	state = "warning"
	timer = warning_duration
	hit_area.monitoring = false
	mover.position.x = -start_x_abs if direction > 0 else start_x_abs
	mover.position.z = 0.0
	if warning_player:
		warning_player.stop()
		warning_player.play()

func _start_passing() -> void:
	state = "passing"
	hit_area.monitoring = true
	can_hit = true
	dust_timer = 0.0

func _has_finished_crossing() -> bool:
	if direction > 0:
		return mover.position.x > end_x_abs
	return mover.position.x < -end_x_abs

func _update_chicken_animation(delta: float) -> void:
	for i in range(chicken_nodes.size()):
		var holder: Node3D = chicken_nodes[i]
		var phase: float = anim_time * 15.0 + float(i) * 0.85
		var hop: float = 0.05 + max(0.0, sin(phase)) * (0.10 if state == "passing" else 0.04)
		var sway: float = sin(phase * 0.5) * 0.04
		holder.position.y = 0.34 + hop
		holder.position.z += (sway - holder.position.z + (0.18 if i % 2 == 0 else -0.18)) * min(1.0, delta * 8.0)
		var model: Node3D = holder.get_node("Pollo_Rapido_%d" % i)
		model.rotation_degrees.x = -90 + sin(phase) * 8.0
		model.rotation_degrees.z = sin(phase * 1.2) * 6.0
		model.rotation_degrees.y = (90 if direction > 0 else -90) + cos(phase) * 3.0

func _spawn_dust_puff() -> void:
	var puff_root := Node3D.new()
	puff_root.name = "PolvoCubico"
	var back_sign: float = -1.0 if direction > 0 else 1.0
	var offset_z: float = rng.randf_range(-0.35, 0.35)
	puff_root.position = Vector3(mover.position.x + back_sign * 0.9, 0.10, mover.position.z + offset_z)
	add_child(puff_root)

	for i in range(4):
		var cube := MeshInstance3D.new()
		cube.name = "Cubito_%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, 0.12, 0.12)
		cube.mesh = mesh
		cube.position = Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, 0.18), rng.randf_range(-0.12, 0.12))
		var mat := StandardMaterial3D.new()
		var gray := 0.70 + rng.randf_range(0.0, 0.12)
		mat.albedo_color = Color(gray, gray, gray, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cube.set_surface_override_material(0, mat)
		puff_root.add_child(cube)

	dust_particles.append({
		"node": puff_root,
		"life": 0.48,
		"vel": Vector3(-float(direction) * 1.8, 1.2, rng.randf_range(-0.25, 0.25))
	})

func _update_dust_particles(delta: float) -> void:
	for i in range(dust_particles.size() - 1, -1, -1):
		var p: Dictionary = dust_particles[i]
		var node: Node3D = p["node"]
		var life: float = float(p["life"])
		var vel: Vector3 = p["vel"]
		life -= delta
		node.position += vel * delta
		vel.y += 0.8 * delta
		p["life"] = life
		p["vel"] = vel
		dust_particles[i] = p
		for child in node.get_children():
			if child is MeshInstance3D:
				var mesh_instance: MeshInstance3D = child
				mesh_instance.scale += Vector3.ONE * delta * 0.35
				var mat: StandardMaterial3D = mesh_instance.get_active_material(0) as StandardMaterial3D
				if mat != null:
					var c: Color = mat.albedo_color
					c.a = max(0.0, life / 0.48)
					mat.albedo_color = c
		if life <= 0.0:
			node.queue_free()
			dust_particles.remove_at(i)

func _on_body_entered(body: Node) -> void:
	if not can_hit:
		return
	if not body.is_in_group("player"):
		return

	can_hit = false
	get_tree().call_group("game_manager", "on_player_hit_npc", self)
	await get_tree().create_timer(0.45).timeout
	can_hit = true
