class_name CampfireRest
extends Node3D
## Resting at a campfire, as in Breath of the Wild. With the fire lit and nothing hunting the Player, Action at it
## offers Rest; the choice (a Dialogic question, through the [Conversation] under this node) is until morning, noon or
## night. The screen fades while the hours pass: the clock ([DateAndTime]) jumps to that hour, on to the next day when
## it has already passed, and the weather ([WeatherFX]) moves on one forecast cycle for every
## [member hours_per_cycle] skipped. In multiplayer anyone may rest and the host skips the shared clock and weather for
## everyone, as co-op games do; every peer sees the fade.
##
## The fire is the [Campfire] from the weather addon under this node; the camera finds this node as its interaction
## target through the fire's collider, and the [InteractionReach] under it keeps the offer to arm's length. The
## reach covers the flames, where the fire's heat costs the Player health ([BodyTemperature]), so the offer is
## withdrawn while they stand in it and comes back as they step out (the body's felt_temperature_changed).

signal rested(hour: float) ## The hours have passed, on every peer; [param hour] is the hour it is now.

@export var campfire: Campfire
@export var date_and_time: DateAndTime ## Found through the world's DateAndTime node when empty.
@export var weather_fx: WeatherFX ## Found through the WeatherFX group when empty.
@export var hours_per_cycle: float = 4.0 ## In-game hours one forecast cycle covers: the WeatherFX's 4-minute cycle, at a 24-minute day.
@export var prompt_label: String = "Rest"
@export var fade_time: float = 0.6 ## Seconds the screen takes to go dark, and to come back.
@export var dark_time: float = 1.0 ## Seconds it stays dark while the hours pass.

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var conversation: Conversation = $Conversation
@onready var fade: ColorRect = $FadeLayer/Fade

var player: Player ## The local Player being offered a rest, or resting.


## Whether [param who] may rest here now: the fire lit, no enemy hunting them, and not standing in the flames.
func can_rest(who: Player) -> bool:
	return is_instance_valid(campfire) and campfire.lit and who != null and who.hunters.is_empty() \
			and not conversation.is_talking() and not is_burning(who)


## True while the fire's heat is costing [param who] health: they are too close to rest.
func is_burning(who: Player) -> bool:
	var body: BodyTemperature = who.body_temperature
	if body == null or not who.enable_temperature:
		return false
	return body.damage_for(body.air_temperature() + campfire.warmth_at(who.global_position)) > 0.0


## Called by the [Camera] when this is what the action button would act on. The offer follows the heat the Player
## feels while they are the target, so it goes down in the flames and comes back a step away.
func display_menu(who: Player) -> void:
	player = who
	_offer()
	if who.body_temperature and not who.body_temperature.felt_temperature_changed.is_connected(_on_felt_temperature_changed):
		who.body_temperature.felt_temperature_changed.connect(_on_felt_temperature_changed)


func hide_menu() -> void:
	_withdraw()
	if is_instance_valid(player) and player.body_temperature \
			and player.body_temperature.felt_temperature_changed.is_connected(_on_felt_temperature_changed):
		player.body_temperature.felt_temperature_changed.disconnect(_on_felt_temperature_changed)


func _on_felt_temperature_changed(_celsius: float) -> void:
	_offer()


## The prompt, up while [member player] may rest and down while they may not.
func _offer() -> void:
	if is_instance_valid(player) and can_rest(player):
		action_prompt.show_for(player.controls, prompt_label)
	else:
		_withdraw()


## Takes the prompt down and gives the HUD its Action label back; a bare hide() would leave the label reading Rest.
func _withdraw() -> void:
	if is_instance_valid(player) and player.controls:
		action_prompt.hide_for(player.controls)
	else:
		action_prompt.hide()


## Called by the [Camera] on Action: the question comes up, the Player held still meanwhile.
func equip(who: Player) -> void:
	if not can_rest(who):
		return
	player = who
	action_prompt.hide()
	who.is_paused = true
	if not conversation.start(who):
		who.is_paused = false


## The [Conversation] is over, whatever was chosen: the Player may move again.
func end_talk() -> void:
	if is_instance_valid(player):
		player.is_paused = false


## [code][signal arg="rest <hour>"][/code] from the rest timeline (the Conversation's signal_received, wired in the
## scene): rest until that hour.
func _on_signal_received(words: PackedStringArray) -> void:
	if words.size() >= 2 and words[0] == "rest":
		rest_until(float(words[1]))


## Asks the host to skip to [param hour]; the host is the one with the clock and the weather.
func rest_until(hour: float) -> void:
	if multiplayer.is_server():
		_rest(hour)
	else:
		_request_rest.rpc_id(1, hour)


@rpc("any_peer", "call_remote", "reliable")
func _request_rest(hour: float) -> void:
	if multiplayer.is_server():
		_rest(hour)


## On the host: the clock jumps to [param hour], on to the next day when it has passed, the weather moves on as many
## cycles as those hours cover, and every peer fades.
func _rest(hour: float) -> void:
	var clock: DateAndTime = _clock()
	var skipped: float = 0.0
	if clock:
		skipped = hours_until(clock.current_time, hour)
		clock.add_hours(skipped)
	var weather: WeatherFX = _weather()
	if weather and hours_per_cycle > 0.0:
		for cycle: int in int(skipped / hours_per_cycle):
			weather.advance_cycle()
	_rested.rpc(hour)


## Hours from [param now] until [param hour] comes round: later today, or tomorrow when it has passed (or is not a
## quarter of an hour away, so a rest always takes some time).
static func hours_until(now: float, hour: float) -> float:
	var hours: float = fposmod(hour - now, 24.0)
	return hours + 24.0 if hours < 0.25 else hours


@rpc("authority", "call_local", "reliable")
func _rested(hour: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	tween.tween_interval(dark_time)
	tween.tween_property(fade, "modulate:a", 0.0, fade_time)
	rested.emit(hour)


func _clock() -> DateAndTime:
	if date_and_time == null:
		date_and_time = get_tree().current_scene.get_node_or_null("DateAndTime") as DateAndTime if get_tree().current_scene else null
	return date_and_time


func _weather() -> WeatherFX:
	if weather_fx == null:
		weather_fx = get_tree().get_first_node_in_group(&"WeatherFX") as WeatherFX
	return weather_fx
