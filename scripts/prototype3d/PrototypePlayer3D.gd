extends CharacterBody3D
class_name PrototypePlayer3D

signal focus_changed

const GRAVITY_FORCE: float = 24.0
const MAX_LOOK_UP: float = deg_to_rad(65.0)
const MAX_LOOK_DOWN: float = deg_to_rad(-50.0)

@export var move_speed: float = 5.2
@export var acceleration: float = 18.0
@export var mouse_sensitivity: float = 0.0026

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _sensor: Area3D = $InteractionSensor
@onready var _body_visuals: Node3D = $Visuals

var _nearby_interactables: Array[PrototypeInteractable3D] = []
var _current_interactable: PrototypeInteractable3D = null


func _ready() -> void:
	_sensor.area_entered.connect(_on_sensor_area_entered)
	_sensor.area_exited.connect(_on_sensor_area_exited)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	_yaw_pivot.rotate_y(-mouse_motion.relative.x * mouse_sensitivity)
	var next_pitch: float = _pitch_pivot.rotation.x - mouse_motion.relative.y * mouse_sensitivity
	_pitch_pivot.rotation.x = clamp(next_pitch, MAX_LOOK_DOWN, MAX_LOOK_UP)


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = _read_move_input()
	var desired_velocity: Vector3 = _calculate_desired_velocity(input_vector)

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	if is_on_floor():
		velocity.y = -0.01
	else:
		velocity.y -= GRAVITY_FORCE * delta

	move_and_slide()
	_update_visual_heading(input_vector, delta)
	_refresh_current_interactable()


func get_current_prompt() -> String:
	if _current_interactable == null:
		return "Walk the room. Step close to an object or character to inspect it."

	return _current_interactable.get_prompt_text()


func get_focus_name() -> String:
	if _current_interactable == null:
		return "None"

	return _current_interactable.prompt_text


func try_interact() -> bool:
	if _current_interactable == null:
		return false

	return _current_interactable.interact()


func _read_move_input() -> Vector2:
	var horizontal: float = 0.0
	var vertical: float = 0.0

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical -= 1.0

	return Vector2(horizontal, vertical).normalized()


func _calculate_desired_velocity(input_vector: Vector2) -> Vector3:
	var forward: Vector3 = -_yaw_pivot.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right: Vector3 = _yaw_pivot.global_basis.x
	right.y = 0.0
	right = right.normalized()

	return (right * input_vector.x + forward * input_vector.y) * move_speed


func _update_visual_heading(input_vector: Vector2, delta: float) -> void:
	if input_vector.length() <= 0.0:
		return

	var target_yaw: float = atan2(-velocity.x, -velocity.z)
	_body_visuals.rotation.y = lerp_angle(_body_visuals.rotation.y, target_yaw, min(1.0, delta * 8.0))


func _on_sensor_area_entered(area: Area3D) -> void:
	var interactable: PrototypeInteractable3D = area as PrototypeInteractable3D
	if interactable == null:
		return

	if not _nearby_interactables.has(interactable):
		_nearby_interactables.append(interactable)
	_refresh_current_interactable()


func _on_sensor_area_exited(area: Area3D) -> void:
	var interactable: PrototypeInteractable3D = area as PrototypeInteractable3D
	if interactable == null:
		return

	_nearby_interactables.erase(interactable)
	_refresh_current_interactable()


func _refresh_current_interactable() -> void:
	var next_interactables: Array[PrototypeInteractable3D] = []
	var best_interactable: PrototypeInteractable3D = null
	var best_score: float = INF

	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue

		next_interactables.append(interactable)
		var offset: Vector3 = interactable.global_position - global_position
		var distance_score: float = offset.length()
		var facing_score: float = 0.0
		if distance_score > 0.001:
			var facing_direction: Vector3 = -_yaw_pivot.global_basis.z
			facing_direction.y = 0.0
			facing_direction = facing_direction.normalized()
			facing_score = facing_direction.dot(offset.normalized())

		var score: float = distance_score - facing_score * 0.85
		if score < best_score:
			best_score = score
			best_interactable = interactable

	_nearby_interactables = next_interactables
	if _current_interactable == best_interactable:
		for interactable in _nearby_interactables:
			interactable.set_focus_enabled(interactable == _current_interactable)
		return

	_current_interactable = best_interactable
	for interactable in _nearby_interactables:
		interactable.set_focus_enabled(interactable == _current_interactable)
	focus_changed.emit()
