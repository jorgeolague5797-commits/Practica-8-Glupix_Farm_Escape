extends Control

@onready var start_button: Button = $CanvasLayer/CenterBox/Panel/VBox/DespegarButton
@onready var title_label: Label = $CanvasLayer/CenterBox/Panel/VBox/MarginTop/Title
@onready var subtitle_label: Label = $CanvasLayer/CenterBox/Panel/VBox/Subtitle
@onready var story_label: Label = $CanvasLayer/CenterBox/Panel/VBox/Story
@onready var hint_label: Label = $CanvasLayer/CenterBox/Panel/VBox/Hint

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicManager.play_intro()
	_apply_title_fonts()
	start_button.grab_focus()

func _process(delta: float) -> void:
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.03
	start_button.scale = Vector2.ONE * pulse

func _apply_title_fonts() -> void:
	var title_font: Font = _font_title()
	var body_font: Font = _font_body()
	var pixel_font: Font = _font_pixel()

	_set_font(title_label, title_font)
	_set_font(start_button, title_font)
	_set_font(subtitle_label, pixel_font)
	_set_font(story_label, body_font)
	_set_font(hint_label, body_font)
	hint_label.visible = hint_label.text.strip_edges() != ""


func _on_despegar_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ComicIntro.tscn")


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
	])

func _font_body() -> Font:
	return _load_custom_font([
		"res://assets/fonts/Thin Sans.ttf",
		"res://assets/fonts/PixelStorm.ttf",
	])

func _font_pixel() -> Font:
	return _load_custom_font([
		"res://assets/fonts/BoldPixels.otf",
		"res://assets/fonts/boldpixels.ttf",
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
