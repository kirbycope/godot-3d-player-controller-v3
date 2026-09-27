class_name GameCommands
extends RefCounted
## This game's own chat commands, registered with the player controller's chat by [member Main] before any Player
## exists, the way the extra control schemes are, so every level's Player carries them: "/level" ([Levels]), "/time"
## for the clock and "/weather" for the sky. The clock and the weather are the host's in a session (they replicate
## from it), so with other peers in the game only the host may set them; a client is told so.

const WEATHER_NAMES: Dictionary[String, ClimateData.WeatherType] = {
	"clear": ClimateData.WeatherType.BLUE_SKY,
	"cloudy": ClimateData.WeatherType.CLOUDY,
	"rain": ClimateData.WeatherType.RAIN,
	"downpour": ClimateData.WeatherType.HEAVY_RAIN,
	"storm": ClimateData.WeatherType.STORM,
	"snow": ClimateData.WeatherType.SNOW,
	"blizzard": ClimateData.WeatherType.HEAVY_SNOW,
}


static func register() -> void:
	Levels.register()
	ChatWindow.register_command("time", "/time hh[:mm]: sets the clock (host only in a session)", time)
	ChatWindow.register_command("weather", "/weather clear|cloudy|rain|downpour|storm|snow|blizzard|auto: sets the sky (host only in a session)", weather)


## The hour "/time" asks for, as hours since midnight, or -1 when the text is not a time of day.
static func parse_time(text: String) -> float:
	var parts: PackedStringArray = text.split(":")
	if parts.is_empty() or parts.size() > 2 or not parts[0].is_valid_int():
		return -1.0
	var hours: int = parts[0].to_int()
	var minutes: int = parts[1].to_int() if parts.size() == 2 and parts[1].is_valid_int() else (0 if parts.size() == 1 else -1)
	if hours < 0 or hours > 23 or minutes < 0 or minutes > 59:
		return -1.0
	return hours + minutes / 60.0


## Whether this peer may set the shared things: alone, or the host of a session with others in it.
static func may_set_shared(peers: int, is_server: bool) -> bool:
	return peers == 0 or is_server


static func time(args: PackedStringArray, chat: ChatWindow) -> void:
	var clock: DateAndTime = _find(chat, "DateAndTime") as DateAndTime
	if clock == null:
		chat.append_system("This level has no clock")
		return
	if args.is_empty():
		chat.append_system("It is %02d:%02d. /time hh[:mm] sets the clock." % [int(clock.current_time), int(fmod(clock.current_time, 1.0) * 60.0)])
		return
	var hour: float = parse_time(args[0])
	if hour < 0.0:
		chat.append_system("Usage: /time hh[:mm], on the 24 hour clock")
		return
	if not may_set_shared(_peers(chat), chat.multiplayer.is_server()):
		chat.append_system("Only the host sets the clock in a session")
		return
	clock.current_time = hour
	chat.append_system("The clock says %s" % args[0])


static func weather(args: PackedStringArray, chat: ChatWindow) -> void:
	var sky: WeatherFX = _find(chat, "WeatherFX") as WeatherFX
	if sky == null:
		chat.append_system("This level has no weather")
		return
	var names: String = ", ".join(WEATHER_NAMES.keys()) + ", auto"
	if args.is_empty() or not (WEATHER_NAMES.has(args[0].to_lower()) or args[0].to_lower() == "auto"):
		chat.append_system("Weather: %s. /weather <name> sets it." % names)
		return
	if not may_set_shared(_peers(chat), chat.multiplayer.is_server()):
		chat.append_system("Only the host sets the weather in a session")
		return
	var name: String = args[0].to_lower()
	if name == "auto":
		sky.force_weather = false
		chat.append_system("The weather runs on its own again")
		return
	sky.force_weather = true
	sky.manual_weather = WEATHER_NAMES[name]
	sky.set_weather(WEATHER_NAMES[name])
	chat.append_system("Weather set to %s" % name)


static func _peers(chat: ChatWindow) -> int:
	return chat.multiplayer.get_peers().size() if chat.multiplayer.has_multiplayer_peer() else 0


## The first node of [param type_name] in the tree: a level has one clock and one sky.
static func _find(chat: ChatWindow, type_name: String) -> Node:
	var found: Array[Node] = chat.get_tree().root.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null
