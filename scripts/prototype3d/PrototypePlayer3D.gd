extends CharacterBody3D
class_name PrototypePlayer3D

signal focus_changed

const GRAVITY_FORCE: float = 24.0
const MAX_LOOK_UP: float = deg_to_rad(65.0)
const MAX_LOOK_DOWN: float = deg_to_rad(-50.0)
const BODY_SWAY_SPEED: float = 8.0
const CAMERA_SWAY_SPEED: float = 7.0

@export var move_speed: float = 5.2
@export var acceleration: float = 18.0
@export var mouse_sensitivity: float = 0.0026
@export var display_name: String = "Player"
@export var default_spring_length: float = 3.8
@export var focus_spring_length: float = 3.15
@export var default_fov: float = 56.0
@export var moving_fov: float = 59.0
@export var focus_fov: float = 52.0

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var _sensor: Area3D = $InteractionSensor
@onready var _body_visuals: Node3D = $Visuals
@onready var _body_mesh: MeshInstance3D = $Visuals/Body
@onready var _head_mesh: MeshInstance3D = $Visuals/Head
@onready var _selection_ring: MeshInstance3D = get_node_or_null("Visuals/SelectionRing") as MeshInstance3D

var _nearby_interactables: Array[PrototypeInteractable3D] = []
var _current_interactable: PrototypeInteractable3D = null
var _presentation_time: float = 0.0
var _is_active: bool = true
var _input_locked: bool = false


func _ready() -> void:
	_sensor.area_entered.connect(_on_sensor_area_entered)
	_sensor.area_exited.connect(_on_sensor_area_exited)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spring_arm.spring_length = default_spring_length
	_camera.fov = default_fov
	_apply_active_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active or _input_locked:
		return

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	if mouse_motion == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	_yaw_pivot.rotate_y(-mouse_motion.relative.x * mouse_sensitivity)
	var next_pitch: float = _pitch_pivot.rotation.x - mouse_motion.relative.y * mouse_sensitivity
	_pitch_pivot.rotation.x = clamp(next_pitch, MAX_LOOK_DOWN, MAX_LOOK_UP)


func _physics_process(delta: float) -> void:
	_presentation_time += delta

	if not _is_active:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if is_on_floor():
			velocity.y = -0.01
		else:
			velocity.y -= GRAVITY_FORCE * delta
		move_and_slide()
		_update_body_presentation(delta, Vector2.ZERO)
		_clear_focus()
		return

	var input_vector: Vector2 = Vector2.ZERO if _input_locked else _read_move_input()
	var desired_velocity: Vector3 = _calculate_desired_velocity(input_vector)

	velocity.x = move_toward(velocity.x, desired_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, acceleration * delta)
	if is_on_floor():
		velocity.y = -0.01
	else:
		velocity.y -= GRAVITY_FORCE * delta

	move_and_slide()
	_update_visual_heading(input_vector, delta)
	_update_body_presentation(delta, input_vector)
	_update_camera_presentation(delta, input_vector)
	_refresh_current_interactable()


func get_current_prompt() -> String:
	if _current_interactable == null:
		return "Walk the room. Step close to an object or character to inspect it."

	return _current_interactable.get_prompt_text()


func get_focus_name() -> String:
	if _current_interactable == null:
		return "None"

	return _current_interactable.prompt_text


func get_focus_interactable_id() -> String:
	if _current_interactable == null:
		return ""

	return _current_interactable.interactable_id


func get_display_name() -> String:
	return display_name


func get_camera() -> Camera3D:
	return _camera


func has_focus_interactable() -> bool:
	return _current_interactable != null


func get_motion_ratio() -> float:
	var planar_velocity: Vector2 = Vector2(velocity.x, velocity.z)
	if move_speed <= 0.001:
		return 0.0

	return clamp(planar_velocity.length() / move_speed, 0.0, 1.0)


func try_interact() -> bool:
	if not _is_active or _current_interactable == null:
		return false

	return _current_interactable.interact()


func set_active_state(is_active: bool) -> void:
	if _is_active == is_active:
		return

	_is_active = is_active
	_camera.current = is_active
	if not is_active:
		_clear_focus()
	_apply_active_visuals()


func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		velocity = Vector3.ZERO


func snap_to_marker(marker: Node3D) -> void:
	if marker == null:
		return

	global_position = marker.global_position
	velocity = Vector3.ZERO
	_yaw_pivot.global_rotation.y = marker.global_rotation.y
	_body_visuals.global_rotation.y = marker.global_rotation.y


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


func _update_body_presentation(delta: float, input_vector: Vector2) -> void:
	var motion_ratio: float = get_motion_ratio()
	var breathing_offset: float = sin(_presentation_time * 1.6) * 0.035
	var bob_offset: float = sin(_presentation_time * (4.2 + motion_ratio * 5.4)) * 0.075 * motion_ratio
	var target_body_height: float = 0.03 + breathing_offset + bob_offset
	var current_body_position: Vector3 = _body_visuals.position
	current_body_position.y = move_toward(current_body_position.y, target_body_height, delta * BODY_SWAY_SPEED)
	_body_visuals.position = current_body_position

	var target_roll: float = deg_to_rad(-input_vector.x * 7.5 * max(0.22, motion_ratio))
	var target_pitch: float = deg_to_rad(1.8 + motion_ratio * 4.4)
	var current_rotation: Vector3 = _body_visuals.rotation
	current_rotation.x = lerp_angle(current_rotation.x, target_pitch, min(1.0, delta * BODY_SWAY_SPEED))
	current_rotation.z = lerp_angle(current_rotation.z, target_roll, min(1.0, delta * BODY_SWAY_SPEED))
	_body_visuals.rotation = current_rotation

	if _head_mesh != null:
		var head_position: Vector3 = _head_mesh.position
		head_position.y = 1.66 + sin(_presentation_time * 2.0) * 0.018 + motion_ratio * 0.012
		_head_mesh.position = head_position
		var head_rotation: Vector3 = _head_mesh.rotation
		head_rotation.z = lerp_angle(head_rotation.z, -target_roll * 0.45, min(1.0, delta * BODY_SWAY_SPEED))
		_head_mesh.rotation = head_rotation

	if _body_mesh != null:
		_body_mesh.rotation.x = lerp_angle(_body_mesh.rotation.x, deg_to_rad(motion_ratio * 2.4), min(1.0, delta * BODY_SWAY_SPEED))


func _update_camera_presentation(delta: float, input_vector: Vector2) -> void:
	var motion_ratio: float = get_motion_ratio()
	var focus_ratio: float = 1.0 if has_focus_interactable() else 0.0
	var target_spring_length: float = lerp(default_spring_length, focus_spring_length, focus_ratio)
	_spring_arm.spring_length = move_toward(_spring_arm.spring_length, target_spring_length, delta * 2.8)

	var target_fov: float = default_fov + (moving_fov - default_fov) * motion_ratio
	target_fov = lerp(target_fov, focus_fov, focus_ratio)
	_camera.fov = move_toward(_camera.fov, target_fov, delta * 10.0)

	var target_camera_x: float = 0.22 + input_vector.x * 0.06 + focus_ratio * 0.1
	var target_camera_y: float = 0.52 + sin(_presentation_time * (3.6 + motion_ratio * 4.0)) * 0.028 * motion_ratio
	var target_camera_rotation_x: float = -0.16 + motion_ratio * 0.016

	var camera_position: Vector3 = _camera.position
	camera_position.x = move_toward(camera_position.x, target_camera_x, delta * CAMERA_SWAY_SPEED)
	camera_position.y = move_toward(camera_position.y, target_camera_y, delta * CAMERA_SWAY_SPEED)
	_camera.position = camera_position
	_camera.rotation.x = lerp_angle(_camera.rotation.x, target_camera_rotation_x, min(1.0, delta * CAMERA_SWAY_SPEED))


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


func _clear_focus() -> void:
	if _current_interactable == null:
		return

	for interactable in _nearby_interactables:
		if not is_instance_valid(interactable):
			continue
		interactable.set_focus_enabled(false)

	_current_interactable = null
	focus_changed.emit()


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


func _apply_active_visuals() -> void:
	if _selection_ring != null:
		_selection_ring.visible = _is_active
