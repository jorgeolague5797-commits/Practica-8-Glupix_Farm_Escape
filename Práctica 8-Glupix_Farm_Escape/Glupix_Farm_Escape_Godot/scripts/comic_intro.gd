extends Control

const LEVEL_SCENE: String = "res://scenes/Level.tscn"
const COMIC_TEXTURE_PATH: String = "res://assets/intro_comic.png"
const CHASE_BAR_SCRIPT = preload("res://scripts/comic_chase_bar.gd")

var comic_texture: Texture2D

var root_bg: ColorRect
var top_bar: PanelContainer
var center_panel: PanelContainer
var bottom_bar: PanelContainer

var frame_margin: MarginContainer
var scroll: ScrollContainer
var content: Control
var comic_image: TextureRect

var title_label: Label
var subtitle_label: Label
var progress_label: Label
var hint_label: Label
var chase_bar: Control

var btn_inicio: Button
var btn_bajar: Button
var btn_jugar: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MusicManager.play_intro()

	comic_texture = load(COMIC_TEXTURE_PATH)

	_build_ui()
	_apply_comic_fonts()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_refresh_layout()
	scroll.scroll_vertical = 0
	_connect_scrollbar()
	_update_progress()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		call_deferred("_refresh_layout")
		call_deferred("_update_progress")

func _process(_delta: float) -> void:
	if btn_jugar:
		if btn_jugar.disabled:
			btn_jugar.scale = Vector2.ONE
		else:
			var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.025
			btn_jugar.scale = Vector2.ONE * pulse

func _build_ui() -> void:
	root_bg = ColorRect.new()
	root_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_bg.color = Color("#05070b")
	add_child(root_bg)

	# -------- Barra superior --------
	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _make_style(Color("#0b1020"), Color("#bf63ff"), 3, 22))
	add_child(top_bar)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 18)
	top_margin.add_theme_constant_override("margin_right", 18)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.add_theme_constant_override("margin_bottom", 12)
	top_bar.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_vbox)

	var row_top := HBoxContainer.new()
	row_top.add_theme_constant_override("separation", 14)
	top_vbox.add_child(row_top)

	title_label = Label.new()
	title_label.text = "CÓMIC INTRODUCTORIO"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("#d8ff6b"))
	title_label.add_theme_color_override("font_outline_color", Color("#0d0d0d"))
	title_label.add_theme_constant_override("outline_size", 4)
	row_top.add_child(title_label)

	progress_label = Label.new()
	progress_label.text = "0%"
	progress_label.custom_minimum_size = Vector2(96, 42)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 24)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	row_top.add_child(progress_label)

	var buttons_box := HBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 12)
	row_top.add_child(buttons_box)

	btn_inicio = _make_nav_button("↑ INICIO", Color("#3957c7"), Color("#8eb2ff"))
	btn_inicio.pressed.connect(_on_inicio_pressed)
	buttons_box.add_child(btn_inicio)

	btn_bajar = _make_nav_button("BAJAR ↓", Color("#0b8191"), Color("#60efff"))
	btn_bajar.pressed.connect(_on_bajar_pressed)
	buttons_box.add_child(btn_bajar)

	btn_jugar = _make_nav_button("JUGAR ➜", Color("#4c601c"), Color("#d8ff6b"))
	btn_jugar.disabled = true
	btn_jugar.pressed.connect(_on_jugar_pressed)
	buttons_box.add_child(btn_jugar)

	var row_bottom := HBoxContainer.new()
	row_bottom.add_theme_constant_override("separation", 16)
	top_vbox.add_child(row_bottom)

	subtitle_label = Label.new()
	subtitle_label.text = "Desliza el cómic y ayuda a Glupix a escapar."
	subtitle_label.custom_minimum_size = Vector2(380, 36)
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color("#f0f4ff"))
	row_bottom.add_child(subtitle_label)

	chase_bar = CHASE_BAR_SCRIPT.new()
	chase_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_bottom.add_child(chase_bar)

	# -------- Panel central --------
	center_panel = PanelContainer.new()
	center_panel.add_theme_stylebox_override("panel", _make_style(Color("#070912"), Color("#b350ff"), 4, 24))
	add_child(center_panel)

	frame_margin = MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 22)
	frame_margin.add_theme_constant_override("margin_right", 22)
	frame_margin.add_theme_constant_override("margin_top", 22)
	frame_margin.add_theme_constant_override("margin_bottom", 22)
	center_panel.add_child(frame_margin)

	scroll = ScrollContainer.new()
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_margin.add_child(scroll)

	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)

	comic_image = TextureRect.new()
	comic_image.texture = comic_texture
	comic_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	comic_image.stretch_mode = TextureRect.STRETCH_SCALE
	comic_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(comic_image)

	# Barra inferior eliminada a petición del usuario.
	bottom_bar = null
	hint_label = null

func _refresh_layout() -> void:
	_update_fixed_layout()
	_layout_comic_image()

func _update_fixed_layout() -> void:
	var w: float = max(size.x, 1100.0)
	var h: float = max(size.y, 700.0)

	var outer_margin: float = clamp(w * 0.018, 24.0, 36.0)
	var inner_margin: float = outer_margin + 18.0

	var top_y: float = 24.0
	var top_h: float = 168.0

	# Separación real y pareja
	var gap_above_center: float = 28.0
	var gap_below_center: float = 28.0

	var bottom_margin_only: float = 24.0

	var center_y: float = top_y + top_h + gap_above_center
	var center_bottom: float = h - bottom_margin_only
	var center_h: float = center_bottom - center_y

	top_bar.position = Vector2(outer_margin, top_y)
	top_bar.size = Vector2(w - outer_margin * 2.0, top_h)

	center_panel.position = Vector2(inner_margin, center_y)
	center_panel.size = Vector2(w - inner_margin * 2.0, center_h)

	var button_width: float = clamp(w * 0.09, 116.0, 150.0)
	btn_inicio.custom_minimum_size = Vector2(button_width, 48)
	btn_bajar.custom_minimum_size = Vector2(button_width, 48)
	btn_jugar.custom_minimum_size = Vector2(button_width, 48)

	subtitle_label.custom_minimum_size = Vector2(clamp(w * 0.21, 280.0, 420.0), 36)

func _layout_comic_image() -> void:
	if comic_texture == null:
		return

	var tex_size: Vector2 = comic_texture.get_size()

	# Usar el tamaño real del panel central y no el valor inestable del scroll en el primer frame.
	var available_w: float = max(320.0, center_panel.size.x - 44.0 - 44.0 - 14.0)
	var top_bottom_padding: float = 20.0
	var side_padding: float = clamp(available_w * 0.02, 10.0, 18.0)

	var target_width: float = available_w - side_padding * 2.0
	var scale_value: float = target_width / tex_size.x
	var target_size: Vector2 = tex_size * scale_value

	content.custom_minimum_size = Vector2(available_w, target_size.y + top_bottom_padding * 2.0)
	content.size = content.custom_minimum_size

	comic_image.size = target_size
	comic_image.position = Vector2((available_w - target_size.x) * 0.5, top_bottom_padding)

func _connect_scrollbar() -> void:
	var bar := scroll.get_v_scroll_bar()
	if bar and not bar.value_changed.is_connected(_on_scroll_value_changed):
		bar.value_changed.connect(_on_scroll_value_changed)

func _on_scroll_value_changed(_value: float) -> void:
	_update_progress()

func _update_progress() -> void:
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return

	var max_scroll: float = max(1.0, bar.max_value - bar.page)
	var current: float = clamp(float(scroll.scroll_vertical), 0.0, max_scroll)
	var pct: float = clamp((current / max_scroll) * 100.0, 0.0, 100.0)

	progress_label.text = str(int(round(pct))) + "%"
	if chase_bar:
		chase_bar.set("progress", pct)

	if pct >= 98.0:
		btn_jugar.disabled = false
		if hint_label != null:
			hint_label.text = "¡Lo lograste! Terminaste el cómic. Presiona JUGAR ➜ para comenzar la aventura."
	else:
		btn_jugar.disabled = true
		if hint_label != null:
			hint_label.text = "Usa la rueda del mouse o BAJAR ↓ para leer el cómic completo. JUGAR se desbloquea al final."

func _on_inicio_pressed() -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scroll, "scroll_vertical", 0, 0.35)
	await tween.finished
	_update_progress()

func _on_bajar_pressed() -> void:
	var bar := scroll.get_v_scroll_bar()
	var max_scroll: int = int(max(0.0, bar.max_value - bar.page))
	var next_value: int = min(max_scroll, scroll.scroll_vertical + int(max(260.0, center_panel.size.y * 0.55)))

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scroll, "scroll_vertical", next_value, 0.35)
	await tween.finished
	_update_progress()

func _on_jugar_pressed() -> void:
	if btn_jugar.disabled:
		return
	get_tree().change_scene_to_file(LEVEL_SCENE)

func _make_nav_button(text_value: String, base_color: Color, accent_color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_focus_color", Color("#ffffff"))
	button.add_theme_stylebox_override("normal", _make_style(base_color.darkened(0.35), accent_color.darkened(0.15), 2, 15))
	button.add_theme_stylebox_override("hover", _make_style(base_color, accent_color, 3, 15))
	button.add_theme_stylebox_override("pressed", _make_style(base_color.darkened(0.45), Color("#ffffff"), 3, 15))
	button.add_theme_stylebox_override("disabled", _make_style(Color("#181a22"), Color("#3b4257"), 2, 15))
	return button

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

func _load_custom_font(paths: Array[String]) -> Font:
	for font_path in paths:
		if ResourceLoader.exists(font_path):
			var font_res = load(font_path)
			if font_res is Font:
				return font_res
	return null

func _font_title() -> Font:
	return _load_custom_font([
		"res://assets/fonts/PixelStorm.ttf",
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
		"res://assets/fonts/boldpixels_kit/BoldPixels.ttf",
		"res://assets/fonts/boldpixels_kit/BoldPixels.otf",
		"res://assets/fonts/PixelStorm.ttf",
	])

func _set_font(control: Control, font: Font) -> void:
	if font != null:
		control.add_theme_font_override("font", font)

func _apply_comic_fonts() -> void:
	var title_font: Font = _font_title()
	var body_font: Font = _font_body()
	var pixel_font: Font = _font_pixel()

	_set_font(title_label, title_font)
	_set_font(subtitle_label, body_font)
	_set_font(progress_label, pixel_font)
	if hint_label != null:
		_set_font(hint_label, body_font)
	_set_font(btn_inicio, pixel_font)
	_set_font(btn_bajar, pixel_font)
	_set_font(btn_jugar, title_font)
