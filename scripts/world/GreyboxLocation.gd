extends Node2D
class_name GreyboxLocation

@export var location_id: String = ""


func _ready() -> void:
	EventBus.state_changed.connect(_refresh_visual_state)
	_refresh_visual_state()


func get_spawn_position(player_id: String) -> Vector2:
	var marker_name: String = "Player1Spawn" if player_id == GameState.PLAYER_1_ID else "Player2Spawn"
	var marker: Marker2D = get_node_or_null(marker_name) as Marker2D
	if marker != null:
		return marker.global_position

	return global_position


func _refresh_visual_state() -> void:
	_set_canvas_item_visible("IntactFloor", not GameState.floor_collapsed)
	_set_canvas_item_visible("CollapsedGap", GameState.floor_collapsed)
	_set_canvas_item_visible("CollapsedDust", GameState.floor_collapsed)
	_set_canvas_item_visible("BedroomKeyProp", not GameState.bedroom_key_taken)
	_set_canvas_item_visible("ShedLockedGlow", not GameState.shed_unlocked)
	_set_canvas_item_visible("ShedUnlockedGlow", GameState.shed_unlocked)
	_apply_prefixed_visibility(self)

	var shed_door: Door = get_node_or_null("ShedDoorInteractable") as Door
	if shed_door != null:
		shed_door.locked = not GameState.shed_unlocked


func _set_canvas_item_visible(node_name: String, should_show: bool) -> void:
	var item: CanvasItem = get_node_or_null(node_name) as CanvasItem
	if item != null:
		item.visible = should_show


func _apply_prefixed_visibility(root: Node) -> void:
	for child_variant in root.get_children():
		var child: Node = child_variant as Node
		if child == null:
			continue

		var item: CanvasItem = child as CanvasItem
		var node_name: String = str(child.name)
		if item != null:
			if node_name.begins_with("PreCollapse"):
				item.visible = not GameState.floor_collapsed
			elif node_name.begins_with("PostCollapse"):
				item.visible = GameState.floor_collapsed
			elif node_name.begins_with("PreKeyTaken"):
				item.visible = not GameState.bedroom_key_taken
			elif node_name.begins_with("PostKeyTaken"):
				item.visible = GameState.bedroom_key_taken
			elif node_name.begins_with("PreShedUnlock"):
				item.visible = not GameState.shed_unlocked
			elif node_name.begins_with("PostShedUnlock"):
				item.visible = GameState.shed_unlocked

		_apply_prefixed_visibility(child)
