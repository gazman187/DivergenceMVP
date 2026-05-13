extends Node
class_name AudioManager

const RADIO_STATIC_PROFILES := {
	"Clear": "clean_link",
	"Weak": "faint_hiss",
	"Broken": "stutter_static",
	"Lost": "dead_air"
}

var last_event: String = ""
var current_ambience: String = ""
var current_radio_profile: String = ""
var recent_one_shots: Array[String] = []


func _ready() -> void:
	EventBus.audio_requested.connect(_on_audio_requested)
	EventBus.radio_status_changed.connect(_on_radio_status_changed)
	EventBus.state_changed.connect(_on_state_changed)
	_sync_ambience()
	_sync_radio_profile("Clear")


func _on_audio_requested(event_name: String) -> void:
	last_event = event_name
	_register_one_shot(event_name)
	print("[AudioManager] oneshot:", event_name)


func _on_radio_status_changed(status: String) -> void:
	_sync_radio_profile(status)


func _on_state_changed() -> void:
	_sync_ambience()


func _sync_ambience() -> void:
	var target := _resolve_ambience_profile()
	if target == current_ambience:
		return

	if current_ambience == "":
		print("[AudioManager] ambience start:", target)
	else:
		print("[AudioManager] ambience transition:", current_ambience, "->", target)

	current_ambience = target


func _sync_radio_profile(status: String) -> void:
	var target := RADIO_STATIC_PROFILES.get(status, "dead_air")
	if target == current_radio_profile:
		return

	if current_radio_profile == "":
		print("[AudioManager] radio profile start:", target)
	else:
		print("[AudioManager] radio profile transition:", current_radio_profile, "->", target)

	current_radio_profile = target


func _resolve_ambience_profile() -> String:
	var locations := [
		GameState.player_1_location,
		GameState.player_2_location
	]

	if "Shed" in locations:
		return "hollow_shed"

	if "WoodsEdge" in locations:
		return "night_wind"

	if "Outside" in locations and GameState.player_1_location == GameState.player_2_location:
		return "outside_reconverged"

	if GameState.floor_collapsed and GameState.player_1_location != GameState.player_2_location:
		return "strained_silence"

	if "Outside" in locations:
		return "yard_hush"

	return "upstairs_hum"


func _register_one_shot(event_name: String) -> void:
	recent_one_shots.append(event_name)
	if recent_one_shots.size() > 8:
		recent_one_shots.pop_front()
