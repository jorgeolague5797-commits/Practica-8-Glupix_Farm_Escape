extends Node

const MENU_SOUND: AudioStream = preload("res://audio/menu.mp3")
const WIN_SOUND: AudioStream = preload("res://audio/win.mp3")
const GAMEOVER_SOUND: AudioStream = preload("res://audio/gameover.mp3")
const COLLECT_SOUND: AudioStream = preload("res://audio/collect.wav")

var menu_player: AudioStreamPlayer
var win_player: AudioStreamPlayer
var gameover_player: AudioStreamPlayer
var collect_player: AudioStreamPlayer
var menu_active: bool = false

func _ready() -> void:
	menu_player = AudioStreamPlayer.new()
	menu_player.name = "MenuAudio"
	menu_player.bus = "Master"
	menu_player.volume_db = -4.0
	add_child(menu_player)
	menu_player.finished.connect(_on_menu_finished)

	win_player = AudioStreamPlayer.new()
	win_player.name = "WinSFX"
	win_player.bus = "Master"
	win_player.volume_db = -1.0
	add_child(win_player)

	gameover_player = AudioStreamPlayer.new()
	gameover_player.name = "GameOverSFX"
	gameover_player.bus = "Master"
	gameover_player.volume_db = -1.0
	add_child(gameover_player)

	collect_player = AudioStreamPlayer.new()
	collect_player.name = "CollectSFX"
	collect_player.bus = "Master"
	collect_player.volume_db = -2.0
	add_child(collect_player)

func play_menu() -> void:
	# menu.mp3 sólo se activa mientras el menú de pausa está abierto.
	if menu_player == null:
		return

	menu_active = true
	if menu_player.playing:
		return

	menu_player.stream = MENU_SOUND
	menu_player.play()

func stop_menu() -> void:
	menu_active = false
	if menu_player:
		menu_player.stop()

func _on_menu_finished() -> void:
	if menu_active and menu_player:
		menu_player.play()

func play_win() -> void:
	if win_player == null:
		return
	win_player.stop()
	win_player.stream = WIN_SOUND
	win_player.play()


func play_gameover() -> void:
	if gameover_player == null:
		return
	gameover_player.stop()
	gameover_player.stream = GAMEOVER_SOUND
	gameover_player.play()


func play_collect() -> void:
	if collect_player == null:
		return
	collect_player.stop()
	collect_player.stream = COLLECT_SOUND
	collect_player.play()
