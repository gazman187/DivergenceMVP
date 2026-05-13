extends Interactable
class_name TriggerZone

@export var trigger_action: String = "hallway_collapse"


func interact(player_id: String) -> bool:
	if not super.interact(player_id):
		return false

	if trigger_action == "hallway_collapse":
		return SceneRouter.attempt_hallway_cross(player_id)
	if trigger_action == "collapsed_edge":
		return SceneRouter.inspect_collapsed_edge(player_id)

	_emit_prompt("This trigger is only a greybox placeholder.")
	return false
