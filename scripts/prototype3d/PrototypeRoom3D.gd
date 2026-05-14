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
const COLLAPSE_PRE_DELAY: float = 0.42
const CAMERA_SHAKE_MAX_TIME: float = 0.62
const PLAYER_COUNT: int = 2

const DEFAULT_FEED_LINES: Array[String] = [
	"Both players start upstairs. Move through the doorway and let the weak hallway section fail."
]

const INTERACTION_FEED: Dictionary = {
	"radio": "The radio hisses with no carrier, only stressed wiring and room tone.",
	"window": "Cold moonlight cuts a clean route through the room.",
	"hallway_edge": "The floor is gone.",
	"companion": "Your companion keeps one eye on the door and one on you."
}

@onready var _player_one: PrototypePlayer3D = $Player as PrototypePlayer3D
@onready var _player_two: PrototypePlayer3D = $PlayerTwo as PrototypePlayer3D
@onready var _collapse_trigger: Area3D = $CollapseTrigger
@onready var _door_zone: PrototypeInteractable3D = $Interactables/DoorZone as PrototypeInteractable3D
@onready var _hallway_edge_zone: PrototypeInteractable3D = $Interactables/HallwayEdgeZone as PrototypeInteractable3D
@onready var _companion_silhouette: Node3D = $Characters/Companion
@onready var _companion_zone: PrototypeInteractable3D = $Interactables/CompanionZone as PrototypeInteractable3D
@onready var _blocked_friend: Node3D = $Characters/BlockedFriend
@onready var _hallway_weak_panel: CSGBox3D = $RoomShell/HallwayWeakPanel
@onready var _hallway_runner: CSGBox3D = $RoomShell/HallwayRunner
@onready var _hallway_hole_void: CSGBox3D = $RoomShell/HallwayHoleVoid
@onready var _collapse_barrier: CSGBox3D = $RoomShell/CollapseBarrier
@onready var _dust_plume: MeshInstance3D = $RoomShell/DustPlume
@onready var _downstairs_placeholder: Node3D = $RoomShell/DownstairsPlaceholder
@onready var _downstairs_fill_light: SpotLight3D = $DownstairsFill
@onready var _player_one_room_anchor: Node3D = $TransitionAnchors/PlayerOneRoom
@onready var _player_two_room_anchor: Node3D = $TransitionAnchors/PlayerTwoRoom
@onready var _player_one_hallway_anchor: Node3D = $TransitionAnchors/PlayerOneHallway
@onready var _player_two_hallway_anchor: Node3D = $TransitionAnchors/PlayerTwoHallway
@onready var _player_one_downstairs_anchor: Node3D = $TransitionAnchors/PlayerOneDownstairs
@onready var _player_two_downstairs_anchor: Node3D = $TransitionAnchors/PlayerTwoDownstairs
@onready var _player_one_blocked_anchor: Node3D = $TransitionAnchors/PlayerOneBlocked
@onready var _player_two_blocked_anchor: Node3D = $TransitionAnchors/PlayerTwoBlocked
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
var _collapse_sequence_player_id: String = ""
var _collapse_sequence_time_left: float = 0.0
var _collapse_in_progress: bool = false
var _collapse_visual_active: bool = false
var _camera_shake_time_left: float = 0.0
var _dust_alpha: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_capture_autoloads()
	_connect_autoload_signals()
	_connect_local_signals()

	_debug_panel.visible = false
	_feed_lines = []
	for line in DEFAULT_FEED_LINES:
		_feed_lines.append(line)

	_area_card_title.text = "UPSTAIRS ROOM"
	_area_card_subtitle.text = "Enter the hallway, trigger the collapse, and prove the first real separation beat."
	if _companion_silhouette != null:
		_companion_silhouette.visible = false
	if _companion_zone != null:
		_companion_zone.monitoring = false
		_companion_zone.visible = false
	if _blocked_friend != null:
		_blocked_friend.visible = false

	_refresh_feed_label()
	_set_active_player(0)
	_start_run_if_possible()
	_set_collapse_visual_state(false)
	_sync_players_from_state(true)
	_refresh_prompt()
	_refresh_status()


func _process(delta: float) -> void:
	_presentation_time += delta
	_update_collapse_sequence(delta)
	_update_area_card(delta)
	_update_transition_overlay(delta)
	_update_dust_visual(delta)
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
		if _collapse_in_progress:
			_mark_input_handled()
			return
		_switch_active_player()
		_mark_input_handled()
		return

	if key_event.keycode == KEY_E:
		if _collapse_in_progress:
			_mark_input_handled()
			return
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
	_event_bus.connect("collapse_triggered", Callable(self, "_on_collapse_triggered"))


func _connect_local_signals() -> void:
	_player_one.focus_changed.connect(_on_player_focus_changed)
	_player_two.focus_changed.connect(_on_player_focus_changed)
	if _collapse_trigger != null:
		_collapse_trigger.body_entered.connect(_on_collapse_trigger_body_entered)

	var interactable_nodes: Array[Node] = get_tree().get_nodes_in_group("prototype_interactable")
	for node in interactable_nodes:
		var interactable: PrototypeInteractable3D = node as PrototypeInteractable3D
		if interactable == null:
			continue
		interactable.interacted.connect(_on_interactable_interacted)


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
		_show_area_card("HALLWAY THRESHOLD", "The hallway is only long enough to fail once.")
		_trigger_transition_flash(0.14)
	elif location == "Downstairs":
		_show_area_card("DOWNSTAIRS", "%s drops below while the other player stays upstairs." % _display_name(player_id))
		_trigger_transition_flash(0.26)
	elif location == "UpstairsRoom":
		_show_area_card("UPSTAIRS ROOM", "Back inside the room, with the threat still framed in the doorway.")


func _on_state_changed() -> void:
	_sync_players_from_state(false)


func _on_collapse_triggered(player_id: String) -> void:
	_set_collapse_visual_state(true)
	_position_non_triggering_player(player_id)
	_camera_shake_time_left = CAMERA_SHAKE_MAX_TIME
	_trigger_transition_flash(0.34)
	_show_area_card("FLOOR COLLAPSE", "%s is routed below. The upstairs path is gone." % _display_name(player_id))


func _on_collapse_trigger_body_entered(body: Node3D) -> void:
	if _collapse_in_progress or _is_floor_collapsed():
		return

	var player_id: String = _player_id_for_body(body)
	if player_id == "":
		return

	if _get_player_location(player_id) != "UpstairsHallway":
		return

	_start_collapse_sequence(player_id)


func _start_collapse_sequence(player_id: String) -> void:
	_collapse_in_progress = true
	_collapse_sequence_player_id = player_id
	_collapse_sequence_time_left = COLLAPSE_PRE_DELAY
	_camera_shake_time_left = 0.14
	_player_one.set_input_locked(true)
	_player_two.set_input_locked(true)
	_emit_bus_void("emit_prompt_changed", ["The floor gives one warning."])
	_emit_bus_void("emit_event_logged", ["A hard creak runs through the hallway boards.", "critical"])
	_emit_bus_void("emit_audio_requested", ["weak_floor_groan"])
	_show_area_card("WEAK FLOOR", "The house gives a single warning before it tears away.", 1.2)
	_trigger_transition_flash(0.10)


func _update_collapse_sequence(delta: float) -> void:
	if not _collapse_in_progress:
		return

	_collapse_sequence_time_left = max(0.0, _collapse_sequence_time_left - delta)
	if _collapse_sequence_time_left > 0.0:
		return

	var triggering_player_id: String = _collapse_sequence_player_id
	_collapse_in_progress = false
	_collapse_sequence_player_id = ""
	_call_scene_router_bool("attempt_hallway_cross", [triggering_player_id])
	_player_one.set_input_locked(false)
	_player_two.set_input_locked(false)


func _handle_doorway_interaction() -> void:
	var player_id: String = _active_player_id()
	var current_location: String = _get_player_location(player_id)

	if current_location == "UpstairsRoom":
		var moved_to_hallway: bool = _call_scene_router_bool("move_player_to_hallway", [player_id])
		if moved_to_hallway:
			_trigger_transition_flash(0.16)
		return

	if _is_floor_collapsed() and _is_player_upstairs(player_id):
		_call_scene_router_bool("inspect_collapsed_edge", [player_id])
		return

	if current_location == "UpstairsHallway":
		_push_feed_line("Keep moving. The weak section is a few steps farther in.")
		return

	_push_feed_line("That doorway only matters while the player is still upstairs.")


func _handle_hallway_edge_interaction() -> void:
	var player_id: String = _active_player_id()
	if not _is_floor_collapsed():
		_push_feed_line("The weak section has not collapsed yet.")
		return

	if not _is_player_upstairs(player_id):
		_push_feed_line("The floor is gone.")
		return

	_call_scene_router_bool("inspect_collapsed_edge", [player_id])


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
	var fade_color: Color = _transition_fade.color
	fade_color.a = _transition_fade_alpha
	_transition_fade.color = fade_color


func _update_dust_visual(delta: float) -> void:
	if _dust_plume == null:
		return

	if not _dust_plume.visible and _dust_alpha <= 0.0:
		return

	_dust_alpha = move_toward(_dust_alpha, 0.0, delta * 0.85)
	var dust_modulate: Color = _dust_plume.modulate
	dust_modulate.a = _dust_alpha
	_dust_plume.modulate = dust_modulate
	if _dust_alpha <= 0.01 and _collapse_visual_active:
		_dust_plume.visible = false


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
		prompt_text = "The floor is gone." if _is_floor_collapsed() else "Keep moving. The weak section is ahead."

	if _collapse_in_progress:
		prompt_text = "The hallway is giving way."

	_prompt_label.text = "%s // %s" % [active_player.get_display_name().to_upper(), prompt_text]


func _refresh_status() -> void:
	var active_player_name: String = _active_player_name()
	var active_location: String = _pretty_location(_get_player_location(_active_player_id()))
	var collapse_state: String = "Collapsed" if _is_floor_collapsed() else "Holding"
	_status_label.text = "%s | %s | Radio %s | Floor %s | Tab/Q switch | E interact | F1 debug" % [
		active_player_name,
		active_location,
		_radio_status,
		collapse_state
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
	var collapse_player_name: String = _collapse_triggered_by_name()
	_debug_label.text = "Prototype Room Debug\nActive: %s\nP1: %s [%s]\nP2: %s [%s]\nRadio: %s\nCollapse: %s\nPrompt: %s\nCursor: %s" % [
		_active_player_name(),
		_format_player_position(_player_one),
		_get_player_location(PLAYER_ONE_ID),
		_format_player_position(_player_two),
		_get_player_location(PLAYER_TWO_ID),
		_radio_status,
		collapse_player_name,
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
	var collapse_ratio: float = 1.0 if _is_floor_collapsed() else 0.0

	var target_window_energy: float = 2.15 + focus_ratio * 0.28
	var target_door_energy: float = 1.45 + hallway_ratio * 0.48 + collapse_ratio * 0.22
	var target_hallway_fill_energy: float = 1.05 + hallway_ratio * 0.36 - collapse_ratio * 0.16
	var target_downstairs_fill_energy: float = 0.55 + collapse_ratio * 0.72
	var target_player_key_energy: float = 1.68 + motion_ratio * 0.40
	var target_companion_rim_energy: float = 0.95 + focus_ratio * 0.18
	var target_lamp_energy: float = 2.05 - focus_ratio * 0.08

	_window_beam.light_energy = move_toward(_window_beam.light_energy, target_window_energy, delta * LIGHT_LERP_SPEED)
	_door_spill.light_energy = move_toward(_door_spill.light_energy, target_door_energy, delta * LIGHT_LERP_SPEED)
	_hallway_fill_light.light_energy = move_toward(_hallway_fill_light.light_energy, target_hallway_fill_energy, delta * LIGHT_LERP_SPEED)
	_downstairs_fill_light.light_energy = move_toward(_downstairs_fill_light.light_energy, target_downstairs_fill_energy, delta * LIGHT_LERP_SPEED)
	_player_key_light.light_energy = move_toward(_player_key_light.light_energy, target_player_key_energy, delta * LIGHT_LERP_SPEED)
	_companion_rim_light.light_energy = move_toward(_companion_rim_light.light_energy, target_companion_rim_energy, delta * LIGHT_LERP_SPEED)
	_lamp_light.light_energy = move_toward(_lamp_light.light_energy, target_lamp_energy, delta * LIGHT_LERP_SPEED)

	var camera_rotation: Vector3 = active_camera.rotation
	camera_rotation.z = lerp_angle(camera_rotation.z, -motion_ratio * 0.01, min(1.0, delta * 2.6))
	active_camera.rotation = camera_rotation

	if _camera_shake_time_left > 0.0:
		var shake_ratio: float = clamp(_camera_shake_time_left / CAMERA_SHAKE_MAX_TIME, 0.0, 1.0)
		var camera_position: Vector3 = active_camera.position
		camera_position.x += sin(_presentation_time * 62.0) * 0.045 * shake_ratio
		camera_position.y += cos(_presentation_time * 49.0) * 0.03 * shake_ratio
		active_camera.position = camera_position
		_camera_shake_time_left = max(0.0, _camera_shake_time_left - delta)


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


func _player_for_id(player_id: String) -> PrototypePlayer3D:
	return _player_one if player_id == PLAYER_ONE_ID else _player_two


func _player_id_for_body(body: Node3D) -> String:
	if body == _player_one:
		return PLAYER_ONE_ID
	if body == _player_two:
		return PLAYER_TWO_ID
	return ""


func _format_player_position(player_node: PrototypePlayer3D) -> String:
	if player_node == null:
		return "(missing)"

	return "(%.2f, %.2f, %.2f)" % [
		player_node.global_position.x,
		player_node.global_position.y,
		player_node.global_position.z
	]


func _sync_players_from_state(force_sync: bool) -> void:
	_sync_player_position(
		_player_one,
		PLAYER_ONE_ID,
		_player_one_room_anchor,
		_player_one_hallway_anchor,
		_player_one_downstairs_anchor,
		force_sync
	)
	_sync_player_position(
		_player_two,
		PLAYER_TWO_ID,
		_player_two_room_anchor,
		_player_two_hallway_anchor,
		_player_two_downstairs_anchor,
		force_sync
	)


func _sync_player_position(
	player_node: PrototypePlayer3D,
	player_id: String,
	room_anchor: Node3D,
	hallway_anchor: Node3D,
	downstairs_anchor: Node3D,
	force_sync: bool
) -> void:
	if player_node == null:
		return

	var location: String = _get_player_location(player_id)
	var previous_location: String = ""
	if _last_player_locations.has(player_id):
		previous_location = str(_last_player_locations[player_id])

	if not force_sync and location == previous_location:
		return

	var anchor: Node3D = room_anchor
	match location:
		"UpstairsRoom":
			anchor = room_anchor
		"UpstairsHallway":
			anchor = hallway_anchor
		"Downstairs":
			anchor = downstairs_anchor
		_:
			anchor = room_anchor

	player_node.snap_to_marker(anchor)
	_last_player_locations[player_id] = location


func _position_non_triggering_player(triggering_player_id: String) -> void:
	var other_player_id: String = _other_player_id(triggering_player_id)
	if not _is_player_upstairs(other_player_id):
		return

	var other_player: PrototypePlayer3D = _player_for_id(other_player_id)
	var blocked_anchor: Node3D = _player_one_blocked_anchor if other_player_id == PLAYER_ONE_ID else _player_two_blocked_anchor
	if other_player == null or blocked_anchor == null:
		return

	other_player.snap_to_marker(blocked_anchor)


func _doorway_prompt_for(active_player: PrototypePlayer3D) -> String:
	if active_player == null:
		return "Move closer to the doorway"

	var player_id: String = PLAYER_ONE_ID if active_player == _player_one else PLAYER_TWO_ID
	if _is_floor_collapsed() and _is_player_upstairs(player_id):
		return "The floor is gone."

	var location: String = _get_player_location(player_id)
	if location == "UpstairsHallway":
		return "Move deeper into the weak section"

	return "Press E - enter hallway"


func _show_area_card(title: String, subtitle: String, duration: float = AREA_CARD_BEAT_DURATION) -> void:
	_area_card_title.text = title
	_area_card_subtitle.text = subtitle
	_area_card_duration_current = duration
	_title_card_time_left = duration
	_area_card.modulate.a = 1.0
	_area_card.visible = true


func _trigger_transition_flash(target_alpha: float) -> void:
	_transition_fade_alpha = maxf(_transition_fade_alpha, target_alpha)


func _set_collapse_visual_state(collapsed: bool) -> void:
	_collapse_visual_active = collapsed
	if _hallway_weak_panel != null:
		_hallway_weak_panel.visible = not collapsed
		_hallway_weak_panel.use_collision = not collapsed
	if _hallway_runner != null:
		_hallway_runner.visible = not collapsed
	if _hallway_hole_void != null:
		_hallway_hole_void.visible = collapsed
	if _collapse_barrier != null:
		_collapse_barrier.visible = collapsed
		_collapse_barrier.use_collision = collapsed
	if _downstairs_placeholder != null:
		_downstairs_placeholder.visible = collapsed
	if _downstairs_fill_light != null:
		_downstairs_fill_light.visible = collapsed
	if _collapse_trigger != null:
		_collapse_trigger.monitoring = not collapsed
	if _hallway_edge_zone != null:
		_hallway_edge_zone.monitoring = collapsed
		_hallway_edge_zone.monitorable = collapsed
	if _dust_plume != null:
		_dust_plume.visible = collapsed
		_dust_alpha = 0.78 if collapsed else 0.0
		var dust_modulate: Color = _dust_plume.modulate
		dust_modulate.a = _dust_alpha
		_dust_plume.modulate = dust_modulate


func _display_name(player_id: String) -> String:
	if _game_state == null:
		return player_id

	return str(_game_state.call("get_player_display_name", player_id))


func _get_player_location(player_id: String) -> String:
	if _game_state == null:
		return "UpstairsRoom"

	return str(_game_state.call("get_player_location", player_id))


func _is_player_upstairs(player_id: String) -> bool:
	var location: String = _get_player_location(player_id)
	return location == "UpstairsRoom" or location == "UpstairsHallway" or location == "Bedroom"


func _is_floor_collapsed() -> bool:
	if _game_state == null:
		return false

	return bool(_game_state.get("floor_collapsed"))


func _collapse_triggered_by_name() -> String:
	if _game_state == null:
		return "Nobody"

	var triggering_player_id: String = str(_game_state.get("collapse_triggered_by"))
	if triggering_player_id == "":
		return "Nobody"

	return _display_name(triggering_player_id)


func _other_player_id(player_id: String) -> String:
	return PLAYER_TWO_ID if player_id == PLAYER_ONE_ID else PLAYER_ONE_ID


func _pretty_location(location: String) -> String:
	match location:
		"UpstairsRoom":
			return "Upstairs Room"
		"UpstairsHallway":
			return "Hallway"
		"Downstairs":
			return "Downstairs"
		_:
			return location


func _call_scene_router_bool(method_name: String, args: Array) -> bool:
	if _scene_router == null:
		_push_feed_line("SceneRouter is unavailable in this prototype build.")
		return false

	return bool(_scene_router.callv(method_name, args))


func _emit_bus_void(method_name: String, args: Array) -> void:
	if _event_bus == null:
		return

	_event_bus.callv(method_name, args)


func _mark_input_handled() -> void:
	# Guardrail: using viewport handling here avoids the recurring accept_event() issue.
	get_viewport().set_input_as_handled()
