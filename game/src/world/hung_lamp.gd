extends StaticBody3D
## A copper or iron lantern hung on a house wall, ceiling or porch (group "hung_lamps").
## It holds up to 24 waxy residue and burns one every WAX game minutes (two a
## day). E with wax tops it up, otherwise E lights it or puts it out; right-click takes it down, keeping
## what the lamp can hold in the hand and giving back the rest.

const WAX := 720.0        # game minutes of light in one waxy residue
const HUNG := 24
const HELD := 6
const RANGE := 15.0

var item_id := "copper_lantern"   # which lantern (they differ only in looks)
var fuel := 0.0           # game minutes left
var lit := false
var world: Node = null
var _last := -1.0
var _light: OmniLight3D
var _mesh: MeshInstance3D


func _ready() -> void:
	add_to_group("hung_lamps")
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.24, 0.3, 0.24)
	cs.shape = box
	cs.position.y = 0.12
	add_child(cs)
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_light = OmniLight3D.new()
	_light.position.y = 0.12
	_light.omni_range = RANGE
	_light.light_energy = 1.0
	_light.light_color = Color(1.0, 0.78, 0.48)
	_light.shadow_enabled = false
	add_child(_light)
	_last = Game.time
	_refresh()


func _refresh() -> void:
	if _mesh:
		_mesh.mesh = Assets.mesh("item_" + item_id + ("_lit" if lit else ""))
	if _light:
		_light.visible = lit


func _process(_delta: float) -> void:
	# By the clock, so a night's sleep burns what it should.
	var dt: float = maxf(Game.time - _last, 0.0)
	_last = Game.time
	if lit:
		fuel = maxf(fuel - dt, 0.0)
		if fuel <= 0.0:
			lit = false
			_refresh()


func wax_left() -> int:
	return ceili(fuel / WAX)


func prompt(_player: Node) -> String:
	var state := "lit" if lit else "out"
	if Game.inventory.count("wax") > 0 and wax_left() < HUNG:
		return "Fill the lantern with wax [E]   (%d/%d, %s; right-click takes it down)" % [wax_left(), HUNG, state]
	if lit:
		return "Put out the lantern [E]   (%d/%d wax; right-click takes it down)" % [wax_left(), HUNG]
	return "Light the lantern [E]   (%d/%d wax; right-click takes it down)" % [wax_left(), HUNG]


func interact(player: Node) -> void:
	var inv = Game.inventory
	var room := HUNG - wax_left()
	var have: int = inv.count("wax")
	if have > 0 and room > 0:
		var n := mini(have, room)
		inv.remove("wax", n)
		fuel += n * WAX
		Game.notify("You fill the lantern: %d of %d wax." % [wax_left(), HUNG])
		Sfx.play("craft", -8.0)
		return
	if lit:
		lit = false
	elif fuel <= 0.0:
		Game.notify("The lantern is dry. It burns waxy residue.")
	elif player.lamp_flame(global_position):
		lit = true
	else:
		Game.notify("You need a flame to light it: a striker, bow drill, torch, ember or a fire close by.")
	_refresh()


func use_interact(_player: Node) -> void:
	## Taken down: it keeps what it can hold in the hand; the rest comes back as wax.
	var keep: float = minf(fuel, HELD * WAX)
	var spare := floori((fuel - keep) / WAX)
	var drop := global_position + global_basis.z * 0.5
	if Game.inventory.add(item_id, 1, 0.0, false, {"fuel": keep}) > 0 and world:
		world.spawn_pickup(item_id, 1, drop, 0.0, true, {"fuel": keep})
	if spare > 0:
		var over: int = Game.inventory.add("wax", spare)
		if over > 0 and world:
			world.spawn_pickup("wax", over, drop, 0.0, true)
	queue_free()


func to_dict() -> Dictionary:
	var p := global_position
	return {"pos": [p.x, p.y, p.z], "yaw": rotation.y, "id": item_id, "fuel": fuel, "lit": lit, "at": Game.time}


func from_dict(d: Dictionary) -> void:
	rotation.y = float(d.get("yaw", 0.0))
	item_id = String(d.get("id", "copper_lantern"))
	fuel = float(d.get("fuel", 0.0))
	lit = bool(d.get("lit", false))
	_last = Game.time
	_refresh()
