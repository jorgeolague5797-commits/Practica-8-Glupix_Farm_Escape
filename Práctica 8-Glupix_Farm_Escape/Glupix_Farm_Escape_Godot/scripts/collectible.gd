extends Area3D

signal collectible_picked(type_id: String, points: int)

@export var type_id: String = "mini_ufo"
@export var points: int = 100
@export var rotate_speed: float = 1.8
@export var float_height: float = 0.12
@export var float_speed: float = 2.2

var collected: bool = false
var base_y: float = 0.0
var visual_root: Node3D

func _ready() -> void:
	base_y = position.y
	body_entered.connect(_on_body_entered)
	_build_visual()
	set_process(true)

func _process(delta: float) -> void:
	rotation.y += rotate_speed * delta
	position.y = base_y + sin(Time.get_ticks_msec() / 1000.0 * float_speed) * float_height

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	collected = true
	collectible_picked.emit(type_id, points)
	get_tree().call_group("game_manager", "on_collectible_picked", type_id, points, global_position)
	queue_free()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visual_%s" % type_id
	add_child(visual_root)

	match type_id:
		"mini_ufo":
			_build_mini_ufo()
		"earth":
			_build_earth()
		"mini_alien":
			_build_mini_alien()
		"crystal":
			_build_crystal()
		"energy_core":
			_build_energy_core()
		_:
			_build_crystal()

func _warm_collectible_color(color: Color) -> Color:
	var adjusted: Color = color.lerp(Color("#ffd29a"), 0.08).darkened(0.04)
	adjusted.a = color.a
	return adjusted


func _box(name_value: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = name_value
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	var mat := StandardMaterial3D.new()
	var final_color: Color = _warm_collectible_color(color)
	mat.albedo_color = final_color
	mat.emission_enabled = true
	mat.emission = final_color.darkened(0.25)
	mat.emission_energy_multiplier = 0.08
	mat.roughness = 0.7
	mesh_instance.set_surface_override_material(0, mat)
	visual_root.add_child(mesh_instance)
	return mesh_instance

func _build_mini_ufo() -> void:
	_box("PlatoBase", Vector3(0, 0, 0), Vector3(0.95, 0.18, 0.95), Color("#8fe8ff"))
	_box("Cuerpo", Vector3(0, 0.12, 0), Vector3(0.62, 0.20, 0.62), Color("#b7f7ff"))
	_box("Cupula", Vector3(0, 0.30, 0), Vector3(0.38, 0.25, 0.38), Color("#7dff9b"))
	for i in range(4):
		var x: float = 0.36 if i < 2 else -0.36
		var z: float = 0.36 if i % 2 == 0 else -0.36
		_box("Luz_%d" % i, Vector3(x, -0.02, z), Vector3(0.16, 0.08, 0.16), Color("#ffe96b"))

func _build_earth() -> void:
	_box("Oceano", Vector3(0, 0.05, 0), Vector3(0.72, 0.72, 0.72), Color("#2f93ff"))
	_box("Continente_A", Vector3(-0.18, 0.18, 0.20), Vector3(0.28, 0.16, 0.12), Color("#43d66b"))
	_box("Continente_B", Vector3(0.22, -0.06, -0.19), Vector3(0.22, 0.20, 0.12), Color("#53c85b"))
	_box("Nube_A", Vector3(0.12, 0.32, 0.12), Vector3(0.32, 0.08, 0.10), Color("#ffffff"))
	_box("Nube_B", Vector3(-0.22, -0.24, -0.16), Vector3(0.22, 0.08, 0.10), Color("#f0f8ff"))

func _build_mini_alien() -> void:
	_box("Cuerpo", Vector3(0, -0.08, 0), Vector3(0.34, 0.45, 0.26), Color("#79ff6c"))
	_box("Cabeza", Vector3(0, 0.28, 0), Vector3(0.48, 0.40, 0.36), Color("#93ff79"))
	_box("OjoIzq", Vector3(-0.11, 0.31, 0.19), Vector3(0.09, 0.12, 0.04), Color("#111111"))
	_box("OjoDer", Vector3(0.11, 0.31, 0.19), Vector3(0.09, 0.12, 0.04), Color("#111111"))
	_box("AntenaIzq", Vector3(-0.15, 0.58, 0), Vector3(0.06, 0.22, 0.06), Color("#7dff6e"))
	_box("AntenaDer", Vector3(0.15, 0.58, 0), Vector3(0.06, 0.22, 0.06), Color("#7dff6e"))
	_box("PuntaIzq", Vector3(-0.15, 0.72, 0), Vector3(0.11, 0.11, 0.11), Color("#ff70ef"))
	_box("PuntaDer", Vector3(0.15, 0.72, 0), Vector3(0.11, 0.11, 0.11), Color("#ff70ef"))

func _build_crystal() -> void:
	_box("CristalCentro", Vector3(0, 0.10, 0), Vector3(0.36, 0.70, 0.36), Color("#55f7ff"))
	_box("CristalPunta", Vector3(0, 0.52, 0), Vector3(0.22, 0.22, 0.22), Color("#b6ffff"))
	_box("CristalBase", Vector3(0, -0.25, 0), Vector3(0.50, 0.16, 0.50), Color("#2684ff"))
	_box("Brillo", Vector3(0.14, 0.18, 0.19), Vector3(0.06, 0.38, 0.04), Color("#ffffff"))

func _build_energy_core() -> void:
	_box("Capsula", Vector3(0, 0.04, 0), Vector3(0.45, 0.70, 0.45), Color("#7a39ff"))
	_box("Nucleo", Vector3(0, 0.05, 0.24), Vector3(0.28, 0.36, 0.06), Color("#7dff6e"))
	_box("TapaAlta", Vector3(0, 0.47, 0), Vector3(0.58, 0.12, 0.58), Color("#d8d0ff"))
	_box("TapaBaja", Vector3(0, -0.39, 0), Vector3(0.58, 0.12, 0.58), Color("#d8d0ff"))
	_box("CableA", Vector3(-0.32, 0.03, 0), Vector3(0.08, 0.50, 0.08), Color("#202020"))
	_box("CableB", Vector3(0.32, 0.03, 0), Vector3(0.08, 0.50, 0.08), Color("#202020"))
