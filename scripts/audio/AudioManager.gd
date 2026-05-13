extends Node
class_name AudioManager

var last_event: String = ""


func _ready() -> void:
	EventBus.audio_requested.connect(_on_audio_requested)


func _on_audio_requested(event_name: String) -> void:
	last_event = event_name
	print("[AudioManager] placeholder cue:", event_name)
