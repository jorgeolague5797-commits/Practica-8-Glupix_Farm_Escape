extends Camera3D

@export var offset: Vector3 = Vector3(0, 12, 10)
@export var follow_speed: float = 5.0
var target: Node3D

func set_target(new_target: Node3D) -> void:
	target = new_target

func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position + offset, follow_speed * delta)
		look_at(target.global_position, Vector3.UP)
