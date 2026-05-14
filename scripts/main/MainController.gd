extends Control
class_name MainController

const PLAYER_IDS: Array[String] = [GameState.PLAYER_1_ID, GameState.PLAYER_2_ID]
const WORLD_BOUNDS: Rect2 = Rect2(24.0, 18.0, 1048.0, 746.0)
const CAMERA_LERP_SPEED: float = 5.6
const ATMOSPHERE_LERP_SPEED: float = 4.2
const AREA_CARD_SUBTITLES := {
	"UpstairsRoom": "Water stains. Quiet weight.",
	"UpstairsHallway": "Boards under strain.",
	"Bedroom": "Moonlight and one exit.",
	"Downstairs": "Dust. Impact. Disorientation.",
	"Outside": "Cold air. Shared ground.",
	"WoodsEdge": "Tree line. Signal loss.",
	"Shed": "Optional shelter."
}
const LOCATION_LABELS := {
	"UpstairsRoom": "Upstairs Room",
	"UpstairsHallway": "Upstairs Hallway",
	"Bedroom": "Bedroom",
	"Downstairs": "Downstairs",
	"Outside": "Outside",
	"WoodsEdge": "Woods Edge",
	"Shed": "Shed"
}

@onready var _session_manager: SessionManager = $SessionManager
@onready var _save_manager: SaveManager = $SaveManager
@onready var _debug_toggle_button: Button = $DebugToggleButton
@onready var _debug_panel: PanelContainer = $DebugPanel
@onready var _world_frame: PanelContainer = $WorldFrame
@onready var _world_camera_rig: Node2D = $WorldFrame/WorldCameraRig
@onready var _world_layer: Node2D = $WorldFrame/WorldCameraRig/WorldLayer
@onready var _world_fade: ColorRect = $WorldFade
@onready var _world_state_tint: ColorRect = $WorldFrame/WorldStateTint
@onready var _world_relief_glow: ColorRect = $WorldFrame/WorldReliefGlow
@onready var _world_top_shade: ColorRect = $WorldFrame/WorldTopShade
@onready var _world_bottom_shade: ColorRect = $WorldFrame/WorldBottomShade
@onready var _world_left_shade: ColorRect = $WorldFrame/WorldLeftShade
@onready var _world_right_shade: ColorRect = $WorldFrame/WorldRightShade
@onready var _world_grain_band: ColorRect = $WorldFrame/WorldGrainBand
@onready var _area_card: PanelContainer = $WorldFrame/AreaCard
@onready var _area_card_title: Label = $WorldFrame/AreaCard/MarginContainer/VBoxContainer/AreaTitle
@onready var _area_card_subtitle: Label = $WorldFrame/AreaCard/MarginContainer/VBoxContainer/AreaSubtitle
@onready var _active_player_value: Label = $WorldHUD/Panel/Margin/VBox/ActivePlayerValue
@onready var _active_location_value: Label = $WorldHUD/Panel/Margin/VBox/ActiveLocationValue
@onready var _interaction_hint_value: Label = $WorldHUD/Panel/Margin/VBox/InteractionHintValue
@onready var _collapse_label: Label = find_child("CollapseLabel", true, false) as Label
@onready var _key_label: Label = find_child("KeyLabel", true, false) as Label
@onready var _shed_label: Label = find_child("ShedLabel", true, false) as Label
@onready var _trigger_label: Label = find_child("TriggerLabel", true, false) as Label
@onready var _key_holder_label: Label = find_child("KeyHolderLabel", true, false) as Label
@onready var _link_label: Label = find_child("LinkLabel", true, false) as Label
@onready var _reconverged_label: Label = find_child("ReconvergedLabel", true, false) as Label
@onready var _reset_button: Button = find_child("ResetButton", true, false) as Button
@onready var _save_button: Button = find_child("SaveButton", true, false) as Button
@onready var _load_button: Button = find_child("LoadButton", true, false) as Button

var _player_widgets: Dictionary = {}
var _player_pawns: Dictionary = {}
var _location_nodes: Dictionary = {}
var _last_locations: Dictionary = {}
var _active_player_id: String = GameState.PLAYER_1_ID
var _has_world_state: bool = false
var _camera_target_position: Vector2 = Vector2.ZERO
var _camera_target_scale: Vector2 = Vector2.ONE
var _area_card_tween: Tween


func _ready() -> void:
	_cache_player_widgets()
	_cache_world_nodes()
	_connect_buttons()
	_connect_pawn_signals()

	EventBus.state_changed.connect(_refresh_view)
	EventBus.load_completed.connect(_refresh_view_after_load)

	_debug_toggle_button.pressed.connect(_toggle_debug_panel)
	_set_active_player(GameState.PLAYER_1_ID)
	_session_manager.initialize_local_session()
	_initialize_world_presentation()
	set_process(true)


func _process(delta: float) -> void:
	_update_camera_and_atmosphere(delta)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_TAB or key_event.keycode == KEY_Q:
		_switch_active_player()
		accept_event()
		return

	if key_event.keycode == KEY_E:
		var pawn: PlayerPawn = _player_pawns[_active_player_id] as PlayerPawn
		if pawn != null:
			pawn.try_interact()
		accept_event()
		return

	if key_event.keycode == KEY_F1:
		_toggle_debug_panel()
		accept_event()


func _cache_world_nodes() -> void:
	_player_pawns = {
		GameState.PLAYER_1_ID: $WorldFrame/WorldCameraRig/WorldLayer/Player1Pawn,
		GameState.PLAYER_2_ID: $WorldFrame/WorldCameraRig/WorldLayer/Player2Pawn
	}

	_location_nodes = {
		"UpstairsRoom": $WorldFrame/WorldCameraRig/WorldLayer/UpstairsRoom,
		"UpstairsHallway": $WorldFrame/WorldCameraRig/WorldLayer/UpstairsHallway,
		"Bedroom": $WorldFrame/WorldCameraRig/WorldLayer/Bedroom,
		"Downstairs": $WorldFrame/WorldCameraRig/WorldLayer/Downstairs,
		"Outside": $WorldFrame/WorldCameraRig/WorldLayer/Outside,
		"WoodsEdge": $WorldFrame/WorldCameraRig/WorldLayer/WoodsEdge,
		"Shed": $WorldFrame/WorldCameraRig/WorldLayer/Shed
	}


func _connect_pawn_signals() -> void:
	for player_id in PLAYER_IDS:
		var pawn: PlayerPawn = _player_pawns[player_id] as PlayerPawn
		if pawn != null:
			pawn.interaction_zone_changed.connect(_on_pawn_interaction_zone_changed)


func _cache_player_widgets() -> void:
	_player_widgets = {
		GameState.PLAYER_1_ID: {
			"location": find_child("Player1LocationLabel", true, false),
			"inventory": find_child("Player1InventoryLabel", true, false),
			"status": find_child("Player1StatusLabel", true, false),
			"hallway": find_child("P1HallwayButton", true, false),
			"cross": find_child("P1CrossButton", true, false),
			"bedroom": find_child("P1BedroomButton", true, false),
			"key": find_child("P1KeyButton", true, false),
			"escape": find_child("P1EscapeButton", true, false),
			"downstairs": find_child("P1DownstairsButton", true, false),
			"woods": find_child("P1WoodsButton", true, false),
			"shed": find_child("P1ShedButton", true, false)
		},
		GameState.PLAYER_2_ID: {
			"location": find_child("Player2LocationLabel", true, false),
			"inventory": find_child("Player2InventoryLabel", true, false),
			"status": find_child("Player2StatusLabel", true, false),
			"hallway": find_child("P2HallwayButton", true, false),
			"cross": find_child("P2CrossButton", true, false),
			"bedroom": find_child("P2BedroomButton", true, false),
			"key": find_child("P2KeyButton", true, false),
			"escape": find_child("P2EscapeButton", true, false),
			"downstairs": find_child("P2DownstairsButton", true, false),
			"woods": find_child("P2WoodsButton", true, false),
			"shed": find_child("P2ShedButton", true, false)
		}
	}


func _connect_buttons() -> void:
	_reset_button.pressed.connect(_on_reset_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)

	_bind_player_button(GameState.PLAYER_1_ID, "hallway", _on_move_to_hallway)
	_bind_player_button(GameState.PLAYER_1_ID, "cross", _on_cross_hallway)
	_bind_player_button(GameState.PLAYER_1_ID, "bedroom", _on_route_bedroom)
	_bind_player_button(GameState.PLAYER_1_ID, "key", _on_take_key)
	_bind_player_button(GameState.PLAYER_1_ID, "escape", _on_escape_bedroom)
	_bind_player_button(GameState.PLAYER_1_ID, "downstairs", _on_leave_downstairs)
	_bind_player_button(GameState.S