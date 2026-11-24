extends StaticBody3D
## A two-wheeled handcart (group "handcarts"). Set what you carry on its bed
## like a raft's deck; E on the bed takes the top thing back. E at the handles
## pulls it, E lets go. It has four spaces (space_for). While you pull it you
## can't sprint, fight or use your hands; load and ground slow you, and deep
## water or a steep slope stops it. Being attacked makes you let go. It rides a
## raft as its one hauled thing, and saves with what is on it.

const Terrain := preload("res://src/world/terrain.gd")

const SPACES := 4.0
const BED_Y := 0.62
const HITCH := 1.55      # from the axle to where you hold the handles
const DEEP := 0.5        # water deeper than this stops it
const STEEP := 0.75      # rise over run it won't go up or down
const LOADS := ["logs", "workbenches", "soup_pots", "vessels", "traps", "anvils", "meteorites", "furniture", "crates", "carcasses"]

var world: Node = null
var hauled_by: Node3D = null
var cargo: Array = []    # the nodes on the bed, bottom first
var _shape: CollisionShape3D
var _yaws: Array = []
var _adopted := false
var _blocked_said := 0.0


func setup(w: Node) -> Node3D:
	world = w
	return self


func _ready() -> void:
	add_to_group("handcarts")
	collision_layer = 3
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.85, 2.3)
	_shape.shape = box
	_shape.position = Vector3(0, 0.42, -0.2)
	add_child(_shape)
	var mi := MeshInstance3D.new()
	mi.mesh = Assets.mesh("item_handcart")
	mi.visibility_range_end = 110.0
	add_child(mi)


func _physics_process(_delta: float) -> void:
	if not _adopted:
		_adopted = true
		_adopt()
	_drop_gone()
	_carry()


# --- What rides on it ----------------------------------------------------------------

static func space_for(c: Node) -> float:
	if c.is_in_group("workbenches"):
		return 4.0
	if c.is_in_group("meteorites"):
		return 4.0 if float(c.get("mass") if c.get("mass") != null else 60.0) >= 60.0 else 2.0
	if c.is_in_group("logs"):
		if String(c.item_id).begins_with("short"):
			return 1.0
		match String(c.kind):
			"sigillaria":
				return 4.0
			"lepidodendron":
				return 2.0
		return 2.0 / 3.0   # up to six soft logs
	if c.get("item_id") == "wooden_bed":
		return 4.0
	if c.is_in_group("furniture"):
		return 2.0 if c.item_id == "wooden_table" else 1.0
	if "species" in c:
		return 2.0 if c.haul_mode() == "drag" else 1.0
	return 2.0


func takes(c: Node) -> bool:
	if c == self or c.is_in_group("handcarts"):
		return false
	for g in LOADS:
		if c.is_in_group(g):
			return true
	return "species" in c


func used() -> float:
	_drop_gone()
	var n := 0.0
	for c in cargo:
		n += space_for(c)
	return n


func has_room_for(c: Node) -> bool:
	return c in cargo or used() + space_for(c) <= SPACES + 0.01


func cargo_point() -> Vector3:
	return to_global(Vector3(0, BED_Y, 0.1))


func stow(c: Node3D) -> void:
	if not is_instance_valid(c) or c.is_queued_for_deletion() or c.get("hauled_by") != null or c in cargo:
		return
	if c.has_meta("cart_load"):
		c.remove_meta("cart_load")
	cargo.append(c)
	_yaws.append(wrapf(c.rotation.y - rotation.y, -PI, PI))
	_carry()


func _drop_gone() -> void:
	for i in range(cargo.size() - 1, -1, -1):
		var c = cargo[i]
		if not is_instance_valid(c) or c.is_queued_for_deletion() or c.get("hauled_by") != null:
			cargo.remove_at(i)
			_yaws.remove_at(i)


func _adopt() -> void:
	## After a load: what was saved lying on the bed rides again.
	for g in LOADS:
		for n in get_tree().get_nodes_in_group(g):
			if n in cargo or n.is_queued_for_deletion() or n.get("hauled_by") != null:
				continue
			var at: Vector3 = to_local(n.global_position)
			if absf(at.x) < 0.7 and at.z > -0.8 and at.z < 1.0 and at.y > BED_Y - 0.2 and at.y < BED_Y + 1.2:
				cargo.append(n)
				_yaws.append(wrapf(n.rotation.y - rotation.y, -PI, PI))


func _carry() -> void:
	var fill := 0.0
	for i in cargo.size():
		var c: Node3D = cargo[i]
		var s := space_for(c)
		var z: float = -0.45 + (fill + s * 0.5) * 0.32
		var layer := floori(fill / 2.0)
		c.global_position = to_global(Vector3(0, BED_Y + layer * 0.26, z))
		c.rotation = Vector3(0, wrapf(rotation.y + _yaws[i], -PI, PI), 0)
		fill += s


func load_kg() -> float:
	var kg := 0.0
	for c in cargo:
		if is_instance_valid(c):
			if c.get("inv") != null:
				kg += c.inv.weight()
			kg += float(c.get("mass")) if c.get("mass") != null else 20.0
	return kg


# --- Pulling it ----------------------------------------------------------------------

func can_haul() -> bool:
	return true


func haul_mode() -> String:
	return "pull"


func haul_name() -> String:
	return "handcart"


func haul_radius() -> float:
	return HITCH


func haul_yaw() -> float:
	return 0.0


func haul_lift() -> float:
	return 0.0


func haul_speed() -> float:
	## How fast you pull it: its load, and what it rolls on.
	var k := lerpf(0.9, 0.55, clampf(load_kg() / 300.0, 0.0, 1.0))
	if world and world.has_method("ground_height") and world.ground_height(global_position.x, global_position.z) < Terrain.WATER + 0.1:
		k *= 0.75
	return k


func set_hauled(by: Node3D) -> void:
	hauled_by = by
	_shape.disabled = by != null
	if by == null:
		rotation = Vector3(0, rotation.y, 0)
		if world:
			global_position.y = world.floor_height(global_position)
		_carry()


func haul_follow(p: Node3D) -> void:
	## Trails behind whoever pulls it. Where it can't go it stays, and holds
	## them back at arm's length.
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.01:
		return
	var dir := to / d
	var want := p.global_position - dir * HITCH
	if d > HITCH and _can_roll(want, dir):
		global_position = Vector3(want.x, world.floor_height(want), want.z)
	elif d > HITCH + 0.2:
		p.global_position = Vector3(global_position.x + dir.x * (HITCH + 0.2), p.global_position.y, global_position.z + dir.z * (HITCH + 0.2))
		if Time.get_ticks_msec() / 1000.0 - _blocked_said > 6.0:
			_blocked_said = Time.get_ticks_msec() / 1000.0
			Game.notify("The cart won't go that way: too steep, or the water's too deep.")
	rotation.y = atan2(-dir.x, -dir.z)
	_carry()


func _can_roll(at: Vector3, dir: Vector3) -> bool:
	if world == null:
		return true
	var g: float = world.floor_height(at)
	if g < Terrain.WATER - DEEP:
		return false
	var ahead: float = world.floor_height(at + dir * 0.5)
	return absf(ahead - g) / 0.5 <= STEEP


# --- Prompts -------------------------------------------------------------------------

func _at_handles(player: Node) -> bool:
	return to_local(player.global_position).z < -0.3 or cargo.is_empty()


func prompt(player: Node) -> String:
	if _at_handles(player):
		return "Pull the handcart [E]   (%.0f of %d spaces used)" % [used(), int(SPACES)]
	return "Take the %s off the cart [E]" % cargo.back().haul_name()


func interact(player: Node) -> void:
	_drop_gone()
	if _at_handles(player):
		player.start_haul(self)
		return
	var top: Node3D = cargo.back()
	if top.has_method("can_haul") and not top.can_haul():
		Game.notify("Empty the %s first, or right-click it to slide it off." % top.haul_name())
		return
	player.start_haul(top)


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
