extends StaticBody3D
## A wooden table or chair (group "furniture"): carried in your arms, set down
## on dry ground or a house floor. It only looks good; three blows from an axe,
## shovel or mattock knock a set-down one loose so it can be carried again.

const Terrain := preload("res://src/world/terrain.gd")

const BLOWS := 3

var item_id := "wooden_table"
var world: Node = null
var hauled_by: Node3D = null
var loose := true      # can be lifted; set down, it stays until knocked loose
var _hits := 0
var _shape: CollisionShape3D


func setup(id: String, w: Node) -> Node3D:
	item_id = id
	world = w
	return self


func _ready() -> void:
	add_to_group("furniture")
	collision_layer = 3
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = _box_size()
	_shape.shape = box
	_shape.position.y = box.size.y * 0.5
	add_child(_shape)
	var mi := MeshInstance3D.new()
	mi.mesh = Assets.mesh("item_" + item_id)
	mi.visibility_range_end = 90.0
	add_child(mi)


func _box_size() -> Vector3:
	return Vector3(1.4, 0.78, 0.8) if item_id == "wooden_table" else Vector3(0.46, 0.95, 0.46)


func prompt(_player: Node) -> String:
	if loose:
		return "Pick up the %s [E]" % haul_name()
	return "%s   (three blows with an axe, shovel or mattock knock it loose)" % Items.item_name(item_id)


func interact(player: Node) -> void:
	if loose:
		player.start_haul(self)


func axe_hit() -> void:
	_hit()


func break_apart() -> void:
	_hit()


func _hit() -> void:
	if loose:
		return
	_hits += 1
	Sfx.play_at("hit", global_position, -6.0)
	if _hits >= BLOWS:
		_hits = 0
		loose = true
		Game.notify("The %s comes loose. You can carry it now." % haul_name())


func can_haul() -> bool:
	return loose or hauled_by != null


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return Items.item_name(item_id).to_lower().trim_prefix("wooden ")


func haul_radius() -> float:
	return 0.7 if item_id == "wooden_table" else 0.3


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	return 0.25


func can_put_down() -> bool:
	if world == null or not world.has_method("floor_height"):
		return true
	if world.floor_height(global_position) < Terrain.WATER + 0.05:
		Game.notify("The %s needs dry ground or a floor." % haul_name())
		return false
	return true


func set_hauled(by: Node3D) -> void:
	hauled_by = by
	_shape.disabled = by != null
	if by == null:
		loose = has_meta("cart_load")
		rotation = Vector3(0, rotation.y, 0)
		if world:
			global_position.y = world.floor_height(global_position)


func to_dict() -> Dictionary:
	var p := global_position
	return {"id": item_id, "pos": [p.x, p.y, p.z], "yaw": rotation.y, "loose": loose}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	loose = bool(d.get("loose", false))
