extends Node
class_name SaveManager

const SAVE_PATH := "user://phase1_save.json"


func save_world_state() -> bool:
	var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		EventBus.emit_prompt_changed("Save failed. Godot could not open the local JSON file.")
		return false

	save_file.store_string(JSON.stringify(GameState.serialize_state(), "\t"))
	save_file.close()
	EventBus.emit_save_completed(SAVE_PATH)
	EventBus.emit_prompt_changed("Prototype state saved to %s." % SAVE_PATH)
	return true


func load_world_state() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		EventBus.emit_prompt_changed("No save file exists yet at %s." % SAVE_PATH)
		return false

	var save_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		EventBus.emit_prompt_changed("Load failed. Godot could not read the local JSON file.")
		return false

	var parser := JSON.new()
	var error := parser.parse(save_file.get_as_text())
	save_file.close()

	if error != OK:
		EventBus.emit_prompt_changed("Load failed. The save JSON could not be parsed.")
		return false

	GameState.apply_save_data(parser.data)
	SceneRouter.refresh_radio_status()
	EventBus.emit_load_completed(SAVE_PATH)
	EventBus.emit_prompt_changed("Prototype state loaded from %s." % SAVE_PATH)
	return true
