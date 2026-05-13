extends CharacterBody2D
class_name PlayerPawn

signal interaction_zone_changed(player_id: String, zone: WorldInteractionZone)

const FOOTSTEP_INTERVAL := 0.36

@export var player_id: String = ""
@export var display_name: String = "Player"
@export var move_speed: float = 170.0
@export var body_color: Color = Color(0.82, 0.54, 0.36, 1.0)
@export var outline_color: Color = Color(0.95, 0.92, 0.78, 1.0)

@onready var _outline: Polygon2D = $Outline
@onready var _body: Polygon2D = $Body
@onready var _name_label: Label = $NameLabel
@onready var _sensor: Area2D = $InteractionSensor

var is_selected: bool = false
var _nearby_zones: Array[WorldInteractionZone] = []
var _current_zone: WorldInteractionZone = null
var _footstep_timer: float = 0.0


func _ready() -> void:
	_outline.color = outline_color
	_body.color = body_color
	_name_label.text = display_name
	_sensor.area_entered.connect(_on_sensor_area_entered)
	_sensor.area_exited.connect(_on_sensor_area_exited)
	_apply_selection_visuals()


func _physics_process(delta: float) -> void:
	if not is_selected:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector: Vector2 = _read_movement_input()
	velocity = input_vector * move_speed
	move_and_slide()
	_update_footsteps(delta, input_vector)


func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return

	is_selected = selected
	_apply_selection_visuals()
	_refresh_current_zone()


func sync_to_position(world_position: Vector2) -> void:
	position = world_position
	velocity = Vector2.ZERO
	_refresh_current_zone()


func try_interact() -> bool:
	if _current_zone == null:
		return false

	return _current_zone.try_interact(player_id)


func get_current_prompt() -> String:
	if _current_zone == null:
		return ""

	return _current_zone.get_prompt_text(player_id)


func _read_movement_input() -> Vector2:
	var horizontal: float = 0.0
	var vertical: float = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical += 1.0

	return Vector2(horizontal, vertical).normalized()


func _update_footsteps(delta: float, input_vector: Vector2) -> void:
	if input_vector.length() <= 0.0:
		_footstep_timer = 0.0
		return

	_footstep_timer += delta
	if _footstep_timer < FOOTSTEP_INTERVAL:
		return

	_footstep_timer = 0.0
	EventBus.emit_audio_requested(_footstep_event_for_location())


func _footstep_event_for_location() -> String:
	var location: String = GameState.get_player_location(player_id)
	if location == "Outside" or location == "WoodsEdge":
		return "brush_step"
	if location == "UpstairsHallway":
		return "footstep_creak"
	return "footstep_soft"


func _on_sensor_area_entered(area: Area2D) -> void:
	var zone: WorldInteractionZone = area as WorldInteractionZone
	if zone == null:
		return

	if not _nearby_zones.has(zone):
		_nearby_zones.append(zone)

	_refresh_current_zone()


func _on_sensor_area_exited(area: Area2D) -> void:
	var zone: WorldInteractionZone = area as WorldInteractionZone
	if zone == null:
		return

	_nearby_zones.erase(zone)
	_refresh_current_zone()


func _refresh_current_zone() -> void:
	var previous_zone: WorldInteractionZone = _current_zone
	var best_zone: WorldInteractionZone = null
	var best_distance: float = INF
	var next_zones: Array[WorldInteractionZone] = []

	for zone in _nearby_zones:
		if not is_instance_valid(zone):
			continue
		if not zone.matches_player_location(player_id):
			continue

		next_zones.append(zone)
		var distance_to_zone: float = global_position.distance_to(zone.global_position)
		if distance_to_zone < best_distance:
			best_distance = distance_to_zone
			best_zone = zone

	_nearby_zones = next_zones
	_current_zone = best_zone

	for zone in _nearby_zones:
		zone.set_focus_enabled(player_id, is_selected and zone == _current_zone)

	if previous_zone != null and not _nearby_zones.has(previous_zone):
		previous_zone.set_focus_enabled(player_id, false)

	if previous_zone != _current_zone:
		interaction_zone_changed.emit(player_id, _current_zone)


func _apply_selection_visuals() -> void:
	_outline.visible = is_selected
	_name_label.modulate = Color(1.0, 0.97, 0.88, 1.0) if is_selected else Color(0.82, 0.82, 0.82, 1.0)
