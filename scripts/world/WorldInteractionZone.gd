extends Area2D
class_name WorldInteractionZone

@export var interactable_path: NodePath
@export var required_location: String = ""
@export var zone_label: String = ""
@export var hover_audio_event: String = ""

@onready var _highlight: CanvasItem = get_node_or_null("Highlight") as CanvasItem

var _focused_by_players: Array[String] = []


func _ready() -> void:
	monitoring = true
	monitorable = true
	input_pickable = false
	EventBus.state_changed.connect(_refresh_visual_state)
	_refresh_visual_state()


func matches_player_location(player_id: String) -> bool:
	if required_location == "":
		return true

	return GameState.get_player_location(player_id) == required_location


func get_prompt_text(player_id: String) -> String:
	if not matches_player_location(player_id):
		return ""

	var label: String = _resolve_prompt_label(player_id)
	if label == "":
		return ""

	return "E // %s" % label


func try_interact(player_id: String) -> bool:
	if not matches_player_location(player_id):
		return false

	var interactable: Interactable = _get_interactable()
	if interactable == null:
		return false

	return interactable.interact(player_id)


func set_focus_enabled(player_id: String, enabled: bool) -> void:
	if enabled:
		if not _focused_by_players.has(player_id):
			_focused_by_players.append(player_id)
			if hover_audio_event != "":
				EventBus.emit_audio_requested(hover_audio_event)
	else:
		_focused_by_players.erase(player_id)

	_refresh_visual_state()


func _resolve_prompt_label(player_id: String) -> String:
	var interactable: Interactable = _get_interactable()
	if interactable == null:
		return ""

	if interactable is TriggerZone:
		var trigger: TriggerZone = interactable as TriggerZone
		if trigger.trigger_action == "hallway_collapse" and GameState.floor_collapsed:
			return "The hallway is gone. You cannot follow."
		if trigger.trigger_action == "collapsed_edge":
			if GameState.floor_collapsed:
				return "Look over the broken edge"
			return "Study the sagging floorboards"

	if interactable is ItemPickup and GameState.bedroom_key_taken:
		return "The bedroom key is already gone."

	if interactable is Door:
		var door: Door = interactable as Door
		if door.target_location == "Shed":
			if GameState.shed_unlocked:
				return "Enter the optional shed"
			if not GameState.player_has_item(player_id, door.required_item):
				return "The shed is locked. The bedroom key will open it."
		elif door.target_location == "Bedroom":
			if not GameState.floor_collapsed:
				return "The bedroom route is only needed once the hallway gives way."
			return "Slip into the bedroom"
		elif door.target_location == "WoodsEdge":
			return "Push out to the woods edge"
		elif door.target_location == "Outside" and GameState.get_player_location(player_id) == "WoodsEdge":
			return "Return from the woods edge"

	if zone_label != "":
		return zone_label

	return interactable.interaction_label


func _get_interactable() -> Interactable:
	return get_node_or_null(interactable_path) as Interactable


func _refresh_visual_state() -> void:
	if _highlight == null:
		return

	var color: Color = Color(0.32, 0.56, 0.66, 0.22)
	if _focused_by_players.is_empty():
		color.a = 0.12
	else:
		var interactable: Interactable = _get_interactable()
		if interactable is TriggerZone:
			var trigger: TriggerZone = interactable as TriggerZone
			if GameState.floor_collapsed and trigger.trigger_action == "hallway_collapse":
				color = Color(0.82, 0.35, 0.28, 0.30)
			elif trigger.trigger_action == "collapsed_edge":
				color = Color(0.74, 0.66, 0.46, 0.26)
			else:
				color = Color(0.76, 0.84, 0.62, 0.26)
		else:
			color = Color(0.76, 0.84, 0.62, 0.26)

	if _highlight is ColorRect:
		var rect: ColorRect = _highlight as ColorRect
		rect.color = color
	elif _highlight is Polygon2D:
		var polygon: Polygon2D = _highlight as Polygon2D
		polygon.color = color
