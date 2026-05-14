extends Node2D
class_name GreyboxLocation

@export var location_id: String = ""
@export var camera_zoom: float = 1.0
@export var post_collapse_camera_zoom: float = 1.0


func _ready() -> void:
	EventBus.state_changed.connect(_refresh_visual_state)
	_set_canvas_item_visible("Title", false)
	_set_canvas_item_visible("Description", false)
	_refresh_visual_state()


func get_spawn_position(player_id: String) -> Vector2:
	var marker_name: String = "Player1Spawn" if player_id == GameState.PLAYER_1_ID else "Player2Spawn"
	var marker: Marker2D = get_node_or_null(marker_name) as Marker2D
	if marker != null:
		return position + marker.position

	return position


func get_camera_focus_position() -> Vector2:
	var marker_name: String = "PostCollapseCameraFocus" if GameState.floor_collapsed else "CameraFocus"
	var marker: Marker2D = get_node_or_null(marker_name) as Marker2D
	if marker == null and GameState.floor_collapsed:
		marker = get_node_or_null("CameraFocus") as Marker2D

	if marker != null:
		return position + marker.position

	var player_one_marker: Marker2D = get_node_or_null("Player1Spawn") as Marker2D
	var player_two_marker: Marker2D = get_node_or_null("Player2Spawn") as Marker2D
	if player_one_marker != null and player_two_marker != null:
		return position + ((player_one_marker.position + player_two_marker.position) * 0.5)

	return position


func get_camera_zoom_value() -> float:
	if GameState.floor_collapsed and post_collapse_camera_zoom > 0.0:
		return post_collapse_camera_zoom

	return camera_zoom


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
