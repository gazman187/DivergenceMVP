extends RefCounted
class_name VoiceProximityManager

const SAME_ROOM_STRENGTH: float = 1.0
const ADJACENT_STRENGTH: float = 0.5
const DISTANT_STRENGTH: float = 0.25
const VERTICAL_SPLIT_STRENGTH: float = 0.12
const NO_SIGNAL_STRENGTH: float = 0.0

const ADJACENT_VOICE_VOLUME: float = 0.42
const DISTANT_VOICE_VOLUME: float = 0.18
const VERTICAL_SPLIT_VOICE_VOLUME: float = 0.10

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
	var relationship: String = _describe_relationship(location_one, location_two, floor_collapsed, distance, strength)
	var state: String = state_from_strength(strength)
	var voice_volume: float = _resolve_voice_volume(strength, relationship)
	var environment_bleed: float = _resolve_environment_bleed(distance, strength, relationship)
	var occlusion: float = _resolve_occlusion(location_one, location_two, relationship)
	var room_resonance: float = _resolve_room_resonance(location_one, location_two, relationship)
	var silence_pressure: float = _resolve_silence_pressure(location_one, location_two, relationship, strength)
	var relief: float = _resolve_relief(location_one, location_two, floor_collapsed)
	var presence_hint: String = _resolve_presence_hint(location_one, location_two, relationship, strength)
	var flavor: String = _describe_flavor(location_one, location_two, relationship, strength)

	return {
		"state": state,
		"strength": strength,
		"voice_volume": voice_volume,
		"environment_bleed": environment_bleed,
		"distance": distance,
		"relationship": relationship,
		"flavor": flavor,
		"audible": strength > 0.0,
		"occlusion": occlusion,
		"room_resonance": room_resonance,
		"silence_pressure": silence_pressure,
		"relief": relief,
		"presence_hint": presence_hint
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
	var visited: Dictionary = {start: true}

	while not frontier.is_empty():
		var current: Dictionary = frontier.pop_front()
		var location: String = str(current["location"])
		var distance: int = int(current["distance"])

		var neighbors: Array = LOCATION_GRAPH[location] if LOCATION_GRAPH.has(location) else []
		for neighbor_variant in neighbors:
			var neighbor_name: String = str(neighbor_variant)
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


static func _resolve_voice_volume(strength: float, relationship: String) -> float:
	if relationship == "same_room":
		return 1.0

	if relationship == "vertical_split":
		return VERTICAL_SPLIT_VOICE_VOLUME

	if relationship == "adjacent":
		return minf(strength, ADJACENT_VOICE_VOLUME)

	if relationship == "distant":
		return minf(strength, DISTANT_VOICE_VOLUME)

	return 0.0


static func _resolve_environment_bleed(distance: int, strength: float, relationship: String) -> float:
	if relationship == "same_room":
		return 0.28

	if relationship == "vertical_split":
		return 0.14

	if relationship == "adjacent":
		return 0.16

	if relationship == "distant":
		return 0.07

	if strength <= 0.0 and distance <= 2:
		return 0.02

	return 0.0


static func _resolve_occlusion(location_one: String, location_two: String, relationship: String) -> float:
	if relationship == "same_room":
		if location_one == "Outside" and location_two == "Outside":
			return 0.04
		return 0.10

	if relationship == "vertical_split":
		return 0.78

	if relationship == "adjacent":
		if _is_outdoor(location_one) or _is_outdoor(location_two):
			return 0.28
		return 0.22

	if relationship == "distant":
		return 0.48

	return 1.0


static func _resolve_room_resonance(location_one: String, location_two: String, relationship: String) -> float:
	if relationship == "same_room":
		return _room_resonance_for(location_one)

	return (_room_resonance_for(location_one) + _room_resonance_for(location_two)) * 0.5


static func _resolve_silence_pressure(location_one: String, location_two: String, relationship: String, strength: float) -> float:
	if relationship == "same_room":
		if location_one == "Outside":
			return 0.14
		if location_one == "WoodsEdge":
			return 0.24
		return 0.20

	if relationship == "vertical_split":
		return 0.74

	if relationship == "adjacent":
		if _is_outdoor(location_one) and _is_outdoor(location_two):
			return 0.28
		return 0.34

	if relationship == "distant":
		return 0.56

	if strength <= 0.0:
		if _is_indoor(location_one) != _is_indoor(location_two):
			return 0.94
		if location_one == "WoodsEdge" or location_two == "WoodsEdge":
			return 0.90
		return 0.86

	return 0.70


static func _resolve_relief(location_one: String, location_two: String, floor_collapsed: bool) -> float:
	if location_one != location_two:
		return 0.0

	if location_one == "Outside":
		return 0.88 if floor_collapsed else 0.30

	if floor_collapsed:
		return 0.48

	return 0.14


static func _resolve_presence_hint(location_one: String, location_two: String, relationship: String, strength: float) -> String:
	if relationship == "same_room":
		return "shared_presence"

	if relationship == "vertical_split":
		if location_one == "Downstairs" or location_two == "Downstairs":
			return "muffled_overhead"
		return "muffled_below"

	if strength > 0.0 and (_is_outdoor(location_one) or _is_outdoor(location_two)):
		return "distant_reply"

	if strength > 0.0:
		return "thin_presence"

	return "absence"


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


static func _describe_flavor(location_one: String, location_two: String, relationship: String, strength: float) -> String:
	if relationship == "same_room":
		if location_one == "Outside":
			return "Open air carries every word. The distance between them drops away."
		if location_one == "Downstairs":
			return "Voices land together inside the lower resonance of the house."
		return "Same room. Their voices sit in the same air again."

	if relationship == "vertical_split":
		return "Only a muffled human trace slips through floorboards and dust."

	if relationship == "adjacent":
		if _is_outdoor(location_one) or _is_outdoor(location_two):
			return "Wind and distance soften the line, but a nearby reply still carries."
		return "Voices bleed through walls and open thresholds, softened by the house."

	if relationship == "distant":
		if _is_outdoor(location_one) or _is_outdoor(location_two):
			return "A far reply drifts through open air before the wind takes it."
		return "Only a thin trace survives through rooms, doors, and pressure."

	if strength <= 0.0 and (_is_indoor(location_one) != _is_indoor(location_two)):
		return "The house structure swallows the line completely."

	return "Silence and distance answer back."


static func _room_resonance_for(location: String) -> float:
	match location:
		"UpstairsRoom":
			return 0.34
		"UpstairsHallway":
			return 0.46
		"Bedroom":
			return 0.30
		"Downstairs":
			return 0.74
		"Outside":
			return 0.08
		"WoodsEdge":
			return 0.12
		"Shed":
			return 0.58
		_:
			return 0.26


static func _is_upstairs(location: String) -> bool:
	return location == "UpstairsRoom" or location == "UpstairsHallway" or location == "Bedroom"


static func _is_indoor(location: String) -> bool:
	return location == "UpstairsRoom" \
		or location == "UpstairsHallway" \
		or location == "Bedroom" \
		or location == "Downstairs" \
		or location == "Shed"


static func _is_outdoor(location: String) -> bool:
	return location == "Outside" or location == "WoodsEdge"


static func _is_vertical_split(location_one: String, location_two: String) -> bool:
	var downstairs_pair: bool = location_one == "Downstairs" or location_two == "Downstairs"
	return downstairs_pair and _is_upstairs(location_one) != _is_upstairs(location_two)


static func _pair_key(location_one: String, location_two: String) -> String:
	var ordered: Array[String] = [location_one, location_two]
	ordered.sort()
	return "%s|%s" % [ordered[0], ordered[1]]
