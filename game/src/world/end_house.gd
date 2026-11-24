extends "res://src/world/site.gd"
## The end-game houses (construction.md), in Game.houses beside the softwood
## house and answering the same questions (floor_top, shelters, room_spot...):
## - "outpost": a tiny hut on stone footings, one step up, for islands and
##   long trips.
## - "hardwood_house": 8 x 6 m on six Lepidodendron stilts, with a veranda,
##   stairs, and a dividing wall.
## - "dock_house": 5 x 5 m on tall piles out in up to 2.5 m of water, reached
##   by a walkway built out from the shore in 4 m sections, each safe to stand
##   on once finished. A raft can tie up at its mooring.
## Every part needs a saw and a hammer in your bag. Local space: y = 0 is the
## floor, the doorway and veranda face +Z, toward where you stood to mark it.

const Campfire := preload("res://src/world/campfire.gd")

const T := 0.09
const DOOR := Vector2(0.5, 2.0)
const HARD := "hardwood_board"
const SECTION := 4.0
const WALK_W := 0.75     # half the walkway's width
const CFG := {
	"outpost": {"name": "outpost", "hw": 1.3, "back": -1.3, "front": 1.3, "edge": 1.3, "h": 0.45, "wall": 2.1, "ridge": 3.0,
		"eave": Vector2(1.6, 2.0), "roof_z": Vector2(-1.6, 1.6), "hearth": Vector3(0.72, 0, -0.72), "spacing": 7.0, "ramp": 1.3},
	"hardwood_house": {"name": "hardwood house", "hw": 4.0, "back": -3.0, "front": 3.0, "edge": 5.0, "h": 2.2, "wall": 2.8, "ridge": 4.7,
		"eave": Vector2(4.45, 2.6), "roof_z": Vector2(-3.4, 5.3), "hearth": Vector3(-2.9, 0, -2.1), "spacing": 15.0, "ramp": 4.0},
	"dock_house": {"name": "dock house", "hw": 2.5, "back": -2.5, "front": 2.5, "edge": 4.2, "h": 2.5, "wall": 2.5, "ridge": 4.0,
		"eave": Vector2(2.9, 2.35), "roof_z": Vector2(-2.85, 4.5), "hearth": Vector3(1.6, 0, -1.6), "spacing": 13.0, "ramp": 0.0},
}
# Each house has its own look: a trapper's hut, a timber-framed hall in dark
# boards and pale beams, and a tarred, sea-grey boathouse.
const PALETTE := {
	"outpost": {"wood": Color(0.58, 0.47, 0.32), "dark": Color(0.36, 0.27, 0.18), "trim": Color(0.30, 0.22, 0.15), "roof": Color(0.40, 0.33, 0.21)},
	"hardwood_house": {"wood": Color(0.44, 0.27, 0.16), "dark": Color(0.31, 0.20, 0.13), "trim": Color(0.80, 0.68, 0.47), "roof": Color(0.27, 0.25, 0.23)},
	"dock_house": {"wood": Color(0.50, 0.51, 0.46), "dark": Color(0.25, 0.23, 0.21), "trim": Color(0.36, 0.33, 0.29), "roof": Color(0.21, 0.23, 0.25)},
}
const WINDOWS := {
	"outpost": {"left": [0.0], "right": [0.0]},
	"hardwood_house": {"back": [-2.6, 2.6], "left": [-1.3, 1.3], "right": [-1.3, 1.3], "front": [-2.5, 2.5]},
	"dock_house": {"back": [0.0], "left": [0.0], "right": [0.0], "front": [-1.6]},
}
const PANE := Color(0.09, 0.12, 0.13)
const IRON := Color(0.20, 0.20, 0.21)
const STONE := Color(0.50, 0.49, 0.46)
const CLAY := Color(0.56, 0.42, 0.30)

var type := "outpost"
var walk_len := 8.0      # dock house: metres of walkway from the deck to the shore
var fire: Node3D = null
var _fire_save := {}
var _parts: Array = []


func setup(t: String, w: Node, walk := 8.0) -> Node3D:
	type = t
	world = w
	walk_len = walk
	_parts = []
	return self


func cfg() -> Dictionary:
	return CFG[type]


func site_name() -> String:
	return cfg().name


func parts() -> Array:
	if _parts.is_empty():
		_parts = _make_parts()
	return _parts


static func _p(id: String, verb: String, input: Dictionary, steps: int, how := "") -> Dictionary:
	return {"id": id, "verb": verb, "in": input, "steps": steps,
		"how": how if how != "" else "Click the glowing marks to saw, fit and nail each piece."}


static func _log_p(id: String, verb: String, input: Dictionary, steps: int, how: String, kind: String, pound: bool) -> Dictionary:
	## A part built around a log carried here; `pound` needs a river stone too.
	var part_def := _p(id, verb, input, steps, how)
	part_def["log"] = true
	part_def["log_kind"] = kind
	if pound:
		part_def["tools"] = {"stone": 1}
	return part_def


func sections() -> int:
	return maxi(ceili(walk_len / SECTION), 1)


func _make_parts() -> Array:
	var out := []
	match type:
		"outpost":
			out.append(_p("footings", "Lay the stone footings", {"stone": 8}, 8, "Click to bed each river stone into the ground."))
			out.append(_p("floor", "Lay the platform", {"board": 5, "any_nail": 4}, 6))
			out.append(_p("walls", "Put up the walls and doorway", {"board": 6, "any_nail": 6}, 8))
			out.append(_p("roof", "Roof the outpost", {"board": 5, "any_nail": 4}, 6))
			out.append(_p("fireplace", "Build the small hearth", {"stone": 4, "clay": 3}, 6, "Click to set each stone and daub it with wet clay."))
		"hardwood_house":
			for i in 6:
				out.append(_log_p("stilt_%d" % i, "Raise stilt %d of 6" % (i + 1), {}, 6,
						"Click to stand the log up and pound it in with a river stone.", "lepidodendron", true))
			out.append(_p("floor", "Lay the floor", {HARD: 24, "any_nail": 12}, 18))
			out.append(_p("porch", "Lay the veranda", {HARD: 12, "any_nail": 6}, 10))
			out.append(_p("stairs", "Build the stairs", {HARD: 8, "any_nail": 6}, 10))
			out.append(_p("wall_back", "Put up the back wall", {HARD: 10, "any_nail": 5}, 8))
			out.append(_p("wall_left", "Put up the left wall", {HARD: 8, "any_nail": 4}, 7))
			out.append(_p("wall_right", "Put up the right wall", {HARD: 8, "any_nail": 4}, 7))
			out.append(_p("wall_front", "Put up the front wall", {HARD: 10, "any_nail": 5}, 8))
			out.append(_p("wall_div", "Put up the dividing wall", {HARD: 6, "any_nail": 3}, 5))
			out.append(_p("fireplace", "Build the large fireplace", {"stone": 16, "clay": 12}, 20, "Click to set each stone and daub it with wet clay."))
			out.append(_p("ceiling", "Lay the ceiling", {HARD: 20, "any_nail": 10}, 16))
			out.append(_p("roof_left", "Roof the left side", {HARD: 14, "any_nail": 7}, 12))
			out.append(_p("roof_right", "Roof the right side", {HARD: 14, "any_nail": 7}, 12))
		"dock_house":
			for i in sections():
				out.append(_log_p("walk_%d_a" % i, "Set the piles of walkway section %d of %d" % [i + 1, sections()], {}, 2,
						"Click to drive the Calamites log in as a pile.", "calamites", false))
				out.append(_log_p("walk_%d_b" % i, "Deck walkway section %d of %d" % [i + 1, sections()], {"board": 4, "any_nail": 4}, 4,
						"Click the glowing marks to saw, fit and nail each piece.", "calamites", false))
			for i in 6:
				for j in 3:
					out.append(_log_p("pile_%d_%d" % [i, j], "Raise tall pile %d of 6 (log %d of 3)" % [i + 1, j + 1], {} if j == 0 else {"any_nail": 2}, 2,
							"Click to drive the log down and scarf the next one on.", "calamites", j == 0))
			out.append(_p("floor", "Lay the floor", {"board": 14, "any_nail": 7}, 12))
			out.append(_p("porch", "Lay the deck", {"board": 10, "any_nail": 5}, 9))
			out.append(_p("stairs", "Build the water stairs", {"board": 4, "any_nail": 4}, 6))
			for side in ["back", "left", "right", "front"]:
				out.append(_p("wall_" + side, "Put up the %s wall" % side, {"board": 6, "any_nail": 3}, 5))
			out.append(_p("fireplace", "Build the fireplace", {"stone": 10, "clay": 8}, 16, "Click to set each stone and daub it with wet clay."))
			out.append(_p("ceiling", "Lay the ceiling", {"board": 12, "any_nail": 6}, 12))
			out.append(_p("roof_left", "Roof the left side", {"board": 8, "any_nail": 4}, 10))
			out.append(_p("roof_right", "Roof the right side", {"board": 8, "any_nail": 4}, 10))
			out.append(_p("mooring", "Set the mooring", {"branch": 1, "cordage": 2}, 3, "Click to set the post and tie on a line."))
	return out


func _ready() -> void:
	super()
	if preview:
		return
	add_to_group("houses")
	Game.houses.append(self)
	if built.has("fireplace"):
		_make_fire()


func _exit_tree() -> void:
	Game.houses.erase(self)


func _make_fire() -> void:
	if fire:
		return
	fire = Campfire.new()
	fire.hearth = true
	fire.fuel = 0.0
	fire.position = cfg().hearth
	add_child(fire)
	if not _fire_save.is_empty():
		fire.from_dict(_fire_save)
		_fire_save = {}


func _on_part(id: String) -> void:
	if id == "fireplace":
		_make_fire()


func _on_complete(tell := true) -> void:
	Game.crafted.emit(type + "_built")
	if tell:
		Game.notify("The %s is finished: shelter from the rain, and a place to sleep." % site_name())


func hearth_point() -> Vector3:
	return to_global(cfg().hearth)


# --- Building --------------------------------------------------------------------------

func log_word() -> String:
	var p := next_part()
	return "%s log" % ("Lepidodendron" if p.get("log_kind", "") == "lepidodendron" else "Calamites")


func takes_log(lg: Node) -> bool:
	var p := next_part()
	if not p.get("log", false) or not lg.item_id in ["log", "log_stripped"]:
		return false
	return lg.kind == p.get("log_kind", "calamites")


func missing_for(r: Dictionary, log_id: String, player: Node3D) -> Array:
	var missing: Array = super(r, log_id, player)
	if r.get("log", false) and log_id == "" and not missing.is_empty():
		missing[0] = "a %s, brought here" % log_word()
	for tag in ["saw", "hammer"]:
		if not Game.inventory.has_tag(tag):
			missing.append("a %s in your bag" % tag)
	return missing


func log_kind_for(_item: String) -> String:
	return "lepidodendron" if type == "hardwood_house" else "calamites"


func face_point(p: Dictionary) -> Vector3:
	var hits := _pieces(p.id, 0)
	if not hits.is_empty():
		return to_global(_centre(hits[0]))
	return to_global(Vector3.ZERO)


# --- Where things are ---------------------------------------------------------------------

func _walk_z() -> Vector2:
	## The walkway's z range: from the deck's edge out to the shore.
	return Vector2(cfg().edge, cfg().edge + walk_len)


func _shore_y() -> float:
	var at := to_global(Vector3(0, 0, _walk_z().y))
	return _ground(at) - global_position.y


func _walk_top(z: float) -> float:
	var w := _walk_z()
	return lerpf(0.0, _shore_y(), clampf((z - w.x) / maxf(w.y - w.x, 0.1), 0.0, 1.0))


func _section_of(z: float) -> int:
	## Walkway sections count from the shore.
	return clampi(int((_walk_z().y - z) / (walk_len / sections())), 0, sections() - 1)


func _section_done(i: int) -> bool:
	return built.has("walk_%d_b" % i)


func floor_top(p: Vector3) -> float:
	if preview:
		return -INF
	var c := cfg()
	var l := to_local(p)
	if type == "dock_house" and absf(l.x) <= WALK_W + 0.02 and l.z > c.edge and l.z <= _walk_z().y + 0.05:
		if _section_done(_section_of(l.z)):
			var t: float = _walk_top(l.z)
			if l.y > t - 0.9 and l.y < t + 2.6:
				return global_position.y + t
		return -INF
	if float(c.ramp) > 0.0 and built.has("stairs" if type != "outpost" else "floor") and absf(l.x) <= 0.8 and l.z > c.edge and l.z <= c.edge + c.ramp:
		var t: float = -float(c.h) * (l.z - c.edge) / c.ramp
		if l.y > t - 0.7 and l.y < t + 2.0:
			return global_position.y + t
	if absf(l.x) > c.hw + 0.02 or l.y < -0.8 or l.y > c.wall + 1.0:
		return -INF
	if l.z >= c.back - 0.02 and l.z <= c.front and built.has("floor"):
		return global_position.y
	if l.z > c.front and l.z <= c.edge + 0.02 and built.has("porch"):
		return global_position.y
	return -INF


func on_floor(p: Vector3) -> bool:
	return floor_top(p) > -INF and absf(p.y - global_position.y) < 0.5


func shelters(p: Vector3) -> bool:
	if preview or not complete():
		return false
	var c := cfg()
	var l := to_local(p)
	return absf(l.x) <= c.hw + 0.1 and l.z >= c.back - 0.1 and l.z <= c.edge + 0.1 and l.y > -0.5 and l.y < c.ridge


func guards(p: Vector3) -> bool:
	## Each finished walkway section, the deck, and the water right round the house.
	if preview:
		return false
	var c := cfg()
	var l := to_local(p)
	if type != "dock_house":
		return false
	if absf(l.x) <= WALK_W + 1.5 and l.z > c.edge and l.z <= _walk_z().y:
		return _section_done(_section_of(l.z))
	return complete() and absf(l.x) <= c.hw + 3.0 and l.z >= c.back - 3.0 and l.z <= c.edge + 3.0


func berth() -> Vector3:
	return to_global(Vector3(cfg().hw + 1.7, _water() - global_position.y + 0.1, 3.3))


func room_spot(p: Vector3, inset := 0.0) -> bool:
	if preview or not complete() or not on_floor(p):
		return false
	var c := cfg()
	var l := to_local(p)
	return absf(l.x) <= c.hw - T - inset and l.z >= c.back + T + inset and l.z <= c.front - T - inset


func keeps_out(p: Vector3) -> bool:
	## The water predators treat a dock house like a finished dock (dock.gd).
	return guards(p)


func way_out(p: Vector3) -> Vector3:
	## The nearest point just past the guarded water, for a predator caught in it.
	var c := cfg()
	var l := to_local(p)
	var sgn := signf(l.x if l.x != 0.0 else 1.0)
	if l.z > c.edge + 3.0:
		return to_global(Vector3(sgn * (WALK_W + 2.5), l.y, l.z))
	var side: float = c.hw + 4.0
	if side - absf(l.x) < l.z - (c.back - 4.0):
		return to_global(Vector3(sgn * side, l.y, l.z))
	return to_global(Vector3(l.x, l.y, c.back - 4.0))


func covers(p: Vector3, margin := 0.0) -> bool:
	var c := cfg()
	var l := to_local(p)
	if type == "dock_house" and absf(l.x) <= WALK_W + margin and l.z >= c.edge and l.z <= _walk_z().y + margin:
		return true
	return absf(l.x) <= c.eave.x + margin and l.z >= c.roof_z.x - margin and l.z <= maxf(c.roof_z.y, c.edge + c.ramp) + margin


func ladder_at(_p: Vector3) -> bool:
	return false


func roof_built() -> Vector2:
	## The roof's x range, for the rain (0 where a side is missing).
	var c := cfg()
	if built.has("roof"):
		return Vector2(-c.eave.x, c.eave.x)
	return Vector2(-c.eave.x if built.has("roof_left") else 0.0, c.eave.x if built.has("roof_right") else 0.0)


func rain_map(eave: Vector2, ridge: float, half_z: float) -> Transform3D:
	## World to a space where this roof has the softwood roof's proportions,
	## so the rain shader's one roof shape fits it.
	var c := cfg()
	var mid: float = (c.roof_z.x + c.roof_z.y) * 0.5
	var half: float = (c.roof_z.y - c.roof_z.x) * 0.5
	var k: float = (ridge - eave.y) / (c.ridge - c.eave.y)
	var s: Basis = Basis.from_scale(Vector3(eave.x / c.eave.x, k, half_z / half))
	var o: Vector3 = Vector3(0, eave.y - c.eave.y * k, -mid * half_z / half)
	return Transform3D(s, o) * global_transform.affine_inverse()


func _on_torn_down() -> void:
	for n in get_tree().get_nodes_in_group("bedrolls"):
		if not n.is_queued_for_deletion() and covers(n.global_position):
			if world:
				world.spawn_pickup("bedroll", 1, Vector3(n.global_position.x, _ground(n.global_position) + 0.2, n.global_position.z), 0.0, true)
			n.queue_free()
	for g in ["stashes", "stacks", "drops", "workbenches", "furniture", "handcarts", "vessels"]:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node3D and not n.is_queued_for_deletion() and covers(n.global_position) and to_local(n.global_position).y > -0.9:
				n.global_position.y = _ground(n.global_position)


# --- Looks ------------------------------------------------------------------------------

func pal() -> Dictionary:
	return PALETTE[type]


func _roof_y(x: float) -> float:
	## The underside of the roof above local x.
	var c := cfg()
	return c.ridge - (c.ridge - c.eave.y) * absf(x) / c.eave.x


func _wall_len(wall: String) -> float:
	var c := cfg()
	return c.hw * 2.0 if wall in ["back", "front"] else c.front - c.back


func _on_wall(s: int, wall: String, u: float, y: float, su: float, sy: float, col: Color, depth := 0.05, off := 0.07, tilt := 0.0) -> Dictionary:
	## A box on a wall's outer face: u runs along the wall from its middle.
	var c := cfg()
	var mid: float = (c.back + c.front) * 0.5
	match wall:
		"back":
			return _box(s, Vector3(u, y, c.back - off), Vector3(su, sy, depth), col, "wood", Basis(Vector3.BACK, tilt))
		"front":
			return _box(s, Vector3(u, y, c.front + off), Vector3(su, sy, depth), col, "wood", Basis(Vector3.BACK, tilt))
		"left":
			return _box(s, Vector3(-c.hw - off, y, mid + u), Vector3(depth, sy, su), col, "wood", Basis(Vector3.RIGHT, tilt))
	return _box(s, Vector3(c.hw + off, y, mid + u), Vector3(depth, sy, su), col, "wood", Basis(Vector3.RIGHT, tilt))


func _window(s: int, wall: String, u: float) -> Array:
	## A framed window with a cross bar, a sill, and its shutters folded back.
	var w := 0.72
	var h := 0.86
	var y := 1.42
	var t: Color = pal().trim
	var out := [_on_wall(s, wall, u, y, w, h, PANE, T + 0.03, 0.0)]
	for side in [-1.0, 1.0]:
		out.append(_on_wall(s, wall, u + side * (w + 0.08) * 0.5, y, 0.08, h + 0.16, t, T + 0.08, 0.0))
		out.append(_on_wall(s, wall, u, y + side * (h + 0.08) * 0.5, w + 0.16, 0.08, t, T + 0.08, 0.0))
		var at: float = u + side * (w * 0.75 + 0.1)
		out.append(_on_wall(s, wall, at, y, w * 0.5, h, pal().dark, 0.035, 0.075))
		for b in [-0.27, 0.27]:
			out.append(_on_wall(s, wall, at, y + b, w * 0.5 + 0.02, 0.05, t, 0.03, 0.1))
	out.append(_on_wall(s, wall, u, y, 0.035, h, t, T + 0.05, 0.0))
	out.append(_on_wall(s, wall, u, y, w, 0.035, t, T + 0.05, 0.0))
	out.append(_on_wall(s, wall, u, y - h * 0.5 - 0.1, w + 0.3, 0.06, t, 0.2, 0.08))
	return out


func _door(s: int) -> Array:
	## The door frame, and a plank door standing open against the front wall.
	var c := cfg()
	var t: Color = pal().trim
	var out := []
	for side in [-1.0, 1.0]:
		out.append(_on_wall(s, "front", side * (DOOR.x + 0.05), DOOR.y * 0.5, 0.1, DOOR.y, t, T + 0.08, 0.0))
	out.append(_on_wall(s, "front", 0.0, DOOR.y + 0.06, DOOR.x * 2.0 + 0.3, 0.13, t, T + 0.1, 0.0))
	var leaf: float = minf(0.9, c.hw - DOOR.x - 0.14)
	var at: float = DOOR.x + 0.1 + leaf * 0.5
	for i in 4:
		out.append(_on_wall(s, "front", at - leaf * 0.5 + leaf * (i + 0.5) / 4.0, 0.97, leaf / 4.0 - 0.012, 1.9, pal().dark * _shade(i + 2), 0.04, 0.09))
	for y in [0.4, 1.55]:
		out.append(_on_wall(s, "front", at, y, leaf, 0.07, IRON, 0.02, 0.12))
	return out


func _wall_trim(wall: String, s: int) -> Array:
	## The frame on a wall's outside, its windows, and on the front its door.
	var c := cfg()
	var h: float = c.wall
	var l := _wall_len(wall)
	var t: Color = pal().trim
	var out := []
	for side in [-1.0, 1.0]:
		out.append(_on_wall(s, wall, side * (l * 0.5 - 0.02), h * 0.5, 0.17, h, t, 0.13))
	out.append(_on_wall(s, wall, 0.0, 0.08, l + 0.12, 0.16, t, 0.12))
	out.append(_on_wall(s, wall, 0.0, h - 0.07, l + 0.12, 0.14, t, 0.12))
	if type == "hardwood_house":
		# Pegged corner braces, the mark of a timber frame.
		for side in [-1.0, 1.0]:
			var bu: float = side * (l * 0.5 - 0.42)
			var turn: float = side * PI * 0.25 if wall in ["back", "front"] else -side * PI * 0.25
			out.append(_on_wall(s, wall, bu, h - 0.44, 0.86, 0.1, t, 0.08, 0.09, turn))
			out.append(_on_wall(s, wall, bu, 0.44, 0.86, 0.1, t, 0.08, 0.09, -turn))
	elif type == "dock_house":
		out.append(_on_wall(s, wall, 0.0, 0.3, l, 0.5, pal().dark, 0.04, 0.07))
	for u in WINDOWS[type].get(wall, []):
		out.append_array(_window(s, wall, float(u)))
	if wall == "front":
		out.append_array(_door(s))
	return out


func _gable(side: int, s: int) -> Array:
	## Boards closing the triangle under one side of the roof, front and back.
	var c := cfg()
	var n := ceili(c.hw / 0.08)   # slivers fine enough to follow the roof's slope
	var out := []
	for i in n:
		var x: float = side * c.hw * (i + 0.5) / n
		var top: float = _roof_y(x) + 0.03
		if top <= c.wall + 0.02:
			continue
		for z in [c.back, c.front]:
			out.append(_box(s, Vector3(x, (c.wall + top) * 0.5, z), Vector3(c.hw / n + 0.002, top - c.wall, T), pal().wood * _shade(i / 4 + 4)))
	return out


func _rail_runs() -> Array:
	## Where the porch railing runs, as [from, to] in local space: open at
	## the stairs or the walkway.
	var c := cfg()
	var x: float = c.hw - 0.05
	var z: float = c.edge - 0.05
	var gap: float = WALK_W + 0.12 if type == "dock_house" else 0.9
	var runs := [[Vector3(-x, 0, c.front), Vector3(-x, 0, z)], [Vector3(-x, 0, z), Vector3(-gap, 0, z)], [Vector3(gap, 0, z), Vector3(x, 0, z)]]
	if type != "dock_house":  # the dock house's water stairs leave that side
		runs.append([Vector3(x, 0, c.front), Vector3(x, 0, z)])
	return runs


func _rail_pieces(s: int) -> Array:
	var c := cfg()
	var t: Color = pal().trim
	var out := []
	for run in _rail_runs():
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var along := b - a
		var size := Vector3(absf(along.x) + 0.08, 0.07, absf(along.z) + 0.08)
		out.append(_box(s, (a + b) * 0.5 + Vector3(0, 0.95, 0), size, t))
		out.append(_box(s, (a + b) * 0.5 + Vector3(0, 0.2, 0), size * Vector3(1, 0.7, 1), t))
		var n := maxi(ceili(along.length() / 0.32), 1)
		for i in n + 1:
			out.append(_box(s, a + along * (float(i) / n) + Vector3(0, 0.55, 0), Vector3(0.05, 0.75, 0.05), pal().dark))
	for x in [-(c.hw - 0.05), c.hw - 0.05]:
		var at := Vector3(x, 0, c.edge - 0.05)
		out.append(_cyl(s, at, at + Vector3(0, _roof_y(x), 0), 0.085, t))
	return out


func _under_frame(s: int) -> Array:
	## The rim round the floor and the cross-bracing between its stilts.
	var c := cfg()
	var d: Color = pal().dark
	var depth: float = c.edge - c.back
	var mid: float = (c.back + c.edge) * 0.5
	var out := [_box(s, Vector3(-c.hw, -0.16, mid), Vector3(0.12, 0.22, depth), d), _box(s, Vector3(c.hw, -0.16, mid), Vector3(0.12, 0.22, depth), d),
		_box(s, Vector3(0, -0.16, c.back), Vector3(c.hw * 2.0, 0.22, 0.12), d), _box(s, Vector3(0, -0.16, c.edge), Vector3(c.hw * 2.0, 0.22, 0.12), d)]
	if type == "outpost":
		return out
	var posts := _posts()
	for pair in [[0, 2], [2, 4], [1, 3], [3, 5], [0, 1]]:
		var p0: Vector3 = posts[pair[0]]
		var p1: Vector3 = posts[pair[1]]
		var low: float = maxf(_ground_local(p0), _ground_local(p1)) + 0.35
		if type == "dock_house":
			low = maxf(low, _water() - global_position.y + 0.15)
		if low < -0.45:
			out.append(_cyl(s, p0 + Vector3(0, low, 0), p1 + Vector3(0, -0.2, 0), 0.05, d))
			out.append(_cyl(s, p1 + Vector3(0, low, 0), p0 + Vector3(0, -0.2, 0), 0.05, d))
	return out


func _posts() -> Array:
	var c := cfg()
	var x: float = c.hw - 0.2
	var z0: float = c.back + 0.2
	var z1: float = c.edge - 0.2
	return [Vector3(-x, 0, z0), Vector3(x, 0, z0), Vector3(-x, 0, (z0 + z1) * 0.5), Vector3(x, 0, (z0 + z1) * 0.5), Vector3(-x, 0, z1), Vector3(x, 0, z1)]


func _strips(steps: int, c: Vector3, size: Vector3, axis: int, col: Color) -> Array:
	## A panel laid as `steps` boards side by side along an axis.
	var out := []
	for i in steps:
		var sz := size
		sz[axis] = size[axis] / steps - 0.008
		var at := c
		at[axis] = c[axis] - size[axis] * 0.5 + size[axis] * (i + 0.5) / steps
		out.append(_box(i, at, sz, col * _shade(i)))
	return out


func _wall_pieces(id: String, steps: int) -> Array:
	var c := cfg()
	var h: float = c.wall
	var y := h * 0.5
	match id:
		"wall_back":
			return _strips(steps, Vector3(0, y, c.back), Vector3(c.hw * 2.0, h, T), 0, pal().wood)
		"wall_left":
			return _strips(steps, Vector3(-c.hw, y, (c.back + c.front) * 0.5), Vector3(T, h, c.front - c.back), 2, pal().wood)
		"wall_right":
			return _strips(steps, Vector3(c.hw, y, (c.back + c.front) * 0.5), Vector3(T, h, c.front - c.back), 2, pal().wood)
		"wall_front":
			return _front_pieces(steps, c.front, c.hw)
		"wall_div":
			var out := _strips(maxi(steps - 2, 1), Vector3(0.9, y, (c.back + c.front - 1.2) * 0.5), Vector3(T, h, c.front - c.back - 1.2), 2, pal().dark)
			out.append(_box(steps - 2, Vector3(0.9, (h + DOOR.y) * 0.5, c.front - 0.6), Vector3(T, h - DOOR.y, 1.2), pal().dark))
			out.append(_box(steps - 1, Vector3(0.9, y, c.front - 0.02), Vector3(T, h, 0.04), pal().dark))
			return out
	return []


func _front_pieces(steps: int, z: float, hw: float) -> Array:
	var c := cfg()
	var h: float = c.wall
	var side: float = hw - DOOR.x
	var out := []
	var n := maxi((steps - 1) / 2, 1)
	for i in n:
		var w := side / n
		out.append(_box(i * 2, Vector3(-hw + w * (i + 0.5), h * 0.5, z), Vector3(w - 0.008, h, T), pal().wood * _shade(i)))
		out.append(_box(i * 2 + 1, Vector3(hw - w * (i + 0.5), h * 0.5, z), Vector3(w - 0.008, h, T), pal().wood * _shade(i + 3)))
	out.append(_box(steps - 1, Vector3(0, (h + DOOR.y) * 0.5, z), Vector3(DOOR.x * 2.0, h - DOOR.y, T), pal().dark))
	return out


func _roof_pieces(side: int, steps: int) -> Array:
	## Staggered shingles laid in courses from the eave up, one course a
	## step, with barge boards at the ends and a ridge cap to finish.
	var c := cfg()
	var run: float = c.eave.x
	var rise: float = c.ridge - c.eave.y
	var len := Vector2(run, rise).length()
	var basis := Basis(Vector3.BACK, side * -atan2(rise, run))
	var zl: float = c.roof_z.y - c.roof_z.x
	var cols := maxi(ceili(zl / 0.62), 2)
	var col: Color = pal().roof
	var out := []
	for i in steps:
		var f := (i + 0.5) / steps
		var at := Vector3(side * run * (1.0 - f), c.eave.y + rise * f + 0.05, 0)
		var offset := 0.5 if i % 2 == 1 else 0.0
		for j in cols + (1 if i % 2 == 1 else 0):
			var z0: float = maxf(c.roof_z.x, c.roof_z.x + zl * (j - offset) / cols)
			var z1: float = minf(c.roof_z.y, c.roof_z.x + zl * (j + 1 - offset) / cols)
			at.z = (z0 + z1) * 0.5
			out.append(_box(i, at, Vector3(len / steps * 1.16, 0.05, z1 - z0 - 0.012), col * (0.86 + 0.14 * absf(sin(i * 2.3 + j * 1.9))), "wood", basis))
	var last := steps - 1
	var mid := Vector3(side * run * 0.5, (c.ridge + c.eave.y) * 0.5 + 0.07, 0)
	for z in [c.roof_z.x, c.roof_z.y]:
		mid.z = z
		out.append(_box(last, mid, Vector3(len + 0.1, 0.09, 0.09), pal().trim, "wood", basis))
	out.append_array(_gable(side, last))
	if side > 0:
		out.append(_box(last, Vector3(0, c.ridge + 0.11, (c.roof_z.x + c.roof_z.y) * 0.5), Vector3(0.24, 0.09, zl + 0.08), pal().trim))
	return out


func _pieces(id: String, _k: int) -> Array:
	var c := cfg()
	var p := part(id)
	var steps: int = p.get("steps", 1)
	if id.begins_with("stilt_"):
		var at: Vector3 = _posts()[int(id.get_slice("_", 1))]
		return [_cyl(0, at + Vector3(0, _ground_local(at) - 0.3, 0), at + Vector3(0, -0.06, 0), 0.2, pal().dark)]
	if id.begins_with("pile_"):
		var at: Vector3 = _posts()[int(id.get_slice("_", 1))]
		var j := int(id.get_slice("_", 2))
		var low: float = _ground_local(at) - 0.3
		var a: float = lerpf(low, -0.06, j / 3.0)
		var b: float = lerpf(low, -0.06, (j + 1) / 3.0)
		return [_cyl(0, at + Vector3(0, a, 0), at + Vector3(0, b, 0), 0.17, pal().dark)]
	if id.begins_with("walk_"):
		return _walk_pieces(int(id.get_slice("_", 1)), id.ends_with("_b"))
	if id.begins_with("wall_"):
		var wall_out := _wall_pieces(id, steps)
		if id != "wall_div":
			wall_out.append_array(_wall_trim(id.trim_prefix("wall_"), steps - 1))
		return wall_out
	match id:
		"footings":
			var out := []
			for i in 8:
				var a := i * TAU / 8.0 + 0.39
				var at := Vector3(cos(a) * c.hw * 1.15, 0, sin(a) * c.hw * 1.15)
				out.append(_blob(i, at + Vector3(0, _ground_local(at) + 0.1, 0), Vector3(0.24, 0.22, 0.24), STONE))
			return out
		"floor":
			var out := _strips(steps, Vector3(0, -0.05, (c.back + c.front) * 0.5), Vector3(c.hw * 2.0, 0.1, c.front - c.back), 2, pal().wood)
			if type == "outpost":
				out.append(_box(steps - 1, Vector3(0, -c.h * 0.5, c.edge + c.ramp * 0.5), Vector3(1.6, 0.08, Vector2(c.ramp, c.h).length()),
						pal().wood, "wood", Basis(Vector3.RIGHT, atan2(c.h, c.ramp))))
			out.append_array(_under_frame(steps - 1))
			return out
		"porch":
			return _strips(steps, Vector3(0, -0.05, (c.front + c.edge) * 0.5), Vector3(c.hw * 2.0, 0.1, c.edge - c.front), 2, pal().wood * 1.12) \
					+ _rail_pieces(steps - 1)
		"stairs":
			if type == "dock_house":
				var drop: float = _water() - global_position.y + 0.15
				var out := []
				for i in steps:
					var f := (i + 1.0) / steps
					out.append(_box(i, Vector3(c.hw + f * 1.4, drop * f, 3.3), Vector3(0.3, 0.06, 1.0), pal().wood))
				for side_z in [2.78, 3.82]:
					out.append(_cyl(steps - 1, Vector3(c.hw, 0.0, side_z), Vector3(c.hw + 1.4, drop, side_z), 0.06, pal().trim))
				return out
			var out := []
			for i in steps:
				var f := (i + 1.0) / steps
				out.append(_box(i, Vector3(0, -c.h * f, c.edge + c.ramp * f), Vector3(1.6, 0.08, c.ramp / steps + 0.08), pal().wood))
			for x in [-0.84, 0.84]:
				out.append(_cyl(steps - 1, Vector3(x, 0.0, c.edge), Vector3(x, -c.h, c.edge + c.ramp), 0.07, pal().trim))
			return out
		"walls":
			var n := steps / 4
			var out := []
			for q in _strips(n, Vector3(0, c.wall * 0.5, c.back), Vector3(c.hw * 2.0, c.wall, T), 0, pal().wood):
				out.append(q)
			var l := _strips(n, Vector3(-c.hw, c.wall * 0.5, 0), Vector3(T, c.wall, c.front - c.back), 2, pal().wood)
			var r := _strips(n, Vector3(c.hw, c.wall * 0.5, 0), Vector3(T, c.wall, c.front - c.back), 2, pal().wood)
			for q in l + r:
				q.s += n if q in l else n * 2
				out.append(q)
			for q in _front_pieces(steps - n * 3, c.front, c.hw):
				q.s += n * 3
				out.append(q)
			for w in ["back", "left", "right", "front"]:
				out.append_array(_wall_trim(w, steps - 1))
			return out
		"fireplace":
			var out := []
			for i in steps:
				var a := i * TAU / maxf(steps - 3, 1)
				if i < steps - 3:
					out.append(_blob(i, c.hearth + Vector3(cos(a) * 0.48, 0.08, sin(a) * 0.48), Vector3(0.14, 0.1, 0.14), STONE))
				else:
					var back: Vector3 = c.hearth + Vector3(0, 0, -0.42)
					var top: float = _roof_y(back.x) + 0.6
					match i - (steps - 3):
						0:
							out.append(_box(i, back + Vector3(0, 0.55, 0), Vector3(0.95, 1.1, 0.34), STONE, "stone"))
						1:
							out.append(_box(i, back + Vector3(0, (1.1 + top) * 0.5, 0), Vector3(0.46, top - 1.1, 0.34), CLAY, "stone"))
						_:
							out.append(_box(i, back + Vector3(0, top + 0.05, 0), Vector3(0.6, 0.12, 0.46), STONE, "stone"))
			return out
		"ceiling":
			return _strips(steps, Vector3(0, c.wall + 0.03, (c.back + c.front) * 0.5), Vector3(c.hw * 2.0, 0.06, c.front - c.back), 2, pal().dark)
		"roof":
			return _roof_pieces(-1, steps / 2) + _shift(_roof_pieces(1, steps - steps / 2), steps / 2)
		"roof_left":
			return _roof_pieces(-1, steps)
		"roof_right":
			return _roof_pieces(1, steps)
		"mooring":
			var at := Vector3(c.hw + 0.3, 0, 3.3)
			return [_cyl(0, at + Vector3(0, _water() - global_position.y - 0.6, 0), at + Vector3(0, 0.9, 0), 0.09, pal().dark)] \
					+ _lash(1, at + Vector3(0, 0.6, 0), Vector3.UP, 0.1) + _lash(2, at + Vector3(0, 0.45, 0), Vector3.UP, 0.1)
	return []


func _shift(a: Array, by: int) -> Array:
	for q in a:
		q.s += by
	return a


func _walk_pieces(i: int, deck: bool) -> Array:
	var w := _walk_z()
	var seg: float = walk_len / sections()
	var z1: float = w.y - seg * i
	var z0: float = z1 - seg
	if not deck:
		var out := []
		for side in [-1, 1]:
			var at := Vector3(side * WALK_W, 0, (z0 + z1) * 0.5)
			out.append(_cyl(0 if side < 0 else 1, at + Vector3(0, _ground_local(at) - 0.3, 0), at + Vector3(0, _walk_top(at.z) + 0.7, 0), 0.13, pal().dark))
		return out
	var out := []
	for k in 4:
		var a: float = lerpf(z0, z1, k / 4.0)
		var b: float = lerpf(z0, z1, (k + 1) / 4.0)
		var ta: float = _walk_top(a)
		var tb: float = _walk_top(b)
		var c := Vector3(0, (ta + tb) * 0.5 - 0.04, (a + b) * 0.5)
		var basis := Basis(Vector3.RIGHT, atan2(tb - ta, b - a))
		out.append(_box(k, c, Vector3(WALK_W * 2.0, 0.08, Vector2(b - a, tb - ta).length() - 0.01), pal().wood * _shade(k), "wood", basis))
	var beam_z: float = (z0 + z1) * 0.5
	out.append(_box(3, Vector3(0, _walk_top(beam_z) - 0.15, beam_z), Vector3(WALK_W * 2.0 + 0.3, 0.12, 0.14), pal().dark))
	return out


func _shapes(id: String) -> Array:
	var c := cfg()
	var out := []
	if id.begins_with("stilt_") or id.ends_with("_0") and id.begins_with("pile_"):
		var at: Vector3 = _posts()[int(id.get_slice("_", 1))]
		out.append(_cyl_shape(0.2, at + Vector3(0, _ground_local(at), 0), at + Vector3(0, -0.06, 0)))
		return out
	if id.begins_with("walk_") and id.ends_with("_b"):
		for q in _walk_pieces(int(id.get_slice("_", 1)), true):
			out.append(_box_shape(q.size + Vector3(0, 0.04, 0.03), q.c, q.basis))
		return out
	match id:
		"floor":
			out.append(_box_shape(Vector3(c.hw * 2.0, 0.1, c.front - c.back), Vector3(0, -0.05, (c.back + c.front) * 0.5)))
			if type == "outpost":
				out.append(_ramp_shape(c))
		"porch":
			out.append(_box_shape(Vector3(c.hw * 2.0, 0.1, c.edge - c.front), Vector3(0, -0.05, (c.front + c.edge) * 0.5)))
			for run in _rail_runs():
				var along: Vector3 = run[1] - run[0]
				out.append(_box_shape(Vector3(absf(along.x) + 0.1, 1.0, absf(along.z) + 0.1), (run[0] + run[1]) * 0.5 + Vector3(0, 0.5, 0)))
		"stairs":
			if type != "dock_house":
				out.append(_ramp_shape(c))
		"wall_back":
			out.append(_box_shape(Vector3(c.hw * 2.0, c.wall, T), Vector3(0, c.wall * 0.5, c.back)))
		"wall_left", "wall_right":
			var x: float = -c.hw if id == "wall_left" else c.hw
			out.append(_box_shape(Vector3(T, c.wall, c.front - c.back), Vector3(x, c.wall * 0.5, (c.back + c.front) * 0.5)))
		"wall_front":
			out.append_array(_front_shapes(c))
		"wall_div":
			out.append(_box_shape(Vector3(T, c.wall, c.front - c.back - 1.2), Vector3(0.9, c.wall * 0.5, (c.back + c.front - 1.2) * 0.5)))
			out.append(_box_shape(Vector3(T, c.wall - DOOR.y, 1.2), Vector3(0.9, (c.wall + DOOR.y) * 0.5, c.front - 0.6)))
		"walls":
			out.append(_box_shape(Vector3(c.hw * 2.0, c.wall, T), Vector3(0, c.wall * 0.5, c.back)))
			for x in [-c.hw, c.hw]:
				out.append(_box_shape(Vector3(T, c.wall, c.front - c.back), Vector3(x, c.wall * 0.5, 0)))
			out.append_array(_front_shapes(c))
		"ceiling":
			out.append(_box_shape(Vector3(c.hw * 2.0, 0.06, c.front - c.back), Vector3(0, c.wall + 0.03, (c.back + c.front) * 0.5)))
	return out


func _ramp_shape(c: Dictionary) -> CollisionShape3D:
	var len := Vector2(c.ramp, c.h).length()
	return _box_shape(Vector3(1.6, 0.1, len), Vector3(0, -c.h * 0.5 - 0.05, c.edge + c.ramp * 0.5), Basis(Vector3.RIGHT, atan2(c.h, c.ramp)))


func _front_shapes(c: Dictionary) -> Array:
	var side: float = c.hw - DOOR.x
	return [_box_shape(Vector3(side, c.wall, T), Vector3(-c.hw + side * 0.5, c.wall * 0.5, c.front)),
		_box_shape(Vector3(side, c.wall, T), Vector3(c.hw - side * 0.5, c.wall * 0.5, c.front)),
		_box_shape(Vector3(DOOR.x * 2.0, c.wall - DOOR.y, T), Vector3(0, (c.wall + DOOR.y) * 0.5, c.front))]


func _outline_shapes() -> Array:
	if complete():
		return []
	var c := cfg()
	var depth: float = c.edge - c.back
	var out := [_box_shape(Vector3(c.hw * 2.0, c.wall + c.h, depth), Vector3(0, (c.wall - c.h) * 0.5, (c.back + c.edge) * 0.5))]
	if type == "dock_house":
		var w := _walk_z()
		out.append(_box_shape(Vector3(WALK_W * 2.0 + 0.6, 2.2, walk_len), Vector3(0, _walk_top((w.x + w.y) * 0.5) + 0.6, (w.x + w.y) * 0.5)))
	return out


# --- Saving --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var d := super()
	d["type"] = type
	d["walk"] = walk_len
	if fire:
		d["fire"] = fire.to_dict()
	return d


func from_dict(d: Dictionary) -> void:
	type = String(d.get("type", type))
	walk_len = float(d.get("walk", walk_len))
	_parts = []
	_fire_save = d.get("fire", {})
	super(d)
