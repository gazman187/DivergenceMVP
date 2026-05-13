extends Interactable
class_name Door

@export var target_location: String = "Outside"
@export var locked: bool = false
@export var required_item: String = ""


func interact(player_id: String) -> bool:
	if not super.interact(player_id):
		return false

	var can_bypass_lock := target_location == "Shed" and GameState.shed_unlocked
	if locked and not can_bypass_lock and required_item != "" and not GameState.player_has_item(player_id, required_item):
		_emit_prompt("%s needs the bedroom key for this route." % _player_name(player_id))
		return false

	match target_location:
		"UpstairsHallway":
			return SceneRouter.move_player_to_hallway(player_id)
		"Outside":
			return _route_to_outside(player_id)
		"WoodsEdge":
			return SceneRouter.toggle_woods_edge(player_id)
		"Shed":
			var entered := SceneRouter.interact_with_shed(player_id)
			if entered and GameState.shed_unlocked:
				locked = false
			return entered
		"Bedroom":
			return SceneRouter.route_player_to_bedroom(player_id)
		_:
			_emit_prompt("This door is a placeholder and does not lead anywhere yet.")
			return false


func _route_to_outside(player_id: String) -> bool:
	match GameState.get_player_location(player_id):
		"Bedroom":
			return SceneRouter.escape_bedroom_via_window(player_id)
		"Downstairs":
			return SceneRouter.move_downstairs_to_outside(player_id)
		"Shed":
			return SceneRouter.leave_shed(player_id)
		"WoodsEdge":
			return SceneRouter.toggle_woods_edge(player_id)
		_:
			_emit_prompt("%s cannot reach outside from here using this placeholder door." % _player_name(player_id))
			return false
