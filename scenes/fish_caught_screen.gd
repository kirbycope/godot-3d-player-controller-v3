class_name FishCaughtScreen
extends PlayerMenuLayer
## The catch held up, Zelda style: the fish turning in front of a fan of rays (`resources/shaders/radial_shine.gdshader`),
## its name, its length with a star when it is the record, and its flavour text ([member Item.description]). A
## [PlayerMenuLayer], so the Player stands still and, alone, the world pauses; Action, Confirm, Cancel or Start puts it
## away. The rod on the Player opens it once the catch has arced into their hands; junk reads "Junk" for its size.

var shown: Fish

@onready var model_pivot: Node3D = %ModelPivot
@onready var model_camera: Camera3D = %ModelCamera
@onready var preview: SubViewportContainer = %Preview
@onready var name_label: Label = %NameLabel
@onready var size_label: Label = %SizeLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var rays: ColorRect = %Rays

var _last_tick_usec: int = 0 ## Wall clock at the last frame, since delta is zero while the world is frozen.
var _spin_seconds: float = 0.0 ## Seconds the rays have turned, handed to the shine shader in place of TIME.


func _ready() -> void:
	super()
	set_process(false)


func _input(event: InputEvent) -> void:
	super(event)
	if visible and (event.is_action_pressed("action") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		hide_menu()
		get_viewport().set_input_as_handled()


## Fills the screen for [param fish] at [param length_cm] and shows it; [param is_record] adds the star.
func show_catch(fish: Fish, length_cm: float, is_record: bool = false) -> void:
	shown = fish
	name_label.text = fish.get_display_name()
	size_label.text = "Junk" if fish.is_junk else "%.1f cm%s" % [length_cm, "  * record" if is_record else ""]
	flavor_label.text = fish.description
	_show_model(fish)
	show_menu()


func show_menu() -> void:
	super()
	_last_tick_usec = Time.get_ticks_usec()
	set_process(true)


func hide_menu() -> void:
	super()
	set_process(false)


## The world behind the screen is frozen ([method PlayerMenuLayer.freeze_time]), which makes [param _delta] zero
## and stops the shader clock, so the fish turns and the rays wheel on the wall clock instead.
func _process(_delta: float) -> void:
	super(_delta)
	var now: int = Time.get_ticks_usec()
	var seconds: float = (now - _last_tick_usec) / 1_000_000.0
	_last_tick_usec = now
	model_pivot.rotate_y(seconds * 0.8)
	_spin_seconds += seconds
	(rays.material as ShaderMaterial).set_shader_parameter(&"spin_seconds", _spin_seconds)


## The species' model ([method Fish.get_model_scene]) turning in the viewport, at its base size and centred as the
## inventory preview does.
func _show_model(fish: Fish) -> void:
	for child: Node in model_pivot.get_children():
		child.queue_free()
	var model: Node3D = fish.get_model_scene().instantiate() as Node3D
	model_pivot.add_child(model)
	fish.prepare_model(model) # once in the tree, so the model's own ready nodes exist
	var bounds: AABB = Fish.model_bounds(model, model_pivot)
	model.position = -bounds.get_center()
	model_camera.size = maxf(bounds.get_longest_axis_size() * 1.4, 0.1)
