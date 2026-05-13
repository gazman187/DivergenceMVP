extends Node
class_name AudioManager

const RADIO_STATIC_PROFILES := {
	"Clear": "clean_link",
	"Reduced": "warm_hiss",
	"Faint": "muffled_trace",
	"Lost": "dead_air"
}

const CONNECTION_FADE_SPEED: float = 1.35
const BLEED_FADE_SPEED: float = 1.05
const ATMOSPHERE_FADE_SPEED: float = 0.85
const VALUE_EPSILON: float = 0.002

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
var current_occlusion: float = 0.10
var current_room_resonance: float = 0.34
var current_silence_pressure: float = 0.20
var current_relief: float = 0.14
var current_openness: float = 0.26
var current_instability: float = 0.22

var target_connection_strength: float = 1.0
var target_voice_volume: float = 1.0
var target_environment_bleed: float = 0.30
var target_signal_state: String = "Clear"
var target_signal_flavor: String = "Same room. Every word lands clearly."
var target_relationship: String = "same_room"
var target_occlusion: float = 0.10
var target_room_resonance: float = 0.34
var target_silence_pressure: float = 0.20
var target_relief: float = 0.14
var target_openness: float = 0.26
var target_instability: float = 0.22

var _ambient_cue_timer: float = 0.0
var _structural_cue_timer: float = 0.0
var _presence_cue_timer: float = 0.0
var _silence_cooldown_timer: float = 0.0


func _ready() -> void:
	EventBus.audio_requested.connect(_on_audio_requested)
	EventBus.radio_target_changed.connect(_on_radio_target_changed)
	EventBus.state_changed.connect(_on_state_changed)
	_sync_ambience(true)
	_sync_connection_target(_build_target_profile(), true)
	_reset_environment_timers(true)
	set_process(true)


func _on_audio_requested(event_name: String) -> void:
	last_event = event_name
	_register_one_shot(event_name)
	print("[AudioManager] oneshot:", event_name)
	_emit_environment_bleed(event_name)


func _on_radio_target_changed(profile: Dictionary) -> void:
	_sync_connection_target(profile, false)


func _on_state_changed() -> void:
	_sync_ambience(false)


func _process(delta: float) -> void:
	var changed: bool = false
	changed = _move_audio_value("current_connection_strength", target_connection_strength, CONNECTION_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_voice_volume", target_voice_volume, CONNECTION_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_environment_bleed", target_environment_bleed, BLEED_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_occlusion", target_occlusion, ATMOSPHERE_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_room_resonance", target_room_resonance, ATMOSPHERE_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_silence_pressure", target_silence_pressure, ATMOSPHERE_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_relief", target_relief, ATMOSPHERE_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_openness", target_openness, ATMOSPHERE_FADE_SPEED * delta) or changed
	changed = _move_audio_value("current_instability", target_instability, ATMOSPHERE_FADE_SPEED * delta) or changed

	var next_state: String = VoiceProximityManager.state_from_strength(current_connection_strength)
	if next_state != current_signal_state:
		_handle_signal_transition(current_signal_state, next_state)
		current_signal_state = next_state
		_sync_radio_profile(current_signal_state)
		EventBus.emit_radio_status_changed(current_signal_state)
		changed = true

	_advance_environment(delta)

	if changed:
		_refresh_current_flavor()
		_emit_connection_snapshot()


func _sync_ambience(force_initial: bool) -> void:
	var target_key: String = _resolve_ambience_profile()
	var previous_key: String = current_ambience
	if target_key == current_ambience and not force_initial:
		return

	target_openness = _ambience_openness(target_key)
	target_instability = _ambience_instability(target_key)
	target_silence_pressure = maxf(target_silence_pressure, _ambience_silence(target_key))
	current_ambience = target_key
	_reset_environment_timers(true)

	if previous_key == "" or force_initial:
		print("[AudioManager] ambience start:", target_key)
	else:
		print("[AudioManager] ambience transition:", previous_key, "->", target_key)

	var ambience_note: String = _ambience_transition_text(target_key, previous_key)
	if ambience_note != "":
		EventBus.emit_event_logged(ambience_note, "ambience")

	_refresh_current_flavor()
	_emit_connection_snapshot()


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
	target_occlusion = _profile_float(profile, "occlusion", 1.0)
	target_room_resonance = _profile_float(profile, "room_resonance", 0.26)
	target_silence_pressure = _profile_float(profile, "silence_pressure", 0.50)
	target_relief = _profile_float(profile, "relief", 0.0)

	if not instant:
		var target_only_changed: bool = previous_target_state != target_signal_state \
			or previous_target_flavor != target_signal_flavor \
			or previous_target_relationship != target_relationship
		if target_only_changed \
			and absf(current_connection_strength - target_connection_strength) <= VALUE_EPSILON \
			and absf(current_voice_volume - target_voice_volume) <= VALUE_EPSILON \
			and absf(current_environment_bleed - target_environment_bleed) <= VALUE_EPSILON:
			current_signal_state = target_signal_state
			current_signal_flavor = target_signal_flavor
			current_relationship = target_relationship
			current_occlusion = target_occlusion
			current_room_resonance = target_room_resonance
			current_silence_pressure = target_silence_pressure
			current_relief = target_relief
			_sync_radio_profile(current_signal_state)
			EventBus.emit_radio_status_changed(current_signal_state)
			_refresh_current_flavor()
			_emit_connection_snapshot()
		return

	current_connection_strength = target_connection_strength
	current_voice_volume = target_voice_volume
	current_environment_bleed = target_environment_bleed
	current_signal_state = target_signal_state
	current_signal_flavor = target_signal_flavor
	current_relationship = target_relationship
	current_occlusion = target_occlusion
	current_room_resonance = target_room_resonance
	current_silence_pressure = target_silence_pressure
	current_relief = target_relief

	_sync_radio_profile(current_signal_state)
	EventBus.emit_radio_status_changed(current_signal_state)
	_refresh_current_flavor()
	_emit_connection_snapshot()


func _handle_signal_transition(previous_status: String, next_status: String) -> void:
	if next_status == "Lost":
		EventBus.emit_event_logged("The line drops out. The other presence becomes absence.", "signal")
		print("[AudioManager] signal cue: loss")
		return

	if previous_status == "Lost":
		EventBus.emit_event_logged("A human trace slips back into the static.", "hope")
		print("[AudioManager] signal cue: return")
		return

	if next_status == "Reduced" and previous_status == "Clear":
		EventBus.emit_event_logged("Distance enters the line.", "signal")
		return

	if next_status == "Faint" and previous_status != "Lost":
		EventBus.emit_event_logged("Only a thin voice-trace survives.", "signal")
		return

	if next_status == "Clear" and previous_status != "Clear":
		EventBus.emit_event_logged("Their voices reach each other cleanly again.", "hope")


func _emit_connection_snapshot() -> void:
	EventBus.emit_radio_connection_changed(get_connection_snapshot())


func get_connection_snapshot() -> Dictionary:
	return {
		"state": current_signal_state,
		"strength": current_connection_strength,
		"voice_volume": current_voice_volume,
		"environment_bleed": current_environment_bleed,
		"relationship": current_relationship,
		"flavor": current_signal_flavor,
		"occlusion": current_occlusion,
		"room_resonance": current_room_resonance,
		"silence_pressure": current_silence_pressure,
		"relief": current_relief,
		"ambience": current_ambience,
		"openness": current_openness,
		"instability": current_instability
	}


func _build_target_profile() -> Dictionary:
	return VoiceProximityManager.calculate_profile(
		GameState.player_1_location,
		GameState.player_2_location,
		GameState.floor_collapsed
	)


func _refresh_current_flavor() -> void:
	current_relationship = target_relationship

	var base_flavor: String = target_signal_flavor
	if current_signal_state != target_signal_state:
		match current_signal_state:
			"Clear":
				base_flavor = "The line feels steady again."
			"Reduced":
				base_flavor = "The channel softens with distance."
			"Faint":
				base_flavor = "A muffled human trace still hangs on."
			_:
				base_flavor = "Static takes the space between them."

	var ambience_tail: String = _ambience_flavor_tail(current_ambience)
	if ambience_tail == "":
		current_signal_flavor = base_flavor
		return

	current_signal_flavor = "%s %s" % [base_flavor, ambience_tail]


func _move_audio_value(property_name: String, target_value: float, step: float) -> bool:
	var current_value: float = float(get(property_name))
	var next_value: float = move_toward(current_value, target_value, step)
	if absf(next_value - current_value) <= VALUE_EPSILON:
		if absf(current_value - target_value) <= VALUE_EPSILON:
			return false

		set(property_name, target_value)
		return true

	set(property_name, next_value)
	return true


func _advance_environment(delta: float) -> void:
	_silence_cooldown_timer = maxf(0.0, _silence_cooldown_timer - delta)
	_ambient_cue_timer -= delta
	_structural_cue_timer -= delta
	_presence_cue_timer -= delta

	if _ambient_cue_timer <= 0.0:
		_trigger_ambient_cue()
		_schedule_ambient_timer()

	if _structural_cue_timer <= 0.0:
		_trigger_structural_cue()
		_schedule_structural_timer()

	if _presence_cue_timer <= 0.0:
		_trigger_presence_cue()
		_schedule_presence_timer()


func _trigger_ambient_cue() -> void:
	if _silence_cooldown_timer > 0.0:
		return

	var cues: Array[String] = _ambient_event_pool(current_ambience)
	var cue_name: String = _choose_cue(cues)
	if cue_name == "":
		return

	print("[AudioManager] ambience cue:", cue_name, "profile=", current_ambience)
	EventBus.emit_audio_requested(cue_name)
	_silence_cooldown_timer = lerpf(1.2, 4.0, current_silence_pressure)


func _trigger_structural_cue() -> void:
	if _silence_cooldown_timer > 1.8 and current_instability < 0.32:
		return

	var cues: Array[String] = _structural_event_pool(current_ambience)
	var cue_name: String = _choose_cue(cues)
	if cue_name == "":
		return

	EventBus.emit_audio_requested(cue_name)
	_silence_cooldown_timer = lerpf(1.8, 5.4, current_silence_pressure)


func _trigger_presence_cue() -> void:
	var profile: Dictionary = _build_target_profile()
	var presence_hint: String = _profile_string(profile, "presence_hint", "")
	if presence_hint == "" or presence_hint == "shared_presence" or presence_hint == "absence":
		return

	var cue_name: String = _presence_cue_name(presence_hint)
	if cue_name == "":
		return

	EventBus.emit_audio_requested(cue_name)


func _emit_environment_bleed(event_name: String) -> void:
	if current_environment_bleed <= 0.01:
		return

	print(
		"[AudioManager] bleed-through:",
		event_name,
		"level=",
		int(round(current_environment_bleed * 100.0)),
		"relationship=",
		current_relationship,
		"occlusion=",
		int(round(current_occlusion * 100.0))
	)


func _resolve_ambience_profile() -> String:
	var player_one_location: String = GameState.player_1_location
	var player_two_location: String = GameState.player_2_location

	if player_one_location == player_two_location:
		match player_one_location:
			"Shed":
				return "hollow_shed"
			"WoodsEdge":
				return "night_wind"
			"Outside":
				return "outside_reconverged" if GameState.floor_collapsed else "yard_hush"
			"Downstairs":
				return "below_house_dread"
			"Bedroom":
				return "bedroom_isolation"
			"UpstairsHallway":
				return "hallway_strain"
			_:
				return "upstairs_hum"

	if player_one_location == "WoodsEdge" or player_two_location == "WoodsEdge":
		return "night_wind"

	if player_one_location == "Shed" or player_two_location == "Shed":
		return "hollow_shed"

	if GameState.floor_collapsed:
		if player_one_location == "Bedroom" or player_two_location == "Bedroom":
			return "bedroom_isolation"
		if player_one_location == "Downstairs" or player_two_location == "Downstairs":
			return "split_house"
		return "strained_silence"

	if player_one_location == "Outside" or player_two_location == "Outside":
		return "yard_hush"

	if player_one_location == "UpstairsHallway" or player_two_location == "UpstairsHallway":
		return "hallway_strain"

	return "upstairs_hum"


func _reset_environment_timers(force_reset: bool) -> void:
	if force_reset or _ambient_cue_timer <= 0.0:
		_schedule_ambient_timer()
	if force_reset or _structural_cue_timer <= 0.0:
		_schedule_structural_timer()
	if force_reset or _presence_cue_timer <= 0.0:
		_schedule_presence_timer()


func _schedule_ambient_timer() -> void:
	var range: Vector2 = _ambient_cue_range(current_ambience)
	_ambient_cue_timer = randf_range(range.x, range.y)


func _schedule_structural_timer() -> void:
	var range: Vector2 = _structural_cue_range(current_ambience)
	_structural_cue_timer = randf_range(range.x, range.y)


func _schedule_presence_timer() -> void:
	if current_relationship == "same_room" or current_relationship == "severed":
		_presence_cue_timer = randf_range(14.0, 20.0)
		return

	if current_relationship == "vertical_split":
		_presence_cue_timer = randf_range(5.5, 9.5)
		return

	_presence_cue_timer = randf_range(8.0, 13.5)


func _choose_cue(cues: Array[String]) -> String:
	if cues.is_empty():
		return ""

	var filtered_cues: Array[String] = []
	for cue_name in cues:
		if recent_one_shots.has(cue_name):
			continue
		filtered_cues.append(cue_name)

	var active_pool: Array[String] = filtered_cues if not filtered_cues.is_empty() else cues
	var cue_index: int = randi_range(0, active_pool.size() - 1)
	return active_pool[cue_index]


func _ambience_openness(profile_key: String) -> float:
	match profile_key:
		"outside_reconverged":
			return 0.90
		"yard_hush":
			return 0.78
		"night_wind":
			return 0.82
		"hollow_shed":
			return 0.20
		"below_house_dread":
			return 0.18
		"bedroom_isolation":
			return 0.22
		"hallway_strain":
			return 0.28
		"split_house":
			return 0.16
		"strained_silence":
			return 0.14
		_:
			return 0.30


func _ambience_instability(profile_key: String) -> float:
	match profile_key:
		"hallway_strain":
			return 0.78
		"split_house":
			return 0.66
		"below_house_dread":
			return 0.54
		"bedroom_isolation":
			return 0.42
		"hollow_shed":
			return 0.34
		"outside_reconverged":
			return 0.16
		"yard_hush":
			return 0.20
		"night_wind":
			return 0.18
		"strained_silence":
			return 0.48
		_:
			return 0.28


func _ambience_silence(profile_key: String) -> float:
	match profile_key:
		"bedroom_isolation":
			return 0.74
		"split_house":
			return 0.80
		"strained_silence":
			return 0.84
		"below_house_dread":
			return 0.66
		"night_wind":
			return 0.52
		"yard_hush":
			return 0.44
		"outside_reconverged":
			return 0.26
		"hollow_shed":
			return 0.50
		"hallway_strain":
			return 0.40
		_:
			return 0.34


func _ambient_cue_range(profile_key: String) -> Vector2:
	match profile_key:
		"outside_reconverged":
			return Vector2(8.0, 13.0)
		"yard_hush":
			return Vector2(7.0, 12.0)
		"night_wind":
			return Vector2(6.5, 11.0)
		"bedroom_isolation":
			return Vector2(8.5, 14.0)
		"split_house":
			return Vector2(9.0, 15.0)
		"strained_silence":
			return Vector2(10.0, 16.0)
		"below_house_dread":
			return Vector2(7.5, 12.0)
		"hollow_shed":
			return Vector2(7.0, 11.5)
		"hallway_strain":
			return Vector2(6.5, 10.5)
		_:
			return Vector2(7.0, 11.0)


func _structural_cue_range(profile_key: String) -> Vector2:
	match profile_key:
		"outside_reconverged":
			return Vector2(18.0, 28.0)
		"yard_hush":
			return Vector2(15.0, 24.0)
		"night_wind":
			return Vector2(18.0, 30.0)
		"bedroom_isolation":
			return Vector2(10.5, 16.0)
		"split_house":
			return Vector2(7.0, 12.0)
		"strained_silence":
			return Vector2(8.0, 13.5)
		"below_house_dread":
			return Vector2(8.0, 13.0)
		"hollow_shed":
			return Vector2(10.0, 16.5)
		"hallway_strain":
			return Vector2(5.5, 9.5)
		_:
			return Vector2(11.0, 18.0)


func _ambient_event_pool(profile_key: String) -> Array[String]:
	match profile_key:
		"outside_reconverged":
			return ["yard_wind_open", "shared_outdoor_hush", "distant_tree_brush"]
		"yard_hush":
			return ["yard_wind_low", "distant_tree_brush", "cold_air_gap"]
		"night_wind":
			return ["tree_line_wind", "brush_tension_far", "night_open_air"]
		"bedroom_isolation":
			return ["window_air_leak", "bedroom_metal_tick", "far_house_settle"]
		"split_house":
			return ["empty_house_hush", "dust_drift_quiet", "faint_beam_pressure"]
		"strained_silence":
			return ["empty_house_hush", "cold_air_gap", "dust_drift_quiet"]
		"below_house_dread":
			return ["downstairs_drip_far", "low_room_resonance", "muffled_house_shift"]
		"hollow_shed":
			return ["shed_dry_roof_tick", "shed_hollow_air", "shed_board_answer"]
		"hallway_strain":
			return ["hallway_air_whisper", "weak_floor_answer", "stressed_wallpaper_rustle"]
		_:
			return ["thin_wind_bleed", "old_wiring_hum", "far_house_settle"]


func _structural_event_pool(profile_key: String) -> Array[String]:
	match profile_key:
		"outside_reconverged":
			return ["porch_settle_soft"]
		"yard_hush":
			return ["porch_settle_soft", "far_beam_shift"]
		"night_wind":
			return ["far_branch_strain"]
		"bedroom_isolation":
			return ["bedroom_ceiling_tick", "fixture_chain_tension", "far_beam_shift"]
		"split_house":
			return ["stressed_beam_answer", "debris_shift_far", "muffled_overhead_settle"]
		"strained_silence":
			return ["stressed_beam_answer", "far_beam_shift"]
		"below_house_dread":
			return ["muffled_overhead_settle", "pipe_knock_soft", "stressed_beam_answer"]
		"hollow_shed":
			return ["shed_frame_creak", "shed_roof_settle"]
		"hallway_strain":
			return ["beam_strain_soft", "weak_floor_groan", "hallway_timber_tick"]
		_:
			return ["far_house_settle", "timber_tick_soft"]


func _ambience_transition_text(profile_key: String, previous_key: String) -> String:
	if profile_key == previous_key:
		return ""

	match profile_key:
		"outside_reconverged":
			return "The yard opens around both players. The pressure eases with the air."
		"yard_hush":
			return "Open wind replaces the house pressure, but not the loneliness."
		"night_wind":
			return "The tree line eats the signal and leaves mostly wind."
		"bedroom_isolation":
			return "The bedroom drops into a smaller, lonelier room tone."
		"split_house":
			return "The house sounds split in two now: below, above, and distance between."
		"strained_silence":
			return "Silence settles in after the break, with only the house answering itself."
		"below_house_dread":
			return "The lower floor closes in with heavier air and distant drips."
		"hollow_shed":
			return "The shed answers in dry, hollow wood instead of open yard air."
		"hallway_strain":
			return "The hallway tightens into stressed boards and shallow creaks."
		_:
			return "A thin upstairs hush returns to the house."


func _ambience_flavor_tail(profile_key: String) -> String:
	match profile_key:
		"outside_reconverged":
			return "Open night air takes some pressure out of the moment."
		"yard_hush":
			return "The yard feels open, cold, and exposed."
		"night_wind":
			return "The tree line swallows detail and leaves mostly wind."
		"bedroom_isolation":
			return "Window air and small metal ticks make the room feel lonelier."
		"split_house":
			return "The broken house answers in distant settling and muffled space."
		"strained_silence":
			return "Silence does most of the work now."
		"below_house_dread":
			return "The lower floor rings with enclosed resonance and faint drips."
		"hollow_shed":
			return "Dry boards and hollow timber color the air."
		"hallway_strain":
			return "The boards still sound stressed under the wallpapered hush."
		_:
			return "Thin wind and old structure hold the rest of the room."


func _presence_cue_name(presence_hint: String) -> String:
	match presence_hint:
		"muffled_overhead":
			return "muffled_movement_overhead"
		"muffled_below":
			return "faint_settling_below"
		"distant_reply":
			return "far_voice_trace"
		"thin_presence":
			return "muffled_presence_shift"
		_:
			return ""


func _register_one_shot(event_name: String) -> void:
	recent_one_shots.append(event_name)
	if recent_one_shots.size() > 10:
		recent_one_shots.pop_front()


func _profile_float(profile: Dictionary, key: String, default_value: float) -> float:
	if not profile.has(key):
		return default_value

	return float(profile[key])


func _profile_string(profile: Dictionary, key: String, default_value: String) -> String:
	if not profile.has(key):
		return default_value

	return str(profile[key])
