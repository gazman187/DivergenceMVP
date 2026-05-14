extends Area3D
class_name PrototypeInteractable3D

signal interacted(interactable_id: String, message_text: String)

@export var interactable_id: String = ""
@export var prompt_text: String = "Inspect"
@export_multiline var message_text: String = ""

@onready var _highlight: Node3D = get_node_or_null("Highlight") as Node3D


func _ready() -> void:
	monitoring = true
	monitorable = true
	_set_highlight_visible(false)


func get_prompt_text() -> String:
	return "E // %s" % prompt_text


func interact() -> bool:
	interacted.emit(interactable_id, message_text)
	return true


func set_focus_enabled(enabled: bool) -> void:
	_set_highlight_visible(enabled)


func _set_highlight_visible(enabled: bool) -> void:
	if _highlight == null:
		return

	_highlight.visible = enabled
