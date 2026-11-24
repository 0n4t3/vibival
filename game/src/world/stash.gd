extends StaticBody3D
## A sack set down on the ground as a stash. It holds up to capacity() kg
## (its sack item's `stash`: 50 for a frond sack, 100 for a cloth one) in its
## own inventory (food in it still spoils). Open it with interact to move
## things in and out; once it is empty it can be picked up again, as the same
## sack.

const Inventory := preload("res://src/core/inventory.gd")
const TICK := 1.0

var inv: RefCounted = Inventory.new()
var sack_id := "fiber_sack"   # which sack it is
var _tick_t := 0.0
var _mesh: MeshInstance3D


func _init() -> void:
	inv.overload = 1.0
	set_sack(sack_id)


func set_sack(id: String) -> void:
	sack_id = id if Items.def(id).has("stash") else "fiber_sack"
	inv.capacity_override = capacity()
	if crate() and is_inside_tree():
		add_to_group("crates")
	if _mesh:
		_mesh.mesh = Assets.mesh(_mesh_key())


func capacity() -> float:
	return float(Items.def(sack_id).get("stash", 50.0))


func _mesh_key() -> String:
	if sack_id == "storage_crate":
		return "item_storage_crate"
	return "stash" if sack_id == "fiber_sack" else "stash_" + sack_id


func _ready() -> void:
	add_to_group("stashes")
	if crate():
		add_to_group("crates")
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.45
	cs.shape = sh
	cs.position.y = 0.3
	add_child(cs)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Assets.mesh(_mesh_key())
	_mesh.visibility_range_end = 80.0
	add_child(_mesh)


func _process(delta: float) -> void:
	_tick_t += delta
	if _tick_t >= TICK:
		inv.tick(_tick_t)
		_tick_t = 0.0


func prompt(_player: Node) -> String:
	return "Open %s (%.1f / %d kg) [E]" % [Items.item_name(sack_id).to_lower(), inv.weight(), capacity()]


func interact(player: Node) -> void:
	if hauled_by != null:
		return
	if player.world and player.world.has_method("open_stash"):
		player.world.open_stash(self)


func is_empty() -> bool:
	return inv.slots.all(func(s): return s == null)


func use_interact(player: Node) -> void:
	## A crate, right-clicked: lift it if empty; loaded, slide it onto a
	## handcart beside it (or off the cart it's on).
	if not crate() or hauled_by != null:
		return
	var w: Node = player.world
	var on: Node3D = null
	for c in get_tree().get_nodes_in_group("handcarts"):
		if self in c.cargo:
			on = c
	if on:
		on.cargo.erase(self)
		on._yaws.resize(on.cargo.size())
		global_position = on.to_global(Vector3(1.3, 0, 0.1))
		global_position.y = w.floor_height(global_position)
		return
	if is_empty():
		player.start_haul(self)
		return
	var cart: Node3D = w.cart_near(global_position, 3.0) if w.has_method("cart_near") else null
	if cart == null or not cart.has_room_for(self):
		Game.notify("Too heavy to lift loaded. Bring a handcart alongside, or empty it first.")
		return
	cart.stow(self)


func pick_up() -> bool:
	if crate():
		var p: Node = get_parent().get("player")
		if not is_empty() or p == null or p.hauling or p.carry_blocked():
			return false
		p.start_haul(self)
		return true
	## Back into your inventory, only once it is empty. Its weight never stops
	## you: on your shoulder the sack lets you carry more.
	if not is_empty() or Game.inventory.add(sack_id, 1, 0.0, true) > 0:
		return false
	Sfx.play("pickup", -8.0)
	queue_free()
	return true


# --- A storage crate is carried in your arms (player.gd), not the bag ----------------
# Empty, you can lift it. Loaded, it only moves on a handcart.

var hauled_by: Node3D = null


func crate() -> bool:
	return sack_id == "storage_crate"


func can_haul() -> bool:
	return crate() and (hauled_by != null or is_empty())


func haul_mode() -> String:
	return "carry"


func haul_name() -> String:
	return Items.item_name(sack_id).to_lower()


func haul_radius() -> float:
	return 0.55


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	return 0.35


func set_hauled(by: Node3D) -> void:
	hauled_by = by
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = by != null
	if by == null:
		rotation = Vector3(0, rotation.y, 0)
		var w := get_parent()
		if w and w.has_method("floor_height"):
			global_position.y = maxf(w.floor_height(global_position), 0.0)


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "sack": sack_id, "inv": inv.to_dict()}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	set_sack(String(d.get("sack", "fiber_sack")))  # older saves: the frond sack
	inv.from_dict(d.get("inv", {}))
