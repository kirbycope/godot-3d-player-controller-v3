class_name FishingRod
extends Equipment
## One-button fishing: Action casts the float where the camera aims, nibbles telegraph the bite, Action
## inside the hook window hooks the fish, reeling plays out on its own and the catch lands on the HUD card.
##
## Timing runs on the Timer nodes wired in the scene; the fish table and shadows come from the [Buoyancy]
## water the float lands in. The float goes through the ProjectileSpawner when the scene has one, so every
## peer sees the float, its line, the dips and the catch; the rod itself only runs on its owner.

signal line_cast ## The float has left the rod.
signal bite(fish: Fish) ## The hook window is open.
signal fish_hooked(fish: Fish)
signal fish_caught(fish: Fish, length_cm: float)
signal fish_escaped(fish: Fish) ## The hook window closed, or the line was pulled while a fish was on.

enum State { IDLE, CASTING, WAITING, BITE, REELING }

const FISHING_EMOTES: Array[String] = ["FishingIdle", "FishingCast", "FishingReel"]
const CAST_ANIMATION: StringName = &"Fishing Cast/mixamo_com"

@export var fishing_action: StringName = &"action"
@export var bobber_scene: PackedScene
@export var max_cast_distance: float = 12.0
@export var cast_release: float = 1.5 ## Seconds into the cast animation at which the float leaves the rod.
@export var bite_wait: Vector2 = Vector2(3.0, 8.0) ## Seconds before the bite, before the rain and shadow bonuses.
@export var nibble_interval: Vector2 = Vector2(0.8, 1.8) ## Seconds between the small dips before the bite.
@export var hook_window: float = 0.6 ## Seconds after the bite in which Action hooks the fish.
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
	player.animation_tree.animation_finished.connect(_on_animation_finished)
	player.state_changed.connect(_on_player_state_changed)
	_on_equipment_changed()


func _input(event: InputEvent) -> void:
	if not player or not player.is_fishing or not event.is_action_pressed(fishing_action):
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


## Hooks the biting fish and starts reeling; bigger fish take longer.
func hook() -> void:
	if state != State.BITE:
		return
	hook_timer.stop()
	state = State.REELING
	player.is_reeling_line = true
	emote_state.start("FishingReel")
	if animation_player.has_animation("Take 001"):
		animation_player.play("Take 001")
	reel_timer.start(1.0 + hooked_length / 40.0)
	if water.shadows and not hooked_fish.is_junk:
		water.shadows.hook(bobber.global_position, reel_timer.wait_time)
	_play(reel_sfx)
	fish_hooked.emit(hooked_fish)


## Brings the line back in with nothing on it.
func retract() -> void:
	var lost: Fish = hooked_fish if state == State.BITE or state == State.REELING else null
	_clear_line()
	state = State.IDLE
	if player.is_fishing:
		emote_state.start("FishingIdle")
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
	line_cast.emit()


## The spawner hands a client its own float once the server has spawned it.
func _on_spawner_spawned(node: Node) -> void:
	if bobber == null and state == State.WAITING and node is Bobber and (node as Bobber).shooter == player:
		_adopt_bobber(node as Bobber)


func _adopt_bobber(float_node: Bobber) -> void:
	bobber = float_node
	bobber.landed_in_water.connect(_on_bobber_landed_in_water)
	bobber.landed_dry.connect(retract)


## Rolls what will bite and how soon; rain and a nearby shadow both shorten the wait.
func _on_bobber_landed_in_water(area: Area3D) -> void:
	water = area as Buoyancy
	bobber.plunge.rpc(0.08, 0.5)
	_play(splash_sfx)
	hooked_fish = water.pick_fish() if water else null
	if hooked_fish == null:
		return
	var wait: float = randf_range(bite_wait.x, bite_wait.y)
	if water.is_raining():
		wait *= 0.5
	if water.shadows and water.shadows.nearest_distance(bobber.global_position) <= shadow_bonus_distance:
		wait *= 0.6
	bite_timer.start(wait)
	nibble_timer.start(randf_range(nibble_interval.x, nibble_interval.y))


func _on_nibble_timer_timeout() -> void:
	if state != State.WAITING or bite_timer.time_left < 0.6:
		return
	bobber.plunge.rpc(0.04, 0.4)
	_play(nibble_sfx)
	nibble_timer.start(randf_range(nibble_interval.x, nibble_interval.y))


func _on_bite_timer_timeout() -> void:
	if state != State.WAITING:
		return
	state = State.BITE
	nibble_timer.stop()
	hooked_length = hooked_fish.roll_length()
	bobber.plunge.rpc(0.35, 0.8)
	_play(bite_sfx)
	Input.start_joy_vibration(0, 0.5, 0.7, 0.3)
	hook_timer.start(hook_window)
	bite.emit(hooked_fish)


## The hook window closed: the fish spits the hook and the shadows dart off.
func _on_hook_timer_timeout() -> void:
	if state != State.BITE:
		return
	if water.shadows:
		water.shadows.scatter()
	retract()


func _on_reel_timer_timeout() -> void:
	if state != State.REELING:
		return
	var fish: Fish = hooked_fish
	var length: float = hooked_length
	# Every peer watches the catch arc out of the water; the card is the caster's alone
	bobber.present_catch.rpc(fish.resource_path, length)
	state = State.IDLE
	_clear_line()
	emote_state.start("FishingIdle")
	var card: FishCard = player.controls.get_node_or_null(^"FishCard") as FishCard
	if card:
		card.show_catch(fish, length)
	_play(catch_sfx)
	fish_caught.emit(fish, length)


func _play(stream: AudioStream) -> void:
	if stream:
		audio.stream = stream
		audio.play()


## Holds the fishing upper-body posture while a rod is equipped; unequipping pulls the line in.
func _on_equipment_changed() -> void:
	player.is_fishing = player.inventory.has_equipment(Equipment.EquipmentType.FISHING_ROD)
	player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0 if player.is_fishing else 0.0)
	if player.is_fishing:
		emote_state.start("FishingIdle")
	else:
		retract()


## Any non-fishing emote hands back to the fishing posture once it ends.
func _on_animation_finished(_animation_name: StringName) -> void:
	if player.is_fishing and String(emote_state.get_current_node()) not in FISHING_EMOTES:
		emote_state.start("FishingIdle")


## Jumping, swimming, driving or anything else that changes state pulls the line in.
func _on_player_state_changed(_from_state: int, _to_state: int) -> void:
	if state != State.IDLE:
		retract()
