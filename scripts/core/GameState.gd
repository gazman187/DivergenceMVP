extends Node
class_name GameState

const PLAYER_1_ID := "player_1"
const PLAYER_2_ID := "player_2"

var floor_collapsed: bool = false
var bedroom_key_taken: bool = false
var shed_unlocked: bool = false
var collapse_triggered_by: String = ""
var player_1_location: String = "UpstairsRoom"
var player_2_location: String = "UpstairsRoom"
var player_1_inventory: Array[String] = []
var player_2_inventory: Array[String] = []

var _player_states: Dictionary = {}


func _ready() -> void:
	reset_state(false)


func reset_state(emit_signal: bool = true) -> void:
	floor_collapsed = false
	bedroom_key_taken = false
	shed_unlocked = false
	collapse_triggered_by = ""

	var player_one := PlayerState.new(PLAYER_1_ID, "Player 1")
	var player_two := PlayerState.new(PLAYER_2_ID, "Player 2")
	player_one.location = "UpstairsRoom"
	player_two.location = "UpstairsRoom"

	_player_states = {
		PLAYER_1_ID: player_one,
		PLAYER_2_ID: player_two
	}

	_sync_public_state()

	if emit_signal:
		_emit_state_changed()


func get_player_state(player_id: String) -> PlayerState:
	return _player_states.get(player_id) as PlayerState


func get_player_location(player_id: String) -> String:
	var state := get_player_state(player_id)
	return state.location if state != null else "Unknown"


func get_player_inventory(player_id: String) -> Array[String]:
	var state := get_player_state(player_id)
	return state.inventory.duplicate() if state != null else []


func get_player_display_name(player_id: String) -> String:
	var state := get_player_state(player_id)
	return state.display_name if state != null else player_id


func get_other_player_id(player_id: String) -> String:
	return PLAYER_2_ID if player_id == PLAYER_1_ID else PLAYER_1_ID


func set_player_location(player_id: String, location: String) -> void:
	var state := get_player_state(player_id)
	if state == null:
		return

	state.location = location
	_sync_public_state()
	_emit_state_changed()


func add_item_to_player(player_id: String, item_id: String, emit_signal: bool = true) -> bool:
	var state := get_player_state(player_id)
	if state == null:
		return false

	if state.inventory.has(item_id):
		return false

	state.inventory.append(item_id)
	_sync_public_state()

	if emit_signal:
		_emit_inventory_changed(player_id)
		_emit_state_changed()

	return true


func take_bedroom_key(player_id: String) -> bool:
	if bedroom_key_taken:
		return false

	bedroom_key_taken = true
	var added := add_item_to_player(player_id, "bedroom_key", false)
	if not added:
		bedroom_key_taken = false
		return false

	_sync_public_state()
	_emit_inventory_changed(player_id)
	_emit_state_changed()
	return true


func player_has_item(player_id: String, item_id: String) -> bool:
	var state := get_player_state(player_id)
	return state != null and state.inventory.has(item_id)


func unlock_shed(player_id: String) -> bool:
	if shed_unlocked:
		return false

	if not player_has_item(player_id, "bedroom_key"):
		return false

	shed_unlocked = true
	_sync_public_state()
	_emit_state_changed()
	return true


func mark_floor_collapsed(player_id: String) -> bool:
	if floor_collapsed:
		return false

	floor_collapsed = true
	collapse_triggered_by = player_id
	_sync_public_state()
	_emit_state_changed()
	return true


func is_location_upstairs(location: String) -> bool:
	return location in ["UpstairsRoom", "UpstairsHallway", "Bedroom"]


func is_player_upstairs(player_id: String) -> bool:
	return is_location_upstairs(get_player_location(player_id))


func serialize_state() -> Dictionary:
	return {
		"floor_collapsed": floor_collapsed,
		"bedroom_key_taken": bedroom_key_taken,
		"shed_unlocked": shed_unlocked,
		"collapse_triggered_by": collapse_triggered_by,
		"player_1_location": player_1_location,
		"player_2_location": player_2_location,
		"player_1_inventory": player_1_inventory.duplicate(),
		"player_2_inventory": player_2_inventory.duplicate(),
		"players": {
			PLAYER_1_ID: get_player_state(PLAYER_1_ID).to_dict(),
			PLAYER_2_ID: get_player_state(PLAYER_2_ID).to_dict()
		}
	}


func apply_save_data(data: Dictionary) -> void:
	floor_collapsed = bool(data.get("floor_collapsed", false))
	bedroom_key_taken = bool(data.get("bedroom_key_taken", false))
	shed_unlocked = bool(data.get("shed_unlocked", false))
	collapse_triggered_by = str(data.get("collapse_triggered_by", ""))

	var players_data: Dictionary = data.get("players", {})
	if players_data.is_empty():
		var player_one := PlayerState.new(PLAYER_1_ID, "Player 1")
		player_one.location = str(data.get("player_1_location", "UpstairsRoom"))
		for item in data.get("player_1_inventory", []):
			player_one.inventory.append(str(item))

		var player_two := PlayerState.new(PLAYER_2_ID, "Player 2")
		player_two.location = str(data.get("player_2_location", "UpstairsRoom"))
		for item in data.get("player_2_inventory", []):
			player_two.inventory.append(str(item))

		_player_states = {
			PLAYER_1_ID: player_one,
			PLAYER_2_ID: player_two
		}
	else:
		_player_states = {
			PLAYER_1_ID: PlayerState.from_dict(players_data.get(PLAYER_1_ID, {})),
			PLAYER_2_ID: PlayerState.from_dict(players_data.get(PLAYER_2_ID, {}))
		}
		if get_player_state(PLAYER_1_ID).display_name == "":
			get_player_state(PLAYER_1_ID).display_name = "Player 1"
		if get_player_state(PLAYER_2_ID).display_name == "":
			get_player_state(PLAYER_2_ID).display_name = "Player 2"

	_sync_public_state()
	_emit_state_changed()


func _sync_public_state() -> void:
	player_1_location = get_player_location(PLAYER_1_ID)
	player_2_location = get_player_location(PLAYER_2_ID)
	player_1_inventory = get_player_inventory(PLAYER_1_ID)
	player_2_inventory = get_player_inventory(PLAYER_2_ID)


func _emit_state_changed() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		EventBus.emit_state_changed()


func _emit_inventory_changed(player_id: String) -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		EventBus.emit_inventory_changed(player_id, get_player_inventory(player_id))
