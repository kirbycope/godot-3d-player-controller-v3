class_name Doom
extends Control
## A DOOM-style raycaster for the [RetroComputer] screen: a DOS prompt boots into a 320x200 maze of hunting
## demons, drawn one screen column at a time in [method _draw]. The wall, monster and shotgun art is generated
## on the fly, so the scene ships no third-party assets. Walking and turning poll the player controller's
## actions (analog input has no signal); everything else arrives as events pushed into the screen's [SubViewport].

enum Screen { PROMPT, BOOTING, PLAYING, DEAD, WON, ENGINE }

## A floating one-eyed demon that bites once it has seen you.
class Demon:
	var position: Vector2
	var health: int = 80
	var is_awake: bool = false
	var attack_cooldown: float = 0.0
	var dead_time: float = 0.0 ## Seconds since it died; the blood splat fades over [constant SPLAT_TIME].

const WIDTH: int = 320
const HEIGHT: int = 200
const VIEW_HEIGHT: int = 168 ## The 3D view; the status bar takes the rest.
const HALF_VIEW: int = 84
const TEXTURE_SIZE: int = 64
const SPRITE_SIZE: int = 32
const PLANE_LENGTH: float = 0.66 ## Half-width of the camera plane at unit distance: about a 66 degree field of view.
const SPLAT_TIME: float = 0.6
const COMMAND: String = "DOOM.EXE"
const PROMPT_TEXT: String = "RETRO PC BIOS v1.02\n640K RAM OK\n\nC:\\>"
const BOOT_LINES: PackedStringArray = [
	"",
	"DOOM Startup v1.9",
	"V_Init: allocating screens.",
	"Z_Init: zone memory daemon ready.",
	"W_Init: adding DOOM.WAD",
	"R_Init: refresh daemon [........]",
	"P_Init: playloop state.",
	"S_Init: sound (PC speaker).",
	"ST_Init: status bar.",
]
## Walls are '#' stone, 'B' brown brick and 'T' tech panels; 'P' is where you start and every 'E' is a demon.
const MAP: PackedStringArray = [
	"################",
	"#P.....#.......#",
	"#..##..#..TT...#",
	"#..##.......E..#",
	"#......BBB..T..#",
	"####...B.......#",
	"#..E...B..###..#",
	"#......#..#E...#",
	"#..TT..#..#....#",
	"#..T....E......#",
	"#..T...#####...#",
	"#......#...#.E.#",
	"#..E...#...#...#",
	"#..............#",
	"#......E.......#",
	"################",
]
const WALL_KINDS: Dictionary[String, int] = {"#": 0, "B": 1, "T": 2}

@export var move_speed: float = 3.0 ## Map cells per second.
@export var mouse_sensitivity: float = 0.004 ## Radians per pixel of mouse motion or touch drag.
@export var joypad_turn_speed: float = 2.5 ## Radians per second at full stick.
@export var demon_speed: float = 1.6 ## Map cells per second once a demon hunts you.
@export var demon_bite: int = 12 ## Health lost per bite.
@export var shotgun_damage: int = 40
@export var shoot_sfx: AudioStream
@export var hurt_sfx: AudioStream
@export var demon_death_sfx: AudioStream
@export_file("*.sf2") var soundfont: String = "" ## SoundFont the real engine's music plays through (Godot MIDI Player); empty means no music.
@export var use_engine: bool = true ## Off, the raycaster plays even where the PureDoom library is built; `doom_raycaster.tscn` runs it that way on its own.

var screen: Screen = Screen.PROMPT
var player_position: Vector2
var player_angle: float = 0.0
var health: int = 100
var ammo: int = 50
var kills: int = 0
var demons: Array[Demon] = []
var fire_cooldown: float = 0.0
var flash_time: float = 0.0 ## Muzzle flash left to show, in seconds.
var hurt_time: float = 0.0 ## Red pain flash left to show, in seconds.
var bob: float = 0.0 ## Walk cycle phase for the shotgun sway.
var face_look: int = 0 ## -1, 0 or 1: where the status bar face is glancing.
var boot_text: String = ""
var boot_line: int = 0
var wall_textures: Array[ImageTexture] = []
var demon_texture: ImageTexture
var splat_texture: ImageTexture
var shotgun_texture: ImageTexture
var flash_texture: ImageTexture
var depth: PackedFloat32Array = PackedFloat32Array() ## Wall distance per screen column, so sprites hide behind walls.
var font: Font
var engine: Control ## The real DOOM (the PureDoom GDExtension node) when its library is built for this platform; the raycaster otherwise.
var midi_player: Node ## Godot MIDI Player synthesising the engine's music, when a [member soundfont] is set.

@onready var boot_label: Label = $BootLabel
@onready var boot_timer: Timer = $BootTimer
@onready var face_timer: Timer = $FaceTimer
@onready var sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	for kind: int in WALL_KINDS.size():
		wall_textures.append(make_wall_texture(kind))
	demon_texture = make_demon_texture()
	splat_texture = make_splat_texture()
	shotgun_texture = make_shotgun_texture()
	flash_texture = make_flash_texture()
	depth.resize(WIDTH)
	font = boot_label.get_theme_font("font")
	sleep()


## Events pushed into the screen's [SubViewport] by the [RetroComputer] while the Player is at the keyboard.
func _unhandled_input(event: InputEvent) -> void:
	if screen == Screen.PLAYING:
		if event is InputEventMouseMotion:
			player_angle += (event as InputEventMouseMotion).relative.x * mouse_sensitivity
		elif event is InputEventScreenDrag:
			player_angle += (event as InputEventScreenDrag).relative.x * mouse_sensitivity
		elif event.is_action_pressed("shoot"):
			fire()
	elif (screen == Screen.DEAD or screen == Screen.WON) and (event.is_action_pressed("shoot") or event.is_action_pressed("action")):
		start_level()


## Walks, turns and runs the demons; only enabled while a level is being played.
func _physics_process(delta: float) -> void:
	if screen != Screen.PLAYING:
		return
	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	player_angle += look.x * joypad_turn_speed * delta
	var move: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var forward: Vector2 = Vector2.from_angle(player_angle)
	var right: Vector2 = Vector2(-forward.y, forward.x)
	var step: Vector2 = (forward * -move.y + right * move.x) * move_speed * delta
	player_position = slide(player_position, step, 0.25)
	bob += step.length() * 5.0
	fire_cooldown -= delta
	flash_time -= delta
	hurt_time -= delta
	for demon: Demon in demons:
		update_demon(demon, delta)
	queue_redraw()


## Shows the DOS prompt and stops simulating; called when nobody is at the computer.
func sleep() -> void:
	screen = Screen.PROMPT
	set_physics_process(false)
	boot_timer.stop()
	if engine:
		engine.call(&"stop")
		engine.hide()
	if midi_player:
		midi_player.call(&"stop") # Silences every held note
	boot_label.text = PROMPT_TEXT + "_"
	boot_label.show()
	queue_redraw()


## Types the command at the prompt and scrolls the startup log before the level begins.
func boot() -> void:
	screen = Screen.BOOTING
	boot_line = 0
	boot_text = PROMPT_TEXT
	boot_label.text = boot_text
	boot_label.show()
	boot_timer.start(0.4)


func _on_boot_timer_timeout() -> void:
	var typed: int = boot_text.length() - PROMPT_TEXT.length()
	if typed < COMMAND.length():
		boot_text += COMMAND[typed]
		boot_label.text = boot_text
		boot_timer.start(0.12)
	elif boot_line < BOOT_LINES.size():
		boot_text += "\n" + BOOT_LINES[boot_line]
		boot_line += 1
		boot_label.text = boot_text
		boot_timer.start(0.25)
	else:
		start_game()


## Blinks the cursor while the prompt is idle.
func _on_blink_timer_timeout() -> void:
	if screen == Screen.PROMPT:
		boot_label.text = PROMPT_TEXT + ("" if boot_label.text.ends_with("_") else "_")


## The status bar face glances about at random, as the original's did.
func _on_face_timer_timeout() -> void:
	face_look = randi_range(-1, 1)
	face_timer.wait_time = randf_range(0.7, 2.0)


## Hands the screen to the real engine when the PureDoom library is built for this platform (and [member use_engine]
## allows it), else plays the raycaster.
func start_game() -> void:
	if use_engine and engine == null and ClassDB.class_exists(&"PureDoom"):
		# The class only exists with the library loaded, so it is created here rather than placed in the scene
		engine = ClassDB.instantiate(&"PureDoom") as Control
		engine.set_anchors_preset(Control.PRESET_FULL_RECT)
		# The node defaults to this path too, but the libraries in bin/ were built when the addon lived at
		# addons/pure_doom, so they still bake in the old one. Setting it here works on every platform.
		engine.set(&"wad_path", "res://addons/godot_doom_gdextension/assets/doom1.wad")
		engine.connect(&"exited", sleep.unbind(1))
		add_child(engine)
		if soundfont != "" and ResourceLoader.exists("res://addons/midi/MidiPlayer.tscn"):
			midi_player = (load("res://addons/midi/MidiPlayer.tscn") as PackedScene).instantiate()
			midi_player.set(&"soundfont", soundfont)
			add_child(midi_player)
			engine.connect(&"midi_message", Callable(midi_player, &"receive_raw_midi_message"))
	if engine:
		boot_label.hide()
		screen = Screen.ENGINE
		engine.show()
		engine.call(&"start")
		queue_redraw()
	else:
		start_level()


## Resets health, ammo and the demons from [constant MAP] and starts the raycaster.
func start_level() -> void:
	boot_label.hide()
	health = 100
	ammo = 50
	kills = 0
	fire_cooldown = 0.0
	flash_time = 0.0
	hurt_time = 0.0
	demons.clear()
	for y: int in MAP.size():
		for x: int in MAP[y].length():
			var cell: String = MAP[y][x]
			if cell == "P":
				player_position = Vector2(x + 0.5, y + 0.5)
				player_angle = 0.0
			elif cell == "E":
				var demon: Demon = Demon.new()
				demon.position = Vector2(x + 0.5, y + 0.5)
				demons.append(demon)
	screen = Screen.PLAYING
	set_physics_process(true)
	queue_redraw()


## Fires the shotgun at the nearest demon inside the aim cone with a clear line of sight.
func fire() -> void:
	if ammo <= 0 or fire_cooldown > 0.0:
		return
	ammo -= 1
	fire_cooldown = 0.6
	flash_time = 0.1
	play_sound(shoot_sfx)
	var target: Demon = null
	var target_distance: float = INF
	for demon: Demon in demons:
		if demon.health <= 0:
			continue
		var to_demon: Vector2 = demon.position - player_position
		var distance: float = to_demon.length()
		var aim_error: float = absf(angle_difference(player_angle, to_demon.angle()))
		if aim_error < atan2(0.35, distance) and distance < target_distance and has_line_of_sight(player_position, demon.position):
			target = demon
			target_distance = distance
	if target == null:
		return
	target.is_awake = true
	target.health -= shotgun_damage
	if target.health <= 0:
		kills += 1
		play_sound(demon_death_sfx)
		if kills == demons.size():
			screen = Screen.WON
			set_physics_process(false)
			queue_redraw()


## Wakes a demon that can see you, walks it to you and lets it bite when it arrives.
func update_demon(demon: Demon, delta: float) -> void:
	if demon.health <= 0:
		demon.dead_time += delta
		return
	var to_player: Vector2 = player_position - demon.position
	var distance: float = to_player.length()
	if not demon.is_awake:
		demon.is_awake = distance < 10.0 and has_line_of_sight(demon.position, player_position)
		return
	if distance > 1.2:
		demon.position = slide(demon.position, to_player.normalized() * demon_speed * delta, 0.3)
	demon.attack_cooldown -= delta
	if distance < 1.6 and demon.attack_cooldown <= 0.0:
		demon.attack_cooldown = 1.0
		health -= demon_bite
		hurt_time = 0.3
		play_sound(hurt_sfx)
		if health <= 0:
			health = 0
			screen = Screen.DEAD
			set_physics_process(false)
			queue_redraw()


## Moves [param from] by [param step] one axis at a time, stopping [param radius] short of any wall.
func slide(from: Vector2, step: Vector2, radius: float) -> Vector2:
	var to: Vector2 = from
	if not is_wall(Vector2(from.x + step.x + signf(step.x) * radius, from.y)):
		to.x += step.x
	if not is_wall(Vector2(to.x, from.y + step.y + signf(step.y) * radius)):
		to.y += step.y
	return to


## Returns the wall kind in the cell, -1 for floor; anything off the map counts as stone.
func wall_kind_at(x: int, y: int) -> int:
	if y < 0 or y >= MAP.size() or x < 0 or x >= MAP[y].length():
		return 0
	return WALL_KINDS.get(MAP[y][x], -1)


func is_wall(point: Vector2) -> bool:
	return wall_kind_at(floori(point.x), floori(point.y)) >= 0


## Steps along the segment in tenths of a cell looking for a wall in the way.
func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var steps: int = ceili(from.distance_to(to) * 10.0)
	for i: int in steps:
		if is_wall(from.lerp(to, float(i) / steps)):
			return false
	return true


func play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	sound.stream = stream
	sound.play()


func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color.BLACK)
	if screen == Screen.PROMPT or screen == Screen.BOOTING or screen == Screen.ENGINE:
		return
	var forward: Vector2 = Vector2.from_angle(player_angle)
	var plane: Vector2 = Vector2(-forward.y, forward.x) * PLANE_LENGTH
	draw_floor_and_ceiling()
	draw_walls(forward, plane)
	draw_demons(forward, plane)
	draw_shotgun()
	if hurt_time > 0.0:
		draw_rect(Rect2(0, 0, WIDTH, VIEW_HEIGHT), Color(0.8, 0.0, 0.0, 0.35))
	draw_status_bar()
	if screen == Screen.DEAD:
		draw_rect(Rect2(0, 0, WIDTH, VIEW_HEIGHT), Color(0.5, 0.0, 0.0, 0.55))
		draw_banner("YOU DIED", "FIRE TO TRY AGAIN")
	elif screen == Screen.WON:
		draw_banner("LEVEL COMPLETE", "FIRE TO PLAY AGAIN")


## Eight bands each way from the horizon, darker as they recede, like the original's light diminishing.
func draw_floor_and_ceiling() -> void:
	var band: int = HALF_VIEW / 8
	for i: int in 8:
		var brightness: float = 0.35 + 0.65 * i / 7.0
		draw_rect(Rect2(0, HALF_VIEW - (i + 1) * band, WIDTH, band), Color(0.16, 0.16, 0.2) * brightness)
		draw_rect(Rect2(0, HALF_VIEW + i * band, WIDTH, band), Color(0.32, 0.24, 0.18) * brightness)


## Casts one ray per screen column through the map grid and draws the textured wall slice it hits.
func draw_walls(forward: Vector2, plane: Vector2) -> void:
	for x: int in WIDTH:
		var ray: Vector2 = forward + plane * (2.0 * x / WIDTH - 1.0)
		var map_x: int = floori(player_position.x)
		var map_y: int = floori(player_position.y)
		var delta_x: float = absf(1.0 / ray.x) if ray.x != 0.0 else 1e30
		var delta_y: float = absf(1.0 / ray.y) if ray.y != 0.0 else 1e30
		var step_x: int = -1 if ray.x < 0.0 else 1
		var step_y: int = -1 if ray.y < 0.0 else 1
		var side_x: float = (player_position.x - map_x) * delta_x if ray.x < 0.0 else (map_x + 1.0 - player_position.x) * delta_x
		var side_y: float = (player_position.y - map_y) * delta_y if ray.y < 0.0 else (map_y + 1.0 - player_position.y) * delta_y
		var side: int = 0
		var kind: int = -1
		while kind < 0:
			if side_x < side_y:
				side_x += delta_x
				map_x += step_x
				side = 0
			else:
				side_y += delta_y
				map_y += step_y
				side = 1
			kind = wall_kind_at(map_x, map_y)
		var distance: float = maxf(side_x - delta_x if side == 0 else side_y - delta_y, 0.01)
		depth[x] = distance
		var line_height: float = VIEW_HEIGHT / distance
		var wall_x: float = player_position.y + distance * ray.y if side == 0 else player_position.x + distance * ray.x
		wall_x -= floorf(wall_x)
		var texture_x: int = int(wall_x * TEXTURE_SIZE)
		if (side == 0 and ray.x > 0.0) or (side == 1 and ray.y < 0.0):
			texture_x = TEXTURE_SIZE - 1 - texture_x
		var brightness: float = clampf(1.0 - distance / 14.0, 0.2, 1.0) * (0.75 if side == 1 else 1.0)
		draw_texture_rect_region(wall_textures[kind], Rect2(x, HALF_VIEW - line_height * 0.5, 1, line_height),
				Rect2(texture_x, 0, 1, TEXTURE_SIZE), Color(brightness, brightness, brightness))


## Projects each demon (or its splat) onto the view, far to near, drawing only the columns in front of the walls.
func draw_demons(forward: Vector2, plane: Vector2) -> void:
	var visible_demons: Array[Demon] = []
	visible_demons.assign(demons.filter(func(demon: Demon) -> bool: return demon.health > 0 or demon.dead_time < SPLAT_TIME))
	visible_demons.sort_custom(func(a: Demon, b: Demon) -> bool:
		return a.position.distance_squared_to(player_position) > b.position.distance_squared_to(player_position))
	var inverse_determinant: float = 1.0 / (plane.x * forward.y - forward.x * plane.y)
	for demon: Demon in visible_demons:
		var relative: Vector2 = demon.position - player_position
		var view_x: float = inverse_determinant * (forward.y * relative.x - forward.x * relative.y)
		var view_depth: float = inverse_determinant * (-plane.y * relative.x + plane.x * relative.y)
		if view_depth <= 0.1:
			continue
		var size: int = int(VIEW_HEIGHT / view_depth)
		var left: int = int(WIDTH * 0.5 * (1.0 + view_x / view_depth)) - size / 2
		var top: float = HALF_VIEW - size * 0.5
		var brightness: float = clampf(1.0 - view_depth / 14.0, 0.2, 1.0)
		var tint: Color = Color(brightness, brightness, brightness, 1.0 if demon.health > 0 else 1.0 - demon.dead_time / SPLAT_TIME)
		var texture: ImageTexture = demon_texture if demon.health > 0 else splat_texture
		for column: int in range(maxi(left, 0), mini(left + size, WIDTH)):
			if view_depth >= depth[column]:
				continue
			var texture_x: int = (column - left) * SPRITE_SIZE / size
			draw_texture_rect_region(texture, Rect2(column, top, 1, size), Rect2(texture_x, 0, 1, SPRITE_SIZE), tint)


## The shotgun sways with your stride, kicks back when fired and flashes at the muzzle.
func draw_shotgun() -> void:
	var sway: Vector2 = Vector2(sin(bob) * 6.0, absf(cos(bob)) * 4.0)
	var kick: float = 10.0 if flash_time > 0.0 else 0.0
	var origin: Vector2 = Vector2(WIDTH * 0.5 - 64.0 + sway.x, VIEW_HEIGHT - 96.0 + sway.y + kick)
	if flash_time > 0.0:
		draw_texture_rect(flash_texture, Rect2(origin + Vector2(40.0, -36.0), Vector2(48.0, 48.0)), false)
	draw_texture_rect(shotgun_texture, Rect2(origin, Vector2(128.0, 96.0)), false)


## Ammo, health and kills in red numerals around a face that glances about and grimaces when bitten.
func draw_status_bar() -> void:
	draw_rect(Rect2(0, VIEW_HEIGHT, WIDTH, HEIGHT - VIEW_HEIGHT), Color(0.22, 0.22, 0.22))
	draw_rect(Rect2(0, VIEW_HEIGHT, WIDTH, 2), Color(0.4, 0.4, 0.4))
	var numeral: Color = Color(0.85, 0.15, 0.1)
	draw_string(font, Vector2(10, VIEW_HEIGHT + 13), "AMMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(10, VIEW_HEIGHT + 28), "%d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, numeral)
	draw_string(font, Vector2(70, VIEW_HEIGHT + 13), "HEALTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(70, VIEW_HEIGHT + 28), "%d%%" % health, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, numeral)
	draw_string(font, Vector2(200, VIEW_HEIGHT + 13), "KILLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.7, 0.7))
	draw_string(font, Vector2(200, VIEW_HEIGHT + 28), "%d / %d" % [kills, demons.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, numeral)
	var face: Vector2 = Vector2(148, VIEW_HEIGHT + 4)
	var pain: float = 1.0 - health / 100.0
	draw_rect(Rect2(face, Vector2(24, 24)), Color(0.9, 0.7, 0.55).lerp(Color(0.7, 0.15, 0.1), pain * 0.8))
	draw_rect(Rect2(face, Vector2(24, 5)), Color(0.35, 0.2, 0.1))
	draw_rect(Rect2(face + Vector2(4, 8), Vector2(6, 4)), Color.WHITE)
	draw_rect(Rect2(face + Vector2(14, 8), Vector2(6, 4)), Color.WHITE)
	draw_rect(Rect2(face + Vector2(6 + face_look * 2, 9), Vector2(2, 2)), Color.BLACK)
	draw_rect(Rect2(face + Vector2(16 + face_look * 2, 9), Vector2(2, 2)), Color.BLACK)
	if hurt_time > 0.0 or screen == Screen.DEAD:
		draw_rect(Rect2(face + Vector2(8, 16), Vector2(8, 5)), Color(0.3, 0.0, 0.0))
	else:
		draw_rect(Rect2(face + Vector2(7, 18), Vector2(10, 1)), Color(0.3, 0.1, 0.1))


func draw_banner(title: String, hint: String) -> void:
	draw_string(font, Vector2(0, 80), title, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 24, Color(0.95, 0.2, 0.1))
	draw_string(font, Vector2(0, 100), hint, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 10, Color(0.9, 0.9, 0.9))


## Stone bricks, brown bricks or tech panels with a green light strip; the grit is seeded so every run matches.
func make_wall_texture(kind: int) -> ImageTexture:
	var image: Image = Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = kind + 1
	for y: int in TEXTURE_SIZE:
		for x: int in TEXTURE_SIZE:
			var grit: float = rng.randf_range(-0.05, 0.05)
			var color: Color
			if kind == 2:
				var seam: bool = x % 32 < 1 or y % 32 < 1
				var light: bool = y % 32 > 26 and y % 32 < 31 and x % 32 > 7 and x % 32 < 25
				color = Color(0.12, 0.13, 0.15) if seam else (Color(0.2, 0.9, 0.3) if light else Color(0.3, 0.32, 0.36))
			else:
				var row_offset: int = 8 if (y / 16) % 2 == 1 else 0
				var mortar: bool = y % 16 < 2 or (x + row_offset) % 32 < 2
				if kind == 0:
					color = Color(0.25, 0.25, 0.25) if mortar else Color(0.55, 0.53, 0.5)
				else:
					color = Color(0.2, 0.12, 0.08) if mortar else Color(0.5, 0.26, 0.15)
			image.set_pixel(x, y, color + Color(grit, grit, grit, 0.0))
	return ImageTexture.create_from_image(image)


## A red ball with a green eye and a toothy grin.
func make_demon_texture() -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	var centre: Vector2 = Vector2(16.0, 16.0)
	for y: int in SPRITE_SIZE:
		for x: int in SPRITE_SIZE:
			var point: Vector2 = Vector2(x + 0.5, y + 0.5)
			var radius: float = point.distance_to(centre)
			if radius > 14.0:
				continue
			var color: Color = Color(0.8, 0.12, 0.1) * (1.15 - 0.6 * pow(radius / 14.0, 2.0))
			if radius > 13.0:
				color = Color(0.15, 0.0, 0.0)
			var eye: float = point.distance_to(Vector2(16.0, 11.0))
			if eye < 4.0:
				color = Color(0.2, 0.85, 0.25) if eye > 1.8 else Color.BLACK
			if y >= 19 and y <= 23 and absf(x - 15.5) < 8.0 - (y - 19):
				color = Color(0.15, 0.0, 0.0) if not (y <= 20 and x % 3 == 0) else Color(0.95, 0.95, 0.9)
			color.a = 1.0
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


## The gore left behind when a demon dies.
func make_splat_texture() -> ImageTexture:
	var image: Image = Image.create(SPRITE_SIZE, SPRITE_SIZE, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for y: int in SPRITE_SIZE:
		for x: int in SPRITE_SIZE:
			var radius: float = Vector2(x - 15.5, y - 15.5).length()
			if radius < 11.0 * rng.randf_range(0.5, 1.0):
				image.set_pixel(x, y, Color(0.6, 0.02, 0.02) * rng.randf_range(0.7, 1.2))
	return ImageTexture.create_from_image(image)


## A pump shotgun seen from behind: barrel, wooden pump, receiver and stock, 64 by 48 and drawn at twice that.
func make_shotgun_texture() -> ImageTexture:
	var image: Image = Image.create(64, 48, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(27, 0, 10, 32), Color(0.3, 0.3, 0.33))
	image.fill_rect(Rect2i(27, 0, 2, 32), Color(0.18, 0.18, 0.2))
	image.fill_rect(Rect2i(35, 0, 2, 32), Color(0.18, 0.18, 0.2))
	image.fill_rect(Rect2i(31, 0, 2, 32), Color(0.45, 0.45, 0.5))
	image.fill_rect(Rect2i(30, 0, 4, 3), Color(0.05, 0.05, 0.05))
	image.fill_rect(Rect2i(23, 14, 18, 12), Color(0.45, 0.28, 0.12))
	for rib: int in range(15, 26, 3):
		image.fill_rect(Rect2i(23, rib, 18, 1), Color(0.3, 0.17, 0.07))
	image.fill_rect(Rect2i(20, 30, 24, 10), Color(0.22, 0.22, 0.25))
	image.fill_rect(Rect2i(20, 30, 24, 2), Color(0.35, 0.35, 0.38))
	image.fill_rect(Rect2i(26, 38, 28, 10), Color(0.4, 0.24, 0.1))
	image.fill_rect(Rect2i(26, 38, 28, 2), Color(0.55, 0.35, 0.15))
	return ImageTexture.create_from_image(image)


## A spiky yellow and orange burst for the muzzle.
func make_flash_texture() -> ImageTexture:
	var image: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y: int in 24:
		for x: int in 24:
			var offset: Vector2 = Vector2(x - 11.5, y - 11.5)
			var reach: float = 11.5 * (0.6 + 0.4 * absf(sin(offset.angle() * 4.0)))
			var radius: float = offset.length()
			if radius < reach * 0.4:
				image.set_pixel(x, y, Color(1.0, 1.0, 0.85))
			elif radius < reach * 0.7:
				image.set_pixel(x, y, Color(1.0, 0.85, 0.2))
			elif radius < reach:
				image.set_pixel(x, y, Color(1.0, 0.45, 0.1))
	return ImageTexture.create_from_image(image)
