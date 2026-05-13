extends Interactable
class_name ItemPickup

@export var item_id: String = "bedroom_key"
@export var consumed: bool = false


func interact(player_id: String) -> bool:
	if not super.interact(player_id):
		return false

	if consumed or GameState.bedroom_key_taken:
		_emit_prompt("The bedroom key has already been taken.")
		return false

	if item_id == "bedroom_key":
		var was_taken := SceneRouter.search_bedroom_for_key(player_id)
		if was_taken:
			consumed = true
		return was_taken

	_emit_prompt("This pickup is only a greybox placeholder.")
	return false
