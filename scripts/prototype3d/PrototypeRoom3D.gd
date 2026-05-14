extends Node3D
class_name PrototypeRoom3D

const PLAYER_ONE_ID: String = "player_1"
const PLAYER_TWO_ID: String = "player_2"

const TITLE_CARD_DURATION: float = 4.5
const AREA_CARD_BEAT_DURATION: float = 2.8
const MAX_FEED_LINES: int = 2
const CHARACTER_IDLE_SPEED: float = 1.35
const LIGHT_LERP_SPEED: float = 2.2
const TRANSITION_FADE_SPEED: float = 1.9
const PLAYER_COUNT: int = 2

const DEFAULT_FEED_LINES: Array[String] = [
	"Both players start upstairs. Move to the doorway and press E to enter the hallway."
]

const INTERACTION_FEED: Dictionary = {
	"radio": "The radio hisses with no carrier, only stressed wiring and room tone.",
	"window": "Cold moonlight cuts a clean route through the room.",
	"hallway_edge": "The boards answer back. This is as far as the first 3D beat needs to go.",
	"companion": "Your companion keeps one eye on the door and one on you."
}

@onready var _player_one: PrototypePlayer3D = $Player as PrototypePlayer3D
@onready var _player_two: PrototypePlayer3D = $PlayerTwo as PrototypePlayer3D
@onready var _door_zone: PrototypeInteractable3D = $Interactables/DoorZone as PrototypeInteractable3D
@onready var _hallway_edge_zone: PrototypeInteractable3D = $Interactables/HallwayEdgeZone as PrototypeInteractable3D
@onready var _companion_silhouette: Node3D = $Characters/Companion
@onready var _companion_zone: PrototypeInteractable3D = $Interactables/CompanionZone as PrototypeInteractable3D
@onready var _blocked_friend: Node3D = $Characters/BlockedFriend
@onready var _player_one_room_anchor: Node3D = $TransitionAnchors/PlayerOneRoom
@onready var _player_two_room_anchor: Node3D = $TransitionAnchors/PlayerTwoRoom
@onready var _player_one_hallway_anchor: Node3D = $TransitionAnchors/PlayerOneHallway
@onready var _player_two_hallway_anchor: Node3D = $TransitionAnchors/PlayerTwoHallway
@onready var _area_card: Control = $UI/AreaCard
@onready var _area_card_title: Label = $UI/AreaCard/Margin/VBox/AreaTitle
@onready var _area_card_subtitle: Label = $UI/AreaCard/Margin/VBox/AreaSubtitle
@onready var _prompt_label: Label = $UI/PromptPanel/Margin/PromptLabel
@onready var _feed_label: Label = $UI/NarrativePanel/Margin/VBox/FeedLabel
@onready var _status_label: Label = $UI/StatusPanel/Margin/VBox/StatusLabel
@onready var _debug_panel: PanelContainer = $UI/DebugPanel
@onready var _debug_label: Label = $UI/DebugPanel/Margin/DebugLabel
@onready var _transition_fade: ColorRect = $UI/TransitionFade
@onready var _lamp_light: OmniLight3D = $LampLight
@onready var _door_spill: SpotLight3D = $DoorSpill
@onready var _window_beam: SpotLight3D = $WindowBeam
@onready var _player_key_light: SpotLight3D = $PlayerKeyLight
@onready var _companion_rim_light: SpotLight3D = $CompanionRimLight
@onready var _hallway_fill_light: SpotLight3D = $HallwayFill

var _game_state: Node = null
var _event_bus: Node = null
var _scene_router: Node = null
var _title_card_time_left: float = TITLE_CARD_DURATION
var _area_card_duration_current: float = TITLE_CARD_DURATION
var _feed_lines: Array[String] = []
var _presentation_time: float = 0.0
var _active_player_index: int = 0
var _transition_fade_alpha: float = 0.0
var _radio_status: String = "Clear"
var _last_router_prompt: String = ""
var _last_player_locations: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capture_autoloads()
	_connect_autoload_signals()

	_player_one.focus_changed.connect(_on_player_focus_changed)
	_player_two.focus_changed.connect(_on_player_focus_changed)

	var interactable_nodes: Array[Node] = get_tree().get_nodes_in_group("prototype_interactable")
	for node in interactable_nodes:
		var interactable: PrototypeInteractable3D = node as PrototypeInteractable3D
		if interactable == null:
			continue
		interactable.interacted.connect(_on_interactable_interacted)

	_debug_panel.visible = false
	_feed_lines = []
	for line in DEFAULT_FEED_LINES:
		_feed_lines.append(line)

	_area_card_title.text = "UPSTAIRS ROOM"
	_area_card_subtitle.text = "One playable room, one doorway transition, and a clean first gameplay beat."
	if _companion_silhouette != null:
		_companion_silhouette.visible = false
	if _companion_zone != null:
		_companion_zone.monitoring = false
		_companion_zone.visible = false
	if _door_zone != null:
		_door_zone.monitoring = true
	if _hallway_edge_zone != null:
		_hallway_edge_zone.monitoring = true
	if _blocked_friend != null:
		_blocked_friend.visible = false

	_refresh_feed_label()
	_set_active_player(0)
	_start_run_if_possible()
	_sync_players_from_state(true)
	_refresh_prompt()
	_refresh_status()


func _process(delta: float) -> void:
	_presentation_time += delta
	_update_area_card(delta)
	_update_transition_overlay(delta)
	_refresh_prompt()
	_refresh_status()
	_update_character_embodiment(delta)
	_update_lighting_mood(delta)
	_refresh_debug_text()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_TAB or key_event.keycode == KEY_Q:
		_switch_active_player()
		_mark_input_handled()
		return

	if key_event.keycode == KEY_E:
		var active_player: PrototypePlayer3D = _get_active_player()
		if active_player != null:
			active_player.try_interact()
		_mark_input_handled()
		return

	if key_event.keycode == KEY_ESCAPE:
		_toggle_mouse_capture()
		_mark_input_handled()
		return

	if key_event.keycode == KEY_F1:
		_debug_panel.visible = not _debug_panel.visible
		_mark_input_handled()


func _capture_autoloads() -> void:
	_game_state = get_node_or_null("/root/GameState")
	_event_bus = get_node_or_null("/root/EventBus")
	_scene_router = get_node_or_null("/root/SceneRouter")


func _connect_autoload_signals() -> void:
	if _event_bus == null:
		return

	_event_bus.connect("prompt_changed", Callable(self, "_on_prompt_changed"))
	_event_bus.connect("event_logged", Callable(self, "_on_event_logged"))
	_event_bus.connect("radio_status_changed", Callable(self, "_on_radio_status_changed"))
	_event_bus.connect("player_routed", Callable(self, "_on_player_routed"))
	_event_bus.connect("state_changed", Callable(self, "_on_state_changed"))


func _start_run_if_possible() -> void:
	if _scene_router != null:
		_scene_router.call("start_new_run")


func _on_player_focus_changed() -> void:
	_refresh_prompt()


func _on_interactable_interacted(interactable_id: String, message_text: String) -> void:
	match interactable_id:
		"blocked_door":
			_handle_doorway_interaction()
			return
		"hallway_edge":
			_handle_hallway_edge_interaction()
			return

	var feed_text: String = message_text
	if INTERACTION_FEED.has(interactable_id):
		feed_text = str(INTERACTION_FEED[interactable_id])

	_push_feed_line(feed_text)


func _on_prompt_changed(text: String) -> void:
	_last_router_prompt = text


func _on_event_logged(text: String, _tone: String) -> void:
	_push_feed_line(text)


func _on_radio_status_changed(status: String) -> void:
	_radio_status = status


func _on_player_routed(player_id: String, location: String) -> void:
	_sync_players_from_state(false)
	if location == "UpstairsHallway":
		_show_area_card("HALLWAY THRESHOLD", "One step out of the room. The floor answers immediately.")
		_trigger_transition_flash(0.18)
	elif location == "UpstairsRoom":
		_show_area_card("UPSTAIRS ROOM", "Back inside the room, with the doorway still carrying the threat.")
	elif player_id == _active_player_id():
		_trigger_transition_flash(0.12)


func _on_state_changed() -> void:
	_sync_players_from_state(false)


func _handle_doorway_interaction() -> void:
	var player_id: String = _active_player_id()
	var current_location: String = _get_player_location(player_id)

	if current_location == "UpstairsRoom":
		var moved_to_hallway: bool = _call_scene_router_bool("move_player_to_hallway", [player_id])
		if moved_to_hallway:
			_trigger_transition_flash(0.18)
		return

	if current_location == "UpstairsHallway":
		_handle_hallway_edge_interaction()
		return

	_push_feed_line("That doorway only matters while the player is still upstairs.")


func _handle_hallway_edge_interaction() -> void:
	var player_id: String = _active_player_id()
	var current_location: String = _get_player_location(player_id)
	if current_location != "UpstairsHallway":
		_push_feed_line("Step into the hallway first.")
		return

	var inspected: bool = _call_scene_router_bool("inspect_collapsed_edge", [player_id])
	if inspected:
		_show_area_card("WEAK FLOOR", "The house answers, but the full collapse stays for a later beat.")
		_trigger_transition_flash(0.10)


func _update_area_card(delta: float) -> void:
	if _title_card_time_left <= 0.0:
		_area_card.visible = false
		return

	_title_card_time_left = max(0.0, _title_card_time_left - delta)
	_area_card.visible = true

	var fade_strength: float = min(1.0, _title_card_time_left / maxf(0.001, _area_card_duration_current))
	var alpha: float = min(1.0, fade_strength * 1.2)
	if _title_card_time_left < 1.0:
		alpha = _title_card_time_left

	_area_card.modulate.a = alpha


func _update_transition_overlay(delta: float) -> void:
	_transition_fade_alpha = move_toward(_transition_fade_alpha, 0.0, delta * TRANSITION_FADE_SPEED)
	if _transition_fade != null:
		var color: Color = _transition_fade.color
		color.a = _transition_fade_alpha
		_transition_fade.color = color


func _refresh_prompt() -> void:
	var active_player: PrototypePlayer3D = _get_active_player()
	if active_player == null:
		_prompt_label.text = "No active player is available."
		return

	var prompt_text: String = active_player.get_current_prompt()
	var focus_id: String = active_player.get_focus_interactable_id()
	if focus_id == "blocked_door":
		prompt_text = _doorway_prompt_for(active_player)
	elif focus_id == "hallway_edge":
		prompt_text = "Press E - test the weak floor"

	_prompt_label.text = "%s // %s" % [active_player.get_display_name().to_upper(), prompt_text]


func _refresh_status() -> void:
	var active_player_name: String = _active_player_name()
	var active_location: String = _pretty_location(_get_player_location(_active_player_id()))
	_status_label.text = "%s | %s | Radio %s | Tab/Q switch | E interact | F1 debug" % [
		active_player_name,
		active_location,
		_radio_status
	]


func _refresh_feed_label() -> void:
	_feed_label.text = "\n".join(_feed_lines)


func _push_feed_line(line: String) -> void:
	var trimmed_line: String = line.strip_edges()
	if trimmed_line == "":
		return

	if not _feed_lines.is_empty() and _feed_lines[_feed_lines.size() - 1] == trimmed_line:
		return

	_feed_lines.append(trimmed_line)
	while _feed_lines.size() > MAX_FEED_LINES:
		_feed_lines.remove_at(0)
	_refresh_feed_label()


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_push_feed_line("Cursor released.")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_push_feed_line("Cursor recaptured.")


func _refresh_debug_text() -> void:
	var cursor_mode: String = "Captured" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Free"
	_debug_label.text = "Prototype Room Debug\nActive: %s\nP1: %s [%s]\nP2: %s [%s]\nRadio: %s\nPrompt: %s\nCursor: %s" % [
		_active_player_name(),
		_format_player_position(_player_one),
		_get_player_location(PLAYER_ONE_ID),
		_format_player_position(_player_two),
		_get_player_location(PLAYER_TWO_ID),
		_radio_status,
		_last_router_prompt,
		cursor_mode
	]


func _update_character_embodiment(delta: float) -> void:
	if _blocked_friend == null or not _blocked_friend.visible:
		return

	var blocked_position: Vector3 = _blocked_friend.position
	blocked_position.y = sin(_presentation_time * (CHARACTER_IDLE_SPEED + 0.22) + 0.9) * 0.024
	_blocked_friend.position = blocked_position
	_blocked_friend.rotation.y = lerp_angle(_blocked_friend.rotation.y, -1.65806 + sin(_presentation_time * 0.82) * 0.05, min(1.0, delta * 1.6))


func _update_lighting_mood(delta: float) -> void:
	var active_player: PrototypePlayer3D = _get_active_player()
	var active_camera: Camera3D = _get_active_camera()
	if active_player == null or active_camera == null:
		return

	var motion_ratio: float = active_player.get_motion_ratio()
	var focus_ratio: float = 1.0 if active_player.has_focus_interactable() else 0.0
	var hallway_ratio: float = 1.0 if _get_player_location(_active_player_id()) == "UpstairsHallway" else 0.0

	var target_window_energy: float = 2.2 + focus_ratio * 0.35
	var target_door_energy: float = 1.55 + hallway_ratio * 0.55 + focus_ratio * 0.12
	var target_hallway_fill_energy: float = 1.05 + hallway_ratio * 0.45
	var target_player_key_energy: float = 1.75 + motion_ratio * 0.42
	var target_companion_rim_energy: float = 1.05 + focus_ratio * 0.22
	var target_lamp_energy: float = 2.1 - focus_ratio * 0.12

	_window_beam.light_energy = move_toward(_window_beam.light_energy, target_window_energy, delta * LIGHT_LERP_SPEED)
	_door_spill.light_energy = move_toward(_door_spill.light_energy, target_door_energy, delta * LIGHT_LERP_SPEED)
	_hallway_fill_light.light_energy = move_toward(_hallway_fill_light.light_energy, target_hallway_fill_energy, delta * LIGHT_LERP_SPEED)
	_player_key_light.light_energy = move_toward(_player_key_light.light_energy, target_player_key_energy, delta * LIGHT_LERP_SPEED)
	_companion_rim_light.light_energy = move_toward(_companion_rim_light.light_energy, target_companion_rim_energy, delta * LIGHT_LERP_SPEED)
	_lamp_light.light_energy = move_toward(_lamp_light.light_energy, target_lamp_energy, delta * LIGHT_LERP_SPEED)

	var camera_rotation: Vector3 = active_camera.rotation
	camera_rotation.z = lerp_angle(camera_rotation.z, -motion_ratio * 0.01, min(1.0, delta * 2.6))
	active_camera.rotation = camera_rotation


func _switch_active_player() -> void:
	var next_player_index: int = (_active_player_index + 1) % PLAYER_COUNT
	_set_active_player(next_player_index)


func _set_active_player(player_index: int) -> void:
	_active_player_index = clampi(player_index, 0, PLAYER_COUNT - 1)
	_player_one.set_active_state(_active_player_index == 0)
	_player_two.set_active_state(_active_player_index == 1)
	_refresh_prompt()
	_refresh_status()


func _get_active_player() -> PrototypePlayer3D:
	return _player_one if _active_player_index == 0 else _player_two


func _get_active_camera() -> Camera3D:
	var active_player: PrototypePlayer3D = _get_active_player()
	if active_player == null:
		return null

	return active_player.get_camera()


func _active_player_name() -> String:
	var active_player: PrototypePlayer3D = _get_active_player()
	if active_player == null:
		return "Unknown"

	return active_player.get_display_name()


func _active_player_id() -> String:
	return PLAYER_ONE_ID if _active_player_index == 0 else PLAYER_TWO_ID


func _format_player_position(player_node: PrototypePlayer3D) -> String:
	if player_node == null:
		return "(missing)"

	return "(%.2f, %.2f, %.2f)" % [
		player_node.global_position.x,
		player_node.global_position.y,
		player_node.global_position.z
	]


func _sync_players_from_state(force_sync: bool) -> void:
	_sync_player_position(_player_one, PLAYER_ONE_ID, _player_one_room_anchor, _player_one_hallway_anchor, force_sync)
	_sync_player_position(_player_two, PLAYER_TWO_ID, _player_two_room_anchor, _player_two_hallway_anchor, force_sync)


func _sync_player_position(player_node: PrototypePlayer3D, player_id: String, room_anchor: Node3D, hallway_anchor: Node3D, force_sync: bool) -> void:
	if player_node == null:
		return

	var location: String = _get_player_location(player_id)
	var previous_location: String = ""
	if _last_player_locations.has(player_id):
		previous_location = str(_last_player_locations[player_id])

	if not force_sync and location == previous_location:
		return

	var anchor: Node3D = null
	match location:
		"UpstairsRoom":
			anchor = room_anchor
		"UpstairsHallway":
			anchor = hallway_anchor
		_:
			anchor = room_anchor

	player_node.snap_to_marker(anchor)
	_last_player_locations[player_id] = location


func _doorway_prompt_for(active_player: PrototypePlayer3D) -> String:
	if active_player == null:
		return "Move closer to the doorway"

	var player_id: String = PLAYER_ONE_ID if active_player == _player_one else PLAYER_TWO_ID
	var location: String = _get_player_location(player_id)
	if location == "UpstairsHallway":
		return "Press E - hold at the hallway edge"

	return "Press E - enter hallway"


func _call_scene_router_bool(method_name: String, args: Array) -> bool:
	if _scene_router == null:
		_push_feed_line("SceneRouter is unavailable in this prototype build.")
		return false

	return bool(_scene_router.callv(method_name, args))


func _get_player_location(player_id: String) -> String:
	if _game_state == null:
		return "UpstairsRoom"

	return str(_game_state.call("get_player_location", player_id))


func _pretty_location(location: String) -> String:
	match location:
		"UpstairsRoom":
			return "Upstairs Room"
		"UpstairsHallway":
			return "Hallway Threshold"
		_:
			return location


func _show_area_card(title: String, subtitle: String, duration: float = AREA_CARD_BEAT_DURATION) -> void:
	_area_card_title.text = title
	_area_card_subtitle.text = subtitle
	_area_card_duration_current = duration
	_title_card_time_left = duration
	_area_card.modulate.a = 1.0
	_area_card.visible = true


func _trigger_transition_flash(target_alpha: float) -> void:
	_transition_fade_alpha = maxf(_transition_fade_alpha, target_alpha)


func _mark_input_handled() -> void:
	# Guardrail: using viewport handling here avoids the recurring accept_event() issue.
	get_viewport().set_input_as_handled()
