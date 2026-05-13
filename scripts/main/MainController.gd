extends Control
class_name MainController

const PLAYER_IDS := [GameState.PLAYER_1_ID, GameState.PLAYER_2_ID]
const LOCATION_LABELS := {
	"UpstairsRoom": "Upstairs Room",
	"UpstairsHallway": "Upstairs Hallway",
	"Bedroom": "Bedroom",
	"Downstairs": "Downstairs",
	"Outside": "Outside",
	"WoodsEdge": "Woods Edge",
	"Shed": "Shed"
}

@onready var _session_manager: SessionManager = $SessionManager
@onready var _save_manager: SaveManager = $SaveManager
@onready var _collapse_label: Label = find_child("CollapseLabel", true, false) as Label
@onready var _key_label: Label = find_child("KeyLabel", true, false) as Label
@onready var _shed_label: Label = find_child("ShedLabel", true, false) as Label
@onready var _trigger_label: Label = find_child("TriggerLabel", true, false) as Label
@onready var _key_holder_label: Label = find_child("KeyHolderLabel", true, false) as Label
@onready var _link_label: Label = find_child("LinkLabel", true, false) as Label
@onready var _reconverged_label: Label = find_child("ReconvergedLabel", true, false) as Label
@onready var _reset_button: Button = find_child("ResetButton", true, false) as Button
@onready var _save_button: Button = find_child("SaveButton", true, false) as Button
@onready var _load_button: Button = find_child("LoadButton", true, false) as Button

var _player_widgets: Dictionary = {}
var _preview_nodes: Dictionary = {}
var _last_locations: Dictionary = {}


func _ready() -> void:
	_cache_player_widgets()
	_connect_buttons()

	EventBus.state_changed.connect(_refresh_view)
	EventBus.load_completed.connect(_refresh_view_after_load)

	_session_manager.initialize_local_session()


func _cache_player_widgets() -> void:
	_player_widgets = {
		GameState.PLAYER_1_ID: {
			"location": find_child("Player1LocationLabel", true, false),
			"inventory": find_child("Player1InventoryLabel", true, false),
			"status": find_child("Player1StatusLabel", true, false),
			"preview": find_child("Player1Preview", true, false),
			"hallway": find_child("P1HallwayButton", true, false),
			"cross": find_child("P1CrossButton", true, false),
			"bedroom": find_child("P1BedroomButton", true, false),
			"key": find_child("P1KeyButton", true, false),
			"escape": find_child("P1EscapeButton", true, false),
			"downstairs": find_child("P1DownstairsButton", true, false),
			"woods": find_child("P1WoodsButton", true, false),
			"shed": find_child("P1ShedButton", true, false)
		},
		GameState.PLAYER_2_ID: {
			"location": find_child("Player2LocationLabel", true, false),
			"inventory": find_child("Player2InventoryLabel", true, false),
			"status": find_child("Player2StatusLabel", true, false),
			"preview": find_child("Player2Preview", true, false),
			"hallway": find_child("P2HallwayButton", true, false),
			"cross": find_child("P2CrossButton", true, false),
			"bedroom": find_child("P2BedroomButton", true, false),
			"key": find_child("P2KeyButton", true, false),
			"escape": find_child("P2EscapeButton", true, false),
			"downstairs": find_child("P2DownstairsButton", true, false),
			"woods": find_child("P2WoodsButton", true, false),
			"shed": find_child("P2ShedButton", true, false)
		}
	}


func _connect_buttons() -> void:
	_reset_button.pressed.connect(_on_reset_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)

	_bind_player_button(GameState.PLAYER_1_ID, "hallway", _on_move_to_hallway)
	_bind_player_button(GameState.PLAYER_1_ID, "cross", _on_cross_hallway)
	_bind_player_button(GameState.PLAYER_1_ID, "bedroom", _on_route_bedroom)
	_bind_player_button(GameState.PLAYER_1_ID, "key", _on_take_key)
	_bind_player_button(GameState.PLAYER_1_ID, "escape", _on_escape_bedroom)
	_bind_player_button(GameState.PLAYER_1_ID, "downstairs", _on_leave_downstairs)
	_bind_player_button(GameState.PLAYER_1_ID, "woods", _on_toggle_woods)
	_bind_player_button(GameState.PLAYER_1_ID, "shed", _on_shed_action)

	_bind_player_button(GameState.PLAYER_2_ID, "hallway", _on_move_to_hallway)
	_bind_player_button(GameState.PLAYER_2_ID, "cross", _on_cross_hallway)
	_bind_player_button(GameState.PLAYER_2_ID, "bedroom", _on_route_bedroom)
	_bind_player_button(GameState.PLAYER_2_ID, "key", _on_take_key)
	_bind_player_button(GameState.PLAYER_2_ID, "escape", _on_escape_bedroom)
	_bind_player_button(GameState.PLAYER_2_ID, "downstairs", _on_leave_downstairs)
	_bind_player_button(GameState.PLAYER_2_ID, "woods", _on_toggle_woods)
	_bind_player_button(GameState.PLAYER_2_ID, "shed", _on_shed_action)


func _bind_player_button(player_id: String, widget_key: String, callback: Callable) -> void:
	var button: Button = _player_widgets[player_id][widget_key]
	button.pressed.connect(callback.bind(player_id))


func _on_reset_pressed() -> void:
	SceneRouter.start_new_run()


func _on_save_pressed() -> void:
	_save_manager.save_world_state()


func _on_load_pressed() -> void:
	_save_manager.load_world_state()


func _refresh_view() -> void:
	var radio_profile := VoiceProximityManager.calculate_profile(
		GameState.player_1_location,
		GameState.player_2_location,
		GameState.floor_collapsed
	)
	_collapse_label.text = "Floor Collapsed: %s" % _format_bool(GameState.floor_collapsed)
	_key_label.text = "Bedroom Key Taken: %s" % _format_bool(GameState.bedroom_key_taken)
	_shed_label.text = "Shed Unlocked: %s" % _format_bool(GameState.shed_unlocked)
	_trigger_label.text = "Collapse Triggered By: %s" % _format_trigger_name()
	_key_holder_label.text = "Key Holder: %s" % _key_holder_text()
	_link_label.text = "Radio Link: %s / %d%%" % [
		str(radio_profile.get("state", "Lost")),
		int(round(float(radio_profile.get("strength", 0.0)) * 100.0))
	]
	_reconverged_label.text = "Group State: %s" % _group_state_text()

	for player_id in PLAYER_IDS:
		_refresh_player_panel(player_id)


func _refresh_player_panel(player_id: String) -> void:
	var widgets: Dictionary = _player_widgets[player_id]
	var location := GameState.get_player_location(player_id)
	var inventory := GameState.get_player_inventory(player_id)

	(widgets["location"] as Label).text = "Location: %s" % _pretty_location(location)
	(widgets["inventory"] as Label).text = "Inventory: %s" % _pretty_inventory(inventory)
	(widgets["status"] as Label).text = "Status: %s" % _player_status_text(player_id)

	_update_preview(player_id, location)
	_update_button_states(player_id, location)


func _update_preview(player_id: String, location: String) -> void:
	var preview_holder: Control = _player_widgets[player_id]["preview"]
	for child in preview_holder.get_children():
		child.queue_free()

	var scene_path := SceneRouter.get_scene_path_for_location(location)
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		_preview_nodes[player_id] = null
		return

	var preview := packed_scene.instantiate()
	preview_holder.add_child(preview)
	_preview_nodes[player_id] = preview

	var previous_location := str(_last_locations.get(player_id, ""))
	if previous_location != location:
		preview.modulate = Color(1, 1, 1, 0)
		var tween := create_tween()
		tween.tween_property(preview, "modulate", Color(1, 1, 1, 1), 0.24)

	_last_locations[player_id] = location


func _update_button_states(player_id: String, location: String) -> void:
	var widgets: Dictionary = _player_widgets[player_id]
	var upstairs_after_collapse := GameState.floor_collapsed and GameState.is_player_upstairs(player_id)

	(widgets["hallway"] as Button).disabled = location != "UpstairsRoom"
	(widgets["cross"] as Button).disabled = location != "UpstairsHallway"
	(widgets["bedroom"] as Button).disabled = not upstairs_after_collapse or location == "Bedroom"
	(widgets["key"] as Button).disabled = location != "Bedroom" or GameState.bedroom_key_taken
	(widgets["escape"] as Button).disabled = location != "Bedroom"
	(widgets["downstairs"] as Button).disabled = location != "Downstairs"
	(widgets["woods"] as Button).disabled = location not in ["Outside", "WoodsEdge"]
	(widgets["shed"] as Button).disabled = location not in ["Outside", "Shed"]

	(widgets["woods"] as Button).text = "Return Outside" if location == "WoodsEdge" else "Go To Woods Edge"
	(widgets["shed"] as Button).text = "Leave Shed" if location == "Shed" else "Try Shed Door"


func _on_move_to_hallway(player_id: String) -> void:
	SceneRouter.move_player_to_hallway(player_id)


func _on_cross_hallway(player_id: String) -> void:
	_interact_or_fallback(
		player_id,
		"CollapseTrigger",
		Callable(SceneRouter, "attempt_hallway_cross").bind(player_id)
	)


func _on_route_bedroom(player_id: String) -> void:
	SceneRouter.route_player_to_bedroom(player_id, true)


func _on_take_key(player_id: String) -> void:
	_interact_or_fallback(
		player_id,
		"BedroomKey",
		Callable(SceneRouter, "search_bedroom_for_key").bind(player_id)
	)


func _on_escape_bedroom(player_id: String) -> void:
	_interact_or_fallback(
		player_id,
		"WindowExit",
		Callable(SceneRouter, "escape_bedroom_via_window").bind(player_id)
	)


func _on_leave_downstairs(player_id: String) -> void:
	_interact_or_fallback(
		player_id,
		"OutsideDoor",
		Callable(SceneRouter, "move_downstairs_to_outside").bind(player_id)
	)


func _on_toggle_woods(player_id: String) -> void:
	SceneRouter.toggle_woods_edge(player_id)


func _on_shed_action(player_id: String) -> void:
	var location := GameState.get_player_location(player_id)
	var node_name := "YardDoor" if location == "Shed" else "ShedDoor"
	var fallback := Callable(SceneRouter, "leave_shed").bind(player_id) if location == "Shed" else Callable(SceneRouter, "interact_with_shed").bind(player_id)
	_interact_or_fallback(player_id, node_name, fallback)


func _interact_or_fallback(player_id: String, node_name: String, fallback: Callable) -> void:
	var preview: Node = _preview_nodes.get(player_id)
	if preview != null:
		var interactable := preview.get_node_or_null(node_name)
		if interactable != null and interactable.has_method("interact"):
			interactable.interact(player_id)
			return

	fallback.call()


func _refresh_view_after_load(_path: String) -> void:
	_refresh_view()


func _format_bool(value: bool) -> String:
	return "Yes" if value else "No"


func _format_trigger_name() -> String:
	if GameState.collapse_triggered_by == "":
		return "Nobody Yet"

	return GameState.get_player_display_name(GameState.collapse_triggered_by)


func _pretty_location(location: String) -> String:
	return LOCATION_LABELS.get(location, location)


func _pretty_inventory(inventory: Array[String]) -> String:
	if inventory.is_empty():
		return "Empty"

	var display_items: Array[String] = []
	for item in inventory:
		display_items.append(item.replace("_", " ").capitalize())

	return ", ".join(display_items)


func _key_holder_text() -> String:
	if GameState.player_has_item(GameState.PLAYER_1_ID, "bedroom_key"):
		return "Player 1"

	if GameState.player_has_item(GameState.PLAYER_2_ID, "bedroom_key"):
		return "Player 2"

	return "Nobody"


func _group_state_text() -> String:
	if GameState.player_1_location == GameState.player_2_location:
		if not GameState.floor_collapsed:
			return "Together Upstairs"

		if GameState.player_1_location == "Outside":
			return "Reconverged Outside"

		return "Reconverged at %s" % _pretty_location(GameState.player_1_location)

	return "Separated"


func _player_status_text(player_id: String) -> String:
	var location := GameState.get_player_location(player_id)
	var has_key := GameState.player_has_item(player_id, "bedroom_key")

	if has_key and location == "Outside":
		return "Key carrier outside"

	if has_key:
		return "Carrying bedroom key"

	match location:
		"UpstairsRoom":
			return "Waiting upstairs"
		"UpstairsHallway":
			return "Testing weak floor"
		"Bedroom":
			return "Cut off upstairs"
		"Downstairs":
			return "Routed below collapse"
		"Outside":
			return "At reconvergence point"
		"WoodsEdge":
			return "Range testing at tree line"
		"Shed":
			return "Inside optional shed"
		_:
			return "Status unknown"