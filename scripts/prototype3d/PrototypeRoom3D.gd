extends Node3D
class_name PrototypeRoom3D

const TITLE_CARD_DURATION: float = 4.5
const MAX_FEED_LINES: int = 3

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
@onready var _area_card: Control = $UI/AreaCard
@onready var _area_card_title: Label = $UI/AreaCard/Margin/VBox/AreaTitle
@onready var _area_card_subtitle: Label = $UI/AreaCard/Margin/VBox/AreaSubtitle
@onready var _prompt_label: Label = $UI/PromptPanel/Margin/PromptLabel
@onready var _feed_label: Label = $UI/NarrativePanel/Margin/VBox/FeedLabel
@onready var _status_label: Label = $UI/StatusPanel/Margin/VBox/StatusLabel
@onready var _debug_panel: PanelContainer = $UI/DebugPanel
@onready var _debug_label: Label = $UI/DebugPanel/Margin/DebugLabel

var _title_card_time_left: float = TITLE_CARD_DURATION
var _feed_lines: Array[String] = []


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
	_area_card_subtitle.text = "One playable vertical slice. Readability first, atmosphere second."
	_debug_panel.visible = false
	_feed_lines = []
	for line in DEFAULT_FEED_LINES:
		_feed_lines.append(line)
	_refresh_feed_label()
	_refresh_prompt()
	_status_label.text = "WASD move  |  Mouse look  |  E inspect  |  Esc release cursor  |  F1 debug"


func _process(delta: float) -> void:
	_update_area_card(delta)
	_refresh_prompt()
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
