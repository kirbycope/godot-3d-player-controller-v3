class_name FishingRod
extends Equipment
## One-button fishing: Action casts the float where the camera aims, nibbles telegraph the bite, Action
## inside the hook window hooks the fish, reeling plays out on its own and the catch lands on the HUD card.
##
## Timing runs on the Timer nodes wired in the scene; the fish table and shadows come from the [Buoyancy]
## water the float lands in, filtered by the [member lure] on the line (a [Lure] item used from the inventory
## goes on the line). A landed fish is a GARP [Item], so it goes into the Player's inventory. The float goes
## through the ProjectileSpawner when the scene has one, so every peer sees the float, its line, the dips and
## the catch; the rod itself only runs on its owner.

signal line_cast ## The float has left the rod.
signal bite(fish: Fish) ## The hook window is open.
signal fish_hooked(fish: Fish)
signal fish_caught(fish: Fish, length_cm: float)
signal fish_escaped(fish: Fish) ## The hook window closed, or the line was pulled while a fish was on.
signal lure_changed(lure: Item) ## Something else is on the line (null for a bare hook).

enum State { IDLE, CASTING, WAITING, BITE, REELING }

const FISHING_EMOTES: Array[String] = ["FishingIdle", "FishingCast", "FishingReel"]
const LINE_STATES: Array[int] = [NodeStateMachine.States.STANDING, NodeStateMachine.States.SPRINTING, NodeStateMachine.States.CROUCHING, NodeStateMachine.States.NONE] ## States the line stays out through; anything else pulls it in.
const ACTION_LABELS: Dictionary[int, String] = {State.IDLE: "Cast", State.CASTING: "", State.WAITING: "Reel In", State.BITE: "Hook!", State.REELING: ""} ## Action prompt per state.
const CAST_ANIMATION: StringName = &"Fishing Cast/mixamo_com"

@export var fishing_action: StringName = &"action"
@export var bobber_scene: PackedScene
@export var lure: Item: ## What is on the line; a [Lure] used from the inventory replaces it.
	set(value):
		lure = value
		lure_changed.emit(lure)
@export var max_cast_distance: float = 12.0
@export var cast_release: float = 1.5 ## Seconds into the cast animation at which the float leaves the rod.
@export var bite_wait: Vector2 = Vector2(3.0, 8.0) ## Seconds before the bite, before the rain and shadow bonuses.
@export var nibble_interval: Vector2 = Vector2(0.8, 1.8) ## Seconds between the small dips before the bite.
@export var hook_window: float = 1.0 ## Seconds after the bite in which Action hooks the fish.
@export var shadow_bonus_distance: float = 2.5 ## Landing within this of a shadow shortens the wait.
@export_group("Sounds")
@export var splash_sfx: AudioStream
@export var nibble_sfx: AudioStream
@export var bite_sfx: AudioStream
@export var reel_sfx: AudioStream
@export var catch_sfx: AudioStream

var state: State = State.IDLE
var bobber: Bobber
var water: Buoyancy ## The water the float landed in.
var hooked_fish: Fish ## The fish that will bite (chosen on landing) or is being reeled.
var hooked_length: float = 0.0
var emote_state: AnimationNodeStateMachinePlayback

@onready var animation_player: AnimationPlayer = $Sketchfab_Scene/AnimationPlayer
@onready var rod_tip: Marker3D = %RodTip ## Rides the pole's last bone, so the line starts at the bending tip.
@onready var cast_timer: Timer = $CastTimer ## Runs to the release point of the cast animation; its timeout launches the float.
@onready var bite_timer: Timer = $BiteTimer
@onready var nibble_timer: Timer = $NibbleTimer
@onready var hook_timer: Timer = $HookTimer

var hook_pulse: Tween ## Pulses the Action button green while the hook window is open.
@onready var reel_timer: Timer = $ReelTimer
@onready var audio: AudioStreamPlayer3D = $Audio


## Runs for the equipped copy (which has [member player] set); the world pickup does nothing.
func _ready() -> void:
	# The model's own thread hangs to the floor; the Line node draws the real one to the float
	var thread: Node3D = $Sketchfab_Scene.find_child("*RodThread*", true, false)
	if thread:
		thread.visible = false
	if not player or not is_multiplayer_authority():
		return
	emote_state = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	player.inventory.equipment_changed.connect(_on_equipment_changed)
	player.inventory.item_used.connect(_on_item_used)
	player.animation_tree.animation_finished.connect(_on_animation_finished)
	player.state_changed.connect(_on_player_state_changed)
	player.controls.input_type_changed.connect(_on_input_type_changed)
	_on_equipment_changed()


func _input(event: InputEvent) -> void:
	# No casting from a menu or from behind the wheel; a horse or a boat is fine
	if not player or not player.is_fishing or player.is_paused or player.riding is Vehicle \
			or not event.is_action_pressed(fishing_action):
		return
	match state:
		State.IDLE:
			cast()
		State.WAITING:
			retract()
		State.BITE:
			hook()


## Starts the cast facing the crosshair, like a throw; the float leaves [member cast_release] seconds into the animation.
func cast() -> void:
	if state != State.IDLE:
		return
	state = State.CASTING
	player.is_casting_line = true
	player.rotate_model_to_direction(-player.projectile_raycast.global_basis.z)
	emote_state.start("FishingCast")
	cast_timer.start(cast_release)
	update_labels()


## Hooks the biting fish and starts reeling; bigger fish take longer.
func hook() -> void:
	if state != State.BITE:
		return
	hook_timer.stop()
	state = State.REELING
	player.is_reeling_line = true
	update_labels()
	emote_state.start("FishingReel")
	if animation_player.has_animation("Take 001"):
		animation_player.play("Take 001")
	reel_timer.start(1.0 + hooked_length / 40.0)
	bobber.splash.rpc(0.8)
	bobber.thrash.rpc(reel_timer.wait_time)
	_play(reel_sfx)
	fish_hooked.emit(hooked_fish)


## Brings the line back in with nothing on it.
func retract() -> void:
	var lost: Fish = hooked_fish if state == State.BITE or state == State.REELING else null
	if water and water.shadows:
		water.shadows.release()
	_clear_line()
	state = State.IDLE
	if player.is_fishing:
		emote_state.start("FishingIdle")
		update_labels()
	if lost:
		fish_escaped.emit(lost)


func get_rod_tip() -> Vector3:
	return rod_tip.global_position


func _clear_line() -> void:
	for timer: Timer in [cast_timer, bite_timer, nibble_timer, hook_timer, reel_timer]:
		timer.stop()
	if is_instance_valid(bobber):
		bobber.retract.rpc()
	bobber = null
	water = null
	hooked_fish = null
	animation_player.stop()
	player.is_casting_line = false
	player.is_reeling_line = false


## Lobs the float from chest height on an arc that lands where the camera aims (clamped to the cast range).
## The rod tip itself can hang at ground level between poses, so it only anchors the drawn line.
func _on_cast_timer_timeout() -> void:
	if state != State.CASTING:
		return
	var ray: RayCast3D = player.projectile_raycast
	ray.force_raycast_update()
	var aim: Vector3 = (-ray.global_basis.z).slide(player.up_direction).normalized()
	var origin: Vector3 = player.global_position + player.up_direction * 1.3 + aim * 0.4
	var target: Vector3 = ray.get_collision_point() if ray.is_colliding() else ray.global_position - ray.global_basis.z * max_cast_distance
	var flat: Vector3 = (target - origin).slide(Vector3.UP)
	if flat.length() > max_cast_distance:
		flat = flat.normalized() * max_cast_distance
	# Aiming at a pool floor would flatten the arc; land at deck height and let the float drop in
	var rise: float = maxf(target.y, origin.y - 1.0) - origin.y
	var time: float = clampf(flat.length() / 6.0, 0.5, 1.4)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var velocity: Vector3 = flat / time + Vector3.UP * (rise + 0.5 * gravity * time * time) / time
	var spawner: ProjectileSpawner = get_tree().get_first_node_in_group(&"ProjectileSpawner") as ProjectileSpawner
	if spawner:
		# A client's copy arrives through the spawner's spawned signal instead of the return value
		if not spawner.spawned.is_connected(_on_spawner_spawned):
			spawner.spawned.connect(_on_spawner_spawned)
		var spawned: Projectile = spawner.fire(bobber_scene, Transform3D(Basis(), origin), velocity.normalized(), velocity.length(), player, self)
		if spawned:
			_adopt_bobber(spawned as Bobber)
	else:
		var local: Bobber = bobber_scene.instantiate()
		player.get_parent().add_child(local)
		local.launch(Transform3D(Basis(), origin), velocity.normalized(), velocity.length(), player, self)
		_adopt_bobber(local)
	state = State.WAITING
	player.is_casting_line = false
	update_labels()
	line_cast.emit()


## The spawner hands a client its own float once the server has spawned it.
func _on_spawner_spawned(node: Node) -> void:
	if bobber == null and state == State.WAITING and node is Bobber and (node as Bobber).shooter == player:
		_adopt_bobber(node as Bobber)


## A float that lands on dry ground just lies there until the player reels in; only water starts the bite.
func _adopt_bobber(float_node: Bobber) -> void:
	bobber = float_node
	bobber.landed_in_water.connect(_on_bobber_landed_in_water)


## Rolls what will bite and how soon; rain and a nearby shadow both shorten the wait.
func _on_bobber_landed_in_water(area: Area3D) -> void:
	water = area as Buoyancy
	bobber.plunge.rpc(0.08, 0.5)
	bobber.splash.rpc(0.6)
	_play(splash_sfx)
	hooked_fish = water.pick_fish(lure) if water else null
	if hooked_fish == null:
		return
	var bait: Lure = lure as Lure
	var wait: float = randf_range(bite_wait.x, bite_wait.y)
	if water.is_raining():
		wait *= 0.5
	if water.shadows and water.shadows.nearest_distance(bobber.global_position) <= shadow_bonus_distance:
		wait *= 0.6
	if bait:
		wait *= bait.bite_time_scale
	bite_timer.start(wait)
	nibble_timer.start(randf_range(nibble_interval.x, nibble_interval.y))
	if water.shadows:
		# Only a shadow already close takes the bait; the species says how close, the bait can stretch it
		water.shadows.attract(bobber.global_position, hooked_fish.attract_range + (bait.attract_range_bonus if bait else 0.0))


func _on_nibble_timer_timeout() -> void:
	if state != State.WAITING or bite_timer.time_left < 0.6:
		return
	bobber.plunge.rpc(0.04, 0.4)
	bobber.splash.rpc(0.25)
	if water.shadows:
		water.shadows.nibble(bobber.global_position)
	_play(nibble_sfx)
	nibble_timer.start(randf_range(nibble_interval.x, nibble_interval.y))


func _on_bite_timer_timeout() -> void:
	if state != State.WAITING:
		return
	state = State.BITE
	nibble_timer.stop()
	hooked_length = hooked_fish.roll_length()
	# Bait that gets eaten is gone with the bite; the line is bare once the bag runs out
	if lure and lure.consumable and player.inventory:
		player.inventory.remove_item(lure, 1)
		if player.inventory.count_of(lure) <= 0:
			lure = null
	bobber.plunge.rpc(0.35, 0.8)
	bobber.splash.rpc(1.0)
	if water.shadows:
		water.shadows.dive(bobber.global_position)
	_play(bite_sfx)
	Input.start_joy_vibration(0, 0.5, 0.7, 0.3)
	hook_timer.start(hook_window)
	update_labels()
	bite.emit(hooked_fish)


## The hook window closed: the fish spits the hook and the shadows dart off.
func _on_hook_timer_timeout() -> void:
	if state != State.BITE:
		return
	bobber.splash.rpc(0.4)
	if water.shadows:
		water.shadows.scatter()
	retract()


func _on_reel_timer_timeout() -> void:
	if state != State.REELING:
		return
	var fish: Fish = hooked_fish
	var length: float = hooked_length
	# Every peer watches the catch arc out of the water; the card is the caster's alone
	bobber.splash.rpc(1.0)
	bobber.present_catch.rpc(fish.resource_path, length)
	state = State.IDLE
	_clear_line()
	emote_state.start("FishingIdle")
	update_labels()
	# The log keeps every length in the bag and the record per species; the card says when this one is the record
	var log: FishingLog = player.get_node_or_null(^"FishingLog") as FishingLog
	var is_record: bool = log.record_catch(fish, length) if log else false
	var card: FishCard = player.controls.get_node_or_null(^"FishCard") as FishCard
	if card:
		card.show_catch(fish, length, is_record)
	_play(catch_sfx)
	player.inventory.add_item(fish) # a full tab leaves it on the card only
	fish_caught.emit(fish, length)


## What the rod says about itself in the inventory: the bait on the line and what it does.
func get_details() -> String:
	if lure == null:
		return "Bare hook."
	var text: String = "On the line: %s" % lure.get_display_name()
	var bait: Lure = lure as Lure
	if bait:
		var effects: PackedStringArray = bait.describe_effects()
		var takers: PackedStringArray = []
		for water_area: Node in get_tree().get_nodes_in_group("WATER"):
			if water_area is Buoyancy:
				for fish in (water_area as Buoyancy).fish:
					if fish.lures.any(func(wanted: Item) -> bool: return wanted.is_same(bait)) and not takers.has(fish.get_display_name()):
						takers.append(fish.get_display_name())
		if not takers.is_empty():
			effects.append("Tempts: " + ", ".join(takers))
		if not effects.is_empty():
			text += "\n" + "\n".join(effects)
	return text


## The Action prompt follows the fishing state while the rod is out; states yield the labels meanwhile.
func update_labels() -> void:
	if not player.is_fishing:
		return
	player.controls.reset_labels()
	player.controls.joypad_button_0_label.text = ACTION_LABELS[state]
	# The hook window is short: the Action button throbs green until it closes
	if state == State.BITE:
		if hook_pulse == null or not hook_pulse.is_valid():
			var button: CanvasItem = player.controls.joypad_button_0
			hook_pulse = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			hook_pulse.tween_property(button, "modulate", Color(0.55, 1.0, 0.55), 0.25)
			hook_pulse.tween_property(button, "modulate", Color(0.0, 0.85, 0.0), 0.25)
	else:
		stop_hook_pulse()


## Puts the Action button back to its own colour.
func stop_hook_pulse() -> void:
	if hook_pulse and hook_pulse.is_valid():
		hook_pulse.kill()
	hook_pulse = null
	if player and player.controls:
		player.controls.joypad_button_0.modulate = Color.WHITE


func _on_input_type_changed(_input_type: int) -> void:
	update_labels()


## Using a [Lure] from the inventory puts it on the line.
func _on_item_used(item: Item, _count: int) -> void:
	if item is Lure:
		lure = item


func _play(stream: AudioStream) -> void:
	if stream:
		audio.stream = stream
		audio.play()


## Keeps the posture right for the equipped copy every frame; the world pickup has no Player.
func _process(_delta: float) -> void:
	if player and player.is_fishing and is_multiplayer_authority():
		update_posture()


## The fishing posture (the upper-body emote over the locomotion) shows while the line is out or the Player stands
## or sits still; on the move the great-sword locomotion carries the rod on its own, so the walk and run read right.
## Another emote or a spell's channel pose on that layer is left to its own owner.
func update_posture() -> void:
	if emote_state == null or String(emote_state.get_current_node()) not in FISHING_EMOTES:
		return
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0 if wants_posture() else 0.0)


## Whether the fishing posture belongs on the body right now.
func wants_posture() -> bool:
	if state != State.IDLE:
		return true
	if player.is_sitting:
		return true
	return not player.has_move_input and Vector2(player.velocity.x, player.velocity.z).length() < 0.5


## Holds the fishing upper-body posture while a rod is equipped; unequipping pulls the line in.
func _on_equipment_changed() -> void:
	player.is_fishing = player.inventory.has_equipment(Equipment.EquipmentType.FISHING_ROD)
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0 if player.is_fishing else 0.0)
	if player.is_fishing:
		emote_state.start("FishingIdle")
		update_labels()
	else:
		retract()
		stop_hook_pulse()
		# Hand the control labels back to the active state, as a dropped held object does
		player.controls.reset_labels()
		var state_node: NodeStateMachine = player.state_machine.get_node_or_null(NodePath(NodeStateMachine.get_state_name(player.current_state))) as NodeStateMachine
		if state_node:
			state_node._on_input_type_changed(player.controls.current_input_type)


## Any non-fishing emote hands back to the fishing posture once it ends.
func _on_animation_finished(_animation_name: StringName) -> void:
	if player.is_fishing and String(emote_state.get_current_node()) not in FISHING_EMOTES:
		emote_state.start("FishingIdle")


## Jumping, falling, swimming, driving and the like pull the line in; stopping a sprint or crouching does not.
func _on_player_state_changed(_from_state: int, to_state: int) -> void:
	if state != State.IDLE and not to_state in LINE_STATES:
		retract()
