extends Node

const LOCATION_SCENES := {
	"UpstairsRoom": "res://scenes/locations/UpstairsRoom.tscn",
	"UpstairsHallway": "res://scenes/locations/UpstairsHallway.tscn",
	"Bedroom": "res://scenes/locations/Bedroom.tscn",
	"Downstairs": "res://scenes/locations/Downstairs.tscn",
	"Outside": "res://scenes/locations/Outside.tscn",
	"WoodsEdge": "res://scenes/locations/WoodsEdge.tscn",
	"Shed": "res://scenes/locations/Shed.tscn"
}

var _last_reconvergence_signature: String = ""


func get_scene_path_for_location(location: String) -> String:
	return LOCATION_SCENES.get(location, LOCATION_SCENES["Outside"])


func start_new_run() -> void:
	_last_reconvergence_signature = ""
	GameState.reset_state()
	EventBus.emit_prompt_changed("Both players begin together upstairs. Move either player into the hallway to test the collapse split.")
	EventBus.emit_event_logged("House quiet. Two voices upstairs. The weak hallway waits ahead.", "system")
	EventBus.emit_audio_requested("session_started")
	refresh_radio_status()


func move_player_to_hallway(player_id: String) -> bool:
	var current := GameState.get_player_location(player_id)
	if current != "UpstairsRoom":
		EventBus.emit_prompt_changed("%s is not in the upstairs room." % GameState.get_player_display_name(player_id))
		return false

	if GameState.floor_collapsed:
		return route_player_to_bedroom(player_id, true)

	GameState.set_player_location(player_id, "UpstairsHallway")
	EventBus.emit_player_routed(player_id, "UpstairsHallway")
	EventBus.emit_prompt_changed("%s steps into the weak hallway." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s steps into the weak hallway." % GameState.get_player_display_name(player_id), "movement")
	EventBus.emit_audio_requested("footstep_creak")
	refresh_radio_status()
	return true


func attempt_hallway_cross(player_id: String) -> bool:
	var current := GameState.get_player_location(player_id)
	if current != "UpstairsHallway":
		EventBus.emit_prompt_changed("%s needs to be standing in the hallway first." % GameState.get_player_display_name(player_id))
		return false

	if GameState.floor_collapsed:
		return route_player_to_bedroom(player_id, true)

	GameState.mark_floor_collapsed(player_id)
	GameState.set_player_location(player_id, "Downstairs")
	EventBus.emit_collapse_triggered(player_id)
	EventBus.emit_player_routed(player_id, "Downstairs")

	var other_player := GameState.get_other_player_id(player_id)
	if GameState.is_player_upstairs(other_player):
		GameState.set_player_location(other_player, "Bedroom")
		EventBus.emit_player_routed(other_player, "Bedroom")

	EventBus.emit_cinematic_requested("res://scenes/cinematic/FloorCollapseCinematic.tscn")
	EventBus.emit_prompt_changed("%s crashes through the floor. The other player is cut off upstairs and forced into the bedroom route." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("The floor collapses beneath %s." % GameState.get_player_display_name(player_id), "critical")
	EventBus.emit_event_logged("%s is cut off upstairs and forced into the bedroom route." % GameState.get_player_display_name(other_player), "critical")
	EventBus.emit_audio_requested("floor_collapse")
	refresh_radio_status()
	return true


func route_player_to_bedroom(player_id: String, forced_route: bool = false) -> bool:
	var current := GameState.get_player_location(player_id)
	var valid_source := current in ["UpstairsRoom", "UpstairsHallway", "Bedroom"]
	if not valid_source:
		EventBus.emit_prompt_changed("%s is no longer upstairs, so the bedroom route does not apply." % GameState.get_player_display_name(player_id))
		return false

	if not GameState.floor_collapsed and not forced_route:
		EventBus.emit_prompt_changed("The bedroom route only matters after the hallway collapse.")
		return false

	if current == "Bedroom":
		EventBus.emit_prompt_changed("%s is already inside the bedroom." % GameState.get_player_display_name(player_id))
		return false

	GameState.set_player_location(player_id, "Bedroom")
	EventBus.emit_player_routed(player_id, "Bedroom")
	EventBus.emit_prompt_changed("%s is redirected into the bedroom and needs another way out." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s is rerouted through the bedroom." % GameState.get_player_display_name(player_id), "system")
	EventBus.emit_audio_requested("door_slam")
	refresh_radio_status()
	return true


func search_bedroom_for_key(player_id: String) -> bool:
	if GameState.get_player_location(player_id) != "Bedroom":
		EventBus.emit_prompt_changed("%s needs to be in the bedroom to search for the key." % GameState.get_player_display_name(player_id))
		return false

	if GameState.bedroom_key_taken:
		EventBus.emit_prompt_changed("The bedroom key has already been taken.")
		return false

	GameState.take_bedroom_key(player_id)
	EventBus.emit_prompt_changed("%s finds the bedroom key." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s finds the bedroom key in the dark bedroom." % GameState.get_player_display_name(player_id), "system")
	EventBus.emit_audio_requested("pickup_key")
	refresh_radio_status()
	return true


func escape_bedroom_via_window(player_id: String) -> bool:
	if GameState.get_player_location(player_id) != "Bedroom":
		EventBus.emit_prompt_changed("%s is not at the bedroom window." % GameState.get_player_display_name(player_id))
		return false

	GameState.set_player_location(player_id, "Outside")
	EventBus.emit_player_routed(player_id, "Outside")
	EventBus.emit_prompt_changed("%s climbs down the drainpipe and makes it outside." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s escapes through the bedroom window and down the drainpipe." % GameState.get_player_display_name(player_id), "movement")
	EventBus.emit_audio_requested("window_escape")
	refresh_radio_status()
	_emit_reconvergence_if_needed()
	return true


func move_downstairs_to_outside(player_id: String) -> bool:
	if GameState.get_player_location(player_id) != "Downstairs":
		EventBus.emit_prompt_changed("%s is not downstairs." % GameState.get_player_display_name(player_id))
		return false

	GameState.set_player_location(player_id, "Outside")
	EventBus.emit_player_routed(player_id, "Outside")
	EventBus.emit_prompt_changed("%s exits downstairs and reaches the outside reconvergence point." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s stumbles out of the lower floor and reaches the yard." % GameState.get_player_display_name(player_id), "movement")
	EventBus.emit_audio_requested("outside_door")
	refresh_radio_status()
	_emit_reconvergence_if_needed()
	return true


func toggle_woods_edge(player_id: String) -> bool:
	var current := GameState.get_player_location(player_id)
	if current == "Outside":
		GameState.set_player_location(player_id, "WoodsEdge")
		EventBus.emit_player_routed(player_id, "WoodsEdge")
		EventBus.emit_prompt_changed("%s pushes farther out toward the woods edge." % GameState.get_player_display_name(player_id))
		EventBus.emit_event_logged("%s drifts toward the woods edge." % GameState.get_player_display_name(player_id), "movement")
		EventBus.emit_audio_requested("brush_step")
		refresh_radio_status()
		return true

	if current == "WoodsEdge":
		GameState.set_player_location(player_id, "Outside")
		EventBus.emit_player_routed(player_id, "Outside")
		EventBus.emit_prompt_changed("%s returns from the woods edge to the house exterior." % GameState.get_player_display_name(player_id))
		EventBus.emit_event_logged("%s returns from the tree line to the house exterior." % GameState.get_player_display_name(player_id), "movement")
		EventBus.emit_audio_requested("brush_step")
		refresh_radio_status()
		_emit_reconvergence_if_needed()
		return true

	EventBus.emit_prompt_changed("%s can only move to the woods edge from outside." % GameState.get_player_display_name(player_id))
	return false


func interact_with_shed(player_id: String) -> bool:
	var current := GameState.get_player_location(player_id)
	if current == "Shed":
		return leave_shed(player_id)

	if current != "Outside":
		EventBus.emit_prompt_changed("%s needs to be outside to reach the shed." % GameState.get_player_display_name(player_id))
		return false

	if not GameState.shed_unlocked:
		if not GameState.player_has_item(player_id, "bedroom_key"):
			EventBus.emit_prompt_changed("The shed is locked. Whoever found the bedroom key can open it, but it is optional.")
			EventBus.emit_event_logged("The shed door holds fast. No key, no entry.", "system")
			EventBus.emit_audio_requested("door_locked")
			return false

		GameState.unlock_shed(player_id)
		EventBus.emit_shed_unlocked(player_id)
		EventBus.emit_event_logged("The bedroom key turns in the shed lock.", "system")

	GameState.set_player_location(player_id, "Shed")
	EventBus.emit_player_routed(player_id, "Shed")
	EventBus.emit_prompt_changed("%s opens the optional shed and steps inside." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s opens the optional shed." % GameState.get_player_display_name(player_id), "system")
	EventBus.emit_audio_requested("shed_open")
	refresh_radio_status()
	_emit_reconvergence_if_needed()
	return true


func leave_shed(player_id: String) -> bool:
	if GameState.get_player_location(player_id) != "Shed":
		EventBus.emit_prompt_changed("%s is not in the shed." % GameState.get_player_display_name(player_id))
		return false

	GameState.set_player_location(player_id, "Outside")
	EventBus.emit_player_routed(player_id, "Outside")
	EventBus.emit_prompt_changed("%s leaves the shed and returns outside." % GameState.get_player_display_name(player_id))
	EventBus.emit_event_logged("%s leaves the shed and returns to the yard." % GameState.get_player_display_name(player_id), "movement")
	EventBus.emit_audio_requested("shed_open")
	refresh_radio_status()
	_emit_reconvergence_if_needed()
	return true


func refresh_radio_status() -> void:
	var status := VoiceProximityManager.calculate_status(
		GameState.player_1_location,
		GameState.player_2_location,
		GameState.floor_collapsed
	)
	EventBus.emit_radio_status_changed(status)


func _emit_reconvergence_if_needed() -> void:
	if not GameState.floor_collapsed:
		_last_reconvergence_signature = ""
		return

	if GameState.player_1_location != GameState.player_2_location:
		_last_reconvergence_signature = ""
		return

	var signature := GameState.player_1_location
	if signature == _last_reconvergence_signature:
		return

	_last_reconvergence_signature = signature
	EventBus.emit_event_logged(
		"The radio steadies. Both players reconverge at %s." % _pretty_location(signature).to_lower(),
		"hope"
	)


func _pretty_location(location: String) -> String:
	match location:
		"UpstairsRoom":
			return "the upstairs room"
		"UpstairsHallway":
			return "the upstairs hallway"
		"Bedroom":
			return "the bedroom"
		"Downstairs":
			return "the downstairs hall"
		"Outside":
			return "the yard"
		"WoodsEdge":
			return "the woods edge"
		"Shed":
			return "the shed"
		_:
			return location