extends Control
class_name MainController

const PLAYER_IDS: Array[String] = [GameState.PLAYER_1_ID, GameState.PLAYER_2_ID]
const WORLD_BOUNDS: Rect2 = Rect2(24.0, 18.0, 1048.0, 746.0)
const CAMERA_LERP_SPEED: float = 5.6
const ATMOSPHERE_LERP_SPEED: float = 4.2
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
@onready var _debug_toggle_button: Button = $DebugToggleButton
@onready var _debug_panel: PanelContainer = $DebugPanel
@onready var _world_frame: PanelContainer = $WorldFrame
@onready var _world_camera_rig: Node2D = $WorldFrame/WorldCameraRig
@onready var _world_layer: Node2D = $WorldFrame/WorldCameraRig/WorldLayer
@onready var _world_fade: ColorRect = $WorldFade
@onready var _world_state_tint: ColorRect = $WorldFrame/WorldStateTint
@onready var _world_relief_glow: ColorRect = $WorldFrame/WorldReliefGlow
@onready var _world_top_shade: ColorRect = $WorldFrame/WorldTopShade
@onready var _world_bottom_shade: ColorRect = $WorldFrame/WorldBottomShade
@onready var _world_left_shade: ColorRect = $WorldFrame/WorldLeftShade
@onready var _world_right_shade: ColorRect = $WorldFrame/WorldRightShade
@onready var _world_grain_band: ColorRect = $WorldFrame/WorldGrainBand
@onready var _active_player_value: Label = $WorldHUD/Panel/Margin/VBox/ActivePlayerValue
@onready var _active_location_value: Label = $WorldHUD/Panel/Margin/VBox/ActiveLocationValue
@onready var _interaction_hint_value: Label = $WorldHUD/Panel/Margin/VBox/InteractionHintValue
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
var _player_pawns: Dictionary = {}
var _location_nodes: Dictionary = {}
var _last_locations: Dictionary = {}
var _active_player_id: String = GameState.PLAYER_1_ID
var _has_world_state: bool = false
var _camera_target_position: Vector2 = Vector2.ZERO
var _camera_target_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	_cache_player_widgets()
	_cache_world_nodes()
	_connect_buttons()
	_connect_pawn_signals()

	EventBus.state_changed.connect(_refresh_view)
	EventBus.load_completed.connect(_refresh_view_after_load)

	_debug_toggle_button.pressed.connect(_toggle_debug_panel)
	_set_active_player(GameState.PLAYER_1_ID)
	_session_manager.initialize_local_session()
	_initialize_world_presentation()
	set_process(true)


func _process(delta: float) -> void:
	_update_camera_and_atmosphere(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_TAB or key_event.keycode == KEY_Q:
		_switch_active_player()
		accept_event()
		return

	if key_event.keycode == KEY_E:
		var pawn: PlayerPawn = _player_pawns[_active_player_id] as PlayerPawn
		if pawn != null:
			pawn.try_interact()
		accept_event()
		return

	if key_event.keycode == KEY_F1:
		_toggle_debug_panel()
		accept_event()


func _cache_world_nodes() -> void:
	_player_pawns = {
		GameState.PLAYER_1_ID: $WorldFrame/WorldCameraRig/WorldLayer/Player1Pawn,
		GameState.PLAYER_2_ID: $WorldFrame/WorldCameraRig/WorldLayer/Player2Pawn
	}

	_location_nodes = {
		"UpstairsRoom": $WorldFrame/WorldCameraRig/WorldLayer/UpstairsRoom,
		"UpstairsHallway": $WorldFrame/WorldCameraRig/WorldLayer/UpstairsHallway,
		"Bedroom": $WorldFrame/WorldCameraRig/WorldLayer/Bedroom,
		"Downstairs": $WorldFrame/WorldCameraRig/WorldLayer/Downstairs,
		"Outside": $WorldFrame/WorldCameraRig/WorldLayer/Outside,
		"WoodsEdge": $WorldFrame/WorldCameraRig/WorldLayer/WoodsEdge,
		"Shed": $WorldFrame/WorldCameraRig/WorldLayer/Shed
	}


func _connect_pawn_signals() -> void:
	for player_id in PLAYER_IDS:
		var pawn: PlayerPawn = _player_pawns[player_id] as PlayerPawn
		if pawn != null:
			pawn.interaction_zone_changed.connect(_on_pawn_interaction_zone_changed)


func _cache_player_widgets() -> void:
	_player_widgets = {
		GameState.PLAYER_1_ID: {
			"location": find_child("Player1LocationLabel", true, false),
			"inventory": find_child("Player1InventoryLabel", true, false),
			"status": find_child("Player1StatusLabel", true, false),
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
	var button: Button = _player_widgets[player_id][widget_key] as Button
	button.pressed.connect(callback.bind(player_id))


func _on_reset_pressed() -> void:
	_last_locations.clear()
	_has_world_state = false
	SceneRouter.start_new_run()


func _on_save_pressed() -> void:
	_save_manager.save_world_state()


func _on_load_pressed() -> void:
	_save_manager.load_world_state()


func _refresh_view() -> void:
	var radio_profile: Dictionary = VoiceProximityManager.calculate_profile(
		GameState.player_1_location,
		GameState.player_2_location,
		GameState.floor_collapsed
	)
	var radio_state: String = str(radio_profile["state"])
	var radio_strength: float = float(radio_profile["strength"])

	_collapse_label.text = "Floor Collapsed: %s" % _format_bool(GameState.floor_collapsed)
	_key_label.text = "Bedroom Key Taken: %s" % _format_bool(GameState.bedroom_key_taken)
	_shed_label.text = "Shed Unlocked: %s" % _format_bool(GameState.shed_unlocked)
	_trigger_label.text = "Collapse Triggered By: %s" % _format_trigger_name()
	_key_holder_label.text = "Key Holder: %s" % _key_holder_text()
	_link_label.text = "Radio Link: %s / %d%%" % [radio_state, int(round(radio_strength * 100.0))]
	_reconverged_label.text = "Group State: %s" % _group_state_text()

	var location_changed: bool = false
	for player_id in PLAYER_IDS:
		_refresh_player_panel(player_id)
		var location: String = GameState.get_player_location(player_id)
		var previous_location: String = ""
		if _last_locations.has(player_id):
			previous_location = str(_last_locations[player_id])
		if previous_location != location:
			_sync_player_position(player_id, location)
			location_changed = true
		_last_locations[player_id] = location

	if _has_world_state and location_changed:
		_play_world_fade()

	_has_world_state = true
	_update_world_hud()


func _refresh_player_panel(player_id: String) -> void:
	var widgets: Dictionary = _player_widgets[player_id]
	var location: String = GameState.get_player_location(player_id)
	var inventory: Array[String] = GameState.get_player_inventory(player_id)

	(widgets["location"] as Label).text = "Location: %s" % _pretty_location(location)
	(widgets["inventory"] as Label).text = "Inventory: %s" % _pretty_inventory(inventory)
	(widgets["status"] as Label).text = "Status: %s" % _player_status_text(player_id)
	_update_button_states(player_id, location)


func _update_button_states(player_id: String, location: String) -> void:
	var widgets: Dictionary = _player_widgets[player_id]
	var upstairs_after_collapse: bool = GameState.floor_collapsed and GameState.is_player_upstairs(player_id)

	(widgets["hallway"] as Button).disabled = location != "UpstairsRoom"
	(widgets["cross"] as Button).disabled = location != "UpstairsHallway"
	(widgets["bedroom"] as Button).disabled = not upstairs_after_collapse or location == "Bedroom"
	(widgets["key"] as Button).disabled = location != "Bedroom" or GameState.bedroom_key_taken
	(widgets["escape"] as Button).disabled = location != "Bedroom"
	(widgets["downstairs"] as Button).disabled = location != "Downstairs"
	(widgets["woods"] as Button).disabled = location != "Outside" and location != "WoodsEdge"
	(widgets["shed"] as Button).disabled = location != "Outside" and location != "Shed"

	(widgets["woods"] as Button).text = "Return Outside" if location == "WoodsEdge" else "Go To Woods Edge"
	(widgets["shed"] as Button).text = "Leave Shed" if location == "Shed" else "Try Shed Door"


func _sync_player_position(player_id: String, location: String) -> void:
	var pawn: PlayerPawn = _player_pawns[player_id] as PlayerPawn
	var location_node: GreyboxLocation = _location_nodes[location] as GreyboxLocation
	if pawn == null or location_node == null:
		return

	pawn.sync_to_position(location_node.get_spawn_position(player_id))


func _on_move_to_hallway(player_id: String) -> void:
	SceneRouter.move_player_to_hallway(player_id)


func _on_cross_hallway(player_id: String) -> void:
	SceneRouter.attempt_hallway_cross(player_id)


func _on_route_bedroom(player_id: String) -> void:
	SceneRouter.route_player_to_bedroom(player_id)


func _on_take_key(player_id: String) -> void:
	SceneRouter.search_bedroom_for_key(player_id)


func _on_escape_bedroom(player_id: String) -> void:
	SceneRouter.escape_bedroom_via_window(player_id)


func _on_leave_downstairs(player_id: String) -> void:
	SceneRouter.move_downstairs_to_outside(player_id)


func _on_toggle_woods(player_id: String) -> void:
	SceneRouter.toggle_woods_edge(player_id)


func _on_shed_action(player_id: String) -> void:
	var location: String = GameState.get_player_location(player_id)
	if location == "Shed":
		SceneRouter.leave_shed(player_id)
		return

	SceneRouter.interact_with_shed(player_id)


func _switch_active_player() -> void:
	var next_player_id: String = GameState.PLAYER_2_ID if _active_player_id == GameState.PLAYER_1_ID else GameState.PLAYER_1_ID
	_set_active_player(next_player_id)


func _set_active_player(player_id: String) -> void:
	_active_player_id = player_id
	for candidate_id in PLAYER_IDS:
		var pawn: PlayerPawn = _player_pawns[candidate_id] as PlayerPawn
		if pawn != null:
			pawn.set_selected(candidate_id == _active_player_id)

	_update_world_hud()


func _update_world_hud() -> void:
	var active_name: String = GameState.get_player_display_name(_active_player_id)
	var active_location: String = _pretty_location(GameState.get_player_location(_active_player_id))
	var prompt_text: String = ""
	var active_pawn: PlayerPawn = _player_pawns[_active_player_id] as PlayerPawn
	if active_pawn != null:
		prompt_text = active_pawn.get_current_prompt()

	_active_player_value.text = "Active Player: %s" % active_name
	_active_location_value.text = "Location: %s" % active_location
	_interaction_hint_value.text = prompt_text if prompt_text != "" else "WASD or arrows to move. Press E near a highlighted zone. Tab switches players."


func _initialize_world_presentation() -> void:
	_camera_target_position = _world_camera_rig.position
	_camera_target_scale = _world_camera_rig.scale
	_world_state_tint.color = Color(0.14, 0.18, 0.22, 0.0)
	_world_relief_glow.color = Color(0.36, 0.42, 0.38, 0.0)
	_world_top_shade.color = Color(0.01, 0.02, 0.03, 0.22)
	_world_bottom_shade.color = Color(0.01, 0.02, 0.03, 0.24)
	_world_left_shade.color = Color(0.01, 0.02, 0.03, 0.18)
	_world_right_shade.color = Color(0.01, 0.02, 0.03, 0.20)
	_world_grain_band.color = Color(0.68, 0.72, 0.76, 0.02)


func _update_camera_and_atmosphere(delta: float) -> void:
	var active_location: String = GameState.get_player_location(_active_player_id)
	var active_location_node: GreyboxLocation = _location_nodes[active_location] as GreyboxLocation
	var frame_size: Vector2 = _world_frame.size
	var focus_position: Vector2 = _resolve_focus_position(active_location, active_location_node)
	var zoom_value: float = _resolve_zoom_value(active_location_node)
	var target_position: Vector2 = (frame_size * 0.5) - (focus_position * zoom_value)
	_camera_target_position = _clamp_camera_position(target_position, zoom_value, frame_size)
	_camera_target_scale = Vector2.ONE * zoom_value

	var camera_weight: float = clampf(delta * CAMERA_LERP_SPEED, 0.0, 1.0)
	_world_camera_rig.position = _world_camera_rig.position.lerp(_camera_target_position, camera_weight)
	_world_camera_rig.scale = _world_camera_rig.scale.lerp(_camera_target_scale, camera_weight)

	_update_spatial_presence(active_location, delta)
	_update_frame_atmosphere(active_location, delta)


func _resolve_focus_position(active_location: String, active_location_node: GreyboxLocation) -> Vector2:
	var active_pawn: PlayerPawn = _player_pawns[_active_player_id] as PlayerPawn
	if active_pawn == null:
		return WORLD_BOUNDS.get_center()

	var active_point: Vector2 = _world_point_for_node(active_pawn)
	if active_location_node == null:
		return active_point

	var location_point: Vector2 = _world_layer.position + active_location_node.get_camera_focus_position()
	var other_player_id: String = GameState.get_other_player_id(_active_player_id)
	var other_location: String = GameState.get_player_location(other_player_id)
	if other_location == active_location:
		var other_pawn: PlayerPawn = _player_pawns[other_player_id] as PlayerPawn
		if other_pawn != null:
			var midpoint: Vector2 = (active_point + _world_point_for_node(other_pawn)) * 0.5
			return midpoint.lerp(location_point, 0.22)

	return active_point.lerp(location_point, 0.34)


func _resolve_zoom_value(active_location_node: GreyboxLocation) -> float:
	var zoom_value: float = 1.0
	if active_location_node != null:
		zoom_value = active_location_node.get_camera_zoom_value()

	var other_player_id: String = GameState.get_other_player_id(_active_player_id)
	if GameState.get_player_location(other_player_id) == GameState.get_player_location(_active_player_id):
		zoom_value = maxf(0.88, zoom_value - 0.12)

	return zoom_value


func _clamp_camera_position(target_position: Vector2, zoom_value: float, frame_size: Vector2) -> Vector2:
	var min_x: float = frame_size.x - ((WORLD_BOUNDS.position.x + WORLD_BOUNDS.size.x) * zoom_value)
	var max_x: float = -(WORLD_BOUNDS.position.x * zoom_value)
	var min_y: float = frame_size.y - ((WORLD_BOUNDS.position.y + WORLD_BOUNDS.size.y) * zoom_value)
	var max_y: float = -(WORLD_BOUNDS.position.y * zoom_value)

	var clamped_x: float = target_position.x
	var clamped_y: float = target_position.y
	if min_x <= max_x:
		clamped_x = clampf(target_position.x, min_x, max_x)
	else:
		clamped_x = (min_x + max_x) * 0.5

	if min_y <= max_y:
		clamped_y = clampf(target_position.y, min_y, max_y)
	else:
		clamped_y = (min_y + max_y) * 0.5

	return Vector2(clamped_x, clamped_y)


func _update_spatial_presence(active_location: String, delta: float) -> void:
	var other_player_id: String = GameState.get_other_player_id(_active_player_id)
	var other_location: String = GameState.get_player_location(other_player_id)
	var together: bool = active_location == other_location
	var presence_weight: float = clampf(delta * ATMOSPHERE_LERP_SPEED, 0.0, 1.0)

	for location_key in _location_nodes.keys():
		var location_id: String = str(location_key)
		var location_node: GreyboxLocation = _location_nodes[location_id] as GreyboxLocation
		if location_node == null:
			continue

		var target_modulate: Color = _location_presence_color(location_id, active_location, other_location, together)
		location_node.modulate = location_node.modulate.lerp(target_modulate, presence_weight)

	for player_id in PLAYER_IDS:
		var pawn: PlayerPawn = _player_pawns[player_id] as PlayerPawn
		if pawn == null:
			continue

		var pawn_color: Color = _pawn_presence_color(player_id, active_location, together)
		pawn.modulate = pawn.modulate.lerp(pawn_color, presence_weight)


func _location_presence_color(location_id: String, active_location: String, other_location: String, together: bool) -> Color:
	if location_id == active_location:
		return Color(1.0, 1.0, 1.0, 1.0)

	if together and location_id == other_location:
		return Color(0.98, 0.99, 1.0, 0.94)

	if location_id == other_location:
		return Color(0.76, 0.8, 0.84, 0.68)

	if _is_related_location(active_location, location_id):
		return Color(0.58, 0.62, 0.68, 0.5)

	return Color(0.34, 0.38, 0.42, 0.34)


func _pawn_presence_color(player_id: String, active_location: String, together: bool) -> Color:
	if player_id == _active_player_id:
		return Color(1.0, 1.0, 1.0, 1.0)

	var location: String = GameState.get_player_location(player_id)
	if together and location == active_location:
		return Color(0.9, 0.92, 0.96, 0.9)

	if location == active_location:
		return Color(0.8, 0.84, 0.9, 0.78)

	return Color(0.56, 0.6, 0.66, 0.42)


func _update_frame_atmosphere(active_location: String, delta: float) -> void:
	var together: bool = GameState.player_1_location == GameState.player_2_location
	var tint_target: Color = Color(0.14, 0.18, 0.22, 0.04)
	var relief_target: Color = Color(0.36, 0.42, 0.38, 0.05)
	var shade_alpha: float = 0.20
	var grain_alpha: float = 0.02

	if together and active_location == "Outside":
		tint_target = Color(0.18, 0.22, 0.24, 0.025)
		relief_target = Color(0.44, 0.5, 0.46, 0.16)
		shade_alpha = 0.12
		grain_alpha = 0.014
	elif together:
		tint_target = Color(0.22, 0.18, 0.14, 0.04)
		relief_target = Color(0.46, 0.38, 0.26, 0.10)
		shade_alpha = 0.18
	elif active_location == "Bedroom":
		tint_target = Color(0.12, 0.16, 0.24, 0.07)
		relief_target = Color(0.24, 0.3, 0.42, 0.06)
		shade_alpha = 0.24
		grain_alpha = 0.026
	elif active_location == "Downstairs" or active_location == "UpstairsHallway":
		tint_target = Color(0.1, 0.14, 0.2, 0.08)
		relief_target = Color(0.18, 0.24, 0.28, 0.05)
		shade_alpha = 0.26
		grain_alpha = 0.028
	elif active_location == "WoodsEdge":
		tint_target = Color(0.08, 0.14, 0.12, 0.06)
		relief_target = Color(0.18, 0.3, 0.24, 0.07)
		shade_alpha = 0.22
	else:
		tint_target = Color(0.12, 0.17, 0.22, 0.07)
		relief_target = Color(0.24, 0.3, 0.34, 0.06)
		shade_alpha = 0.22

	var weight: float = clampf(delta * ATMOSPHERE_LERP_SPEED, 0.0, 1.0)
	_world_state_tint.color = _world_state_tint.color.lerp(tint_target, weight)
	_world_relief_glow.color = _world_relief_glow.color.lerp(relief_target, weight)
	_world_top_shade.color = _world_top_shade.color.lerp(Color(0.01, 0.02, 0.03, shade_alpha + 0.04), weight)
	_world_bottom_shade.color = _world_bottom_shade.color.lerp(Color(0.01, 0.02, 0.03, shade_alpha + 0.07), weight)
	_world_left_shade.color = _world_left_shade.color.lerp(Color(0.01, 0.02, 0.03, shade_alpha), weight)
	_world_right_shade.color = _world_right_shade.color.lerp(Color(0.01, 0.02, 0.03, shade_alpha + 0.03), weight)
	_world_grain_band.color = _world_grain_band.color.lerp(Color(0.68, 0.72, 0.76, grain_alpha), weight)


func _world_point_for_node(node: Node2D) -> Vector2:
	return _world_layer.position + node.position


func _is_related_location(source: String, candidate: String) -> bool:
	match source:
		"UpstairsRoom":
			return candidate == "UpstairsHallway" or candidate == "Bedroom"
		"UpstairsHallway":
			return candidate == "UpstairsRoom" or candidate == "Bedroom" or candidate == "Downstairs"
		"Bedroom":
			return candidate == "UpstairsRoom" or candidate == "UpstairsHallway" or candidate == "Outside"
		"Downstairs":
			return candidate == "UpstairsHallway" or candidate == "Outside"
		"Outside":
			return candidate == "Downstairs" or candidate == "WoodsEdge" or candidate == "Shed" or candidate == "Bedroom"
		"WoodsEdge":
			return candidate == "Outside"
		"Shed":
			return candidate == "Outside"
		_:
			return false


func _toggle_debug_panel() -> void:
	_debug_panel.visible = not _debug_panel.visible
	_debug_toggle_button.text = "Hide Debug" if _debug_panel.visible else "Show Debug"


func _on_pawn_interaction_zone_changed(player_id: String, _zone: WorldInteractionZone) -> void:
	if player_id == _active_player_id:
		_update_world_hud()


func _play_world_fade() -> void:
	_world_fade.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_world_fade, "modulate:a", 0.24, 0.08)
	tween.chain().tween_property(_world_fade, "modulate:a", 0.0, 0.24)


func _refresh_view_after_load(_path: String) -> void:
	_last_locations.clear()
	_has_world_state = false
	_refresh_view()


func _format_bool(value: bool) -> String:
	return "Yes" if value else "No"


func _format_trigger_name() -> String:
	if GameState.collapse_triggered_by == "":
		return "Nobody Yet"

	return GameState.get_player_display_name(GameState.collapse_triggered_by)


func _pretty_location(location: String) -> String:
	if LOCATION_LABELS.has(location):
		return str(LOCATION_LABELS[location])

	return location


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
	var location: String = GameState.get_player_location(player_id)
	var has_key: bool = GameState.player_has_item(player_id, "bedroom_key")

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
