extends StaticBody3D
## A pegged board on a house wall (group "wall_racks"): six tools on display,
## each keeping its wear. E on the board hangs what you hold; E on a tool puts
## it straight in your hand (what you held stays in the bag, or takes its peg
## if the bag is full). Three blows take the rack down, its tools with it.
## It is not a workbench rack: tools here teach and enable no recipes.

const SLOTS := 6
const BLOWS := 3

var tools: Array = [null, null, null, null, null, null]   # inventory slots {id, n, age, data}
var world: Node = null
var _pegs: Array = []
var _hits := 0
var _check_t := 0.0


class Peg extends StaticBody3D:
	var rack: Node3D
	var slot := 0

	func prompt(_player: Node) -> String:
		return "Take the %s [E]" % Items.item_name(rack.tools[slot].id).to_lower()

	func interact(player: Node) -> void:
		rack.grab(slot, player)

	func axe_hit() -> void:
		rack.axe_hit()

	func break_apart() -> void:
		rack.axe_hit()


func is_tool(id: String) -> bool:
	return Items.hangs_on_rack(id)


func _ready() -> void:
	add_to_group("wall_racks")
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 0.3, 0.1)
	cs.shape = box
	add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = Assets.mesh("item_wall_rack")
	mi.rotation.x = PI * 0.5
	mi.position.z = -0.02
	add_child(mi)
	_rebuild()


func _process(delta: float) -> void:
	# The wall it was on is gone: it falls, with what hung on it.
	_check_t += delta
	if _check_t < 2.0:
		return
	_check_t = 0.0
	if world and world.has_method("wall_near") and not world.wall_near(global_position):
		take_down()


func free_slot() -> int:
	return tools.find(null)


func hang(data: Dictionary) -> bool:
	var i := free_slot()
	if i < 0:
		return false
	tools[i] = data.duplicate(true)
	tools[i].n = 1
	_rebuild()
	return true


func prompt(_player: Node) -> String:
	var held: String = Game.inventory.held_id()
	if held != "" and is_tool(held):
		if free_slot() < 0:
			return "Wall tool rack: full"
		return "Hang the %s on the rack [E]" % Items.item_name(held).to_lower()
	return "Wall tool rack (%d of %d)   hold a tool to hang it" % [SLOTS - tools.count(null), SLOTS]


func interact(_player: Node) -> void:
	var inv = Game.inventory
	var held: String = inv.held_id()
	if held == "" or not is_tool(held) or free_slot() < 0:
		return
	var s: Dictionary = inv.slots[inv.selected]
	hang({"id": s.id, "n": 1, "age": s.get("age", 0.0), "data": s.get("data", {})})
	inv.take(inv.selected, 1)
	Sfx.play("pickup", -6.0)


func grab(i: int, _player: Node) -> void:
	## Straight into your hand.
	var t = tools[i]
	if t == null:
		return
	var inv = Game.inventory
	var at := -1
	if inv.slots[inv.selected] == null:
		at = inv.selected
	else:
		at = inv.slots.find(null)
	if at < 0:
		# The bag is full: what you hold takes the tool's peg, if it's a tool.
		var held: String = inv.held_id()
		if not is_tool(held):
			Game.notify("Your bag is full.")
			return
		var h: Dictionary = inv.slots[inv.selected]
		tools[i] = {"id": h.id, "n": 1, "age": h.get("age", 0.0), "data": h.get("data", {})}
		inv.slots[inv.selected] = {"id": t.id, "n": 1, "age": t.age, "data": t.get("data", {})}
		inv.changed.emit()
		_rebuild()
		Sfx.play("pickup", -6.0)
		return
	inv.slots[at] = {"id": t.id, "n": 1, "age": t.age, "data": t.get("data", {})}
	inv.selected = at
	inv.changed.emit()
	tools[i] = null
	_rebuild()
	Sfx.play("pickup", -6.0)


func axe_hit() -> void:
	_hits += 1
	Sfx.play_at("hit", global_position, -6.0)
	if _hits >= BLOWS:
		take_down()


func break_apart() -> void:
	axe_hit()


func take_down() -> void:
	## Its tools go to your bag, or your feet; the rack with them.
	var drop := global_position + global_basis.z * 0.6
	for t in tools + [{"id": "wall_rack", "age": 0.0, "data": {}}]:
		if t == null:
			continue
		if Game.inventory.add(t.id, 1, t.age, false, t.get("data", {})) > 0 and world:
			world.spawn_pickup(t.id, 1, drop, t.age, true, t.get("data", {}))
	queue_free()


func _rebuild() -> void:
	for n in _pegs:
		n.queue_free()
	_pegs.clear()
	if not is_inside_tree():
		return
	for i in SLOTS:
		if tools[i] == null:
			continue
		var p := Peg.new()
		p.rack = self
		p.slot = i
		p.collision_layer = 2
		p.collision_mask = 0
		p.position = Vector3(-0.45 + i * 0.18, -0.1, 0.09)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.16, 0.42, 0.08)
		cs.shape = box
		p.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = Assets.mesh("item_" + tools[i].id)
		var size := mi.mesh.get_aabb().size
		var k := minf(1.0, 0.4 / maxf(maxf(size.x, size.z), 0.01))
		mi.transform = Transform3D((Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)).scaled(Vector3.ONE * k), Vector3.ZERO)
		mi.position -= mi.transform.basis * mi.mesh.get_aabb().get_center()
		p.add_child(mi)
		add_child(p)
		_pegs.append(p)


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "tools": tools.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	var saved: Array = d.get("tools", [])
	for i in SLOTS:
		var t = saved[i] if i < saved.size() else null
		tools[i] = t if t != null and Items.exists(String(t.get("id", ""))) else null
	_rebuild()
