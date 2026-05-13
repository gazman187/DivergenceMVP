extends Node
class_name SessionManager

# Phase 1 uses a local two-player simulation rather than real networking.
func initialize_local_session() -> void:
	SceneRouter.start_new_run()
