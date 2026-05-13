extends Control
class_name UIManager

const MAX_FEED_LINES := 7
const RADIO_STYLES := {
	"Clear": {
		"bars": 4,
		"color": Color(0.63, 0.89, 0.75, 1.0),
		"flavor": "Voices carry cleanly through the house.",
		"static": 0.04
	},
	"Weak": {
		"bars": 3,
		"color": Color(0.84, 0.79, 0.48, 1.0),
		"flavor": "The channel thins and warms with static.",
		"static": 0.12
	},
	"Broken": {
		"bars": 2,
		"color": Color(0.88, 0.55, 0.45, 1.0),
		"flavor": "Fragments push through cracked interference.",
		"static": 0.22
	},
	"Lost": {
		"bars": 1,
		"color": Color(0.66, 0.68, 0.74, 1.0),
		"flavor": "Only static and distance answer back.",
		"static": 0.34
	}
}

@onready var _prompt_frame: PanelContainer = $InteractionPrompt
@onready var _prompt_label: Label = $InteractionPrompt/MarginContainer/VBoxContainer/PromptText
@onready var _event_feed_label: Label = $EventFeed/MarginContainer/VBoxContainer/EventFeedEntries
@onready var _radio_panel: PanelContainer = $RadioStatus
@onready var _radio_value: Label = $RadioStatus/MarginContainer/VBoxContainer/StatusValue
@onready var _radio_flavor: Label = $RadioStatus/MarginContainer/VBoxContainer/FlavorText
@onready var _radio_static_line: ColorRect = $RadioStatus/StaticLine
@onready var _radio_glow: ColorRect = $RadioStatus/SignalGlow
@onready var _cinematic: Control = $FloorCollapseCinematic
@onready var _cinematic_backdrop: ColorRect = $FloorCollapseCinematic/Backdrop
@onready var _cinematic_flash: ColorRect = $FloorCollapseCinematic/Flash
@onready var _cinematic_panel: PanelContainer = $FloorCollapseCinematic/CenterContainer/PanelContainer
@onready var _cinematic_title: Label = $FloorCollapseCinematic/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ImpactTitle
@onready var _cinematic_subtitle: Label = $FloorCollapseCinematic/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ImpactSubtitle

var _radio_status: String = "Clear"
var _event_feed_lines: Array[String] = []
var _radio_bars: Array[ColorRect] = []
var _collapse_running: bool = false


func _ready() -> void:
	randomize()
	EventBus.prompt_changed.connect(_on_prompt_changed)
	EventBus.event_logged.connect(_on_event_logged)
	EventBus.radio_status_changed.connect(_on_radio_status_changed)
	EventBus.cinematic_requested.connect(_on_cinematic_requested)

	_radio_bars = [
		$RadioStatus/MarginContainer/VBoxContainer/BarRow/SignalBar1,
		$RadioStatus/MarginContainer/VBoxContainer/BarRow/SignalBar2,
		$RadioStatus/MarginContainer/VBoxContainer/BarRow/SignalBar3,
		$RadioStatus/MarginContainer/VBoxContainer/BarRow/SignalBar4
	]

	_prompt_label.text = "Prototype ready. Move either player into the hallway."
	_cinematic.visible = false
	_cinematic_flash.modulate.a = 0.0
	_apply_radio_status("Clear", false)
	_append_event("Receiver warmed. The house is listening.", "system")
	set_process(true)


func _process(_delta: float) -> void:
	var style: Dictionary = RADIO_STYLES.get(_radio_status, RADIO_STYLES["Lost"])
	_radio_static_line.modulate.a = float(style["static"]) + randf_range(0.0, 0.08)
	_radio_static_line.position.y = 22.0 + randf_range(-2.0, 2.0)
	_radio_glow.modulate.a = 0.08 + randf_range(0.0, 0.06)


func _on_prompt_changed(text: String) -> void:
	_prompt_label.text = text
	_pulse_prompt()


func _on_event_logged(text: String, tone: String) -> void:
	_append_event(text, tone)


func _on_radio_status_changed(status: String) -> void:
	var previous_status := _radio_status
	_apply_radio_status(status, previous_status != status)

	if previous_status != status:
		_append_event(_signal_transition_text(status), "signal")


func _on_cinematic_requested(scene_path: String) -> void:
	if scene_path == "res://scenes/cinematic/FloorCollapseCinematic.tscn":
		_play_floor_collapse_cinematic()


func _play_floor_collapse_cinematic() -> void:
	if _collapse_running:
		return

	_show_collapse_sequence()


func _show_collapse_sequence():
	_collapse_running = true
	_cinematic.visible = true
	_cinematic_backdrop.modulate.a = 0.0
	_cinematic_flash.modulate.a = 0.0
	_cinematic_panel.scale = Vector2(0.96, 0.96)
	_cinematic_title.text = "CRACK"
	_cinematic_subtitle.text = "The weak hallway finally gives way."

	var intro_tween := create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(_cinematic_backdrop, "modulate:a", 1.0, 0.12)
	intro_tween.tween_property(_cinematic_panel, "scale", Vector2.ONE, 0.18)
	await intro_tween.finished

	await _shake_ui(0.42, 10.0)
	await _flash_impact()
	await get_tree().create_timer(0.52).timeout

	_cinematic.visible = false
	position = Vector2.ZERO
	_collapse_running = false


func _apply_radio_status(status: String, animate: bool) -> void:
	_radio_status = status
	var style: Dictionary = RADIO_STYLES.get(status, RADIO_STYLES["Lost"])
	var active_bars := int(style["bars"])
	var accent: Color = style["color"]

	_radio_value.text = status.to_upper()
	_radio_value.modulate = accent
	_radio_flavor.text = str(style["flavor"])
	_radio_flavor.modulate = accent.lerp(Color(1, 1, 1, 1), 0.45)
	_radio_glow.color = accent

	for index in range(_radio_bars.size()):
		var bar := _radio_bars[index]
		bar.color = accent if index < active_bars else Color(0.21, 0.24, 0.28, 0.9)

	if animate:
		var pulse := create_tween()
		pulse.set_parallel(true)
		pulse.tween_property(_radio_panel, "scale", Vector2(1.02, 1.02), 0.08)
		pulse.tween_property(_radio_glow, "modulate:a", 0.22, 0.08)
		pulse.chain().tween_property(_radio_panel, "scale", Vector2.ONE, 0.16)
		pulse.parallel().tween_property(_radio_glow, "modulate:a", 0.10, 0.18)


func _append_event(text: String, tone: String) -> void:
	var formatted := "%s %s" % [_tone_prefix(tone), text]
	if not _event_feed_lines.is_empty() and _event_feed_lines[-1] == formatted:
		return

	_event_feed_lines.append(formatted)
	while _event_feed_lines.size() > MAX_FEED_LINES:
		_event_feed_lines.pop_front()

	_event_feed_label.text = "\n".join(_event_feed_lines)


func _tone_prefix(tone: String) -> String:
	match tone:
		"critical":
			return "IMPACT //"
		"signal":
			return "RADIO  //"
		"hope":
			return "LINK   //"
		"movement":
			return "TRACE  //"
		_:
			return "SYSTEM //"


func _signal_transition_text(status: String) -> String:
	match status:
		"Clear":
			return "Signal clear. Both voices cut through again."
		"Weak":
			return "Signal weakening..."
		"Broken":
			return "Radio link breaking into fragments."
		"Lost":
			return "Signal lost in static."
		_:
			return "Signal shifting."


func _pulse_prompt() -> void:
	var tween := create_tween()
	tween.tween_property(_prompt_frame, "scale", Vector2(1.01, 1.01), 0.08)
	tween.chain().tween_property(_prompt_frame, "scale", Vector2.ONE, 0.16)


func _shake_ui(duration: float, amplitude: float):
	var end_time := Time.get_ticks_msec() + int(duration * 1000.0)
	while Time.get_ticks_msec() < end_time:
		position = Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
		await get_tree().create_timer(0.03).timeout

	position = Vector2.ZERO


func _flash_impact():
	var flash_tween := create_tween()
	flash_tween.tween_property(_cinematic_flash, "modulate:a", 0.95, 0.05)
	flash_tween.chain().tween_property(_cinematic_flash, "modulate:a", 0.0, 0.28)
	await flash_tween.finished
