extends CharacterBody3D
## First-person survivor: movement, swimming, looking, interacting, attacking
## and using held items. Physics layer 1 = solid world, layer 2 = interactables,
## layer 3 (bit value 4) = blocks movement but not interaction rays.

signal hurt_flash(amount: float)
signal died
signal escape_rolled(chance: float, roll: float, freed: bool)

const HungLamp := preload("res://src/world/hung_lamp.gd")
const EndHouse := preload("res://src/world/end_house.gd")
const Survival := preload("res://src/core/survival.gd")
const Inventory := preload("res://src/core/inventory.gd")
const Preserves := preload("res://src/core/preserves.gd")
const Chart := preload("res://src/core/chart.gd")
const ThrownRock := preload("res://src/world/thrown_rock.gd")
const Fishing := preload("res://src/world/fishing.gd")
const House := preload("res://src/world/house.gd")
const Chunk := preload("res://src/world/chunk.gd")
const Dock := preload("res://src/world/dock.gd")
const Creature := preload("res://src/creatures/creature.gd")

const WALK := 3.6
const SPRINT := 6.2
const JUMP := 4.3
const GRAVITY := 11.0
const FLY_SPEED := 8.0
const FLY_TAP := 0.35       # seconds between the two jump presses that toggle flying
const INTERACT_RANGE := 3.0
const DROP_REACH := 1.0         # how far in front a dropped item lands
const DROP_CLEARANCE := 0.3     # and how far short of anything solid in the way
const FIST_DAMAGE := 2.0
const GRAB_DPS := 13.0          # default health lost per second in an amphibian's jaws
const GRAB_BITE := 25.0         # default damage of the initial bite (species override both)
const STAB_COOLDOWN := 0.3
const THROW_SPEED := 17.0
const THROW_COOLDOWN := 0.6
const SPINE_PRICK := 4.0   # punching a live Acanthodes bare-fisted: its spines prick you
const WAYPOINT_RANGE := 250.0
# Escaping a Uranocentrodon is a dice roll once it has you in deep water (or
# after ROLL_TIME): a 10% chance it drops you anyway, raised by the best strike
# you landed while held.
const ESCAPE_BASE := 0.10
const ESCAPE_BONUS := {"": 0.0, "bare": 0.15, "stone": 0.30, "metal": 0.45, "advanced": 0.60}
const ROLL_TIME := 1.5
const MIN_ROLL_TIME := 0.8    # always time for a couple of strikes first
# Falls and nasty bites can break bones (see Survival.limbs).
const FALL_SAFE := 3.0          # falls up to this many metres are harmless
const FALL_RISK := 4.0          # the chance of an injury rises from 25% over this many more
const CLIMB := 1.6              # m/s up or down a rope ladder
const FRACTURE_FROM := 15.0     # a hit at least this hard may break an arm or a leg
const TRAUMA := 0.4             # blood lost at once per point of a hit
const HOLE_WITHIN := 4.0  # how long (Game.time) broken ground waits for the next swing
# Spear combat (combat.md). A spear thrusts: a tap is a quick thrust, held
# CHARGE_HOLD or longer and let go a charged one, which also lunges you
# forward. Use held with a spear blocks (from the front only): a blocked hit
# is turned aside, halved or comes through (BLOCK_ROLL).
const HIT_MULT := 1.25          # spears hit this much harder than their `damage` (other tools don't)
const QUICK_RECOVERY := 0.7
const QUICK_STAMINA := 5.0
const CHARGE_HOLD := 0.5        # held this long, it is a charged thrust
const CHARGE_MULT := 2.0
const CHARGE_RECOVERY := 0.8
const CHARGE_STAMINA := 12.0
const CHARGE_REACH := 3.8
const CHARGE_TREMBLE := 2.5     # held longer than this the arms tremble and stamina drains
const LUNGE_DIST := 0.8         # metres a charged thrust carries you
const LUNGE_TIME := 0.15
const SURPRISE_MULT := 2.5      # on an animal that hasn't noticed you; the larger of this and the charge applies
const QUICK_STAGGER := 1        # stagger values (creature.gd poise)
const CHARGE_STAGGER := 3
const DEFLECT_STAGGER := 2      # a fully turned-aside blow staggers the attacker
const BLOCK_STAMINA := 8.0
const BLOCK_SPEED := 0.5
const BLOCK_ARC := 0.5          # a blow is blocked only from within 60 degrees of where you face
const BLOCK_ROLL := [0.25, 0.55]  # under the first: no damage; under the second: half; otherwise all of it
const GUARD_BREAK := 0.5        # a blow through the guard drops it this long
const BACK_SPEED := 0.6         # walking backwards
const SNEAK_SPEED := 0.5
const SNEAK_EYE := 1.1
const STAND_EYE := 1.62
# Tripping: backing up into anything (or shoved into it by a hard hit) puts
# you on your back. It costs nothing but the time.
const TRIP_TIME := 1.5
const GETUP_TIME := 0.6
const TRIP_EYE := 0.45
const TRIP_SLOPE := 0.866       # floor normal y under this (steeper than 30 degrees)
const TRIP_DROP := 0.4          # stepping backwards off a drop this deep
const TRIP_LOOK := 0.4          # the heel check: how far behind you
const TRIP_FALL := 0.6          # falling backwards over something carries you this far past it
const TRIP_PLANTS := ["seed_fern", "planted_seed_fern", "fern", "planted_fern"]  # harvestables you don't trip over
const SPILLS := ["pot_dirty", "pot_clean", "pot_soup", "pot_soup_spoiled"]  # open pots in hand a trip empties (canteens and flasks are stoppered)
const SHOVE_FROM := 15.0        # a hit this hard shoves you back...
const SHOVE_WINDOW := 0.3       # ...and for this long, anything you are shoved into trips you
# Food and water a second of what you do ([energy, water]); sprinting, swimming
# and wading are in Survival.tick.
const COST_OVERLOAD := [0.05, 0.015]
const COST_CARRY := [0.06, 0.015]
const COST_DRAG := [0.10, 0.02]
const COST_LADDER := [0.06, 0.015]
const COST_POLE := [0.04, 0.01]
# ...and of one action.
const COST_JUMP := [0.10, 0.02]
const COST_SWING := [0.15, 0.03]   # a quick thrust, or any other tool's swing or stab
const COST_CHARGE := [0.25, 0.05]
const COST_BLOCK := [0.05, 0.01]
const COST_THROW := [0.05, 0.01]
const COST_HEAVY := [0.50, 0.12]   # a swing that digs or hacks (Items.EFFORT heavy)

var _hole_at := Vector3.INF  # where the stone mattock broke the ground for a hole
var _hole_t := -INF  # when (Game.time)
var world: Node = null          # scene root; may provide water_level()/place()/spawn_pickup()
var vitals := Survival.new()
var vitals_enabled := true
var ui_open := false
var frozen := false
var lie := 0.0  # 0 on your feet .. 1 flat on your back looking straight up (the arrival: intro.gd)
var fishing: Node = null  # the line you have cast (fishing.gd), if any
var rod_tug := 0.0        # 0..1: how hard the rod jerks in your hand (a bite, a fish fighting)

var head: Node3D
var camera: Camera3D
var hand: Node3D
var held_mesh: MeshInstance3D
var _torch_light: OmniLight3D    # a held light source (lit torch)
var _torch_flicker := 0.0

var work_spot: Node3D = null    # where you kneel crafting on the ground
var work_view := Vector3.ZERO   # camera yaw, pitch and extra fov that keep the work clear of the work UI's panels
var work_back := 0.0            # and how much further back the camera stands when that isn't enough
var _lamp_at := 0.0
var hauling: Node3D = null      # a carcass or log carried (or a large carcass dragged) in front of you
var focus: Object = null        # interactable under the crosshair
var focus_water := false
var prompt := ""
var tooltip := ""               # a panel about what you look at (a soup pot's contents)
var _water_at := Vector3.INF    # where the view meets the water, while focus_water

var _pitch := 0.0
var _rng := RandomNumberGenerator.new()
var _attack_cd := 0.0
var _take_hold := 0.0          # how long E has been held on a pile
var _swing := 1.0
var _step_dist := 0.0
var _shake := 0.0
var _bob := 0.0
## Poling a raft (_physics_riding): the pole in hand is gripped near its top,
## planted ahead in the water and pushed back past you, stroke after stroke.
const POLE_RATE := 3.0     # radians of stroke a second
const POLE_DRAW := 2.5     # the pole model drawn this much longer while poling
const RAFT_LOAD_REACH := 0.45  # set down this near a raft's edge, a thing goes on its deck
var poling := false
var pole_phase := 0.0
var _pole_k := 0.0         # how far into the poling pose the hand is
var _held_id := "~"
var _held_cast := false   # the held rod is cast: shown without its line and hook
var _press_t := 0.0             # seconds you have held pressure on a wound
var _air_top := -INF            # highest point since you left the ground
var next_injury := -1.0         # tests: force the next fracture or fall roll (0..1)
var _drunk_t := 0.0
var flying := false         # debug worlds only
var climbing: Node3D = null     # the house whose rope ladder you are on
var riding: Node3D = null       # the raft you stand on (raft.gd)
var _plan: Node3D = null        # the house a held blueprint shows, where it would go
var _plan_why := ""
var _last_jump := -1.0

var grabbed_by: Node3D = null    # creature holding the player in its jaws
var grip := 0.0                  # its grip, grip_max = locked on, 0 = lets go
var grip_max := 100.0
var _grab_t := 0.0
var strike_tier := ""            # best strike landed while held ("", bare, stone, advanced)
var escape_roll := -1.0          # the escape roll (0..1) once made this grab
var next_roll := -1.0            # tests: force the next escape roll
var blocking := false            # holding a spear up to block (Use held)
var sneaking := false            # crouched and quiet (the sneak toggle)
var sprinting := false           # this frame (creatures hear it: creature._sense)
var next_block := -1.0           # tests: force the next block roll (0..1)
var down := 0.0                  # seconds left on your back after tripping (getting up included)
var _charge := -1.0              # seconds a spear thrust has been held back (-1: not charging)
var _thrust := 1.0               # 0..1 through the thrust animation
var _thrust_charged := false
var _lunge_t := 0.0
var _lunge_dir := Vector3.ZERO
var _guard_broken := 0.0
var _shove_t := 0.0
var _was_floor := true
var _trips := 0
var _down_k := 0.0               # 0 standing .. 1 flat on your back (the trip's view)
var _block_k := 0.0              # how far into the blocking pose the spear is


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.75
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.875
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = Settings.view_distance + 40.0
	camera.fov = Settings.fov
	camera.current = true
	head.add_child(camera)
	hand = Node3D.new()
	hand.position = Vector3(0.32, -0.28, -0.5)
	camera.add_child(hand)
	held_mesh = MeshInstance3D.new()
	held_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(held_mesh)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.6, 0.28)
	_torch_light.position = Vector3(0.0, 0.35, -0.15)
	_torch_light.visible = false
	hand.add_child(_torch_light)

	vitals.died.connect(_on_died)
	vitals.status.connect(Game.notify)
	apply_cheats()
	Settings.changed.connect(_on_settings)
	Game.player = self
	if Game.dev.has("yaw"):
		rotation.y = deg_to_rad(float(Game.dev["yaw"]))
	if Game.dev.has("pitch"):
		_pitch = deg_to_rad(float(Game.dev["pitch"]))
		head.rotation.x = _pitch


func apply_cheats() -> void:
	## A debug world's switches (and the dev --god flag).
	vitals.god = Game.dev.has("god") or (Game.debug and not Game.cheats.damage)
	vitals.no_needs = Game.debug and not Game.cheats.needs
	if not Game.debug:
		flying = false


func _on_settings() -> void:
	camera.fov = Settings.fov
	camera.far = Settings.view_distance + 40.0


func capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if Settings.touch:
		on = false  # touch controls look by dragging; the pointer stays free
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if ui_open or frozen or vitals.dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * Settings.mouse_sensitivity)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		capture_mouse(true)
		get_viewport().set_input_as_handled()
		return
	if grabbed_by or down > 0.0:
		return  # in its jaws, or on your back
	if event.is_action_pressed("sneak"):
		toggle_sneak()
		return
	if event.is_action_pressed("sleep"):
		if focus and is_instance_valid(focus) and focus.has_method("sleep_on") and not hauling:
			focus.sleep_on(self)  # a bedroll: lie down on it at once
		elif world and world.has_method("request_sleep"):
			world.request_sleep()
	elif event.is_action_pressed("waypoint"):
		if world and world.has_method("mark_waypoint"):
			world.mark_waypoint(look_point(WAYPOINT_RANGE))
	elif hauling and event.is_action_pressed("interact") and hauling.has_method("haul_interact") \
			and hauling.haul_interact(self):
		pass  # filled a soup pot at the water
	elif hauling and (event.is_action_pressed("interact") or event.is_action_pressed("drop")):
		put_down()
	elif hauling and event.is_action_pressed("use") and hauling.has_method("haul_use") and hauling.haul_use(self):
		pass  # set up a carried workbench
	elif hauling and (event.is_action_pressed("use") or event.is_action_pressed("attack")):
		Game.notify("Your hands are full. Put the %s down first (Q)." % hauling.haul_name())
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("use"):
		_use_held()
	elif event.is_action_pressed("drop"):
		_drop_held()
	elif event.is_action_pressed("slot_next"):
		Game.inventory.select(Game.inventory.selected + 1)
	elif event.is_action_pressed("slot_prev"):
		Game.inventory.select(Game.inventory.selected - 1)
	else:
		for i in 6:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				Game.inventory.select(i)


func _look(rel: Vector2) -> void:
	rotation.y -= rel.x
	_pitch = clampf(_pitch - rel.y, -1.5, 1.5)
	head.rotation.x = _pitch


func water_level() -> float:
	return world.water_level() if world and world.has_method("water_level") else -INF


func water_depth() -> float:
	return water_level() - global_position.y


func _physics_process(delta: float) -> void:
	poling = false
	sprinting = false  # set again below when on your feet
	if grabbed_by:
		_physics_grabbed(delta)
		return
	if riding:
		_physics_riding(delta)
		return
	var active := not ui_open and not frozen and not vitals.dead
	var depth := water_depth()
	var swimming := depth > 1.25
	var wading := depth > 0.25

	var input := Vector2.ZERO
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var pad_look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if pad_look != Vector2.ZERO and down <= 0.0:
			_look(pad_look * 2.6 * delta)
	if down > 0.0:
		input = Vector2.ZERO  # on your back
	if vitals.pressing >= 0:
		_hold_pressure(delta, input)
		input = Vector2.ZERO
	if sneaking and (swimming or hauling or flying or (active and Input.is_action_pressed("sprint") and input.y < 0.0)):
		sneaking = false  # sprinting stands you up; you can't sneak swimming or carrying
	# What your body allows: a broken arm halves what you carry (the sack's
	# share aside), and a worsening condition takes more.
	Game.inventory.arm_broken = vitals.arm_broken()
	Game.inventory.strength = vitals.carry_mult()
	var load: float = Game.inventory.load_ratio()
	sprinting = active and Input.is_action_pressed("sprint") and input.y < 0.0 \
			and vitals.stamina > 1.0 and not wading and load <= 1.0 and hauling == null and vitals.can_sprint() \
			and not blocking and not sneaking and down <= 0.0
	var speed := SPRINT if sprinting else WALK
	speed *= vitals.speed_mult()
	if input.y > 0.0:
		speed *= lerpf(1.0, BACK_SPEED, clampf(input.y, 0.0, 1.0))  # backing away is slow
	if blocking:
		speed *= BLOCK_SPEED
	if sneaking:
		speed *= SNEAK_SPEED
	if hauling and hauling.haul_mode() == "drag":
		speed *= 0.5
	elif hauling and hauling.has_method("haul_speed"):
		speed *= hauling.haul_speed()
	if hauling and vitals.arm_broken():
		speed *= Survival.ARM_HAUL
	if load > 1.0:
		# Overloaded: slower, and walking costs stamina.
		speed *= lerpf(1.0, 0.5, clampf((load - 1.0) / (Inventory.OVERLOAD - 1.0), 0.0, 1.0))
		if input != Vector2.ZERO:
			vitals.tire(3.0 * delta)
	if swimming:
		speed *= 0.5
	elif wading:
		speed *= lerpf(0.75, 0.5, clampf((depth - 0.25) / 1.0, 0.0, 1.0))

	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var accel := 10.0 if is_on_floor() or swimming else 2.5
	velocity.x = lerpf(velocity.x, dir.x * speed, minf(accel * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * speed, minf(accel * delta, 1.0))
	if _lunge_t > 0.0:
		# A charged thrust carries you forward with it, into the water too.
		_lunge_t -= delta
		var lunge := LUNGE_DIST / LUNGE_TIME * (0.5 if vitals.leg_hurt() else 1.0) \
				* (lerpf(0.75, 0.5, clampf((depth - 0.25) / 1.0, 0.0, 1.0)) if wading else 1.0)
		velocity.x = _lunge_dir.x * lunge
		velocity.z = _lunge_dir.z * lunge

	if active and Game.debug and Input.is_action_just_pressed("jump"):
		# Debug worlds: a double tap of jump takes off or lands.
		var now := Time.get_ticks_msec() * 0.001
		if now - _last_jump < FLY_TAP:
			flying = not flying
			_last_jump = -1.0
			Game.notify("Flying." if flying else "Landed.")
		else:
			_last_jump = now
	climbing = _ladder(input if active else Vector2.ZERO) if not flying and not swimming and not _too_big_for_ladder() else null
	if climbing:
		sneaking = false
	if climbing:
		# On a rope ladder: up and down it, a little from side to side, held
		# out from the edge of the porch until you are up level with it.
		var l: Vector3 = climbing.to_local(global_position)
		var up := _ladder_dir(input if active else Vector2.ZERO)
		var v := Vector3(input.x * 1.0, up * CLIMB, (House.EDGE + 0.42 - l.z) * 4.0)
		if l.y > 0.06 and up > 0.0:
			v = Vector3(0, 0.4, -1.8)  # step off onto the porch
		velocity = climbing.global_basis * v
	elif flying:
		var up := 0.0
		if active:
			up = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("fly_down") else 0.0)
		var fast := FLY_SPEED * (2.5 if active and Input.is_action_pressed("sprint") else 1.0)
		velocity.x = lerpf(velocity.x, dir.x * fast, minf(8.0 * delta, 1.0))
		velocity.z = lerpf(velocity.z, dir.z * fast, minf(8.0 * delta, 1.0))
		velocity.y = lerpf(velocity.y, up * fast, minf(8.0 * delta, 1.0))
	elif swimming:
		# Float with the head just above the surface.
		var target := water_level() - 1.35
		velocity.y = lerpf(velocity.y, (target - global_position.y) * 3.0, minf(4.0 * delta, 1.0))
		if active and Input.is_action_pressed("jump"):
			velocity.y = 1.5
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif active and Input.is_action_just_pressed("jump") and vitals.stamina > 8.0 and not vitals.winded and down <= 0.0:
			velocity.y = JUMP * (0.6 if wading else 1.0)
			vitals.tire(8.0)
			vitals.spend(COST_JUMP[0], COST_JUMP[1])
			sneaking = false

	move_and_slide()
	if hauling:
		_hold_haul()
	_check_fall(swimming or wading)
	_check_trip(input, swimming or wading, active)
	_shove_t = maxf(_shove_t - delta, 0.0)
	_was_floor = is_on_floor()

	if vitals_enabled:
		var still := is_on_floor() and input == Vector2.ZERO and hauling == null
		vitals.tick(delta, sprinting, swimming, wading, false, still)
		# What else you are doing costs food and water too.
		var moving := input != Vector2.ZERO
		var cost: Array = [0.0, 0.0]
		if climbing:
			cost = COST_LADDER
		elif hauling and moving:
			cost = COST_DRAG if hauling.haul_mode() in ["drag", "pull"] else COST_CARRY
		elif load > 1.0 and moving:
			cost = COST_OVERLOAD
		if cost[0] > 0.0:
			vitals.spend(cost[0] * delta, cost[1] * delta)
		if swimming and vitals.stamina <= 0.0:
			if vitals.drowning == 0.0:
				Game.notify("You are exhausted and swallowing water!")
			vitals.drown(delta)

	# Footsteps
	var moved := Vector2(velocity.x, velocity.z).length() * delta
	if is_on_floor() or swimming:
		_step_dist += moved
		_bob += moved * 2.2
	if _step_dist > (2.0 if sprinting else 1.6):
		_step_dist = 0.0
		Sfx.play("splash" if wading else "step", -14.0 if wading else -10.0, 0.15)


func _physics_riding(delta: float) -> void:
	## Standing on a raft: it carries you, and with a pole in hand the move
	## keys push it along (raft.gd reads `push`).
	if not is_instance_valid(riding) or riding.is_queued_for_deletion():
		riding = null
		return
	var active := not ui_open and not frozen and not vitals.dead
	var input := Vector2.ZERO
	if active:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var pad_look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if pad_look != Vector2.ZERO:
			_look(pad_look * 2.6 * delta)
	poling = input != Vector2.ZERO and "pole" in Items.def(Game.inventory.held_id()).get("tags", [])
	if poling:
		var dir := transform.basis * Vector3(input.x, 0, input.y)
		dir.y = 0.0
		riding.push = dir.normalized() * minf(input.length(), 1.0)
		_bob += delta * 2.0
		var was := floorf(pole_phase / TAU)
		pole_phase += delta * POLE_RATE
		if floorf(pole_phase / TAU) > was:
			# Planted again: a soft plunge ahead of the raft.
			Sfx.play_at("splash", global_position - transform.basis.z * 1.6, -12.0)
	global_position = riding.stand_global()
	velocity = Vector3.ZERO
	_air_top = -INF
	if vitals_enabled:
		vitals.tick(delta, false, false, false, false, not poling)
		if poling:
			vitals.spend(COST_POLE[0] * delta, COST_POLE[1] * delta)


func shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)


func _ladder(input: Vector2) -> Node3D:
	## The house whose rope ladder you climb this frame, or null: half way up
	## it, or at its foot heading up, or up on the porch heading down it.
	var h: Node3D = world.ladder_at(global_position) if world and world.has_method("ladder_at") else null
	if h == null:
		return null
	var l: Vector3 = h.to_local(global_position)
	var up := _ladder_dir(input)
	if is_on_floor():
		if l.y > -0.06:
			return h if up < 0.0 and climbing == null else (h if climbing and up != 0.0 else null)
		if up <= 0.0:
			return null  # at its foot, walking away
	return h


func _ladder_dir(input: Vector2) -> float:
	## Which way the move keys take you on a ladder: facing the house, forward
	## climbs (or down, looking down) and back comes down; facing away, the
	## other way round.
	var h: Node3D = climbing if climbing else (world.ladder_at(global_position) if world and world.has_method("ladder_at") else null)
	if h == null or absf(input.y) < 0.1:
		return 0.0
	var push := -input.y
	var facing: Vector3 = h.global_basis.inverse() * -global_transform.basis.z
	if facing.z < 0.0:
		return -1.0 if push < 0.0 or _pitch < -0.35 else 1.0
	return 1.0 if push < 0.0 else -1.0


func _process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_swing = minf(_swing + delta * 3.2, 1.0)
	_shake = maxf(_shake - delta * 2.5, 0.0)
	var held: String = Game.inventory.held_id()
	if held != _held_id or (fishing != null) != _held_cast:
		_held_id = held
		_held_cast = fishing != null
		_update_held_mesh()
		Game.learn_tool(held)  # a rack tool in hand: its recipes go in the book
	_update_torch(delta)

	# View effects: bob, swing, shake
	var bob := sin(_bob) * 0.03
	camera.position = Vector3(cos(_bob * 0.5) * 0.015, bob, 0)
	if _shake > 0.0:
		camera.position += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.08
	var s := sin(_swing * PI)
	hand.rotation = Vector3(-s * 1.1, s * 0.4, 0)
	hand.position = Vector3(0.32 - s * 0.15, -0.28 + bob * 0.5, -0.5 - s * 0.2)
	_down_tick(delta)
	if spear_held():
		_spear_pose(delta, bob)
	_pole_k = move_toward(_pole_k, 1.0 if poling and work_spot == null else 0.0, delta * 3.0)
	if _pole_k > 0.0 or Items.def(_held_id).get("shape", "") == "rod":
		_pole_pose()
	if rod_tug > 0.0:
		# Something on the line: the rod jerks and bends toward it.
		var tt := Time.get_ticks_msec() * 0.001
		hand.rotation += Vector3(0.25 * rod_tug + sin(tt * 38.0) * 0.12 * rod_tug, 0, cos(tt * 31.0) * 0.08 * rod_tug)
		rod_tug = maxf(rod_tug - delta * 1.5, 0.0)

	if grabbed_by:
		_process_grabbed(delta)
		_update_focus()
		return
	# Kneeling over work on the ground, looking down at it.
	head.position.y = lerpf(head.position.y, work_spot.eye_height() if work_spot else (SNEAK_EYE if sneaking else STAND_EYE), minf(delta * (3.0 if work_spot else 6.0), 1.0))
	head.position.z = lerpf(head.position.z, work_spot.eye_back() + work_back if work_spot else 0.0, minf(delta * 3.0, 1.0))
	camera.fov = lerpf(camera.fov, 50.0 + work_view.z if work_spot else Settings.fov, minf(delta * 5.0, 1.0))
	camera.rotation.x = lerpf(camera.rotation.x, work_view.y if work_spot else 0.0, minf(delta * 5.0, 1.0))
	camera.rotation.y = lerpf(camera.rotation.y, work_view.x if work_spot else 0.0, minf(delta * 5.0, 1.0))
	held_mesh.visible = work_spot == null
	if work_spot and is_instance_valid(work_spot):
		var to: Vector3 = work_spot.look_point() - head.global_position
		var want := atan2(to.y, Vector2(to.x, to.z).length())
		_pitch = lerpf(_pitch, want, minf(delta * 5.0, 1.0))
		head.rotation.x = _pitch
		if work_spot.house:
			# Building a house you turn to face each step.
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(delta * 4.0, 1.0))
	camera.rotation.z = lerpf(camera.rotation.z, 0.0, minf(delta * 4.0, 1.0))
	if _down_k > 0.0:
		# Tripped: flat on your back, looking up, then getting up again.
		var k := smoothstep(0.0, 1.0, _down_k)
		head.position.y = lerpf(head.position.y, TRIP_EYE, k)
		head.rotation.x = lerpf(_pitch, 0.9, k)
		camera.rotation.z = 0.35 * k
	if lie > 0.0:
		# Lying on your back: eyes near the ground, looking up at the sky.
		head.position.y = lerpf(1.62, 0.3, lie)
		_pitch = 1.45 * lie
		head.rotation.x = _pitch
	var sway: float = vitals.drunk_sway() if vitals_enabled else 0.0
	if sway > 0.0:
		# Very drunk: the world rolls and drifts.
		_drunk_t += delta
		camera.rotation.z += sin(_drunk_t * 1.3) * 0.09 * sway
		if not ui_open and not frozen and not vitals.dead and work_spot == null:
			_look(Vector2(sin(_drunk_t * 0.7) * 0.004, cos(_drunk_t * 0.9) * 0.002) * sway)
	if not ui_open and not frozen and not vitals.dead:
		var can_aim := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Settings.touch \
				or not Input.get_connected_joypads().is_empty()
		if spear_held():
			_spear_input(delta, can_aim)
		elif can_aim and _attack_cd <= 0.0 and Input.is_action_pressed("attack") and hauling == null and down <= 0.0:
			_attack()
		if not spear_held():
			blocking = false
			_charge = -1.0
	else:
		blocking = false
		_charge = -1.0
	_update_focus()
	_hold_take(delta)
	_update_plan()


# --- Spear combat ---------------------------------------------------------------

static func spear_prompt(text: String) -> String:
	## A prompt's right-click use, said as it is with a spear in hand: Use
	## blocks, so "Pick it up [Right-click]" is "Put the spear away to pick it up".
	var re := RegEx.new()
	re.compile("([A-Z][A-Za-z ]*?) \\[Right-click\\]")
	var out := text
	for m in re.search_all(text):
		var what := m.get_string(1)
		out = out.replace(m.get_string(), "Put the spear away to " + what.left(1).to_lower() + what.substr(1) + ("" if what.contains(" ") else " it"))
	return out.replace("right-click takes it down", "put the spear away to take it down")

func spear_held() -> bool:
	return Items.def(Game.inventory.held_id()).get("shape", "") == "spear"


func _spear_input(delta: float, can_aim: bool) -> void:
	## A spear in hand: hold attack to draw back a thrust, let go to strike
	## (charged after CHARGE_HOLD); hold Use to block.
	_guard_broken = maxf(_guard_broken - delta, 0.0)
	if Game.hints_seen.get("spear", false) == false and world != null:
		Game.hints_seen["spear"] = true
		Game.notify(Settings.hint("Spear: tap [Left-click] to thrust, hold and let go to lunge. Hold [Right-click] to block."))
	var can := can_aim and hauling == null and down <= 0.0 and work_spot == null
	blocking = can and Input.is_action_pressed("use") and can_block()
	match Game.dev.get("pose", ""):
		# Dev --pose=block|charge|thrust holds the spear so, for screenshots.
		"block":
			blocking = true
			return
		"charge":
			_charge = CHARGE_HOLD
			return
		"thrust":
			_thrust = 0.25
			_thrust_charged = true
			return
	if blocking or not can:
		_charge = -1.0
		return
	if Input.is_action_pressed("attack"):
		if _charge < 0.0:
			if _attack_cd <= 0.0:
				_charge = 0.0
		else:
			_charge += delta
			if _charge > CHARGE_TREMBLE:
				vitals.tire(6.0 * delta)  # held back too long: the arms tremble
	elif _charge >= 0.0:
		var charged := _charge >= CHARGE_HOLD and not vitals.winded
		_charge = -1.0
		thrust(charged)


func can_block() -> bool:
	## Blocking needs your feet under you, your breath and an unbroken guard.
	return spear_held() and grabbed_by == null and climbing == null and hauling == null and down <= 0.0 \
			and not vitals.winded and _guard_broken <= 0.0 and water_depth() <= 1.25 and not vitals.dead


func thrust_damage(charged: bool) -> float:
	## What a thrust of the held spear does before any bonus (HIT_MULT, and
	## the charge if charged), halved if its edge is blunt or you are winded.
	var def := Items.def(Game.inventory.held_id())
	var dmg: float = def.get("damage", FIST_DAMAGE) * HIT_MULT
	if Game.inventory.blunt(Game.inventory.selected):
		dmg *= 0.5
	if vitals.winded:
		dmg *= 0.5
	return dmg * (CHARGE_MULT if charged else 1.0)


func thrust(charged: bool) -> void:
	## A thrust straight out along the view: quick, or charged (harder, further,
	## carrying you forward a step). A miss still costs the breath and the time.
	if _attack_cd > 0.0 or not spear_held():
		return
	var def := Items.def(Game.inventory.held_id())
	var reach: float = CHARGE_REACH if charged else float(def.get("reach", 3.4))
	_attack_cd = CHARGE_RECOVERY if charged else QUICK_RECOVERY
	vitals.tire(CHARGE_STAMINA if charged else QUICK_STAMINA)
	var cost: Array = COST_CHARGE if charged else COST_SWING
	vitals.spend(cost[0], cost[1])
	_thrust = 0.0
	_thrust_charged = charged
	Sfx.play("swing", -6.0 if charged else -8.0, 0.1)
	if charged:
		shake(0.15)
		if water_depth() <= 1.25 and riding == null and climbing == null and hauling == null and is_on_floor():
			_lunge_dir = -global_transform.basis.z
			_lunge_dir.y = 0.0
			_lunge_dir = _lunge_dir.normalized()
			_lunge_t = LUNGE_TIME
	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	if riding and is_instance_valid(riding) and riding.biter and is_instance_valid(riding.biter):
		# Jaws on a corner of the raft: a thrust anywhere near its head counts.
		var b: Node3D = riding.biter
		var to_b: Vector3 = b.head_position() - o
		if to_b.length() <= reach + 1.6 and to_b.normalized().dot(d) > 0.5:
			b.take_damage(thrust_damage(charged), self, CHARGE_STAGGER if charged else QUICK_STAGGER)
			Sfx.play_at("hit", b.head_position(), -2.0)
			if is_instance_valid(riding):
				riding.bite_hit(b)
			used_tool(true)
			return
	var best := _creature_ahead(reach)
	if best == null:
		return
	# The larger bonus applies, never both: a charge, or catching it unaware.
	var surprise: bool = best.unaware()
	var mult: float = maxf(CHARGE_MULT if charged else 1.0, SURPRISE_MULT if surprise else 1.0)
	var stagger: int = Creature.ALWAYS if surprise else (CHARGE_STAGGER if charged else QUICK_STAGGER)
	best.take_damage(thrust_damage(false) * mult, self, stagger)
	Sfx.play_at("hit", best.hit_center(), -2.0 if not charged else 1.0)
	used_tool(true)


func _creature_ahead(reach: float) -> Node3D:
	## The live animal the view's line meets first within reach (trees and
	## walls in the way stop it), or null.
	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	var best: Node3D = null
	var best_t := reach
	for c in Game.creatures:
		if not is_instance_valid(c) or c.dead or c.submerged:
			continue
		var to: Vector3 = c.hit_center() - o
		var t := to.dot(d)
		if t < 0.0 or t > best_t + c.hit_radius:
			continue
		var miss := (to - d * t).length()
		if miss < c.hit_radius:
			best = c
			best_t = t
	if best:
		var hit := _ray(best_t, 1)
		if hit and o.distance_to(hit.position) < best_t - 0.3:
			return null  # a tree or wall is in the way
	return best


func fends(c: Node3D) -> bool:
	## Blocking, face on to it: an Eogyrinus's charge meets the spear point
	## instead of seizing you.
	return blocking and in_front(c.global_position)


func in_front(from: Vector3) -> bool:
	## Whether a blow from `from` comes from within BLOCK_ARC of where you face.
	var to := from - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return true
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	return to.normalized().dot(fwd.normalized()) >= BLOCK_ARC


func _block(amount: float, by: Node3D) -> Array:
	## A blow on the guard: [what got through, "deflect" | "half" | "full"]. It
	## costs breath, wears the spear, and a blow straight through drops the guard.
	var roll := next_block if next_block >= 0.0 else _rng.randf()
	next_block = -1.0
	vitals.tire(BLOCK_STAMINA)
	vitals.spend(COST_BLOCK[0], COST_BLOCK[1])
	used_tool(true)
	if roll < BLOCK_ROLL[0]:
		Sfx.play("hit", -4.0, 0.3)
		Game.notify("You turn the blow aside with the spear.")
		if by != null and is_instance_valid(by) and by.has_method("try_stagger"):
			by.try_stagger(DEFLECT_STAGGER, self)
		return [0.0, "deflect"]
	if roll < BLOCK_ROLL[1]:
		Game.notify("The spear takes some of the blow.")
		return [amount * 0.5, "half"]
	_guard_broken = GUARD_BREAK
	Game.notify("The blow breaks through your guard.")
	return [amount, "full"]


func toggle_sneak() -> void:
	## Crouch and move quietly (halves how far animals notice you), or stand.
	if sneaking:
		sneaking = false
		return
	if hauling or climbing or flying or water_depth() > 1.25 or down > 0.0:
		return
	sneaking = true


func _spear_pose(delta: float, bob: float) -> void:
	## The spear in hand: drawn back while a thrust is held, driven straight
	## out and drawn back in a thrust, or held across you to block.
	_thrust = minf(_thrust + delta / (CHARGE_RECOVERY if _thrust_charged else QUICK_RECOVERY), 1.0)
	_block_k = move_toward(_block_k, 1.0 if blocking else 0.0, delta * 8.0)
	var pos := Vector3(0.32, -0.28 + bob * 0.5, -0.5)
	var rot := Vector3.ZERO
	if _charge >= 0.0:
		var k := smoothstep(0.0, 1.0, clampf(_charge / CHARGE_HOLD, 0.0, 1.0))
		pos += Vector3(0.0, -0.03 * k, 0.15 * k)
		rot.x = -0.25 * k
		if _charge > CHARGE_TREMBLE:
			var tt := Time.get_ticks_msec() * 0.001
			pos += Vector3(sin(tt * 41.0), cos(tt * 37.0), 0.0) * 0.006
	if _thrust < 1.0:
		# Out fast, back slower.
		var ext := _thrust / 0.25 if _thrust < 0.25 else 1.0 - smoothstep(0.0, 1.0, (_thrust - 0.25) / 0.75)
		var dist := 0.6 if _thrust_charged else 0.45
		pos += Vector3(-0.1 * ext, 0.02 * ext, -dist * ext)
		rot += Vector3(-0.4 * ext, 0.12 * ext, 0.0)
		if _thrust_charged:
			camera.position += Vector3(0, 0, -0.05 * ext)
	if _block_k > 0.0:
		var bk := smoothstep(0.0, 1.0, _block_k)
		pos = pos.lerp(Vector3(0.16, -0.2 + bob * 0.5, -0.5), bk)
		rot = rot.lerp(Vector3(-0.28, 1.3, 0.12), bk)
	hand.position = pos
	hand.rotation = rot


# --- Tripping ---------------------------------------------------------------------

func _check_trip(input: Vector2, wet: bool, active: bool) -> void:
	## Backing up into anything (or shoved into it by a hard hit) puts you on
	## your back: something solid, anything lying on the ground, a steep slope
	## or a drop.
	if down > 0.0 or wet or flying or climbing or riding or grabbed_by or vitals.dead or not vitals_enabled:
		return  # (vitals_enabled: not in the lab tutorial)
	if hauling and hauling.haul_mode() != "carry":
		return  # dragging or pulling, you face the way you go
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var backing: bool = active and input.y > 0.5 and flat.length() > 1.0
	var shoved := _shove_t > 0.0 and flat.length() > 0.5
	if not backing and not shoved:
		return
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var toward: Vector3 = -fwd if backing else flat.normalized()   # the way you are going
	var why := ""
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if n.y < 0.7 and n.dot(-toward) > 0.5:
			why = "into something behind you"
			break
	var over := false
	if why == "" and is_on_floor() and _loose_at(global_position + toward * TRIP_LOOK):
		why = "over something on the ground"
		over = true
	if why == "" and backing and is_on_floor() and get_floor_normal().y < TRIP_SLOPE:
		why = "on the steep ground"
	if why == "" and backing and _was_floor and not is_on_floor() and velocity.y <= 0.0 and not _ground_within(TRIP_DROP):
		why = "off the edge"
	if why != "":
		trip(why, toward if over else Vector3.ZERO)


func _loose_at(p: Vector3) -> bool:
	## Whether anything lies at your heels there: a stone, a stick, a pile,
	## a log, a carcass, a stash... (layer 2, which you walk through).
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.2
	q.shape = sh
	q.transform = Transform3D(Basis(), p + Vector3(0, 0.22, 0))
	q.collision_mask = 2
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c: Object = hit.collider
		if c == null:
			continue
		var n: Object = c if not c.get_parent() or c.has_method("interact") else c.get_parent()
		if n.is_in_group("plots") or n == work_spot or n == hauling:
			continue  # a planting hole is flat
		if c.get_parent() and c.get_parent().get("_outline") == c:
			continue  # a building site's outline of parts still to come isn't there yet
		if str(n.get("kind")) in TRIP_PLANTS:
			continue  # ferns are underfoot everywhere: you walk through them
		return true
	return false


func _ground_within(dist: float) -> bool:
	var from := global_position + Vector3(0, 0.1, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, dist + 0.1, 0), 1 | 2, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func trip(why := "", over := Vector3.ZERO) -> void:
	## Down on your back for TRIP_TIME, then up again. No harm done, but
	## whatever you were backing away from gets its chance. Tripped over
	## something on the ground (`over`: the way you were going), you fall
	## back past it, where there is room, so getting up you aren't at once
	## tripping on it again.
	if down > 0.0 or vitals.dead:
		return
	if over != Vector3.ZERO and not test_move(global_transform, over * TRIP_FALL):
		global_position += over * TRIP_FALL
	down = TRIP_TIME + GETUP_TIME
	_charge = -1.0
	blocking = false
	sneaking = false
	_lunge_t = 0.0
	_shove_t = 0.0
	velocity = Vector3(velocity.x * 0.3, velocity.y, velocity.z * 0.3)
	shake(0.4)
	Sfx.play("hit", -6.0, 0.2)
	_trips += 1
	var spilt := _spill()
	Game.notify(("You trip %s and fall on your back." % why if why != "" else "You trip and fall on your back.") \
			+ (" %s." % spilt if spilt != "" else "") + (" Backing away while you fight is dangerous." if _trips == 1 else ""))


func _spill() -> String:
	## Falling with an open pot in your hand, an unsealed pot of preserves, or
	## an open pot or unsealed vessel in your arms: what was in it is lost
	## (food tumbles out onto the ground), and what you carried is dropped.
	## Returns what spilled ("The pot of boiled water spills"), or "".
	var what: Array = []
	var inv = Game.inventory
	var held: String = inv.held_id()
	if held in SPILLS:
		what.append(Items.item_name(held).to_lower())
		inv.replace(inv.selected, "pot")
	elif held == "pot_preserves":
		what.append("pot of preserves")
		var s = inv.held()
		var food: Array = Preserves.contents(s.get("data", {}))
		inv.replace(inv.selected, "pot")
		for it in food:
			if world and world.has_method("spawn_pickup"):
				world.spawn_pickup(it.id, 1, drop_point(), it.age, true)
	if hauling:
		var h := hauling
		if h.has_method("spill") and h.spill():
			what.append(Items.item_name(h.item_id).to_lower())
		put_down()
	if what.is_empty():
		return ""
	Sfx.play("splash", -6.0, 0.2)
	return "The " + " and the ".join(what) + (" spills" if what.size() == 1 else " spill")


func _down_tick(delta: float) -> void:
	if down > 0.0:
		down = maxf(down - delta, 0.0)
	var want := 1.0 if down > GETUP_TIME else 0.0
	_down_k = move_toward(_down_k, want, delta * (5.0 if want > _down_k else 1.0 / GETUP_TIME))


func _update_plan() -> void:
	## Holding a blueprint shows the building where it would go: blue where
	## it can stand, red where it can't.
	var kind: String = Items.def(Game.inventory.held_id()).get("blueprint", "")
	var show := kind != "" and not ui_open and not vitals.dead and work_spot == null and hauling == null \
			and climbing == null and riding == null and world != null and world.has_method("house_spot")
	if _plan and _plan.get_meta("kind", "house") != kind:
		_plan.queue_free()
		_plan = null
	if not show:
		if _plan:
			_plan.queue_free()
			_plan = null
		_plan_why = ""
		return
	var spot: Dictionary = world.dock_spot(self) if kind == "dock" else (world.end_house_spot(kind, self) if EndHouse.CFG.has(kind) else world.house_spot(self))
	_plan_why = spot.why
	if _plan == null:
		_plan = Dock.new() if kind == "dock" else (EndHouse.new().setup(kind, world, float(spot.get("walk", 8.0))) if EndHouse.CFG.has(kind) else House.new())
		_plan.set_meta("kind", kind)
		_plan.preview = true
		_plan.world = world
		world.add_child(_plan)
	if _plan is EndHouse and absf(_plan.walk_len - float(spot.get("walk", _plan.walk_len))) > 0.01:
		_plan.setup(kind, world, float(spot.walk))
	_plan.show_plan(spot.at, spot.yaw, spot.why == "")
	if focus == null:
		prompt = ("Mark out the %s site here [Right-click]" % ("dock" if kind == "dock" else (EndHouse.CFG[kind].name if EndHouse.CFG.has(kind) else "house"))) if _plan_why == "" else "Can't build here: " + _plan_why.trim_suffix(".").to_lower()


func _hold_take(delta: float) -> void:
	## Holding E on a pile keeps taking from it (one is taken on the press).
	if hauling or ui_open or focus == null or not focus.has_method("take_one") or focus.carried() \
			or not Input.is_action_pressed("interact"):
		_take_hold = 0.0
		return
	_take_hold += delta
	if _take_hold > 0.45:
		_take_hold -= 0.12
		if not focus.take_one(self):
			_take_hold = -INF


func _update_torch(delta: float) -> void:
	_update_lamp()
	## A held light (lit torch) flickers; rain makes it very dim.
	var range_m: float = Items.def(_held_id).get("light", 0.0)
	_torch_light.visible = range_m > 0.0 and not vitals.dead
	if not _torch_light.visible:
		return
	var wet: bool = world != null and world.get("raining") == true and not Items.def(_held_id).get("hooded", false)
	_torch_flicker += delta * 11.0
	var f := 0.85 + 0.15 * sin(_torch_flicker) * sin(_torch_flicker * 1.9 + 0.7)
	_torch_light.omni_range = range_m * (0.4 if wet else 1.0)
	_torch_light.light_energy = (0.25 if wet else 0.9) * f


func _pole_pose() -> void:
	## Blends the hand into the poling stroke: reach forward and plant the
	## tip ahead (pull = 0), then lean on it and push it back past you
	## (pull = 1), lifting it clear on the way forward again.
	var k := smoothstep(0.0, 1.0, _pole_k)
	var pull := 0.5 - 0.5 * cos(pole_phase)
	var lift := maxf(-sin(pole_phase), 0.0)   # swung forward again, clear of the water
	var tip := lerpf(-1.2, -1.7, pull) + lift * 0.35
	hand.rotation = hand.rotation.lerp(Vector3(tip, 0.25, -0.15), k)
	hand.position = hand.position.lerp(Vector3(0.28, -0.3 - pull * 0.1 + lift * 0.05, lerpf(-0.78, -0.52, pull)), k)
	if Items.def(_held_id).get("shape", "") == "rod" and fishing == null:
		# Drawn full length (the item is a short model), gripped at the top,
		# the rest of it reaching down into the water.
		var long := lerpf(1.0, POLE_DRAW, k)
		held_mesh.scale = Vector3(long, lerpf(1.0, 1.3, k), lerpf(1.0, 1.3, k))   # the model lies along x
		held_mesh.position = held_mesh.basis.orthonormalized() * Vector3(lerpf(0.5, 0.6, k) * long, 0, 0)


func _update_held_mesh() -> void:
	if _held_id == "":
		held_mesh.mesh = null
		return
	held_mesh.mesh = Assets.mesh("item_" + _held_id)
	var shape: String = Items.def(_held_id).get("shape", "")
	if shape == "fishing_rod" and _held_cast:
		# Cast: the line and hook are out on the water (fishing.gd), so the
		# rod in hand is bare.
		held_mesh.mesh = Assets.mesh("item_rod_blank")
	held_mesh.rotation = Vector3.ZERO
	held_mesh.position = Vector3.ZERO
	held_mesh.scale = Vector3.ONE
	match shape:
		"axe", "drill", "stick", "mattock", "shovel", "hammer", "torch", "torch_lit":
			# Long items lie along +X: stand them up, leaning away, gripped low.
			held_mesh.rotation = Vector3(-0.5, 0, PI * 0.5)
			held_mesh.position = held_mesh.basis * Vector3(0.18, 0, 0)
		"spear":
			held_mesh.rotation = Vector3(-1.15, 0, PI * 0.5)
			held_mesh.position = held_mesh.basis * Vector3(0.25, 0, 0)
		"rod", "fishing_rod", "blowpipe":
			# Held by the butt, the tip out ahead and up.
			held_mesh.rotation = Vector3(-1.0, 0, PI * 0.5)
			held_mesh.position = held_mesh.basis * Vector3(0.5, 0, 0)
		"pipe", "segment", "injector":
			held_mesh.rotation = Vector3(0, PI * 0.5, 0)
			held_mesh.scale = Vector3.ONE * 0.6
		_:
			held_mesh.scale = Vector3.ONE * 0.9


# --- Interaction ----------------------------------------------------------------

func _ray(range_m: float, mask: int) -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * range_m
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	q.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(q)


func look_point(range_m: float) -> Vector3:
	## The solid ground (or tree, or boulder) under the crosshair, or INF.
	var hit := _ray(range_m, 1)
	return hit.position if hit else Vector3.INF


func _update_focus() -> void:
	focus = null
	focus_water = false
	_water_at = Vector3.INF
	prompt = ""
	tooltip = ""
	if ui_open or vitals.dead or grabbed_by:
		return
	if vitals.pressing >= 0:
		prompt = "Pressing on the wound: %d s more. Moving lets go." % ceili(pressure_left())
		return
	if hauling and climbing:
		return  # nothing to do with it until you are off the ladder
	if hauling:
		if hauling.has_method("haul_prompt"):
			_look_at_water(_ray(INTERACT_RANGE, 1 | 2))
			prompt = hauling.haul_prompt(self)
		else:
			prompt = "%s the %s [E]" % ["Drop" if hauling.haul_mode() == "drag" else "Put down", hauling.haul_name()]
		return
	var hit := _ray(INTERACT_RANGE, 1 | 2)
	if hit:
		var c: Object = hit.collider
		if not c.has_method("interact") and c.get_parent() and c.get_parent().has_method("interact"):
			c = c.get_parent()
		if c.has_method("interact"):
			focus = c
			prompt = c.prompt(self) if c.has_method("prompt") else "Interact [E]"
			tooltip = c.tooltip(self) if c.has_method("tooltip") else ""
			if c.has_method("use_interact") and spear_held():
				prompt = spear_prompt(prompt)
			return
	if _axe_prompt():
		return
	if riding and is_instance_valid(riding):
		focus = riding
		prompt = riding.prompt(self)
		return
	if _look_at_water(hit):
		var held: String = Game.inventory.held_id()
		if Items.def(held).has("hold") and _water_at.is_finite():
			prompt = "Fill %s [E]" % Items.item_name(held)
		else:
			prompt = "Drink swamp water [E]"


func _axe_prompt() -> bool:
	## With an axe in hand at a standing tree: how to fell it.
	var held: String = Game.inventory.held_id()
	if not "chop" in Items.def(held).get("tags", []) or world == null or not world.has_method("tree_ahead"):
		return false
	var t: Dictionary = world.tree_ahead()
	if t.is_empty():
		return false
	var def: Dictionary = Chunk.TREES[t.kind]
	if def.get("soft", true) or Items.def(held).get("tier", "") != "stone":
		prompt = "Kneel to fell the %s [C]" % def.get("name", "tree")
	else:
		prompt = "The %s is too hard to fell with a stone %s" % [def.get("name", "tree"), Items.tool_word(held)]
	return true


func _look_at_water(hit: Dictionary) -> bool:
	## Whether the view meets the water within reach (or you stand in it);
	## sets focus_water, and where the view meets it (_water_at).
	var wl := water_level()
	if wl == -INF:
		return false
	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	if o.y > wl and d.y < -0.05:
		var t := (wl - o.y) / d.y
		var hit_dist: float = o.distance_to(hit.position) if hit else INF
		if t < INTERACT_RANGE + 0.5 and t < hit_dist + 0.05:
			focus_water = true
			_water_at = o + d * t
	elif o.y <= wl + 0.2:
		focus_water = true
	return focus_water


func water_point() -> Vector3:
	## The water you are looking at (or standing in).
	if _water_at.is_finite():
		return _water_at
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	var p := global_position + fwd.normalized() * 1.5
	return Vector3(p.x, water_level(), p.z)


func _interact() -> void:
	if focus and is_instance_valid(focus):
		focus.interact(self)
		return
	if focus_water:
		var held: String = Game.inventory.held_id()
		var fill: String = Items.def(held).get("hold", "")
		if fill != "":
			Game.inventory.replace(Game.inventory.selected, fill)
			Sfx.play("splash", -6.0)
			Game.notify("Filled with murky swamp water.")
		else:
			vitals.consume({"water": 12.0, "sick": 0.25}, _rng)
			Sfx.play("drink", -4.0)


func _use_held() -> void:
	# With a spear in hand Use is the block (held, see _spear_input), and
	# nothing else: put the spear away to use a vessel, bedroll or crate.
	if spear_held():
		return
	# Right-click on something with its own use (a fermentation vessel opens).
	if focus and is_instance_valid(focus) and focus.has_method("use_interact"):
		focus.use_interact(self)
		return
	var inv = Game.inventory
	var id: String = inv.held_id()
	if id == "":
		return
	var def := Items.def(id)
	if id == "compost":
		# Worked in round a growing plant, it hurries it on (plot.gd).
		if focus and is_instance_valid(focus) and focus.has_method("feed") and focus.feed(self):
			inv.take(inv.selected, 1)
		else:
			Game.notify("Right-click a growing plant to work the compost in, or set it in a hole with a seed or root.")
		return
	if "dig" in def.get("tags", []):
		dig_hole()
		return
	if def.get("fishing", false):
		if fishing and is_instance_valid(fishing):
			fishing.reel()
		else:
			cast_rod()
		return
	if def.get("chart", false):
		if world and world.has_method("open_map"):
			world.open_map()
		return
	if id == "ash_pencil":
		var why: String = Chart.sharpen(inv, inv.selected)
		Game.notify(why if why != "" else "You sharpen the pencil.")
		if why == "":
			Sfx.play("rustle", -6.0, 0.3)
		return
	if def.get("lamp", false):
		_use_lamp()
		return
	if id == "torch" and inv.count("fire_striker") > 0:
		inv.spark()
		inv.replace(inv.selected, "torch_lit")
		Sfx.play("fire_start", -8.0)
		Game.notify("You strike a spark and the torch catches.")
		return
	if def.has("blueprint"):
		if world and world.has_method("place_blueprint") and world.place_blueprint(def.blueprint, self):
			inv.take(inv.selected, 1)
		return
	if def.has("place"):
		if world and world.has_method("place"):
			var pos := global_position - transform.basis.z * 1.6
			if world.place(def.place, pos, id):
				inv.take(inv.selected, 1)
		return
	if def.get("preserves", false):
		use_preserves(inv.selected)
		return
	if Items.is_food(id):
		consume_slot(inv.selected)
		return
	if def.has("treat"):
		treat_slot(inv.selected)
		return
	if def.has("hold") and focus_water:
		_interact()
		return
	if def.get("throw", false):
		throw_held()


func dig_hole() -> void:
	## Dig a hole with the held mattock in the ground you are looking at.
	if _attack_cd > 0.0 or world == null or not world.has_method("dig_hole"):
		return
	var at := look_point(float(Items.def(Game.inventory.held_id()).get("reach", 2.3)) + 0.5)
	if not at.is_finite():
		Game.notify("Aim at the ground nearby to dig a hole.")
		return
	_attack_cd = THROW_COOLDOWN
	_swing = 0.0
	if Items.slow_tool(Game.inventory.held_id()):
		# The stone mattock breaks the ground first, then digs the hole: only
		# where a hole can go, and the next swing soon after (game time,
		# so a pause doesn't lose it).
		if _hole_at.distance_to(at) > 0.6 or Game.time - _hole_t > HOLE_WITHIN:
			if not world.dig_hole(at, true):
				return
			_hole_at = at
			_hole_t = Game.time
			vitals.tire(3.0)
			vitals.spend(COST_HEAVY[0], COST_HEAVY[1])
			Sfx.play_at("chop", at, -6.0, 0.2)
			Game.notify("You break the ground (1 / 2).")
			return
		_hole_at = Vector3.INF
	if world.dig_hole(at):
		vitals.tire(6.0)
		vitals.spend(COST_HEAVY[0], COST_HEAVY[1])
		used_tool(false)


func throw_held() -> void:
	## Throw the held stone where you are looking.
	var inv = Game.inventory
	if _attack_cd > 0.0 or world == null or inv.held() == null:
		return
	var item: Dictionary = inv.take(inv.selected, 1)
	_attack_cd = THROW_COOLDOWN
	_swing = 0.0
	vitals.tire(3.0)
	vitals.spend(COST_THROW[0], COST_THROW[1])
	var dir := -camera.global_transform.basis.z
	var from := camera.global_position + dir * 0.4 + Vector3(0, -0.1, 0)
	var v := dir * THROW_SPEED + Vector3(0, 1.5, 0) + velocity * 0.5
	var rock := ThrownRock.new()
	rock.age = float(item.get("age", 0.0))  # a baitbox keeps going off
	world.add_child(rock.setup(item.id, from, v, self, world))
	Sfx.play("swing", -6.0)


func cast_rod() -> void:
	## Casts the held fishing rod where you are looking, the hook flying like a
	## thrown stone. Not without bait on it.
	var inv = Game.inventory
	var s = inv.held()
	if s == null or world == null or _attack_cd > 0.0:
		return
	var bait: String = s.get("data", {}).get("bait", "")
	if bait == "":
		Game.notify("There's no bait on this rod. Press %s to kneel, lay out the rod and some bait, and bait it." % Settings.button_name("craft"))
		return
	_attack_cd = THROW_COOLDOWN
	_swing = 0.0
	var dir := -camera.global_transform.basis.z
	var from := camera.global_position + dir * 0.4 + Vector3(0, -0.1, 0)
	var v := dir * THROW_SPEED + Vector3(0, 1.5, 0) + velocity * 0.5
	fishing = Fishing.new().setup(self, world, from, v, bait)
	world.add_child(fishing)
	Sfx.play("swing", -6.0)


func consume_slot(i: int) -> void:
	var inv = Game.inventory
	var s = inv.slots[i]
	if s == null:
		return
	var def: Dictionary = inv.def_of(i)
	if not Items.is_food(s.id):
		return
	if vitals_enabled:
		vitals.consume(def, _rng)  # (in the lab you only drink a coffee)
	Sfx.play("drink" if def.get("water", 0.0) > def.get("energy", 0.0) else "eat", -4.0)
	if _use_measure(i, def):
		pass
	elif def.has("empty") and s.n == 1:
		# What is left keeps the slot: an emptied pot, or a canteen's other
		# serving (still the same soup, as old as it was).
		var rest := Items.is_food(def.empty)
		inv.replace(i, def.empty, s.age if rest else 0.0, s.get("data", {}) if rest else {})
	else:
		inv.take(i, 1)
		if def.has("empty"):
			inv.add(def.empty, 1, 0.0, true)
	Game.crafted.emit("ate_" + s.id)


func _use_measure(i: int, def: Dictionary) -> bool:
	## An item used a measure at a time (a canteen or flask of alcohol): one
	## less in it, or the empty container (`drained`, else the canteen) once
	## the last is gone. False for anything else.
	if not def.has("measures"):
		return false
	var inv = Game.inventory
	var s: Dictionary = inv.slots[i]
	var left := int(s.get("data", {}).get("left", def.measures)) - 1
	if left > 0:
		inv.replace(i, s.id, s.age, Items.measures_data(s.id, left))
	else:
		inv.replace(i, def.get("drained", "canteen"))
	return true


func use_preserves(i: int) -> bool:
	## Opens the preserving pot in slot i (core/preserves.gd): everything into
	## the bag, what doesn't fit at your feet. Sealing one is a hand recipe.
	var inv = Game.inventory
	var s = inv.slots[i]
	if s == null or not Items.def(s.id).get("preserves", false):
		return false
	var spilled: Array = Preserves.open(inv, i)
	for it in spilled:
		if world and world.has_method("spawn_pickup"):
			world.spawn_pickup(it.id, 1, drop_point(), it.age, true)
	Sfx.play("pickup", -6.0)
	Game.notify("You open the pot and take the food out." + (" Your bag is full: some of it is at your feet." if not spilled.is_empty() else ""))
	return true


func treat_slot(i: int, wound := -1) -> bool:
	## Uses a treatment from slot i on wound index `wound` (or the wound that
	## needs it most): boiled water washes, alcohol cleans and fights
	## infection, a bandage or wax covers (see Survival).
	var inv = Game.inventory
	var s = inv.slots[i]
	if s == null or not vitals_enabled:
		return false
	var def := Items.def(s.id)
	var kind: String = def.get("treat", "")
	var why := ""
	match kind:
		"clean", "alcohol":
			if not vitals.wash(wound, kind == "alcohol"):
				why = "You have no wounds that need washing." if not vitals.wounds.is_empty() else "You have no wounds that need that."
			else:
				Game.notify("You wash out your wounds with boiled water." if kind == "clean" else "You clean the wound with alcohol. It burns.")
		"suture":
			why = vitals.suture(wound)
			if why == "":
				Game.notify("You stitch the wound closed.")
		"bandage", "wax":
			why = vitals.cover(wound, kind)
			if why == "":
				Game.notify("You bind the wound." if kind == "bandage" else "You seal the wound with wax.")
		_:
			why = "That won't help your wounds."
	if why != "":
		Game.notify(why)
		return false
	if _use_measure(i, def):
		pass
	elif def.has("empty") and s.n == 1:
		inv.replace(i, def.empty)
	else:
		inv.take(i, 1)
		if def.has("empty"):
			inv.add(def.empty, 1, 0.0, true)
	Sfx.play("craft", -10.0)
	Game.crafted.emit("treated_" + s.id)
	return true


func _drop_held() -> void:
	var inv = Game.inventory
	var s = inv.held()
	if s == null or world == null or not world.has_method("spawn_pickup"):
		return
	var item: Dictionary = inv.take(inv.selected, 1)
	var pos := drop_point()
	if Items.def(item.id).get("splat", false) and world.has_method("splat_guts"):
		world.splat_guts(pos)
		return
	if world.has_method("pile_item"):
		world.pile_item(item.id, 1, pos, item.age, item.get("data", {}))  # raw materials go on a pile there
		return
	world.spawn_pickup(item.id, 1, pos, item.age, true, item.get("data", {}))


func drop_point() -> Vector3:
	## Where a dropped item lands: a metre in front at chest height, or short
	## of a trunk, wall or anything else solid in the way, never inside it.
	var from := global_position + Vector3(0, 0.8, 0)
	var to := from - transform.basis.z * DROP_REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var back: float = maxf(from.distance_to(hit.position) - DROP_CLEARANCE, 0.0)
	return from + (to - from).normalized() * back


# --- Carrying and dragging ----------------------------------------------------------
# A medium carcass or a log is carried in front of you at walking pace; a large
# carcass is dragged at half that. Either way your hands are full: no sprinting,
# no using or picking things up, no bag and no crafting until you put it down
# (Q or E). What can be hauled has can_haul, haul_mode, haul_name, haul_radius,
# haul_yaw, haul_lift and set_hauled (creature.gd, wood_log.gd).

func carry_blocked() -> bool:
	## Aboard a raft your hands are for the pole: nothing is taken up to carry.
	## Callers that change something first (a carcass, a pile, a bench's rack)
	## ask this before they do.
	if riding == null:
		return false
	Game.notify("You can't carry that while you're aboard. Look out over the water and press E to step off first.")
	return true


func start_haul(c: Node3D) -> void:
	if hauling or c == null or not c.can_haul() or carry_blocked():
		return
	hauling = c
	c.set_hauled(self)
	_hold_haul()
	Sfx.play("pickup", -4.0)
	if Game.hints_seen.get("haul", false) == false and not c.is_in_group("workbenches"):
		Game.hints_seen["haul"] = true
		Game.notify("%s it. Put it down with Q or E; kneel beside it (C) to %s it." % ["Dragging" if c.haul_mode() == "drag" else "Carrying",
				"butcher" if "species" in c else "work"])


func put_down() -> void:
	## Lays what you are carrying on the ground in front of you.
	var c := hauling
	if c and climbing:
		Game.notify("Climb off the ladder before you set the %s down." % c.haul_name())
		return
	var raft: Node3D = _raft_for(c) if is_instance_valid(c) else null
	if raft and not raft.has_room_for(c):
		Game.notify("There's already a %s on the raft." % raft.cargo.haul_name())
		return
	var cart: Node3D = _cart_for(c) if is_instance_valid(c) and raft == null else null
	if cart and not cart.has_room_for(c):
		Game.notify("There's no room on the cart for the %s." % c.haul_name())
		return
	if raft:
		c.global_position = raft.cargo_point()  # the middle of the deck
	elif cart:
		c.global_position = cart.cargo_point()
		c.set_meta("cart_load", true)
	elif c and is_instance_valid(c):
		_keep_on_floor(c)  # first, so a workbench's room is checked where it will stand
	if c and is_instance_valid(c) and c.has_method("can_put_down") and not c.can_put_down():
		return  # a workbench needs room to stand
	hauling = null
	if c == null or not is_instance_valid(c):
		return
	c.set_hauled(null)
	if raft:
		raft.stow(c)
	elif cart:
		cart.stow(c)
	Sfx.play("step", -4.0)


func _too_big_for_ladder() -> bool:
	## A cart or a dragged log doesn't go up a rope ladder.
	return hauling != null and is_instance_valid(hauling) and hauling.haul_mode() in ["pull", "drag"] and not "species" in hauling


func _cart_for(c: Node3D) -> Node3D:
	## The handcart this would be set down on: held out over its bed.
	if world == null or not world.has_method("cart_near") or c.is_in_group("handcarts"):
		return null
	var cart: Node3D = world.cart_near(c.global_position, 1.5)
	return cart if cart and cart.takes(c) else null


func _raft_for(c: Node3D) -> Node3D:
	## The raft this would be set down on: held out over its deck or just off
	## its edge, or with you standing on it. Null for what can't ride on one.
	if world == null or not world.has_method("raft_under"):
		return null
	var r: Node3D = world.raft_under(c.global_position, RAFT_LOAD_REACH)
	if r == null:
		r = world.raft_under(global_position)
	return r if r != null and r.takes(c) else null


func _keep_on_floor(c: Node3D) -> void:
	## Standing on a house's floor, what you set down stays up on it: held out
	## past a wall (or the porch's edge), it is drawn back toward you until it
	## is over the floor, rather than dropping to the ground under the house.
	if world == null or not world.has_method("floor_height") or not world.has_method("ground_height"):
		return
	var me := global_position
	var mine: float = world.floor_height(me)
	if mine <= world.ground_height(me.x, me.z) + 0.5:
		return  # on the ground: it goes down wherever it is
	var at := c.global_position
	for t in [1.0, 0.75, 0.5, 0.25, 0.0]:
		var q := Vector3(lerpf(me.x, at.x, t), me.y + 0.5, lerpf(me.z, at.z, t))
		if world.floor_height(q) > mine - 0.3:
			c.global_position = Vector3(q.x, maxf(at.y, mine), q.z)  # a dragged one may hang below
			return


func _hold_haul() -> void:
	## It rides in front of you: held up at chest height, or, a big carcass,
	## lying on the ground (or a house's floor), dragged along by the head. On
	## a rope ladder it is slung on your back, out from the house.
	var c := hauling
	if not is_instance_valid(c) or c.is_queued_for_deletion() or not c.can_haul():
		hauling = null
		return
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var r: float = c.haul_radius()
	var at: Vector3
	if climbing:
		var out: Vector3 = climbing.global_basis.z
		at = global_position + out * (r + 0.35) + Vector3(0, 0.5, 0)
		c.rotation.y = climbing.rotation.y + c.haul_yaw()
	elif c.haul_mode() == "pull":
		c.haul_follow(self)
		return
	elif c.haul_mode() == "drag":
		at = global_position + fwd * (r * 1.6 + 0.9)
		var g: float = world.floor_height(Vector3(at.x, global_position.y, at.z)) if world and world.has_method("floor_height") else global_position.y
		at.y = maxf(g, water_level() - 0.3)
		c.rotation.y = rotation.y
	else:
		at = global_position + fwd * (r + 0.55) + Vector3(0, c.haul_lift(), 0)
		c.rotation.y = rotation.y + c.haul_yaw()
	c.global_position = at


# --- The metal lamp ------------------------------------------------------------------
# Its fuel is in its slot's data, in game minutes (hung_lamp.gd WAX to a residue).

func lamp_flame(at: Vector3) -> bool:
	## Whether there's a flame to light a lamp from here, wearing a striker if
	## that's what does it.
	var inv = Game.inventory
	if Game.nearest_fire(at, 3.0) or inv.count("torch_lit") > 0 or inv.count("ember") > 0:
		return true
	if inv.has_tag("fire"):
		inv.spark()
		return true
	return false


func _use_lamp() -> void:
	## On a house wall or ceiling, hangs it. Otherwise it tops up from your
	## wax, then lights; lit, it goes out, keeping its fuel.
	var inv = Game.inventory
	var i: int = inv.selected
	var s: Dictionary = inv.slots[i]
	if world and world.has_method("hang_lamp") and world.hang_lamp(self, s):
		inv.take(i, 1)
		return
	var data: Dictionary = s.get("data", {}).duplicate()
	var fuel: float = float(data.get("fuel", 0.0))
	var base: String = Items.lantern_base(s.id)
	if Items.lantern_is_lit(s.id):
		inv.replace(i, base, 0.0, data)
		Game.notify("You put out the lantern.")
		return
	var room := HungLamp.HELD - ceili(fuel / HungLamp.WAX)
	var n: int = mini(inv.count("wax"), room)
	if n > 0:
		inv.remove("wax", n)
		fuel += n * HungLamp.WAX
		data["fuel"] = fuel
		inv.replace(i, base, 0.0, data)
		Game.notify("You fill the lantern: %d of %d wax." % [ceili(fuel / HungLamp.WAX), HungLamp.HELD])
	if fuel <= 0.0:
		Game.notify("The lantern is dry. It burns waxy residue.")
	elif lamp_flame(global_position):
		inv.replace(i, base + "_lit", 0.0, data)
		Sfx.play("fire_start", -10.0)
	elif n == 0:
		Game.notify("You need a flame to light it: a striker, bow drill, torch, ember or a fire close by.")


func _update_lamp() -> void:
	## A lit lamp burns while it's in your hand; put away, it goes out.
	var inv = Game.inventory
	var now: float = Game.time
	var dt: float = maxf(now - _lamp_at, 0.0)
	_lamp_at = now
	for i in inv.SIZE:
		var s = inv.slots[i]
		if s == null or not Items.lantern_is_lit(s.id):
			continue
		var base: String = Items.lantern_base(s.id)
		var data: Dictionary = s.get("data", {}).duplicate()
		if i != inv.selected:
			inv.replace(i, base, 0.0, data)
			continue
		var fuel: float = maxf(float(data.get("fuel", 0.0)) - dt, 0.0)
		data["fuel"] = fuel
		s["data"] = data
		if fuel <= 0.0:
			inv.replace(i, base, 0.0, data)
			Game.notify("Your lantern has burnt dry.")


# --- Combat ---------------------------------------------------------------------

func _attack() -> void:
	var def := Items.def(Game.inventory.held_id())
	var dmg: float = def.get("damage", FIST_DAMAGE)
	if Game.inventory.blunt(Game.inventory.selected):
		dmg *= 0.5  # a blunt metal edge
	var reach: float = def.get("reach", 1.8)
	_attack_cd = 0.75 if reach > 3.0 else 0.55
	if vitals.stamina < 5.0:
		_attack_cd += 0.5
		dmg *= 0.5
	vitals.tire(6.0)
	vitals.spend(COST_SWING[0], COST_SWING[1])
	_swing = 0.0
	Sfx.play("swing", -8.0)

	var o := camera.global_position
	var d := -camera.global_transform.basis.z
	if riding and is_instance_valid(riding) and riding.biter and is_instance_valid(riding.biter):
		# Jaws on a corner of the raft: a blow anywhere near its head counts.
		var b: Node3D = riding.biter
		var to_b: Vector3 = b.head_position() - o
		if to_b.length() <= reach + 1.6 and to_b.normalized().dot(d) > 0.5:
			b.take_damage(dmg, self)
			Sfx.play_at("hit", b.head_position(), -2.0)
			if is_instance_valid(riding):
				riding.bite_hit(b)
			used_tool(true)
			return
	var best := _creature_ahead(reach)
	if best:
		best.take_damage(dmg, self)
		Sfx.play_at("hit", best.hit_center(), -2.0)
		used_tool(true)
		if Game.inventory.held_id() == "" and best.def.get("fish", {}).get("spines", false):
			# Punching a live acanthodian bare-fisted: its fin spines jab back.
			hurt(SPINE_PRICK, best.global_position, 0.2, "spines")
			Game.notify("The %s's fin spines jab your hand." % best.def.name)
	elif Items.works_on(Game.inventory.held_id(), ["chop", "dig"]):
		# A shovel knocks a campfire apart and digs a meteorite out; an axe
		# hacks out a stump and hacks at a house site to tear it down; either
		# knocks a workbench loose, takes a plant out (a harvestable fern: its
		# spores, the same whichever) or, struck into the ground, clears a
		# decorative fern there for nothing. The stone mattock does it all,
		# slowly (Items.slow_tool).
		var held: String = Game.inventory.held_id()
		var digs: bool = "dig" in def.get("tags", [])
		var hit := _ray(reach, 1 | 2)
		if hit:
			var c: Node = hit.collider
			var done := false
			for n in [c, c.get_parent()]:
				if n and digs and n.has_method("break_apart"):
					n.break_apart()
					done = true
					break
				if n and not digs and n.has_method("axe_hit"):
					n.axe_hit()
					_heavy_work()
					done = true
					break
				if n and n.has_method("dig") and n.has_method("dug_by"):
					if Items.works_on(held, n.dug_by()):
						n.dig(Items.slow_tool(held))
						used_tool(false)
						_heavy_work()
					done = true
					break
			if not done and world and world.has_method("clear_fern"):
				world.clear_fern(hit.position)


func _heavy_work() -> void:
	## A swing that did hard work (digging, hacking): Heavy work's food and
	## water instead of a plain swing's.
	vitals.spend(COST_HEAVY[0] - COST_SWING[0], COST_HEAVY[1] - COST_SWING[1])


func used_tool(_hit := true) -> void:
	## A blow that landed with what you hold: a use of it (stone tools may
	## break, metal edges wear: Inventory.use_tool).
	var def := Items.def(Game.inventory.held_id())
	if def.has("breaks") or def.has("edge"):
		Game.inventory.use_tool(Game.inventory.selected)


func hurt(amount: float, from: Vector3, dirt := 0.3, source := "", deep := 1.0, by: Node3D = null) -> String:
	## A blow from a creature (from != ZERO): blood lost at once, a wound that
	## bleeds by how deep it is, a dressed wound torn open, and from a hard
	## enough hit perhaps a broken arm or leg. Otherwise just blood lost.
	## Blocking with a spear, a blow from in front goes on the guard first
	## (_block). Returns "deflect", "half" or "full" ("" when dead): what came
	## through. `by` is the animal, which a deflected blow staggers.
	if vitals.dead:
		return ""
	var got := "full"
	if from != Vector3.ZERO:
		_charge = -1.0  # a hit spoils a thrust you were drawing back
		if blocking and in_front(from):
			var b := _block(amount, by)
			amount = b[0]
			got = b[1]
			if got == "deflect":
				shake(0.1)
				return got
	if from != Vector3.ZERO and hauling and is_instance_valid(hauling) and hauling.haul_mode() == "pull":
		put_down()
		Game.notify("You let go of the handcart.")
	stop_pressure()
	if from != Vector3.ZERO and amount >= 3.0:
		vitals.reopen()
		vitals.add_wound(amount / 40.0 * deep, dirt, source)  # deep: a bite that cuts worse than it hits
		if amount >= FRACTURE_FROM and _injury_roll() < clampf((amount - 12.0) / 40.0, 0.0, 0.6):
			var limb := "arm" if _rng.randf() < 0.5 else "leg"
			if vitals.limbs.has(limb):
				limb = "leg" if limb == "arm" else "arm"
			vitals.break_limb(limb)
	vitals.lose_blood(amount * TRAUMA if from != Vector3.ZERO else amount)
	_shake = clampf(_shake + amount * 0.06, 0.0, 1.0)
	hurt_flash.emit(amount)
	Sfx.play("hurt", -2.0)
	if work_spot and world and world.has_method("close_work"):
		world.close_work()  # startled to your feet
	if from != Vector3.ZERO:
		var push := (global_position - from)
		push.y = 0.0
		velocity += push.normalized() * minf(amount * 0.4, 5.0) + Vector3(0, 1.5, 0)
		if amount >= SHOVE_FROM:
			_shove_t = SHOVE_WINDOW  # shoved into anything behind you, you go down
	return got


func _injury_roll() -> float:
	var r := next_injury if next_injury >= 0.0 else _rng.randf()
	next_injury = -1.0
	return r


func _check_fall(wet: bool) -> void:
	## Coming down hard from a height may sprain an ankle or break a leg, one
	## or the other, as likely as each other.
	if flying or wet or grabbed_by or climbing:
		_air_top = -INF
		return
	if not is_on_floor():
		_air_top = maxf(_air_top, global_position.y)
		return
	if _air_top == -INF:
		return
	var drop := _air_top - global_position.y
	_air_top = -INF
	landed(drop)


func landed(drop: float) -> void:
	## Came down from `drop` metres.
	if drop <= FALL_SAFE or vitals.dead:
		return
	Sfx.play("hurt", -6.0)
	_shake = clampf(_shake + 0.5, 0.0, 1.0)
	if _injury_roll() < clampf(0.25 + (drop - FALL_SAFE) / FALL_RISK * 0.75, 0.0, 1.0):
		vitals.break_limb("ankle" if _rng.randf() < 0.5 else "leg")
		stop_pressure()


# --- Pressure on a wound ------------------------------------------------------------
# From the Health tab: you hold still and press on a bleeding wound for
# Survival.PRESSURE_TIME. Moving, being hit or seized lets go.

func start_pressure(wound := -1) -> bool:
	if vitals.dead or grabbed_by or hauling:
		if hauling:
			Game.notify("Put down what you're carrying first (Q).")
		return false
	if wound < 0:
		for k in vitals.wounds.size():
			if vitals.wounds[k].bleed > 0 and (wound < 0 or vitals.wounds[k].bleed > vitals.wounds[wound].bleed):
				wound = k
	if wound < 0 or wound >= vitals.wounds.size() or vitals.wounds[wound].bleed == 0:
		Game.notify("Nothing is bleeding.")
		return false
	vitals.pressing = wound
	_press_t = 0.0
	velocity = Vector3(0, velocity.y, 0)
	return true


func stop_pressure(say := false) -> void:
	if vitals.pressing >= 0 and say:
		Game.notify("You let go of the wound.")
	vitals.pressing = -1
	_press_t = 0.0


func pressure_left() -> float:
	return maxf(Survival.PRESSURE_TIME - _press_t, 0.0) if vitals.pressing >= 0 else 0.0


func _hold_pressure(delta: float, input: Vector2) -> void:
	if input != Vector2.ZERO or Input.is_action_just_pressed("jump") or vitals.pressing >= vitals.wounds.size() \
			or vitals.wounds[vitals.pressing].bleed == 0:
		stop_pressure(input != Vector2.ZERO)
		return
	_press_t += delta
	if _press_t >= Survival.PRESSURE_TIME:
		var k := vitals.pressing
		stop_pressure()
		vitals.apply_pressure(k)


func _on_died() -> void:
	stop_pressure()
	put_down()
	if world and world.has_method("close_menus"):
		world.close_menus()  # they are drawn over the death screen's buttons
	capture_mouse(false)
	if grabbed_by and is_instance_valid(grabbed_by):
		grabbed_by.victim_died()
	died.emit()


# --- Seized by an amphibian -------------------------------------------------------
# The creature lunges and clamps its jaws on you. Your view is wrenched round to
# face it and you are pulled down toward the water. Stab it fast (attack) to
# break its grip before it drowns you; without good gear you rarely do.

func start_grab(creature: Node3D) -> void:
	if grabbed_by or vitals.dead:
		return
	stop_pressure()
	put_down()
	grabbed_by = creature
	blocking = false
	_charge = -1.0
	sneaking = false
	grip_max = creature.def.get("grip", 100.0)
	grip = grip_max
	strike_tier = ""
	escape_roll = -1.0
	_grab_t = 0.0
	_attack_cd = 0.25
	velocity = Vector3.ZERO
	if ui_open and world and world.has_method("close_ui"):
		world.close_ui()
	# Wrench the view round to stare into its jaws.
	var to: Vector3 = creature.head_position() - global_position
	rotation.y = atan2(-to.x, -to.z)
	_pitch = -0.35
	head.rotation.x = _pitch
	camera.rotation.z = 0.5
	_shake = 1.0
	Sfx.play("roar", 2.0, 0.05)
	hurt(creature.def.get("bite", GRAB_BITE), creature.global_position, 0.85, "amphibian")
	Game.crafted.emit("grabbed")


func _physics_grabbed(delta: float) -> void:
	var c := grabbed_by
	if not is_instance_valid(c):
		release_grab()
		return
	# Held in front of the jaws and dragged along with them.
	var anchor: Vector3 = c.grab_anchor()
	global_position = global_position.lerp(anchor, minf(delta * 6.0, 1.0))
	velocity = Vector3.ZERO
	if vitals_enabled:
		vitals.tick(delta, false, false, water_depth() > 0.25)


func _process_grabbed(delta: float) -> void:
	var c := grabbed_by
	if not is_instance_valid(c):
		release_grab()
		return
	_grab_t += delta
	var depth := water_depth()
	var dps: float = c.def.get("grab_dps", GRAB_DPS)
	vitals.lose_blood(dps * (1.5 if depth > 1.0 else 1.0) * delta)
	hurt_flash.emit(dps * delta * 0.4)
	if vitals.dead:
		return
	if rolls_for_escape() and escape_roll < 0.0 and (_grab_t >= ROLL_TIME or (_grab_t >= MIN_ROLL_TIME and c.in_deep_water())):
		_roll_escape()
		if grabbed_by == null:
			return
	# Keep the head low and the view locked on the jaws, thrashing.
	head.position.y = lerpf(head.position.y, 0.7, minf(delta * 5.0, 1.0))
	var to: Vector3 = c.head_position() - camera.global_position
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(delta * 6.0, 1.0))
	_pitch = lerpf(_pitch, clampf(atan2(to.y, Vector2(to.x, to.z).length()), -1.2, 0.6), minf(delta * 6.0, 1.0))
	head.rotation.x = _pitch
	camera.rotation.z = 0.35 + sin(_grab_t * 9.0) * 0.12
	_shake = maxf(_shake, 0.35)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if not frozen and _attack_cd <= 0.0 and Input.is_action_just_pressed("attack"):
		stab()


func rolls_for_escape() -> bool:
	## Whether the creature holding you lets go on a dice roll rather than
	## when its grip is broken.
	return is_instance_valid(grabbed_by) and grabbed_by.def.get("escape", false)


func escape_chance() -> float:
	return ESCAPE_BASE + ESCAPE_BONUS[strike_tier]


func _roll_escape() -> void:
	var c := grabbed_by
	var chance := escape_chance()
	escape_roll = next_roll if next_roll >= 0.0 else randf()
	next_roll = -1.0
	var freed := escape_roll < chance
	escape_rolled.emit(chance, escape_roll, freed)
	if freed:
		c.release(true)
		release_grab()
		velocity = Vector3(0, 1.5, 0)
		Game.notify("It lets go! You are out in deep water. Swim for the bank!")
	else:
		Game.notify("Its jaws only clamp tighter...")


func stab_power() -> float:
	## How much grip one stab breaks, by what you hold.
	var def := Items.def(Game.inventory.held_id())
	var p := 2.5
	if def.has("damage"):
		p = 4.0 + def.damage * 0.5
		if def.get("reach", 0.0) > 3.0:
			p *= 0.6   # a spear is too long to use in the jaws
	if vitals.stamina < 5.0:
		p *= 0.5
	return p


func stab() -> void:
	var c := grabbed_by
	if not is_instance_valid(c):
		return
	_attack_cd = STAB_COOLDOWN
	_swing = 0.0
	vitals.tire(4.0)
	vitals.spend(COST_SWING[0], COST_SWING[1])
	var def := Items.def(Game.inventory.held_id())
	c.take_damage(def.get("damage", FIST_DAMAGE), self)
	Sfx.play("hit", -2.0, 0.2)
	if rolls_for_escape():
		var tier: String = def.get("tier", "bare")
		if ESCAPE_BONUS[tier] > ESCAPE_BONUS[strike_tier]:
			strike_tier = tier
		return
	grip -= stab_power()
	if grip <= 0.0:
		var away: Vector3 = global_position - c.global_position
		away.y = 0.0
		c.release(true)
		release_grab()
		velocity = away.normalized() * 4.0 + Vector3(0, 2.5, 0)
		Game.notify("It lets go! Get away from the water!")


func release_grab() -> void:
	grabbed_by = null
	grip = 0.0
	_pitch = clampf(_pitch, -1.2, 1.2)
