extends RefCounted
class_name VoiceProximityManager

const LOCATION_GRAPH := {
	"UpstairsRoom": ["UpstairsHallway", "Bedroom"],
	"UpstairsHallway": ["UpstairsRoom", "Bedroom"],
	"Bedroom": ["UpstairsRoom", "UpstairsHallway", "Outside"],
	"Downstairs": ["Outside"],
	"Outside": ["Downstairs", "Bedroom", "WoodsEdge", "Shed"],
	"WoodsEdge": ["Outside"],
	"Shed": ["Outside"]
}


static func calculate_status(location_one: String, location_two: String, floor_collapsed: bool) -> String:
	if location_one == location_two:
		return "Clear"

	var distance := _distance_between(location_one, location_two)
	var collapse_split := floor_collapsed and _is_upstairs(location_one) != _is_upstairs(location_two)
	var includes_woods := location_one == "WoodsEdge" or location_two == "WoodsEdge"

	if collapse_split and includes_woods:
		return "Lost"

	if collapse_split and distance <= 2:
		return "Broken"

	match distance:
		1:
			return "Weak"
		2:
			return "Broken"
		_:
			return "Lost"


static func _distance_between(start: String, target: String) -> int:
	if start == target:
		return 0

	var frontier: Array[Dictionary] = [{"location": start, "distance": 0}]
	var visited := {start: true}

	while not frontier.is_empty():
		var current: Dictionary = frontier.pop_front()
		var location := str(current.get("location", ""))
		var distance := int(current.get("distance", 0))

		for neighbor in LOCATION_GRAPH.get(location, []):
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


static func _is_upstairs(location: String) -> bool:
	return location in ["UpstairsRoom", "UpstairsHallway", "Bedroom"]
