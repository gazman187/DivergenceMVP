extends Node

signal state_changed
signal prompt_changed(text: String)
signal event_logged(text: String, tone: String)
signal radio_target_changed(profile: Dictionary)
signal radio_status_changed(status: String)
signal radio_connection_changed(snapshot: Dictionary)
signal player_routed(player_id: String, location: String)
signal inventory_changed(player_id: String, inventory: Array[String])
signal collapse_triggered(player_id: String)
signal shed_unlocked(player_id: String)
signal cinematic_requested(scene_path: String)
signal audio_requested(event_name: String)
signal save_completed(path: String)
signal load_completed(path: String)


func emit_state_changed() -> void:
	state_changed.emit()


func emit_prompt_changed(text: String) -> void:
	prompt_changed.emit(text)


func emit_event_logged(text: String, tone: String = "system") -> void:
	event_logged.emit(text, tone)


func emit_radio_target_changed(profile: Dictionary) -> void:
	radio_target_changed.emit(profile)


func emit_radio_status_changed(status: String) -> void:
	radio_status_changed.emit(status)


func emit_radio_connection_changed(snapshot: Dictionary) -> void:
	radio_connection_changed.emit(snapshot)


func emit_player_routed(player_id: String, location: String) -> void:
	player_routed.emit(player_id, location)


func emit_inventory_changed(player_id: String, inventory: Array[String]) -> void:
	inventory_changed.emit(player_id, inventory)


func emit_collapse_triggered(player_id: String) -> void:
	collapse_triggered.emit(player_id)


func emit_shed_unlocked(player_id: String) -> void:
	shed_unlocked.emit(player_id)


func emit_cinematic_requested(scene_path: String) -> void:
	cinematic_requested.emit(scene_path)


func emit_audio_requested(event_name: String) -> void:
	audio_requested.emit(event_name)


func emit_save_completed(path: String) -> void:
	save_completed.emit(path)


func emit_load_completed(path: String) -> void:
	load_completed.emit(path)