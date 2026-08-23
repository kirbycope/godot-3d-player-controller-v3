extends Node3D

## Demo controller for testing the radi-ot 3D radio addon.

const AUDIO_SPACE_NEEDLE: AudioStream = preload(
	"res://addons/radi_ot/assets/audio/eleven_labs/david/breaking_news_space_needle.mp3"
)
const AUDIO_COASTAL_WIND: AudioStream = preload(
	"res://addons/radi_ot/assets/audio/eleven_labs/david/weather_alert_coastal_wind.mp3"
)

@export var radio_player: RadiOtPlayer3D

var project_rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")

@onready var _bulletin_button_1: Button = $UI/VBoxContainer/BulletinBtn1 as Button
@onready var _bulletin_button_2: Button = $UI/VBoxContainer/BulletinBtn2 as Button
@onready var _cancel_bulletin_btn: Button = $UI/VBoxContainer/CancelBulletinBtn as Button
@onready var _camera: Camera3D = $Camera3D as Camera3D
@onready var click_to_start: CanvasLayer = $ClickToStart


func _ready() -> void:
	if radio_player == null and has_node("RadioMesh/RadiOtPlayer3D"):
		radio_player = get_node("RadioMesh/RadiOtPlayer3D") as RadiOtPlayer3D

	# Get rendering settings from the project settings
	var requires_input_activation: bool = (
		OS.has_feature("web")
		or project_rendering_method not in ["forward_plus", "mobile"]
	)
	# [Webfix] Show the Click to Start button
	if requires_input_activation:
		if click_to_start != null:
			click_to_start.show()
	else:
		if click_to_start != null:
			click_to_start.hide()


func _input(event: InputEvent) -> void:
	if click_to_start != null and click_to_start.visible:
		if (event is InputEventMouseButton and event.is_pressed()) \
				or (event is InputEventScreenTouch and event.is_pressed()):
			_start_demo()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or radio_player == null:
		return
	if not radio_player.enable_keyboard_controls or not radio_player.is_power_on():
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event: InputEventKey = event as InputEventKey
		if key_event.physical_keycode == KEY_L or key_event.keycode == KEY_L:
			radio_player.tune_next_station()
		elif key_event.physical_keycode == KEY_J or key_event.keycode == KEY_J:
			radio_player.tune_previous_station()
		elif key_event.physical_keycode == KEY_M or key_event.keycode == KEY_M:
			radio_player.toggle_power()


func _start_demo() -> void:
	if click_to_start != null:
		click_to_start.hide()
	if radio_player != null:
		radio_player.tune_to_station_index(0)


func _process(delta: float) -> void:
	# Subtle slow camera orbit to showcase 3D spatial audio
	if _camera != null:
		var current_y: float = _camera.position.y
		var time: float = Time.get_ticks_msec() / 1000.0 * 0.2
		_camera.position.x = sin(time) * 4.0
		_camera.position.z = cos(time) * 4.0
		_camera.position.y = current_y
		_camera.look_at(Vector3(0.0, 0.5, 0.0))


func _on_bulletin_btn_1_pressed() -> void:
	if radio_player != null:
		radio_player.urgent_bulletin(
			AUDIO_SPACE_NEEDLE,
			"Unidentified phenomena reported over the Space Needle! Citizens are advised to stay indoors."
		)


func _on_bulletin_btn_2_pressed() -> void:
	if radio_player != null:
		radio_player.urgent_bulletin(
			AUDIO_COASTAL_WIND,
			"Severe coastal wind advisory in effect across Puget Sound and SR-99 Alaskan Way."
		)


func _on_cancel_bulletin_btn_pressed() -> void:
	if radio_player != null:
		radio_player.cancel_bulletin()


func _on_last_station_pressed() -> void:
	if radio_player != null:
		radio_player.tune_previous_station()


func _on_last_touch_screen_button_pressed() -> void:
	if radio_player != null:
		radio_player.tune_previous_station()


func _on_next_station_pressed() -> void:
	if radio_player != null:
		radio_player.tune_next_station()


func _on_next_touch_screen_button_pressed() -> void:
	if radio_player != null:
		radio_player.tune_next_station()
