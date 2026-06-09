extends Node
class_name FleetService


func build_fleet_payload(fleet: Array, total_cost: int) -> Dictionary:
	var ships: Array = []
	for ship in fleet:
		var entry := {
			"name": str(ship.get("name", "")),
			"weapons": ship.get("weapons", []).duplicate(),
		}
		ships.append(entry)
	return {
		"ships": ships,
		"total_cost": total_cost,
	}
