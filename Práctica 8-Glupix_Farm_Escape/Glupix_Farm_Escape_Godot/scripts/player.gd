extends CharacterBody3D

@export var grid_size: float = 2.0
@export var step_speed: float = 10.0
@export var min_x: float = -8.0
@export var max_x: float = 8.0
@export var max_back_z: float = 24.0

var start_position: Vector3
var facing_direction: Vector3 = Vector3.FORWARD
var target_position: Vector3
var is_moving := false

@onready var model_root: Node3D = $ModelRoot

func _ready() -> void:
	add_to_group("player")
	start_position = global_position
	target_position = global_position
	_ensure_input_map()
	_update_model_rotation()

func _ensure_input_map() -> void:
	# WASD/flechas giran; espacio avanza.
	var actions = {
		"turn_forward": [KEY_W, KEY_UP],
		"turn_back": [KEY_S, KEY_DOWN],
		"turn_left": [KEY_A, KEY_LEFT],
		"turn_right": [KEY_D, KEY_RIGHT],
		"jump_forward": [KEY_SPACE],
	}
	for action in actions.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	if not is_moving:
		if Input.is_action_just_pressed("turn_forward"):
			facing_direction = Vector3.FORWARD
			_update_model_rotation()
		elif Input.is_action_just_pressed("turn_back"):
			facing_direction = Vector3.BACK
			_update_model_rotation()
		elif Input.is_action_just_pressed("turn_left"):
			facing_direction = Vector3.LEFT
			_update_model_rotation()
		elif Input.is_action_just_pressed("turn_right"):
			facing_direction = Vector3.RIGHT
			_update_model_rotation()

		if Input.is_action_just_pressed("jump_forward"):
			var proposed_target: Vector3 = global_position + facing_direction * grid_size
			proposed_target.x = clamp(proposed_target.x, min_x, max_x)
			proposed_target.z = min(proposed_target.z, max_back_z)

			var managers := get_tree().get_nodes_in_group("game_manager")
			if managers.size() > 0 and managers[0].has_method("can_player_move_to"):
				if not managers[0].call("can_player_move_to", proposed_target):
					return

			target_position = proposed_target
			if global_position.distance_to(target_position) > 0.01:
				is_moving = true

	if is_moving:
		global_position = global_position.move_toward(target_position, step_speed * delta)
		global_position.x = clamp(global_position.x, min_x, max_x)
		global_position.z = min(global_position.z, max_back_z)
		model_root.position.y = abs(sin(Time.get_ticks_msec() * 0.025)) * 0.18
		if global_position.distance_to(target_position) < 0.03:
			global_position = target_position
			model_root.position.y = 0.0
			is_moving = false

func _update_model_rotation() -> void:
	model_root.rotation.y = atan2(facing_direction.x, facing_direction.z)

func reset_player() -> void:
	global_position = start_position
	target_position = start_position
	velocity = Vector3.ZERO
	is_moving = false
	facing_direction = Vector3.FORWARD
	_update_model_rotation()


func stop_player() -> void:
	velocity = Vector3.ZERO
	target_position = global_position
	is_moving = false
	model_root.position.y = 0.0
