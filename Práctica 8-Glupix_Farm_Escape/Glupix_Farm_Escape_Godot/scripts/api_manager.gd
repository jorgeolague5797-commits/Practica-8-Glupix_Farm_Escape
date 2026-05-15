extends Node

signal api_data_received(advice: String, even_length: bool)

const ADVICE_URL: String = "https://api.adviceslip.com/advice"

var http: HTTPRequest
var busy: bool = false

func _ready() -> void:
	http = HTTPRequest.new()
	http.name = "HTTPRequest_AdviceSlip"
	add_child(http)
	http.request_completed.connect(_on_request_completed)

func fetch_advice() -> void:
	if busy or http == null:
		return
	busy = true
	var err: int = http.request(ADVICE_URL)
	if err != OK:
		busy = false
		api_data_received.emit("No se pudo conectar con la API.", false)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var advice: String = "Recupera tus artefactos y mira antes de avanzar."
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("slip"):
			var slip = parsed["slip"]
			if slip is Dictionary and slip.has("advice"):
				advice = str(slip["advice"])
	var even_length: bool = advice.length() % 2 == 0
	api_data_received.emit(advice, even_length)
