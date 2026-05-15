extends Node

const INTRO_MUSIC: AudioStream = preload("res://audio/inicio.mp3")
const GAME_MUSIC: AudioStream = preload("res://audio/game.mp3")

var player: AudioStreamPlayer
var current_music: String = ""

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = "Master"
	add_child(player)
	player.finished.connect(_on_music_finished)
	if GameSettings:
		GameSettings.settings_changed.connect(refresh_volume)
	refresh_volume()

func play_intro() -> void:
	_play_music("intro", INTRO_MUSIC)

func play_game() -> void:
	_play_music("game", GAME_MUSIC)

func _play_music(music_name: String, stream: AudioStream) -> void:
	if current_music == music_name and player.playing:
		refresh_volume()
		return

	current_music = music_name
	player.stop()
	player.stream = stream
	refresh_volume()
	player.play()

func refresh_volume() -> void:
	if player and GameSettings:
		player.volume_db = GameSettings.get_music_db()

func _on_music_finished() -> void:
	if player and player.stream:
		player.play()
