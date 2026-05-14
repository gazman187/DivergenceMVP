extends Area3D
class_name PrototypeInteractable3D

signal interacted(interactable_id: String, message_text: String)

@export var interactable_id: String = ""
@export var prompt_text: String = "Inspect"
@export_multiline var message_text: String = ""

@onready var _highlight: Node3D = get_node_or_null("Highlight") as Node3D

var _highlight_base_scale: Vector3 = Vector3.ONE
var _pulse_time: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true
	if _highlight != null:
		_highlight_base_scale = _highlight.scale
	_set_highlight_visible(false)


func _process(delta: float) -> void:
	if _highlight == null or not _highlight.visible:
		return

	_pulse_time += delta
	var pulse_scale: float = 1.0 + sin(_pulse_time * 3.2) * 0.045
	_highlight.scale = _highlight_base_scale * pulse_scale


func get_prompt_text() -> String:
	return "Press E - %s" % prompt_text


func interact() -> bool:
	interacted.emit(interactable_id, message_text)
	return true


func set_focus_enabled(enabled: bool) -> void:
	_set_highlight_visible(enabled)


func _set_highlight_visible(enabled: bool) -> void:
	if _highlight == null:
		return

	_highlight.visible = enabled
	if not enabled:
		_highlight.scale = _highlight_base_scale
