extends Node

# Base de datos local SQLite para la práctica.
# Requiere tener instalado y habilitado el plugin godot-sqlite.
# La base se crea en user://game_data.db
#
# Tabla requerida:
# highscores (
#   id INTEGER PRIMARY KEY,
#   player_name TEXT DEFAULT 'Jugador',
#   max_score INTEGER,
#   date TEXT
# )
#
# Además de mostrar el máximo histórico, guarda registros de partidas
# y mantiene los últimos 10 scores más el máximo histórico.

var best_score: int = 0
var best_date: String = ""
var player_name: String = "Jugador"

var db_path: String = "user://game_data.db"
var fallback_path: String = "user://highscores_fallback.cfg"
var sqlite_db = null
var sqlite_ready: bool = false
var fallback_scores: Array = []

func _ready() -> void:
	_open_database()
	load_highscore()

func _open_database() -> void:
	sqlite_ready = false

	if not ClassDB.class_exists("SQLite"):
		push_warning("No se encontró el plugin godot-sqlite. Instálalo desde Asset Library para usar la base de datos SQLite.")
		_load_fallback_scores()
		return

	sqlite_db = ClassDB.instantiate("SQLite")
	if sqlite_db == null:
		push_warning("No se pudo crear una instancia de SQLite.")
		_load_fallback_scores()
		return

	sqlite_db.path = db_path

	var opened = false
	if sqlite_db.has_method("open_db"):
		opened = sqlite_db.call("open_db")
	elif sqlite_db.has_method("open"):
		opened = sqlite_db.call("open")

	if not opened:
		push_warning("No se pudo abrir la base de datos SQLite en: " + db_path)
		_load_fallback_scores()
		return

	sqlite_ready = true

	_query("""
		CREATE TABLE IF NOT EXISTS highscores (
			id INTEGER PRIMARY KEY,
			player_name TEXT DEFAULT 'Jugador',
			max_score INTEGER,
			date TEXT
		);
	""")

func _query(sql: String) -> bool:
	if not sqlite_ready or sqlite_db == null:
		return false
	var result = sqlite_db.call("query", sql)
	if result is bool:
		return result
	return true

func _get_rows(sql: String) -> Array:
	if not _query(sql):
		return []
	var rows = sqlite_db.query_result
	if rows is Array:
		return rows
	return []

func load_highscore() -> int:
	if sqlite_ready:
		var rows: Array = _get_rows("SELECT player_name, max_score, date FROM highscores ORDER BY max_score DESC, id DESC LIMIT 1;")
		if rows.size() > 0:
			var row: Dictionary = rows[0]
			player_name = str(row.get("player_name", "Jugador"))
			best_score = int(row.get("max_score", 0))
			best_date = str(row.get("date", ""))
		else:
			player_name = "Jugador"
			best_score = 0
			best_date = ""
		return best_score

	_load_fallback_scores()
	_calculate_fallback_best()
	return best_score

func update_highscore(current_score: int) -> bool:
	var was_new_best: bool = current_score > best_score
	var date_value: String = Time.get_datetime_string_from_system(false, true)
	player_name = "Jugador"

	if sqlite_ready:
		var sql: String = """
			INSERT INTO highscores (player_name, max_score, date)
			VALUES ('Jugador', %d, '%s');
		""" % [current_score, _escape_sql(date_value)]
		_query(sql)
		load_highscore()
		_trim_sqlite_scores()
		load_highscore()
		return was_new_best

	_load_fallback_scores()
	fallback_scores.append({
		"player_name": "Jugador",
		"max_score": current_score,
		"date": date_value
	})
	_trim_fallback_scores()
	_save_fallback_scores()
	_calculate_fallback_best()
	return was_new_best

func get_best_score() -> int:
	return best_score

func get_best_date() -> String:
	return best_date

func get_player_name() -> String:
	return player_name

func get_recent_scores() -> Array:
	if sqlite_ready:
		return _get_rows("SELECT id, player_name, max_score, date FROM highscores ORDER BY id DESC LIMIT 10;")

	_load_fallback_scores()
	var result: Array = []
	for i in range(fallback_scores.size() - 1, -1, -1):
		result.append(fallback_scores[i])
		if result.size() >= 10:
			break
	return result

func get_storage_description() -> String:
	if sqlite_ready:
		return "SQLite: " + db_path
	return "SQLite no disponible: instala godot-sqlite"

func _trim_sqlite_scores() -> void:
	var keep_ids: Array[String] = []

	var recent_rows: Array = _get_rows("SELECT id FROM highscores ORDER BY id DESC LIMIT 10;")
	for row in recent_rows:
		keep_ids.append(str(int(row.get("id", 0))))

	var best_rows: Array = _get_rows("SELECT id FROM highscores ORDER BY max_score DESC, id DESC LIMIT 1;")
	if best_rows.size() > 0:
		var best_id: String = str(int(best_rows[0].get("id", 0)))
		if not keep_ids.has(best_id):
			keep_ids.append(best_id)

	if keep_ids.size() == 0:
		return

	_query("DELETE FROM highscores WHERE id NOT IN (%s);" % ",".join(keep_ids))

func _load_fallback_scores() -> void:
	fallback_scores = []
	var cfg := ConfigFile.new()
	if cfg.load(fallback_path) == OK:
		var saved = cfg.get_value("highscores", "scores", [])
		if saved is Array:
			fallback_scores = saved

func _save_fallback_scores() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("highscores", "scores", fallback_scores)
	cfg.save(fallback_path)

func _calculate_fallback_best() -> void:
	best_score = 0
	best_date = ""
	player_name = "Jugador"
	for row in fallback_scores:
		if row is Dictionary:
			var row_score: int = int(row.get("max_score", 0))
			if row_score >= best_score:
				best_score = row_score
				best_date = str(row.get("date", ""))
				player_name = str(row.get("player_name", "Jugador"))

func _trim_fallback_scores() -> void:
	if fallback_scores.size() <= 10:
		return

	var best_row = null
	var best_value: int = -1
	for row in fallback_scores:
		if row is Dictionary:
			var row_score: int = int(row.get("max_score", 0))
			if row_score > best_value:
				best_value = row_score
				best_row = row

	var last_ten: Array = []
	var start_index: int = max(0, fallback_scores.size() - 10)
	for i in range(start_index, fallback_scores.size()):
		last_ten.append(fallback_scores[i])

	if best_row != null and not last_ten.has(best_row):
		last_ten.insert(0, best_row)

	fallback_scores = last_ten

func _escape_sql(value: String) -> String:
	return value.replace("'", "''")
