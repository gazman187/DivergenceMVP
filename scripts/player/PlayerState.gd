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
	var state := PlayerState.new(
		str(data.get("player_id", "")),
		str(data.get("display_name", ""))
	)
	state.location = str(data.get("location", "UpstairsRoom"))
	state.inventory.clear()

	for item in data.get("inventory", []):
		state.inventory.append(str(item))

	return state
