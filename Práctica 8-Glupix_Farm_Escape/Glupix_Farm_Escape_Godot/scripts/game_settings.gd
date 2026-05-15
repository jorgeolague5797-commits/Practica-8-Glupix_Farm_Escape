extends Node

signal settings_changed

const WINDOWED_SIZE: Vector2i = Vector2i(1280, 720)

var music_volume: float = 0.65
var screen_mode: int = 0
var ui_scale: float = 1.00
var artifacts_collected: int = 0
var artifact_score: int = 0

func _ready() -> void:
	apply_window_settings()

func get_music_db() -> float:
	if music_volume <= 0.001:
		return -80.0
	return linear_to_db(music_volume)

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	settings_changed.emit()

func set_screen_mode(value: int) -> void:
	screen_mode = clamp(value, 0, 2)
	apply_window_settings()
	settings_changed.emit()

func set_ui_scale(value: float) -> void:
	ui_scale = clamp(value, 0.80, 1.25)
	settings_changed.emit()

func apply_window_settings() -> void:
	if screen_mode == 0:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif screen_mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_size(WINDOWED_SIZE)
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - WINDOWED_SIZE) / 2)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		DisplayServer.window_set_size(DisplayServer.screen_get_size())
		DisplayServer.window_set_position(Vector2i.ZERO)

func get_screen_mode_name() -> String:
	if screen_mode == 0:
		return "Pantalla completa"
	if screen_mode == 1:
		return "Ventana"
	return "Sin bordes"

func add_artifacts(amount: int, points: int) -> void:
	artifacts_collected += amount
	artifact_score += points

func reset_artifacts_session() -> void:
	artifacts_collected = 0
	artifact_score = 0
