extends Node3D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const NPC_SCENE := preload("res://scenes/NPC.tscn")
const GLUPIX_MODEL := preload("res://models/glupix_player.glb")
const COW_MODEL := preload("res://models/cow_npc.glb")
const CHICKEN_MODEL := preload("res://models/chicken_voxel.glb")
const CHICKEN_HERD_SCRIPT := preload("res://scripts/chicken_herd.gd")
const COLLECTIBLE_SCENE := preload("res://scenes/Collectible.tscn")

const PLAYER_START_Z: float = 24.0
const PLAYER_MAX_BACK_Z: float = PLAYER_START_Z
const FRONT_FENCE_Z: float = PLAYER_START_Z + 1.55
const SCORE_PER_UNIT: float = 50.0
const API_EVENT_INTERVAL: float = 30.0
const API_EVENT_DURATION: float = 8.0
const MAX_ACTIVE_ARTIFACTS: int = 1
const COLLECTIBLE_SCORE_STEP: int = 3000
const GAME_OVER_TIPS: Array[String] = [
	"Espera a que pasen las vacas antes de saltar.",
	"Los pollos avisan antes de cruzar: escucha la alerta.",
	"Avanza con Espacio solo cuando Glupix mire al lado correcto.",
	"Los artefactos son raros: aparecen cada 3000 puntos.",
	"Cada 30 segundos puede ocurrir un evento espacial.",
	"Usa las zonas verdes como descanso antes de cruzar."
]

var player: CharacterBody3D
var attempts: int = 0
var score: int = 0
var collectible_score: int = 0
var artifacts_collected: int = 0
var elapsed_time: float = 0.0
var game_won: bool = false

# Modo infinito/procedural
var endless_mode: bool = true
var deepest_generated_z: float = -29.0
var next_checkpoint_z: float = -24.0
var chunk_index: int = 1
var endless_checkpoint: Area3D
var best_distance: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var blocked_obstacles: Array[Dictionary] = []

var game_over_active: bool = false

var pause_menu: Control
var pause_background: ColorRect
var pause_card: PanelContainer
var pause_title_label: Label
var pause_subtitle_label: Label
var pause_info_label: Label
var pause_hint_label: Label
var resume_button: Button
var restart_button: Button
var config_button: Button
var controls_button: Button
var exit_button: Button

var main_menu_view: VBoxContainer
var config_view: VBoxContainer
var controls_view: VBoxContainer

var hud_panel: PanelContainer
var hud_goal_panel: PanelContainer
var hud_time_label: Label
var hud_score_label: Label
var hud_artifacts_label: Label
var hud_highscore_label: Label
var hud_api_label: Label
var hud_goal_label: Label
var scores_button: Button
var scores_panel: PanelContainer
var scores_label: Label
var scores_close_button: Button
var catch_panel: PanelContainer
var catch_label: Label
var catch_message_token: int = 0

var config_panel: VBoxContainer
var api_speed_timer: float = 0.0
var api_speed_multiplier: float = 1.0
var next_artifact_score_marker: int = COLLECTIBLE_SCORE_STEP
var next_api_event_time: float = API_EVENT_INTERVAL
var collectible_type_bag: Array = []
var last_collectible_type: String = ""
var game_over_tip_box: HBoxContainer
var game_over_icon_label: Label
var game_over_tip_label: Label
var game_over_tip_token: int = 0
var game_over_tip_index: int = 0
var music_slider: HSlider
var screen_option: OptionButton
var scale_slider: HSlider

@onready var camera: Camera3D = $Camera3D
@onready var message_label: Label = $CanvasLayer/GameMessage
@onready var attempts_label: Label = $CanvasLayer/AttemptsLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	MusicManager.play_game()
	artifacts_collected = GameSettings.artifacts_collected
	collectible_score = GameSettings.artifact_score
	next_api_event_time = API_EVENT_INTERVAL
	next_artifact_score_marker = int(floor(float(max(0, collectible_score)) / float(COLLECTIBLE_SCORE_STEP))) * COLLECTIBLE_SCORE_STEP + COLLECTIBLE_SCORE_STEP
	HighscoreManager.load_highscore()
	if not APIManager.api_data_received.is_connected(_on_api_data_received):
		APIManager.api_data_received.connect(_on_api_data_received)
	if not GameSettings.settings_changed.is_connected(_on_settings_changed):
		GameSettings.settings_changed.connect(_on_settings_changed)

	add_to_group("game_manager")
	_ensure_pause_input_map()
	_setup_world_environment()
	_create_level_geometry()
	_spawn_player()
	_spawn_npcs()
	_spawn_decorations()
	_spawn_collectibles_initial()
	_create_goal_area()
	_style_hud()
	_create_pause_menu()
	_apply_game_fonts()
	_apply_ui_scale()
	message_label.text = ""
	message_label.visible = false
	_refresh_hud_numbers()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if game_won:
		return

	elapsed_time += delta
	_update_event_countdown(delta)
	if api_speed_timer > 0.0:
		api_speed_timer -= delta
		if api_speed_timer <= 0.0:
			_apply_api_speed_modifier(1.0)
	_update_score_from_player()
	_maybe_spawn_collectible_by_score()
	if endless_mode and not game_over_active and player != null and player.global_position.z <= next_checkpoint_z + 1.0:
		_extend_endless_world()
	_refresh_hud_numbers()

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause_game"):
		if game_over_active:
			return
		_toggle_pause_menu()

func _ensure_pause_input_map() -> void:
	if not InputMap.has_action("pause_game"):
		InputMap.add_action("pause_game")

	var esc_event := InputEventKey.new()
	esc_event.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event("pause_game", esc_event)

	var p_event := InputEventKey.new()
	p_event.physical_keycode = KEY_P
	InputMap.action_add_event("pause_game", p_event)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player_Glupix"
	player.global_position = Vector3(0, 0, PLAYER_START_Z)
	player.max_back_z = PLAYER_MAX_BACK_Z
	add_child(player)

	var model = GLUPIX_MODEL.instantiate()
	model.name = "Modelo_Glupix"
	model.scale = Vector3(0.42, 0.42, 0.42)
	model.position = Vector3(0, 0.45, 0)
	model.rotation_degrees = Vector3(-90, 0, 0)
	player.get_node("ModelRoot").add_child(model)

	camera.call("set_target", player)

func _spawn_npcs() -> void:
	# Primer tramo hecho a mano: 2, 3 y 4 carriles.
	_spawn_cow("Vaca_2Carriles_1", Vector3(-8, 0, 18), Vector3.RIGHT, 4.2, 16.0)
	_spawn_cow("Vaca_2Carriles_2", Vector3(8, 0, 16), Vector3.LEFT, 4.8, 16.0)

	_spawn_cow("Vaca_3Carriles_1", Vector3(-8, 0, 8), Vector3.RIGHT, 5.0, 16.0)
	_spawn_cow("Vaca_3Carriles_2", Vector3(8, 0, 6), Vector3.LEFT, 5.6, 16.0)
	_spawn_cow("Vaca_3Carriles_3", Vector3(-8, 0, 4), Vector3.RIGHT, 4.4, 16.0)

	_spawn_cow("Vaca_4Carriles_1", Vector3(8, 0, -4), Vector3.LEFT, 5.8, 16.0)
	_spawn_cow("Vaca_4Carriles_2", Vector3(-8, 0, -6), Vector3.RIGHT, 6.2, 16.0)
	_spawn_cow("Vaca_4Carriles_3", Vector3(8, 0, -8), Vector3.LEFT, 5.2, 16.0)
	_spawn_cow("Vaca_4Carriles_4", Vector3(-8, 0, -10), Vector3.RIGHT, 6.6, 16.0)

func _spawn_cow(npc_name: String, pos: Vector3, direction: Vector3, npc_speed: float, distance: float) -> void:
	var npc = NPC_SCENE.instantiate() as CharacterBody3D
	npc.name = npc_name
	npc.global_position = pos
	npc.speed = npc_speed * 1.18
	npc.travel_distance = distance
	npc.move_direction = direction
	add_child(npc)

	var model = COW_MODEL.instantiate()
	model.name = "Modelo_Vaca"
	model.scale = Vector3(0.45, 0.45, 0.45)
	model.position = Vector3(0, 0.45, 0)
	model.rotation_degrees = Vector3(-90, 0, 0)
	npc.get_node("ModelRoot").add_child(model)

func _spawn_chicken_herd(node_name: String, z_pos: float, direction: Vector3, herd_speed: float, count: int) -> void:
	var herd = CHICKEN_HERD_SCRIPT.new()
	herd.name = node_name
	herd.global_position = Vector3(0, 0, z_pos)
	herd.direction = 1 if direction.x >= 0.0 else -1
	herd.speed = herd_speed
	herd.herd_count = count
	herd.cooldown_min = 2.2
	herd.cooldown_max = 4.2
	add_child(herd)

func _spawn_decorations() -> void:
	# El pollo ya no está como decoración al inicio.
	# Ahora es una manada rápida estilo tren de Crossy Road.
	_spawn_chicken_herd("Manada_pollos_inicio", 11.8, Vector3.RIGHT, 24.0, 8)

func _spawn_collectibles_initial() -> void:
	# Solo aparece un artefacto inicial para que se sienta especial,
	# no como una moneda común repetida.
	_spawn_collectible("mini_ufo", Vector3(-3.0, 0.85, 18.0), 100)

func _maybe_spawn_collectible_by_score() -> void:
	if player == null:
		return

	if score < next_artifact_score_marker:
		return

	# Máximo un artefacto activo a la vez: aparecen menos y se sienten únicos.
	if _count_active_collectibles() >= MAX_ACTIVE_ARTIFACTS:
		return

	var spawn_z: float = player.global_position.z - 10.0
	var possible_x: Array[float] = [-6.0, -4.0, -2.0, 2.0, 4.0, 6.0]
	var candidate := Vector3(0.0, 0.85, spawn_z)

	# Evita aparecer encima de obstáculos.
	for i in range(10):
		var chosen_x: float = possible_x[rng.randi_range(0, possible_x.size() - 1)]
		candidate = Vector3(chosen_x, 0.85, spawn_z - float(i % 4) * 2.0)
		if can_player_move_to(Vector3(candidate.x, player.global_position.y, candidate.z)):
			break

	_spawn_random_collectible(candidate)
	next_artifact_score_marker += COLLECTIBLE_SCORE_STEP


func _count_active_collectibles() -> int:
	var count: int = 0
	for child in get_children():
		if String(child.name).begins_with("Coleccionable_"):
			count += 1
	return count


func _spawn_random_collectible(pos: Vector3) -> void:
	var type_id: String = _get_next_unique_collectible_type()
	_spawn_collectible(type_id, pos, _get_collectible_points(type_id))


func _get_next_unique_collectible_type() -> String:
	if collectible_type_bag.is_empty():
		collectible_type_bag = ["mini_ufo", "earth", "mini_alien", "crystal", "energy_core"]
		collectible_type_bag.shuffle()

	var type_id: String = str(collectible_type_bag.pop_back())
	if type_id == last_collectible_type and not collectible_type_bag.is_empty():
		collectible_type_bag.push_front(type_id)
		type_id = str(collectible_type_bag.pop_back())

	last_collectible_type = type_id
	return type_id


func _get_collectible_points(type_id: String) -> int:
	match type_id:
		"mini_ufo":
			return 100
		"earth":
			return 250
		"mini_alien":
			return 150
		"crystal":
			return 200
		"energy_core":
			return 300
		_:
			return 100


func _spawn_collectible(type_id: String, pos: Vector3, points: int) -> void:
	var collectible = COLLECTIBLE_SCENE.instantiate()
	collectible.name = "Coleccionable_%s" % type_id
	collectible.global_position = pos
	collectible.type_id = type_id
	collectible.points = points
	add_child(collectible)

func on_collectible_picked(type_id: String, points: int, pos: Vector3) -> void:
	var final_points: int = points
	artifacts_collected += 1
	collectible_score += final_points
	GameSettings.add_artifacts(1, final_points)
	SfxManager.play_collect()
	_update_score_from_player()
	_show_collectible_message(type_id, final_points)

func _show_collectible_message(type_id: String, points: int) -> void:
	var nice_name: String = _get_collectible_name(type_id)
	message_label.visible = true
	message_label.text = "+%d  %s" % [points, nice_name]
	await get_tree().create_timer(1.4).timeout
	if not game_over_active:
		message_label.visible = false

func _get_collectible_name(type_id: String) -> String:
	match type_id:
		"mini_ufo":
			return "Mini OVNI"
		"earth":
			return "Planeta Tierra"
		"mini_alien":
			return "Mini alien"
		"crystal":
			return "Cristal espacial"
		"energy_core":
			return "Núcleo de energía"
		_:
			return "Artefacto alienígena"

func _update_event_countdown(delta: float) -> void:
	if game_over_active:
		return

	# Mientras un evento está activo no se pisa el texto del HUD.
	if api_speed_timer > 0.0:
		return

	next_api_event_time -= delta
	if next_api_event_time <= 0.0:
		next_api_event_time = API_EVENT_INTERVAL
		if hud_api_label:
			hud_api_label.text = "Evento: señal..."
		APIManager.fetch_advice()
	elif hud_api_label:
		hud_api_label.text = "Evento: %02ds" % int(ceil(next_api_event_time))


func _on_api_data_received(advice: String, even_length: bool) -> void:
	# La API externa decide un evento de juego, pero en el HUD se muestra como evento del mundo.
	var event_index: int = abs(hash(advice)) % 5
	_activate_space_event(event_index)


func _activate_space_event(event_index: int) -> void:
	api_speed_timer = API_EVENT_DURATION
	next_api_event_time = API_EVENT_INTERVAL
	var title: String = ""
	var effect_text: String = ""

	match event_index:
		0:
			title = "Campo grav."
			effect_text = "vacas lentas"
			_apply_api_speed_modifier(0.82)
		1:
			title = "Tormenta"
			effect_text = "vacas rápidas"
			_apply_api_speed_modifier(1.18)
		2:
			title = "Pulso +300"
			effect_text = "+300 score"
			collectible_score += 300
			GameSettings.add_artifacts(0, 300)
			_apply_api_speed_modifier(1.0)
			_update_score_from_player()
		3:
			title = "Radar"
			effect_text = "artefacto extra"
			_apply_api_speed_modifier(1.0)
			if player != null and _count_active_collectibles() < MAX_ACTIVE_ARTIFACTS:
				_spawn_random_collectible(Vector3(0.0, 0.85, player.global_position.z - 9.0))
		_:
			title = "Estela +150"
			effect_text = "vacas lentas"
			collectible_score += 150
			GameSettings.add_artifacts(0, 150)
			_apply_api_speed_modifier(0.90)
			_update_score_from_player()

	if hud_api_label:
		hud_api_label.text = "Evento: " + title

func _apply_api_speed_modifier(multiplier: float) -> void:
	api_speed_multiplier = multiplier
	for node in get_children():
		if node.has_method("set_api_speed_multiplier"):
			node.call("set_api_speed_multiplier", multiplier)

func _create_level_geometry() -> void:
	# Base general del terreno y franjas laterales más amplias.
	_create_box("Suelo_base", Vector3(0, -0.18, 0), Vector3(24.0, 0.36, 64.0), Color("#4f8f5d"), true)
	_create_box("Suelo_lateral_izq", Vector3(-12.8, -0.20, 0), Vector3(4.6, 0.30, 64.0), Color("#5c9a64"), false)
	_create_box("Suelo_lateral_der", Vector3(12.8, -0.20, 0), Vector3(4.6, 0.30, 64.0), Color("#5c9a64"), false)

	# Zonas verdes mejor integradas.
	_create_grass_zone("Zona_inicio", Vector3(0, 0.05, 24), Vector3(18, 0.10, 7), Color("#63bf63"))
	_create_grass_zone("Zona_segura_antes_2_carriles", Vector3(0, 0.06, 21), Vector3(18, 0.10, 2), Color("#6acb67"))
	_create_grass_zone("Zona_descanso_tras_2_carriles", Vector3(0, 0.10, 13), Vector3(18, 0.10, 3.2), Color("#63bf63"))
	_create_chicken_lane("Carril_pollos_inicio", Vector3(0, 0.155, 11.8), Vector3(18, 0.10, 1.65))
	_create_grass_zone("Zona_segura_antes_3_carriles", Vector3(0, 0.11, 10.5), Vector3(18, 0.10, 2), Color("#6acb67"))
	_create_grass_zone("Zona_descanso_tras_3_carriles", Vector3(0, 0.15, 1), Vector3(18, 0.10, 3.2), Color("#63bf63"))
	_create_grass_zone("Zona_segura_antes_4_carriles", Vector3(0, 0.16, -2), Vector3(18, 0.10, 2.2), Color("#6acb67"))
	_create_grass_zone("Zona_descanso_tras_4_carriles", Vector3(0, 0.21, -14), Vector3(18, 0.10, 5.0), Color("#63bf63"))
	_create_grass_zone("Zona_final", Vector3(0, 0.22, -20), Vector3(18, 0.10, 6), Color("#6ec764"))
	_create_grass_zone("Zona_meta", Vector3(0, 0.23, -25), Vector3(18, 0.10, 4), Color("#78d46e"))

	# Caminos de tierra estilo corral, no carretera.
	_create_dirt_lane("Carril_2A", Vector3(0, 0.08, 18), Vector3(18, 0.10, 1.8), Color("#97714a"))
	_create_dirt_lane("Carril_2B", Vector3(0, 0.09, 16), Vector3(18, 0.10, 1.8), Color("#8d6943"))
	_create_dirt_lane("Carril_3A", Vector3(0, 0.12, 8), Vector3(18, 0.10, 1.8), Color("#97714a"))
	_create_dirt_lane("Carril_3B", Vector3(0, 0.13, 6), Vector3(18, 0.10, 1.8), Color("#8d6943"))
	_create_dirt_lane("Carril_3C", Vector3(0, 0.14, 4), Vector3(18, 0.10, 1.8), Color("#9d7750"))
	_create_dirt_lane("Carril_4A", Vector3(0, 0.17, -4), Vector3(18, 0.10, 1.8), Color("#8d6943"))
	_create_dirt_lane("Carril_4B", Vector3(0, 0.18, -6), Vector3(18, 0.10, 1.8), Color("#9b7550"))
	_create_dirt_lane("Carril_4C", Vector3(0, 0.19, -8), Vector3(18, 0.10, 1.8), Color("#88633e"))
	_create_dirt_lane("Carril_4D", Vector3(0, 0.20, -10), Vector3(18, 0.10, 1.8), Color("#97714a"))

	# Obstáculos y detalles extra.
	_create_farm_obstacles()
	_create_nature_details()
	_create_mud_puddles()
	_create_farm_landmarks()
	_create_farm_fences()


func _create_grass_zone(zone_name: String, pos: Vector3, size: Vector3, base_color: Color) -> void:
	_create_box(zone_name, pos, size, base_color, false)

	var detail_root := Node3D.new()
	detail_root.name = zone_name + "_Detalles"
	add_child(detail_root)

	var top_y: float = pos.y + size.y * 0.5
	var bright: Color = base_color.lerp(Color("#a2eb74"), 0.25)
	var dark: Color = base_color.lerp(Color("#2f7639"), 0.28)

	# Parcheado de césped en capas para romper lo plano.
	for ix in range(5):
		for iz in range(3):
			var px: float = pos.x - size.x * 0.36 + float(ix) * (size.x * 0.18)
			var pz: float = pos.z - size.z * 0.28 + float(iz) * (size.z * 0.28)
			var patch_h: float = 0.03 + 0.01 * float((ix + iz) % 3)
			var patch_size_x: float = 1.7 + 0.28 * float((ix + iz) % 2)
			var patch_size_z: float = max(0.42, size.z * 0.18)
			var patch_color: Color = base_color.lerp(bright, 0.14 * float(1 + ((ix + iz) % 2)))
			_create_local_box(detail_root, "Parche_%d_%d" % [ix, iz], Vector3(px, top_y + patch_h * 0.5 + 0.01, pz), Vector3(patch_size_x, patch_h, patch_size_z), patch_color, false)

	# Matas de pasto y florecitas voxel.
	var clumps: Array[Vector3] = [
		Vector3(pos.x - size.x * 0.38, top_y + 0.08, pos.z - size.z * 0.24),
		Vector3(pos.x - size.x * 0.16, top_y + 0.08, pos.z + size.z * 0.10),
		Vector3(pos.x + size.x * 0.02, top_y + 0.08, pos.z - size.z * 0.02),
		Vector3(pos.x + size.x * 0.20, top_y + 0.08, pos.z + size.z * 0.18),
		Vector3(pos.x + size.x * 0.34, top_y + 0.08, pos.z - size.z * 0.16)
	]
	for i in range(clumps.size()):
		_create_grass_clump(detail_root, "Mata_%d" % i, clumps[i], dark, bright)
		if i % 2 == 0:
			_create_local_box(detail_root, "Flor_%d" % i, clumps[i] + Vector3(0.0, 0.14, 0.0), Vector3(0.06, 0.06, 0.06), Color("#fff5c4"), false)

	# Bordes oscuros para relieve.
	_create_local_box(detail_root, "BordeNorte", Vector3(pos.x, top_y + 0.015, pos.z - size.z * 0.5 + 0.10), Vector3(size.x, 0.03, 0.18), dark, false)
	_create_local_box(detail_root, "BordeSur", Vector3(pos.x, top_y + 0.015, pos.z + size.z * 0.5 - 0.10), Vector3(size.x, 0.03, 0.18), dark, false)
	_create_local_box(detail_root, "BordeOeste", Vector3(pos.x - size.x * 0.5 + 0.10, top_y + 0.014, pos.z), Vector3(0.18, 0.03, size.z), dark.darkened(0.08), false)
	_create_local_box(detail_root, "BordeEste", Vector3(pos.x + size.x * 0.5 - 0.10, top_y + 0.014, pos.z), Vector3(0.18, 0.03, size.z), dark.darkened(0.08), false)


func _create_grass_clump(parent: Node3D, clump_name: String, pos: Vector3, dark_color: Color, bright_color: Color) -> void:
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(-0.18, 0.02, 0.12),
		Vector3(0.16, 0.01, -0.10),
		Vector3(-0.05, 0.03, -0.16),
		Vector3(0.10, 0.02, 0.18)
	]
	for i in range(offsets.size()):
		var blade_h: float = 0.12 + 0.04 * float(i % 3)
		var blade_color: Color = dark_color if i % 2 == 0 else bright_color
		_create_local_box(parent, clump_name + "_Hoja_%d" % i, pos + offsets[i], Vector3(0.09, blade_h, 0.09), blade_color, false)


func _create_chicken_lane(lane_name: String, pos: Vector3, size: Vector3) -> void:
	# Carril tipo corral: tierra, paja, huellas y vallas bajas. Ya no parece carretera.
	_create_box(lane_name, pos, size, Color("#8f6a45"), false)

	var detail_root := Node3D.new()
	detail_root.name = lane_name + "_Detalles"
	add_child(detail_root)

	var top_y: float = pos.y + size.y * 0.5
	var dirt_dark: Color = Color("#6c4a2f")
	var dirt_light: Color = Color("#ab8158")
	var straw: Color = Color("#e4c65b")
	var fence_wood: Color = Color("#7f5536")
	var grass_edge: Color = Color("#62b95f")

	# Huellas largas de paso rápido.
	_create_local_box(detail_root, "HuellaIzq", Vector3(pos.x - 3.0, top_y + 0.015, pos.z), Vector3(7.2, 0.03, 0.40), dirt_dark, false)
	_create_local_box(detail_root, "HuellaDer", Vector3(pos.x + 3.0, top_y + 0.015, pos.z), Vector3(7.2, 0.03, 0.40), dirt_dark, false)
	_create_local_box(detail_root, "TierraCentro", Vector3(pos.x, top_y + 0.012, pos.z), Vector3(4.2, 0.025, 0.34), dirt_light, false)

	# Bordes de pasto.
	_create_local_box(detail_root, "BordePastoN", Vector3(pos.x, top_y + 0.015, pos.z - size.z * 0.5 + 0.12), Vector3(size.x, 0.03, 0.16), grass_edge, false)
	_create_local_box(detail_root, "BordePastoS", Vector3(pos.x, top_y + 0.015, pos.z + size.z * 0.5 - 0.12), Vector3(size.x, 0.03, 0.16), grass_edge, false)

	# Montoncitos de paja.
	for i in range(8):
		var px: float = pos.x - 7.0 + float(i) * 2.0
		var pz: float = pos.z + (-0.24 if i % 2 == 0 else 0.22)
		_create_local_box(detail_root, "PajaA_%d" % i, Vector3(px, top_y + 0.04, pz), Vector3(0.34, 0.05, 0.08), straw, false)
		_create_local_box(detail_root, "PajaB_%d" % i, Vector3(px + 0.10, top_y + 0.05, pz + 0.06), Vector3(0.18, 0.04, 0.08), straw.darkened(0.08), false)

	# Huellitas pequeñas de pollos.
	for i in range(12):
		var hx: float = pos.x - 7.6 + float(i) * 1.35
		_create_local_box(detail_root, "HuellaPolloA_%d" % i, Vector3(hx, top_y + 0.02, pos.z - 0.08), Vector3(0.06, 0.02, 0.14), dirt_dark.darkened(0.10), false)
		_create_local_box(detail_root, "HuellaPolloB_%d" % i, Vector3(hx + 0.10, top_y + 0.02, pos.z + 0.10), Vector3(0.06, 0.02, 0.14), dirt_dark.darkened(0.10), false)

	# Vallas bajas a los lados del carril, estilo corral.
	for side in [-1, 1]:
		var rail_z: float = pos.z + float(side) * (size.z * 0.5 + 0.12)
		_create_local_box(detail_root, "Rail_%d_A" % side, Vector3(pos.x, 0.46, rail_z), Vector3(size.x - 0.8, 0.10, 0.06), fence_wood, false)
		_create_local_box(detail_root, "Rail_%d_B" % side, Vector3(pos.x, 0.78, rail_z), Vector3(size.x - 0.8, 0.10, 0.06), fence_wood.lightened(0.08), false)
		for p in range(9):
			var post_x: float = pos.x - 7.8 + float(p) * 1.95
			_create_local_box(detail_root, "Poste_%d_%d" % [side, p], Vector3(post_x, 0.62, rail_z), Vector3(0.10, 0.82, 0.10), fence_wood.darkened(0.12), false)

	# Señales pequeñas de advertencia granjera, sin parecer carretera.
	_create_local_box(detail_root, "PosteAlertaIzq", Vector3(-8.2, 0.82, pos.z), Vector3(0.12, 1.10, 0.12), Color("#5a3a23"), false)
	_create_local_box(detail_root, "SenalAlertaIzq", Vector3(-8.2, 1.28, pos.z), Vector3(0.52, 0.34, 0.10), straw, false)
	_create_local_box(detail_root, "MarcaAlertaIzq", Vector3(-8.2, 1.28, pos.z + 0.06), Vector3(0.10, 0.20, 0.05), Color("#6b2c1e"), false)
	_create_local_box(detail_root, "PosteAlertaDer", Vector3(8.2, 0.82, pos.z), Vector3(0.12, 1.10, 0.12), Color("#5a3a23"), false)
	_create_local_box(detail_root, "SenalAlertaDer", Vector3(8.2, 1.28, pos.z), Vector3(0.52, 0.34, 0.10), straw, false)
	_create_local_box(detail_root, "MarcaAlertaDer", Vector3(8.2, 1.28, pos.z + 0.06), Vector3(0.10, 0.20, 0.05), Color("#6b2c1e"), false)


func _create_dirt_lane(lane_name: String, pos: Vector3, size: Vector3, base_color: Color) -> void:
	_create_box(lane_name, pos, size, base_color, false)

	var detail_root := Node3D.new()
	detail_root.name = lane_name + "_Detalles"
	add_child(detail_root)

	var top_y: float = pos.y + size.y * 0.5
	var dark_dirt: Color = base_color.lerp(Color("#53391e"), 0.35)
	var light_dirt: Color = base_color.lerp(Color("#bb9568"), 0.28)
	var grass_edge: Color = Color("#63b85f")
	var straw: Color = Color("#d9be63")

	# Surcos anchos tipo camino de corral.
	_create_local_box(detail_root, "HuellaIzq", Vector3(pos.x - 3.2, top_y + 0.015, pos.z), Vector3(7.4, 0.03, 0.40), dark_dirt, false)
	_create_local_box(detail_root, "HuellaDer", Vector3(pos.x + 3.2, top_y + 0.015, pos.z), Vector3(7.4, 0.03, 0.40), dark_dirt, false)
	_create_local_box(detail_root, "FranjaCentro", Vector3(pos.x, top_y + 0.012, pos.z), Vector3(4.2, 0.025, 0.30), light_dirt, false)

	# Bordes verdes del carril.
	_create_local_box(detail_root, "CespedBordeN", Vector3(pos.x, top_y + 0.016, pos.z - size.z * 0.5 + 0.12), Vector3(size.x, 0.03, 0.16), grass_edge, false)
	_create_local_box(detail_root, "CespedBordeS", Vector3(pos.x, top_y + 0.016, pos.z + size.z * 0.5 - 0.12), Vector3(size.x, 0.03, 0.16), grass_edge, false)

	# Piedras pequeñas repartidas en el carril.
	for i in range(6):
		var rx: float = pos.x - size.x * 0.35 + float(i) * (size.x * 0.14)
		var rz: float = pos.z + (0.18 if i % 2 == 0 else -0.18)
		var pebble_color: Color = dark_dirt.lerp(Color("#8a7458"), 0.40 + 0.08 * float(i % 3))
		_create_local_box(detail_root, "Piedra_%d" % i, Vector3(rx, top_y + 0.045, rz), Vector3(0.18, 0.06, 0.12), pebble_color, false)

	# Paja y pequeñas hierbas secas para mayor detalle.
	for i in range(7):
		var sx: float = pos.x - 6.8 + float(i) * 2.2
		_create_local_box(detail_root, "Paja_%d" % i, Vector3(sx, top_y + 0.04, pos.z + (-0.30 if i % 2 == 0 else 0.30)), Vector3(0.26, 0.04, 0.08), straw, false)
		_create_local_box(detail_root, "MataSeca_%d" % i, Vector3(sx + 0.14, top_y + 0.07, pos.z + (0.28 if i % 2 == 0 else -0.26)), Vector3(0.08, 0.12, 0.08), grass_edge.darkened(0.10), false)


func _create_farm_obstacles() -> void:
	_create_hay_stack("Paca_heno_inicio", Vector3(-5.9, 0.0, 21.0))
	_create_crate_stack("Cajones_inicio", Vector3(5.4, 0.0, 22.0))
	_create_hay_stack("Paca_heno_descanso_2", Vector3(5.5, 0.0, 13.0))
	_create_crate_stack("Cajones_granja", Vector3(-5.8, 0.0, 10.4))
	_create_feed_sacks("Costales_inicio", Vector3(5.0, 0.0, 9.8))
	_create_water_trough("Bebedero_granja", Vector3(-5.7, 0.0, 0.8))
	_create_milk_cans("Lecheras", Vector3(5.8, 0.0, 1.0))
	_create_crate_stack("Cajones_centro", Vector3(5.4, 0.0, -0.6))
	_create_feed_sacks("Costales_pienso", Vector3(-4.8, 0.0, -14.2))
	_create_wheelbarrow("Carretilla", Vector3(4.8, 0.0, -18.0))
	_create_water_trough("Bebedero_final", Vector3(-5.5, 0.0, -18.8))
	_create_hay_stack("Paca_heno_final", Vector3(5.4, 0.0, -20.0))
	_create_milk_cans("Lecheras_final", Vector3(-5.1, 0.0, -23.0))


func _register_obstacle_cell(pos: Vector3, size: Vector3) -> void:
	# El jugador se mueve por saltos de cuadrícula, así que además de la colisión física
	# registramos una zona bloqueada para evitar que atraviese props estáticos.
	blocked_obstacles.append({
		"pos": pos,
		"rx": max(0.75, size.x * 0.55),
		"rz": max(0.75, size.z * 0.55)
	})


func can_player_move_to(target_pos: Vector3) -> bool:
	# Límite del corral.
	if target_pos.x < -8.0 or target_pos.x > 8.0:
		return false
	if target_pos.z > PLAYER_MAX_BACK_Z:
		return false

	for obstacle in blocked_obstacles:
		var obstacle_pos: Vector3 = obstacle["pos"]
		var rx: float = obstacle["rx"]
		var rz: float = obstacle["rz"]
		if abs(target_pos.x - obstacle_pos.x) <= rx and abs(target_pos.z - obstacle_pos.z) <= rz:
			return false

	return true


func _make_obstacle_root(node_name: String, pos: Vector3, collision_size: Vector3) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = node_name
	root.global_position = pos

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = collision_size + Vector3(0.18, 0.15, 0.18)
	shape.shape = box
	shape.position = Vector3(0, collision_size.y * 0.5, 0)
	root.add_child(shape)
	add_child(root)

	_register_obstacle_cell(pos, collision_size + Vector3(0.35, 0.0, 0.35))
	return root


func _create_hay_stack(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(2.0, 1.4, 1.2))
	var hay_main: Color = Color("#d2a43c")
	var hay_light: Color = Color("#e5bf5c")
	var strap: Color = Color("#8d6931")

	_create_local_box(root, "BalaA", Vector3(-0.45, 0.45, 0.0), Vector3(1.0, 0.9, 0.9), hay_main, false)
	_create_local_box(root, "BalaB", Vector3(0.55, 0.45, 0.0), Vector3(1.0, 0.9, 0.9), hay_light, false)
	_create_local_box(root, "BalaSup", Vector3(0.05, 1.05, 0.0), Vector3(0.9, 0.7, 0.9), hay_main, false)
	for x in [-0.45, 0.55, 0.05]:
		_create_local_box(root, "Cinta_%s" % str(x), Vector3(x, 0.45 if x != 0.05 else 1.05, 0.0), Vector3(0.08, 0.92 if x != 0.05 else 0.72, 0.96), strap, false)


func _create_crate_stack(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(1.8, 1.2, 1.2))
	var wood: Color = Color("#8d5b34")
	var wood_dark: Color = Color("#5c381f")

	_create_crate(root, "CajaBase", Vector3(-0.40, 0.35, 0.0), Vector3(0.9, 0.7, 0.9), wood, wood_dark)
	_create_crate(root, "CajaBase2", Vector3(0.50, 0.35, 0.0), Vector3(0.9, 0.7, 0.9), wood, wood_dark)
	_create_crate(root, "CajaSup", Vector3(0.05, 0.95, 0.0), Vector3(0.8, 0.6, 0.8), wood, wood_dark)


func _create_crate(parent: Node3D, crate_name: String, pos: Vector3, size: Vector3, wood: Color, wood_dark: Color) -> void:
	_create_local_box(parent, crate_name + "_Cuerpo", pos, size, wood, false)
	_create_local_box(parent, crate_name + "_Tabla1", pos + Vector3(0.0, 0.18, 0.0), Vector3(size.x * 0.94, 0.08, size.z * 1.02), wood_dark, false)
	_create_local_box(parent, crate_name + "_Tabla2", pos + Vector3(0.0, -0.18, 0.0), Vector3(size.x * 0.94, 0.08, size.z * 1.02), wood_dark, false)
	_create_local_box(parent, crate_name + "_Lateral1", pos + Vector3(-size.x * 0.45, 0.0, 0.0), Vector3(0.08, size.y * 0.96, size.z * 1.02), wood_dark, false)
	_create_local_box(parent, crate_name + "_Lateral2", pos + Vector3(size.x * 0.45, 0.0, 0.0), Vector3(0.08, size.y * 0.96, size.z * 1.02), wood_dark, false)


func _create_water_trough(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(1.8, 0.8, 1.0))
	var wood: Color = Color("#6a4325")
	var wood_dark: Color = Color("#442918")
	var water: Color = Color("#5dc9f5")

	_create_local_box(root, "Base", Vector3(0.0, 0.30, 0.0), Vector3(1.6, 0.50, 0.8), wood, false)
	_create_local_box(root, "Hueco", Vector3(0.0, 0.42, 0.0), Vector3(1.30, 0.26, 0.55), wood_dark, false)
	_create_local_box(root, "Agua", Vector3(0.0, 0.50, 0.0), Vector3(1.18, 0.04, 0.48), water, false)
	_create_local_box(root, "PataA", Vector3(-0.55, 0.12, 0.0), Vector3(0.12, 0.24, 0.12), wood_dark, false)
	_create_local_box(root, "PataB", Vector3(0.55, 0.12, 0.0), Vector3(0.12, 0.24, 0.12), wood_dark, false)


func _create_milk_cans(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(1.0, 1.1, 0.8))
	var metal: Color = Color("#cfd6d8")
	var dark: Color = Color("#8b9498")

	for i in range(3):
		var lx: float = -0.28 + float(i) * 0.28
		var h: float = 0.72 + 0.05 * float(i % 2)
		_create_local_box(root, "Lata_%d" % i, Vector3(lx, h * 0.5, 0.0), Vector3(0.20, h, 0.20), metal, false)
		_create_local_box(root, "Tapa_%d" % i, Vector3(lx, h + 0.03, 0.0), Vector3(0.16, 0.05, 0.16), dark, false)
		_create_local_box(root, "Asa_%d" % i, Vector3(lx, h * 0.82, -0.12), Vector3(0.12, 0.12, 0.03), dark, false)


func _create_feed_sacks(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(1.8, 1.0, 1.0))
	var sack: Color = Color("#d9d0aa")
	var sack_dark: Color = Color("#b6ad8e")
	var label: Color = Color("#6eb764")

	_create_local_box(root, "CostalA", Vector3(-0.42, 0.38, 0.0), Vector3(0.78, 0.76, 0.72), sack, false)
	_create_local_box(root, "CostalB", Vector3(0.42, 0.38, 0.0), Vector3(0.78, 0.76, 0.72), sack_dark, false)
	_create_local_box(root, "CostalSup", Vector3(0.0, 0.88, 0.0), Vector3(0.80, 0.50, 0.72), sack, false)
	_create_local_box(root, "Etiqueta", Vector3(0.0, 0.38, 0.37), Vector3(0.50, 0.30, 0.06), label, false)


func _create_wheelbarrow(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(1.8, 1.0, 1.2))
	var metal: Color = Color("#65777d")
	var metal_dark: Color = Color("#415056")
	var wood: Color = Color("#8b613d")

	_create_local_box(root, "Tolva", Vector3(0.0, 0.52, 0.0), Vector3(1.0, 0.34, 0.72), metal, false)
	_create_local_box(root, "Rueda", Vector3(-0.58, 0.22, 0.0), Vector3(0.18, 0.40, 0.40), metal_dark, false)
	_create_local_box(root, "Eje", Vector3(-0.43, 0.22, 0.0), Vector3(0.16, 0.08, 0.08), metal_dark, false)
	_create_local_box(root, "PataA", Vector3(0.34, 0.18, -0.18), Vector3(0.08, 0.30, 0.08), wood, false)
	_create_local_box(root, "PataB", Vector3(0.34, 0.18, 0.18), Vector3(0.08, 0.30, 0.08), wood, false)
	_create_local_box(root, "ManijaA", Vector3(0.66, 0.36, -0.22), Vector3(0.60, 0.06, 0.06), wood, false)
	_create_local_box(root, "ManijaB", Vector3(0.66, 0.36, 0.22), Vector3(0.60, 0.06, 0.06), wood, false)



func _create_nature_details() -> void:
	_create_tree("Arbol_inicio_izq", Vector3(-7.3, 0.0, 24.5), 1.0)
	_create_tree("Arbol_inicio_der", Vector3(7.1, 0.0, 23.6), 0.92)
	_create_tree("Arbol_descanso_izq", Vector3(-7.1, 0.0, 12.8), 0.95)
	_create_tree("Arbol_descanso_der", Vector3(7.0, 0.0, 0.2), 1.05)
	_create_tree("Arbol_medio_izq", Vector3(-7.0, 0.0, -8.0), 0.92)
	_create_tree("Arbol_final_der", Vector3(7.2, 0.0, -19.2), 1.10)
	_create_tree("Arbol_meta_izq", Vector3(-7.4, 0.0, -24.8), 0.95)

	_create_bush("Arbusto_1", Vector3(6.4, 0.0, 22.0), 0.9)
	_create_bush("Arbusto_2", Vector3(-6.1, 0.0, 19.8), 1.1)
	_create_bush("Arbusto_3", Vector3(6.6, 0.0, 10.8), 0.95)
	_create_bush("Arbusto_4", Vector3(-6.5, 0.0, 2.0), 1.0)
	_create_bush("Arbusto_5", Vector3(6.2, 0.0, -12.8), 1.0)
	_create_bush("Arbusto_6", Vector3(-6.2, 0.0, -22.0), 0.95)
	_create_bush("Arbusto_7", Vector3(6.8, 0.0, -4.0), 1.0)
	_create_bush("Arbusto_8", Vector3(-6.8, 0.0, -16.0), 0.9)


func _create_tree(node_name: String, pos: Vector3, scale_value: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	add_child(root)

	var trunk: Color = Color("#7b5230")
	var trunk_dark: Color = Color("#59391f")
	var leaf: Color = Color("#4d9b46")
	var leaf_light: Color = Color("#6bbb58")

	var trunk_h: float = 1.8 * scale_value
	_create_local_box(root, "Tronco", Vector3(0.0, trunk_h * 0.5, 0.0), Vector3(0.42 * scale_value, trunk_h, 0.42 * scale_value), trunk, false)
	_create_local_box(root, "TroncoFrente", Vector3(0.0, trunk_h * 0.55, 0.18 * scale_value), Vector3(0.16 * scale_value, trunk_h * 0.85, 0.12 * scale_value), trunk_dark, false)

	var canopy_y: float = trunk_h + 0.65 * scale_value
	_create_local_box(root, "CopaBase", Vector3(0.0, canopy_y, 0.0), Vector3(2.2 * scale_value, 0.90 * scale_value, 2.2 * scale_value), leaf, false)
	_create_local_box(root, "CopaMedia", Vector3(0.0, canopy_y + 0.55 * scale_value, 0.0), Vector3(1.7 * scale_value, 0.80 * scale_value, 1.7 * scale_value), leaf_light, false)
	_create_local_box(root, "CopaAlta", Vector3(0.0, canopy_y + 0.95 * scale_value, 0.0), Vector3(1.1 * scale_value, 0.55 * scale_value, 1.1 * scale_value), leaf, false)
	_create_local_box(root, "RamaIzq", Vector3(-0.55 * scale_value, canopy_y - 0.05 * scale_value, 0.0), Vector3(0.80 * scale_value, 0.34 * scale_value, 0.80 * scale_value), leaf_light, false)
	_create_local_box(root, "RamaDer", Vector3(0.55 * scale_value, canopy_y - 0.05 * scale_value, 0.0), Vector3(0.80 * scale_value, 0.34 * scale_value, 0.80 * scale_value), leaf_light, false)


func _create_bush(node_name: String, pos: Vector3, scale_value: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	add_child(root)

	var bush_dark: Color = Color("#3f8739")
	var bush: Color = Color("#5cab4e")
	var bush_light: Color = Color("#76c764")

	_create_local_box(root, "Base", Vector3(0.0, 0.26 * scale_value, 0.0), Vector3(1.5 * scale_value, 0.52 * scale_value, 1.1 * scale_value), bush_dark, false)
	_create_local_box(root, "Centro", Vector3(0.0, 0.52 * scale_value, 0.0), Vector3(1.1 * scale_value, 0.48 * scale_value, 0.9 * scale_value), bush, false)
	_create_local_box(root, "LomoIzq", Vector3(-0.46 * scale_value, 0.54 * scale_value, 0.12 * scale_value), Vector3(0.72 * scale_value, 0.44 * scale_value, 0.72 * scale_value), bush_light, false)
	_create_local_box(root, "LomoDer", Vector3(0.46 * scale_value, 0.50 * scale_value, -0.10 * scale_value), Vector3(0.68 * scale_value, 0.40 * scale_value, 0.68 * scale_value), bush, false)


func _create_mud_puddles() -> void:
	_create_mud_puddle("Charco_1", Vector3(3.6, 0.08, 12.7), Vector3(1.4, 0.05, 0.9))
	_create_mud_puddle("Charco_2", Vector3(-3.8, 0.12, 0.6), Vector3(1.8, 0.05, 1.1))
	_create_mud_puddle("Charco_3", Vector3(3.9, 0.18, -12.9), Vector3(1.6, 0.05, 0.95))
	_create_mud_puddle("Charco_4", Vector3(-3.4, 0.22, -21.4), Vector3(1.5, 0.05, 1.0))


func _create_mud_puddle(node_name: String, pos: Vector3, size: Vector3) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	add_child(root)

	var mud_dark: Color = Color("#5e4129")
	var mud: Color = Color("#7c5837")
	var mud_light: Color = Color("#92694a")
	var water_highlight: Color = Color("#8db2a8")

	_create_local_box(root, "Base", Vector3(0.0, 0.0, 0.0), size, mud_dark, false)
	_create_local_box(root, "Centro", Vector3(0.0, 0.01, 0.0), Vector3(size.x * 0.72, size.y * 0.8, size.z * 0.72), mud, false)
	_create_local_box(root, "Brillo", Vector3(-size.x * 0.10, 0.02, -size.z * 0.05), Vector3(size.x * 0.32, size.y * 0.35, size.z * 0.22), water_highlight, false)
	_create_local_box(root, "Borde1", Vector3(-size.x * 0.30, 0.01, size.z * 0.18), Vector3(size.x * 0.18, size.y * 0.45, size.z * 0.20), mud_light, false)
	_create_local_box(root, "Borde2", Vector3(size.x * 0.24, 0.01, -size.z * 0.20), Vector3(size.x * 0.22, size.y * 0.45, size.z * 0.18), mud_light, false)


func _create_farm_landmarks() -> void:
	_create_barn_prop("GraneroDecor", Vector3(6.6, 0.0, -25.0))
	_create_windmill("MolinoDecor", Vector3(-7.0, 0.0, -24.0))
	_create_tractor_prop("TractorDecor", Vector3(-6.3, 0.0, -17.2))
	_create_signpost("SenialInicio", Vector3(6.8, 0.0, 24.8), true)
	_create_signpost("SenialMeta", Vector3(6.8, 0.0, -24.2), false)


func _create_barn_prop(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(2.8, 2.4, 2.1))
	var red: Color = Color("#bd3e34")
	var red_dark: Color = Color("#8d2b22")
	var white: Color = Color("#f2f0e9")
	var shadow: Color = Color("#643329")

	_create_local_box(root, "Cuerpo", Vector3(0.0, 1.0, 0.0), Vector3(2.6, 2.0, 1.8), red, false)
	_create_local_box(root, "TechoIzq", Vector3(-0.42, 2.10, 0.0), Vector3(1.35, 0.28, 2.0), white, false)
	_create_local_box(root, "TechoDer", Vector3(0.42, 2.10, 0.0), Vector3(1.35, 0.28, 2.0), white, false)
	_create_local_box(root, "Fronton", Vector3(0.0, 2.35, 0.0), Vector3(1.1, 0.34, 2.0), white, false)
	_create_local_box(root, "Puerta", Vector3(0.0, 0.62, 0.92), Vector3(0.74, 1.2, 0.08), shadow, false)
	_create_local_box(root, "MarcoPuerta", Vector3(0.0, 0.62, 0.98), Vector3(0.96, 1.36, 0.06), white, false)
	_create_local_box(root, "Ventana", Vector3(0.0, 1.62, 0.92), Vector3(0.34, 0.34, 0.08), shadow, false)
	_create_local_box(root, "BordeIzq", Vector3(-1.28, 1.0, 0.0), Vector3(0.08, 2.04, 1.86), red_dark, false)
	_create_local_box(root, "BordeDer", Vector3(1.28, 1.0, 0.0), Vector3(0.08, 2.04, 1.86), red_dark, false)


func _create_windmill(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(1.6, 4.2, 1.6))
	var wood: Color = Color("#d1c2ab")
	var wood_dark: Color = Color("#907f66")
	var blade: Color = Color("#eee9de")
	var roof: Color = Color("#805339")

	_create_local_box(root, "Base", Vector3(0.0, 1.3, 0.0), Vector3(1.2, 2.6, 1.2), wood, false)
	_create_local_box(root, "BaseAlta", Vector3(0.0, 2.85, 0.0), Vector3(0.95, 0.55, 0.95), wood_dark, false)
	_create_local_box(root, "Techo", Vector3(0.0, 3.45, 0.0), Vector3(1.15, 0.45, 1.15), roof, false)
	_create_local_box(root, "CentroAspas", Vector3(0.0, 2.55, 0.72), Vector3(0.24, 0.24, 0.24), wood_dark, false)
	_create_local_box(root, "AspaArriba", Vector3(0.0, 3.10, 0.72), Vector3(0.14, 0.90, 0.08), blade, false)
	_create_local_box(root, "AspaAbajo", Vector3(0.0, 2.00, 0.72), Vector3(0.14, 0.90, 0.08), blade, false)
	_create_local_box(root, "AspaIzq", Vector3(-0.55, 2.55, 0.72), Vector3(0.90, 0.14, 0.08), blade, false)
	_create_local_box(root, "AspaDer", Vector3(0.55, 2.55, 0.72), Vector3(0.90, 0.14, 0.08), blade, false)


func _create_tractor_prop(node_name: String, pos: Vector3) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(2.2, 1.5, 1.5))
	var body: Color = Color("#57a83e")
	var body_dark: Color = Color("#356b2a")
	var wheel: Color = Color("#202020")
	var rim: Color = Color("#d7d7d7")
	var seat: Color = Color("#7b5230")

	_create_local_box(root, "Chasis", Vector3(0.0, 0.58, 0.0), Vector3(1.5, 0.50, 0.84), body, false)
	_create_local_box(root, "Motor", Vector3(-0.48, 0.88, 0.0), Vector3(0.62, 0.36, 0.74), body_dark, false)
	_create_local_box(root, "Cabina", Vector3(0.30, 1.00, 0.0), Vector3(0.62, 0.56, 0.70), body, false)
	_create_local_box(root, "TechoCabina", Vector3(0.30, 1.40, 0.0), Vector3(0.86, 0.10, 0.82), body_dark, false)
	_create_local_box(root, "Escape", Vector3(-0.72, 1.12, 0.0), Vector3(0.10, 0.48, 0.10), Color("#6e6e6e"), false)
	_create_local_box(root, "Asiento", Vector3(0.30, 0.96, 0.0), Vector3(0.24, 0.12, 0.26), seat, false)
	_create_local_box(root, "RuedaTI", Vector3(-0.62, 0.34, 0.56), Vector3(0.28, 0.68, 0.28), wheel, false)
	_create_local_box(root, "RuedaTD", Vector3(-0.62, 0.34, -0.56), Vector3(0.28, 0.68, 0.28), wheel, false)
	_create_local_box(root, "RuedaPI", Vector3(0.70, 0.26, 0.56), Vector3(0.22, 0.52, 0.22), wheel, false)
	_create_local_box(root, "RuedaPD", Vector3(0.70, 0.26, -0.56), Vector3(0.22, 0.52, 0.22), wheel, false)
	_create_local_box(root, "RinTI", Vector3(-0.62, 0.34, 0.56), Vector3(0.10, 0.34, 0.10), rim, false)
	_create_local_box(root, "RinTD", Vector3(-0.62, 0.34, -0.56), Vector3(0.10, 0.34, 0.10), rim, false)
	_create_local_box(root, "RinPI", Vector3(0.70, 0.26, 0.56), Vector3(0.08, 0.24, 0.08), rim, false)
	_create_local_box(root, "RinPD", Vector3(0.70, 0.26, -0.56), Vector3(0.08, 0.24, 0.08), rim, false)


func _create_signpost(node_name: String, pos: Vector3, start_arrow: bool) -> void:
	var root := _make_obstacle_root(node_name, pos, Vector3(0.8, 1.8, 0.5))
	var wood: Color = Color("#8a5a35")
	var wood_dark: Color = Color("#5b3720")
	var sign_color: Color = Color("#f1d85b") if start_arrow else Color("#8fdd68")

	_create_local_box(root, "Poste", Vector3(0.0, 0.9, 0.0), Vector3(0.16, 1.8, 0.16), wood_dark, false)
	_create_local_box(root, "TablaA", Vector3(0.18 if start_arrow else -0.18, 1.26, 0.0), Vector3(0.82, 0.26, 0.14), sign_color, false)
	_create_local_box(root, "TablaB", Vector3(0.10 if start_arrow else -0.10, 0.92, 0.0), Vector3(0.66, 0.24, 0.14), sign_color.darkened(0.08), false)
	if start_arrow:
		_create_local_box(root, "Punta", Vector3(0.58, 1.26, 0.0), Vector3(0.20, 0.18, 0.14), sign_color, false)
	else:
		_create_local_box(root, "Punta", Vector3(-0.58, 1.26, 0.0), Vector3(0.20, 0.18, 0.14), sign_color, false)

func _create_farm_fences() -> void:
	_create_farm_fence_side("Valla_granja_izquierda", -9.2, 58.0)
	_create_farm_fence_side("Valla_granja_derecha", 9.2, 58.0)
	_create_front_boundary_fence()


func _create_farm_fence_side(side_name: String, x_pos: float, total_length: float, center_z: float = 0.0) -> void:
	var side_root := Node3D.new()
	side_root.name = side_name
	add_child(side_root)

	var dark_wood := Color("#4a2e1f")
	var mid_wood := Color("#6b4329")
	var light_wood := Color("#87583a")

	var segment_length: float = 3.2
	var start_z: float = center_z - total_length * 0.5
	var segment_count: int = int(ceil(total_length / segment_length))

	for i in range(segment_count):
		var seg_start: float = start_z + i * segment_length
		var seg_end: float = min(seg_start + segment_length, center_z + total_length * 0.5)
		var seg_len: float = max(0.4, seg_end - seg_start)
		var seg_center: float = seg_start + seg_len * 0.5

		# Postes gruesos del segmento.
		_create_local_box(side_root, "PosteInicio_%d" % i, Vector3(x_pos, 0.95, seg_start + 0.12), Vector3(0.24, 1.9, 0.24), dark_wood, true)
		_create_local_box(side_root, "PosteFin_%d" % i, Vector3(x_pos, 0.95, seg_end - 0.12), Vector3(0.24, 1.9, 0.24), dark_wood, true)

		# Travesaños horizontales.
		_create_local_box(side_root, "TravesanoSup_%d" % i, Vector3(x_pos, 1.18, seg_center), Vector3(0.12, 0.16, max(0.5, seg_len - 0.24)), mid_wood, true)
		_create_local_box(side_root, "TravesanoMid_%d" % i, Vector3(x_pos, 0.68, seg_center), Vector3(0.12, 0.14, max(0.5, seg_len - 0.24)), light_wood, true)

		# Tablas verticales detalladas.
		var plank_count: int = max(3, int(floor(seg_len / 0.52)))
		for j in range(plank_count):
			var t: float = 0.0 if plank_count == 1 else float(j) / float(plank_count - 1)
			var plank_z: float = lerp(seg_start + 0.28, seg_end - 0.28, t)
			var plank_h: float = 1.42 + 0.08 * sin(float(i * 5 + j))
			var plank_y: float = 0.78 + (plank_h - 1.42) * 0.5
			var plank_color: Color = mid_wood.lerp(light_wood, 0.25 + 0.25 * float((i + j) % 2))
			_create_local_box(side_root, "Tabla_%d_%d" % [i, j], Vector3(x_pos, plank_y, plank_z), Vector3(0.16, plank_h, 0.18), plank_color, true)

			# Tapa superior pequeña para dar más detalle.
			if j % 2 == 0:
				_create_local_box(side_root, "Tapa_%d_%d" % [i, j], Vector3(x_pos, plank_y + plank_h * 0.5 + 0.06, plank_z), Vector3(0.18, 0.07, 0.20), dark_wood, false)


func _create_front_boundary_fence() -> void:
	var front_root := Node3D.new()
	front_root.name = "Valla_frontal_corral"
	add_child(front_root)

	var dark_wood := Color("#4a2e1f")
	var mid_wood := Color("#6b4329")
	var light_wood := Color("#87583a")
	var z_pos: float = FRONT_FENCE_Z

	_create_local_box(front_root, "PosteIzq", Vector3(-8.6, 0.96, z_pos), Vector3(0.24, 1.92, 0.24), dark_wood, true)
	_create_local_box(front_root, "PosteDer", Vector3(8.6, 0.96, z_pos), Vector3(0.24, 1.92, 0.24), dark_wood, true)

	_create_local_box(front_root, "BarraSup", Vector3(0.0, 1.18, z_pos), Vector3(17.0, 0.16, 0.12), mid_wood, true)
	_create_local_box(front_root, "BarraMid", Vector3(0.0, 0.72, z_pos), Vector3(17.0, 0.14, 0.12), light_wood, true)

	for j in range(19):
		var plank_x: float = -8.2 + float(j) * 0.9
		var plank_h: float = 1.46 + 0.06 * sin(float(j) * 0.8)
		var plank_y: float = 0.80 + (plank_h - 1.46) * 0.5
		var plank_color: Color = mid_wood.lerp(light_wood, 0.2 + 0.15 * float(j % 2))
		_create_local_box(front_root, "TablaFrontal_%d" % j, Vector3(plank_x, plank_y, z_pos), Vector3(0.22, plank_h, 0.18), plank_color, true)
		if j % 2 == 0:
			_create_local_box(front_root, "TapaFrontal_%d" % j, Vector3(plank_x, plank_y + plank_h * 0.5 + 0.06, z_pos), Vector3(0.24, 0.07, 0.20), dark_wood, false)


func _warm_palette_color(color: Color) -> Color:
	# Filtro cálido global para que el mapa no se vea tan blanco/quemado.
	var warm_tint: Color = Color("#ffd29a")
	var adjusted: Color = color.lerp(warm_tint, 0.13).darkened(0.08)
	adjusted.a = color.a
	return adjusted


func _create_local_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()

	root.name = node_name
	root.position = pos

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh

	var final_color: Color = _warm_palette_color(color)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = final_color
	mat.roughness = 1.0
	mesh_instance.set_surface_override_material(0, mat)
	root.add_child(mesh_instance)

	if collision:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		root.add_child(collision_shape)

	parent.add_child(root)


func _create_goal_area() -> void:
	# Ya no es una meta final: es un punto de avance que genera más camino.
	_create_endless_checkpoint(next_checkpoint_z)


func _create_endless_checkpoint(z_pos: float) -> void:
	# Ya no dibujamos la línea blanca ni dependemos de un Area3D.
	# El siguiente tramo ahora se genera por proximidad del jugador en _process.
	next_checkpoint_z = z_pos
	if endless_checkpoint != null:
		endless_checkpoint.queue_free()
		endless_checkpoint = null

func _create_box(node_name: String, pos: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()

	root.name = node_name
	root.global_position = pos

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh

	var final_color: Color = _warm_palette_color(color)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = final_color
	mat.roughness = 1.0
	mesh_instance.set_surface_override_material(0, mat)
	root.add_child(mesh_instance)

	if collision:
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		root.add_child(collision_shape)

	add_child(root)

func _setup_world_environment() -> void:
	var existing := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if existing == null:
		existing = WorldEnvironment.new()
		existing.name = "WorldEnvironment"
		add_child(existing)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#76b7e8")
	sky_mat.sky_horizon_color = Color("#f3d7b6")
	sky_mat.ground_bottom_color = Color("#86b98b")
	sky_mat.ground_horizon_color = Color("#e8d0a0")
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.58
	env.tonemap_exposure = 0.82
	env.fog_enabled = true
	env.fog_light_color = Color("#f0caa0")
	env.fog_light_energy = 0.16
	env.fog_density = 0.0010
	existing.environment = env


func _style_hud() -> void:
	var canvas := $CanvasLayer

	hud_panel = PanelContainer.new()
	hud_panel.name = "HUD_CrossyRoad"
	hud_panel.anchor_left = 0.0
	hud_panel.anchor_top = 0.0
	hud_panel.anchor_right = 0.0
	hud_panel.anchor_bottom = 0.0
	hud_panel.offset_left = 18
	hud_panel.offset_top = 16
	hud_panel.offset_right = 310
	hud_panel.offset_bottom = 148
	hud_panel.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.07, 0.06, 0.62), Color("#b6ff75"), 2, 18))
	canvas.add_child(hud_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	hud_panel.add_child(margin)

	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 4)
	margin.add_child(hud_box)

	message_label.get_parent().remove_child(message_label)
	hud_box.add_child(message_label)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.add_theme_color_override("font_color", Color("#ffffff"))
	message_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	message_label.add_theme_constant_override("outline_size", 5)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.visible = false

	attempts_label.visible = false
	attempts_label.text = ""

	hud_time_label = Label.new()
	hud_time_label.name = "HUD_Tiempo"
	hud_time_label.add_theme_font_size_override("font_size", 16)
	hud_time_label.add_theme_color_override("font_color", Color("#f5f5e6"))
	hud_time_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	hud_time_label.add_theme_constant_override("outline_size", 4)
	hud_box.add_child(hud_time_label)

	hud_score_label = Label.new()
	hud_score_label.name = "HUD_Score"
	hud_score_label.add_theme_font_size_override("font_size", 16)
	hud_score_label.add_theme_color_override("font_color", Color("#ffd45c"))
	hud_score_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	hud_score_label.add_theme_constant_override("outline_size", 4)
	hud_box.add_child(hud_score_label)

	hud_artifacts_label = Label.new()
	hud_artifacts_label.name = "HUD_Artefactos"
	hud_artifacts_label.add_theme_font_size_override("font_size", 16)
	hud_artifacts_label.add_theme_color_override("font_color", Color("#7dffef"))
	hud_artifacts_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	hud_artifacts_label.add_theme_constant_override("outline_size", 4)
	hud_box.add_child(hud_artifacts_label)

	hud_highscore_label = Label.new()
	hud_highscore_label.name = "HUD_HighScore"
	hud_highscore_label.add_theme_font_size_override("font_size", 16)
	hud_highscore_label.add_theme_color_override("font_color", Color("#d3b7ff"))
	hud_highscore_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	hud_highscore_label.add_theme_constant_override("outline_size", 4)
	hud_box.add_child(hud_highscore_label)

	hud_api_label = Label.new()
	hud_api_label.name = "HUD_API"
	hud_api_label.text = "Evento: 30s"
	hud_api_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_api_label.custom_minimum_size = Vector2(0, 26)
	hud_api_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_api_label.add_theme_font_size_override("font_size", 16)
	hud_api_label.add_theme_color_override("font_color", Color("#ffffff"))
	hud_api_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	hud_api_label.add_theme_constant_override("outline_size", 4)
	hud_box.add_child(hud_api_label)

	hud_goal_panel = PanelContainer.new()
	hud_goal_panel.name = "HUD_Meta"
	hud_goal_panel.anchor_left = 1.0
	hud_goal_panel.anchor_top = 0.0
	hud_goal_panel.anchor_right = 1.0
	hud_goal_panel.anchor_bottom = 0.0
	hud_goal_panel.offset_left = -185
	hud_goal_panel.offset_top = 16
	hud_goal_panel.offset_right = -18
	hud_goal_panel.offset_bottom = 72
	hud_goal_panel.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.07, 0.06, 0.62), Color("#ffd45c"), 2, 16))
	canvas.add_child(hud_goal_panel)

	var goal_margin := MarginContainer.new()
	goal_margin.add_theme_constant_override("margin_left", 12)
	goal_margin.add_theme_constant_override("margin_right", 12)
	goal_margin.add_theme_constant_override("margin_top", 9)
	goal_margin.add_theme_constant_override("margin_bottom", 9)
	hud_goal_panel.add_child(goal_margin)

	hud_goal_label = Label.new()
	hud_goal_label.name = "HUD_TextoMeta"
	hud_goal_label.text = "INFINITO ↑\nSigue avanzando"
	hud_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_goal_label.add_theme_font_size_override("font_size", 15)
	hud_goal_label.add_theme_color_override("font_color", Color("#ffffff"))
	hud_goal_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	hud_goal_label.add_theme_constant_override("outline_size", 4)
	goal_margin.add_child(hud_goal_label)

	scores_button = Button.new()
	scores_button.name = "HUD_BotonScores"
	scores_button.text = "★"
	scores_button.tooltip_text = "Ver últimos scores"
	scores_button.anchor_left = 0.0
	scores_button.anchor_top = 0.0
	scores_button.anchor_right = 0.0
	scores_button.anchor_bottom = 0.0
	scores_button.offset_left = 324
	scores_button.offset_top = 22
	scores_button.offset_right = 370
	scores_button.offset_bottom = 68
	scores_button.add_theme_font_size_override("font_size", 20)
	scores_button.add_theme_color_override("font_color", Color("#ffd45c"))
	scores_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	scores_button.add_theme_stylebox_override("normal", _make_style(Color(0.05, 0.07, 0.06, 0.72), Color("#ffd45c"), 2, 12))
	scores_button.add_theme_stylebox_override("hover", _make_style(Color("#26342f"), Color("#ffd45c"), 3, 12))
	scores_button.add_theme_stylebox_override("pressed", _make_style(Color("#1b261f"), Color("#ffffff"), 3, 12))
	scores_button.pressed.connect(_toggle_scores_panel)
	canvas.add_child(scores_button)

	scores_panel = PanelContainer.new()
	scores_panel.name = "HUD_PanelScores"
	scores_panel.visible = false
	scores_panel.anchor_left = 0.0
	scores_panel.anchor_top = 0.0
	scores_panel.anchor_right = 0.0
	scores_panel.anchor_bottom = 0.0
	scores_panel.offset_left = 18
	scores_panel.offset_top = 148
	scores_panel.offset_right = 338
	scores_panel.offset_bottom = 424
	scores_panel.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.06, 0.05, 0.88), Color("#ffd45c"), 2, 16))
	canvas.add_child(scores_panel)

	var scores_margin := MarginContainer.new()
	scores_margin.add_theme_constant_override("margin_left", 14)
	scores_margin.add_theme_constant_override("margin_right", 14)
	scores_margin.add_theme_constant_override("margin_top", 12)
	scores_margin.add_theme_constant_override("margin_bottom", 12)
	scores_panel.add_child(scores_margin)

	var scores_box := VBoxContainer.new()
	scores_box.add_theme_constant_override("separation", 8)
	scores_margin.add_child(scores_box)

	var scores_header := HBoxContainer.new()
	scores_header.add_theme_constant_override("separation", 8)
	scores_box.add_child(scores_header)

	var scores_title := Label.new()
	scores_title.text = "★ SCORES"
	scores_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scores_title.add_theme_font_size_override("font_size", 15)
	scores_title.add_theme_color_override("font_color", Color("#ffd45c"))
	scores_title.add_theme_color_override("font_outline_color", Color("#18241f"))
	scores_title.add_theme_constant_override("outline_size", 4)
	scores_header.add_child(scores_title)

	scores_close_button = Button.new()
	scores_close_button.text = "X"
	scores_close_button.custom_minimum_size = Vector2(36, 30)
	scores_close_button.add_theme_font_size_override("font_size", 13)
	scores_close_button.pressed.connect(_hide_scores_panel)
	scores_header.add_child(scores_close_button)

	scores_label = Label.new()
	scores_label.text = "Cargando scores..."
	scores_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scores_label.add_theme_font_size_override("font_size", 12)
	scores_label.add_theme_color_override("font_color", Color("#ffffff"))
	scores_label.add_theme_color_override("font_outline_color", Color("#18241f"))
	scores_label.add_theme_constant_override("outline_size", 3)
	scores_box.add_child(scores_label)

	catch_panel = PanelContainer.new()
	catch_panel.name = "HUD_AvisoVaca"
	catch_panel.visible = false
	catch_panel.anchor_left = 0.5
	catch_panel.anchor_top = 0.18
	catch_panel.anchor_right = 0.5
	catch_panel.anchor_bottom = 0.18
	catch_panel.offset_left = -340
	catch_panel.offset_top = -42
	catch_panel.offset_right = 340
	catch_panel.offset_bottom = 42
	catch_panel.add_theme_stylebox_override("panel", _make_style(Color(0.10, 0.03, 0.03, 0.88), Color("#ff7777"), 3, 18))
	canvas.add_child(catch_panel)

	var catch_margin := MarginContainer.new()
	catch_margin.add_theme_constant_override("margin_left", 10)
	catch_margin.add_theme_constant_override("margin_right", 10)
	catch_margin.add_theme_constant_override("margin_top", 9)
	catch_margin.add_theme_constant_override("margin_bottom", 9)
	catch_panel.add_child(catch_margin)

	catch_label = Label.new()
	catch_label.name = "TextoAvisoVaca"
	catch_label.text = ""
	catch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	catch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	catch_label.add_theme_font_size_override("font_size", 22)
	catch_label.add_theme_color_override("font_color", Color("#ffffff"))
	catch_label.add_theme_color_override("font_outline_color", Color("#1a0505"))
	catch_label.add_theme_constant_override("outline_size", 5)
	catch_margin.add_child(catch_label)

func _toggle_scores_panel() -> void:
	if scores_panel == null:
		return
	if scores_panel.visible:
		scores_panel.visible = false
	else:
		_refresh_scores_panel()
		scores_panel.visible = true


func _hide_scores_panel() -> void:
	if scores_panel:
		scores_panel.visible = false


func _refresh_scores_panel() -> void:
	if scores_label == null:
		return

	HighscoreManager.load_highscore()
	var output: String = ""
	output += "MÁXIMO: " + str(HighscoreManager.get_best_score())
	var best_date: String = HighscoreManager.get_best_date()
	if not best_date.is_empty():
		output += "  " + _short_score_date(best_date)
	output += "\n\nÚLTIMOS 10:\n"

	var scores: Array = HighscoreManager.get_recent_scores()
	if scores.size() == 0:
		output += "Aún no hay partidas guardadas."
	else:
		var index: int = 1
		for row in scores:
			if row is Dictionary:
				var row_score: int = int(row.get("max_score", 0))
				var row_date: String = _short_score_date(str(row.get("date", "")))
				output += "%02d. %d pts" % [index, row_score]
				if not row_date.is_empty():
					output += "  " + row_date
				output += "\n"
				index += 1

	scores_label.text = output.strip_edges()


func _short_score_date(date_value: String) -> String:
	if date_value.length() > 16:
		return date_value.substr(0, 16)
	return date_value


func _create_pause_menu() -> void:
	pause_menu = Control.new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)

	pause_background = ColorRect.new()
	pause_background.name = "FondoOscuro"
	pause_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_background.color = Color(0.02, 0.02, 0.04, 0.74)
	pause_background.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(pause_background)

	pause_card = PanelContainer.new()
	pause_card.name = "TarjetaMenu"
	pause_card.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_card.custom_minimum_size = Vector2(520, 570)
	pause_card.anchor_left = 0.5
	pause_card.anchor_top = 0.5
	pause_card.anchor_right = 0.5
	pause_card.anchor_bottom = 0.5
	pause_card.offset_left = -260
	pause_card.offset_top = -285
	pause_card.offset_right = 260
	pause_card.offset_bottom = 285
	pause_card.pivot_offset = Vector2(260, 285)
	pause_card.add_theme_stylebox_override("panel", _make_style(Color("#101f19"), Color("#75e56d"), 3, 20))
	pause_menu.add_child(pause_card)

	var margin := MarginContainer.new()
	margin.name = "Margen"
	margin.process_mode = Node.PROCESS_MODE_ALWAYS
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	pause_card.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.name = "Contenido"
	root_box.process_mode = Node.PROCESS_MODE_ALWAYS
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	pause_title_label = Label.new()
	pause_title_label.text = "GLUPIX FARM ESCAPE"
	pause_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title_label.add_theme_color_override("font_color", Color("#b6ff75"))
	pause_title_label.add_theme_font_size_override("font_size", 28)
	root_box.add_child(pause_title_label)

	pause_subtitle_label = Label.new()
	pause_subtitle_label.text = "Menú de pausa"
	pause_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_subtitle_label.add_theme_color_override("font_color", Color("#f5f5e6"))
	pause_subtitle_label.add_theme_font_size_override("font_size", 15)
	root_box.add_child(pause_subtitle_label)

	var separator_1 := HSeparator.new()
	root_box.add_child(separator_1)

	main_menu_view = VBoxContainer.new()
	main_menu_view.name = "VistaMenuPrincipal"
	main_menu_view.process_mode = Node.PROCESS_MODE_ALWAYS
	main_menu_view.add_theme_constant_override("separation", 8)
	root_box.add_child(main_menu_view)

	resume_button = _make_menu_button("▶  Reanudar", Color("#75e56d"))
	resume_button.pressed.connect(_resume_game)
	main_menu_view.add_child(resume_button)

	restart_button = _make_menu_button("↻  Reiniciar", Color("#ffd45c"))
	restart_button.pressed.connect(_restart_game)
	main_menu_view.add_child(restart_button)

	config_button = _make_menu_button("⚙  Configuración", Color("#69c7ff"))
	config_button.pressed.connect(_show_config)
	main_menu_view.add_child(config_button)

	controls_button = _make_menu_button("⌨  Controles", Color("#c59bff"))
	controls_button.pressed.connect(_show_controls)
	main_menu_view.add_child(controls_button)

	exit_button = _make_menu_button("✕  Salir", Color("#ff7777"))
	exit_button.pressed.connect(_exit_game)
	main_menu_view.add_child(exit_button)

	var separator_2 := HSeparator.new()
	main_menu_view.add_child(separator_2)

	var info_panel := PanelContainer.new()
	info_panel.name = "PanelInfo"
	info_panel.add_theme_stylebox_override("panel", _make_style(Color("#0f1714"), Color("#3c5b49"), 1, 12))
	info_panel.custom_minimum_size = Vector2(430, 96)
	main_menu_view.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 14)
	info_margin.add_theme_constant_override("margin_right", 14)
	info_margin.add_theme_constant_override("margin_top", 9)
	info_margin.add_theme_constant_override("margin_bottom", 9)
	info_panel.add_child(info_margin)

	pause_info_label = Label.new()
	pause_info_label.name = "Info"
	pause_info_label.text = "Pausa activa. Elige una opción."
	pause_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_info_label.add_theme_color_override("font_color", Color("#ffffff"))
	pause_info_label.add_theme_font_size_override("font_size", 14)
	info_margin.add_child(pause_info_label)

	game_over_tip_box = HBoxContainer.new()
	game_over_tip_box.name = "ConsejoGameOver"
	game_over_tip_box.visible = false
	game_over_tip_box.add_theme_constant_override("separation", 10)
	main_menu_view.add_child(game_over_tip_box)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(48, 48)
	icon_panel.add_theme_stylebox_override("panel", _make_style(Color("#2a2110"), Color("#ffd45c"), 2, 12))
	game_over_tip_box.add_child(icon_panel)

	game_over_icon_label = Label.new()
	game_over_icon_label.text = "!"
	game_over_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_icon_label.add_theme_font_size_override("font_size", 30)
	game_over_icon_label.add_theme_color_override("font_color", Color("#ffd45c"))
	icon_panel.add_child(game_over_icon_label)

	var tip_panel := PanelContainer.new()
	tip_panel.custom_minimum_size = Vector2(360, 48)
	tip_panel.add_theme_stylebox_override("panel", _make_style(Color("#0f1714"), Color("#75e56d"), 1, 12))
	game_over_tip_box.add_child(tip_panel)

	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 12)
	tip_margin.add_theme_constant_override("margin_right", 12)
	tip_margin.add_theme_constant_override("margin_top", 9)
	tip_margin.add_theme_constant_override("margin_bottom", 9)
	tip_panel.add_child(tip_margin)

	game_over_tip_label = Label.new()
	game_over_tip_label.text = "Consejo: espera antes de avanzar."
	game_over_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_tip_label.add_theme_font_size_override("font_size", 13)
	game_over_tip_label.add_theme_color_override("font_color", Color("#ffffff"))
	tip_margin.add_child(game_over_tip_label)

	config_view = VBoxContainer.new()
	config_view.name = "VistaConfiguracion"
	config_view.visible = false
	config_view.process_mode = Node.PROCESS_MODE_ALWAYS
	config_view.add_theme_constant_override("separation", 12)
	root_box.add_child(config_view)
	_build_config_view()

	controls_view = VBoxContainer.new()
	controls_view.name = "VistaControles"
	controls_view.visible = false
	controls_view.process_mode = Node.PROCESS_MODE_ALWAYS
	controls_view.add_theme_constant_override("separation", 12)
	root_box.add_child(controls_view)
	_build_controls_view()

	pause_hint_label = Label.new()
	pause_hint_label.text = "ESC / P para cerrar el menú"
	pause_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint_label.add_theme_color_override("font_color", Color("#b7c9bd"))
	pause_hint_label.add_theme_font_size_override("font_size", 14)
	root_box.add_child(pause_hint_label)

	$CanvasLayer.add_child(pause_menu)

func _build_config_view() -> void:
	var info := Label.new()
	info.text = "Ajusta música, pantalla y escala."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color("#ffffff"))
	config_view.add_child(info)

	var music_label := Label.new()
	music_label.text = "Música"
	music_label.add_theme_font_size_override("font_size", 17)
	config_view.add_child(music_label)

	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 1.0
	music_slider.value = GameSettings.music_volume * 100.0
	music_slider.custom_minimum_size = Vector2(430, 30)
	music_slider.value_changed.connect(_on_music_slider_changed)
	config_view.add_child(music_slider)

	var screen_label := Label.new()
	screen_label.text = "Tipo de pantalla"
	screen_label.add_theme_font_size_override("font_size", 17)
	config_view.add_child(screen_label)

	screen_option = OptionButton.new()
	screen_option.add_item("Pantalla completa")
	screen_option.add_item("Ventana")
	screen_option.add_item("Sin bordes")
	screen_option.select(GameSettings.screen_mode)
	screen_option.item_selected.connect(_on_screen_option_selected)
	config_view.add_child(screen_option)

	var scale_label := Label.new()
	scale_label.text = "Escala de interfaz"
	scale_label.add_theme_font_size_override("font_size", 17)
	config_view.add_child(scale_label)

	scale_slider = HSlider.new()
	scale_slider.min_value = 80.0
	scale_slider.max_value = 125.0
	scale_slider.step = 5.0
	scale_slider.value = GameSettings.ui_scale * 100.0
	scale_slider.custom_minimum_size = Vector2(430, 30)
	scale_slider.value_changed.connect(_on_scale_slider_changed)
	config_view.add_child(scale_slider)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 12)
	config_view.add_child(spacer)

	var back_button := _make_menu_button("←  Volver al menú", Color("#75e56d"))
	back_button.pressed.connect(_show_main_menu)
	config_view.add_child(back_button)

func _build_controls_view() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(Color("#0f1714"), Color("#3c5b49"), 1, 12))
	panel.custom_minimum_size = Vector2(430, 210)
	controls_view.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "WASD / Flechas: voltear\nEspacio: avanzar una casilla\nESC / P: abrir o cerrar menú\n\nObjetivo: cruza la granja sin que las vacas te atrapen."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#ffffff"))
	margin.add_child(label)

	var back_button := _make_menu_button("←  Volver al menú", Color("#75e56d"))
	back_button.pressed.connect(_show_main_menu)
	controls_view.add_child(back_button)

func _make_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _make_menu_button(text_value: String, accent_color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(430, 46)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))

	var normal := _make_style(Color("#26342f"), accent_color.darkened(0.45), 2, 12)
	var hover := _make_style(accent_color.darkened(0.25), accent_color, 3, 12)
	var pressed := _make_style(accent_color.darkened(0.45), Color("#ffffff"), 3, 12)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	return button

func _toggle_pause_menu() -> void:
	if game_over_active:
		return
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	pause_menu.visible = true
	_set_hud_visible(false)
	SfxManager.play_menu()
	_show_main_menu()

func _resume_game() -> void:
	if game_over_active:
		return
	SfxManager.stop_menu()
	get_tree().paused = false
	pause_menu.visible = false
	_set_hud_visible(true)

func _restart_game() -> void:
	game_over_active = false
	SfxManager.stop_menu()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _show_main_menu() -> void:
	game_over_active = false
	pause_title_label.text = "GLUPIX FARM ESCAPE"
	pause_subtitle_label.text = "Menú de pausa"
	pause_info_label.text = "Pausa activa. Elige una opción."
	pause_hint_label.text = "ESC / P para cerrar el menú"
	pause_hint_label.visible = true
	if pause_background:
		pause_background.color = Color(0.02, 0.02, 0.04, 0.74)
	if resume_button:
		resume_button.visible = true
	if restart_button:
		restart_button.visible = true
		restart_button.text = "↻  Reiniciar"
	if config_button:
		config_button.visible = true
	if controls_button:
		controls_button.visible = true
	if exit_button:
		exit_button.visible = true
		exit_button.text = "✕  Salir"
	if game_over_tip_box:
		game_over_tip_box.visible = false
	game_over_tip_token += 1
	main_menu_view.visible = true
	config_view.visible = false
	controls_view.visible = false

func _show_config() -> void:
	pause_hint_label.visible = true
	pause_subtitle_label.text = "Configuración"
	main_menu_view.visible = false
	config_view.visible = true
	controls_view.visible = false
	if music_slider:
		music_slider.value = GameSettings.music_volume * 100.0
	if screen_option:
		screen_option.select(GameSettings.screen_mode)
	if scale_slider:
		scale_slider.value = GameSettings.ui_scale * 100.0

func _show_controls() -> void:
	pause_hint_label.visible = true
	pause_subtitle_label.text = "Controles"
	main_menu_view.visible = false
	config_view.visible = false
	controls_view.visible = true

func _exit_game() -> void:
	SfxManager.stop_menu()
	get_tree().quit()

func _set_hud_visible(value: bool) -> void:
	if hud_panel:
		hud_panel.visible = value
	if hud_goal_panel:
		hud_goal_panel.visible = value
	if scores_button:
		scores_button.visible = value
	if scores_panel and not value:
		scores_panel.visible = false
	if catch_panel and not value:
		catch_panel.visible = false

func _on_settings_changed() -> void:
	_apply_ui_scale()
	MusicManager.refresh_volume()

func _on_music_slider_changed(value: float) -> void:
	GameSettings.set_music_volume(value / 100.0)

func _on_screen_option_selected(index: int) -> void:
	GameSettings.set_screen_mode(index)

func _on_scale_slider_changed(value: float) -> void:
	GameSettings.set_ui_scale(value / 100.0)

func _apply_ui_scale() -> void:
	var s: float = GameSettings.ui_scale
	if hud_panel:
		hud_panel.scale = Vector2(s, s)
	if hud_goal_panel:
		hud_goal_panel.scale = Vector2(s, s)
	if scores_button:
		scores_button.scale = Vector2(s, s)
	if scores_panel:
		scores_panel.scale = Vector2(s, s)
	if pause_card:
		pause_card.scale = Vector2(s, s)

func on_player_hit_npc(npc: Node) -> void:
	if game_won or game_over_active:
		return
	attempts += 1
	_update_score_from_player()
	HighscoreManager.update_highscore(score)
	if player and player.has_method("stop_player"):
		player.stop_player()
	_show_game_over_menu(npc)

func _show_game_over_menu(source_npc: Node = null) -> void:
	game_over_active = true
	get_tree().paused = true
	pause_menu.visible = true
	_set_hud_visible(false)
	SfxManager.stop_menu()
	SfxManager.play_gameover()

	var cause_text: String = "Un enemigo atrapó a Glupix."
	if source_npc != null and String(source_npc.name).to_lower().find("pollo") != -1:
		cause_text = "¡La manada de pollos te arrolló!"
	elif source_npc != null and String(source_npc.name).to_lower().find("vaca") != -1:
		cause_text = "¡Una vaca atrapó a Glupix!"

	pause_title_label.text = "GAME OVER"
	pause_subtitle_label.text = "¿Quieres reiniciar?"
	pause_info_label.text = cause_text + "\n\nTiempo: " + _format_time(elapsed_time) + "   Score: " + str(score) + "\nMejor: " + str(HighscoreManager.get_best_score())
	pause_hint_label.text = ""
	pause_hint_label.visible = false
	if game_over_tip_box:
		game_over_tip_box.visible = true
	_start_game_over_tips()
	if pause_background:
		pause_background.color = Color(0.01, 0.01, 0.01, 0.82)

	main_menu_view.visible = true
	config_view.visible = false
	controls_view.visible = false
	if resume_button:
		resume_button.visible = false
	if restart_button:
		restart_button.visible = true
		restart_button.text = "↻  Reiniciar partida"
	if config_button:
		config_button.visible = false
	if controls_button:
		controls_button.visible = false
	if exit_button:
		exit_button.visible = true
		exit_button.text = "✕  Salir"


func _start_game_over_tips() -> void:
	game_over_tip_token += 1
	game_over_tip_index = rng.randi_range(0, GAME_OVER_TIPS.size() - 1)
	_cycle_game_over_tips(game_over_tip_token)


func _cycle_game_over_tips(token: int) -> void:
	while game_over_active and token == game_over_tip_token:
		if game_over_tip_label:
			game_over_tip_label.text = "Consejo: " + GAME_OVER_TIPS[game_over_tip_index % GAME_OVER_TIPS.size()]
		game_over_tip_index += 1
		await get_tree().create_timer(2.4, true).timeout


func _show_catch_message(text_value: String) -> void:
	if catch_panel == null or catch_label == null:
		return

	catch_message_token += 1
	var current_token: int = catch_message_token

	catch_label.text = text_value
	catch_panel.visible = true
	catch_panel.modulate.a = 1.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	catch_panel.scale = Vector2(0.86, 0.86)
	tween.tween_property(catch_panel, "scale", Vector2.ONE, 0.18)

	await get_tree().create_timer(1.6).timeout
	if current_token != catch_message_token:
		return

	var fade := create_tween()
	fade.tween_property(catch_panel, "modulate:a", 0.0, 0.35)
	await fade.finished

	if current_token == catch_message_token:
		catch_panel.visible = false
		catch_panel.modulate.a = 1.0

func _on_goal_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if endless_mode:
		_extend_endless_world()
	else:
		if not game_won:
			game_won = true
			SfxManager.play_win()
			_update_score_from_player()
			message_label.text = "¡GANASTE!"
			_refresh_hud_numbers()


func _extend_endless_world() -> void:
	chunk_index += 1

	var chunk_start_z: float = deepest_generated_z

	# Tramos largos: salen entre 78 y 102 unidades.
	var chunk_length: float = 78.0 + float(rng.randi_range(0, 24))
	var chunk_end_z: float = chunk_start_z - chunk_length
	var chunk_center_z: float = (chunk_start_z + chunk_end_z) * 0.5

	_create_box("Suelo_infinito_%d" % chunk_index, Vector3(0, -0.14, chunk_center_z), Vector3(18.8, 0.28, chunk_length + 2.0), Color("#3f8d4f"), true)
	_create_farm_fence_side("Valla_infinita_izq_%d" % chunk_index, -9.2, chunk_length, chunk_center_z)
	_create_farm_fence_side("Valla_infinita_der_%d" % chunk_index, 9.2, chunk_length, chunk_center_z)

	var current_z: float = chunk_start_z - 2.5
	var safe_color: Color = Color("#63bf63") if chunk_index % 2 == 0 else Color("#6ec764")

	var entry_safe_len: float = 5.5 + rng.randf_range(0.0, 2.0)
	_create_grass_zone("Seguro_infinito_%d_Entrada" % chunk_index, Vector3(0, 0.20, current_z - entry_safe_len * 0.5), Vector3(18, 0.10, entry_safe_len), safe_color)
	current_z -= entry_safe_len

	# Carril especial: manada de pollos rápida con alerta sonora.
	if rng.randf() < 0.75:
		var chicken_lane_z: float = current_z - 1.2
		_create_chicken_lane("Carril_pollos_infinito_%d" % chunk_index, Vector3(0, 0.215, chicken_lane_z), Vector3(18, 0.10, 1.55))
		var chicken_dir: Vector3 = Vector3.RIGHT if chunk_index % 2 == 0 else Vector3.LEFT
		var chicken_speed: float = 24.0 + float(chunk_index) * 0.45 + rng.randf_range(0.0, 3.5)
		var chicken_count: int = rng.randi_range(7, 11)
		_spawn_chicken_herd("Manada_pollos_infinita_%d" % chunk_index, chicken_lane_z, chicken_dir, chicken_speed, chicken_count)
		current_z -= 3.0

	var road_group_count: int = rng.randi_range(3, 5)
	if chunk_index >= 6:
		road_group_count = rng.randi_range(4, 6)

	var max_lanes: int = 4
	if chunk_index >= 4:
		max_lanes = 5

	var base_speed: float = 4.2 + float(chunk_index) * 0.32

	for group in range(road_group_count):
		var lane_count: int = rng.randi_range(2, max_lanes)
		var lane_spacing: float = 2.05

		for i in range(lane_count):
			var lane_z: float = current_z - 1.0 - float(i) * lane_spacing
			var lane_color: Color = Color("#97714a") if (i + group) % 2 == 0 else Color("#8d6943")
			_create_dirt_lane("Carril_infinito_%d_%d_%d" % [chunk_index, group, i], Vector3(0, 0.22, lane_z), Vector3(18, 0.10, 1.8), lane_color)

			var direction: Vector3 = Vector3.RIGHT if (i + group + chunk_index) % 2 == 0 else Vector3.LEFT
			var start_x: float = -8.0 if direction == Vector3.RIGHT else 8.0
			var speed: float = base_speed + float(i) * 0.45 + float(group) * 0.18 + rng.randf_range(0.0, 0.55)
			_spawn_cow("Vaca_infinita_%d_%d_%d" % [chunk_index, group, i], Vector3(start_x, 0, lane_z), direction, speed, 16.0)

		current_z -= float(lane_count) * lane_spacing + 1.2

		var rest_len: float = 4.0 + rng.randf_range(0.0, 3.5)
		var rest_center_z: float = current_z - rest_len * 0.5
		var rest_color: Color = Color("#6acb67") if group % 2 == 0 else Color("#63bf63")
		_create_grass_zone("Seguro_infinito_%d_Descanso_%d" % [chunk_index, group], Vector3(0, 0.23, rest_center_z), Vector3(18, 0.10, rest_len), rest_color)
		_create_chunk_props(chunk_index * 10 + group, rest_center_z, chunk_end_z)
		_spawn_random_collectible(Vector3(rng.randf_range(-3.5, 3.5), 0.85, rest_center_z))
		current_z -= rest_len

		# A veces aparece otro carril de pollos dentro del tramo.
		if rng.randf() < 0.28 and current_z > chunk_end_z + 15.0:
			var extra_chicken_z: float = current_z - 1.2
			_create_chicken_lane("Carril_pollos_extra_%d_%d" % [chunk_index, group], Vector3(0, 0.225, extra_chicken_z), Vector3(18, 0.10, 1.55))
			var extra_dir: Vector3 = Vector3.LEFT if group % 2 == 0 else Vector3.RIGHT
			_spawn_chicken_herd("Manada_pollos_extra_%d_%d" % [chunk_index, group], extra_chicken_z, extra_dir, 25.0 + rng.randf_range(0.0, 4.0), rng.randi_range(8, 12))
			current_z -= 3.0

	var final_safe_len: float = max(7.0, current_z - chunk_end_z - 3.0)
	var final_safe_center: float = current_z - final_safe_len * 0.5
	_create_grass_zone("Seguro_infinito_%d_Final" % chunk_index, Vector3(0, 0.24, final_safe_center), Vector3(18, 0.10, final_safe_len), Color("#78d46e"))

	deepest_generated_z = chunk_end_z
	next_checkpoint_z = chunk_end_z + 5.0
	_create_endless_checkpoint(next_checkpoint_z)

	_refresh_hud_numbers()


func _create_chunk_props(index: int, safe_z: float, chunk_end_z: float) -> void:
	var left_far: float = -6.9
	var left_mid: float = -5.1
	var right_mid: float = 5.1
	var right_far: float = 6.9
	var z_front: float = safe_z + 1.15
	var z_center: float = safe_z
	var z_back: float = safe_z - 1.15

	match index % 4:
		0:
			_create_hay_stack("Paca_infinita_%d" % index, Vector3(left_far, 0, z_front))
			_create_bush("Arbusto_infinito_%d" % index, Vector3(right_far, 0, z_back), 0.92)
			_create_milk_cans("Lecheras_infitas_%d" % index, Vector3(left_mid, 0, z_back))
			_create_feed_sacks("Costales_decor_%d" % index, Vector3(right_mid, 0, z_front))
		1:
			_create_crate_stack("Cajones_infinitos_%d" % index, Vector3(right_far, 0, z_front))
			_create_mud_puddle("Charco_infinito_%d" % index, Vector3(left_far, 0.22, z_back), Vector3(1.35, 0.05, 0.90))
			_create_water_trough("Bebedero_decor_%d" % index, Vector3(left_mid, 0, z_center))
			_create_bush("Arbusto_extra_%d" % index, Vector3(right_mid, 0, z_back), 0.88)
		2:
			_create_feed_sacks("Costales_infinitos_%d" % index, Vector3(left_far, 0, z_front))
			_create_tree("Arbol_infinito_%d" % index, Vector3(right_far, 0, z_back), 0.82)
			_create_hay_stack("Paca_extra_%d" % index, Vector3(right_mid, 0, z_center))
			_create_bush("Arbusto_extra2_%d" % index, Vector3(left_mid, 0, z_back), 0.86)
		_:
			_create_water_trough("Bebedero_infinito_%d" % index, Vector3(right_far, 0, z_front))
			_create_milk_cans("Lecheras_infinitas_%d" % index, Vector3(left_far, 0, z_back))
			_create_crate_stack("Cajones_decor_%d" % index, Vector3(left_mid, 0, z_front))
			_create_feed_sacks("Costales_decor2_%d" % index, Vector3(right_mid, 0, z_back))

func _update_score_from_player() -> void:
	if player == null:
		return
	var forward_distance: float = max(0.0, PLAYER_START_Z - player.global_position.z)
	if forward_distance > best_distance:
		best_distance = forward_distance
	var new_score: int = max(0, int(best_distance * SCORE_PER_UNIT)) + collectible_score
	score = new_score

func _update_ui(message: String) -> void:
	message_label.text = message
	message_label.visible = not message.is_empty()
	_refresh_hud_numbers()

func _refresh_hud_numbers() -> void:
	attempts_label.text = ""
	if hud_time_label:
		hud_time_label.text = "Tiempo: " + _format_time(elapsed_time)
	if hud_score_label:
		hud_score_label.text = "Score: " + str(score)
	if hud_artifacts_label:
		hud_artifacts_label.text = "Artefactos: " + str(artifacts_collected)
	if hud_highscore_label:
		hud_highscore_label.text = "Mejor: " + str(HighscoreManager.get_best_score())

func _format_time(time_value: float) -> String:
	var total_seconds: int = int(floor(time_value))
	var minutes: int = int(total_seconds / 60)
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _apply_game_fonts() -> void:
	var title_font: Font = _font_title()
	var body_font: Font = _font_body()
	var pixel_font: Font = _font_pixel()

	_set_font(message_label, pixel_font)
	_set_font(attempts_label, pixel_font)
	if hud_time_label:
		_set_font(hud_time_label, pixel_font)
	if hud_score_label:
		_set_font(hud_score_label, pixel_font)
	if hud_artifacts_label:
		_set_font(hud_artifacts_label, pixel_font)
	if hud_highscore_label:
		_set_font(hud_highscore_label, pixel_font)
	if hud_api_label:
		_set_font(hud_api_label, pixel_font)
	if hud_goal_label:
		_set_font(hud_goal_label, title_font)
	if catch_label:
		_set_font(catch_label, pixel_font)
	if scores_button:
		_set_font(scores_button, pixel_font)
	if scores_panel:
		_apply_font_recursive(scores_panel, pixel_font)

	if pause_menu:
		_apply_font_recursive(pause_menu, body_font)
	if pause_title_label:
		_set_font(pause_title_label, title_font)
	if pause_subtitle_label:
		_set_font(pause_subtitle_label, pixel_font)
	if pause_info_label:
		_set_font(pause_info_label, body_font)
	if pause_hint_label:
		_set_font(pause_hint_label, body_font)

func _load_custom_font(paths: Array[String]) -> Font:
	for font_path in paths:
		if ResourceLoader.exists(font_path):
			var loaded_font = load(font_path)
			if loaded_font is Font:
				return loaded_font
	return null

func _font_title() -> Font:
	return _load_custom_font([
		"res://assets/fonts/PixelStorm.ttf",
		"res://assets/fonts/BoldPixels.otf",
		"res://assets/fonts/boldpixels.ttf",
		"res://assets/fonts/boldpixels_kit/BoldPixels.ttf",
		"res://assets/fonts/boldpixels_kit/BoldPixels.otf",
	])

func _font_body() -> Font:
	return _load_custom_font([
		"res://assets/fonts/Thin Sans.ttf",
		"res://assets/fonts/PixelStorm.ttf",
		"res://assets/fonts/boldpixels_kit/BoldPixels.ttf",
	])

func _font_pixel() -> Font:
	return _load_custom_font([
		"res://assets/fonts/BoldPixels.otf",
		"res://assets/fonts/boldpixels.ttf",
		"res://assets/fonts/boldpixels_kit/BoldPixels.ttf",
		"res://assets/fonts/boldpixels_kit/BoldPixels.otf",
		"res://assets/fonts/PixelStorm.ttf",
	])

func _set_font(control: Control, font: Font) -> void:
	if font != null:
		control.add_theme_font_override("font", font)

func _apply_font_recursive(node: Node, font: Font) -> void:
	if font == null:
		return
	if node is Control:
		node.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)
