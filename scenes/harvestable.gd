class_name Harvestable
extends Gatherable
## A tree or an ore deposit of this world: the player controller's [Gatherable], which counts the strikes on the
## server, puts [member Gatherable.item] in the striker's bag and replicates [member Gatherable.is_spent], with what
## this game adds to it. Action while looking at it swings the tool it needs and the strike lands [member hit_delay]
## later; every strike the server counts throws the chips, plays [member hit_sfx] (the spending one
## [member depleted_sfx]) and fills the progress bar on every peer ([method _on_struck], wired to
## [signal Gatherable.struck] in the scene); a spent one stays standing as its spent model (the scenes turn
## [member Gatherable.hide_when_spent] off, and [method _on_depleted], wired to depleted, swaps the model) rather than
## vanishing; and it is Saveable, so a [SaveGame] keeps how far along it is. The scenes inherit the addon's
## [code]scenes/prop/gatherable.tscn[/code].

@export var hit_delay: float = 0.9 ## Seconds after the harvesting animation starts before the strike lands.
@export var harvest_animation: String = "Logging" ## Locomotion node played inside the equipped weapon group while harvesting.
@export_group("Strike Effects")
@export var hit_sfx: AudioStream ## Played on every strike, on every peer.
@export var depleted_sfx: AudioStream ## Played instead on the strike that spends it.

var player: Player ## The local Player looking at it, while one is.

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var progress_bar: ProgressBar3D = $ProgressBar3D ## Reads 0 to 1, the fraction [signal Gatherable.struck] reports.
@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var hit_particles: GPUParticles3D = $HitParticles ## One-shot chips at strike height.


func _ready() -> void:
	super()
	add_to_group(SaveGame.GROUP)


## What a [SaveGame] keeps: how far along it is and whether it is spent.
func save_state() -> Dictionary:
	return {"hits": hits, "yields_given": yields_given, "is_spent": is_spent}


## Puts a [method save_state] back; a spent one does not grow back from a save that has it standing.
func load_state(state: Dictionary) -> void:
	hits = int(state.get("hits", 0))
	yields_given = int(state.get("yields_given", 0))
	if bool(state.get("is_spent", false)):
		is_spent = true


## Action while the local Player looks at it swings the tool it needs, if the Player holds one: the harvesting clip
## plays and the strike lands [member hit_delay] later through [method Gatherable.register_weapon_hit], which asks
## the server. The gate is the looking Player's authority, not this node's (the server owns it), so a client
## harvests too.
func _input(event: InputEvent) -> void:
	if not player or not player.is_multiplayer_authority() or player.is_typing or player.is_paused or is_spent \
			or not event.is_action_pressed("action") or player.is_locomotion_state_active_or_queued(harvest_animation):
		return
	for tool: Equipment in player.inventory.equipment:
		if can_harvest_with(tool):
			player.rotate_model_to_direction(global_position - player.global_position)
			# Heavy equipment uses the GreatSword locomotion group
			var group: String = "GreatSword" if player.inventory.has_heavy_weapon_equipped() else "Shield"
			player.travel_locomotion(group + "/" + harvest_animation)
			get_tree().create_timer(hit_delay).timeout.connect(register_weapon_hit.bind(tool))
			return


## Wired to [signal Gatherable.struck] in the scene: a strike the server counted, on every peer. The chips, the strike
## sound (the spending strike's own at [param fraction] 1) and the progress bar at [param fraction]; it reads the
## fraction alone, so it plays the same whether a client hears of the strike or of [signal Gatherable.depleted] first.
func _on_struck(fraction: float) -> void:
	progress_bar.value = fraction
	hit_particles.restart()
	var stream: AudioStream = depleted_sfx if fraction >= 1.0 else hit_sfx
	if stream:
		hit_audio.stream = stream
		hit_audio.play()


## Wired to depleted in the scene, on every peer: lets go of the Player looking on; the subclasses swap in the spent
## model, which stays where it stood.
func _on_depleted() -> void:
	hide_menu()


## Called by [Camera] while the local Player looks at it.
func display_menu(looking: Player) -> void:
	if is_spent:
		return
	player = looking
	action_prompt.show_for(player.controls)


## Called by [Camera] when the Player looks away, and as it is spent.
func hide_menu() -> void:
	action_prompt.hide_for(player.controls if player else null)
	player = null
