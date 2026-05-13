extends Node
class_name AudioManager

const RADIO_STATIC_PROFILES := {
	"Clear": "clean_link",
	"Reduced": "warm_hiss",
	"Faint": "muffled_trace",
	"Lost": "dead_air"
}
const CONNECTION_FADE_SPEED := 1.35
const BLEED_FADE_SPEED := 1.05
const VALUE_EPSILON := 0.002

var last_event: String = ""
var current_ambience: String = ""
var current_radio_profile: String = ""
var recent_one_shots: Array[String] = []
var current_connection_strength: float = 1.0
var current_voice_volume: float = 1.0
var current_environment_bleed: float = 0.30
var current_signal_state: String = "Clear"
var current_signal_flavor: String = "Same room. Every word lands clearly."
var current_relationship: String = "same_room"

var target_connection_strength: float = 1.0
var target_voice_volume: float = 1.0
var target_environment_bleed: float = 0.30
var target_signal_state: String = "Clear"
var target_signal_flavor: String = "Same room. Every word lands clearly."
var target_relationship: String = "same_room"


func _ready() -> void:
	EventBus.audio_requested.connect(_on_audio_requested)
	EventBus.radio_target_changed.connect(_on_radio_target_changed)
	EventBus.state_changed.connect(_on_state_changed)
	_sync_ambience()
	_sync_connection_target(_build_target_profile(), true)
	set_process(true)


func _on_audio_requested(event_name: String) -> void:
	last_event = event_name
	_register_one_shot(event_name)
	print("[AudioManager] oneshot:", event_name)
	_emit_environment_bleed(event_name)


func _on_radio_target_changed(profile: Dictionary) -> void:
	_sync_connection_target(profile, false)


func _on_state_changed() -> void:
	_sync_ambience()


func _process(delta: float) -> void:
	var changed: bool = false
	changed = _move_audio_value("current_connection_strength", target_connection_strength, CONNECTION_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_voice_volume", target_voice_volume, CONNECTION_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_environment_bleed", target_environment_bleed, BLEED_FADE_SPEED * delta) or changed

	var next_state: String = VoiceProximityManager.state_from_strength(current_connection_strength)
	if next_state != current_signal_state:
		_handle_signal_transition(current_signal_state, next_state)
		current_signal_state = next_state
		_sync_radio_profile(current_signal_state)
		EventBus.emit_radio_status_changed(current_signal_state)
		changed = true

	if changed:
		_refresh_current_flavor()
		_emit_connection_snapshot()


func _sync_ambience() -> void:
	var target: String = _resolve_ambience_profile()
	if target == current_ambience:
		return

	if current_ambience == "":
		print("[AudioManager] ambience start:", target)
	else:
		print("[AudioManager] ambience transition:", current_ambience, "->", target)

	current_ambience = target


func _sync_radio_profile(status: String) -> void:
	var target: String = RADIO_STATIC_PROFILES[status] if RADIO_STATIC_PROFILES.has(status) else "dead_air"
	if target == current_radio_profile:
		return

	if current_radio_profile == "":
		print("[AudioManager] radio profile start:", target)
	else:
		print("[AudioManager] radio profile transition:", current_radio_profile, "->", target)

	current_radio_profile = target


func _sync_connection_target(profile: Dictionary, instant: bool) -> void:
	var previous_target_state: String = target_signal_state
	var previous_target_flavor: String = target_signal_flavor
	var previous_target_relationship: String = target_relationship
	target_connection_strength = _profile_float(profile, "strength", 0.0)
	target_voice_volume = _profile_float(profile, "voice_volume", target_connection_strength)
	target_environment_bleed = _profile_float(profile, "environment_bleed", 0.0)
	target_signal_state = _profile_string(profile, "state", "Lost")
	target_signal_flavor = _profile_string(profile, "flavor", "")
	target_relationship = _profile_string(profile, "relationship", "")

	if not instant:
		var target_only_changed := previous_target_state != target_signal_state \
			or previous_target_flavor != target_signal_flavor \
			or previous_target_relationship != target_relationship
		if target_only_changed \
			and absf(current_connection_strength - target_connection_strength) <= VALUE_EPSILON \
			and absf(current_voice_volume - target_voice_volume) <= VALUE_EPSILON \
			and absf(current_environment_bleed - target_environment_bleed) <= VALUE_EPSILON:
			current_signal_state = target_signal_state
			current_signal_flavor = target_signal_flavor
			current_relationship = target_relationship
			_sync_radio_profile(current_signal_state)
			EventBus.emit_radio_status_changed(current_signal_state)
			_emit_connection_snapshot()
		return

	current_connection_strength = target_connection_strength
	current_voice_volume = target_voice_volume
	current_environment_bleed = target_environment_bleed
	current_signal_state = target_signal_state
	current_signal_flavor = target_signal_flavor
	current_relationship = target_relationship

	_sync_radio_profile(current_signal_state)
	EventBus.emit_radio_status_changed(current_signal_state)
	_emit_connection_snapshot()


func _handle_signal_transition(previous_status: String, next_status: String) -> void:
	if next_status == "Lost":
		EventBus.emit_event_logged("Signal lost.", "signal")
		print("[AudioManager] signal cue: loss")
		return

	if previous_status == "Lost":
		EventBus.emit_event_logged("Signal returning...", "signal")
		print("[AudioManager] signal cue: return")
		return

	if next_status == "Reduced" and previous_status == "Clear":
		EventBus.emit_event_logged("The line weakens.", "signal")
		return

	if next_status == "Faint" and previous_status != "Lost":
		EventBus.emit_event_logged("Only a faint trace remains.", "signal")
		return

	if next_status == "Clear" and previous_status != "Clear":
		EventBus.emit_event_logged("Connection restored.", "hope")


func _emit_connection_snapshot() -> void:
	EventBus.emit_radio_connection_changed(get_connection_snapshot())


func get_connection_snapshot() -> Dictionary:
	return {
		"state": current_signal_state,
		"strength": current_connection_strength,
		"voice_volume": current_voice_volume,
		"environment_bleed": current_environment_bleed,
		"relationship": current_relationship,
		"flavor": current_signal_flavor
	}


func _build_target_profile() -> Dictionary:
	return VoiceProximityManager.calculate_profile(
		GameState.player_1_location,
		GameState.player_2_location,
		GameState.floor_collapsed
	)


func _refresh_current_flavor() -> void:
	current_relationship = target_relationship
	if current_signal_state == target_signal_state:
		current_signal_flavor = target_signal_flavor
		return

	match current_signal_state:
		"Clear":
			current_signal_flavor = "The line feels steady again."
		"Reduced":
			current_signal_flavor = "The channel softens with distance."
		"Faint":
			current_signal_flavor = "A muffled trace still hangs on."
		_:
			current_signal_flavor = "Static takes the space between them."


func _move_audio_value(property_name: String, target_value: float, step: float) -> bool:
	var current_value := float(get(property_name))
	var next_value := move_toward(current_value, target_value, step)
	if absf(next_value - current_value) <= VALUE_EPSILON:
		if absf(current_value - target_value) <= VALUE_EPSILON:
			return false

		set(property_name, target_value)
		return true

	set(property_name, next_value)
	return true


func _emit_environment_bleed(event_name: String) -> void:
	if current_environment_bleed <= 0.01:
		return

	print(
		"[AudioManager] bleed-through:",
		event_name,
		"level=",
		int(round(current_environment_bleed * 100.0)),
		"relationship=",
		current_relationship
	)


func _resolve_ambience_profile() -> String:
	var locations: Array[String] = [
		GameState.player_1_location,
		GameState.player_2_location
	]

	if "Shed" in locations:
		return "hollow_shed"

	if "WoodsEdge" in locations:
		return "night_wind"

	if "Outside" in locations and GameState.player_1_location == GameState.player_2_location:
		return "outside_reconverged"

	if GameState.floor_collapsed and "Bedroom" in locations:
		return "bedroom_isolation"

	if GameState.floor_collapsed and "Downstairs" in locations:
		return "below_house_dread"

	if GameState.floor_collapsed and GameState.player_1_location != GameState.player_2_location:
		return "strained_silence"

	if "Outside" in locations:
		return "yard_hush"

	if "UpstairsHallway" in locations:
		return "hallway_strain"

	return "upstairs_hum"


func _register_one_shot(event_name: String) -> void:
	recent_one_shots.append(event_name)
	if recent_one_shots.size() > 8:
		recent_one_shots.pop_front()


func _profile_float(profile: Dictionary, key: String, default_value: float) -> float:
	if not profile.has(key):
		return default_value

	return float(profile[key])


func _profile_string(profile: Dictionary, key: String, default_value: String) -> String:
	if not profile.has(key):
		return default_value

	return str(profile[key])
