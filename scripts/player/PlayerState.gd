extends RefCounted
class_name PlayerState

# Lightweight container for each player's local simulation state.
var player_id: String = ""
var display_name: String = ""
var location: String = "UpstairsRoom"
var inventory: Array[String] = []


func _init(id: String = "", name: String = "") -> void:
	player_id = id
	display_name = name


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"display_name": display_name,
		"location": location,
		"inventory": inventory.duplicate()
	}


static func from_dict(data: Dictionary) -> PlayerState:
	var player_id_value: String = ""
	var display_name_value: String = ""
	var location_value: String = "UpstairsRoom"
	var inventory_values: Array = []

	if data.has("player_id"):
		player_id_value = str(data["player_id"])
	if data.has("display_name"):
		display_name_value = str(data["display_name"])
	if data.has("location"):
		location_value = str(data["location"])
	if data.has("inventory"):
		inventory_values = data["inventory"] as Array

	var state: PlayerState = PlayerState.new(player_id_value, display_name_value)
	state.location = location_value
	state.inventory.clear()

	for item in inventory_values:
		state.inventory.append(str(item))

	return state
