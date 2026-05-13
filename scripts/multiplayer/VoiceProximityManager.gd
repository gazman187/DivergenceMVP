extends RefCounted
class_name VoiceProximityManager

const SAME_ROOM_STRENGTH := 1.0
const ADJACENT_STRENGTH := 0.5
const DISTANT_STRENGTH := 0.25
const VERTICAL_SPLIT_STRENGTH := 0.12
const NO_SIGNAL_STRENGTH := 0.0

const LOCATION_GRAPH := {
	"UpstairsRoom": ["UpstairsHallway", "Bedroom"],
	"UpstairsHallway": ["UpstairsRoom", "Bedroom"],
	"Bedroom": ["UpstairsRoom", "UpstairsHallway"],
	"Downstairs": ["Outside"],
	"Outside": ["Downstairs", "WoodsEdge", "Shed"],
	"WoodsEdge": ["Outside"],
	"Shed": ["Outside"]
}

const STRENGTH_OVERRIDES := {
	"Bedroom|WoodsEdge": 0.0,
	"Bedroom|Shed": 0.0
}

static func calculate_status(location_one: String, location_two: String, floor_collapsed: bool) -> String:
	var profile: Dictionary = calculate_profile(location_one, location_two, floor_collapsed)
	var state: String = str(profile["state"])
	return state


static func calculate_profile(location_one: String, location_two: String, floor_collapsed: bool) -> Dictionary:
	var distance: int = _distance_between(location_one, location_two)
	var strength: float = _resolve_strength(location_one, location_two, floor_collapsed, distance)
	var state: String = state_from_strength(strength)
	var relationship: String = _describe_relationship(location_one, location_two, floor_collapsed, distance, strength)
	var flavor: String = _describe_flavor(location_one, location_two, floor_collapsed, distance, strength)
	var environment_bleed: float = _resolve_environment_bleed(distance, strength, relationship)

	return {
		"state": state,
		"strength": strength,
		"voice_volume": strength,
		"environment_bleed": environment_bleed,
		"distance": distance,
		"relationship": relationship,
		"flavor": flavor,
		"audible": strength > 0.0
	}


static func state_from_strength(strength: float) -> String:
	if strength >= 0.85:
		return "Clear"

	if strength >= 0.35:
		return "Reduced"

	if strength > 0.0:
		return "Faint"

	return "Lost"


static func _distance_between(start: String, target: String) -> int:
	if start == target:
		return 0

	var frontier: Array[Dictionary] = [{"location": start, "distance": 0}]
	var visited := {start: true}

	while not frontier.is_empty():
		var current: Dictionary = frontier.pop_front()
		var location: String = str(current["location"])
		var distance: int = int(current["distance"])

		var neighbors: Array = LOCATION_GRAPH[location] if LOCATION_GRAPH.has(location) else []
		for neighbor in neighbors:
			var neighbor_name := str(neighbor)
			if visited.has(neighbor_name):
				continue

			if neighbor_name == target:
				return distance + 1

			visited[neighbor_name] = true
			frontier.append({
				"location": neighbor_name,
				"distance": distance + 1
			})

	return 999


static func _resolve_strength(location_one: String, location_two: String, floor_collapsed: bool, distance: int) -> float:
	if location_one == location_two:
		return SAME_ROOM_STRENGTH

	var pair_key: String = _pair_key(location_one, location_two)
	if STRENGTH_OVERRIDES.has(pair_key):
		return float(STRENGTH_OVERRIDES[pair_key])

	if floor_collapsed and _is_vertical_split(location_one, location_two):
		return VERTICAL_SPLIT_STRENGTH

	match distance:
		1:
			return ADJACENT_STRENGTH
		2:
			return DISTANT_STRENGTH
		_:
			return NO_SIGNAL_STRENGTH


static func _resolve_environment_bleed(distance: int, strength: float, relationship: String) -> float:
	if relationship == "vertical_split":
		return 0.18

	if strength >= 1.0:
		return 0.30

	if strength >= 0.5:
		return 0.18

	if strength > 0.0:
		return 0.10

	if distance <= 2 and relationship != "severed":
		return 0.04

	return 0.0


static func _describe_relationship(location_one: String, location_two: String, floor_collapsed: bool, distance: int, strength: float) -> String:
	if location_one == location_two:
		return "same_room"

	if floor_collapsed and _is_vertical_split(location_one, location_two):
		return "vertical_split"

	if strength <= 0.0:
		return "severed"

	if distance <= 1:
		return "adjacent"

	return "distant"


static func _describe_flavor(location_one: String, location_two: String, floor_collapsed: bool, distance: int, strength: float) -> String:
	if location_one == location_two:
		return "Same room. Every word lands clearly."

	if floor_collapsed and _is_vertical_split(location_one, location_two):
		return "Muffled through the floorboards after the collapse."

	if strength >= 0.5:
		return "Nearby voices bleed through walls and open doors."

	if strength > 0.0:
		return "Only a thin trace gets through the distance."

	if distance <= 2:
		return "Static dominates. Environmental sounds barely carry."

	return "No readable line remains between the players."


static func _is_upstairs(location: String) -> bool:
	return location in ["UpstairsRoom", "UpstairsHallway", "Bedroom"]


static func _is_vertical_split(location_one: String, location_two: String) -> bool:
	var downstairs_pair := location_one == "Downstairs" or location_two == "Downstairs"
	return downstairs_pair and _is_upstairs(location_one) != _is_upstairs(location_two)


static func _pair_key(location_one: String, location_two: String) -> String:
	var ordered := [location_one, location_two]
	ordered.sort()
	return "%s|%s" % [ordered[0], ordered[1]]