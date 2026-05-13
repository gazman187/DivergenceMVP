extends Node
class_name Interactable

@export var interaction_label: String = "Interact"
@export var is_enabled: bool = true


func interact(player_id: String) -> bool:
	if not is_enabled:
		_emit_prompt("Nothing happens.")
		return false

	return true


func _emit_prompt(text: String) -> void:
	EventBus.emit_prompt_changed(text)


func _player_name(player_id: String) -> String:
	return GameState.get_player_display_name(player_id)
