extends "res://src/world/furniture.gd"
## A straw-filled mattress on a nailed frame. Carried in your arms and set down
## anywhere dry. E (or sleep) opens the rest panel: lie down for as long as you
## choose, tired or not (swamp.open_rest). Right-click lifts it to move it.


func _box_size() -> Vector3:
	return Vector3(2.05, 0.56, 1.05)


func prompt(_player: Node) -> String:
	return "Bed: rest [E]   Move it [Right-click]"


func interact(player: Node) -> void:
	sleep_on(player)


func sleep_on(player: Node) -> void:
	if player.world and player.world.has_method("open_rest"):
		player.world.open_rest()


func use_interact(player: Node) -> void:
	player.start_haul(self)


func haul_radius() -> float:
	return 1.1


func set_hauled(by: Node3D) -> void:
	super(by)
	loose = true


func from_dict(d: Dictionary) -> void:
	super(d)
	loose = true
