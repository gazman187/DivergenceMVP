extends Control
class_name UIManager

@onready var _prompt_label: Label = $InteractionPrompt/MarginContainer/PromptText
@onready var _radio_value: Label = $RadioStatus/MarginContainer/VBoxContainer/StatusValue
@onready var _cinematic: Control = $FloorCollapseCinematic


func _ready() -> void:
	EventBus.prompt_changed.connect(_on_prompt_changed)
	EventBus.radio_status_changed.connect(_on_radio_status_changed)
	EventBus.cinematic_requested.connect(_on_cinematic_requested)

	_prompt_label.text = "Prototype ready."
	_radio_value.text = "Clear"
	_cinematic.visible = false


func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text


func _on_radio_status_changed(status: String) -> void:
	_radio_value.text = status


func _on_cinematic_requested(scene_path: String) -> void:
	if scene_path == "res://scenes/cinematic/FloorCollapseCinematic.tscn":
		_play_floor_collapse_cinematic()


func _play_floor_collapse_cinematic() -> void:
	_show_collapse_sequence()


async func _show_collapse_sequence() -> void:
	_cinematic.visible = true
	await get_tree().create_timer(1.25).timeout
	_cinematic.visible = false
