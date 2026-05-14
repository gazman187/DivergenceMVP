extends Node3D
class_name PrototypeRoom3D

const TITLE_CARD_DURATION: float = 4.5
const MAX_FEED_LINES: int = 3
const CHARACTER_IDLE_SPEED: float = 1.35
const LIGHT_LERP_SPEED: float = 2.2

const DEFAULT_FEED_LINES: Array[String] = [
	"You arrive upstairs before the collapse. The room should read clearly at a glance."
]

const INTERACTION_FEED: Dictionary = {
	"radio": "The radio hisses with no carrier, only stressed wiring and room tone.",
	"window": "Cold moonlight cuts a clean route through the room.",
	"weak_floor": "The floorboards flex at the threshold. This is where the house will fail.",
	"companion": "Your companion keeps one eye on the door and one on you.",
	"blocked_door": "The hallway is close enough to matter and unsafe enough to fear."
}

@onready var _player: PrototypePlayer3D = $Player as PrototypePlayer3D
@onready var _camera: Camera3D = $Player/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var _area_card: Control = $UI/AreaCard
@onready var _area_card_title: Label = $UI/AreaCard/Margin/VBox/AreaTitle
@onready var _area_card_subtitle: Label = $UI/AreaCard/Margin/VBox/AreaSubtitle
@onready var _prompt_label: Label = $UI/PromptPanel/Margin/PromptLabel
@onready var _feed_label: Label = $UI/NarrativePanel/Margin/VBox/FeedLabel
@onready var _status_label: Label = $UI/StatusPanel/Margin/VBox/StatusLabel
@onready var _debug_panel: PanelContainer = $UI/DebugPanel
@onready var _debug_label: Label = $UI/DebugPanel/Margin/DebugLabel
@onready var _companion: Node3D = $Characters/Companion
@onready var _blocked_friend: Node3D = $Characters/BlockedFriend
@onready var _lamp_light: OmniLight3D = $LampLight
@onready var _door_spill: SpotLight3D = $DoorSpill
@onready var _window_beam: SpotLight3D = $WindowBeam
@onready var _player_key_light: SpotLight3D = $PlayerKeyLight
@onready var _companion_rim_light: SpotLight3D = $CompanionRimLight

var _title_card_time_left: float = TITLE_CARD_DURATION
var _feed_lines: Array[String] = []
var _presentation_time: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_player.focus_changed.connect(_on_player_focus_changed)

	var interactable_nodes: Array[Node] = get_tree().get_nodes_in_group("prototype_interactable")
	for node in interactable_nodes:
		var interactable: PrototypeInteractable3D = node as PrototypeInteractable3D
		if interactable == null:
			continue
		interactable.interacted.connect(_on_interactable_interacted)

	_area_card_title.text = "UPSTAIRS ROOM"
	_area_card_subtitle.text = "An embodied vertical slice with a clear threat line and a room you can actually read."
	_debug_panel.visible = false
	_feed_lines = []
	for line in DEFAULT_FEED_LINES:
		_feed_lines.append(line)
	_refresh_feed_label()
	_refresh_prompt()
	_status_label.text = "WASD move  |  Mouse look  |  E inspect  |  Esc release cursor  |  F1 debug"


func _process(delta: float) -> void:
	_presentation_time += delta
	_update_area_card(delta)
	_refresh_prompt()
	_update_character_embodiment(delta)
	_update_lighting_mood(delta)
	_refresh_debug_text()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_E:
		_player.try_interact()
		accept_event()
		return

	if key_event.keycode == KEY_ESCAPE:
		_toggle_mouse_capture()
		accept_event()
		return

	if key_event.keycode == KEY_F1:
		_debug_panel.visible = not _debug_panel.visible
		accept_event()


func _on_player_focus_changed() -> void:
	_refresh_prompt()


func _on_interactable_interacted(interactable_id: String, message_text: String) -> void:
	var feed_text: String = message_text
	if INTERACTION_FEED.has(interactable_id):
		feed_text = str(INTERACTION_FEED[interactable_id])

	_push_feed_line(feed_text)


func _update_area_card(delta: float) -> void:
	if _title_card_time_left <= 0.0:
		_area_card.visible = false
		return

	_title_card_time_left = max(0.0, _title_card_time_left - delta)
	_area_card.visible = true

	var fade_strength: float = min(1.0, _title_card_time_left / TITLE_CARD_DURATION)
	var alpha: float = min(1.0, fade_strength * 1.2)
	if _title_card_time_left < 1.0:
		alpha = _title_card_time_left

	_area_card.modulate.a = alpha


func _refresh_prompt() -> void:
	_prompt_label.text = _player.get_current_prompt()


func _refresh_feed_label() -> void:
	_feed_label.text = "\n".join(_feed_lines)


func _push_feed_line(line: String) -> void:
	if line == "":
		return

	_feed_lines.append(line)
	while _feed_lines.size() > MAX_FEED_LINES:
		_feed_lines.remove_at(0)
	_refresh_feed_label()


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_push_feed_line("Cursor released for inspection.")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_push_feed_line("Back in the room.")


func _refresh_debug_text() -> void:
	var position_text: String = "(%.2f, %.2f, %.2f)" % [
		_player.global_position.x,
		_player.global_position.y,
		_player.global_position.z
	]
	var cursor_mode: String = "Captured" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "Free"
	_debug_label.text = "Prototype Room Debug\nFocus: %s\nPosition: %s\nCursor: %s" % [
		_player.get_focus_name(),
		position_text,
		cursor_mode
	]


func _update_character_embodiment(delta: float) -> void:
	var companion_position: Vector3 = _companion.position
	companion_position.y = sin(_presentation_time * CHARACTER_IDLE_SPEED) * 0.035
	_companion.position = companion_position
	_companion.rotation.y = lerp_angle(_companion.rotation.y, 2.61799 + sin(_presentation_time * 0.7) * 0.08, min(1.0, delta * 1.8))

	var blocked_position: Vector3 = _blocked_friend.position
	blocked_position.y = sin(_presentation_time * (CHARACTER_IDLE_SPEED + 0.22) + 0.9) * 0.024
	_blocked_friend.position = blocked_position
	_blocked_friend.rotation.y = lerp_angle(_blocked_friend.rotation.y, -1.65806 + sin(_presentation_time * 0.82) * 0.05, min(1.0, delta * 1.6))


func _update_lighting_mood(delta: float) -> void:
	var motion_ratio: float = _player.get_motion_ratio()
	var focus_ratio: float = 1.0 if _player.has_focus_interactable() else 0.0

	var target_window_energy: float = 2.2 + focus_ratio * 0.55
	var target_door_energy: float = 1.5 + focus_ratio * 0.25
	var target_player_key_energy: float = 1.75 + motion_ratio * 0.45
	var target_companion_rim_energy: float = 1.25 + focus_ratio * 0.5
	var target_lamp_energy: float = 2.2 - focus_ratio * 0.2

	_window_beam.light_energy = move_toward(_window_beam.light_energy, target_window_energy, delta * LIGHT_LERP_SPEED)
	_door_spill.light_energy = move_toward(_door_spill.light_energy, target_door_energy, delta * LIGHT_LERP_SPEED)
	_player_key_light.light_energy = move_toward(_player_key_light.light_energy, target_player_key_energy, delta * LIGHT_LERP_SPEED)
	_companion_rim_light.light_energy = move_toward(_companion_rim_light.light_energy, target_companion_rim_energy, delta * LIGHT_LERP_SPEED)
	_lamp_light.light_energy = move_toward(_lamp_light.light_energy, target_lamp_energy, delta * LIGHT_LERP_SPEED)

	var camera_rotation: Vector3 = _camera.rotation
	camera_rotation.z = lerp_angle(camera_rotation.z, -motion_ratio * 0.01, min(1.0, delta * 2.6))
	_camera.rotation = camera_rotation
