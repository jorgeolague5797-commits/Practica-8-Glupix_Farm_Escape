extends CharacterBody3D

@export var speed: float = 4.0
@export var travel_distance: float = 10.0
@export var move_direction: Vector3 = Vector3.RIGHT
@export var hit_distance: float = 1.3

var start_position: Vector3
var target_position: Vector3
var going_to_target := true
var can_hit := true
var facing_yaw: float = 0.0
var anim_time: float = 0.0
var model_base_y: float = 0.0
var base_speed_for_api: float = 0.0

@onready var model_root: Node3D = $ModelRoot

func _ready() -> void:
	add_to_group("npc")
	start_position = global_position
	move_direction = move_direction.normalized()
	if move_direction == Vector3.ZERO:
		move_direction = Vector3.RIGHT
	target_position = start_position + move_direction * travel_distance
	_update_facing()
	model_base_y = model_root.position.y
	base_speed_for_api = speed

	if has_node("HitArea"):
		$HitArea.body_entered.connect(_on_hit_area_body_entered)

func _physics_process(delta: float) -> void:
	var goal := target_position if going_to_target else start_position
	global_position = global_position.move_toward(goal, speed * delta)
	_animate_cow(delta)

	if global_position.distance_to(goal) < 0.05:
		going_to_target = not going_to_target
		_update_facing()

func _update_facing() -> void:
	var dir := move_direction if going_to_target else -move_direction
	facing_yaw = atan2(dir.x, dir.z)
	model_root.rotation.y = facing_yaw

func _animate_cow(delta: float) -> void:
	anim_time += delta * (3.2 + speed * 0.55)
	var stride: float = anim_time
	var bounce: float = abs(sin(stride * 2.2)) * 0.08
	var roll_deg: float = sin(stride * 4.0) * 3.8
	var pitch_deg: float = sin(stride * 2.0) * 4.2
	var head_sway_deg: float = sin(stride) * 1.4
	model_root.position.y = model_base_y + bounce
	model_root.rotation.x = deg_to_rad(pitch_deg)
	model_root.rotation.y = facing_yaw + deg_to_rad(head_sway_deg)
	model_root.rotation.z = deg_to_rad(roll_deg)

func _on_hit_area_body_entered(body: Node) -> void:
	if not can_hit:
		return
	if not body.is_in_group("player"):
		return

	# Filtro extra: sólo cuenta choque si Glupix está realmente cerca en el plano X/Z.
	# Esto evita morir cuando estás parado en una zona segura y la vaca pasa por otro carril.
	var my_pos := Vector2(global_position.x, global_position.z)
	var player_pos := Vector2(body.global_position.x, body.global_position.z)
	var distance_xz := my_pos.distance_to(player_pos)

	if distance_xz <= hit_distance:
		can_hit = false
		get_tree().call_group("game_manager", "on_player_hit_npc", self)
		await get_tree().create_timer(0.5).timeout
		can_hit = true


func set_api_speed_multiplier(multiplier: float) -> void:
	if base_speed_for_api <= 0.0:
		base_speed_for_api = speed
	speed = base_speed_for_api * multiplier
