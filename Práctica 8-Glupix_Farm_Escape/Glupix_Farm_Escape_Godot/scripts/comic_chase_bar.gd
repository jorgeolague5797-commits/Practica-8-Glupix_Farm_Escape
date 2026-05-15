extends Control

@export_range(0.0, 100.0, 0.1) var progress: float = 0.0:
	set(value):
		progress = clamp(value, 0.0, 100.0)
		queue_redraw()

var t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(420, 54)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	var border: StyleBoxFlat = StyleBoxFlat.new()
	border.bg_color = Color("#171b28")
	border.border_color = Color("#7f8aa5")
	border.border_width_left = 2
	border.border_width_top = 2
	border.border_width_right = 2
	border.border_width_bottom = 2
	border.corner_radius_top_left = 12
	border.corner_radius_top_right = 12
	border.corner_radius_bottom_left = 12
	border.corner_radius_bottom_right = 12
	draw_style_box(border, outer)

	var pad: float = 8.0
	var track: Rect2 = Rect2(Vector2(pad, 15), Vector2(size.x - pad * 2.0, 24))
	var track_bg: StyleBoxFlat = StyleBoxFlat.new()
	track_bg.bg_color = Color("#2a3148")
	track_bg.corner_radius_top_left = 10
	track_bg.corner_radius_top_right = 10
	track_bg.corner_radius_bottom_left = 10
	track_bg.corner_radius_bottom_right = 10
	draw_style_box(track_bg, track)

	var fill_w: float = track.size.x * (progress / 100.0)
	var fill: Rect2 = Rect2(track.position, Vector2(fill_w, track.size.y))
	var fill_box: StyleBoxFlat = StyleBoxFlat.new()
	fill_box.bg_color = Color("#86e35f")
	fill_box.corner_radius_top_left = 10
	fill_box.corner_radius_top_right = 10
	fill_box.corner_radius_bottom_left = 10
	fill_box.corner_radius_bottom_right = 10
	draw_style_box(fill_box, fill)

	# Línea de suelo / césped.
	draw_line(Vector2(track.position.x, track.position.y + track.size.y + 6), Vector2(track.end.x, track.position.y + track.size.y + 6), Color("#5bc24e"), 3.0)
	for i in range(0, int(track.size.x), 18):
		var gx: float = track.position.x + float(i)
		draw_line(Vector2(gx, track.position.y + track.size.y + 7), Vector2(gx + 6, track.position.y + track.size.y + 2), Color("#97f277"), 2.0)

	# Estrellas decorativas.
	for i in range(5):
		var sx: float = 20.0 + float(i) * ((size.x - 40.0) / 4.0)
		var sy: float = 8.0 + sin(t * 1.7 + float(i)) * 1.5
		draw_circle(Vector2(sx, sy), 1.8 + float(i % 2), Color("#ffd54a"))

	var alien_x: float = track.position.x + track.size.x * (progress / 100.0)
	var cow_progress: float = max(progress - 16.0, 0.0)
	var cow_x: float = track.position.x + track.size.x * (cow_progress / 100.0)
	var bob_alien: float = sin(t * 6.0) * 1.5
	var bob_cow: float = sin(t * 7.3 + 0.8) * 1.5

	_draw_cow(Vector2(cow_x, track.position.y + track.size.y * 0.5 + bob_cow))
	_draw_alien(Vector2(alien_x, track.position.y + track.size.y * 0.5 + bob_alien))

	# Meta.
	var flag_x: float = track.end.x - 12.0
	draw_line(Vector2(flag_x, track.position.y - 6), Vector2(flag_x, track.end.y + 8), Color("#f0f0f0"), 2.0)
	draw_rect(Rect2(Vector2(flag_x, track.position.y - 6), Vector2(10, 8)), Color("#ffcf33"))

func _draw_alien(center: Vector2) -> void:
	var x: float = center.x
	var y: float = center.y

	draw_circle(Vector2(x, y + 16), 10, Color(0, 0, 0, 0.18))
	draw_rect(Rect2(Vector2(x - 8, y - 10), Vector2(16, 16)), Color("#90df4f"))
	draw_rect(Rect2(Vector2(x - 3, y - 5), Vector2(6, 6)), Color("#f5f5f5"))
	draw_rect(Rect2(Vector2(x - 1.5, y - 3.5), Vector2(3, 3)), Color("#111111"))
	draw_rect(Rect2(Vector2(x - 4, y + 2), Vector2(8, 3)), Color("#7e133b"))

	draw_rect(Rect2(Vector2(x - 6, y - 16), Vector2(2, 6)), Color("#90df4f"))
	draw_rect(Rect2(Vector2(x + 4, y - 16), Vector2(2, 6)), Color("#90df4f"))
	draw_rect(Rect2(Vector2(x - 7, y - 19), Vector2(4, 4)), Color("#9d54ea"))
	draw_rect(Rect2(Vector2(x + 3, y - 19), Vector2(4, 4)), Color("#9d54ea"))

	draw_rect(Rect2(Vector2(x - 12, y - 4), Vector2(4, 10)), Color("#90df4f"))
	draw_rect(Rect2(Vector2(x + 8, y - 4), Vector2(4, 10)), Color("#90df4f"))

	draw_rect(Rect2(Vector2(x - 7, y + 6), Vector2(4, 6)), Color("#9d54ea"))
	draw_rect(Rect2(Vector2(x + 3, y + 6), Vector2(4, 6)), Color("#9d54ea"))

func _draw_cow(center: Vector2) -> void:
	var x: float = center.x
	var y: float = center.y

	draw_circle(Vector2(x, y + 16), 11, Color(0, 0, 0, 0.18))
	draw_rect(Rect2(Vector2(x - 10, y - 8), Vector2(18, 14)), Color("#f2f2f2"))
	draw_rect(Rect2(Vector2(x + 5, y - 5), Vector2(10, 10)), Color("#f2f2f2"))
	draw_rect(Rect2(Vector2(x + 7, y - 1), Vector2(8, 5)), Color("#f4a4b7"))

	draw_rect(Rect2(Vector2(x - 8, y - 5), Vector2(5, 5)), Color("#222222"))
	draw_rect(Rect2(Vector2(x + 0, y + 0), Vector2(4, 4)), Color("#222222"))

	draw_rect(Rect2(Vector2(x - 8, y + 6), Vector2(3, 7)), Color("#222222"))
	draw_rect(Rect2(Vector2(x - 2, y + 6), Vector2(3, 7)), Color("#222222"))
	draw_rect(Rect2(Vector2(x + 4, y + 6), Vector2(3, 7)), Color("#222222"))
	draw_rect(Rect2(Vector2(x + 10, y + 6), Vector2(3, 7)), Color("#222222"))

	draw_rect(Rect2(Vector2(x + 7, y - 9), Vector2(2, 4)), Color("#8d5a32"))
	draw_rect(Rect2(Vector2(x + 12, y - 9), Vector2(2, 4)), Color("#8d5a32"))
